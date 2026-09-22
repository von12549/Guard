[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$sourceRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../../..'))
$sourcePackage = Join-Path $sourceRoot 'docs/guards/v4'
$runRoot = Join-Path $sourceRoot 'artifacts/guards/v4/p6/trusted-base'
$base = Join-Path $runRoot 'base'
$head = Join-Path $runRoot 'head'
$weak = Join-Path $runRoot 'weak'
$failures = [Collections.Generic.List[string]]::new()

function Write-Utf8([string] $Path, [string] $Text) { $parent=[IO.Path]::GetDirectoryName($Path);if(-not[IO.Directory]::Exists($parent)){[void][IO.Directory]::CreateDirectory($parent)};[IO.File]::WriteAllText($Path,$Text,[Text.UTF8Encoding]::new($false)) }
function Write-Json([string] $Path, $Value) { Write-Utf8 $Path (($Value|ConvertTo-Json -Depth 100)+"`n") }
function Invoke-Git([string] $Repository,[string[]] $Arguments){$output=@(& git.exe -C $Repository @Arguments 2>&1);if($LASTEXITCODE){throw "git $($Arguments-join' ') failed: $($output-join"`n")"};@($output|ForEach-Object{[string]$_})}
function Invoke-Runner([string] $RunnerRoot,[string[]] $Arguments){$runner=Join-Path $RunnerRoot 'docs/guards/v4/integrations/github/Invoke-V4TrustedBase.ps1';$output=@(& pwsh -NoProfile -File $runner @Arguments 2>&1);[pscustomobject]@{Code=$LASTEXITCODE;Text=($output-join"`n")}}
function Expect($Run,[int]$Code,[string]$Name,[string]$Pattern=''){if($Run.Code-ne$Code-or($Pattern-and$Run.Text-notmatch$Pattern)){$failures.Add("${Name}: expected $Code/$Pattern, got $($Run.Code): $($Run.Text)")}}

if(Test-Path $runRoot){$resolved=[IO.Path]::GetFullPath($runRoot);$prefix=[IO.Path]::GetFullPath((Join-Path $sourceRoot 'artifacts/guards/v4')).TrimEnd([IO.Path]::DirectorySeparatorChar)+[IO.Path]::DirectorySeparatorChar;if(-not$resolved.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)){throw "Unsafe cleanup: $resolved"};Remove-Item -LiteralPath $resolved -Recurse -Force}
[void][IO.Directory]::CreateDirectory($runRoot)
& git clone --quiet --no-local $sourceRoot $base;if($LASTEXITCODE){throw 'base clone failed'}
$formalPlan=Get-Content -Raw (Join-Path $sourceRoot 'docs/guards/plans/20260922-v4-p6-linux-first-ci.plan.json')|ConvertFrom-Json
foreach($relative in $formalPlan.plannedPaths){$source=Join-Path $sourceRoot $relative;$destination=Join-Path $base $relative;if(-not(Test-Path $source)){throw "P6 planned source missing: $relative"};$parent=Split-Path -Parent $destination;if(-not(Test-Path $parent)){[void][IO.Directory]::CreateDirectory($parent)};Copy-Item -LiteralPath $source -Destination $destination -Force}
$contractPath=Join-Path $base 'docs/guards/v4/integrations/github/ci-contract.json';$contract=Get-Content -Raw $contractPath|ConvertFrom-Json -AsHashtable -Depth 100;$testRelative='docs/guards/v4/tests/p0/Test-V4Contracts.ps1';$testHash=(Get-FileHash -Algorithm SHA256 (Join-Path $base $testRelative)).Hash.ToLowerInvariant();$contract.approvedTests=@([ordered]@{path=$testRelative;sha256=$testHash;linux=$true;windowsSmoke=$true;windowsFull=$true});Write-Json $contractPath $contract
Invoke-Git $base @('config','user.email','p6@example.invalid')|Out-Null;Invoke-Git $base @('config','user.name','V4 P6')|Out-Null;Invoke-Git $base @('add','--all')|Out-Null;Invoke-Git $base @('commit','-q','-m','p6 base')|Out-Null;$baseSha=(@(Invoke-Git $base @('rev-parse','HEAD')))[0]
& git clone --quiet --no-local $base $head;if($LASTEXITCODE){throw 'head clone failed'};Invoke-Git $head @('config','user.email','p6@example.invalid')|Out-Null;Invoke-Git $head @('config','user.name','V4 P6')|Out-Null
$candidatePlan='docs/guards/plans/20260922-ci-candidate.plan.json';$candidateNote='docs/guards/v4/plans/ci-candidate-note.md'
Write-Utf8 (Join-Path $head $candidateNote) "# Candidate`n"
Write-Json (Join-Path $head $candidatePlan) ([ordered]@{formatVersion=1;id='20260922-ci-candidate';title='CI candidate';goal='Exercise trusted CI';acceptanceCriteria=@('Exact diff passes');plannedPaths=@($candidatePlan,$candidateNote);areas=@('ci');risks=@();decisions=@('V4-AD-012');validationCommands=@('v4-contract');dependencies=@();boundaries=@()})
Invoke-Git $head @('add','--all')|Out-Null;Invoke-Git $head @('commit','-q','-m','candidate')|Out-Null;$headSha=(@(Invoke-Git $head @('rev-parse','HEAD')))[0]

$contractEvidence=Join-Path $runRoot 'contract-evidence';$contractRun=Invoke-Runner $base @('-Mode','Contract','-HeadRoot',$head,'-BaseSha',$baseSha,'-HeadSha',$headSha,'-EvidenceRoot',$contractEvidence);Expect $contractRun 0 'contract positive' '"status": "pass"'
$contractResultPath=Join-Path $contractEvidence 'contract.json';if(Test-Path $contractResultPath){$contractResult=Get-Content -Raw $contractResultPath|ConvertFrom-Json;if($contractResult.rootPlan-cne$candidatePlan-or$contractResult.windowsRequired){$failures.Add('Contract result did not bind the exact ordinary Plan/classification.')}}else{$failures.Add("Contract report missing: $($contractRun.Text)")}
$overlap=Invoke-Runner $base @('-Mode','Contract','-HeadRoot',$head,'-BaseSha',$baseSha,'-HeadSha',$headSha,'-EvidenceRoot',(Join-Path $head 'artifacts/forbidden'));Expect $overlap 11 'authority-root overlap' 'overlaps an authority root'
$artifact=Join-Path $runRoot 'artifact';$linuxRun=Invoke-Runner $base @('-Mode','Linux','-HeadRoot',$head,'-BaseSha',$baseSha,'-HeadSha',$headSha,'-StateRoot',(Join-Path $runRoot 'linux-state'),'-EvidenceRoot',(Join-Path $runRoot 'linux-evidence'),'-ArtifactRoot',$artifact);Expect $linuxRun 0 'Linux producer' '"mode": "linux"'
$manifestPath=Join-Path $artifact 'manifest.json';if(-not(Test-Path $manifestPath)){throw "Linux artifact manifest missing: $($linuxRun.Text)"};if(-not(Test-Json -LiteralPath $manifestPath -SchemaFile (Join-Path $base 'docs/guards/v4/core/contracts/ci-artifact-manifest.schema.json') -ErrorAction SilentlyContinue)){$failures.Add('Linux artifact manifest is invalid.')}
$manifest=Get-Content -Raw $manifestPath|ConvertFrom-Json;if(@($manifest.buildEvidence.secretEnvironmentNames).Count-ne0-or-not$manifest.buildEvidence.hostSha256){$failures.Add('Build Evidence is not secret-free and host-bound.')}
$packageRun=Invoke-Runner $base @('-Mode','Package','-HeadRoot',$head,'-BaseSha',$baseSha,'-HeadSha',$headSha,'-EvidenceRoot',(Join-Path $runRoot 'package-evidence'),'-ArtifactRoot',$artifact);Expect $packageRun 0 'Package artifact consumer' '"reusedArtifact": true'
$windowsRun=Invoke-Runner $base @('-Mode','Windows','-Coverage','smoke','-HeadRoot',$head,'-BaseSha',$baseSha,'-HeadSha',$headSha,'-StateRoot',(Join-Path $runRoot 'windows-state'),'-EvidenceRoot',(Join-Path $runRoot 'windows-evidence'),'-ArtifactRoot',$artifact);Expect $windowsRun 0 'Windows artifact consumer' '"reusedArtifact": true'
if(@(Invoke-Git $head @('status','--porcelain','--untracked-files=no')).Count-ne0){$failures.Add('Trusted runner modified tracked HeadRoot files.')}

$hostArtifact=Join-Path $artifact 'host/v4-guards.dll';[IO.File]::AppendAllText($hostArtifact,'tamper',[Text.UTF8Encoding]::new($false));$tamper=Invoke-Runner $base @('-Mode','Package','-HeadRoot',$head,'-BaseSha',$baseSha,'-HeadSha',$headSha,'-EvidenceRoot',(Join-Path $runRoot 'tamper-evidence'),'-ArtifactRoot',$artifact);Expect $tamper 12 'artifact tamper' 'artifact file drift'
Write-Utf8 (Join-Path $head 'docs/guards/v4/plans/undeclared.md') "undeclared`n";Invoke-Git $head @('add','--all')|Out-Null;Invoke-Git $head @('commit','-q','-m','undeclared')|Out-Null;$badHeadSha=(@(Invoke-Git $head @('rev-parse','HEAD')))[0];$under=Invoke-Runner $base @('-Mode','Contract','-HeadRoot',$head,'-BaseSha',$baseSha,'-HeadSha',$badHeadSha,'-EvidenceRoot',(Join-Path $runRoot 'under-evidence'));Expect $under 16 'under-declared Plan' 'do not exactly match'

& git clone --quiet --no-local $base $weak;if($LASTEXITCODE){throw 'weak clone failed'};Invoke-Git $weak @('config','user.email','p6@example.invalid')|Out-Null;Invoke-Git $weak @('config','user.name','V4 P6')|Out-Null;[IO.File]::AppendAllText((Join-Path $weak $testRelative),"`n# weakening`n",[Text.UTF8Encoding]::new($false));Invoke-Git $weak @('add','--all')|Out-Null;Invoke-Git $weak @('commit','-q','-m','weaken test')|Out-Null;$weakSha=(@(Invoke-Git $weak @('rev-parse','HEAD')))[0]
$weakRun=Invoke-Runner $base @('-Mode','Linux','-HeadRoot',$weak,'-BaseSha',$baseSha,'-HeadSha',$weakSha,'-StateRoot',(Join-Path $runRoot 'weak-state'),'-EvidenceRoot',(Join-Path $runRoot 'weak-evidence'),'-ArtifactRoot',(Join-Path $runRoot 'weak-artifact'));Expect $weakRun 12 'candidate test weakening' 'Approved test hash drift'
$provenance=Invoke-Runner $base @('-Mode','Contract','-HeadRoot',$head,'-BaseSha',$badHeadSha,'-HeadSha',$badHeadSha,'-EvidenceRoot',(Join-Path $runRoot 'provenance-evidence'),'-Certification','-RequestedWindowsCoverage','full');if($provenance.Code-eq0){$failures.Add('Wrong trusted base provenance unexpectedly passed.')}

if($failures.Count){throw ($failures-join"`n")}
Write-Host 'V4 P6 trusted-base tests passed: exact Plan, root isolation, isolated Linux producer, immutable Package/Windows reuse, tamper, under-declaration, test weakening and provenance negatives.'
