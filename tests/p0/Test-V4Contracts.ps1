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
    plugin = [ordered]@{ formatVersion = 1; id = 'v4-guards'; version = '1.0.0'; apiVersion = '1.0'; contractsManifest = 'core/contracts/contracts-manifest.json'; profilesCatalog = 'profiles/catalog'; modulesCatalog = 'modules'; defaultProfile = 'default' }
    profile = [ordered]@{ formatVersion = 1; id = 'synthetic_profile'; version = '1.0.0'; projectIdentity = [ordered]@{ id = 'synthetic'; relativeRoots = @('src') }; moduleSelections = @([ordered]@{ id = 'synthetic-probe'; versionRange = '>=1.0.0 <2.0.0'; config = [ordered]@{} }); stageConfiguration = $stageConfig; rules = @('ARCH.SYNTHETIC'); baselineRefs = @('baselines/synthetic.json') }
    'module-registry' = [ordered]@{ formatVersion = 1; modules = @([ordered]@{ id = 'synthetic-probe'; manifestPath = 'modules/synthetic-probe/module.json'; manifestSha256 = $hash; allowedCapabilities = [ordered]@{ readRoots = @('TargetRoot'); writeRoots = @('EvidenceRoot'); processes = @('pwsh'); network = $false; maxTimeoutSeconds = 30 } }) }
    module = [ordered]@{ formatVersion = 1; id = 'synthetic-probe'; version = '1.0.0'; compatibleApi = '1.x'; supportedPlatforms = @('linux-x64','win-x64'); adapter = [ordered]@{ kind = 'powershell'; path = 'modules/synthetic-probe/adapter.ps1'; sha256 = $hash }; prerequisites = @([ordered]@{ runtime = 'pwsh'; versionRange = '>=7.4' }); capabilities = [ordered]@{ readRoots = @('TargetRoot'); writeRoots = @('EvidenceRoot'); processes = @('pwsh'); network = $false; timeoutSeconds = 30 }; stages = @('analysis'); configSchema = 'modules/synthetic-probe/config.schema.json'; resultSchema = 'core/contracts/stage-result.schema.json'; dependencyLock = [ordered]@{ path = 'modules/synthetic-probe/dependencies.lock.json'; sha256 = $hash }; authorities = @([ordered]@{ id = 'matrix'; path = 'modules/synthetic-probe/matrix.json'; sha256 = $hash }) }
    'stage-result' = [ordered]@{ formatVersion = 1; runId = ('c' * 32); stage = 'analysis'; status = 'pass'; exitCategory = 'success'; executedStages = @('analysis'); profile = [ordered]@{ id = 'synthetic_profile'; version = '1.0.0'; sha256 = $hash }; roots = [ordered]@{ packageRoot = 'C:/package'; targetRoot = 'C:/target'; stateRoot = 'C:/state'; evidenceRoot = 'C:/evidence' }; authorityHashes = [ordered]@{ plugin = $hash }; moduleResults = @([ordered]@{ moduleId = 'synthetic-probe'; status = 'pass'; evidencePath = 'modules/synthetic-probe.json' }); findings = @(); coverage = @([ordered]@{ claimId = 'ARCH.SYNTHETIC'; matched = 1; minimum = 1 }) }
    state = [ordered]@{ formatVersion = 1; projectInstances = @([ordered]@{ id = ('d' * 32); targetCanonicalPath = 'C:/target'; targetIdentityHash = $hash; profileId = 'synthetic_profile'; claimedStatePaths = @('projects/example'); claimedEvidencePaths = @('projects/example') }); transactions = @([ordered]@{ id = ('e' * 32); kind = 'state-write'; status = 'applied'; manifestHash = $hash; projectId = ('d' * 32) }); resetReceipts = @([ordered]@{ id = ('f' * 32); mode = 'project'; acceptedManifestHash = $hash; beforeHash = $hash; afterHash = $hash }) }
    plan = [ordered]@{ formatVersion = 1; id = '20260922-synthetic'; title = 'Synthetic'; goal = 'Prove the contract'; acceptanceCriteria = @('The fixture passes'); plannedPaths = @('docs/example.json'); areas = @('contracts'); risks = @(); decisions = @('V4-AD-013'); validationCommands = @('contract-test'); dependencies = @(); boundaries = @() }
    'plan-set' = [ordered]@{ formatVersion = 1; id = '20260922-synthetic-set'; members = @([ordered]@{ order = 1; planId = 'a'; path = 'plans/a.plan.json'; sha256 = $hash; dependsOn = @() }, [ordered]@{ order = 2; planId = 'b'; path = 'plans/b.plan.json'; sha256 = $hash; dependsOn = @('a') }); derivedUnion = [ordered]@{ plannedPaths = @('a','b'); areas = @('contracts'); risks = @(); decisions = @('V4-AD-013'); validationCommands = @('contract-test'); boundaries = @() }; compositionHash = $hash }
    'capability-matrix' = [ordered]@{ formatVersion = 1; moduleId = 'architecture-conformance'; claims = @([ordered]@{ claimId = 'ARCH.PROJECT_REFERENCE'; authority = 'profile/rules.json'; evidenceKinds = @('project-model-raw','compiled-assembly'); earliestStage = 'pre'; detectors = @('project-model','archunitnet'); fixtures = [ordered]@{ clean = 'fixtures/clean'; violating = 'fixtures/violating'; missingInput = 'fixtures/missing' }; minimumMatches = 1; knownLimits = @('condition evaluation is Post-only'); parityRule = 'Same blocking category and non-zero evidence.' }) }
    'rule-execution-plan' = [ordered]@{ formatVersion = 1; moduleId = 'architecture-conformance'; matrixSha256 = $hash; rules = @([ordered]@{ ruleId = 'ARCH.PROJECT_REFERENCE'; claimId = 'ARCH.PROJECT_REFERENCE'; stage = 'post'; detectors = @('project-model','archunitnet'); evidenceKinds = @('project-model-raw','compiled-assembly'); severity = 'blocking'; baseline = $null; minimumMatches = 1 }) }
    'finding-baseline' = [ordered]@{ formatVersion = 1; findings = @([ordered]@{ ruleId = 'ARCH.PROJECT_REFERENCE'; subject = 'Application/App.csproj -> ../Forbidden/Forbidden.csproj'; evidenceKind = 'project-model-raw'; detectorId = 'project-model' }) }
    'reset-manifest' = [ordered]@{ formatVersion = 1; mode = 'project'; projectId = ('d' * 32); entries = @([ordered]@{ root = 'state'; path = 'projects/example/data.txt'; type = 'file'; sha256 = $hash }); beforeHash = $hash; expectedAfterHash = $hash; manifestHash = $hash }
    'genesis-record' = [ordered]@{ formatVersion = 1; seedSha = $commit; packageHash = $hash; contractsManifestHash = $hash; deterministicTests = @([ordered]@{ id = 'p0a'; resultHash = $hash }); nonInterferenceEvidence = @('artifacts/guards/v3-ifx/summary-validate.json'); recovery = [ordered]@{ restoreSha = $commit; instructionsHash = $hash }; acceptedBy = [ordered]@{ authorityType = 'human-review'; authorityId = 'review-1'; candidateHostVerdictAllowed = $false } }
    'ci-contract' = [ordered]@{ formatVersion = 1; targetBranch = 'codex/v4-development-base'; requiredContexts = @('v4-contract','v4-linux','v4-package','v4-required'); permissions = [ordered]@{ contents='read' }; allowedChangedPatterns = @('docs/guards/v4/**'); windowsSensitivePatterns = @('docs/guards/v4/core/host/**'); approvedTests = @([ordered]@{ path='docs/guards/v4/tests/p0/Test-V4Contracts.ps1'; sha256=$hash; linux=$true; windowsSmoke=$true; windowsFull=$true }); artifact = [ordered]@{ name='v4-ci-artifact'; manifestPath='manifest.json'; packagePath='package'; hostPath='host/v4-guards.dll' }; excludedSuites = @('ifx-solution','ifx-frontend','ifx-database','v3-package-candidate') }
    'ci-artifact-manifest' = [ordered]@{ formatVersion = 1; baseSha=$commit; headSha=$commit; contractSha256=$hash; packageHash=$hash; buildEvidence=[ordered]@{ configuration='Release'; targetFramework='net10.0'; sourceSha256=$hash; hostPath='host/v4-guards.dll'; hostSha256=$hash; secretEnvironmentNames=@() }; linuxTests=@('docs/guards/v4/tests/p0/Test-V4Contracts.ps1'); files=@([ordered]@{path='package/plugin.json';sha256=$hash;size=1},[ordered]@{path='host/v4-guards.dll';sha256=$hash;size=1}) }
    'distribution-manifest' = [ordered]@{ formatVersion=1; id='v4-guards'; version='1.0.0'; rootDirectory='v4-guards-1.0.0'; source=[ordered]@{ commit=$commit; packageHash=$hash; contractsManifestSha256=$hash; hostSha256=$hash }; files=@([ordered]@{ path='package/plugin.json'; kind='package'; sha256=$hash; size=1 },[ordered]@{ path='host/v4-guards.dll'; kind='host'; sha256=$hash; size=1 }) }
    'install-receipt' = [ordered]@{ formatVersion=1; id=('a' * 32); status='installed'; version='1.0.0'; installRoot='C:/v4/v4-guards-1.0.0'; archiveSha256=$hash; manifestSha256=$hash; files=@([ordered]@{ path='distribution-manifest.json'; sha256=$hash; size=1 },[ordered]@{ path='package/plugin.json'; sha256=$hash; size=1 }) }
    'prerequisite-report' = [ordered]@{ formatVersion=1; status='pass'; exitCategory='success'; profile='default'; selectedModules=@(); requirements=@([ordered]@{ runtime='dotnet'; versionRange='>=10.0 <11.0'; sources=@('host'); status='pass'; detectedVersion='10.0.100'; executablePath='C:/dotnet/dotnet.exe' }) }
    'runtime-requirements' = [ordered]@{ formatVersion=1; requirements=@([ordered]@{ runtime='pwsh'; versionRange='>=7.4' },[ordered]@{ runtime='dotnet'; versionRange='>=10.0 <11.0' }) }
    'compatibility-baseline' = [ordered]@{ formatVersion=1; pluginVersion='1.0.0'; apiVersion='1.0'; files=@(1..12|ForEach-Object{[ordered]@{path="core/contracts/fixture-$_.json";role=if($_-eq1){'cli'}elseif($_-eq2){'configuration'}else{'report'};sha256=$hash}}) }
    'platform-certification' = [ordered]@{ formatVersion=1; status='pass'; platform='linux'; coverage='complete'; sourceCommit=$commit; packageHash=$hash; osDescription='Linux'; architecture='x64'; toolchain=[ordered]@{pwsh='7.5.0';dotnet='10.0.100';git='2.43.0'};tests=@([ordered]@{path='docs/guards/v4/tests/p0/Test-V4Contracts.ps1';sha256=$hash;resultSha256=$hash});secretEnvironmentNames=@() }
    'recovery-artifact' = [ordered]@{ formatVersion=1; candidateCommit=$commit; restoreCommit=('c'*40); packageHash=$hash; archiveSha256=$hash; compatibilityBaselineSha256=$hash; strategy='restore-reviewed-source-checkpoint'; verificationCommands=@('one','two','three'); remoteRollbackRequired=$false }
    'v1-certification' = [ordered]@{ formatVersion=1; id='v4-guards-v1-candidate'; version='1.0.0'; status='candidate'; sourceCommit=$commit; packageHash=$hash; archiveSha256=$hash; contractsManifestSha256=$hash; compatibilityBaselineSha256=$hash; platformReports=@([ordered]@{platform='linux';coverage='complete';path='platform/linux.json';sha256=$hash;testCount=1},[ordered]@{platform='windows';coverage='full';path='platform/windows.json';sha256=$hash;testCount=1});acceptance=@('P8.1-platforms','P8.2-lifecycle','P8.3-supply-chain','P8.4-compatibility-recovery','P8.5-v4-native-architecture');releaseAuthorized=$false;activeIfxCutover=$false;ifxProfileIncluded=$false;architectureRuntimeDependencies=@('pwsh','dotnet','roslyn','archunitnet') }
}

$fixtures['project-query'] = [ordered]@{ formatVersion=1; status='pass'; query='project'; authority='v4-host'; project=[ordered]@{ projectId=('c'*32); targetRoot='C:/target'; targetIdentityHash=$hash; bound=$false; profileId=$null; stateDocumentStatus='missing' }; roots=[ordered]@{ packageRoot='C:/package'; targetRoot='C:/target'; stateRoot='C:/state'; evidenceRoot='C:/evidence' } }
$fixtures['profile-catalog-query'] = [ordered]@{ formatVersion=1; status='pass'; query='profiles'; authority='v4-host'; profiles=@([ordered]@{ id='synthetic_profile'; version='1.0.0'; sha256=$hash; projectIdentityId='synthetic'; selectedModules=@('synthetic-probe'); stages=@('bootstrap','analysis','pre','post' | ForEach-Object { [ordered]@{ stage=$_; enabled=$true; modules=@('synthetic-probe') } }) }) }
$fixtures['prerequisite-query'] = [ordered]@{ formatVersion=1; status='pass'; query='doctor'; authority='v4-host'; report=(Clone $fixtures['prerequisite-report']) }
$fixtures['run-catalog-query'] = [ordered]@{ formatVersion=1; status='pass'; query='runs'; authority='v4-host'; projectId=('c'*32); runs=@([ordered]@{ runId=('d'*32); stage='analysis'; status='pass'; exitCategory='success'; profileId='synthetic_profile'; profileVersion='1.0.0'; resultSha256=$hash; executedStages=@('analysis'); findingCount=0; coverageCount=1 }) }
$fixtures['evidence-query'] = [ordered]@{ formatVersion=1; status='pass'; query='evidence'; authority='v4-host'; projectId=('c'*32); runId=('c'*32); resultSha256=$hash; stageResult=(Clone $fixtures['stage-result']); files=@([ordered]@{ path='runs/example/stage-result.json'; kind='stage-result'; sha256=$hash; size=1 }) }
$fixtures['plan-catalog-query'] = [ordered]@{ formatVersion=1; status='pass'; query='plans'; authority='v4-host'; planRoot='plans'; plans=@([ordered]@{ id='20260922-synthetic'; title='Synthetic'; kind='v4-native'; presentationMode='native-contract'; validation='v4-plan-valid'; jsonPath='plans/20260922-synthetic.plan.json'; markdownPath='plans/20260922-synthetic.md'; jsonSha256=$hash; markdownSha256=$hash }) }

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

$duplicateStages = Clone $fixtures['stage-result']
$duplicateStages.executedStages = @('analysis','analysis')
Invalid 'duplicate executed Stages' 'stage-result' $duplicateStages

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

$mixedPlanView = Clone $fixtures['plan-catalog-query']
$mixedPlanView.plans[0].presentationMode = 'historical-read-only'
Invalid 'mixed native and historical Plan presentation' 'plan-catalog-query' $mixedPlanView

$looseDoctor = Clone $fixtures['prerequisite-query']
$looseDoctor.report['unexpected'] = $true
Invalid 'doctor nested report unknown field' 'prerequisite-query' $looseDoctor

$looseEvidence = Clone $fixtures['evidence-query']
$looseEvidence.stageResult['unexpected'] = $true
Invalid 'evidence nested Stage result unknown field' 'evidence-query' $looseEvidence

$cliPath = Join-Path $contractRoot 'cli-contract.json'
$cli = Get-Content -Raw $cliPath | ConvertFrom-Json -AsHashtable -Depth 30
Valid 'cli-contract' $cli
$stableCommands = @($cli.commands | Where-Object stability -eq 'stable' | ForEach-Object id | Sort-Object)
$expectedCommands = @('contract.validate','plan.compose','plan.validate','reset.factory','reset.project','stage.run','version')
if (($stableCommands -join ',') -cne ($expectedCommands -join ',')) { $failures.Add('Stable CLI command identities drifted') }
$planValidate = @($cli.commands | Where-Object id -ceq 'plan.validate')[0]
$planCompose = @($cli.commands | Where-Object id -ceq 'plan.compose')[0]
$contractValidate = @($cli.commands | Where-Object id -ceq 'contract.validate')[0]
$resetProject = @($cli.commands | Where-Object id -ceq 'reset.project')[0]
$resetFactory = @($cli.commands | Where-Object id -ceq 'reset.factory')[0]
if ($contractValidate.syntax -cne 'v4-guards contract validate --package-root <path> --schema <id> --document <path>') { $failures.Add('Contract validate syntax drifted') }
if ($resetProject.syntax -notmatch '--package-root <path>') { $failures.Add('Project reset syntax omits PackageRoot') }
if ($resetFactory.syntax -notmatch '--package-root <path>') { $failures.Add('Factory reset syntax omits PackageRoot') }
if ($planValidate.syntax -cne 'v4-guards plan validate --package-root <path> --target-root <path> --plan <path>') { $failures.Add('Plan validate syntax drifted') }
if ($planCompose.syntax -cne 'v4-guards plan compose --package-root <path> --target-root <path> --evidence-root <path> --id <id> --plan <path>... --output <path>') { $failures.Add('Plan compose syntax drifted') }
$exitMap = @($cli.exitCategories | Sort-Object code | ForEach-Object { "$($_.id)=$($_.code)" })
$expectedExitMap = @('success=0','invalid-input=10','unsafe-path=11','integrity-failure=12','capability-denied=13','adapter-failure=14','prerequisite-missing=15','findings-blocking=16','state-conflict=17','reset-refused=18','internal-error=19')
if (($exitMap -join ',') -cne ($expectedExitMap -join ',')) { $failures.Add('Stable exit category mapping drifted') }

$queryPath = Join-Path $contractRoot 'query-contract.json'
$query = Get-Content -Raw $queryPath | ConvertFrom-Json -AsHashtable -Depth 30
Valid 'query-contract' $query
$queryCommands = @($query.commands | ForEach-Object id)
$expectedQueryCommands = @('query.project','query.profiles','query.doctor','query.runs','query.evidence','query.plans')
if (($queryCommands -join ',') -cne ($expectedQueryCommands -join ',')) { $failures.Add('Experimental query command identities drifted') }
if (@($query.commands | Where-Object { $_.stability -cne 'experimental' -or $_.mutability -cne 'read-only' }).Count -ne 0) {
    $failures.Add('A query command is not experimental and read-only')
}
$expectedQuerySchemas = @('project-query','profile-catalog-query','prerequisite-query','run-catalog-query','evidence-query','plan-catalog-query')
if ((@($query.commands | ForEach-Object resultSchema) -join ',') -cne ($expectedQuerySchemas -join ',')) { $failures.Add('Query result schema mapping drifted') }

$schemaNames = @('capability-matrix','ci-artifact-manifest','ci-contract','cli-contract','compatibility-baseline','distribution-manifest','evidence-query','finding-baseline','genesis-record','install-receipt','module-registry','module','plan-catalog-query','plan-set','plan','platform-certification','plugin','prerequisite-query','prerequisite-report','profile-catalog-query','profile','project-query','query-contract','recovery-artifact','reset-manifest','rule-execution-plan','run-catalog-query','runtime-requirements','stage-result','state','v1-certification')
foreach ($name in $schemaNames) {
    $schema = Get-Content -Raw (Schema $name) | ConvertFrom-Json -AsHashtable -Depth 50
    if ($schema.'$schema' -ne 'http://json-schema.org/draft-07/schema#' -or $schema.additionalProperties -ne $false -or -not $schema.ContainsKey('$id')) {
        $failures.Add("$name is not a strict identified draft-07 schema")
    }
}

$expectedManifestPaths = @($schemaNames | ForEach-Object { "core/contracts/$_.schema.json" }) + @('core/contracts/cli-contract.json','core/contracts/query-contract.json') | Sort-Object
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
Write-Host "V4 P0B contract tests passed: $($schemaNames.Count) schemas, $($cli.commands.Count) stable CLI entries, $($query.commands.Count) experimental read queries, $($manifest.files.Count) bound contracts."
