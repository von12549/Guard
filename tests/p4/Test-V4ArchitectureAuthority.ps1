[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$packageRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $packageRoot '../../..'))
$moduleRoot = Join-Path $packageRoot 'modules/architecture-conformance'
$matrixPath = Join-Path $moduleRoot 'capability-matrix.json'
$planPath = Join-Path $moduleRoot 'rule-execution-plan.json'
$manifestPath = Join-Path $moduleRoot 'module.json'
$failures = [Collections.Generic.List[string]]::new()

function Hash([string] $Path) { (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant() }
function Read([string] $Path) { Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json -AsHashtable -Depth 100 }

if (-not (Test-Json -LiteralPath $matrixPath -SchemaFile (Join-Path $packageRoot 'core/contracts/capability-matrix.schema.json') -ErrorAction SilentlyContinue)) {
    $failures.Add('capability matrix violates its schema')
}
if (-not (Test-Json -LiteralPath $planPath -SchemaFile (Join-Path $packageRoot 'core/contracts/rule-execution-plan.schema.json') -ErrorAction SilentlyContinue)) {
    $failures.Add('rule execution plan violates its schema')
}

$matrix = Read $matrixPath; $plan = Read $planPath; $manifest = Read $manifestPath
$claims = @($matrix.claims); $rules = @($plan.rules)
if ($claims.Count -ne 12 -or @($claims.claimId | Sort-Object -Unique).Count -ne 12) { $failures.Add('matrix does not contain 12 unique v1 claims') }
if ($rules.Count -ne $claims.Count -or @($rules.ruleId | Sort-Object -Unique).Count -ne $rules.Count) { $failures.Add('execution plan rule identity is not one-to-one') }
if ($plan.matrixSha256 -cne (Hash $matrixPath)) { $failures.Add('execution plan does not bind the matrix hash') }

$allowedDetectors = @('project-model','roslyn-syntax','roslyn-semantic','archunitnet')
$allowedEvidence = @('project-model-raw','source-syntax','source-semantic','compiled-assembly')
foreach ($claim in $claims) {
    $rule = @($rules | Where-Object claimId -CEQ $claim.claimId)
    if ($rule.Count -ne 1 -or $rule[0].ruleId -cne $claim.claimId) { $failures.Add("claim/rule mapping is not exact: $($claim.claimId)"); continue }
    if (@($claim.detectors | Where-Object { $_ -notin $allowedDetectors }).Count -ne 0) { $failures.Add("claim has unknown detector: $($claim.claimId)") }
    if (@($claim.evidenceKinds | Where-Object { $_ -notin $allowedEvidence }).Count -ne 0) { $failures.Add("claim has unknown evidence: $($claim.claimId)") }
    if ((@($rule[0].detectors) -join ',') -cne (@($claim.detectors) -join ',') -or
        (@($rule[0].evidenceKinds) -join ',') -cne (@($claim.evidenceKinds) -join ',') -or
        $rule[0].stage -cne $claim.earliestStage -or $rule[0].minimumMatches -ne $claim.minimumMatches) {
        $failures.Add("claim/rule allocation drift: $($claim.claimId)")
    }
    foreach ($fixture in @($claim.fixtures.clean,$claim.fixtures.violating,$claim.fixtures.missingInput)) {
        if (-not (Test-Path -LiteralPath (Join-Path $packageRoot $fixture) -PathType Container)) { $failures.Add("missing fixture root for $($claim.claimId): $fixture") }
    }
}

$matrixClaims = @($claims.claimId | Sort-Object)
foreach ($case in @('clean','violating','missing')) {
    $fixture = Read (Join-Path $moduleRoot "fixtures/$case/fixture.json")
    if ((@($fixture.claims | Sort-Object) -join ',') -cne ($matrixClaims -join ',')) { $failures.Add("$case fixture does not cover every claim") }
}

$authorityById = @{}; foreach ($authority in $manifest.authorities) { $authorityById[$authority.id] = $authority }
foreach ($expected in @(
    @('capability-matrix','capability-matrix.json'),
    @('rule-execution-plan','rule-execution-plan.json'),
    @('fixture-catalog','fixtures/manifest.json'),
    @('module-result','result.schema.json')
)) {
    $authority = $authorityById[$expected[0]]
    if ($null -eq $authority -or $authority.sha256 -cne (Hash (Join-Path $moduleRoot $expected[1]))) { $failures.Add("module authority hash drift: $($expected[0])") }
}

$genericText = (Get-ChildItem -LiteralPath $moduleRoot -Recurse -File | Sort-Object FullName | ForEach-Object { Get-Content -Raw -LiteralPath $_.FullName }) -join "`n"
if ($genericText -match '(?i)(?:\bIFX\b|\bV3(?:_ifx)?\b|docs/guards/)') { $failures.Add('generic module contains a product identifier or reference runtime path') }

$syntheticProfile = Read (Join-Path $packageRoot 'profiles/catalog/synthetic_profile/profile.json')
if (@($syntheticProfile.moduleSelections | Where-Object id -CEQ 'architecture-conformance').Count -ne 1 -or
    @($syntheticProfile.stageConfiguration.pre.modules) -notcontains 'architecture-conformance') {
    $failures.Add('synthetic profile does not select Architecture Conformance for Pre')
}

$registry = Read (Join-Path $packageRoot 'modules/registry.json')
$entry = @($registry.modules | Where-Object id -CEQ 'architecture-conformance')
if ($entry.Count -ne 1 -or $entry[0].manifestSha256 -cne (Hash $manifestPath)) { $failures.Add('architecture module registry binding is invalid') }

$fixtureRoot = Join-Path $repositoryRoot 'artifacts/guards/v4/p4a/package-drift'
if (Test-Path -LiteralPath $fixtureRoot) { Remove-Item -LiteralPath $fixtureRoot -Recurse -Force }
New-Item -ItemType Directory -Path $fixtureRoot -Force | Out-Null
$copy = Join-Path $fixtureRoot 'package'; Copy-Item -LiteralPath $packageRoot -Destination $copy -Recurse
[IO.File]::AppendAllText((Join-Path $copy 'modules/architecture-conformance/capability-matrix.json'), " `n")
$checkOutput = @(& pwsh -NoProfile -File (Join-Path $copy 'core/runtime/Test-V4Package.ps1') -PackageRoot $copy 2>&1) -join "`n"
if ($LASTEXITCODE -eq 0 -or $checkOutput -notmatch 'module authority hash drift') { $failures.Add('package checker accepted architecture authority hash drift') }

$input = @{ formatVersion = 1; stage = 'pre'; targetRoot = $repositoryRoot; config = @{ enabledClaims=@('ARCH.PROJECT_REFERENCE'); forbiddenProjectReferences=@(); forbiddenPackages=@(); allowedTargetFrameworks=@('net10.0'); requireResolvedProjectReferences=$true } } | ConvertTo-Json -Compress
$env:V4_STAGE_INPUT_JSON = $input
try { $adapterJson = & pwsh -NoProfile -File (Join-Path $moduleRoot 'adapter.ps1'); $adapter = $adapterJson | ConvertFrom-Json }
finally { Remove-Item Env:V4_STAGE_INPUT_JSON -ErrorAction SilentlyContinue }
if ($adapter.status -cne 'pass' -or @($adapter.findings).Count -ne 0) { $failures.Add('packaged Stage Gate adapter contract is invalid') }
if (-not (Test-Json -Json $adapterJson -SchemaFile (Join-Path $moduleRoot 'result.schema.json') -ErrorAction SilentlyContinue)) { $failures.Add('adapter output violates the declared module result schema') }

if ($failures.Count -gt 0) { throw ($failures -join "`n") }
Write-Host 'V4 P4A authority tests passed: 12 claims, exact rule allocation, three fixture classes, hash binding and generic-module isolation.'
