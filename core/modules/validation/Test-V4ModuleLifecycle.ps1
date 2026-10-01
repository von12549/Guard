[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$package=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$key=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($package))).Substring(0,12).ToLowerInvariant()
$work=[IO.Path]::Combine([IO.Path]::GetTempPath(),'v4-guards-work',$key,'m5-modules')
$script=Join-Path $package 'core/modules/Invoke-V4ModuleLifecycle.ps1'
$failures=[Collections.Generic.List[string]]::new()
function Hash([string]$Path){(Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()}
function Read-Json([string]$Path){Get-Content -Raw -LiteralPath $Path|ConvertFrom-Json -AsHashtable -Depth 100}
function Write-Json([string]$Path,$Value){[IO.File]::WriteAllText($Path,(($Value|ConvertTo-Json -Depth 100)+"`n"),[Text.UTF8Encoding]::new($false))}
function Run([string[]]$Arguments){$text=@(& pwsh -NoLogo -NoProfile -NonInteractive -File $script @Arguments 2>&1)-join"`n";[pscustomobject]@{Code=$LASTEXITCODE;Text=$text}}
function Expect($Run,[int]$Code,[string]$Name,[string]$Pattern=''){if($Run.Code-ne$Code-or($Pattern-and$Run.Text-notmatch$Pattern)){$failures.Add("${Name}: expected $Code/$Pattern, got $($Run.Code): $($Run.Text)")}}
if(Test-Path $work){$full=[IO.Path]::GetFullPath($work);$safe=[IO.Path]::GetFullPath([IO.Path]::Combine([IO.Path]::GetTempPath(),'v4-guards-work')).TrimEnd([IO.Path]::DirectorySeparatorChar)+[IO.Path]::DirectorySeparatorChar;if(-not$full.StartsWith($safe,[StringComparison]::OrdinalIgnoreCase)){throw"Unsafe cleanup: $full"};Remove-Item -LiteralPath $full -Recurse -Force}
$state=Join-Path $work 'state';$evidence=Join-Path $work 'evidence';$target=Join-Path $work 'target';[void][IO.Directory]::CreateDirectory($state);[void][IO.Directory]::CreateDirectory($evidence);[void][IO.Directory]::CreateDirectory($target);[IO.File]::WriteAllText((Join-Path $target 'sentinel.txt'),"unchanged`n",[Text.UTF8Encoding]::new($false));$targetHash=Hash (Join-Path $target 'sentinel.txt')
$common=@('-PackageRoot',$package)
Expect (Run (@('-Operation','inventory')+$common)) 0 'inventory' '"moduleCount"'
Expect (Run (@('-Operation','inspect')+$common+@('-Module','synthetic-probe'))) 0 'inspect' 'installed-immutable'
Expect (Run (@('-Operation','graph')+$common)) 0 'graph' '"nodes"'
Expect (Run (@('-Operation','scaffold')+$common+@('-StateRoot',$state,'-TargetRoot',$target,'-Module','sample-extension','-Version','1.0.0','-Candidate','candidates/sample'))) 0 'scaffold' '"adapterSourceGenerated": false'
Expect (Run (@('-Operation','scaffold')+$common+@('-StateRoot',$state,'-Module','synthetic-probe','-Version','1.0.0','-Candidate','candidates/builtin'))) 16 'built-in replacement refusal'
$candidate=Join-Path $state 'candidates/sample';$moduleRoot=Join-Path $candidate 'package/modules/sample-extension';$adapter=Join-Path $moduleRoot 'adapter.ps1'
$adapterText=@'
$input=$env:V4_STAGE_INPUT_JSON|ConvertFrom-Json -AsHashtable -Depth 100
if($env:GUARD_TEST_SECRET){throw 'inherited secret environment'}
[ordered]@{formatVersion=1;status='pass';exitCategory='success';message='fixture pass';findings=@();coverage=@([ordered]@{claimId='MODULE.SAMPLE';matched=1;minimum=1})}|ConvertTo-Json -Compress -Depth 20
'@
[IO.File]::WriteAllText($adapter,$adapterText,[Text.UTF8Encoding]::new($false));$manifest=Read-Json (Join-Path $moduleRoot 'module.json');$manifest.adapter.sha256=Hash $adapter;Write-Json (Join-Path $moduleRoot 'module.json') $manifest
Expect (Run (@('-Operation','validate')+$common+@('-StateRoot',$state,'-TargetRoot',$target,'-Module','sample-extension','-Candidate','candidates/sample'))) 0 'validate' '"immutableCandidate": true'
Expect (Run (@('-Operation','test')+$common+@('-StateRoot',$state,'-EvidenceRoot',$evidence,'-TargetRoot',$target,'-Module','sample-extension','-Candidate','candidates/sample'))) 13 'untrusted execution refusal' 'disabled outside explicit synthetic fixture'
$oldSecret=$env:GUARD_TEST_SECRET;try{$env:GUARD_TEST_SECRET='must-not-cross-process-boundary';Expect (Run (@('-Operation','test')+$common+@('-StateRoot',$state,'-EvidenceRoot',$evidence,'-TargetRoot',$target,'-Module','sample-extension','-Candidate','candidates/sample','-AllowSyntheticFixture'))) 0 'synthetic fixture test' '"inheritedEnvironment": false'}finally{$env:GUARD_TEST_SECRET=$oldSecret}

$external=Join-Path $work 'external';[void][IO.Directory]::CreateDirectory($external);$externalSentinel=Join-Path $external 'sentinel.txt';[IO.File]::WriteAllText($externalSentinel,"unchanged`n",[Text.UTF8Encoding]::new($false));$externalHash=Hash $externalSentinel
$hostileText="[IO.File]::WriteAllText('$($externalSentinel.Replace("'","''"))','changed'); Invoke-WebRequest -Uri 'http://127.0.0.1:9/'`n"
[IO.File]::WriteAllText($adapter,$hostileText,[Text.UTF8Encoding]::new($false));$manifest.adapter.sha256=Hash $adapter;Write-Json (Join-Path $moduleRoot 'module.json') $manifest
Expect (Run (@('-Operation','test')+$common+@('-StateRoot',$state,'-EvidenceRoot',$evidence,'-TargetRoot',$target,'-Module','sample-extension','-Candidate','candidates/sample'))) 13 'hostile candidate pre-execution refusal' 'disabled outside explicit synthetic fixture'
if((Hash $externalSentinel)-cne$externalHash){$failures.Add('Refused hostile candidate modified the external sentinel.')}

$manifest.capabilities.network=$true;Write-Json (Join-Path $moduleRoot 'module.json') $manifest;Expect (Run (@('-Operation','validate')+$common+@('-StateRoot',$state,'-Module','sample-extension','-Candidate','candidates/sample'))) 13 'network capability refusal' 'network capability'
$manifest.capabilities.network=$false;$manifest.capabilities.processes=@('pwsh','curl');Write-Json (Join-Path $moduleRoot 'module.json') $manifest;Expect (Run (@('-Operation','validate')+$common+@('-StateRoot',$state,'-Module','sample-extension','-Candidate','candidates/sample'))) 13 'extra process capability refusal' 'only the pwsh process'
$manifest.capabilities.processes=@('pwsh');$manifest.capabilities.timeoutSeconds=1
$childSentinel=Join-Path $external 'child-survived.txt';$escapedChild=$childSentinel.Replace("'","''")
$timeoutText=@"
Start-Process pwsh -ArgumentList @('-NoProfile','-Command',"Start-Sleep -Seconds 4; [IO.File]::WriteAllText('$escapedChild','survived')")
Start-Sleep -Seconds 120
"@
[IO.File]::WriteAllText($adapter,$timeoutText,[Text.UTF8Encoding]::new($false));$manifest.adapter.sha256=Hash $adapter;Write-Json (Join-Path $moduleRoot 'module.json') $manifest
Expect (Run (@('-Operation','test')+$common+@('-StateRoot',$state,'-EvidenceRoot',$evidence,'-TargetRoot',$target,'-Module','sample-extension','-Candidate','candidates/sample','-AllowSyntheticFixture'))) 14 'timeout and process tree termination' 'process tree was terminated'
Start-Sleep -Seconds 5
if(Test-Path -LiteralPath $childSentinel){$failures.Add('Timed-out fixture left a child process that wrote after tree termination.')}
$manifest.capabilities.timeoutSeconds=30;[IO.File]::WriteAllText($adapter,$adapterText,[Text.UTF8Encoding]::new($false));$manifest.adapter.sha256=Hash $adapter;Write-Json (Join-Path $moduleRoot 'module.json') $manifest

if(-not $IsWindows){
    $externalAdapter=Join-Path $external 'adapter.ps1';[IO.File]::WriteAllText($externalAdapter,$adapterText,[Text.UTF8Encoding]::new($false));Remove-Item -LiteralPath $adapter
    try{
        New-Item -ItemType SymbolicLink -Path $adapter -Target $externalAdapter|Out-Null
        Expect (Run (@('-Operation','validate')+$common+@('-StateRoot',$state,'-Module','sample-extension','-Candidate','candidates/sample'))) 11 'adapter file symlink refusal' 'link or reparse point'
    }finally{if(Test-Path -LiteralPath $adapter){Remove-Item -LiteralPath $adapter -Force};[IO.File]::WriteAllText($adapter,$adapterText,[Text.UTF8Encoding]::new($false))}
}
$linked=Join-Path $candidate 'package/modules/external-link'
try{
    if($IsWindows){New-Item -ItemType Junction -Path $linked -Target $external|Out-Null}else{New-Item -ItemType SymbolicLink -Path $linked -Target $external|Out-Null}
    Expect (Run (@('-Operation','pack')+$common+@('-StateRoot',$state,'-EvidenceRoot',$evidence,'-Module','sample-extension','-Candidate','candidates/sample','-Output','packs/refused-link'))) 11 'recursive link refusal' 'link or reparse point'
}finally{if(Test-Path -LiteralPath $linked){Remove-Item -LiteralPath $linked -Force}}
Expect (Run (@('-Operation','diff')+$common+@('-StateRoot',$state,'-Module','sample-extension','-Candidate','candidates/sample'))) 0 'diff' '"replacementRefused": true'
Expect (Run (@('-Operation','pack')+$common+@('-StateRoot',$state,'-EvidenceRoot',$evidence,'-Module','sample-extension','-Candidate','candidates/sample','-Output','packs/one'))) 0 'first pack' '"deterministic": true'
Expect (Run (@('-Operation','pack')+$common+@('-StateRoot',$state,'-EvidenceRoot',$evidence,'-Module','sample-extension','-Candidate','candidates/sample','-Output','packs/two'))) 0 'second pack'
if((Hash (Join-Path $evidence 'packs/one.zip'))-cne(Hash (Join-Path $evidence 'packs/two.zip'))){$failures.Add('Repeated Module packs are not byte-identical.')}
$bundleManifest=Join-Path $evidence 'packs/one/bundle-manifest.json';if(-not(Test-Json -LiteralPath $bundleManifest -SchemaFile (Join-Path $package 'core/contracts/extension-bundle.schema.json') -ErrorAction SilentlyContinue)){$failures.Add('Packed bundle manifest is invalid.')}
Expect (Run (@('-Operation','review')+$common+@('-EvidenceRoot',$evidence,'-BundleRoot','packs/one','-ReviewAuthority','fixture-operator','-BaseArchiveSha256',('a'*64),'-Output','reviews/sample.json'))) 0 'review preparation' '"productionAccepted": false'
$review=Read-Json (Join-Path $evidence 'reviews/sample.json');if($review.decision-cne'unresolved'-or$review.authoritative-ne$false){$failures.Add('Review preparation created acceptance authority.')}
if((Hash (Join-Path $target 'sentinel.txt'))-cne$targetHash){$failures.Add('Module lifecycle mutated TargetRoot.')}
if($failures.Count){throw($failures-join"`n")}
Write-Host 'V4 M5 Module lifecycle tests passed: immutable inventory/scaffold/validation/fixtures/diff/deterministic pack and review preparation.'
