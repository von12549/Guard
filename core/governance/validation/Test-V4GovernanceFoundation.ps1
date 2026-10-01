[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$packageRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$workKey = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($packageRoot))).Substring(0,12).ToLowerInvariant()
$workRoot = [IO.Path]::Combine([IO.Path]::GetTempPath(),'v4-guards-work',$workKey,'m5-governance')
$buildRoot = Join-Path $packageRoot 'build'
$project = Join-Path $packageRoot 'core/host/V4.Guards.Host/V4.Guards.Host.csproj'
$dll = Join-Path $workRoot 'build/bin/V4.Guards.Host/debug/v4-guards.dll'
$failures = [Collections.Generic.List[string]]::new()

function Write-Utf8([string] $Path, [string] $Text) { $parent=[IO.Path]::GetDirectoryName($Path);if(-not[IO.Directory]::Exists($parent)){[void][IO.Directory]::CreateDirectory($parent)};[IO.File]::WriteAllText($Path,$Text,[Text.UTF8Encoding]::new($false)) }
function Write-Json([string] $Path, $Value) { Write-Utf8 $Path (($Value|ConvertTo-Json -Depth 100)+"`n") }
function Hash-Text([string] $Text) { [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($Text))).ToLowerInvariant() }
function Hash([string] $Path) { (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant() }
function Run([string[]] $Arguments) { $text=@(& dotnet $dll @Arguments 2>&1)-join"`n";[pscustomobject]@{Code=$LASTEXITCODE;Text=$text} }
function Expect($Run,[int]$Code,[string]$Name,[string]$Pattern=''){if($Run.Code-ne$Code -or ($Pattern-and$Run.Text-notmatch$Pattern)){$failures.Add("${Name}: expected $Code/$Pattern, got $($Run.Code): $($Run.Text)")}}
function Plan([string]$Id,[string[]]$Paths,[string[]]$Dependencies=@(),[int]$Commands=1,[int]$Entries=1){[ordered]@{formatVersion=1;id=$Id;title="Plan $Id";goal='Governed test';acceptanceCriteria=@('observable');plannedPaths=@($Paths);areas=@('governance');risks=@(1..$Entries|ForEach-Object{"risk-$Id-$_"});decisions=@();validationCommands=@(1..$Commands|ForEach-Object{"command-$Id-$_"});dependencies=@($Dependencies);boundaries=@()}}
function Invoke-Git([string]$Root,[string[]]$Arguments){$text=@(& git -C $Root @Arguments 2>&1)-join"`n";if($LASTEXITCODE){throw "git $($Arguments -join ' ') failed: $text"};$text.Trim()}
function Commit([string]$Root,[string]$Message){Invoke-Git $Root @('add','-A')|Out-Null;Invoke-Git $Root @('-c','user.name=v4-m5-test','-c','user.email=v4-m5@example.invalid','-c','commit.gpgsign=false','commit','-q','-m',$Message)|Out-Null;Invoke-Git $Root @('rev-parse','HEAD')}

if(Test-Path $workRoot){$full=[IO.Path]::GetFullPath($workRoot);$safe=[IO.Path]::GetFullPath([IO.Path]::Combine([IO.Path]::GetTempPath(),'v4-guards-work')).TrimEnd([IO.Path]::DirectorySeparatorChar)+[IO.Path]::DirectorySeparatorChar;if(-not$full.StartsWith($safe,[StringComparison]::OrdinalIgnoreCase)){throw "Unsafe cleanup: $full"};Remove-Item -LiteralPath $full -Recurse -Force}
[void][IO.Directory]::CreateDirectory($workRoot)
$oldAppData=$env:APPDATA
if($IsWindows){$env:APPDATA=Join-Path $workRoot 'appdata';[void][IO.Directory]::CreateDirectory($env:APPDATA)}
$properties=@('-p:ImportDirectoryBuildProps=false','-p:ImportDirectoryBuildTargets=false','-p:ImportDirectoryPackagesProps=false','-p:ImportDirectorySolutionProps=false','-p:ImportDirectorySolutionTargets=false',"-p:CustomBeforeMicrosoftCommonProps=$(Join-Path $buildRoot 'V4.Build.props')")
Push-Location $buildRoot
try{& dotnet restore $project --configfile (Join-Path $buildRoot 'NuGet.config') --artifacts-path (Join-Path $workRoot 'build') -nologo @properties;if($LASTEXITCODE){throw 'M5 governance restore failed.'};& dotnet build $project --no-restore --artifacts-path (Join-Path $workRoot 'build') -nologo @properties;if($LASTEXITCODE){throw 'M5 governance build failed.'}}
finally{Pop-Location;if($IsWindows){$env:APPDATA=$oldAppData}}

$catalog=Get-Content -Raw (Join-Path $packageRoot 'core/governance/governance-contract.json')|ConvertFrom-Json -AsHashtable -Depth 100
foreach($entry in $catalog.files){$path=Join-Path $packageRoot $entry.path;if(-not(Test-Path $path)-or(Hash $path)-cne[string]$entry.sha256){$failures.Add("Governance catalog drift: $($entry.path)")}}
foreach($schema in @('plan-authoring','target-trust-policy','target-trust-authorization')){if(-not(Test-Json -LiteralPath (Join-Path $packageRoot "core/governance/contracts/$schema.schema.json") -ErrorAction SilentlyContinue)){$failures.Add("Invalid governance schema JSON: $schema")}}

$target=Join-Path $workRoot 'plan-target';$evidence=Join-Path $workRoot 'plan-evidence';[void][IO.Directory]::CreateDirectory($target);[void][IO.Directory]::CreateDirectory($evidence)
$scaffold=Run @('plan','scaffold','--package-root',$packageRoot,'--evidence-root',$evidence,'--id','20261001-scaffold-test','--output','proposal.json')
Expect $scaffold 0 'proposal scaffold' '"authoritative": false'
if(-not(Test-Json -LiteralPath (Join-Path $evidence 'proposal.json') -SchemaFile (Join-Path $packageRoot 'core/governance/contracts/plan-authoring.schema.json') -ErrorAction SilentlyContinue)){$failures.Add('Scaffold proposal violates authoring schema.')}

$paths=@();for($i=0;$i-lt17;$i++){$relative="plans/20261001-limit-$i.plan.json";$paths+=$relative;Write-Json (Join-Path $target $relative) (Plan "20261001-limit-$i" @("src/$i.txt"))}
$args=@('plan','compose','--package-root',$packageRoot,'--target-root',$target,'--evidence-root',$evidence,'--id','20261001-member-limit');foreach($path in $paths){$args+=@('--plan',$path)};$args+=@('--output','member-limit.json');Expect (Run $args) 10 'member limit' '16-member limit'
$large=Plan '20261001-large-plan' @('src/large.txt');$large.title='x'*(1024*1024);Write-Json (Join-Path $target 'plans/large.plan.json') $large;Expect (Run @('plan','validate','--package-root',$packageRoot,'--target-root',$target,'--plan','plans/large.plan.json')) 10 'per-Plan byte limit' '1048576-byte'
$chain=@();for($i=0;$i-lt9;$i++){$relative="plans/20261001-depth-$i.plan.json";$chain+=$relative;$document=if($i){Plan "20261001-depth-$i" @("depth/$i") @("20261001-depth-$($i-1)")}else{Plan "20261001-depth-$i" @("depth/$i")};Write-Json (Join-Path $target $relative) $document};$args=@('plan','compose','--package-root',$packageRoot,'--target-root',$target,'--evidence-root',$evidence,'--id','20261001-depth-limit');foreach($path in $chain){$args+=@('--plan',$path)};$args+=@('--output','depth-limit.json');Expect (Run $args) 10 'dependency depth limit' 'depth limit of 8'
Write-Json (Join-Path $target 'plans/commands.plan.json') (Plan '20261001-command-limit' @('commands') @() 257);Write-Json (Join-Path $target 'plans/peer.plan.json') (Plan '20261001-peer' @('peer'));Expect (Run @('plan','compose','--package-root',$packageRoot,'--target-root',$target,'--evidence-root',$evidence,'--id','20261001-command-limit-set','--plan','plans/commands.plan.json','--plan','plans/peer.plan.json','--output','commands.json')) 10 'command limit' '256-validation-command'
Write-Json (Join-Path $target 'plans/entries.plan.json') (Plan '20261001-entry-limit' @('entries') @() 1 257);Expect (Run @('plan','compose','--package-root',$packageRoot,'--target-root',$target,'--evidence-root',$evidence,'--id','20261001-entry-limit-set','--plan','plans/entries.plan.json','--plan','plans/peer.plan.json','--output','entries.json')) 10 'risk decision limit' '256 combined'
$pathPlan=Plan '20261001-path-limit' @(0..4096|ForEach-Object{"paths/$_"});Write-Json (Join-Path $target 'plans/paths.plan.json') $pathPlan;Expect (Run @('plan','compose','--package-root',$packageRoot,'--target-root',$target,'--evidence-root',$evidence,'--id','20261001-path-limit-set','--plan','plans/paths.plan.json','--plan','plans/peer.plan.json','--output','paths.json')) 10 'planned path limit' '4096-path'
$aggregatePaths=@();for($i=0;$i-lt9;$i++){$relative="plans/20261001-aggregate-$i.plan.json";$aggregatePaths+=$relative;$document=Plan "20261001-aggregate-$i" @("aggregate/$i");$document.title=('x'*950000);Write-Json (Join-Path $target $relative) $document};$args=@('plan','compose','--package-root',$packageRoot,'--target-root',$target,'--evidence-root',$evidence,'--id','20261001-aggregate-limit');foreach($path in $aggregatePaths){$args+=@('--plan',$path)};$args+=@('--output','aggregate.json');Expect (Run $args) 10 'aggregate byte limit' '8388608-byte aggregate'

$finalRepo=Join-Path $workRoot 'finalize-repo';[void][IO.Directory]::CreateDirectory($finalRepo);Invoke-Git $finalRepo @('init','-q')|Out-Null;Write-Utf8 (Join-Path $finalRepo 'owned.txt') "base`n";$base=Commit $finalRepo 'base';Write-Utf8 (Join-Path $finalRepo 'owned.txt') "head`n";$head=Commit $finalRepo 'head'
$proposal=[ordered]@{formatVersion=1;state='proposal';plan=(Plan '20261001-finalized-test' @('owned.txt'));unresolvedQuestions=@()};$proposalPath=Join-Path $evidence 'finalize.json';Write-Json $proposalPath $proposal;$proposalHash=Hash $proposalPath
$final=Run @('plan','finalize','--package-root',$packageRoot,'--target-root',$finalRepo,'--evidence-root',$evidence,'--input','finalize.json','--output-directory','finalized','--base-ref',$base,'--head-ref',$head,'--confirm-proposal-sha256',$proposalHash,'--source-id','operator-input','--generator-id','v4-host-m5','--policy-id','v4-m5-plan-governance')
Expect $final 0 'exact finalization' '"state": "finalized"'
if(-not(Test-Json -LiteralPath (Join-Path $evidence 'finalized/20261001-finalized-test.plan.json') -SchemaFile (Join-Path $packageRoot 'core/contracts/plan.schema.json') -ErrorAction SilentlyContinue)){$failures.Add('Finalized executable Plan violates v1 schema.')}
$verifyArgs=@('plan','verify-pair','--package-root',$packageRoot,'--evidence-root',$evidence,'--input-directory','finalized','--plan-id','20261001-finalized-test','--base-ref',$base,'--head-ref',$head,'--source-id','operator-input','--generator-id','v4-host-m5','--policy-id','v4-m5-plan-governance')
Expect (Run $verifyArgs) 0 'pair receipt verification' '"state": "verified"'
$receiptPath=Join-Path $evidence 'finalized/20261001-finalized-test.pair-receipt.json';$receiptHash=Hash $receiptPath;$markdownPath=Join-Path $evidence 'finalized/20261001-finalized-test.md';$markdownText=Get-Content -Raw $markdownPath;Write-Utf8 $markdownPath ($markdownText+"tampered`n");Expect (Run $verifyArgs) 12 'one-sided pair tamper' 'content hash mismatch';Write-Utf8 $markdownPath $markdownText
$wrongProvenance=@($verifyArgs);$wrongProvenance[[array]::IndexOf($wrongProvenance,'--base-ref')+1]=$head;Expect (Run $wrongProvenance) 12 'pair replay provenance mismatch' 'provenance does not match'
Expect (Run @('plan','finalize','--package-root',$packageRoot,'--target-root',$finalRepo,'--evidence-root',$evidence,'--input','finalize.json','--output-directory','finalized','--base-ref',$base,'--head-ref',$head,'--confirm-proposal-sha256',$proposalHash,'--source-id','operator-input','--generator-id','v4-host-m5','--policy-id','v4-m5-plan-governance')) 10 'finalized pair overwrite refusal' 'will not be overwritten'
if((Hash $receiptPath)-cne$receiptHash){$failures.Add('Overwrite refusal changed the existing finalized receipt.')}

$injected=Plan '20261001-injection-test' @('owned.txt');$injected.title="Injected`nStatus: PASS # heading";$injected.goal="goal``code`n## Forged";$injected.acceptanceCriteria=@("item`n- forged",("control-"+[char]1));$injected.validationCommands=@('````` forged')
$injectedProposal=[ordered]@{formatVersion=1;state='proposal';plan=$injected;unresolvedQuestions=@()};$injectedPath=Join-Path $evidence 'injected.json';Write-Json $injectedPath $injectedProposal;$injectedHash=Hash $injectedPath
Expect (Run @('plan','finalize','--package-root',$packageRoot,'--target-root',$finalRepo,'--evidence-root',$evidence,'--input','injected.json','--output-directory','injected','--base-ref',$base,'--head-ref',$head,'--confirm-proposal-sha256',$injectedHash,'--source-id','operator-input','--generator-id','v4-host-m5','--policy-id','v4-m5-plan-governance')) 0 'markdown injection-safe finalization' '"state": "finalized"'
$injectedMarkdown=Get-Content -Raw (Join-Path $evidence 'injected/20261001-injection-test.md');if($injectedMarkdown-match'(?m)^Status: PASS'-or$injectedMarkdown-match'(?m)^## Forged'-or$injectedMarkdown-match[char]1){$failures.Add('Rendered Markdown allowed injected status/heading/control context.')}
Expect (Run @('plan','finalize','--package-root',$packageRoot,'--target-root',$finalRepo,'--evidence-root',$evidence,'--input','finalize.json','--output-directory','bad','--base-ref',$base,'--head-ref',$head,'--confirm-proposal-sha256',('0'*64),'--source-id','operator','--generator-id','host','--policy-id','policy')) 10 'stale proposal refusal' 'confirmation does not match'

function Trust-Plan([string]$Id,[string[]]$Paths,[string[]]$Boundaries=@()){[ordered]@{formatVersion=1;id=$Id;title="Trust Plan $Id";goal='Exercise revision-bound target trust';acceptanceCriteria=@('Exact candidate diff is governed');plannedPaths=@($Paths);areas=@('governance');risks=@();decisions=@();validationCommands=@('verify');dependencies=@();boundaries=@($Boundaries)}}
function New-TrustCase([string]$Name,[string]$Mode){
    $root=Join-Path $workRoot "trust-$Name";[void][IO.Directory]::CreateDirectory($root);Invoke-Git $root @('init','-q')|Out-Null;Invoke-Git $root @('config','core.autocrlf','false')|Out-Null
    $policy=[ordered]@{formatVersion=1;id='consumer-trust';authorizationDirectory='.guard/authorizations';protectedPaths=@('.guard/trust-policy.json','.guard/authorizations/**','.github/workflows/**','.guard/profile.json')}
    Write-Json (Join-Path $root '.guard/trust-policy.json') $policy;Write-Utf8 (Join-Path $root '.github/workflows/guard.yml') "old`n";Write-Utf8 (Join-Path $root '.guard/profile.json') "old-profile`n";$seed=Commit $root 'seed'
    $oldHash=Hash-Text "old`n";$newHash=Hash-Text "new`n";$profileOld=Hash-Text "old-profile`n";$profileNew=Hash-Text "new-profile`n"
    $entryHead=if($Mode-eq'hash-mismatch'){'f'*64}else{$newHash};$entries=@([ordered]@{path='.github/workflows/guard.yml';baseSha256=$oldHash;headSha256=$entryHead})
    if($Mode-ne'partial'){$entries+=@([ordered]@{path='.guard/profile.json';baseSha256=$profileOld;headSha256=$profileNew})}
    $authorization=[ordered]@{formatVersion=1;id='20261001-consumer-change-authorization';planId='20261001-consumer-change';policyId='consumer-trust';entries=$entries;acceptedBy=[ordered]@{kind='human-review';authority='fixture-operator';candidateHostVerdictAllowed=$false}}
    if($Mode-ne'candidate-only'){Write-Json (Join-Path $root '.guard/authorizations/change.json') $authorization;$authBase=Commit $root 'authorization'}else{$authBase=$seed}
    Write-Utf8 (Join-Path $root '.github/workflows/guard.yml') "new`n";Write-Utf8 (Join-Path $root '.guard/profile.json') "new-profile`n"
    if($Mode-eq'candidate-only'){Write-Json (Join-Path $root '.guard/authorizations/change.json') $authorization}elseif($Mode-ne'reused'){Remove-Item -LiteralPath (Join-Path $root '.guard/authorizations/change.json')}
    $planPath='docs/consumer.plan.json';$peerPath='docs/peer.plan.json';$setPath='docs/plan-set.json';$authPath='.guard/authorizations/change.json'
    $owned=@('.github/workflows/guard.yml','.guard/profile.json');if($Mode-ne'reused'){$owned+=$authPath};if($Mode-eq'omission'){$owned=@('.github/workflows/guard.yml',$authPath)}
    $boundaries=if($Mode-eq'self-authorizing'){@('authorization')}else{@('trust-change')}
    Write-Json (Join-Path $root $planPath) (Trust-Plan '20261001-consumer-change' $owned $boundaries)
    Write-Json (Join-Path $root $peerPath) (Trust-Plan '20261001-consumer-peer' @($planPath,$peerPath,$setPath))
    $composeRoot=Join-Path $workRoot "compose-$Name";[void][IO.Directory]::CreateDirectory($composeRoot)
    $compose=Run @('plan','compose','--package-root',$packageRoot,'--target-root',$root,'--evidence-root',$composeRoot,'--id','20261001-consumer-set','--plan',$planPath,'--plan',$peerPath,'--output','plan-set.json')
    if($compose.Code){throw "Trust fixture composition failed for ${Name}: $($compose.Text)"}
    Copy-Item -LiteralPath (Join-Path $composeRoot 'plan-set.json') -Destination (Join-Path $root $setPath)
    if($Mode-eq'forged-hash'){$set=Get-Content -Raw (Join-Path $root $setPath)|ConvertFrom-Json -AsHashtable -Depth 100;$set.members[0].sha256='f'*64;Write-Json (Join-Path $root $setPath) $set}
    if($Mode-eq'composition'){$set=Get-Content -Raw (Join-Path $root $setPath)|ConvertFrom-Json -AsHashtable -Depth 100;$set.compositionHash='f'*64;Write-Json (Join-Path $root $setPath) $set}
    if($Mode-eq'wrong-union'){$set=Get-Content -Raw (Join-Path $root $setPath)|ConvertFrom-Json -AsHashtable -Depth 100;$set.derivedUnion.plannedPaths=@($set.derivedUnion.plannedPaths|Where-Object{$_-cne'.guard/profile.json'});Write-Json (Join-Path $root $setPath) $set}
    if($Mode-eq'duplicate'){$set=Get-Content -Raw (Join-Path $root $setPath)|ConvertFrom-Json -AsHashtable -Depth 100;$set.members[1].planId=$set.members[0].planId;Write-Json (Join-Path $root $setPath) $set}
    if($Mode-eq'missing-plan'){Remove-Item -LiteralPath (Join-Path $root $planPath)}
    $candidate=Commit $root 'candidate'
    [pscustomobject]@{Root=$root;Base=$authBase;Head=$candidate}
}
$valid=New-TrustCase 'valid' 'valid';Expect (Run @('target-trust','validate','--package-root',$packageRoot,'--target-root',$valid.Root,'--policy','.guard/trust-policy.json','--authorization','.guard/authorizations/change.json','--plan-set','docs/plan-set.json','--base-ref',$valid.Base,'--head-ref',$valid.Head)) 0 'valid target trust' '"authorizationConsumed": true'
Write-Utf8 (Join-Path $valid.Root 'docs/consumer.plan.json') "working-tree drift must not be read`n";Expect (Run @('target-trust','validate','--package-root',$packageRoot,'--target-root',$valid.Root,'--policy','.guard/trust-policy.json','--authorization','.guard/authorizations/change.json','--plan-set','docs/plan-set.json','--base-ref',$valid.Base,'--head-ref',$valid.Head)) 0 'revision bytes ignore working tree drift' '"authorizationConsumed": true'
foreach($caseName in @('candidate-only','reused','partial','hash-mismatch','self-authorizing','forged-hash','missing-plan','composition','wrong-union','duplicate','omission')){$case=New-TrustCase $caseName $caseName;Expect (Run @('target-trust','validate','--package-root',$packageRoot,'--target-root',$case.Root,'--policy','.guard/trust-policy.json','--authorization','.guard/authorizations/change.json','--plan-set','docs/plan-set.json','--base-ref',$case.Base,'--head-ref',$case.Head)) $(if($caseName-in@('candidate-only','missing-plan')){12}else{16}) "target trust $caseName"}

if($failures.Count){throw($failures-join"`n")}
Write-Host 'V4 M5 governance tests passed: contract binding, Plan limits/finalization and base-held target authorization negatives.'
