[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$packageRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$repoRoot = [IO.Path]::GetFullPath((Join-Path $packageRoot '../../..'))
$checker = Join-Path $packageRoot 'core/runtime/Test-V4Package.ps1'
$fixtureRoot = Join-Path $repoRoot 'artifacts/guards/v4/p1b'
$failures = [Collections.Generic.List[string]]::new()

function Write-Json([string] $Path, $Value) {
    [IO.File]::WriteAllText($Path, ($Value | ConvertTo-Json -Depth 100) + "`n", [Text.UTF8Encoding]::new($false))
}

function New-Case([string] $Name) {
    $caseRoot = Join-Path $fixtureRoot $Name
    if (Test-Path -LiteralPath $caseRoot) { Remove-Item -LiteralPath $caseRoot -Recurse -Force }
    New-Item -ItemType Directory -Path $caseRoot -Force | Out-Null
    $copy = Join-Path $caseRoot 'package'
    Copy-Item -LiteralPath $packageRoot -Destination $copy -Recurse -Force
    return $copy
}

function Invoke-Check([string] $Root) {
    $output = & pwsh -NoLogo -NoProfile -NonInteractive -File $checker -PackageRoot $Root 2>&1 | Out-String
    [pscustomobject]@{ Code = $LASTEXITCODE; Output = $output.Trim() }
}

function Update-ManifestHash([string] $Root) {
    $registryPath = Join-Path $Root 'modules/registry.json'
    $registry = Get-Content -Raw $registryPath | ConvertFrom-Json -AsHashtable -Depth 100
    $entry = $registry.modules[0]
    $entry.manifestSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $Root $entry.manifestPath)).Hash.ToLowerInvariant()
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
if ($positive.Code -ne 0) { $failures.Add("positive registry failed: $($positive.Output)") }

Expect-Failure 'registry-unknown-field' {
    param($copy)
    $path = Join-Path $copy 'modules/registry.json'; $json = Get-Content -Raw $path | ConvertFrom-Json -AsHashtable -Depth 100
    $json.unexpected = $true; Write-Json $path $json
} 'module registry does not satisfy'

Expect-Failure 'registry-duplicate-id' {
    param($copy)
    $path = Join-Path $copy 'modules/registry.json'; $json = Get-Content -Raw $path | ConvertFrom-Json -AsHashtable -Depth 100
    $duplicate = ($json.modules[0] | ConvertTo-Json -Depth 100 -Compress) | ConvertFrom-Json -AsHashtable -Depth 100
    $duplicate.manifestPath = 'modules/synthetic-probe/other.json'; $json.modules = @($json.modules[0], $duplicate); Write-Json $path $json
} 'duplicate module registry ID'

Expect-Failure 'registry-path-escape' {
    param($copy)
    $path = Join-Path $copy 'modules/registry.json'; $json = Get-Content -Raw $path | ConvertFrom-Json -AsHashtable -Depth 100
    $json.modules[0].manifestPath = '../outside.json'; Write-Json $path $json
} 'module registry does not satisfy'

Expect-Failure 'registry-manifest-hash-drift' {
    param($copy)
    $path = Join-Path $copy 'modules/registry.json'; $json = Get-Content -Raw $path | ConvertFrom-Json -AsHashtable -Depth 100
    $json.modules[0].manifestSha256 = ('0' * 64); Write-Json $path $json
} 'module manifest hash drift'

Expect-Failure 'undisclosed-module-directory' {
    param($copy)
    New-Item -ItemType Directory -Path (Join-Path $copy 'modules/hidden-module') -Force | Out-Null
} 'undisclosed module directory'

Expect-Failure 'process-capability-escalation' {
    param($copy)
    $path = Join-Path $copy 'modules/synthetic-probe/module.json'; $json = Get-Content -Raw $path | ConvertFrom-Json -AsHashtable -Depth 100
    $json.capabilities.processes = @('pwsh','bash'); Write-Json $path $json; Update-ManifestHash $copy
} 'exceeds registered process capability: bash'

Expect-Failure 'network-capability-escalation' {
    param($copy)
    $path = Join-Path $copy 'modules/synthetic-probe/module.json'; $json = Get-Content -Raw $path | ConvertFrom-Json -AsHashtable -Depth 100
    $json.capabilities.network = $true; Write-Json $path $json; Update-ManifestHash $copy
} 'exceeds registered network capability'

Expect-Failure 'timeout-capability-escalation' {
    param($copy)
    $path = Join-Path $copy 'modules/synthetic-probe/module.json'; $json = Get-Content -Raw $path | ConvertFrom-Json -AsHashtable -Depth 100
    $json.capabilities.timeoutSeconds = 31; Write-Json $path $json; Update-ManifestHash $copy
} 'exceeds registered timeout capability'

Expect-Failure 'read-root-capability-escalation' {
    param($copy)
    $path = Join-Path $copy 'modules/synthetic-probe/module.json'; $json = Get-Content -Raw $path | ConvertFrom-Json -AsHashtable -Depth 100
    $json.capabilities.readRoots = @('TargetRoot','StateRoot'); Write-Json $path $json; Update-ManifestHash $copy
} 'exceeds registered read-root capability: StateRoot'

if ($failures.Count -gt 0) { throw ($failures -join "`n") }
Write-Host 'V4 P1B registry tests passed: exact catalog plus nine registry, integrity and capability-escalation negatives.'
