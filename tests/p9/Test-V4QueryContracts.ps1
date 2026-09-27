[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$packageRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $packageRoot '../../..'))
$buildRoot = Join-Path $packageRoot 'build'
$hostProject = Join-Path $packageRoot 'core/host/V4.Guards.Host/V4.Guards.Host.csproj'
$artifactsRoot = Join-Path $repositoryRoot 'artifacts/guards/v4/p9b'
$hostOutput = Join-Path $artifactsRoot 'host'
$fixtureRoot = Join-Path $artifactsRoot 'fixture'
$targetRoot = Join-Path $fixtureRoot 'target'
$stateRoot = Join-Path $fixtureRoot 'state'
$evidenceRoot = Join-Path $fixtureRoot 'evidence'
$planRoot = Join-Path $targetRoot 'plans'
$failures = [Collections.Generic.List[string]]::new()

function Fail([string] $Message) { $script:failures.Add($Message) }

function Hash-Tree([string] $Root) {
    $items = [ordered]@{}
    foreach ($file in @(Get-ChildItem -LiteralPath $Root -Recurse -File -Force | Sort-Object FullName)) {
        $relative = [IO.Path]::GetRelativePath($Root, $file.FullName).Replace('\','/')
        $items[$relative] = (Get-FileHash -Algorithm SHA256 -LiteralPath $file.FullName).Hash.ToLowerInvariant()
    }
    $items | ConvertTo-Json -Compress
}

function Build-Host() {
    $properties = @(
        '-p:ImportDirectoryBuildProps=false', '-p:ImportDirectoryBuildTargets=false', '-p:ImportDirectoryPackagesProps=false',
        '-p:ImportDirectorySolutionProps=false', '-p:ImportDirectorySolutionTargets=false',
        "-p:CustomBeforeMicrosoftCommonProps=$(Join-Path $buildRoot 'V4.Build.props')"
    )
    Push-Location $buildRoot
    try {
        & dotnet restore $hostProject --configfile (Join-Path $buildRoot 'NuGet.config') --artifacts-path $artifactsRoot -nologo @properties
        if ($LASTEXITCODE) { throw 'Host restore failed.' }
        & dotnet build $hostProject --no-restore --artifacts-path $artifactsRoot -o $hostOutput -nologo @properties
        if ($LASTEXITCODE) { throw 'Host build failed.' }
    }
    finally { Pop-Location }
}

function Invoke-Host([string[]] $HostArgs) {
    $lines = @(& dotnet (Join-Path $hostOutput 'v4-guards.dll') @HostArgs 2>&1 | ForEach-Object { $_.ToString() })
    [pscustomobject]@{ ExitCode = $LASTEXITCODE; Text = ($lines -join "`n") }
}

function Assert-Query([string] $Label, [string] $Schema, [string[]] $HostArgs) {
    $result = Invoke-Host $HostArgs
    if ($result.ExitCode -ne 0) {
        Fail "$Label failed with exit $($result.ExitCode): $($result.Text)"
        return $null
    }
    if (-not (Test-Json -Json $result.Text -SchemaFile (Join-Path $packageRoot "core/contracts/$Schema.schema.json") -ErrorAction SilentlyContinue)) {
        Fail "$Label violates $Schema.schema.json."
        return $null
    }
    try { $result.Text | ConvertFrom-Json -Depth 100 }
    catch { Fail "$Label output is not JSON: $($_.Exception.Message)"; $null }
}

function Assert-Exit([string] $Label, [int] $Code, [string] $Category, [string[]] $HostArgs) {
    $result = Invoke-Host $HostArgs
    if ($result.ExitCode -ne $Code -or $result.Text -notmatch [Regex]::Escape($Category)) {
        Fail "$Label returned exit $($result.ExitCode), expected $Code/${Category}: $($result.Text)"
    }
}

if (Test-Path -LiteralPath $artifactsRoot) { Remove-Item -LiteralPath $artifactsRoot -Recurse -Force }
foreach ($path in @($targetRoot, $stateRoot, $evidenceRoot, $planRoot)) {
    New-Item -ItemType Directory -Path $path -Force | Out-Null
}
[IO.File]::WriteAllText((Join-Path $targetRoot 'input.txt'), "synthetic-ok`n", [Text.UTF8Encoding]::new($false))

$native = [ordered]@{
    formatVersion=1; id='20260922-native-query-fixture'; title='Native query fixture'; goal='Prove native Plan catalog projection'
    acceptanceCriteria=@('The fixture is catalogued'); plannedPaths=@('src/native.txt'); areas=@('contracts'); risks=@()
    decisions=@('V4-AD-013'); validationCommands=@('query-test'); dependencies=@(); boundaries=@()
}
$historical = [ordered]@{
    formatVersion=1; id='20260922-historical-query-fixture'; title='Historical query fixture'; goal='Prove historical compatibility projection'
    acceptanceCriteria=@('The fixture remains read-only'); plannedPaths=@('src/historical.txt'); areaIds=@('GuardDocs'); ruleIds=@()
    validationCommands=@('query-test'); decisionPaths=@()
}
[IO.File]::WriteAllText((Join-Path $planRoot '20260922-native-query-fixture.plan.json'), ($native | ConvertTo-Json -Depth 20) + "`n", [Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $planRoot '20260922-native-query-fixture.md'), "# Native query fixture`n", [Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $planRoot '20260922-historical-query-fixture.plan.json'), ($historical | ConvertTo-Json -Depth 20) + "`n", [Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $planRoot '20260922-historical-query-fixture.md'), "# Historical query fixture`n", [Text.UTF8Encoding]::new($false))

Build-Host

$commonProject = @('query','project','--package-root',$packageRoot,'--target-root',$targetRoot,'--state-root',$stateRoot,'--evidence-root',$evidenceRoot)
$packageBefore = Hash-Tree $packageRoot
$targetBefore = Hash-Tree $targetRoot
$stateBefore = Hash-Tree $stateRoot
$evidenceBefore = Hash-Tree $evidenceRoot

$projectMissing = Assert-Query 'unbound project query' 'project-query' $commonProject
if ($null -ne $projectMissing -and ($projectMissing.project.bound -or $projectMissing.project.stateDocumentStatus -cne 'missing' -or $null -ne $projectMissing.project.profileId)) {
    Fail 'Unbound project projection is not explicit about missing state.'
}
$profiles = Assert-Query 'profile catalog query' 'profile-catalog-query' @('query','profiles','--package-root',$packageRoot)
if ($null -ne $profiles -and (@($profiles.profiles).Count -ne 2 -or @($profiles.profiles.id) -notcontains 'synthetic_profile')) {
    Fail 'Profile catalog does not expose the two package-owned profiles.'
}
$doctor = Assert-Query 'prerequisite query' 'prerequisite-query' @('query','doctor','--package-root',$packageRoot,'--profile','synthetic_profile')
if ($null -ne $doctor -and ($doctor.report.profile -cne 'synthetic_profile' -or $doctor.report.status -cne 'pass')) {
    Fail 'Doctor query did not preserve the package prerequisite report.'
}
$plans = Assert-Query 'Plan catalog query' 'plan-catalog-query' @('query','plans','--package-root',$packageRoot,'--target-root',$targetRoot,'--plan-root','plans')
if ($null -ne $plans) {
    $nativeView = @($plans.plans | Where-Object id -eq '20260922-native-query-fixture')
    $historicalView = @($plans.plans | Where-Object id -eq '20260922-historical-query-fixture')
    if ($nativeView.Count -ne 1 -or $nativeView[0].kind -cne 'v4-native' -or $nativeView[0].presentationMode -cne 'native-contract') {
        Fail 'V4-native Plan classification is incorrect.'
    }
    if ($historicalView.Count -ne 1 -or $historicalView[0].kind -cne 'v3-historical' -or
        $historicalView[0].presentationMode -cne 'historical-read-only' -or $historicalView[0].validation -cne 'v3-compatibility-view') {
        Fail 'V3 historical Plan classification is not an explicit read-only compatibility view.'
    }
}

if ((Hash-Tree $packageRoot) -cne $packageBefore -or (Hash-Tree $targetRoot) -cne $targetBefore -or
    (Hash-Tree $stateRoot) -cne $stateBefore -or (Hash-Tree $evidenceRoot) -cne $evidenceBefore) {
    Fail 'Initial query set changed a V4 root.'
}

$stage = Invoke-Host @('stage','run','--stage','analysis','--package-root',$packageRoot,'--target-root',$targetRoot,'--state-root',$stateRoot,'--evidence-root',$evidenceRoot,'--profile','synthetic_profile')
if ($stage.ExitCode -ne 0) { throw "Fixture Stage run failed: $($stage.Text)" }
$stageResult = $stage.Text | ConvertFrom-Json -Depth 100
$state = Get-Content -Raw -LiteralPath (Join-Path $stateRoot 'state.json') | ConvertFrom-Json -Depth 100
$projectId = [string]$state.projectInstances[0].id
$runId = [string]$stageResult.runId

$packageBound = Hash-Tree $packageRoot
$targetBound = Hash-Tree $targetRoot
$stateBound = Hash-Tree $stateRoot
$evidenceBound = Hash-Tree $evidenceRoot

$project = Assert-Query 'bound project query' 'project-query' $commonProject
if ($null -ne $project -and (-not $project.project.bound -or $project.project.projectId -cne $projectId -or $project.project.profileId -cne 'synthetic_profile')) {
    Fail 'Bound project projection does not match Host state authority.'
}
$runs = Assert-Query 'run catalog query' 'run-catalog-query' @('query','runs','--package-root',$packageRoot,'--state-root',$stateRoot,'--evidence-root',$evidenceRoot,'--project',$projectId)
if ($null -ne $runs -and (@($runs.runs).Count -ne 1 -or $runs.runs[0].runId -cne $runId -or $runs.runs[0].resultSha256 -notmatch '^[a-f0-9]{64}$')) {
    Fail 'Run catalog projection does not match Stage evidence.'
}
$evidence = Assert-Query 'evidence detail query' 'evidence-query' @('query','evidence','--package-root',$packageRoot,'--state-root',$stateRoot,'--evidence-root',$evidenceRoot,'--project',$projectId,'--run',$runId)
if ($null -ne $evidence -and ($evidence.stageResult.runId -cne $runId -or @($evidence.files).Count -lt 1 -or
    @($evidence.files | Where-Object kind -eq 'stage-result').Count -ne 1)) {
    Fail 'Evidence projection does not preserve the validated Stage result and file catalog.'
}

Assert-Exit 'mutable root overlap' 11 'unsafe-path' @('query','project','--package-root',$packageRoot,'--target-root',$targetRoot,'--state-root',$targetRoot,'--evidence-root',$evidenceRoot)
Assert-Exit 'run traversal' 10 'invalid-input' @('query','evidence','--package-root',$packageRoot,'--state-root',$stateRoot,'--evidence-root',$evidenceRoot,'--project',$projectId,'--run','../escape')
Assert-Exit 'Plan root traversal' 11 'unsafe-path' @('query','plans','--package-root',$packageRoot,'--target-root',$targetRoot,'--plan-root','../plans')

$tamperedEvidence = Join-Path $fixtureRoot 'tampered-evidence'
Copy-Item -LiteralPath $evidenceRoot -Destination $tamperedEvidence -Recurse
$tamperedResultPath = Join-Path $tamperedEvidence "projects/$projectId/runs/$runId/stage-result.json"
$tamperedResult = Get-Content -Raw -LiteralPath $tamperedResultPath | ConvertFrom-Json -AsHashtable -Depth 100
$tamperedResult['unexpected'] = $true
[IO.File]::WriteAllText($tamperedResultPath, ($tamperedResult | ConvertTo-Json -Depth 100) + "`n", [Text.UTF8Encoding]::new($false))
Assert-Exit 'tampered Stage result' 12 'integrity-failure' @('query','runs','--package-root',$packageRoot,'--state-root',$stateRoot,'--evidence-root',$tamperedEvidence,'--project',$projectId)

if ((Hash-Tree $packageRoot) -cne $packageBound -or (Hash-Tree $targetRoot) -cne $targetBound -or
    (Hash-Tree $stateRoot) -cne $stateBound -or (Hash-Tree $evidenceRoot) -cne $evidenceBound) {
    Fail 'Read/query operations changed PackageRoot, TargetRoot, StateRoot or EvidenceRoot.'
}

if ($failures.Count -gt 0) { throw "V4 P9.2 query contract tests failed:`n - $($failures -join "`n - ")" }
Write-Host "V4 P9.2 query contract tests passed on $([Runtime.InteropServices.RuntimeInformation]::OSDescription)."
