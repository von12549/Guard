[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$packageRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$repoRoot = [IO.Path]::GetFullPath((Join-Path $packageRoot '../../..'))
$checker = Join-Path $packageRoot 'core/runtime/Test-V4Package.ps1'
$fixtureRoot = Join-Path $repoRoot 'artifacts/guards/v4/p1a'
$failures = [Collections.Generic.List[string]]::new()

function Invoke-Check([string] $Root) {
    $output = & pwsh -NoLogo -NoProfile -NonInteractive -File $checker -PackageRoot $Root 2>&1 | Out-String
    [pscustomobject]@{ Code = $LASTEXITCODE; Output = $output.Trim() }
}

function New-Case([string] $Name) {
    $caseRoot = Join-Path $fixtureRoot $Name
    if (Test-Path -LiteralPath $caseRoot) { Remove-Item -LiteralPath $caseRoot -Recurse -Force }
    New-Item -ItemType Directory -Path $caseRoot -Force | Out-Null
    $copy = Join-Path $caseRoot 'package'
    Copy-Item -LiteralPath $packageRoot -Destination $copy -Recurse -Force
    return $copy
}

function Write-Json([string] $Path, $Value) {
    [IO.File]::WriteAllText($Path, ($Value | ConvertTo-Json -Depth 100) + "`n", [Text.UTF8Encoding]::new($false))
}

function Update-RegistryHash([string] $Root, [string] $ModuleId) {
    $registryPath = Join-Path $Root 'modules/registry.json'
    $registry = Get-Content -Raw $registryPath | ConvertFrom-Json -AsHashtable -Depth 100
    $entry = @($registry.modules | Where-Object id -CEQ $ModuleId)
    if ($entry.Count -ne 1) { throw "Registry entry not found: $ModuleId" }
    $entry[0].manifestSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $Root $entry[0].manifestPath)).Hash.ToLowerInvariant()
    Write-Json $registryPath $registry
}

function Expect-Failure([string] $Name, [scriptblock] $Mutation, [string] $Pattern) {
    $copy = New-Case $Name
    & $Mutation $copy
    $result = Invoke-Check $copy
    if ($result.Code -eq 0) { $failures.Add("$Name unexpectedly passed"); return }
    if ($result.Output -notmatch $Pattern) { $failures.Add("$Name failed for the wrong reason: $($result.Output)") }
}

if (Test-Path -LiteralPath $fixtureRoot) { Remove-Item -LiteralPath $fixtureRoot -Recurse -Force }
New-Item -ItemType Directory -Path $fixtureRoot -Force | Out-Null

$positive = Invoke-Check $packageRoot
if ($positive.Code -ne 0) {
    $failures.Add("positive package failed: $($positive.Output)")
    $positiveDocument = $null
} else {
    $positiveDocument = $positive.Output | ConvertFrom-Json
    if ($positiveDocument.status -ne 'pass' -or $positiveDocument.profiles.Count -ne 2 -or $positiveDocument.modules.Count -ne 3) {
        $failures.Add('positive package result identity is incorrect')
    }
}

$mutable = New-Case 'mutable-exclusion'
foreach ($relative in @('state/noise.json','.work/noise.json','artifacts/noise.json')) {
    $path = Join-Path $mutable $relative
    New-Item -ItemType Directory -Path (Split-Path -Parent $path) -Force | Out-Null
    [IO.File]::WriteAllText($path, "mutable`n", [Text.UTF8Encoding]::new($false))
}
$mutableResult = Invoke-Check $mutable
if ($mutableResult.Code -ne 0) {
    $failures.Add("mutable-root exclusion failed: $($mutableResult.Output)")
} elseif ($null -ne $positiveDocument -and ($mutableResult.Output | ConvertFrom-Json).packageHash -cne $positiveDocument.packageHash) {
    $failures.Add('mutable V4 data changed the package hash')
}

$empty = New-Case 'empty-package'
Remove-Item -LiteralPath (Join-Path $empty 'modules/synthetic-probe') -Recurse -Force
Remove-Item -LiteralPath (Join-Path $empty 'modules/architecture-conformance') -Recurse -Force
Remove-Item -LiteralPath (Join-Path $empty 'modules/build-evidence-provider') -Recurse -Force
Remove-Item -LiteralPath (Join-Path $empty 'profiles/catalog/synthetic_profile') -Recurse -Force
$emptyRegistryPath = Join-Path $empty 'modules/registry.json'
$emptyRegistry = Get-Content -Raw $emptyRegistryPath | ConvertFrom-Json -AsHashtable -Depth 100
$emptyRegistry.modules = @(); Write-Json $emptyRegistryPath $emptyRegistry
$emptyResult = Invoke-Check $empty
if ($emptyResult.Code -ne 0) { $failures.Add("empty package failed: $($emptyResult.Output)") }
else {
    $emptyDocument = $emptyResult.Output | ConvertFrom-Json
    if (($emptyDocument.profiles -join ',') -cne 'default' -or $emptyDocument.modules.Count -ne 0) {
        $failures.Add('empty package did not resolve only the default profile')
    }
}

Expect-Failure 'unknown-plugin-field' {
    param($copy)
    $path = Join-Path $copy 'plugin.json'; $json = Get-Content -Raw $path | ConvertFrom-Json -AsHashtable
    $json.unexpected = $true; Write-Json $path $json
} 'plugin manifest does not satisfy'

Expect-Failure 'duplicate-profile-id' {
    param($copy)
    Copy-Item -LiteralPath (Join-Path $copy 'profiles/catalog/default') -Destination (Join-Path $copy 'profiles/catalog/duplicate') -Recurse
} 'duplicate profile ID'

Expect-Failure 'catalog-path-escape' {
    param($copy)
    $path = Join-Path $copy 'plugin.json'; $json = Get-Content -Raw $path | ConvertFrom-Json -AsHashtable
    $json.profilesCatalog = '../outside'; Write-Json $path $json
} 'plugin manifest does not satisfy'

Expect-Failure 'raw-profile-command' {
    param($copy)
    $path = Join-Path $copy 'profiles/catalog/synthetic_profile/profile.json'; $json = Get-Content -Raw $path | ConvertFrom-Json -AsHashtable
    $json.command = 'pwsh evil.ps1'; Write-Json $path $json
} 'profile synthetic_profile does not satisfy'

Expect-Failure 'undeclared-module' {
    param($copy)
    $path = Join-Path $copy 'profiles/catalog/synthetic_profile/profile.json'; $json = Get-Content -Raw $path | ConvertFrom-Json -AsHashtable
    $json.moduleSelections[0].id = 'missing-module'; $json.stageConfiguration.analysis.modules = @('missing-module'); Write-Json $path $json
} 'selects undeclared module'

Expect-Failure 'target-root-write' {
    param($copy)
    $path = Join-Path $copy 'modules/synthetic-probe/module.json'; $json = Get-Content -Raw $path | ConvertFrom-Json -AsHashtable
    $json.capabilities.writeRoots = @('TargetRoot'); Write-Json $path $json; Update-RegistryHash $copy 'synthetic-probe'
} 'module synthetic-probe does not satisfy'

Expect-Failure 'adapter-hash-drift' {
    param($copy)
    [IO.File]::AppendAllText((Join-Path $copy 'modules/synthetic-probe/adapter.ps1'), "`n# drift`n", [Text.UTF8Encoding]::new($false))
} 'adapter hash drift'

foreach ($path in @('docs/guards/v4/state/probe.json','docs/guards/v4/.work/probe.json','docs/guards/v4/artifacts/probe.json')) {
    & git -C $repoRoot check-ignore -q -- $path
    if ($LASTEXITCODE -ne 0) { $failures.Add("mutable path is not ignored: $path") }
}

if ($failures.Count -gt 0) { throw ($failures -join "`n") }
Write-Host 'V4 P1A package tests passed: schema-valid authorities, empty package, mutable exclusion and seven fail-closed negatives.'
