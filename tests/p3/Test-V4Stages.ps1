[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$packageRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $packageRoot '../../..'))
$buildRoot = Join-Path $packageRoot 'build'
$project = Join-Path $packageRoot 'core/host/V4.Guards.Host/V4.Guards.Host.csproj'
$artifactsRoot = Join-Path $repositoryRoot 'artifacts/guards/v4/p3a'
$runRoot = Join-Path $artifactsRoot 'fixture'
$schema = Join-Path $packageRoot 'core/contracts/stage-result.schema.json'
$failures = [Collections.Generic.List[string]]::new()

function Hash-Tree([string] $Root) {
    $items = [ordered]@{}
    Get-ChildItem -LiteralPath $Root -Recurse -File | Sort-Object FullName | ForEach-Object {
        $relative = [IO.Path]::GetRelativePath($Root, $_.FullName).Replace('\', '/')
        $items[$relative] = (Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName).Hash.ToLowerInvariant()
    }
    return ($items | ConvertTo-Json -Compress)
}

function New-Roots([string] $Name, [string] $Content = 'synthetic-ok', [switch] $NoInput) {
    $root = Join-Path $runRoot $Name
    $target = Join-Path $root 'target'; $state = Join-Path $root 'state'; $evidence = Join-Path $root 'evidence'
    foreach ($path in @($target,$state,$evidence)) { New-Item -ItemType Directory -Path $path -Force | Out-Null }
    if (-not $NoInput) { [IO.File]::WriteAllText((Join-Path $target 'input.txt'), "$Content`n", [Text.UTF8Encoding]::new($false)) }
    [IO.File]::WriteAllText((Join-Path $target 'Synthetic.csproj'), '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFramework>net10.0</TargetFramework></PropertyGroup></Project>', [Text.UTF8Encoding]::new($false))
    [pscustomobject]@{ Root = $root; Target = $target; State = $state; Evidence = $evidence; TargetHash = (Hash-Tree $target) }
}

function Invoke-Stage($Roots, [string] $Stage, [string] $Profile = 'synthetic_profile') {
    $dll = Join-Path $artifactsRoot 'bin/V4.Guards.Host/debug/v4-guards.dll'
    $arguments = @('stage','run','--stage',$Stage,'--package-root',$packageRoot,'--target-root',$Roots.Target,
        '--state-root',$Roots.State,'--evidence-root',$Roots.Evidence,'--profile',$Profile)
    $output = @(& dotnet $dll @arguments 2>&1)
    [pscustomobject]@{ Code = $LASTEXITCODE; Output = ($output -join "`n") }
}

function Assert-Run([string] $Name, $Roots, $Run, [int] $Code, [string] $Category) {
    if ($Run.Code -ne $Code) { $failures.Add("${Name}: expected exit $Code, got $($Run.Code): $($Run.Output)"); return $null }
    try { $result = $Run.Output | ConvertFrom-Json }
    catch { $failures.Add("${Name}: output is not JSON: $($Run.Output)"); return $null }
    if ($result.exitCategory -cne $Category) { $failures.Add("${Name}: expected category $Category, got $($result.exitCategory)") }
    if ($result.runId -notmatch '^[a-f0-9]{32}$') { $failures.Add("${Name}: run ID is invalid"); return $result }
    $state = Get-Content -Raw (Join-Path $Roots.State 'state.json') | ConvertFrom-Json
    $projectId = @($state.projectInstances)[0].id
    $resultPath = Join-Path $Roots.Evidence "projects/$projectId/runs/$($result.runId)/stage-result.json"
    if (-not (Test-Path -LiteralPath $resultPath -PathType Leaf)) { $failures.Add("${Name}: project-confined Stage result is missing"); return $result }
    if (-not (Test-Json -LiteralPath $resultPath -SchemaFile $schema -ErrorAction SilentlyContinue)) { $failures.Add("${Name}: Stage result does not satisfy stage-result.schema.json") }
    foreach ($file in Get-ChildItem -LiteralPath $Roots.Evidence -Recurse -File) {
        $relative = [IO.Path]::GetRelativePath($Roots.Evidence, $file.FullName).Replace('\','/')
        if (-not $relative.StartsWith("projects/$projectId/", [StringComparison]::Ordinal)) { $failures.Add("${Name}: evidence escaped the project claim: $relative") }
    }
    return $result
}

if (Test-Path -LiteralPath $runRoot) { Remove-Item -LiteralPath $runRoot -Recurse -Force }
New-Item -ItemType Directory -Path $runRoot -Force | Out-Null
$properties = @(
    '-p:ImportDirectoryBuildProps=false', '-p:ImportDirectoryBuildTargets=false', '-p:ImportDirectoryPackagesProps=false',
    '-p:ImportDirectorySolutionProps=false', '-p:ImportDirectorySolutionTargets=false',
    "-p:CustomBeforeMicrosoftCommonProps=$(Join-Path $buildRoot 'V4.Build.props')"
)
Push-Location $buildRoot
try {
    & dotnet restore $project --configfile (Join-Path $buildRoot 'NuGet.config') --artifacts-path $artifactsRoot -nologo @properties
    if ($LASTEXITCODE) { throw 'V4 P3A restore failed.' }
    & dotnet build $project --no-restore --artifacts-path $artifactsRoot -nologo @properties
    if ($LASTEXITCODE) { throw 'V4 P3A build failed.' }
} finally { Pop-Location }

$packageBefore = Hash-Tree $packageRoot
$direct = New-Roots 'direct'
foreach ($stage in @('bootstrap','analysis','pre','post')) {
    $result = Assert-Run "direct $stage" $direct (Invoke-Stage $direct $stage) 0 'success'
    $expectedModules = if ($stage -eq 'pre') { 2 } else { 1 }
    if ($null -ne $result -and ($result.stage -cne $stage -or $result.status -cne 'pass' -or @($result.moduleResults).Count -ne $expectedModules)) {
        $failures.Add("direct ${stage}: uniform result identity is invalid")
    }
}

$blocking = New-Roots 'blocking' 'synthetic-bad'
$blockingResult = Assert-Run 'blocking finding' $blocking (Invoke-Stage $blocking 'analysis') 16 'findings-blocking'
if ($null -ne $blockingResult -and ($blockingResult.status -cne 'fail' -or @($blockingResult.findings).Count -ne 1 -or $blockingResult.findings[0].ruleId -cne 'SYNTHETIC.INPUT')) {
    $failures.Add('blocking finding result is invalid')
}

$missing = New-Roots 'missing' -NoInput
$missingResult = Assert-Run 'missing prerequisite' $missing (Invoke-Stage $missing 'post') 15 'prerequisite-missing'
if ($null -ne $missingResult -and ($missingResult.status -cne 'error' -or @($missingResult.coverage)[0].matched -ne 0)) {
    $failures.Add('missing prerequisite result is invalid')
}

$default = New-Roots 'default' -NoInput
$defaultResult = Assert-Run 'disabled default Stage' $default (Invoke-Stage $default 'bootstrap' 'default') 0 'success'
if ($null -ne $defaultResult -and (@($defaultResult.moduleResults).Count -ne 0 -or @($defaultResult.findings).Count -ne 0)) {
    $failures.Add('default profile did not remain an empty deterministic Stage')
}

$invalid = Invoke-Stage $default 'unknown' 'default'
if ($invalid.Code -ne 10 -or $invalid.Output -notmatch '"exitCategory"\s*:\s*"invalid-input"') { $failures.Add("invalid Stage was not rejected structurally: $($invalid.Output)") }

foreach ($roots in @($direct,$blocking,$missing,$default)) {
    if ((Hash-Tree $roots.Target) -cne $roots.TargetHash) { $failures.Add("TargetRoot changed: $($roots.Root)") }
}
if ((Hash-Tree $packageRoot) -cne $packageBefore) { $failures.Add('Stage execution changed PackageRoot') }

if ($failures.Count -gt 0) { throw ($failures -join "`n") }
Write-Host 'V4 P3A Stage tests passed: four direct Stages, schema-valid project evidence, blocking findings, missing prerequisites and empty default profile.'
