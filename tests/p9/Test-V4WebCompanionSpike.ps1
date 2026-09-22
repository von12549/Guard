[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$packageRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $packageRoot '../../..'))
$buildRoot = Join-Path $packageRoot 'build'
$hostProject = Join-Path $packageRoot 'core/host/V4.Guards.Host/V4.Guards.Host.csproj'
$companionProject = Join-Path $packageRoot 'integrations/web/V4.Guards.WebCompanion/V4.Guards.WebCompanion.csproj'
$artifactsRoot = Join-Path $repositoryRoot 'artifacts/guards/v4/p9a'
$hostOutput = Join-Path $artifactsRoot 'host'
$companionOutput = Join-Path $artifactsRoot 'companion'
$runRoot = Join-Path $artifactsRoot 'fixture'
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
    ($items | ConvertTo-Json -Compress)
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

function New-ProcessStart([string] $StateRoot, [string] $EvidenceRoot) {
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
        '--target-root', (Join-Path $runRoot 'target'),
        '--state-root', $StateRoot,
        '--evidence-root', $EvidenceRoot,
        '--host', (Join-Path $hostOutput 'v4-guards.dll'),
        '--port', '0'
    )) { [void]$start.ArgumentList.Add($argument) }
    $start
}

function Start-Companion() {
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = New-ProcessStart (Join-Path $runRoot 'state') (Join-Path $runRoot 'evidence')
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
    if ($ready.status -cne 'ready' -or $ready.address -notmatch '^http://127\.0\.0\.1:[0-9]+$' -or $ready.allowedCommand -cne 'stage.run') {
        try { $process.Kill($true) } catch { }
        throw "Web Companion readiness is invalid: $line"
    }
    [pscustomobject]@{ Process = $process; Address = [string]$ready.address }
}

function Invoke-Post([Net.Http.HttpClient] $HttpClient, [string] $Address, [string] $Json, [switch] $WithOrigin) {
    $request = [Net.Http.HttpRequestMessage]::new([Net.Http.HttpMethod]::Post, "$Address/api/v1/stages/run")
    try {
        if ($WithOrigin) { [void]$request.Headers.TryAddWithoutValidation('Origin', $Address) }
        $request.Content = [Net.Http.StringContent]::new($Json, [Text.Encoding]::UTF8, 'application/json')
        $response = $HttpClient.Send($request)
        $body = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
        [pscustomobject]@{ StatusCode = [int]$response.StatusCode; Body = $body }
    }
    finally { $request.Dispose() }
}

if (Test-Path -LiteralPath $runRoot) { Remove-Item -LiteralPath $runRoot -Recurse -Force }
foreach ($path in @($runRoot, (Join-Path $runRoot 'target'), (Join-Path $runRoot 'state'), (Join-Path $runRoot 'evidence'))) {
    New-Item -ItemType Directory -Path $path -Force | Out-Null
}
[IO.File]::WriteAllText((Join-Path $runRoot 'target/input.txt'), "synthetic-ok`n", [Text.UTF8Encoding]::new($false))

try {
    Build-Project $hostProject $hostOutput
    Build-Project $companionProject $companionOutput

    foreach ($schema in @('session.schema.json','stage-run-request.schema.json','stage-run-response.schema.json')) {
        $schemaPath = Join-Path $packageRoot "integrations/web/V4.Guards.WebCompanion/contracts/$schema"
        try { Get-Content -Raw -LiteralPath $schemaPath | ConvertFrom-Json | Out-Null }
        catch { Fail "Spike schema is not valid JSON: ${schema}: $($_.Exception.Message)" }
    }

    $packageBefore = Hash-Tree $packageRoot
    $targetBefore = Hash-Tree (Join-Path $runRoot 'target')
    $companion = Start-Companion

    $handler = [Net.Http.HttpClientHandler]::new()
    $handler.CookieContainer = [Net.CookieContainer]::new()
    $client = [Net.Http.HttpClient]::new($handler)
    $pageResponse = $client.GetAsync($companion.Address).GetAwaiter().GetResult()
    $pageText = $pageResponse.Content.ReadAsStringAsync().GetAwaiter().GetResult()
    if ([int]$pageResponse.StatusCode -ne 200 -or $pageResponse.Content.Headers.ContentType.MediaType -cne 'text/html' -or
        $pageText -notmatch 'The V4 Host owns execution and the final verdict' -or
        $pageResponse.Headers.GetValues('Content-Security-Policy') -notcontains "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self'; connect-src 'self'; object-src 'none'; base-uri 'none'; frame-ancestors 'none'; form-action 'none'") {
        Fail 'Offline UI entry point or its security headers are invalid.'
    }
    foreach ($asset in @('app.js','styles.css')) {
        $assetResponse = $client.GetAsync("$($companion.Address)/$asset").GetAwaiter().GetResult()
        if ([int]$assetResponse.StatusCode -ne 200) { Fail "Offline UI asset was not served: $asset" }
    }

    $badHostRequest = [Net.Http.HttpRequestMessage]::new([Net.Http.HttpMethod]::Get, "$($companion.Address)/api/v1/session")
    try {
        $badHostRequest.Headers.Host = "localhost:$(([Uri]$companion.Address).Port)"
        $badHostResponse = $client.Send($badHostRequest)
        if ([int]$badHostResponse.StatusCode -ne 400) { Fail "Non-127.0.0.1 Host header was not refused: HTTP $([int]$badHostResponse.StatusCode)" }
    }
    finally { $badHostRequest.Dispose() }

    $sessionResponse = $client.GetAsync("$($companion.Address)/api/v1/session").GetAwaiter().GetResult()
    $sessionText = $sessionResponse.Content.ReadAsStringAsync().GetAwaiter().GetResult()
    if ([int]$sessionResponse.StatusCode -ne 200) { Fail "Session endpoint returned HTTP $([int]$sessionResponse.StatusCode): $sessionText" }
    elseif (-not (Test-Json -Json $sessionText -SchemaFile (Join-Path $packageRoot 'integrations/web/V4.Guards.WebCompanion/contracts/session.schema.json') -ErrorAction SilentlyContinue)) {
        Fail 'Session response violates session.schema.json.'
    }
    else {
        $session = $sessionText | ConvertFrom-Json
        if ($session.authority -cne 'v4-host' -or $session.allowedCommand -cne 'stage.run' -or @($session.roots).Count -ne 4) {
            Fail 'Session response weakens the Host or four-root identity.'
        }
    }

    $anonymous = [Net.Http.HttpClient]::new()
    try {
        $noSession = Invoke-Post $anonymous $companion.Address '{"stage":"analysis","profile":"synthetic_profile","withDependencies":false}' -WithOrigin
        if ($noSession.StatusCode -ne 403) { Fail "Mutation without session was not refused: HTTP $($noSession.StatusCode)" }
    }
    finally { $anonymous.Dispose() }

    $noOrigin = Invoke-Post $client $companion.Address '{"stage":"analysis","profile":"synthetic_profile","withDependencies":false}'
    if ($noOrigin.StatusCode -ne 403) { Fail "Mutation without Origin was not refused: HTTP $($noOrigin.StatusCode)" }
    $wrongOriginRequest = [Net.Http.HttpRequestMessage]::new([Net.Http.HttpMethod]::Post, "$($companion.Address)/api/v1/stages/run")
    try {
        [void]$wrongOriginRequest.Headers.TryAddWithoutValidation('Origin', 'http://example.invalid')
        $wrongOriginRequest.Content = [Net.Http.StringContent]::new('{"stage":"analysis","profile":"synthetic_profile","withDependencies":false}', [Text.Encoding]::UTF8, 'application/json')
        $wrongOriginResponse = $client.Send($wrongOriginRequest)
        if ([int]$wrongOriginResponse.StatusCode -ne 403) { Fail "Wrong Origin was not refused: HTTP $([int]$wrongOriginResponse.StatusCode)" }
    }
    finally { $wrongOriginRequest.Dispose() }

    $evidenceBefore = @(Get-ChildItem -LiteralPath (Join-Path $runRoot 'evidence') -Recurse -File -Force).Count
    $injection = Invoke-Post $client $companion.Address '{"stage":"analysis --help","profile":"synthetic_profile","withDependencies":false}' -WithOrigin
    if ($injection.StatusCode -ne 400 -or $injection.Body -notmatch 'command-refused') { Fail "Stage injection was not refused structurally: $($injection.Body)" }
    $unknown = Invoke-Post $client $companion.Address '{"stage":"analysis","profile":"synthetic_profile","withDependencies":false,"arguments":["--help"]}' -WithOrigin
    if ($unknown.StatusCode -ne 400 -or $unknown.Body -notmatch 'Unknown request field') { Fail "Raw argument field was not refused: $($unknown.Body)" }
    $profileInjection = Invoke-Post $client $companion.Address '{"stage":"analysis","profile":"../../profile","withDependencies":false}' -WithOrigin
    if ($profileInjection.StatusCode -ne 400 -or $profileInjection.Body -notmatch 'command-refused') { Fail "Profile injection was not refused: $($profileInjection.Body)" }
    $duplicate = Invoke-Post $client $companion.Address '{"stage":"analysis","stage":"post","profile":"synthetic_profile","withDependencies":false}' -WithOrigin
    if ($duplicate.StatusCode -ne 400 -or $duplicate.Body -notmatch 'Duplicate request field') { Fail "Duplicate field was not refused: $($duplicate.Body)" }
    $evidenceAfterRefusals = @(Get-ChildItem -LiteralPath (Join-Path $runRoot 'evidence') -Recurse -File -Force).Count
    if ($evidenceAfterRefusals -ne $evidenceBefore) { Fail 'A refused browser request reached the Host or wrote evidence.' }

    $valid = Invoke-Post $client $companion.Address '{"stage":"analysis","profile":"synthetic_profile","withDependencies":false}' -WithOrigin
    if ($valid.StatusCode -ne 200) { Fail "Valid Stage request returned HTTP $($valid.StatusCode): $($valid.Body)" }
    elseif (-not (Test-Json -Json $valid.Body -SchemaFile (Join-Path $packageRoot 'integrations/web/V4.Guards.WebCompanion/contracts/stage-run-response.schema.json') -ErrorAction SilentlyContinue)) {
        Fail 'Stage response violates stage-run-response.schema.json.'
    }
    else {
        $result = $valid.Body | ConvertFrom-Json
        if ($result.command -cne 'stage.run' -or $result.hostExitCode -ne 0 -or $result.hostResult.status -cne 'pass' -or
            $result.hostResult.exitCategory -cne 'success' -or $result.hostResult.profile.id -cne 'synthetic_profile') {
            Fail "Companion did not preserve the successful Host result: $($valid.Body)"
        }
        $stageResultFile = Get-ChildItem -LiteralPath (Join-Path $runRoot 'evidence') -Filter stage-result.json -Recurse -File |
            Where-Object { $_.FullName.Replace('\','/') -match "/runs/$($result.hostResult.runId)/stage-result\.json$" } |
            Select-Object -First 1
        $stageResultPath = if ($null -eq $stageResultFile) { $null } else { $stageResultFile.FullName }
        if ([string]::IsNullOrWhiteSpace($stageResultPath) -or -not (Test-Path -LiteralPath $stageResultPath -PathType Leaf) -or
            -not (Test-Json -LiteralPath $stageResultPath -SchemaFile (Join-Path $packageRoot 'core/contracts/stage-result.schema.json') -ErrorAction SilentlyContinue)) {
            Fail 'Host Stage evidence is missing or violates stage-result.schema.json.'
        }
    }

    if ((Hash-Tree $packageRoot) -cne $packageBefore) { Fail 'PackageRoot changed during the Companion flow.' }
    if ((Hash-Tree (Join-Path $runRoot 'target')) -cne $targetBefore) { Fail 'TargetRoot changed during the Companion flow.' }
    if (-not (Test-Path -LiteralPath (Join-Path $runRoot 'state/state.json') -PathType Leaf)) { Fail 'Host state was not confined to StateRoot.' }
    if (@(Get-ChildItem -LiteralPath (Join-Path $runRoot 'evidence') -Recurse -File -Force).Count -lt 1) { Fail 'Host evidence was not confined to EvidenceRoot.' }

    $overlap = [Diagnostics.Process]::new()
    $overlap.StartInfo = New-ProcessStart (Join-Path $runRoot 'target') (Join-Path $runRoot 'evidence')
    if (-not $overlap.Start()) { Fail 'Overlap-negative Companion process did not start.' }
    elseif (-not $overlap.WaitForExit(15000)) { try { $overlap.Kill($true) } catch { }; Fail 'Overlap-negative Companion did not fail before listening.' }
    else {
        $overlapError = $overlap.StandardError.ReadToEnd()
        if ($overlap.ExitCode -ne 11 -or $overlapError -notmatch 'unsafe-path') { Fail "Mutable-root overlap was not refused: $overlapError" }
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

if ($failures.Count -gt 0) { throw "V4 P9.1 Web Companion spike failed:`n - $($failures -join "`n - ")" }
Write-Host "V4 P9.1 Web Companion spike passed on $([Runtime.InteropServices.RuntimeInformation]::OSDescription)."
