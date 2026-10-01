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
function Entry-Hash($Entry){$sha=[Security.Cryptography.SHA256]::Create();$stream=$Entry.Open();try{[Convert]::ToHexString($sha.ComputeHash($stream)).ToLowerInvariant()}finally{$stream.Dispose();$sha.Dispose()}}
function Entry-Text($Entry){$reader=[IO.StreamReader]::new($Entry.Open(),[Text.Encoding]::UTF8,$true);try{$reader.ReadToEnd()}finally{$reader.Dispose()}}
function Identity-Hash($Files){$identity=@($Files|Sort-Object { [string]$_.path }|ForEach-Object{"$($_.path):$($_.sha256)"})-join"`n";[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($identity))).ToLowerInvariant()}

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
$repoRoot=$root;$activeWorkflow=Join-Path $repoRoot '.github/workflows/v4-guards.yml';if(Test-Path $activeWorkflow){$specimenLines=@(([IO.File]::ReadAllText((Join-Path $root 'integrations/github/proposed-v4-guards.yml'))).Replace("`r`n","`n").Split("`n"));$activeLines=@(([IO.File]::ReadAllText($activeWorkflow)).Replace("`r`n","`n").Split("`n"));if($activeLines.Count -ne $specimenLines.Count -or -not $activeLines[0].StartsWith('#') -or ((@($activeLines|Select-Object -Skip 1)) -join "`n") -cne ((@($specimenLines|Select-Object -Skip 1)) -join "`n")){throw 'Active V4 workflow differs from the reviewed specimen beyond its first comment line.'}}

$baselinePath=Join-Path $root 'core/certification/compatibility-baseline.json';$baseline=Read-Json $baselinePath
if(-not(Test-Json -LiteralPath $baselinePath -SchemaFile (Join-Path $root 'core/contracts/compatibility-baseline.schema.json') -ErrorAction SilentlyContinue)){throw 'Compatibility baseline violates its schema.'}
foreach($file in $baseline.files){if((Hash (Join-Path $root ([string]$file.path)))-cne[string]$file.sha256){throw "Compatibility baseline drift: $($file.path)"}}

Add-Type -AssemblyName System.IO.Compression
$archive=[IO.Path]::GetFullPath($ArchivePath);$zip=[IO.Compression.ZipFile]::OpenRead($archive)
try{
    $entries=@($zip.Entries|Where-Object{-not[string]::IsNullOrEmpty($_.Name)});$entryMap=[Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
    foreach($entry in $entries){$name=$entry.FullName.Replace('\','/');if(-not$entryMap.TryAdd($name,$entry)){throw "Duplicate archive entry: $name"};$segments=$name.Split('/',[StringSplitOptions]::RemoveEmptyEntries);$unixType=(($entry.ExternalAttributes-shr16)-band0xF000);if($segments.Count-lt2-or$segments-contains'..'-or$segments-contains'.'-or[IO.Path]::IsPathRooted($name)-or$unixType-eq0xA000){throw "Unsafe archive entry: $name"}}
    $roots=@($entryMap.Keys|ForEach-Object{$_.Split('/')[0]}|Sort-Object -Unique);if($roots.Count-ne1-or$roots[0]-notmatch'^v4-guards-[0-9]+\.[0-9]+\.[0-9]+$'){throw 'Archive must contain exactly one versioned root.'};$archiveRoot=$roots[0]
    $manifestName="$archiveRoot/distribution-manifest.json";if(-not$entryMap.ContainsKey($manifestName)){throw 'Archive distribution manifest is missing.'};$manifestText=Entry-Text $entryMap[$manifestName]
    if(-not(Test-Json -Json $manifestText -SchemaFile (Join-Path $root 'core/contracts/distribution-manifest.schema.json') -ErrorAction SilentlyContinue)){throw 'Archive distribution manifest violates its schema.'};$manifest=$manifestText|ConvertFrom-Json -AsHashtable -Depth 100
    if([string]$manifest.rootDirectory-cne$archiveRoot){throw 'Archive root and distribution manifest differ.'}
    $declared=@($manifest.files.path|ForEach-Object{"$archiveRoot/$_"}|Sort-Object -CaseSensitive);$actual=@($entryMap.Keys|Where-Object{$_-cne$manifestName}|Sort-Object -CaseSensitive);if(($declared-join"`0")-cne($actual-join"`0")){throw 'Archive payload does not exactly match the distribution manifest.'}
    foreach($file in $manifest.files){$name="$archiveRoot/$($file.path)";$entry=$entryMap[$name];if((Entry-Hash $entry)-cne[string]$file.sha256-or$entry.Length-ne[long]$file.size){throw "Archive payload hash drift: $($file.path)"}}
    if([string]$manifest.source.commit-cne$SourceCommit-or[string]$manifest.source.contractsManifestSha256-cne(Hash(Join-Path $root 'core/contracts/contracts-manifest.json'))){throw 'Archive source provenance does not match the certified source.'}

    $runtimeRelative='core/distribution/runtime-manifest.json';$runtimeArchivePath="package/$runtimeRelative";$runtimeEntryName="$archiveRoot/$runtimeArchivePath";$runtimeHash=$null
    if($entryMap.ContainsKey($runtimeEntryName)){$runtimeText=Entry-Text $entryMap[$runtimeEntryName];if(-not(Test-Json -Json $runtimeText -SchemaFile (Join-Path $root 'core/distribution/contracts/distribution-runtime.schema.json') -ErrorAction SilentlyContinue)){throw 'Archive runtime manifest is invalid.'};$runtimeHash=Entry-Hash $entryMap[$runtimeEntryName]}
    $expectedAuthority=[Collections.Generic.List[object]]::new();foreach($file in $packageResult.authorityFiles){if([string]$file.path-cne$runtimeRelative){$expectedAuthority.Add([ordered]@{path=[string]$file.path;sha256=[string]$file.sha256})}}
    if($null-ne$runtimeHash){$expectedAuthority.Add([ordered]@{path=$runtimeRelative;sha256=$runtimeHash})}
    $archivePackageHash=Identity-Hash $expectedAuthority
    if([string]$manifest.source.packageHash-cne$archivePackageHash){throw 'Archive package identity does not match the certified source plus its declared runtime manifest.'}
    $expectedPackageFiles=@($expectedAuthority.path|ForEach-Object{"package/$_"})+@('package/guard.ps1','package/guard-web.ps1')|Sort-Object -Unique -CaseSensitive;$actualPackageFiles=@($manifest.files|Where-Object kind -CEQ 'package'|ForEach-Object{[string]$_.path}|Sort-Object -CaseSensitive)
    if(($expectedPackageFiles-join"`0")-cne($actualPackageFiles-join"`0")){throw 'Archive package files do not match the certified source authority.'}
    foreach($file in $expectedAuthority){$declaredFile=@($manifest.files|Where-Object path -CEQ "package/$($file.path)");if($declaredFile.Count-ne1-or[string]$declaredFile[0].sha256-cne[string]$file.sha256){throw "Archive package authority drift: $($file.path)"}}
    foreach($launcher in @('guard.ps1','guard-web.ps1')){$declaredLauncher=@($manifest.files|Where-Object path -CEQ "package/$launcher");if($declaredLauncher.Count-ne1-or[string]$declaredLauncher[0].sha256-cne(Hash(Join-Path $root "core/distribution/$launcher"))){throw "Archive launcher drift: $launcher"}}
    foreach($binding in @(@{Path='host/v4-guards.dll';Property='hostSha256'},@{Path='companion/v4-web-companion.dll';Property='companionSha256'})){$declaredBinary=@($manifest.files|Where-Object path -CEQ $binding.Path);if($declaredBinary.Count-ne1-or[string]$declaredBinary[0].sha256-cne[string]$manifest.source[$binding.Property]){throw "Archive binary provenance drift: $($binding.Path)"}}
}finally{$zip.Dispose()}
$archiveHash=Hash $archive;$baselineHash=Hash $baselinePath
$record=[ordered]@{formatVersion=1;id='v4-guards-v1-candidate';version=[string]$manifest.version;status='candidate';sourceCommit=$SourceCommit;packageHash=$packageHash;archiveSha256=$archiveHash;contractsManifestSha256=Hash(Join-Path $root 'core/contracts/contracts-manifest.json');compatibilityBaselineSha256=$baselineHash;platformReports=@($platformEntries);acceptance=@('P8.1-platforms','P8.2-lifecycle','P8.3-supply-chain','P8.4-compatibility-recovery','P8.5-v4-native-architecture');releaseAuthorized=$false;activeIfxCutover=$false;ifxProfileIncluded=$false;architectureRuntimeDependencies=@('pwsh','dotnet','roslyn','archunitnet')}
$recordPath=Join-Path $output 'v1-certification.json';Write-Json $recordPath $record
if(-not(Test-Json -LiteralPath $recordPath -SchemaFile (Join-Path $root 'core/contracts/v1-certification.schema.json') -ErrorAction SilentlyContinue)){throw 'V1 certification record violates its schema.'}
$recovery=[ordered]@{formatVersion=1;candidateCommit=$SourceCommit;restoreCommit=$RestoreCommit;packageHash=$packageHash;archiveSha256=$archiveHash;compatibilityBaselineSha256=$baselineHash;strategy='restore-reviewed-source-checkpoint';verificationCommands=@('pwsh -NoProfile -File tests/p0/Test-V4Contracts.ps1','pwsh -NoProfile -File core/runtime/Test-V4Package.ps1 -PackageRoot .','pwsh -NoProfile -File core/certification/Test-V4SupplyChain.ps1 -PackageRoot .');remoteRollbackRequired=$false}
$recoveryPath=Join-Path $output 'recovery.json';Write-Json $recoveryPath $recovery
if(-not(Test-Json -LiteralPath $recoveryPath -SchemaFile (Join-Path $root 'core/contracts/recovery-artifact.schema.json') -ErrorAction SilentlyContinue)){throw 'Recovery artifact violates its schema.'}
[ordered]@{formatVersion=1;status='pass';certificationPath=$recordPath;recoveryPath=$recoveryPath;packageHash=$packageHash;archivePackageHash=$archivePackageHash;archiveSha256=$archiveHash;releaseAuthorized=$false}|ConvertTo-Json
