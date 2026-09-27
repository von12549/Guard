[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$packageRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $packageRoot '../../..'))
$buildRoot = Join-Path $packageRoot 'build'
$hostProject = Join-Path $packageRoot 'core/host/V4.Guards.Host/V4.Guards.Host.csproj'
$companionProject = Join-Path $packageRoot 'integrations/web/V4.Guards.WebCompanion/V4.Guards.WebCompanion.csproj'
$artifactsRoot = Join-Path $repositoryRoot 'artifacts/guards/v4/p9d'
$hostOutput = Join-Path $artifactsRoot 'host'
$companionOutput = Join-Path $artifactsRoot 'companion'
$fixtureRoot = Join-Path $artifactsRoot 'fixture'
$targetRoot = Join-Path $fixtureRoot 'target'
$planRoot = Join-Path $targetRoot 'plans'
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

function New-CompanionStart([string] $ConfiguredPlanRoot = 'plans') {
    $dotnet = (Get-Command dotnet -ErrorAction Stop).Source
    $start = [Diagnostics.ProcessStartInfo]::new($dotnet)
    $start.UseShellExecute = $false
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.CreateNoWindow = $true
    $start.WorkingDirectory = $companionOutput
    foreach ($argument in @(
        (Join-Path $companionOutput 'v4-web-companion.dll'),
        '--package-root', $packageRoot, '--target-root', $targetRoot,
        '--state-root', $stateRoot, '--evidence-root', $evidenceRoot,
        '--plan-root', $ConfiguredPlanRoot,
        '--host', (Join-Path $hostOutput 'v4-guards.dll'), '--port', '0'
    )) { [void]$start.ArgumentList.Add($argument) }
    $start
}

function Start-Companion() {
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = New-CompanionStart
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

function Invoke-Post([Net.Http.HttpClient] $HttpClient, [string] $Url, [string] $Json) {
    $request = [Net.Http.HttpRequestMessage]::new([Net.Http.HttpMethod]::Post, $Url)
    [void]$request.Headers.TryAddWithoutValidation('Origin', ([Uri]$Url).GetLeftPart([UriPartial]::Authority))
    $request.Content = [Net.Http.StringContent]::new($Json, [Text.Encoding]::UTF8, 'application/json')
    try {
        $response = $HttpClient.Send($request)
        try { [pscustomobject]@{ StatusCode=[int]$response.StatusCode; Body=$response.Content.ReadAsStringAsync().GetAwaiter().GetResult() } }
        finally { $response.Dispose() }
    }
    finally { $request.Dispose() }
}

if (Test-Path -LiteralPath $artifactsRoot) { Remove-Item -LiteralPath $artifactsRoot -Recurse -Force }
foreach ($path in @($targetRoot,$planRoot,$stateRoot,$evidenceRoot)) { New-Item -ItemType Directory -Path $path -Force | Out-Null }
[IO.File]::WriteAllText((Join-Path $targetRoot 'input.txt'), "synthetic-ok`n", [Text.UTF8Encoding]::new($false))

$native = [ordered]@{
    formatVersion=1; id='20260922-native-view-fixture'; title='Native evidence view'; goal='Prove native Plan presentation'
    acceptanceCriteria=@('The pair is read only'); plannedPaths=@('src/native.txt'); areas=@('contracts'); risks=@()
    decisions=@('V4-AD-013'); validationCommands=@('view-test'); dependencies=@(); boundaries=@()
}
$historical = [ordered]@{
    formatVersion=1; id='20260922-historical-view-fixture'; title='Historical evidence view'; goal='Prove historical presentation'
    acceptanceCriteria=@('The pair stays historical'); plannedPaths=@('src/historical.txt'); areaIds=@('GuardDocs'); ruleIds=@()
    validationCommands=@('view-test'); decisionPaths=@()
}
$nativeMarkdown = @'
# Native evidence view

- Safe list item

```text
<literal-code>
```
'@ + "`n"
$historicalMarkdown = "# Historical evidence view`n`n<img src=x onerror=alert(1)>`n`n[unsafe](javascript:alert(1))`n"
[IO.File]::WriteAllText((Join-Path $planRoot '20260922-native-view-fixture.plan.json'), ($native | ConvertTo-Json -Depth 20) + "`n", [Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $planRoot '20260922-native-view-fixture.md'), $nativeMarkdown, [Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $planRoot '20260922-historical-view-fixture.plan.json'), ($historical | ConvertTo-Json -Depth 20) + "`n", [Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $planRoot '20260922-historical-view-fixture.md'), $historicalMarkdown, [Text.UTF8Encoding]::new($false))

try {
    Build-Project $hostProject $hostOutput
    Build-Project $companionProject $companionOutput

    $detailSchema = Join-Path $packageRoot 'integrations/web/V4.Guards.WebCompanion/contracts/plan-detail.schema.json'
    try { Get-Content -Raw -LiteralPath $detailSchema | ConvertFrom-Json | Out-Null }
    catch { throw "Plan detail schema is invalid JSON: $($_.Exception.Message)" }
    $appSource = Get-Content -Raw -LiteralPath (Join-Path $packageRoot 'integrations/web/V4.Guards.WebCompanion/wwwroot/app.js')
    if ($appSource -match '(?i)innerHTML|outerHTML|insertAdjacentHTML|document\.write') { Fail 'The UI contains an HTML-string execution sink.' }
    if ($appSource -notmatch 'textContent' -or $appSource -notmatch 'renderMarkdown') { Fail 'The text-only Markdown renderer is missing.' }

    $packageBefore = Hash-Tree $packageRoot
    $targetBefore = Hash-Tree $targetRoot
    $companion = Start-Companion
    $handler = [Net.Http.HttpClientHandler]::new()
    $handler.CookieContainer = [Net.CookieContainer]::new()
    $client = [Net.Http.HttpClient]::new($handler)

    $anonymous = [Net.Http.HttpClient]::new()
    try {
        foreach ($path in @('/api/v1/runs','/api/v1/evidence/00000000000000000000000000000000','/api/v1/plans','/api/v1/plans/20260922-native-view-fixture')) {
            if ((Invoke-Get $anonymous "$($companion.Address)$path").StatusCode -ne 403) { Fail "Read endpoint without session was not refused: $path" }
        }
    }
    finally { $anonymous.Dispose() }

    $sessionResponse = Invoke-Get $client "$($companion.Address)/api/v1/session"
    if ($sessionResponse.StatusCode -ne 200 -or -not (Test-Json -Json $sessionResponse.Body -SchemaFile (Join-Path $packageRoot 'integrations/web/V4.Guards.WebCompanion/contracts/session.schema.json') -ErrorAction SilentlyContinue)) {
        Fail "Session projection is invalid: $($sessionResponse.Body)"
    }
    else {
        $session = $sessionResponse.Body | ConvertFrom-Json
        if (($session.allowedQueries -join ',') -cne 'query.runs,query.evidence,query.plans') { Fail 'Session did not declare the read-only query capabilities.' }
    }

    $plansResponse = Invoke-Get $client "$($companion.Address)/api/v1/plans"
    if ($plansResponse.StatusCode -ne 200 -or -not (Test-Json -Json $plansResponse.Body -SchemaFile (Join-Path $packageRoot 'core/contracts/plan-catalog-query.schema.json') -ErrorAction SilentlyContinue)) {
        throw "Plan catalog projection is invalid: $($plansResponse.Body)"
    }
    $plans = $plansResponse.Body | ConvertFrom-Json -Depth 100
    $nativeEntry = @($plans.plans | Where-Object id -eq '20260922-native-view-fixture')
    $historicalEntry = @($plans.plans | Where-Object id -eq '20260922-historical-view-fixture')
    if ($nativeEntry.Count -ne 1 -or $nativeEntry[0].kind -cne 'v4-native' -or $nativeEntry[0].presentationMode -cne 'native-contract') { Fail 'Native Plan classification changed.' }
    if ($historicalEntry.Count -ne 1 -or $historicalEntry[0].kind -cne 'v3-historical' -or $historicalEntry[0].presentationMode -cne 'historical-read-only') { Fail 'Historical Plan classification changed.' }

    foreach ($id in @('20260922-native-view-fixture','20260922-historical-view-fixture')) {
        $detailResponse = Invoke-Get $client "$($companion.Address)/api/v1/plans/$id"
        if ($detailResponse.StatusCode -ne 200 -or -not (Test-Json -Json $detailResponse.Body -SchemaFile $detailSchema -ErrorAction SilentlyContinue)) {
            Fail "Plan detail is invalid for ${id}: $($detailResponse.Body)"
            continue
        }
        $detail = $detailResponse.Body | ConvertFrom-Json -Depth 100
        if ($detail.document.id -cne $id) { Fail "Plan detail JSON identity changed for $id." }
        $entry = @($plans.plans | Where-Object id -eq $id)[0]
        if ((Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $targetRoot $entry.jsonPath)).Hash.ToLowerInvariant() -cne $detail.plan.jsonSha256 -or
            (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $targetRoot $entry.markdownPath)).Hash.ToLowerInvariant() -cne $detail.plan.markdownSha256) {
            Fail "Plan detail hashes do not match returned bytes for $id."
        }
    }
    $historicalDetail = (Invoke-Get $client "$($companion.Address)/api/v1/plans/20260922-historical-view-fixture").Body | ConvertFrom-Json -Depth 100
    if ($historicalDetail.markdown -cnotmatch '<img src=x onerror=alert\(1\)>' -or $historicalDetail.markdown -cnotmatch '\[unsafe\]\(javascript:') {
        Fail 'Plan Markdown was altered instead of transported as inert text.'
    }

    if ((Invoke-Get $client "$($companion.Address)/api/v1/plans/not-a-plan").StatusCode -ne 400) { Fail 'Invalid Plan ID was not refused.' }
    if ((Invoke-Get $client "$($companion.Address)/api/v1/plans/20260922-unknown-plan").StatusCode -ne 404) { Fail 'Unknown valid Plan ID was not refused.' }
    if ((Invoke-Get $client "$($companion.Address)/api/v1/evidence/not-a-run").StatusCode -ne 400) { Fail 'Invalid Run ID was not refused.' }

    $stageResponse = Invoke-Post $client "$($companion.Address)/api/v1/stages/run" '{"stage":"analysis","profile":"synthetic_profile","withDependencies":true}'
    if ($stageResponse.StatusCode -ne 200) { throw "Stage fixture failed: $($stageResponse.Body)" }
    $stage = $stageResponse.Body | ConvertFrom-Json -Depth 100
    $runId = [string]$stage.hostResult.runId
    $projectId = [string]((Invoke-Get $client "$($companion.Address)/api/v1/workspace").Body | ConvertFrom-Json -Depth 100).activeProjectId

    $runsResponse = Invoke-Get $client "$($companion.Address)/api/v1/runs"
    if ($runsResponse.StatusCode -ne 200 -or -not (Test-Json -Json $runsResponse.Body -SchemaFile (Join-Path $packageRoot 'core/contracts/run-catalog-query.schema.json') -ErrorAction SilentlyContinue)) {
        Fail "Run catalog projection is invalid: $($runsResponse.Body)"
    }
    else {
        $runs = $runsResponse.Body | ConvertFrom-Json -Depth 100
        if ($runs.projectId -cne $projectId -or @($runs.runs | Where-Object runId -eq $runId).Count -ne 1) { Fail 'Run catalog did not preserve the active Target Host run.' }
    }

    $evidenceResponse = Invoke-Get $client "$($companion.Address)/api/v1/evidence/$runId"
    if ($evidenceResponse.StatusCode -ne 200 -or -not (Test-Json -Json $evidenceResponse.Body -SchemaFile (Join-Path $packageRoot 'core/contracts/evidence-query.schema.json') -ErrorAction SilentlyContinue)) {
        Fail "Evidence projection is invalid: $($evidenceResponse.Body)"
    }
    else {
        $evidence = $evidenceResponse.Body | ConvertFrom-Json -Depth 100
        if ($evidence.runId -cne $runId -or $evidence.stageResult.runId -cne $stage.hostResult.runId -or @($evidence.files).Count -lt 1) {
            Fail 'Evidence endpoint did not preserve the Host Stage result and file inventory.'
        }
    }

    if ((Hash-Tree $packageRoot) -cne $packageBefore) { Fail 'PackageRoot changed during evidence and Plan viewing.' }
    if ((Hash-Tree $targetRoot) -cne $targetBefore) { Fail 'TargetRoot changed during evidence and Plan viewing.' }

    $unsafe = [Diagnostics.Process]::new()
    $unsafe.StartInfo = New-CompanionStart '../plans'
    if (-not $unsafe.Start()) { Fail 'Unsafe Plan-root Companion process did not start.' }
    elseif (-not $unsafe.WaitForExit(15000)) { try { $unsafe.Kill($true) } catch { }; Fail 'Unsafe Plan root did not fail before listening.' }
    else {
        $errorText = $unsafe.StandardError.ReadToEnd()
        if ($unsafe.ExitCode -ne 11 -or $errorText -notmatch 'unsafe-path') { Fail "Unsafe Plan root was not refused: $errorText" }
    }
    $unsafe.Dispose()
}
finally {
    if ($null -ne $client) { $client.Dispose() }
    if ($null -ne $companion -and -not $companion.Process.HasExited) {
        try { $companion.Process.Kill($true); [void]$companion.Process.WaitForExit(10000) } catch { }
        $companion.Process.Dispose()
    }
}

if ($failures.Count -gt 0) { throw "V4 P9.4 evidence and Plan Center tests failed:`n - $($failures -join "`n - ")" }
Write-Host "V4 P9.4 evidence and Plan Center tests passed on $([Runtime.InteropServices.RuntimeInformation]::OSDescription)."
