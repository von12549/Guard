[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$packageRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $packageRoot '../../..'))
$buildRoot = Join-Path $packageRoot 'build'
$hostProject = Join-Path $packageRoot 'core/host/V4.Guards.Host/V4.Guards.Host.csproj'
$companionProject = Join-Path $packageRoot 'integrations/web/V4.Guards.WebCompanion/V4.Guards.WebCompanion.csproj'
$artifactsRoot = Join-Path $repositoryRoot 'artifacts/guards/v4/p9c'
$hostOutput = Join-Path $artifactsRoot 'host'
$companionOutput = Join-Path $artifactsRoot 'companion'
$fixtureRoot = Join-Path $artifactsRoot 'fixture'
$targetA = Join-Path $fixtureRoot 'target-a'
$targetB = Join-Path $fixtureRoot 'target-b'
$stateRoot = Join-Path $fixtureRoot 'state'
$evidenceRoot = Join-Path $fixtureRoot 'evidence'
$failures = [Collections.Generic.List[string]]::new()
$companion = $null
$client = $null

function Fail([string] $Message) { $script:failures.Add($Message) }

function Hash-Tree([string] $Root) {
    $items = [ordered]@{}
    foreach ($file in @(Get-ChildItem -LiteralPath $Root -Recurse -File -Force | Sort-Object FullName)) {
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

function New-CompanionStart([string[]] $Targets, [string] $State = $stateRoot, [string] $Evidence = $evidenceRoot) {
    $dotnet = (Get-Command dotnet -ErrorAction Stop).Source
    $start = [Diagnostics.ProcessStartInfo]::new($dotnet)
    $start.UseShellExecute = $false
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.CreateNoWindow = $true
    $start.WorkingDirectory = $companionOutput
    foreach ($argument in @(
        (Join-Path $companionOutput 'v4-web-companion.dll'),
        '--package-root', $packageRoot,
        '--state-root', $State,
        '--evidence-root', $Evidence,
        '--host', (Join-Path $hostOutput 'v4-guards.dll'),
        '--port', '0'
    )) { [void]$start.ArgumentList.Add($argument) }
    foreach ($target in $Targets) { [void]$start.ArgumentList.Add('--target-root'); [void]$start.ArgumentList.Add($target) }
    $start
}

function Start-Companion() {
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = New-CompanionStart @($targetA,$targetB)
    if (-not $process.Start()) { throw 'Web Companion did not start.' }
    $readyTask = $process.StandardOutput.ReadLineAsync()
    if (-not $readyTask.Wait([TimeSpan]::FromSeconds(30))) {
        try { $process.Kill($true) } catch { }
        throw 'Timed out waiting for Web Companion readiness.'
    }
    $line = $readyTask.Result
    try { $ready = $line | ConvertFrom-Json }
    catch {
        $errorText = $process.StandardError.ReadToEnd()
        try { $process.Kill($true) } catch { }
        throw "Web Companion readiness is not JSON: $line $errorText"
    }
    if ($ready.status -cne 'ready' -or $ready.address -notmatch '^http://127\.0\.0\.1:[0-9]+$') {
        try { $process.Kill($true) } catch { }
        throw "Web Companion readiness is invalid: $line"
    }
    [pscustomobject]@{ Process=$process; Address=[string]$ready.address }
}

function Invoke-Get([Net.Http.HttpClient] $HttpClient, [string] $Url) {
    $response = $HttpClient.GetAsync($Url).GetAwaiter().GetResult()
    try { [pscustomobject]@{ StatusCode=[int]$response.StatusCode; Body=$response.Content.ReadAsStringAsync().GetAwaiter().GetResult() } }
    finally { $response.Dispose() }
}

function New-JsonRequest([Net.Http.HttpMethod] $Method, [string] $Url, [string] $Json, [switch] $WithOrigin) {
    $request = [Net.Http.HttpRequestMessage]::new($Method, $Url)
    if ($WithOrigin) {
        $origin = ([Uri]$Url).GetLeftPart([UriPartial]::Authority)
        [void]$request.Headers.TryAddWithoutValidation('Origin', $origin)
    }
    $request.Content = [Net.Http.StringContent]::new($Json, [Text.Encoding]::UTF8, 'application/json')
    $request
}

function Invoke-Post([Net.Http.HttpClient] $HttpClient, [string] $Url, [string] $Json, [switch] $WithOrigin) {
    $request = New-JsonRequest ([Net.Http.HttpMethod]::Post) $Url $Json -WithOrigin:$WithOrigin
    try {
        $response = $HttpClient.Send($request)
        try { [pscustomobject]@{ StatusCode=[int]$response.StatusCode; Body=$response.Content.ReadAsStringAsync().GetAwaiter().GetResult() } }
        finally { $response.Dispose() }
    }
    finally { $request.Dispose() }
}

if (Test-Path -LiteralPath $artifactsRoot) { Remove-Item -LiteralPath $artifactsRoot -Recurse -Force }
foreach ($path in @($targetA,$targetB,$stateRoot,$evidenceRoot)) { New-Item -ItemType Directory -Path $path -Force | Out-Null }
[IO.File]::WriteAllText((Join-Path $targetA 'input.txt'), "synthetic-ok`n", [Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $targetB 'input.txt'), "synthetic-ok`n", [Text.UTF8Encoding]::new($false))

try {
    Build-Project $hostProject $hostOutput
    Build-Project $companionProject $companionOutput

    foreach ($schema in @('session','stage-run-request','stage-run-response','workspace','workspace-select-request','workspace-select-response')) {
        $path = Join-Path $packageRoot "integrations/web/V4.Guards.WebCompanion/contracts/$schema.schema.json"
        try { Get-Content -Raw -LiteralPath $path | ConvertFrom-Json | Out-Null }
        catch { Fail "Companion schema is invalid JSON: ${schema}: $($_.Exception.Message)" }
    }

    $packageBefore = Hash-Tree $packageRoot
    $targetABefore = Hash-Tree $targetA
    $targetBBefore = Hash-Tree $targetB
    $companion = Start-Companion
    $handler = [Net.Http.HttpClientHandler]::new()
    $handler.CookieContainer = [Net.CookieContainer]::new()
    $client = [Net.Http.HttpClient]::new($handler)

    $sessionResponse = Invoke-Get $client "$($companion.Address)/api/v1/session"
    if ($sessionResponse.StatusCode -ne 200 -or -not (Test-Json -Json $sessionResponse.Body -SchemaFile (Join-Path $packageRoot 'integrations/web/V4.Guards.WebCompanion/contracts/session.schema.json') -ErrorAction SilentlyContinue)) {
        Fail "Session projection is invalid: $($sessionResponse.Body)"
    }
    else {
        $session = $sessionResponse.Body | ConvertFrom-Json
        if ($session.targetCount -ne 2 -or @($session.allowedProfiles) -notcontains 'synthetic_profile') {
            Fail 'Session did not expose the two trusted Targets and installed Profiles.'
        }
    }

    $anonymous = [Net.Http.HttpClient]::new()
    try {
        $noSession = Invoke-Get $anonymous "$($companion.Address)/api/v1/workspace"
        if ($noSession.StatusCode -ne 403) { Fail 'Workspace query without a session was not refused.' }
    }
    finally { $anonymous.Dispose() }

    $workspaceResponse = Invoke-Get $client "$($companion.Address)/api/v1/workspace"
    if ($workspaceResponse.StatusCode -ne 200 -or -not (Test-Json -Json $workspaceResponse.Body -SchemaFile (Join-Path $packageRoot 'integrations/web/V4.Guards.WebCompanion/contracts/workspace.schema.json') -ErrorAction SilentlyContinue)) {
        throw "Workspace projection is invalid: $($workspaceResponse.Body)"
    }
    $workspace = $workspaceResponse.Body | ConvertFrom-Json -Depth 100
    if (@($workspace.targets).Count -ne 2 -or @($workspace.targets | Where-Object active).Count -ne 1 -or
        $workspace.targets[0].targetRoot -cne $targetA -or $workspace.targets[1].targetRoot -cne $targetB) {
        Fail 'Workspace did not preserve trusted Target order and one-active-Target state.'
    }
    $firstProject = [string]$workspace.targets[0].projectId
    $secondProject = [string]$workspace.targets[1].projectId

    $readiness = Invoke-Get $client "$($companion.Address)/api/v1/readiness/synthetic_profile"
    if ($readiness.StatusCode -ne 200 -or -not (Test-Json -Json $readiness.Body -SchemaFile (Join-Path $packageRoot 'core/contracts/prerequisite-query.schema.json') -ErrorAction SilentlyContinue)) {
        Fail "Readiness endpoint did not preserve prerequisite-query: $($readiness.Body)"
    }

    $noOrigin = Invoke-Post $client "$($companion.Address)/api/v1/workspace/select" "{`"projectId`":`"$secondProject`"}"
    if ($noOrigin.StatusCode -ne 403) { Fail 'Target switch without Origin was not refused.' }
    $pathInjection = Invoke-Post $client "$($companion.Address)/api/v1/workspace/select" "{`"projectId`":`"$secondProject`",`"targetRoot`":`"browser-controlled`"}" -WithOrigin
    if ($pathInjection.StatusCode -ne 400 -or $pathInjection.Body -notmatch 'Unknown request field') { Fail 'Browser Target path input was not structurally refused.' }
    $unknownProject = Invoke-Post $client "$($companion.Address)/api/v1/workspace/select" "{`"projectId`":`"$('f'*32)`"}" -WithOrigin
    if ($unknownProject.StatusCode -ne 400 -or $unknownProject.Body -notmatch 'target-refused') { Fail 'Untrusted project ID was not refused.' }

    $selection = Invoke-Post $client "$($companion.Address)/api/v1/workspace/select" "{`"projectId`":`"$secondProject`"}" -WithOrigin
    if ($selection.StatusCode -ne 200 -or -not (Test-Json -Json $selection.Body -SchemaFile (Join-Path $packageRoot 'integrations/web/V4.Guards.WebCompanion/contracts/workspace-select-response.schema.json') -ErrorAction SilentlyContinue)) {
        Fail "Valid Target selection failed: $($selection.Body)"
    }
    $switchedResponse = Invoke-Get $client "$($companion.Address)/api/v1/workspace"
    $switched = $switchedResponse.Body | ConvertFrom-Json -Depth 100
    if ($switched.activeProjectId -cne $secondProject -or @($switched.targets | Where-Object active)[0].targetRoot -cne $targetB) {
        Fail 'Target selection did not establish exactly the requested active Target.'
    }

    $evidenceBeforeRefusal = Hash-Tree $evidenceRoot
    $disabled = Invoke-Post $client "$($companion.Address)/api/v1/stages/run" '{"stage":"analysis","profile":"default","withDependencies":false}' -WithOrigin
    if ($disabled.StatusCode -ne 400 -or $disabled.Body -notmatch 'does not enable') { Fail 'Disabled Profile Stage was not refused before execution.' }
    if ((Hash-Tree $evidenceRoot) -cne $evidenceBeforeRefusal) { Fail 'Disabled Stage request wrote evidence.' }

    $valid = Invoke-Post $client "$($companion.Address)/api/v1/stages/run" '{"stage":"analysis","profile":"synthetic_profile","withDependencies":true}' -WithOrigin
    if ($valid.StatusCode -ne 200 -or -not (Test-Json -Json $valid.Body -SchemaFile (Join-Path $packageRoot 'integrations/web/V4.Guards.WebCompanion/contracts/stage-run-response.schema.json') -ErrorAction SilentlyContinue)) {
        Fail "Valid dependency-visible Stage run failed: $($valid.Body)"
    }
    else {
        $result = $valid.Body | ConvertFrom-Json -Depth 100
        if ($result.hostResult.roots.targetRoot -cne $targetB -or ($result.hostResult.executedStages -join ',') -cne 'bootstrap,analysis') {
            Fail 'Stage Runner did not use the active Target or explicit dependency chain.'
        }
    }

    $runRequest = New-JsonRequest ([Net.Http.HttpMethod]::Post) "$($companion.Address)/api/v1/stages/run" '{"stage":"analysis","profile":"synthetic_profile","withDependencies":false}' -WithOrigin
    try {
        $runTask = $client.SendAsync($runRequest)
        Start-Sleep -Milliseconds 100
        $switchDuringRun = Invoke-Post $client "$($companion.Address)/api/v1/workspace/select" "{`"projectId`":`"$firstProject`"}" -WithOrigin
        if ($switchDuringRun.StatusCode -ne 409 -or $switchDuringRun.Body -notmatch 'run-active') { Fail 'Target switching was not serialized against an active Stage run.' }
        $runResponse = $runTask.GetAwaiter().GetResult()
        try { if ([int]$runResponse.StatusCode -ne 200) { Fail "Serialization fixture Stage failed: HTTP $([int]$runResponse.StatusCode)" } }
        finally { $runResponse.Dispose() }
    }
    finally { $runRequest.Dispose() }

    $requests = [Collections.Generic.List[Net.Http.HttpRequestMessage]]::new()
    $tasks = [Collections.Generic.List[Threading.Tasks.Task[Net.Http.HttpResponseMessage]]]::new()
    try {
        foreach ($index in 1..6) {
            $request = New-JsonRequest ([Net.Http.HttpMethod]::Post) "$($companion.Address)/api/v1/stages/run" '{"stage":"analysis","profile":"synthetic_profile","withDependencies":false}' -WithOrigin
            $requests.Add($request)
            $tasks.Add($client.SendAsync($request))
        }
        [void][Threading.Tasks.Task]::WhenAll($tasks).GetAwaiter().GetResult()
        $codes = @($tasks | ForEach-Object { [int]$_.Result.StatusCode })
        if ($codes -notcontains 200 -or $codes -notcontains 409) { Fail "Concurrent Stage requests were not serialized: $($codes -join ',')" }
        foreach ($task in $tasks) { $task.Result.Dispose() }
    }
    finally { foreach ($request in $requests) { $request.Dispose() } }

    if ((Hash-Tree $packageRoot) -cne $packageBefore) { Fail 'PackageRoot changed during workspace and Stage flows.' }
    if ((Hash-Tree $targetA) -cne $targetABefore -or (Hash-Tree $targetB) -cne $targetBBefore) { Fail 'A TargetRoot changed during workspace and Stage flows.' }
    if (-not (Test-Path -LiteralPath (Join-Path $stateRoot 'state.json') -PathType Leaf)) { Fail 'Stage binding was not confined to StateRoot.' }
    if (@(Get-ChildItem -LiteralPath $evidenceRoot -Recurse -File -Force).Count -lt 1) { Fail 'Stage output was not confined to EvidenceRoot.' }

    $nestedTarget = Join-Path $targetA 'nested'
    New-Item -ItemType Directory -Path $nestedTarget -Force | Out-Null
    $overlap = [Diagnostics.Process]::new()
    $overlap.StartInfo = New-CompanionStart @($targetA,$nestedTarget)
    if (-not $overlap.Start()) { Fail 'Overlapping-Target Companion process did not start.' }
    elseif (-not $overlap.WaitForExit(15000)) { try { $overlap.Kill($true) } catch { }; Fail 'Overlapping Targets did not fail before listening.' }
    else {
        $errorText = $overlap.StandardError.ReadToEnd()
        if ($overlap.ExitCode -ne 11 -or $errorText -notmatch 'unsafe-path') { Fail "Overlapping trusted Targets were not refused: $errorText" }
    }
    $overlap.Dispose()
}
finally {
    if ($null -ne $client) { $client.Dispose() }
    if ($null -ne $companion -and -not $companion.Process.HasExited) {
        try { $companion.Process.Kill($true); [void]$companion.Process.WaitForExit(10000) } catch { }
        $companion.Process.Dispose()
    }
}

if ($failures.Count -gt 0) { throw "V4 P9.3 workspace and Stage Runner tests failed:`n - $($failures -join "`n - ")" }
Write-Host "V4 P9.3 workspace and Stage Runner tests passed on $([Runtime.InteropServices.RuntimeInformation]::OSDescription)."
