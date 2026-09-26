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
$workspaceEvidenceSchema = Join-Path $packageRoot 'core/contracts/workspace-evidence.schema.json'
$targetCommit = (git -C $repositoryRoot rev-parse HEAD).Trim().ToLowerInvariant()
$failures = [Collections.Generic.List[string]]::new()

function Hash-Tree([string] $Root) {
    $items = [ordered]@{}
    Get-ChildItem -LiteralPath $Root -Recurse -File | Sort-Object FullName | ForEach-Object {
        $relative = [IO.Path]::GetRelativePath($Root, $_.FullName).Replace('\', '/')
        $items[$relative] = (Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName).Hash.ToLowerInvariant()
    }
    return ($items | ConvertTo-Json -Compress)
}

function Write-Json([string] $Path, $Value) {
    [IO.File]::WriteAllText($Path,(($Value | ConvertTo-Json -Depth 100).Replace("`r`n","`n") + "`n"),[Text.UTF8Encoding]::new($false))
}

function New-Roots([string] $Name, [string] $Content = 'synthetic-ok', [switch] $NoInput) {
    $root = Join-Path $runRoot $Name
    $target = Join-Path $root 'target'; $state = Join-Path $root 'state'; $evidence = Join-Path $root 'evidence'
    foreach ($path in @($target,$state,$evidence)) { New-Item -ItemType Directory -Path $path -Force | Out-Null }
    if (-not $NoInput) { [IO.File]::WriteAllText((Join-Path $target 'input.txt'), "$Content`n", [Text.UTF8Encoding]::new($false)) }
    foreach ($directory in @('Contracts','Application')) { New-Item -ItemType Directory -Path (Join-Path $target $directory) -Force | Out-Null }
    [IO.File]::WriteAllText((Join-Path $target 'Contracts/Synthetic.Contracts.csproj'), '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFramework>net10.0</TargetFramework><AssemblyName>Synthetic.Contracts</AssemblyName></PropertyGroup></Project>', [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText((Join-Path $target 'Contracts/Contracts.cs'), 'namespace Synthetic.Contracts { public interface IPort { } } namespace Synthetic.ForbiddenTypes { public sealed class ForbiddenType { } } namespace Synthetic.ForbiddenApi { public static class Calls { public static void Use() { } } } namespace Synthetic.ForbiddenPayload { public sealed class Payload { } } namespace Synthetic.ForbiddenImport { public sealed class Marker { } }', [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText((Join-Path $target 'Application/Synthetic.Application.csproj'), '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFramework>net10.0</TargetFramework><AssemblyName>Synthetic.Application</AssemblyName></PropertyGroup><ItemGroup><ProjectReference Include="../Contracts/Synthetic.Contracts.csproj" /></ItemGroup></Project>', [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText((Join-Path $target 'Application/Application.cs'), 'namespace Synthetic.Application.Allowed { public sealed class Port : Synthetic.Contracts.IPort { } }', [Text.UTF8Encoding]::new($false))
    [pscustomobject]@{ Root = $root; Target = $target; State = $state; Evidence = $evidence; TargetHash = (Hash-Tree $target) }
}

function Invoke-Stage($Roots, [string] $Stage, [string] $Profile = 'synthetic_profile', [string] $Package = $packageRoot) {
    $dll = Join-Path $artifactsRoot 'bin/V4.Guards.Host/debug/v4-guards.dll'
    $arguments = @('stage','run','--stage',$Stage,'--package-root',$Package,'--target-root',$Roots.Target,
        '--state-root',$Roots.State,'--evidence-root',$Roots.Evidence,'--profile',$Profile)
    $output = @(& dotnet $dll @arguments 2>&1)
    [pscustomobject]@{ Code = $LASTEXITCODE; Output = ($output -join "`n") }
}

function New-CapabilityGatedPackage() {
    $copy = Join-Path $runRoot 'capability-gated-package'
    Copy-Item -LiteralPath $packageRoot -Destination $copy -Recurse
    $profilePath = Join-Path $copy 'profiles/catalog/synthetic_profile/profile.json'
    $profile = Get-Content -Raw -LiteralPath $profilePath | ConvertFrom-Json -AsHashtable -Depth 100
    @($profile.moduleSelections | Where-Object id -CEQ 'synthetic-probe')[0].config.expectWorkspaceEvidence = $false
    Write-Json $profilePath $profile
    $modulePath = Join-Path $copy 'modules/synthetic-probe/module.json'
    $module = Get-Content -Raw -LiteralPath $modulePath | ConvertFrom-Json -AsHashtable -Depth 100
    $module.capabilities.readRoots = @('TargetRoot')
    Write-Json $modulePath $module
    $registryPath = Join-Path $copy 'modules/registry.json'
    $registry = Get-Content -Raw -LiteralPath $registryPath | ConvertFrom-Json -AsHashtable -Depth 100
    @($registry.modules | Where-Object id -CEQ 'synthetic-probe')[0].manifestSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $modulePath).Hash.ToLowerInvariant()
    Write-Json $registryPath $registry
    return $copy
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
    $workspaceEvidencePath = Join-Path $Roots.Evidence "projects/$projectId/runs/$($result.runId)/workspace-evidence.json"
    if ($result.profile.id -ceq 'synthetic_profile') {
        if (-not (Test-Path -LiteralPath $workspaceEvidencePath -PathType Leaf)) { $failures.Add("${Name}: Host workspace evidence is missing"); return $result }
        if (-not (Test-Json -LiteralPath $workspaceEvidencePath -SchemaFile $workspaceEvidenceSchema -ErrorAction SilentlyContinue)) { $failures.Add("${Name}: workspace evidence does not satisfy its schema") }
        $workspace = Get-Content -Raw -LiteralPath $workspaceEvidencePath | ConvertFrom-Json
        $workspaceHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $workspaceEvidencePath).Hash.ToLowerInvariant()
        if ($result.authorityHashes.workspaceEvidence -cne $workspaceHash) { $failures.Add("${Name}: workspace evidence is not bound as run authority") }
        if ($workspace.targetCommit -cne $targetCommit -or $workspace.scope -cne 'v4-workspace-evidence-v1') { $failures.Add("${Name}: workspace evidence target identity is invalid") }
        if (@(Get-ChildItem -LiteralPath (Split-Path -Parent $workspaceEvidencePath) -Filter 'workspace-evidence.json' -File).Count -ne 1) { $failures.Add("${Name}: run did not contain exactly one workspace evidence document") }
        [string[]]$paths = @($workspace.files | ForEach-Object { [string]$_.path })
        [string[]]$sortedPaths = $paths.Clone(); [Array]::Sort($sortedPaths, [StringComparer]::Ordinal)
        $uniquePaths = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        foreach ($path in $paths) { [void]$uniquePaths.Add($path) }
        if (($paths -join "`n") -cne ($sortedPaths -join "`n") -or $uniquePaths.Count -ne $paths.Count) { $failures.Add("${Name}: workspace evidence paths are not unique ordinal order") }
        $treeLines = @($workspace.files | ForEach-Object { "$($_.path)|$($_.sha256)" }) -join "`n"
        $treeHash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($treeLines))).ToLowerInvariant()
        if ($workspace.treeSha256 -cne $treeHash -or $workspace.fileCount -ne $paths.Count) { $failures.Add("${Name}: workspace evidence tree identity is invalid") }
        $entry = @($workspace.files | Where-Object path -CEQ 'input.txt')
        if (Test-Path -LiteralPath (Join-Path $Roots.Target 'input.txt')) {
            $inputHash = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $Roots.Target 'input.txt')).Hash.ToLowerInvariant()
            if ($entry.Count -ne 1 -or $entry[0].sha256 -cne $inputHash -or [string]$entry[0].text -cne [IO.File]::ReadAllText((Join-Path $Roots.Target 'input.txt'))) { $failures.Add("${Name}: workspace evidence input projection is invalid") }
        }
    }
    elseif (Test-Path -LiteralPath $workspaceEvidencePath) { $failures.Add("${Name}: Profile without workspaceEvidence unexpectedly produced evidence") }
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
    $expectedModules = if ($stage -eq 'pre') { 2 } elseif ($stage -eq 'post') { 3 } else { 1 }
    if ($null -ne $result -and ($result.stage -cne $stage -or $result.status -cne 'pass' -or @($result.moduleResults).Count -ne $expectedModules)) {
        $failures.Add("direct ${stage}: uniform result identity is invalid")
    }
}

$gatedPackage = New-CapabilityGatedPackage
$gated = New-Roots 'capability-gated'
$gatedResult = Assert-Run 'capability-gated injection' $gated (Invoke-Stage $gated 'analysis' 'synthetic_profile' $gatedPackage) 0 'success'
if ($null -ne $gatedResult -and $gatedResult.status -cne 'pass') { $failures.Add('Module without EvidenceRoot did not complete without the workspace evidence binding') }

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

foreach ($roots in @($direct,$gated,$blocking,$missing,$default)) {
    if ((Hash-Tree $roots.Target) -cne $roots.TargetHash) { $failures.Add("TargetRoot changed: $($roots.Root)") }
}
if ((Hash-Tree $packageRoot) -cne $packageBefore) { $failures.Add('Stage execution changed PackageRoot') }

if ($failures.Count -gt 0) { throw ($failures -join "`n") }
Write-Host 'V4 P3A Stage tests passed: four direct Stages, capability-gated workspace evidence, schema-valid project evidence, blocking findings, missing prerequisites and empty default profile.'
