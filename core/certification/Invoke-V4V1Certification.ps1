[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $PackageRoot,
    [Parameter(Mandatory)][string] $LinuxReport,
    [Parameter(Mandatory)][string] $WindowsReport,
    [Parameter(Mandatory)][string] $ArchivePath,
    [Parameter(Mandatory)][ValidatePattern('^[a-f0-9]{40}$')][string] $SourceCommit,
    [Parameter(Mandatory)][ValidatePattern('^[a-f0-9]{40}$')][string] $RestoreCommit,
    [Parameter(Mandatory)][string] $OutputDirectory
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Hash([string] $Path) { (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant() }
function Read-Json([string] $Path) { Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json -AsHashtable -Depth 100 }
function Write-Json([string] $Path,$Value){[void][IO.Directory]::CreateDirectory((Split-Path -Parent $Path));[IO.File]::WriteAllText($Path,(($Value|ConvertTo-Json -Depth 100).Replace("`r`n","`n")+"`n"),[Text.UTF8Encoding]::new($false))}

$root=[IO.Path]::TrimEndingDirectorySeparator([IO.Path]::GetFullPath($PackageRoot));$output=[IO.Path]::TrimEndingDirectorySeparator([IO.Path]::GetFullPath($OutputDirectory));[void][IO.Directory]::CreateDirectory($output)
$platformSchema=Join-Path $root 'core/contracts/platform-certification.schema.json'
$reports=@([ordered]@{Expected='linux';Coverage='complete';Path=[IO.Path]::GetFullPath($LinuxReport)},[ordered]@{Expected='windows';Coverage='full';Path=[IO.Path]::GetFullPath($WindowsReport)})
$contract=Read-Json (Join-Path $root 'integrations/github/ci-contract.json');$platformEntries=[Collections.Generic.List[object]]::new();$packageHash=$null
foreach($item in $reports){
    if(-not(Test-Json -LiteralPath $item.Path -SchemaFile $platformSchema -ErrorAction SilentlyContinue)){throw "$($item.Expected) report violates its schema."}
    $report=Read-Json $item.Path;if($report.platform -cne $item.Expected -or $report.coverage -cne $item.Coverage -or $report.sourceCommit -cne $SourceCommit){throw "$($item.Expected) report provenance mismatch."}
    if($null-eq$packageHash){$packageHash=[string]$report.packageHash}elseif($packageHash-cne[string]$report.packageHash){throw 'Platform package hashes differ.'}
    $property=if($item.Expected-eq'linux'){'linux'}else{'windowsFull'};$expected=@($contract.approvedTests|Where-Object{$_[$property]-eq$true}|ForEach-Object{[string]$_.path}|Sort-Object);$actual=@($report.tests.path|Sort-Object)
    if(($expected-join"`0")-cne($actual-join"`0")){throw "$($item.Expected) report does not cover the exact approved suite."}
    $destination=Join-Path $output "platform/$($item.Expected).json";[void][IO.Directory]::CreateDirectory((Split-Path -Parent $destination));[IO.File]::Copy($item.Path,$destination,$true)
    $platformEntries.Add([ordered]@{platform=$item.Expected;coverage=$item.Coverage;path="platform/$($item.Expected).json";sha256=Hash $destination;testCount=@($report.tests).Count})
}

$packageOutput=@(& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $root 'core/runtime/Test-V4Package.ps1') -PackageRoot $root 2>&1);if($LASTEXITCODE){throw "Package check failed: $($packageOutput-join"`n")"};$packageResult=($packageOutput-join"`n")|ConvertFrom-Json
if($packageResult.packageHash -cne $packageHash){throw 'Certified package hash differs from current package.'}
$supply=@(& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $root 'core/certification/Test-V4SupplyChain.ps1') -PackageRoot $root 2>&1);if($LASTEXITCODE){throw "Supply-chain check failed: $($supply-join"`n")"}
if(Test-Path (Join-Path $root 'profiles/catalog/ifx_profile')){throw 'ifx_profile is outside the V1 certification boundary.'}
$repoRoot=[IO.Path]::GetFullPath((Join-Path $root '../../..'));if(Test-Path (Join-Path $repoRoot '.github/workflows/v4-guards.yml')){throw 'Active V4 workflow exists without activation authorization.'}

$baselinePath=Join-Path $root 'core/certification/compatibility-baseline.json';$baseline=Read-Json $baselinePath
if(-not(Test-Json -LiteralPath $baselinePath -SchemaFile (Join-Path $root 'core/contracts/compatibility-baseline.schema.json') -ErrorAction SilentlyContinue)){throw 'Compatibility baseline violates its schema.'}
foreach($file in $baseline.files){if((Hash (Join-Path $root ([string]$file.path)))-cne[string]$file.sha256){throw "Compatibility baseline drift: $($file.path)"}}

Add-Type -AssemblyName System.IO.Compression
$archive=[IO.Path]::GetFullPath($ArchivePath);$zip=[IO.Compression.ZipFile]::OpenRead($archive)
try{$manifestEntry=@($zip.Entries|Where-Object Name -eq 'distribution-manifest.json');if($manifestEntry.Count-ne1){throw 'Archive distribution manifest is missing.'};$reader=[IO.StreamReader]::new($manifestEntry[0].Open());try{$manifest=$reader.ReadToEnd()|ConvertFrom-Json -AsHashtable -Depth 100}finally{$reader.Dispose()}}finally{$zip.Dispose()}
if($manifest.source.commit -cne $SourceCommit -or $manifest.source.packageHash -cne $packageHash){throw 'Archive provenance does not match the certified source/package.'}
$archiveHash=Hash $archive;$baselineHash=Hash $baselinePath
$record=[ordered]@{formatVersion=1;id='v4-guards-v1-candidate';version=[string]$manifest.version;status='candidate';sourceCommit=$SourceCommit;packageHash=$packageHash;archiveSha256=$archiveHash;contractsManifestSha256=Hash(Join-Path $root 'core/contracts/contracts-manifest.json');compatibilityBaselineSha256=$baselineHash;platformReports=@($platformEntries);acceptance=@('P8.1-platforms','P8.2-lifecycle','P8.3-supply-chain','P8.4-compatibility-recovery','P8.5-v4-native-architecture');releaseAuthorized=$false;activeIfxCutover=$false;ifxProfileIncluded=$false;architectureRuntimeDependencies=@('pwsh','dotnet','roslyn','archunitnet')}
$recordPath=Join-Path $output 'v1-certification.json';Write-Json $recordPath $record
if(-not(Test-Json -LiteralPath $recordPath -SchemaFile (Join-Path $root 'core/contracts/v1-certification.schema.json') -ErrorAction SilentlyContinue)){throw 'V1 certification record violates its schema.'}
$recovery=[ordered]@{formatVersion=1;candidateCommit=$SourceCommit;restoreCommit=$RestoreCommit;packageHash=$packageHash;archiveSha256=$archiveHash;compatibilityBaselineSha256=$baselineHash;strategy='restore-reviewed-source-checkpoint';verificationCommands=@('pwsh -NoProfile -File docs/guards/v4/tests/p0/Test-V4Contracts.ps1','pwsh -NoProfile -File docs/guards/v4/core/runtime/Test-V4Package.ps1 -PackageRoot docs/guards/v4','pwsh -NoProfile -File docs/guards/V3_ifx/commands/Invoke-IFXGuardrails.ps1 -Mode Validate');remoteRollbackRequired=$false}
$recoveryPath=Join-Path $output 'recovery.json';Write-Json $recoveryPath $recovery
if(-not(Test-Json -LiteralPath $recoveryPath -SchemaFile (Join-Path $root 'core/contracts/recovery-artifact.schema.json') -ErrorAction SilentlyContinue)){throw 'Recovery artifact violates its schema.'}
[ordered]@{formatVersion=1;status='pass';certificationPath=$recordPath;recoveryPath=$recoveryPath;packageHash=$packageHash;archiveSha256=$archiveHash;releaseAuthorized=$false}|ConvertTo-Json
