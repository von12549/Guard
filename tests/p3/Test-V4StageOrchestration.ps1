[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$packageRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $packageRoot '../../..'))
$buildRoot = Join-Path $packageRoot 'build'
$project = Join-Path $packageRoot 'core/host/V4.Guards.Host/V4.Guards.Host.csproj'
$artifactsRoot = Join-Path $repositoryRoot 'artifacts/guards/v4/p3b'
$runRoot = Join-Path $artifactsRoot 'fixture'
$schema = Join-Path $packageRoot 'core/contracts/stage-result.schema.json'
$stages = @('bootstrap','analysis','pre','post')
$failures = [Collections.Generic.List[string]]::new()

function Hash-Tree([string] $Root) {
    $items = [ordered]@{}
    Get-ChildItem -LiteralPath $Root -Recurse -File | Sort-Object FullName | ForEach-Object {
        $items[[IO.Path]::GetRelativePath($Root, $_.FullName).Replace('\','/')] = (Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName).Hash.ToLowerInvariant()
    }
    $items | ConvertTo-Json -Compress
}

function New-Roots([string] $Name, [string] $Content = 'synthetic-ok', [switch] $NoInput) {
    $root = Join-Path $runRoot $Name
    $target = Join-Path $root 'target'; $state = Join-Path $root 'state'; $evidence = Join-Path $root 'evidence'
    foreach ($path in @($target,$state,$evidence)) { New-Item -ItemType Directory -Path $path -Force | Out-Null }
    if (-not $NoInput) { [IO.File]::WriteAllText((Join-Path $target 'input.txt'), "$Content`n", [Text.UTF8Encoding]::new($false)) }
    [IO.File]::WriteAllText((Join-Path $target 'Synthetic.csproj'), '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFramework>net10.0</TargetFramework></PropertyGroup></Project>', [Text.UTF8Encoding]::new($false))
    [pscustomobject]@{ Root=$root; Target=$target; State=$state; Evidence=$evidence; TargetHash=(Hash-Tree $target) }
}

function Invoke-Host([string[]] $Arguments) {
    $dll = Join-Path $artifactsRoot 'bin/V4.Guards.Host/debug/v4-guards.dll'
    $output = @(& dotnet $dll @Arguments 2>&1)
    [pscustomobject]@{ Code=$LASTEXITCODE; Output=($output -join "`n") }
}

function Invoke-Stage($Roots, [string] $Stage, [switch] $WithDependencies) {
    $arguments = @('stage','run','--stage',$Stage,'--package-root',$packageRoot,'--target-root',$Roots.Target,
        '--state-root',$Roots.State,'--evidence-root',$Roots.Evidence,'--profile','synthetic_profile')
    if ($WithDependencies) { $arguments += '--with-dependencies' }
    Invoke-Host $arguments
}

function Assert-Stage([string] $Name, $Roots, $Run, [int] $Code, [string] $Category, [string[]] $Executed) {
    if ($Run.Code -ne $Code) { $failures.Add("${Name}: expected exit $Code, got $($Run.Code): $($Run.Output)"); return $null }
    try { $result = $Run.Output | ConvertFrom-Json }
    catch { $failures.Add("${Name}: output is not JSON: $($Run.Output)"); return $null }
    if ($result.exitCategory -cne $Category) { $failures.Add("${Name}: expected $Category, got $($result.exitCategory)") }
    if ((@($result.executedStages) -join ',') -cne ($Executed -join ',')) { $failures.Add("${Name}: executed Stages [$(@($result.executedStages) -join ',')] do not match [$($Executed -join ',')]") }
    $state = Get-Content -Raw (Join-Path $Roots.State 'state.json') | ConvertFrom-Json
    $projectId = @($state.projectInstances)[0].id
    $resultPath = Join-Path $Roots.Evidence "projects/$projectId/runs/$($result.runId)/stage-result.json"
    if (-not (Test-Json -LiteralPath $resultPath -SchemaFile $schema -ErrorAction SilentlyContinue)) { $failures.Add("${Name}: result is missing or violates stage-result.schema.json") }
    return $result
}

function Reset-Project($Roots) {
    $state = Get-Content -Raw (Join-Path $Roots.State 'state.json') | ConvertFrom-Json
    $projectId = @($state.projectInstances)[0].id
    $previewRun = Invoke-Host @('reset','project','--mode','preview','--package-root',$packageRoot,'--state-root',$Roots.State,'--evidence-root',$Roots.Evidence,'--project',$projectId)
    if ($previewRun.Code -ne 0) { $failures.Add("reset preview failed: $($previewRun.Output)"); return $projectId }
    $preview = $previewRun.Output | ConvertFrom-Json
    $applyRun = Invoke-Host @('reset','project','--mode','apply','--package-root',$packageRoot,'--state-root',$Roots.State,'--evidence-root',$Roots.Evidence,'--project',$projectId,'--accept-manifest-hash',$preview.manifestHash)
    if ($applyRun.Code -ne 0) { $failures.Add("reset apply failed: $($applyRun.Output)"); return $projectId }
    if ((Test-Path -LiteralPath (Join-Path $Roots.State "projects/$projectId")) -or (Test-Path -LiteralPath (Join-Path $Roots.Evidence "projects/$projectId"))) {
        $failures.Add("accepted reset left project claims: $projectId")
    }
    return $projectId
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
    if ($LASTEXITCODE) { throw 'V4 P3B restore failed.' }
    & dotnet build $project --no-restore --artifacts-path $artifactsRoot -nologo @properties
    if ($LASTEXITCODE) { throw 'V4 P3B build failed.' }
} finally { Pop-Location }

$packageBefore = Hash-Tree $packageRoot
$visibility = New-Roots 'visibility'
$directPost = Assert-Stage 'direct Post visibility' $visibility (Invoke-Stage $visibility 'post') 0 'success' @('post')
$dependentPost = Assert-Stage 'dependent Post visibility' $visibility (Invoke-Stage $visibility 'post' -WithDependencies) 0 'success' $stages
if ($null -ne $directPost -and @($directPost.moduleResults).Count -ne 1) { $failures.Add('direct Post ran hidden earlier modules') }
if ($null -ne $dependentPost -and @($dependentPost.moduleResults).Count -ne 5) { $failures.Add('dependent Post did not expose all selected module executions') }

$dependencyFailure = New-Roots 'dependency-failure' 'synthetic-bad'
$stopped = Assert-Stage 'dependency failure stop' $dependencyFailure (Invoke-Stage $dependencyFailure 'post' -WithDependencies) 16 'findings-blocking' @('bootstrap')
if ($null -ne $stopped -and @($stopped.moduleResults).Count -ne 1) { $failures.Add('orchestration continued after a blocking dependency') }

$blocking = New-Roots 'all-blocking' 'synthetic-bad'
$missing = New-Roots 'all-missing' -NoInput
$cleanRoots = @()
foreach ($stage in $stages) {
    [void](Assert-Stage "direct blocking $stage" $blocking (Invoke-Stage $blocking $stage) 16 'findings-blocking' @($stage))
    [void](Assert-Stage "direct missing $stage" $missing (Invoke-Stage $missing $stage) 15 'prerequisite-missing' @($stage))

    $clean = New-Roots "clean-reset-$stage"
    $cleanRoots += $clean
    [void](Assert-Stage "pre-reset $stage" $clean (Invoke-Stage $clean $stage) 0 'success' @($stage))
    $projectId = Reset-Project $clean
    [void](Assert-Stage "post-reset $stage" $clean (Invoke-Stage $clean $stage) 0 'success' @($stage))
    $rebound = Get-Content -Raw (Join-Path $clean.State 'state.json') | ConvertFrom-Json
    if (@($rebound.projectInstances)[0].id -cne $projectId) { $failures.Add("$stage changed deterministic project identity after reset") }
}

$duplicateFlag = Invoke-Host @('stage','run','--stage','post','--package-root',$packageRoot,'--target-root',$visibility.Target,
    '--state-root',$visibility.State,'--evidence-root',$visibility.Evidence,'--profile','synthetic_profile','--with-dependencies','--with-dependencies')
if ($duplicateFlag.Code -ne 10 -or $duplicateFlag.Output -notmatch '"exitCategory"\s*:\s*"invalid-input"') { $failures.Add('duplicate dependency switch was not rejected') }

foreach ($roots in @($visibility,$dependencyFailure,$blocking,$missing) + $cleanRoots) {
    if ((Hash-Tree $roots.Target) -cne $roots.TargetHash) { $failures.Add("TargetRoot changed: $($roots.Root)") }
}
if ((Hash-Tree $packageRoot) -cne $packageBefore) { $failures.Add('Stage orchestration changed PackageRoot') }

if ($failures.Count -gt 0) { throw ($failures -join "`n") }
Write-Host 'V4 P3B orchestration tests passed: explicit dependency visibility, fail-fast order, four-Stage negatives and clean-reset replay.'
