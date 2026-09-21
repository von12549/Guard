[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$packageRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$contractRoot = Join-Path $packageRoot 'core/contracts'
$failures = [Collections.Generic.List[string]]::new()
$hash = ('a' * 64)
$commit = ('b' * 40)

function Schema([string] $Name) { Join-Path $contractRoot "$Name.schema.json" }
function Json($Value) { $Value | ConvertTo-Json -Depth 50 -Compress }
function Clone($Value) { (Json $Value) | ConvertFrom-Json -AsHashtable -Depth 50 }
function Valid([string] $Name, $Value) {
    $ok = Test-Json -Json (Json $Value) -SchemaFile (Schema $Name) -ErrorAction SilentlyContinue
    if (-not $ok) { $failures.Add("$Name positive fixture did not validate") }
}
function Invalid([string] $Label, [string] $SchemaName, $Value) {
    $ok = Test-Json -Json (Json $Value) -SchemaFile (Schema $SchemaName) -ErrorAction SilentlyContinue
    if ($ok) { $failures.Add("$Label negative fixture unexpectedly validated") }
}

$stageConfig = [ordered]@{}
foreach ($stage in @('bootstrap','analysis','pre','post')) { $stageConfig[$stage] = [ordered]@{ enabled = $true; modules = @('synthetic-probe') } }

$fixtures = [ordered]@{
    plugin = [ordered]@{ formatVersion = 1; id = 'v4-guards'; version = '0.1.0'; apiVersion = '1.0'; contractsManifest = 'core/contracts/contracts-manifest.json'; profilesCatalog = 'profiles/catalog'; modulesCatalog = 'modules'; defaultProfile = 'default' }
    profile = [ordered]@{ formatVersion = 1; id = 'synthetic_profile'; version = '1.0.0'; projectIdentity = [ordered]@{ id = 'synthetic'; relativeRoots = @('src') }; moduleSelections = @([ordered]@{ id = 'synthetic-probe'; versionRange = '>=1.0.0 <2.0.0'; config = [ordered]@{} }); stageConfiguration = $stageConfig; rules = @('ARCH.SYNTHETIC'); baselineRefs = @('baselines/synthetic.json') }
    'module-registry' = [ordered]@{ formatVersion = 1; modules = @([ordered]@{ id = 'synthetic-probe'; manifestPath = 'modules/synthetic-probe/module.json'; manifestSha256 = $hash; allowedCapabilities = [ordered]@{ readRoots = @('TargetRoot'); writeRoots = @('EvidenceRoot'); processes = @('pwsh'); network = $false; maxTimeoutSeconds = 30 } }) }
    module = [ordered]@{ formatVersion = 1; id = 'synthetic-probe'; version = '1.0.0'; compatibleApi = '1.x'; supportedPlatforms = @('linux-x64','win-x64'); adapter = [ordered]@{ kind = 'powershell'; path = 'modules/synthetic-probe/adapter.ps1'; sha256 = $hash }; prerequisites = @([ordered]@{ runtime = 'pwsh'; versionRange = '>=7.4' }); capabilities = [ordered]@{ readRoots = @('TargetRoot'); writeRoots = @('EvidenceRoot'); processes = @('pwsh'); network = $false; timeoutSeconds = 30 }; stages = @('analysis'); configSchema = 'modules/synthetic-probe/config.schema.json'; resultSchema = 'core/contracts/stage-result.schema.json'; dependencyLock = [ordered]@{ path = 'modules/synthetic-probe/dependencies.lock.json'; sha256 = $hash } }
    'stage-result' = [ordered]@{ formatVersion = 1; runId = ('c' * 32); stage = 'analysis'; status = 'pass'; exitCategory = 'success'; profile = [ordered]@{ id = 'synthetic_profile'; version = '1.0.0'; sha256 = $hash }; roots = [ordered]@{ packageRoot = 'C:/package'; targetRoot = 'C:/target'; stateRoot = 'C:/state'; evidenceRoot = 'C:/evidence' }; authorityHashes = [ordered]@{ plugin = $hash }; moduleResults = @([ordered]@{ moduleId = 'synthetic-probe'; status = 'pass'; evidencePath = 'modules/synthetic-probe.json' }); findings = @(); coverage = @([ordered]@{ claimId = 'ARCH.SYNTHETIC'; matched = 1; minimum = 1 }) }
    state = [ordered]@{ formatVersion = 1; projectInstances = @([ordered]@{ id = ('d' * 32); targetCanonicalPath = 'C:/target'; targetIdentityHash = $hash; profileId = 'synthetic_profile'; claimedStatePaths = @('projects/example'); claimedEvidencePaths = @('projects/example') }); transactions = @([ordered]@{ id = ('e' * 32); kind = 'state-write'; status = 'applied'; manifestHash = $hash; projectId = ('d' * 32) }); resetReceipts = @([ordered]@{ id = ('f' * 32); mode = 'project'; acceptedManifestHash = $hash; beforeHash = $hash; afterHash = $hash }) }
    plan = [ordered]@{ formatVersion = 1; id = '20260922-synthetic'; title = 'Synthetic'; goal = 'Prove the contract'; acceptanceCriteria = @('The fixture passes'); plannedPaths = @('docs/example.json'); areas = @('contracts'); risks = @(); decisions = @('V4-AD-013'); validationCommands = @('contract-test'); dependencies = @(); boundaries = @() }
    'plan-set' = [ordered]@{ formatVersion = 1; id = '20260922-synthetic-set'; members = @([ordered]@{ order = 1; planId = 'a'; path = 'plans/a.plan.json'; sha256 = $hash; dependsOn = @() }, [ordered]@{ order = 2; planId = 'b'; path = 'plans/b.plan.json'; sha256 = $hash; dependsOn = @('a') }); derivedUnion = [ordered]@{ plannedPaths = @('a','b'); areas = @('contracts'); risks = @(); decisions = @('V4-AD-013'); validationCommands = @('contract-test'); boundaries = @() }; compositionHash = $hash }
    'capability-matrix' = [ordered]@{ formatVersion = 1; moduleId = 'architecture-conformance'; claims = @([ordered]@{ claimId = 'ARCH.PROJECT_REFERENCE'; authority = 'profile/rules.json'; evidenceKinds = @('project-model-raw','compiled-assembly'); earliestStage = 'pre'; detectors = @('project-model','archunitnet'); fixtures = [ordered]@{ clean = 'fixtures/clean'; violating = 'fixtures/violating'; missingInput = 'fixtures/missing' }; minimumMatches = 1; knownLimits = @('condition evaluation is Post-only'); parityRule = 'Same blocking category and non-zero evidence.' }) }
    'rule-execution-plan' = [ordered]@{ formatVersion = 1; moduleId = 'architecture-conformance'; matrixSha256 = $hash; rules = @([ordered]@{ ruleId = 'ARCH.PROJECT_REFERENCE'; claimId = 'ARCH.PROJECT_REFERENCE'; stage = 'post'; detectors = @('project-model','archunitnet'); evidenceKinds = @('project-model-raw','compiled-assembly'); severity = 'blocking'; baseline = $null; minimumMatches = 1 }) }
    'genesis-record' = [ordered]@{ formatVersion = 1; seedSha = $commit; packageHash = $hash; contractsManifestHash = $hash; deterministicTests = @([ordered]@{ id = 'p0a'; resultHash = $hash }); nonInterferenceEvidence = @('artifacts/guards/v3-ifx/summary-validate.json'); recovery = [ordered]@{ restoreSha = $commit; instructionsHash = $hash }; acceptedBy = [ordered]@{ authorityType = 'human-review'; authorityId = 'review-1'; candidateHostVerdictAllowed = $false } }
}

foreach ($entry in $fixtures.GetEnumerator()) {
    Valid $entry.Key $entry.Value
    $unknown = Clone $entry.Value
    $unknown['unexpected'] = $true
    Invalid "$($entry.Key) unknown field" $entry.Key $unknown
}

$profileCommand = Clone $fixtures.profile
$profileCommand['command'] = 'pwsh evil.ps1'
Invalid 'profile raw executable' 'profile' $profileCommand

$moduleWrite = Clone $fixtures.module
$moduleWrite.capabilities.writeRoots = @('TargetRoot')
Invalid 'module TargetRoot write' 'module' $moduleWrite

$badExit = Clone $fixtures['stage-result']
$badExit.exitCategory = 'unknown'
Invalid 'unknown Stage exit category' 'stage-result' $badExit

$incompleteUnion = Clone $fixtures['plan-set']
$incompleteUnion.Remove('derivedUnion')
Invalid 'plan-set missing derived union' 'plan-set' $incompleteUnion

$zeroMatch = Clone $fixtures['capability-matrix']
$zeroMatch.claims[0].minimumMatches = 0
Invalid 'blocking claim zero matches' 'capability-matrix' $zeroMatch

$missingFixture = Clone $fixtures['capability-matrix']
$missingFixture.claims[0].fixtures.Remove('missingInput')
Invalid 'claim missing missing-input fixture' 'capability-matrix' $missingFixture

$selfAccepted = Clone $fixtures['genesis-record']
$selfAccepted.acceptedBy.candidateHostVerdictAllowed = $true
Invalid 'candidate self-accepted genesis' 'genesis-record' $selfAccepted

$cliPath = Join-Path $contractRoot 'cli-contract.json'
$cli = Get-Content -Raw $cliPath | ConvertFrom-Json -AsHashtable -Depth 30
Valid 'cli-contract' $cli
$stableCommands = @($cli.commands | Where-Object stability -eq 'stable' | ForEach-Object id | Sort-Object)
$expectedCommands = @('contract.validate','plan.compose','plan.validate','reset.factory','reset.project','stage.run','version')
if (($stableCommands -join ',') -cne ($expectedCommands -join ',')) { $failures.Add('Stable CLI command identities drifted') }
$exitMap = @($cli.exitCategories | Sort-Object code | ForEach-Object { "$($_.id)=$($_.code)" })
$expectedExitMap = @('success=0','invalid-input=10','unsafe-path=11','integrity-failure=12','capability-denied=13','adapter-failure=14','prerequisite-missing=15','findings-blocking=16','state-conflict=17','reset-refused=18','internal-error=19')
if (($exitMap -join ',') -cne ($expectedExitMap -join ',')) { $failures.Add('Stable exit category mapping drifted') }

$schemaNames = @('capability-matrix','cli-contract','genesis-record','module-registry','module','plan-set','plan','plugin','profile','rule-execution-plan','stage-result','state')
foreach ($name in $schemaNames) {
    $schema = Get-Content -Raw (Schema $name) | ConvertFrom-Json -AsHashtable -Depth 50
    if ($schema.'$schema' -ne 'http://json-schema.org/draft-07/schema#' -or $schema.additionalProperties -ne $false -or -not $schema.ContainsKey('$id')) {
        $failures.Add("$name is not a strict identified draft-07 schema")
    }
}

$expectedManifestPaths = @($schemaNames | ForEach-Object { "core/contracts/$_.schema.json" }) + @('core/contracts/cli-contract.json') | Sort-Object
$manifest = Get-Content -Raw (Join-Path $contractRoot 'contracts-manifest.json') | ConvertFrom-Json -AsHashtable -Depth 20
$manifestPaths = @($manifest.files | ForEach-Object path | Sort-Object)
if (($manifestPaths -join ',') -cne ($expectedManifestPaths -join ',')) { $failures.Add('Contract manifest path set is not exact') }
foreach ($entry in $manifest.files) {
    $full = Join-Path $packageRoot $entry.path
    if (-not [IO.File]::Exists($full)) { $failures.Add("Manifest file is missing: $($entry.path)"); continue }
    $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $full).Hash.ToLowerInvariant()
    if ($actual -cne $entry.sha256) { $failures.Add("Manifest hash mismatch: $($entry.path)") }
}

if ($failures.Count -gt 0) { throw ($failures -join "`n") }
Write-Host "V4 P0B contract tests passed: $($schemaNames.Count) schemas, $($cli.commands.Count) commands, $($manifest.files.Count) bound contracts."
