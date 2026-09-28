[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$sourceRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$sourcePackage = $sourceRoot
$workRoot = [IO.Path]::Combine([IO.Path]::GetTempPath(),'v4-guards-work',[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($sourceRoot))).Substring(0,12).ToLowerInvariant())
if(-not(Test-Path -LiteralPath (Join-Path $workRoot '.git'))){[void][IO.Directory]::CreateDirectory($workRoot);& git -C $workRoot init -q;& git -C $workRoot -c user.name=v4-guards-test -c user.email=v4-guards-test@example.invalid -c commit.gpgsign=false commit -q --allow-empty -m 'V4 test work root';if($LASTEXITCODE){throw 'V4 test work root initialization failed.'}}
$runRoot = Join-Path $workRoot 'p6/trusted-base'
$base = Join-Path $runRoot 'base'
$head = Join-Path $runRoot 'head'
$weak = Join-Path $runRoot 'weak'
$failures = [Collections.Generic.List[string]]::new()

function Write-Utf8([string] $Path, [string] $Text) { $parent=[IO.Path]::GetDirectoryName($Path);if(-not[IO.Directory]::Exists($parent)){[void][IO.Directory]::CreateDirectory($parent)};[IO.File]::WriteAllText($Path,$Text,[Text.UTF8Encoding]::new($false)) }
function Write-Json([string] $Path, $Value) { Write-Utf8 $Path ((($Value|ConvertTo-Json -Depth 100)+"`n").Replace("`r`n","`n")) }
function Invoke-Git([string] $Repository,[string[]] $Arguments){$output=@(& git.exe -c core.longpaths=true -C $Repository @Arguments 2>&1);if($LASTEXITCODE){throw "git $($Arguments-join' ') failed: $($output-join"`n")"};@($output|ForEach-Object{[string]$_})}
function Invoke-Runner([string] $RunnerRoot,[string[]] $Arguments){$runner=Join-Path $RunnerRoot 'integrations/github/Invoke-V4TrustedBase.ps1';$output=@(& pwsh -NoProfile -File $runner @Arguments 2>&1);[pscustomobject]@{Code=$LASTEXITCODE;Text=($output-join"`n")}}
function Expect($Run,[int]$Code,[string]$Name,[string]$Pattern=''){if($Run.Code-ne$Code-or($Pattern-and$Run.Text-notmatch$Pattern)){$failures.Add("${Name}: expected $Code/$Pattern, got $($Run.Code): $($Run.Text)")}}

if(Test-Path $runRoot){$resolved=[IO.Path]::GetFullPath($runRoot);$prefix=[IO.Path]::GetFullPath($workRoot).TrimEnd([IO.Path]::DirectorySeparatorChar)+[IO.Path]::DirectorySeparatorChar;if(-not$resolved.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)){throw "Unsafe cleanup: $resolved"};Remove-Item -LiteralPath $resolved -Recurse -Force}
[void][IO.Directory]::CreateDirectory($runRoot)
& git -c core.longpaths=true clone --quiet --no-local $sourceRoot $base;if($LASTEXITCODE){throw 'base clone failed'}
$contractPath=Join-Path $base 'integrations/github/ci-contract.json';$contract=Get-Content -Raw $contractPath|ConvertFrom-Json -AsHashtable -Depth 100;$testRelative='tests/p0/Test-V4Contracts.ps1';$testHash=(Get-FileHash -Algorithm SHA256 (Join-Path $base $testRelative)).Hash.ToLowerInvariant();$probeRelative='tests/p6/Test-V4IsolatedCommandProbe.ps1';$probePath=Join-Path $base $probeRelative;Write-Utf8 $probePath "`$ErrorActionPreference='Stop'`nif(`$IsWindows-and[string]::IsNullOrWhiteSpace(`$env:PATHEXT)){throw 'Isolated runner child has no PATHEXT.'}`n`$output=@(& git --version 2>&1);if(`$LASTEXITCODE){throw `"git is not resolvable in the isolated runner child: `$output`"}`n";$probeHash=(Get-FileHash -Algorithm SHA256 $probePath).Hash.ToLowerInvariant()
$contract.approvedTests=@([ordered]@{path=$testRelative;sha256=$testHash;linux=$true;windowsSmoke=$true;windowsFull=$true},[ordered]@{path=$probeRelative;sha256=$probeHash;linux=$true;windowsSmoke=$true;windowsFull=$true});Write-Json $contractPath $contract
Invoke-Git $base @('config','user.email','p6@example.invalid')|Out-Null;Invoke-Git $base @('config','user.name','V4 P6')|Out-Null;Invoke-Git $base @('add','--all')|Out-Null;Invoke-Git $base @('commit','-q','-m','p6 base')|Out-Null;$baseSha=(@(Invoke-Git $base @('rev-parse','HEAD')))[0]
& git -c core.longpaths=true clone --quiet --no-local $base $head;if($LASTEXITCODE){throw 'head clone failed'};Invoke-Git $head @('config','user.email','p6@example.invalid')|Out-Null;Invoke-Git $head @('config','user.name','V4 P6')|Out-Null
$candidatePlan='docs/plans/20260922-ci-candidate.plan.json';$candidateNote='docs/plans/product/ci-candidate-note.md'
Write-Utf8 (Join-Path $head $candidateNote) "# Candidate`n"
Write-Json (Join-Path $head $candidatePlan) ([ordered]@{formatVersion=1;id='20260922-ci-candidate';title='CI candidate';goal='Exercise trusted CI';acceptanceCriteria=@('Exact diff passes');plannedPaths=@($candidatePlan,$candidateNote);areas=@('ci');risks=@();decisions=@('V4-AD-012');validationCommands=@('v4-contract');dependencies=@();boundaries=@()})
Invoke-Git $head @('add','--all')|Out-Null;Invoke-Git $head @('commit','-q','-m','candidate')|Out-Null;$headSha=(@(Invoke-Git $head @('rev-parse','HEAD')))[0]

$contractEvidence=Join-Path $runRoot 'contract-evidence';$contractRun=Invoke-Runner $base @('-Mode','Contract','-HeadRoot',$head,'-BaseSha',$baseSha,'-HeadSha',$headSha,'-EvidenceRoot',$contractEvidence);Expect $contractRun 0 'contract positive' '"status": "pass"'
$contractResultPath=Join-Path $contractEvidence 'contract.json';if(Test-Path $contractResultPath){$contractResult=Get-Content -Raw $contractResultPath|ConvertFrom-Json;if($contractResult.rootPlan-cne$candidatePlan-or$contractResult.windowsRequired){$failures.Add('Contract result did not bind the exact ordinary Plan/classification.')}}else{$failures.Add("Contract report missing: $($contractRun.Text)")}
$overlap=Invoke-Runner $base @('-Mode','Contract','-HeadRoot',$head,'-BaseSha',$baseSha,'-HeadSha',$headSha,'-EvidenceRoot',(Join-Path $head 'artifacts/forbidden'));Expect $overlap 11 'authority-root overlap' 'overlaps an authority root'
$artifact=Join-Path $runRoot 'artifact';$linuxRun=Invoke-Runner $base @('-Mode','Linux','-HeadRoot',$head,'-BaseSha',$baseSha,'-HeadSha',$headSha,'-StateRoot',(Join-Path $runRoot 'linux-state'),'-EvidenceRoot',(Join-Path $runRoot 'linux-evidence'),'-ArtifactRoot',$artifact);Expect $linuxRun 0 'Linux producer' '"mode": "linux"';if($linuxRun.Text-notmatch[regex]::Escape($probeRelative)){$failures.Add('Linux producer did not run the isolated command probe.')}
$manifestPath=Join-Path $artifact 'manifest.json';if(-not(Test-Path $manifestPath)){throw "Linux artifact manifest missing: $($linuxRun.Text)"};if(-not(Test-Json -LiteralPath $manifestPath -SchemaFile (Join-Path $base 'core/contracts/ci-artifact-manifest.schema.json') -ErrorAction SilentlyContinue)){$failures.Add('Linux artifact manifest is invalid.')}
$manifest=Get-Content -Raw $manifestPath|ConvertFrom-Json;if(@($manifest.buildEvidence.secretEnvironmentNames).Count-ne0-or-not$manifest.buildEvidence.hostSha256){$failures.Add('Build Evidence is not secret-free and host-bound.')}
$packageRun=Invoke-Runner $base @('-Mode','Package','-HeadRoot',$head,'-BaseSha',$baseSha,'-HeadSha',$headSha,'-EvidenceRoot',(Join-Path $runRoot 'package-evidence'),'-ArtifactRoot',$artifact);Expect $packageRun 0 'Package artifact consumer' '"reusedArtifact": true'
$windowsRun=Invoke-Runner $base @('-Mode','Windows','-Coverage','smoke','-HeadRoot',$head,'-BaseSha',$baseSha,'-HeadSha',$headSha,'-StateRoot',(Join-Path $runRoot 'windows-state'),'-EvidenceRoot',(Join-Path $runRoot 'windows-evidence'),'-ArtifactRoot',$artifact);Expect $windowsRun 0 'Windows artifact consumer' '"reusedArtifact": true';if($windowsRun.Text-notmatch[regex]::Escape($probeRelative)){$failures.Add('Windows smoke did not run the isolated command probe (PATHEXT/git resolution).')}
if(@(Invoke-Git $head @('status','--porcelain','--untracked-files=no')).Count-ne0){$failures.Add('Trusted runner modified tracked HeadRoot files.')}
# V4-TODO-017 (O8) regression: a tracked path beyond the Windows MAX_PATH must not read as drift in the
# HeadRoot or in the runner's isolated target. The HeadRoot clone deliberately has no persisted long-path setting.
$deepHead=Join-Path $runRoot 'deep-head';& git -c core.longpaths=true clone --quiet --no-local $base $deepHead;if($LASTEXITCODE){throw 'deep head clone failed'};Invoke-Git $deepHead @('config','user.email','p6@example.invalid')|Out-Null;Invoke-Git $deepHead @('config','user.name','V4 P6')|Out-Null
$deepRelative='docs/plans/product/'+((1..9|ForEach-Object{"long-path-segment-$_-abcdefghij"})-join'/')+'/deep-candidate.md';$deepPlan='docs/plans/20260928-deep-candidate.plan.json'
Write-Utf8 (Join-Path $deepHead $deepRelative) "# Deep candidate`n"
Write-Json (Join-Path $deepHead $deepPlan) ([ordered]@{formatVersion=1;id='20260928-deep-candidate';title='Deep path candidate';goal='Exercise long tracked paths';acceptanceCriteria=@('Exact diff passes');plannedPaths=@($deepPlan,$deepRelative);areas=@('ci');risks=@();decisions=@('V4-TODO-017');validationCommands=@('v4-contract');dependencies=@();boundaries=@()})
Invoke-Git $deepHead @('add','--all')|Out-Null;Invoke-Git $deepHead @('commit','-q','-m','deep candidate')|Out-Null;$deepSha=(@(Invoke-Git $deepHead @('rev-parse','HEAD')))[0]
$deepState=Join-Path $runRoot ('deep-state-'+('s'*40));$deepTargetPath=Join-Path (Join-Path $deepState 'target') $deepRelative
if($IsWindows-and$deepTargetPath.Length-le260){$failures.Add("Long-path regression is vacuous: isolated target path length $($deepTargetPath.Length) does not exceed MAX_PATH.")}
$deepRun=Invoke-Runner $base @('-Mode','Linux','-HeadRoot',$deepHead,'-BaseSha',$baseSha,'-HeadSha',$deepSha,'-StateRoot',$deepState,'-EvidenceRoot',(Join-Path $runRoot 'deep-evidence'),'-ArtifactRoot',(Join-Path $runRoot 'deep-artifact'));Expect $deepRun 0 'long tracked path in HeadRoot and isolated target (V4-TODO-017)' '"mode": "linux"'

$hostArtifact=Join-Path $artifact 'host/v4-guards.dll';[IO.File]::AppendAllText($hostArtifact,'tamper',[Text.UTF8Encoding]::new($false));$tamper=Invoke-Runner $base @('-Mode','Package','-HeadRoot',$head,'-BaseSha',$baseSha,'-HeadSha',$headSha,'-EvidenceRoot',(Join-Path $runRoot 'tamper-evidence'),'-ArtifactRoot',$artifact);Expect $tamper 12 'artifact tamper' 'artifact file drift'
Write-Utf8 (Join-Path $head 'docs/plans/product/undeclared.md') "undeclared`n";Invoke-Git $head @('add','--all')|Out-Null;Invoke-Git $head @('commit','-q','-m','undeclared')|Out-Null;$badHeadSha=(@(Invoke-Git $head @('rev-parse','HEAD')))[0];$under=Invoke-Runner $base @('-Mode','Contract','-HeadRoot',$head,'-BaseSha',$baseSha,'-HeadSha',$badHeadSha,'-EvidenceRoot',(Join-Path $runRoot 'under-evidence'));Expect $under 16 'under-declared Plan' 'do not exactly match'

& git -c core.longpaths=true clone --quiet --no-local $base $weak;if($LASTEXITCODE){throw 'weak clone failed'};Invoke-Git $weak @('config','user.email','p6@example.invalid')|Out-Null;Invoke-Git $weak @('config','user.name','V4 P6')|Out-Null;[IO.File]::AppendAllText((Join-Path $weak $testRelative),"`n# weakening`n",[Text.UTF8Encoding]::new($false));Invoke-Git $weak @('add','--all')|Out-Null;Invoke-Git $weak @('commit','-q','-m','weaken test')|Out-Null;$weakSha=(@(Invoke-Git $weak @('rev-parse','HEAD')))[0]
$weakRun=Invoke-Runner $base @('-Mode','Linux','-HeadRoot',$weak,'-BaseSha',$baseSha,'-HeadSha',$weakSha,'-StateRoot',(Join-Path $runRoot 'weak-state'),'-EvidenceRoot',(Join-Path $runRoot 'weak-evidence'),'-ArtifactRoot',(Join-Path $runRoot 'weak-artifact'));Expect $weakRun 16 'candidate test weakening' 'Approved test hash drift without trust-change authorization'
$provenance=Invoke-Runner $base @('-Mode','Contract','-HeadRoot',$head,'-BaseSha',$badHeadSha,'-HeadSha',$badHeadSha,'-EvidenceRoot',(Join-Path $runRoot 'provenance-evidence'),'-Certification','-RequestedWindowsCoverage','full');if($provenance.Code-eq0){$failures.Add('Wrong trusted base provenance unexpectedly passed.')}

function New-Clone([string] $Source,[string] $Name){$path=Join-Path $runRoot $Name;& git -c core.longpaths=true clone --quiet --no-local $Source $path;if($LASTEXITCODE){throw "$Name clone failed"};Invoke-Git $path @('config','user.email','p6@example.invalid')|Out-Null;Invoke-Git $path @('config','user.name','V4 P6')|Out-Null;$path}
function FileHash([string] $Path){(Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()}
function Invoke-TrustCase([string] $Name,[string] $RunnerRoot,[string] $FromSha,[scriptblock] $Mutate,[string] $PlanId,[string[]] $Boundaries,[int] $Code,[string] $Pattern){
    Invoke-Git $trust @('checkout','-q','--detach',$FromSha)|Out-Null;& $Mutate;Invoke-Git $trust @('add','--all')|Out-Null
    $paths=@(Invoke-Git $trust @('-c','core.quotepath=false','diff','--cached','--name-only','--no-renames'));$planRelative="docs/plans/$PlanId.plan.json"
    Write-Json (Join-Path $trust $planRelative) ([ordered]@{formatVersion=1;id=$PlanId;title="P6 trust case $Name";goal='Exercise trust-change authorization';acceptanceCriteria=@('The trusted base decides the case');plannedPaths=@(@($paths)+@($planRelative)|Sort-Object -Unique -CaseSensitive);areas=@('ci');risks=@();decisions=@('V4-TODO-014');validationCommands=@('v4-contract');dependencies=@();boundaries=@($Boundaries)})
    Invoke-Git $trust @('add','--all')|Out-Null;Invoke-Git $trust @('commit','-q','-m',$Name)|Out-Null;$sha=(@(Invoke-Git $trust @('rev-parse','HEAD')))[0]
    $run=Invoke-Runner $RunnerRoot @('-Mode','Contract','-HeadRoot',$trust,'-BaseSha',$FromSha,'-HeadSha',$sha,'-EvidenceRoot',(Join-Path $runRoot "trust-$Name-evidence"));Expect $run $Code "trust $Name" $Pattern
    [pscustomobject]@{Sha=$sha;Run=$run;Evidence=(Join-Path $runRoot "trust-$Name-evidence/contract.json")}
}

$trust=New-Clone $base 'trust';$scratch=Join-Path $runRoot 'trust-scratch';[void][IO.Directory]::CreateDirectory($scratch)
$contractRelative='integrations/github/ci-contract.json';$runnerRelative='integrations/github/Invoke-V4TrustedBase.ps1';$certificationRelative='core/certification/Invoke-V4V1Certification.ps1';$productRelative='modules/synthetic-probe/adapter.ps1'
$authorizedTest=Join-Path $scratch 'test.ps1';Copy-Item -LiteralPath (Join-Path $base $testRelative) -Destination $authorizedTest;[IO.File]::AppendAllText($authorizedTest,"`n# P6 authorized change`n",[Text.UTF8Encoding]::new($false));$authorizedTestHash=FileHash $authorizedTest
$authorizedContractValue=Get-Content -Raw (Join-Path $base $contractRelative)|ConvertFrom-Json -AsHashtable -Depth 100;$authorizedContractValue.approvedTests[0].sha256=$authorizedTestHash;$authorizedContract=Join-Path $scratch 'ci-contract.json';Write-Json $authorizedContract $authorizedContractValue;$authorizedContractHash=FileHash $authorizedContract
$tcPlan='20260928-p6-trust-change';$recordId='20260928-p6-trust-record';$recordRelative="docs/plans/authorizations/$recordId.json"
$record=[ordered]@{formatVersion=1;id=$recordId;planId=$tcPlan;reason='P6 authorized approved-test change';entries=@([ordered]@{path=$testRelative;baseSha256=$testHash;headSha256=$authorizedTestHash},[ordered]@{path=$contractRelative;baseSha256=(FileHash (Join-Path $trust $contractRelative));headSha256=$authorizedContractHash});acceptedBy=[ordered]@{kind='human-review';authority='p6-operator';candidateHostVerdictAllowed=$false}}
$applyTest={Copy-Item -LiteralPath $authorizedTest -Destination (Join-Path $trust $testRelative) -Force;Copy-Item -LiteralPath $authorizedContract -Destination (Join-Path $trust $contractRelative) -Force}
$addRecord={Write-Json (Join-Path $trust $recordRelative) $record}
$touch={param([string]$Relative)[IO.File]::AppendAllText((Join-Path $trust $Relative),"`n# P6 change`n",[Text.UTF8Encoding]::new($false))}
$editContract={param([scriptblock]$Change)$path=Join-Path $trust $contractRelative;$value=Get-Content -Raw $path|ConvertFrom-Json -AsHashtable -Depth 100;& $Change $value;Write-Json $path $value}

[void](Invoke-TrustCase 'unauthorized-test' $base $baseSha $applyTest '20260928-p6-unauthorized-test' @() 16 'Approved test hash drift without trust-change authorization')
[void](Invoke-TrustCase 'unauthorized-runner' $base $baseSha {& $touch $runnerRelative} '20260928-p6-unauthorized-runner' @('trust-change') 16 'Unauthorized trusted-component change: integrations/github/Invoke-V4TrustedBase\.ps1')
[void](Invoke-TrustCase 'widened-scope' $base $baseSha {& $editContract {param($c)$c.allowedChangedPatterns=@($c.allowedChangedPatterns)+@('.github/**')}} '20260928-p6-widened-scope' @() 16 'Unauthorized trusted-component change: integrations/github/ci-contract\.json')
[void](Invoke-TrustCase 'reduced-windows' $base $baseSha {& $editContract {param($c)$c.windowsSensitivePatterns=@($c.windowsSensitivePatterns|Where-Object{$_ -cne 'tests/p6/**'})}} '20260928-p6-reduced-windows' @() 16 'Unauthorized trusted-component change: integrations/github/ci-contract\.json')
[void](Invoke-TrustCase 'certification-change' $base $baseSha {& $touch $certificationRelative} '20260928-p6-certification-change' @() 16 'Unauthorized trusted-component change: core/certification/')
$product=Invoke-TrustCase 'product-change' $base $baseSha {& $touch $productRelative} '20260928-p6-product-change' @() 0 '"status": "pass"'
[void](Invoke-TrustCase 'candidate-only-record' $base $baseSha {& $addRecord;& $applyTest} $tcPlan @('trust-change') 16 'no base-held authorization record')
[void](Invoke-TrustCase 'authorization-shape' $base $baseSha {& $addRecord;Write-Utf8 (Join-Path $trust 'docs/plans/product/p6-extra.md') "extra`n"} '20260928-p6-authorization' @('authorization') 16 'may only add authorization records')
[void](Invoke-TrustCase 'self-authorization' $base $baseSha {& $addRecord;& $applyTest} $tcPlan @('authorization','trust-change') 10 'Forbidden root Plan boundary combination')
$authorization=Invoke-TrustCase 'authorization' $base $baseSha $addRecord '20260928-p6-authorization' @('authorization') 0 '"status": "authorization-added"'

Invoke-Git $trust @('branch','p6-authorized',$authorization.Sha)|Out-Null;$authorizedBase=New-Clone $trust 'base-authorized';Invoke-Git $authorizedBase @('checkout','-q','--detach',$authorization.Sha)|Out-Null;$authorizedSha=$authorization.Sha;$policy=Get-Content -Raw (Join-Path $authorizedBase 'integrations/github/trust-policy.json')|ConvertFrom-Json
$consume={& $applyTest;Remove-Item -LiteralPath (Join-Path $trust $recordRelative)}
$trustChange=Invoke-TrustCase 'trust-change' $authorizedBase $authorizedSha $consume $tcPlan @('trust-change') 0 '"status": "authorized"'
if($trustChange.Run.Code-eq0){$trustResult=Get-Content -Raw $trustChange.Evidence|ConvertFrom-Json
    $expected=@($policy.verdictComponents|ForEach-Object{"${_}:$(FileHash (Join-Path $authorizedBase $_))"})-join"`n";$actual=@($trustResult.verdictComponents|ForEach-Object{"$($_.path):$($_.sha256)"})-join"`n"
    if($actual-cne$expected){$failures.Add('Contract result verdictComponents do not equal the judging base component hashes.')}
    if($trustResult.trustChange.authorization-cne$recordRelative-or((@($trustResult.trustChange.protectedPaths)|Sort-Object)-join',')-cne((@($testRelative,$contractRelative)|Sort-Object)-join',')){$failures.Add('Contract result did not bind the consumed authorization.')}}
$trustArtifact=Join-Path $runRoot 'trust-artifact';$trustLinux=Invoke-Runner $authorizedBase @('-Mode','Linux','-HeadRoot',$trust,'-BaseSha',$authorizedSha,'-HeadSha',$trustChange.Sha,'-StateRoot',(Join-Path $runRoot 'trust-linux-state'),'-EvidenceRoot',(Join-Path $runRoot 'trust-linux-evidence'),'-ArtifactRoot',$trustArtifact);Expect $trustLinux 0 'trust Linux authorized drift' '"status": "authorized"'
if($trustLinux.Code-eq0){if(@((Get-Content -Raw (Join-Path $trustArtifact 'manifest.json')|ConvertFrom-Json).verdictComponents).Count-ne@($policy.verdictComponents).Count){$failures.Add('CI artifact manifest does not carry the verdict components.')}}
[void](Invoke-TrustCase 'head-mismatch' $authorizedBase $authorizedSha {& $consume;& $touch $testRelative} $tcPlan @('trust-change') 16 'Authorization hash mismatch: tests/p0/Test-V4Contracts\.ps1')
[void](Invoke-TrustCase 'unconsumed' $authorizedBase $authorizedSha $applyTest $tcPlan @('trust-change') 16 'was not consumed in the same diff')
[void](Invoke-TrustCase 'partial' $authorizedBase $authorizedSha {& $consume;& $touch $runnerRelative} $tcPlan @('trust-change') 16 'not covered by the authorization: integrations/github/Invoke-V4TrustedBase\.ps1')
[void](Invoke-TrustCase 'record-deletion' $authorizedBase $authorizedSha {Remove-Item -LiteralPath (Join-Path $trust $recordRelative)} '20260928-p6-record-deletion' @() 16 'Authorization records change only through an authorization Plan')

if($failures.Count){throw ($failures-join"`n")}
Write-Host 'V4 P6 trusted-base tests passed: exact Plan, root isolation, isolated Linux producer, immutable Package/Windows reuse, isolated-child command resolution (PATHEXT), long tracked paths (V4-TODO-017), tamper, under-declaration, test weakening and provenance negatives; trust-change authorization (authorized drift, record shape, hash binding, consumption, coverage, candidate-only records, CI-contract widening, certification and runner protection, unprotected product code, verdict component identity).'
