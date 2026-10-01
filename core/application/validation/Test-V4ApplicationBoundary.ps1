[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$packageRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$buildRoot = Join-Path $packageRoot 'build'
$hostProject = Join-Path $packageRoot 'core/host/V4.Guards.Host/V4.Guards.Host.csproj'
$companionProject = Join-Path $packageRoot 'integrations/web/V4.Guards.WebCompanion/V4.Guards.WebCompanion.csproj'
$runRoot = Join-Path ([IO.Path]::GetTempPath()) ('v4-m3-application-' + [Guid]::NewGuid().ToString('N'))
$artifactsRoot = Join-Path $runRoot 'artifacts'
$hostOutput = Join-Path $runRoot 'host'
$companionOutput = Join-Path $runRoot 'companion'
$targetRoot = Join-Path $runRoot 'target'
$stateRoot = Join-Path $runRoot 'state'
$evidenceRoot = Join-Path $runRoot 'evidence'
$failures = [Collections.Generic.List[string]]::new()
$companion = $null
$client = $null

function Fail([string] $Message) { $script:failures.Add($Message) }

function Hash-Tree([string] $Root) {
    $items = [ordered]@{}
    foreach ($file in @(Get-ChildItem -LiteralPath $Root -Recurse -File -Force | Where-Object { $_.FullName -notmatch '[\\/]\.git[\\/]' } | Sort-Object FullName)) {
        $relative = [IO.Path]::GetRelativePath($Root, $file.FullName).Replace('\','/')
        $items[$relative] = (Get-FileHash -Algorithm SHA256 -LiteralPath $file.FullName).Hash.ToLowerInvariant()
    }
    $items | ConvertTo-Json -Compress
}

function Build-Project([string] $Project, [string] $Output) {
    $properties = @(
        '-p:ImportDirectoryBuildProps=false', '-p:ImportDirectoryBuildTargets=false', '-p:ImportDirectoryPackagesProps=false',
        '-p:ImportDirectorySolutionProps=false', '-p:ImportDirectorySolutionTargets=false',
        "-p:CustomBeforeMicrosoftCommonProps=$(Join-Path $buildRoot 'V4.Build.props')"
    )
    Push-Location $buildRoot
    try {
        & dotnet restore $Project --configfile (Join-Path $buildRoot 'NuGet.config') --artifacts-path $artifactsRoot -nologo @properties
        if ($LASTEXITCODE) { throw "Restore failed for $Project" }
        & dotnet build $Project --no-restore --artifacts-path $artifactsRoot -o $Output -nologo @properties
        if ($LASTEXITCODE) { throw "Build failed for $Project" }
    }
    finally { Pop-Location }
}

function Invoke-Host([string[]] $Arguments) {
    $dotnet = (Get-Command dotnet -ErrorAction Stop).Source
    $start = [Diagnostics.ProcessStartInfo]::new($dotnet)
    $start.UseShellExecute = $false
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.CreateNoWindow = $true
    [void]$start.ArgumentList.Add((Join-Path $hostOutput 'v4-guards.dll'))
    foreach ($argument in $Arguments) { [void]$start.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::Start($start)
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()
    [pscustomobject]@{ Code=$process.ExitCode; Raw=$(if($process.ExitCode -eq 0){$stdout.TrimEnd()}else{$stderr.TrimEnd()}) }
}

function Start-Companion() {
    $dotnet = (Get-Command dotnet -ErrorAction Stop).Source
    $start = [Diagnostics.ProcessStartInfo]::new($dotnet)
    $start.UseShellExecute = $false
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.CreateNoWindow = $true
    $start.WorkingDirectory = $companionOutput
    foreach ($argument in @(
        (Join-Path $companionOutput 'v4-web-companion.dll'), '--package-root', $packageRoot,
        '--target-root', $targetRoot, '--state-root', $stateRoot, '--evidence-root', $evidenceRoot,
        '--plan-root', 'plans', '--host', (Join-Path $hostOutput 'v4-guards.dll'), '--port', '0'
    )) { [void]$start.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::new(); $process.StartInfo = $start
    if (-not $process.Start()) { throw 'M3 Companion did not start.' }
    $readyTask = $process.StandardOutput.ReadLineAsync()
    if (-not $readyTask.Wait([TimeSpan]::FromSeconds(30))) { try { $process.Kill($true) } catch {}; throw 'M3 Companion readiness timed out.' }
    $ready = $readyTask.Result | ConvertFrom-Json
    if ($ready.status -cne 'ready' -or $ready.address -notmatch '^http://127\.0\.0\.1:[0-9]+$') { throw "Invalid readiness: $($readyTask.Result)" }
    [pscustomobject]@{ Process=$process; Address=[string]$ready.address }
}

function Invoke-Get([Net.Http.HttpClient] $HttpClient, [string] $Url) {
    $response = $HttpClient.GetAsync($Url).GetAwaiter().GetResult()
    try { [pscustomobject]@{ StatusCode=[int]$response.StatusCode; Body=$response.Content.ReadAsStringAsync().GetAwaiter().GetResult() } }
    finally { $response.Dispose() }
}

function Invoke-Post([Net.Http.HttpClient] $HttpClient, [string] $Url, [string] $Json, [string] $Csrf = '', [switch] $WithOrigin) {
    $request = [Net.Http.HttpRequestMessage]::new([Net.Http.HttpMethod]::Post, $Url)
    try {
        if ($WithOrigin) { [void]$request.Headers.TryAddWithoutValidation('Origin', ([Uri]$Url).GetLeftPart([UriPartial]::Authority)) }
        if (-not [string]::IsNullOrEmpty($Csrf)) { [void]$request.Headers.TryAddWithoutValidation('X-V4-CSRF', $Csrf) }
        $request.Content = [Net.Http.StringContent]::new($Json, [Text.Encoding]::UTF8, 'application/json')
        $response = $HttpClient.Send($request)
        try { [pscustomobject]@{ StatusCode=[int]$response.StatusCode; Body=$response.Content.ReadAsStringAsync().GetAwaiter().GetResult() } }
        finally { $response.Dispose() }
    }
    finally { $request.Dispose() }
}

[void][IO.Directory]::CreateDirectory($targetRoot)
[void][IO.Directory]::CreateDirectory($stateRoot)
[void][IO.Directory]::CreateDirectory($evidenceRoot)
[void][IO.Directory]::CreateDirectory((Join-Path $targetRoot 'plans'))
[void][IO.Directory]::CreateDirectory((Join-Path $targetRoot '.github/workflows'))
[IO.File]::WriteAllText((Join-Path $targetRoot 'sample.csproj'), '<Project Sdk="Microsoft.NET.Sdk" />', [Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $targetRoot 'input.txt'), "synthetic-ok`n", [Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $targetRoot '.github/workflows/v4-guards.yml'), "name: v4-required`n", [Text.UTF8Encoding]::new($false))
$plan = [ordered]@{
    formatVersion=1; id='20261001-m3-fixture'; title='M3 fixture'; goal='Exercise read-only Plan handoff.'
    acceptanceCriteria=@('The Plan is visible.'); plannedPaths=@('sample.csproj'); areas=@('fixture'); risks=@('none')
    decisions=@('read-only'); validationCommands=@('fixture'); dependencies=@(); boundaries=@()
}
[IO.File]::WriteAllText((Join-Path $targetRoot 'plans/20261001-m3-fixture.plan.json'), ($plan | ConvertTo-Json -Depth 10) + "`n", [Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $targetRoot 'plans/20261001-m3-fixture.md'), "# M3 fixture`n", [Text.UTF8Encoding]::new($false))

try {
    foreach ($schema in Get-ChildItem -LiteralPath (Join-Path $packageRoot 'core/application/contracts') -Filter '*.schema.json') {
        try { Get-Content -Raw -LiteralPath $schema.FullName | ConvertFrom-Json | Out-Null }
        catch { Fail "Application schema is invalid JSON: $($schema.Name)" }
    }
    foreach ($schema in Get-ChildItem -LiteralPath (Join-Path $packageRoot 'integrations/web/V4.Guards.WebCompanion/contracts') -Filter 'application-*.schema.json') {
        try { Get-Content -Raw -LiteralPath $schema.FullName | ConvertFrom-Json | Out-Null }
        catch { Fail "Companion application schema is invalid JSON: $($schema.Name)" }
    }
    if (-not (Test-Json -LiteralPath (Join-Path $packageRoot 'core/application/contracts/application-service-contract.json') -SchemaFile (Join-Path $packageRoot 'core/application/contracts/application-service-contract.schema.json') -ErrorAction SilentlyContinue)) {
        Fail 'Application service contract violates its schema.'
    }
    $contract = Get-Content -Raw -LiteralPath (Join-Path $packageRoot 'core/application/contracts/application-service-contract.json') | ConvertFrom-Json
    foreach ($entry in $contract.schemas) {
        $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $packageRoot $entry.path)).Hash.ToLowerInvariant()
        if ($actual -cne $entry.sha256) { Fail "Application schema hash drift: $($entry.id)" }
    }

    Build-Project $hostProject $hostOutput
    Build-Project $companionProject $companionOutput

    $bind = Invoke-Host @('state','bind','--package-root',$packageRoot,'--target-root',$targetRoot,'--state-root',$stateRoot,'--evidence-root',$evidenceRoot,'--profile','synthetic_profile')
    if ($bind.Code -ne 0) { throw "Fixture state bind failed: $($bind.Raw)" }

    $common = @('--package-root',$packageRoot,'--target-root',$targetRoot,'--state-root',$stateRoot,'--evidence-root',$evidenceRoot,'--plan-root','plans')
    $direct = @{}
    foreach ($operation in @('setup','protection','authorities','lifecycle')) {
        $first = Invoke-Host (@('application','preview','--operation',$operation) + $common)
        $second = Invoke-Host (@('application','preview','--operation',$operation) + $common)
        if ($first.Code -ne 0 -or $second.Code -ne 0) { Fail "Host $operation preview failed: $($first.Raw) $($second.Raw)"; continue }
        $document = $first.Raw | ConvertFrom-Json -Depth 100
        if ($document.previewHash -cne (($second.Raw | ConvertFrom-Json -Depth 100).previewHash)) { Fail "Host $operation preview is not deterministic." }
        if (-not (Test-Json -Json $first.Raw -SchemaFile (Join-Path $packageRoot 'core/application/contracts/application-preview.schema.json') -ErrorAction SilentlyContinue)) { Fail "Host $operation preview violates the envelope schema." }
        $payloadSchema = @{setup='setup-preview';protection='protection-status';authorities='authority-handoff';lifecycle='lifecycle-preview'}[$operation]
        if (-not (Test-Json -Json ($document.payload | ConvertTo-Json -Depth 100) -SchemaFile (Join-Path $packageRoot "core/application/contracts/$payloadSchema.schema.json") -ErrorAction SilentlyContinue)) { Fail "Host $operation payload violates its schema." }
        if ($operation -eq 'setup' -and ($document.payload.summary.applyAvailable -ne $false -or @($document.payload.steps).Count -ne 7)) { Fail 'Setup preview exposed apply or omitted a required step.' }
        if ($operation -eq 'protection') {
            $components = @{}; foreach ($component in $document.payload.components) { $components[[string]$component.id] = [string]$component.status }
            if ($document.payload.protected -ne $false -or $document.payload.localRunnable -ne $true -or
                $components['initialized-context'] -cne 'pass' -or $components['accepted-non-empty-profile'] -cne 'pass' -or
                $components['satisfied-prerequisites'] -cne 'pass' -or $components['required-stage-coverage'] -cne 'pass' -or
                $components['verified-immutable-composition'] -cne 'unverified' -or $components['ci-authority-pin'] -cne 'unverified' -or
                $components['aggregate-verdict-enforcement'] -cne 'unverified') { Fail 'Protection status did not separate local runnable state from required unverified protection proofs.' }
        }
        if ($operation -eq 'authorities' -and (@($document.payload.profiles).Count -lt 2 -or @($document.payload.modules).Count -lt 3 -or @($document.payload.plans).Count -ne 1)) { Fail 'Authority handoff inventory is incomplete.' }
        if ($operation -eq 'lifecycle' -and (@($document.payload.actions | Where-Object available).id -join ',') -cne 'verify') { Fail 'Lifecycle preview made an apply action available.' }
        $direct[$operation] = $first
    }
    $invalid = Invoke-Host (@('application','preview','--operation','apply') + $common)
    if ($invalid.Code -ne 10 -or $invalid.Raw -notmatch 'not allowlisted') { Fail 'Unknown application operation was not refused.' }
    $injection = Invoke-Host (@('application','preview','--operation','setup') + $common + @('--command','pwsh'))
    if ($injection.Code -ne 10 -or $injection.Raw -notmatch 'Unknown argument') { Fail 'Raw command injection was not refused.' }

    $packageBefore = Hash-Tree $packageRoot
    $targetBefore = Hash-Tree $targetRoot
    $companion = Start-Companion
    $handler = [Net.Http.HttpClientHandler]::new(); $handler.CookieContainer = [Net.CookieContainer]::new()
    $client = [Net.Http.HttpClient]::new($handler)
    $sessionResponse = Invoke-Get $client "$($companion.Address)/api/v1/session"
    if ($sessionResponse.StatusCode -ne 200 -or -not (Test-Json -Json $sessionResponse.Body -SchemaFile (Join-Path $packageRoot 'integrations/web/V4.Guards.WebCompanion/contracts/session.schema.json') -ErrorAction SilentlyContinue)) { throw "Invalid session: $($sessionResponse.Body)" }
    $session = $sessionResponse.Body | ConvertFrom-Json
    $projectId = [string]$session.activeProjectId
    $csrf = [string]$session.csrfToken
    $body = "{`"operationId`":`"protection`",`"projectId`":`"$projectId`"}"

    $anonymous = [Net.Http.HttpClient]::new()
    try { if ((Invoke-Post $anonymous "$($companion.Address)/api/v1/application/preview" $body $csrf -WithOrigin).StatusCode -ne 403) { Fail 'Application preview without session was not refused.' } }
    finally { $anonymous.Dispose() }
    if ((Invoke-Post $client "$($companion.Address)/api/v1/application/preview" $body $csrf).StatusCode -ne 403) { Fail 'Application preview without Origin was not refused.' }
    if ((Invoke-Post $client "$($companion.Address)/api/v1/application/preview" $body '' -WithOrigin).StatusCode -ne 403) { Fail 'Application preview without CSRF was not refused.' }
    if ((Invoke-Post $client "$($companion.Address)/api/v1/application/preview" $body ('0' * 64) -WithOrigin).StatusCode -ne 403) { Fail 'Application preview with the wrong CSRF token was not refused.' }
    $extra = "{`"operationId`":`"protection`",`"projectId`":`"$projectId`",`"command`":`"pwsh`"}"
    $extraResponse = Invoke-Post $client "$($companion.Address)/api/v1/application/preview" $extra $csrf -WithOrigin
    if ($extraResponse.StatusCode -ne 400 -or $extraResponse.Body -notmatch 'Unknown request field') { Fail 'Application request command injection was not structurally refused.' }
    $unknown = "{`"operationId`":`"protection`",`"projectId`":`"$('f' * 32)`"}"
    if ((Invoke-Post $client "$($companion.Address)/api/v1/application/preview" $unknown $csrf -WithOrigin).StatusCode -ne 400) { Fail 'Unknown project ID was not refused.' }
    $oversize = '{"operationId":"protection","projectId":"' + $projectId + '","padding":"' + ('x' * 5000) + '"}'
    if ((Invoke-Post $client "$($companion.Address)/api/v1/application/preview" $oversize $csrf -WithOrigin).StatusCode -ne 413) { Fail 'Oversized application request was not refused by the server limit.' }

    $previewResponse = Invoke-Post $client "$($companion.Address)/api/v1/application/preview" $body $csrf -WithOrigin
    if ($previewResponse.StatusCode -ne 200 -or -not (Test-Json -Json $previewResponse.Body -SchemaFile (Join-Path $packageRoot 'integrations/web/V4.Guards.WebCompanion/contracts/application-operation-response.schema.json') -ErrorAction SilentlyContinue)) { throw "Valid preview failed: $($previewResponse.Body)" }
    $preview = $previewResponse.Body | ConvertFrom-Json -Depth 100
    $directProtection = $direct['protection'].Raw | ConvertFrom-Json -Depth 100
    if ($preview.hostResult.previewHash -cne $directProtection.previewHash -or $preview.hostResult.operation -cne $directProtection.operation) { Fail 'Companion did not preserve the direct Host preview identity.' }
    $expectedHostHash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($direct['protection'].Raw))).ToLowerInvariant()
    if ($preview.hostResultSha256 -cne $expectedHostHash) { Fail 'Companion Host-result byte identity hash differs from direct Host output.' }
    if ($preview.hostResult.payload.protected -ne $false -or @($preview.hostResult.payload.components).Count -ne 7) { Fail 'Protection status was vacuous or incomplete.' }

    [IO.File]::AppendAllText((Join-Path $targetRoot 'sample.csproj'), "`n<!-- drift -->", [Text.UTF8Encoding]::new($false))
    $confirmBody = "{`"operationId`":`"protection`",`"projectId`":`"$projectId`",`"previewHash`":`"$($preview.hostResult.previewHash)`"}"
    $stale = Invoke-Post $client "$($companion.Address)/api/v1/application/confirm" $confirmBody $csrf -WithOrigin
    if ($stale.StatusCode -ne 409 -or $stale.Body -notmatch 'stale-preview') { Fail 'Stale preview confirmation was not refused.' }
    $freshResponse = Invoke-Post $client "$($companion.Address)/api/v1/application/preview" $body $csrf -WithOrigin
    $fresh = $freshResponse.Body | ConvertFrom-Json -Depth 100
    $targetAfterOperatorDrift = Hash-Tree $targetRoot
    $freshConfirmBody = "{`"operationId`":`"protection`",`"projectId`":`"$projectId`",`"previewHash`":`"$($fresh.hostResult.previewHash)`"}"
    $confirmed = Invoke-Post $client "$($companion.Address)/api/v1/application/confirm" $freshConfirmBody $csrf -WithOrigin
    if ($confirmed.StatusCode -ne 200 -or -not (Test-Json -Json $confirmed.Body -SchemaFile (Join-Path $packageRoot 'integrations/web/V4.Guards.WebCompanion/contracts/application-receipt.schema.json') -ErrorAction SilentlyContinue)) { Fail "Fresh confirmation receipt is invalid: $($confirmed.Body)" }
    else {
        $receipt = $confirmed.Body | ConvertFrom-Json
        if ($receipt.applied -ne $false -or ($receipt.unperformed -join ',') -cne 'target-write,composition-selection,ci-activation,remote-change') { Fail 'Confirmation receipt crossed an apply boundary.' }
    }

    $cancelRequest = [Net.Http.HttpRequestMessage]::new([Net.Http.HttpMethod]::Post, "$($companion.Address)/api/v1/application/preview")
    $cancelSource = [Threading.CancellationTokenSource]::new([TimeSpan]::FromMilliseconds(25))
    try {
        [void]$cancelRequest.Headers.TryAddWithoutValidation('Origin', ([Uri]$companion.Address).GetLeftPart([UriPartial]::Authority))
        [void]$cancelRequest.Headers.TryAddWithoutValidation('X-V4-CSRF', $csrf)
        $cancelRequest.Content = [Net.Http.StringContent]::new($body, [Text.Encoding]::UTF8, 'application/json')
        try { $null = $client.SendAsync($cancelRequest, $cancelSource.Token).GetAwaiter().GetResult() } catch [Threading.Tasks.TaskCanceledException] { }
    }
    finally { $cancelSource.Dispose(); $cancelRequest.Dispose() }
    Start-Sleep -Milliseconds 750
    $recovered = Invoke-Post $client "$($companion.Address)/api/v1/application/preview" $body $csrf -WithOrigin
    if ($recovered.StatusCode -ne 200) { Fail 'Application preview did not recover after client cancellation.' }

    if ((Hash-Tree $packageRoot) -cne $packageBefore) { Fail 'PackageRoot changed during M3 application flows.' }
    if ((Hash-Tree $targetRoot) -cne $targetAfterOperatorDrift) { Fail 'The Companion changed TargetRoot after the explicit test-owned drift.' }
    if ($targetBefore -ceq $targetAfterOperatorDrift) { Fail 'The stale-preview test did not create test-owned Target drift.' }
}
finally {
    if ($null -ne $client) { $client.Dispose() }
    if ($null -ne $companion -and -not $companion.Process.HasExited) {
        try { $companion.Process.Kill($true); [void]$companion.Process.WaitForExit(10000) } catch { }
        $companion.Process.Dispose()
    }
    if (Test-Path -LiteralPath $runRoot) { Remove-Item -LiteralPath $runRoot -Recurse -Force }
}

if ($failures.Count -gt 0) { throw "V4 M3 application boundary tests failed:`n - $($failures -join "`n - ")" }
Write-Host "V4 M3 application boundary tests passed on $([Runtime.InteropServices.RuntimeInformation]::OSDescription)."
