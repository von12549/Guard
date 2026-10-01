[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$packageRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$workRoot = [IO.Path]::Combine([IO.Path]::GetTempPath(),'v4-guards-work',[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($packageRoot))).Substring(0,12).ToLowerInvariant())
$runRoot = Join-Path $workRoot 'p8-candidate-certification'
$failures = [Collections.Generic.List[string]]::new()

function Write-Utf8([string] $Path,[string] $Text){[void][IO.Directory]::CreateDirectory((Split-Path -Parent $Path));[IO.File]::WriteAllText($Path,$Text,[Text.UTF8Encoding]::new($false))}
function Write-Json([string] $Path,$Value){Write-Utf8 $Path ((($Value|ConvertTo-Json -Depth 100)+"`n").Replace("`r`n","`n"))}
function Run([string] $Script,[string[]] $Arguments){$output=@(& pwsh -NoLogo -NoProfile -NonInteractive -File $Script @Arguments 2>&1);[pscustomobject]@{Code=$LASTEXITCODE;Text=($output-join"`n")}}
function Replace-ZipEntry([string] $Archive,[string] $EntryName,[string] $Text){$zip=[IO.Compression.ZipFile]::Open($Archive,[IO.Compression.ZipArchiveMode]::Update);try{$entry=@($zip.Entries|Where-Object FullName -CEQ $EntryName);if($entry.Count-ne1){throw "ZIP entry is not unique: $EntryName"};$entry[0].Delete();$replacement=$zip.CreateEntry($EntryName,[IO.Compression.CompressionLevel]::NoCompression);$replacement.LastWriteTime=[DateTimeOffset]::new(1980,1,1,0,0,0,[TimeSpan]::Zero);$writer=[IO.StreamWriter]::new($replacement.Open(),[Text.UTF8Encoding]::new($false));try{$writer.Write($Text)}finally{$writer.Dispose()}}finally{$zip.Dispose()}}

if(Test-Path -LiteralPath $runRoot){Remove-Item -LiteralPath $runRoot -Recurse -Force}
[void][IO.Directory]::CreateDirectory($runRoot)
$packageCheck=Run (Join-Path $packageRoot 'core/runtime/Test-V4Package.ps1') @('-PackageRoot',$packageRoot)
if($packageCheck.Code){throw "Source package validation failed: $($packageCheck.Text)"}
$package=$packageCheck.Text|ConvertFrom-Json
$sourceCommit=(& git -C $packageRoot rev-parse HEAD).Trim().ToLowerInvariant();if($LASTEXITCODE-or$sourceCommit-notmatch'^[a-f0-9]{40}$'){throw 'Cannot resolve source commit.'}
$contract=Get-Content -Raw -LiteralPath (Join-Path $packageRoot 'integrations/github/ci-contract.json')|ConvertFrom-Json
$zero='0'*64
foreach($spec in @(@{Platform='linux';Coverage='complete';Property='linux'},@{Platform='windows';Coverage='full';Property='windowsFull'})){
    $tests=@($contract.approvedTests|Where-Object{$_.PSObject.Properties[$spec.Property].Value-eq$true}|ForEach-Object{[ordered]@{path=[string]$_.path;sha256=[string]$_.sha256;resultSha256=$zero}})
    Write-Json (Join-Path $runRoot "$($spec.Platform).json") ([ordered]@{formatVersion=1;status='pass';platform=$spec.Platform;coverage=$spec.Coverage;sourceCommit=$sourceCommit;packageHash=[string]$package.packageHash;osDescription='synthetic certification regression';architecture='x64';toolchain=[ordered]@{pwsh='test';dotnet='test';git='test'};tests=$tests;secretEnvironmentNames=@()})
}

$cleanPackage=Join-Path $runRoot 'package';foreach($file in $package.authorityFiles){$source=Join-Path $packageRoot ([string]$file.path);$destination=Join-Path $cleanPackage ([string]$file.path);[void][IO.Directory]::CreateDirectory((Split-Path -Parent $destination));[IO.File]::Copy($source,$destination,$false)}
Write-Json (Join-Path $cleanPackage 'core/distribution/runtime-manifest.json') ([ordered]@{formatVersion=1;rid='linux-x64';deploymentModel='self-contained';features=[ordered]@{singleFile=$false;trimmed=$false;readyToRun=$false}})
$hostRoot=Join-Path $runRoot 'host';$companionRoot=Join-Path $runRoot 'companion';[void][IO.Directory]::CreateDirectory($hostRoot);[void][IO.Directory]::CreateDirectory($companionRoot)
Write-Utf8 (Join-Path $hostRoot 'v4-guards.dll') 'host';Write-Utf8 (Join-Path $hostRoot 'v4-guards.deps.json') '{}';Write-Utf8 (Join-Path $hostRoot 'v4-guards.runtimeconfig.json') '{"runtimeOptions":{"tfm":"net10.0"}}';Write-Utf8 (Join-Path $hostRoot 'v4-guards') 'host-app'
Write-Utf8 (Join-Path $companionRoot 'v4-web-companion.dll') 'companion';Write-Utf8 (Join-Path $companionRoot 'v4-web-companion.deps.json') '{}';Write-Utf8 (Join-Path $companionRoot 'v4-web-companion.runtimeconfig.json') '{"runtimeOptions":{"tfm":"net10.0"}}';Write-Utf8 (Join-Path $companionRoot 'v4-web-companion') 'companion-app'
$distribution=Run (Join-Path $packageRoot 'core/distribution/New-V4Distribution.ps1') @('-PackageRoot',$cleanPackage,'-HostRoot',$hostRoot,'-CompanionRoot',$companionRoot,'-OutputDirectory',(Join-Path $runRoot 'distribution'),'-SourceCommit',$sourceCommit,'-RuntimeIdentifier','linux-x64','-DeploymentModel','self-contained')
if($distribution.Code){throw "Self-contained regression archive failed: $($distribution.Text)"};$distributionResult=$distribution.Text|ConvertFrom-Json
if([string]$distributionResult.packageHash-ceq[string]$package.packageHash){$failures.Add('Regression archive did not create a RID-specific package identity.')}

$certifier=Join-Path $packageRoot 'core/certification/Invoke-V4V1Certification.ps1';$common=@('-PackageRoot',$packageRoot,'-LinuxReport',(Join-Path $runRoot 'linux.json'),'-WindowsReport',(Join-Path $runRoot 'windows.json'),'-SourceCommit',$sourceCommit,'-RestoreCommit',$sourceCommit)
$positive=Run $certifier ($common+@('-ArchivePath',[string]$distributionResult.archivePath,'-OutputDirectory',(Join-Path $runRoot 'positive')))
if($positive.Code){$failures.Add("RID-specific candidate certification failed: $($positive.Text)")}else{$result=$positive.Text|ConvertFrom-Json;if($result.status-cne'pass'-or$result.packageHash-cne[string]$package.packageHash-or$result.archivePackageHash-cne[string]$distributionResult.packageHash){$failures.Add('Candidate certification did not preserve distinct source and archive package identities.')}}

Add-Type -AssemblyName System.IO.Compression
$forged=Join-Path $runRoot 'forged-source-package-hash.zip';[IO.File]::Copy([string]$distributionResult.archivePath,$forged,$false);$rootName="v4-guards-$((Get-Content -Raw -LiteralPath (Join-Path $packageRoot 'plugin.json')|ConvertFrom-Json).version)";$manifestName="$rootName/distribution-manifest.json";$zip=[IO.Compression.ZipFile]::OpenRead($forged);try{$entry=@($zip.Entries|Where-Object FullName -CEQ $manifestName)[0];$reader=[IO.StreamReader]::new($entry.Open());try{$manifest=$reader.ReadToEnd()|ConvertFrom-Json -AsHashtable -Depth 100}finally{$reader.Dispose()}}finally{$zip.Dispose()};$manifest.source.packageHash=[string]$package.packageHash;Replace-ZipEntry $forged $manifestName ((($manifest|ConvertTo-Json -Depth 100).Replace("`r`n","`n"))+"`n")
$negative=Run $certifier ($common+@('-ArchivePath',$forged,'-OutputDirectory',(Join-Path $runRoot 'negative')))
if($negative.Code-eq0-or$negative.Text-notmatch'Archive package identity does not match'){ $failures.Add("Source/RID package identity forgery was not rejected: $($negative.Text)") }

if($failures.Count){throw($failures-join"`n")}
Write-Host 'V4 P8 candidate certification passed: source and RID package identities remain distinct, exact archive bytes are verified and forged provenance fails closed.'
