[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('inventory','inspect','graph','scaffold','validate','test','diff','pack','review','compose','verify')][string] $Operation,
    [Parameter(Mandatory)][string] $PackageRoot,
    [string] $StateRoot,
    [string] $EvidenceRoot,
    [string] $TargetRoot,
    [string] $Module,
    [string] $Version,
    [string] $Candidate,
    [string] $Output,
    [string] $ReviewAuthority,
    [string] $BaseArchiveSha256,
    [string] $BaseInstallRoot,
    [string] $BaseReceiptPath,
    [string] $BaseArchivePath,
    [string] $BundleRoot,
    [string] $ReviewRecordPath,
    [string] $OutputInstallRoot,
    [string] $CompositionReceiptPath,
    [string] $InstallRoot,
    [string] $ReceiptPath,
    [switch] $AllowSyntheticFixture
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Fail([string] $Message, [int] $Code = 10) { [Console]::Error.WriteLine($Message); exit $Code }
function Hash([string] $Path) { (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant() }
function Read-Json([string] $Path) { Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json -AsHashtable -Depth 100 }
function Write-Json([string] $Path, $Value) {
    $parent = [IO.Path]::GetDirectoryName($Path)
    if (-not [IO.Directory]::Exists($parent)) { [void][IO.Directory]::CreateDirectory($parent) }
    $temporary = Join-Path $parent ".$([IO.Path]::GetFileName($Path))-$([Guid]::NewGuid().ToString('N')).tmp"
    try {
        [IO.File]::WriteAllText($temporary, (($Value | ConvertTo-Json -Depth 100) + "`n"), [Text.UTF8Encoding]::new($false))
        [IO.File]::Move($temporary, $Path, $true)
    } finally { if ([IO.File]::Exists($temporary)) { [IO.File]::Delete($temporary) } }
}
function Is-Under([string] $Path, [string] $Root) {
    $relative = [IO.Path]::GetRelativePath($Root, $Path)
    $relative -eq '.' -or (-not [IO.Path]::IsPathRooted($relative) -and $relative -ne '..' -and -not $relative.StartsWith("..$([IO.Path]::DirectorySeparatorChar)"))
}
function No-Links([string] $Path, [string] $Label) {
    $current = [IO.Path]::GetFullPath($Path)
    while ($current) {
        if ([IO.File]::Exists($current) -or [IO.Directory]::Exists($current)) {
            $item = Get-Item -LiteralPath $current -Force
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or $null -ne $item.LinkTarget) { Fail "$Label crosses a link or reparse point: $current" 11 }
        }
        $parent = [IO.Path]::GetDirectoryName($current)
        if ([string]::IsNullOrEmpty($parent) -or $parent -eq $current) { break }
        $current = $parent
    }
}
function Directory([string] $Value, [string] $Label, [switch] $Create) {
    if ([string]::IsNullOrWhiteSpace($Value)) { Fail "$Label is required." }
    $full = [IO.Path]::TrimEndingDirectorySeparator([IO.Path]::GetFullPath($Value))
    if ($Create -and -not [IO.Directory]::Exists($full)) { [void][IO.Directory]::CreateDirectory($full) }
    if (-not [IO.Directory]::Exists($full)) { Fail "$Label does not exist: $full" }
    No-Links $full $Label
    $full
}
function Relative([string] $Value, [string] $Label) {
    $normalized = $Value.Replace('\','/')
    if ([string]::IsNullOrWhiteSpace($Value) -or [IO.Path]::IsPathRooted($Value) -or $Value -match '^[A-Za-z]:' -or $Value -match '[*?]' -or
        @($normalized.Split('/') | Where-Object { $_ -in @('', '.', '..') }).Count -gt 0) { Fail "$Label must be an exact safe relative path." 11 }
    $normalized
}
function Under([string] $Root, [string] $RelativePath, [string] $Label, [switch] $MustExist) {
    $relative = Relative $RelativePath $Label
    $full = [IO.Path]::GetFullPath((Join-Path $Root $relative))
    if (-not (Is-Under $full $Root)) { Fail "$Label escapes its root." 11 }
    if ($MustExist -and -not ([IO.File]::Exists($full) -or [IO.Directory]::Exists($full))) { Fail "$Label is missing: $relative" }
    if ([IO.File]::Exists($full) -or [IO.Directory]::Exists($full)) { No-Links $full $Label }
    else { No-Links ([IO.Path]::GetDirectoryName($full)) $Label }
    $full
}
function Assert-Disjoint([string] $A, [string] $B, [string] $Label) { if ((Is-Under $A $B) -or (Is-Under $B $A)) { Fail "$Label roots overlap." 11 } }
function Safe-Entries([string] $Root, [string] $Label) {
    No-Links $Root $Label
    $entries = [Collections.Generic.List[IO.FileSystemInfo]]::new()
    $pending = [Collections.Generic.Queue[string]]::new()
    $pending.Enqueue([IO.Path]::GetFullPath($Root))
    while ($pending.Count) {
        $current = $pending.Dequeue()
        foreach ($item in @(Get-ChildItem -LiteralPath $current -Force)) {
            No-Links $item.FullName $Label
            $entries.Add($item)
            if ($item -is [IO.DirectoryInfo]) { $pending.Enqueue($item.FullName) }
        }
    }
    @($entries)
}
function Safe-Files([string] $Root, [string] $Label) { @(Safe-Entries $Root $Label | Where-Object { $_ -is [IO.FileInfo] }) }
function Copy-SafeTree([string] $Source, [string] $Destination, [string] $Label) {
    $sourceFull = [IO.Path]::GetFullPath($Source)
    $entries = @(Safe-Entries $sourceFull $Label)
    [void][IO.Directory]::CreateDirectory($Destination)
    foreach ($directory in @($entries | Where-Object { $_ -is [IO.DirectoryInfo] } | Sort-Object { $_.FullName.Length })) {
        $relative = [IO.Path]::GetRelativePath($sourceFull, $directory.FullName)
        [void][IO.Directory]::CreateDirectory((Join-Path $Destination $relative))
    }
    foreach ($file in @($entries | Where-Object { $_ -is [IO.FileInfo] } | Sort-Object FullName)) {
        $relative = [IO.Path]::GetRelativePath($sourceFull, $file.FullName)
        $target = [IO.Path]::GetFullPath((Join-Path $Destination $relative))
        No-Links ([IO.Path]::GetDirectoryName($target)) "$Label destination"
        [IO.File]::Copy($file.FullName, $target, $false)
    }
}
function Invoke-SyntheticAdapter([string] $Adapter, [string] $InputJson, [int] $TimeoutSeconds, [string] $WorkingDirectory, [string] $TemporaryDirectory) {
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = (Get-Command pwsh -ErrorAction Stop).Source
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.WorkingDirectory = $WorkingDirectory
    $start.ArgumentList.Add('-NoLogo'); $start.ArgumentList.Add('-NoProfile'); $start.ArgumentList.Add('-NonInteractive')
    $start.ArgumentList.Add('-File'); $start.ArgumentList.Add($Adapter)
    $start.Environment.Clear()
    $start.Environment['PATH'] = [IO.Path]::GetDirectoryName($start.FileName)
    $start.Environment['TEMP'] = $TemporaryDirectory
    $start.Environment['TMP'] = $TemporaryDirectory
    $start.Environment['POWERSHELL_TELEMETRY_OPTOUT'] = '1'
    $start.Environment['DOTNET_CLI_TELEMETRY_OPTOUT'] = '1'
    $start.Environment['V4_STAGE_INPUT_JSON'] = $InputJson
    if ($IsWindows) {
        $start.Environment['SystemRoot'] = $env:SystemRoot
        $start.Environment['WINDIR'] = $env:WINDIR
    }
    $process = [Diagnostics.Process]::new(); $process.StartInfo = $start
    try {
        if (-not $process.Start()) { Fail 'Synthetic fixture adapter did not start.' 14 }
        $stdout = $process.StandardOutput.ReadToEndAsync(); $stderr = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
            try { $process.Kill($true) } catch {}
            $process.WaitForExit()
            [Threading.Tasks.Task]::WaitAll(@($stdout,$stderr))
            Fail "Synthetic fixture adapter timed out after $TimeoutSeconds seconds; its process tree was terminated." 14
        }
        [Threading.Tasks.Task]::WaitAll(@($stdout,$stderr))
        [ordered]@{ code=$process.ExitCode; output=(@($stdout.Result,$stderr.Result) | Where-Object { $_ } | Join-String -Separator "`n") }
    } finally {
        if ($null -ne $process) {
            try { if (-not $process.HasExited) { $process.Kill($true); $process.WaitForExit() } } catch {}
            $process.Dispose()
        }
    }
}
function Result([string] $Status, [hashtable] $Details) {
    $body = [ordered]@{ formatVersion=1; status=$Status; operation=$Operation; authority='v4-module-lifecycle'; targetMutated=$false; builtInMutated=$false; remoteChange=$false }
    foreach ($entry in $Details.GetEnumerator()) { $body[$entry.Key] = $entry.Value }
    $schema = Join-Path $package 'core/modules/contracts/module-lifecycle-result.schema.json'
    $text = $body | ConvertTo-Json -Depth 100
    if (-not (Test-Json -Json $text -SchemaFile $schema -ErrorAction SilentlyContinue)) { Fail 'Internal Module lifecycle result violates its schema.' 19 }
    $text
    exit 0
}
function Registry() {
    $path = Join-Path $package 'modules/registry.json'
    if (-not (Test-Json -LiteralPath $path -SchemaFile (Join-Path $package 'core/contracts/module-registry.schema.json') -ErrorAction SilentlyContinue)) { Fail 'Installed Module registry is invalid.' 12 }
    Read-Json $path
}
function Installed-Modules() {
    $registry = Registry
    $profiles = @(Safe-Files (Join-Path $package 'profiles/catalog') 'Installed Profile catalog' | Where-Object Name -CEQ 'profile.json' | ForEach-Object {
        $profile = Read-Json $_.FullName
        [ordered]@{ id=[string]$profile.id; modules=@($profile.moduleSelections | ForEach-Object { [string]$_.id }) }
    })
    @($registry.modules | ForEach-Object {
        $entry = $_
        $manifestPath = Under $package ([string]$entry.manifestPath) 'Installed Module manifest' -MustExist
        if ((Hash $manifestPath) -cne [string]$entry.manifestSha256) { Fail "Installed Module manifest hash drift: $($entry.id)" 12 }
        $manifest = Read-Json $manifestPath
        $lockPath = Under $package ([string]$manifest.dependencyLock.path) 'Installed dependency lock' -MustExist
        if ((Hash $lockPath) -cne [string]$manifest.dependencyLock.sha256) { Fail "Installed dependency lock hash drift: $($entry.id)" 12 }
        $lock = Read-Json $lockPath
        [ordered]@{
            id=[string]$entry.id; version=[string]$manifest.version; provenance='installed-immutable'
            manifestPath=[string]$entry.manifestPath; manifestSha256=[string]$entry.manifestSha256
            compatibleApi=[string]$manifest.compatibleApi; supportedPlatforms=@($manifest.supportedPlatforms)
            stages=@($manifest.stages); capabilities=$manifest.capabilities; prerequisites=@($manifest.prerequisites)
            profileUsage=@($profiles | Where-Object { $_.modules -ccontains [string]$entry.id } | ForEach-Object { $_.id } | Sort-Object)
            dependencies=@($lock.dependencies); allowedCapabilities=$entry.allowedCapabilities
        }
    } | Sort-Object { $_.id })
}
function Candidate-Root() {
    $state = Directory $StateRoot 'StateRoot' -Create
    Assert-Disjoint $state $package 'StateRoot and PackageRoot'
    if ($TargetRoot) { $target = Directory $TargetRoot 'TargetRoot'; Assert-Disjoint $state $target 'StateRoot and TargetRoot' }
    Under $state $Candidate 'Candidate' -MustExist
}
function Validate-Candidate([string] $Root) {
    $moduleRoot = Join-Path $Root "package/modules/$Module"
    $manifestPath = Under $Root "package/modules/$Module/module.json" 'Candidate Module manifest' -MustExist
    if (@((Registry).modules | Where-Object id -CEQ $Module).Count -ne 0) { Fail "Candidate attempts to replace built-in Module: $Module" 16 }
    if (-not (Test-Json -LiteralPath $manifestPath -SchemaFile (Join-Path $package 'core/contracts/module.schema.json') -ErrorAction SilentlyContinue)) { Fail 'Candidate Module schema validation failed.' }
    $manifest = Read-Json $manifestPath
    if ($manifest.id -cne $Module) { Fail 'Candidate Module identity mismatch.' }
    $adapter = Under $Root "package/$($manifest.adapter.path)" 'Candidate adapter' -MustExist
    if ((Hash $adapter) -cne [string]$manifest.adapter.sha256) { Fail 'Candidate adapter hash mismatch.' 12 }
    $config = Under $Root "package/$($manifest.configSchema)" 'Candidate config schema' -MustExist
    $configDocument = Read-Json $config
    if ($configDocument.'$schema' -cne 'http://json-schema.org/draft-07/schema#' -or $configDocument.type -cne 'object' -or $configDocument.additionalProperties -ne $false) { Fail 'Candidate config schema is not a closed draft-07 object schema.' }
    $lockPath = Under $Root "package/$($manifest.dependencyLock.path)" 'Candidate dependency lock' -MustExist
    if ((Hash $lockPath) -cne [string]$manifest.dependencyLock.sha256) { Fail 'Candidate dependency lock hash mismatch.' 12 }
    $lock = Read-Json $lockPath
    if ($lock.formatVersion -ne 1 -or $lock.moduleId -cne $Module -or $null -eq $lock.dependencies) { Fail 'Candidate dependency lock identity is invalid.' }
    if ([string]$manifest.resultSchema -notin @('core/contracts/stage-result.schema.json','core/contracts/stage-result-spike.schema.json')) { Fail 'Candidate result schema is not an allowed Stage result contract.' }
    if (@($manifest.capabilities.writeRoots | Where-Object { $_ -notin @('StateRoot','EvidenceRoot') }).Count -or $manifest.capabilities.network) { Fail 'Candidate requests an unsupported write root or network capability.' 13 }
    if (@($manifest.capabilities.processes).Count -ne 1 -or [string]$manifest.capabilities.processes[0] -cne 'pwsh') { Fail 'Candidate synthetic fixtures may request only the pwsh process.' 13 }
    if ([int]$manifest.capabilities.timeoutSeconds -lt 1 -or [int]$manifest.capabilities.timeoutSeconds -gt 3600) { Fail 'Candidate timeout is outside the accepted range.' 13 }
    foreach ($runtime in @($manifest.prerequisites | ForEach-Object { [string]$_.runtime })) { if (-not (Get-Command $runtime -ErrorAction SilentlyContinue)) { Fail "Candidate prerequisite is unavailable: $runtime" 15 } }
    $profilePath = Under $Root "package/profiles/catalog/$($Module.Replace('-','_'))_profile/profile.json" 'Candidate companion Profile' -MustExist
    if (-not (Test-Json -LiteralPath $profilePath -SchemaFile (Join-Path $package 'core/contracts/profile.schema.json') -ErrorAction SilentlyContinue)) { Fail 'Candidate companion Profile is missing or invalid.' }
    $profile = Read-Json $profilePath
    if (@($profile.moduleSelections | Where-Object id -CEQ $Module).Count -ne 1) { Fail 'Candidate companion Profile does not select the Module exactly once.' }
    [ordered]@{ root=$Root; manifest=$manifest; manifestPath=$manifestPath; profile=$profile; profilePath=$profilePath; lock=$lock }
}
function Tree-Hash([string] $Root) {
    $lines = @(Safe-Files $Root 'Tree hash input' | ForEach-Object { "$([IO.Path]::GetRelativePath($Root,$_.FullName).Replace('\','/'))`0$(Hash $_.FullName)" } | Sort-Object -CaseSensitive)
    $bytes = [Text.Encoding]::UTF8.GetBytes(($lines -join "`n"))
    [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
}

$package = Directory $PackageRoot 'PackageRoot'
$governance = Join-Path $package 'core/governance/governance-contract.json'
if (-not [IO.File]::Exists($governance)) { Fail 'M5 governance contract is missing.' 12 }
$catalog = Read-Json $governance
$resultEntry = @($catalog.files | Where-Object path -CEQ 'core/modules/contracts/module-lifecycle-result.schema.json')
if ($resultEntry.Count -ne 1 -or (Hash (Join-Path $package $resultEntry[0].path)) -cne [string]$resultEntry[0].sha256) { Fail 'Module lifecycle result schema is not hash-bound.' 12 }

switch ($Operation) {
    'inventory' {
        $modules = @(Installed-Modules)
        Result 'pass' @{ modules=$modules; moduleCount=$modules.Count; marketplace='deferred'; signatures='deferred' }
    }
    'inspect' {
        if ($Module -notmatch '^[a-z0-9-]+$') { Fail 'Module ID is invalid.' }
        $found = @(Installed-Modules | Where-Object id -CEQ $Module)
        if ($found.Count -ne 1) { Fail "Installed Module not found: $Module" }
        Result 'pass' @{ module=$found[0] }
    }
    'graph' {
        $modules = @(Installed-Modules)
        $edges = @($modules | ForEach-Object { $source=$_.id; @($_.dependencies | ForEach-Object { [ordered]@{ from=$source; to=[string]$_.id; version=if($_.ContainsKey('version')){[string]$_.version}else{[string]$_.versionRange} } }) })
        Result 'pass' @{ nodes=@($modules | ForEach-Object { [ordered]@{ id=$_.id; version=$_.version; profileUsage=$_.profileUsage } }); edges=$edges }
    }
    'scaffold' {
        if ($Module -notmatch '^[a-z][a-z0-9-]*$' -or $Version -notmatch '^[0-9]+\.[0-9]+\.[0-9]+$') { Fail 'Module ID or version is invalid.' }
        if (@((Registry).modules | Where-Object id -CEQ $Module).Count) { Fail "Built-in Module IDs cannot be scaffolded: $Module" 16 }
        $state = Directory $StateRoot 'StateRoot' -Create; Assert-Disjoint $state $package 'StateRoot and PackageRoot'
        if ($TargetRoot) { $target = Directory $TargetRoot 'TargetRoot'; Assert-Disjoint $state $target 'StateRoot and TargetRoot' }
        $relative = if ($Candidate) { Relative $Candidate 'Candidate' } else { "module-candidates/$Module/$Version" }
        $root = Under $state $relative 'Candidate'
        if ([IO.File]::Exists($root) -or [IO.Directory]::Exists($root)) { Fail 'Candidate already exists.' 17 }
        $moduleRoot = Join-Path $root "package/modules/$Module"; $profileId=$Module.Replace('-','_')+'_profile'; $profileRoot=Join-Path $root "package/profiles/catalog/$profileId"
        [void][IO.Directory]::CreateDirectory($moduleRoot); [void][IO.Directory]::CreateDirectory($profileRoot); [void][IO.Directory]::CreateDirectory((Join-Path $root 'fixtures/clean/target'))
        $config=[ordered]@{'$schema'='http://json-schema.org/draft-07/schema#';type='object';additionalProperties=$false;properties=[ordered]@{}}
        Write-Json (Join-Path $moduleRoot 'config.schema.json') $config
        $lock=[ordered]@{formatVersion=1;moduleId=$Module;dependencies=@()}; Write-Json (Join-Path $moduleRoot 'dependencies.lock.json') $lock
        $manifest=[ordered]@{formatVersion=1;id=$Module;version=$Version;compatibleApi='1.x';supportedPlatforms=@('linux-x64','win-x64');adapter=[ordered]@{kind='powershell';path="modules/$Module/adapter.ps1";sha256=('0'*64)};prerequisites=@([ordered]@{runtime='pwsh';versionRange='>=7.4'});stages=@('analysis');capabilities=[ordered]@{readRoots=@('TargetRoot','EvidenceRoot');writeRoots=@();processes=@('pwsh');network=$false;timeoutSeconds=30};configSchema="modules/$Module/config.schema.json";resultSchema='core/contracts/stage-result.schema.json';dependencyLock=[ordered]@{path="modules/$Module/dependencies.lock.json";sha256=Hash (Join-Path $moduleRoot 'dependencies.lock.json')};authorities=@()}
        Write-Json (Join-Path $moduleRoot 'module.json') $manifest
        $profile=[ordered]@{formatVersion=1;id=$profileId;version=$Version;projectIdentity=[ordered]@{id=$profileId;relativeRoots=@('.')};workspaceEvidence=[ordered]@{relativeRoots=@('.');extensions=@('.txt');excludedDirectoryNames=@('bin','obj','.git','artifacts');maximumFiles=1000;maximumFileBytes=1048576};moduleSelections=@([ordered]@{id=$Module;versionRange=">=$Version <$(([version]$Version).Major+1).0.0";config=[ordered]@{}});stageConfiguration=[ordered]@{bootstrap=[ordered]@{enabled=$false;modules=@()};analysis=[ordered]@{enabled=$true;modules=@($Module)};pre=[ordered]@{enabled=$false;modules=@()};post=[ordered]@{enabled=$false;modules=@()}};rules=@("MODULE.$($Module.ToUpperInvariant().Replace('-','_'))");baselineRefs=@()}
        Write-Json (Join-Path $profileRoot 'profile.json') $profile
        Write-Json (Join-Path $root 'fixtures/manifest.json') ([ordered]@{formatVersion=1;cases=@([ordered]@{id='clean';stage='analysis';target='fixtures/clean/target';expectedStatus='pass';expectedExitCategory='success'})})
        [IO.File]::WriteAllText((Join-Path $moduleRoot 'ADAPTER_REQUIRED.md'), "Provide adapter.ps1, then replace module.json adapter.sha256 with its SHA-256.`n", [Text.UTF8Encoding]::new($false))
        Result 'candidate' @{ candidate=$relative; moduleId=$Module; version=$Version; adapterSourceGenerated=$false; authoritative=$false }
    }
    'validate' {
        if ($Module -notmatch '^[a-z0-9-]+$') { Fail 'Module ID is invalid.' }
        $validated = Validate-Candidate (Candidate-Root)
        Result 'pass' @{ moduleId=$Module; version=$validated.manifest.version; candidate=$Candidate; manifestSha256=Hash $validated.manifestPath; profileSha256=Hash $validated.profilePath; immutableCandidate=$true }
    }
    'test' {
        if (-not $AllowSyntheticFixture) { Fail 'Candidate adapter execution is disabled outside explicit synthetic fixture validation; no OS sandbox is provided.' 13 }
        $root = Candidate-Root; $validated = Validate-Candidate $root
        $fixturesPath=Under $root 'fixtures/manifest.json' 'Fixture manifest' -MustExist
        $fixtures=Read-Json $fixturesPath; if($fixtures.formatVersion-ne 1 -or @($fixtures.cases).Count-lt 1){Fail 'Fixture manifest is invalid.'}
        $evidence=Directory $EvidenceRoot 'EvidenceRoot' -Create; Assert-Disjoint $evidence $package 'EvidenceRoot and PackageRoot'; Assert-Disjoint $evidence $root 'EvidenceRoot and candidate'
        $adapter=Under $root "package/$($validated.manifest.adapter.path)" 'Candidate adapter' -MustExist; $caseResults=@()
        foreach($case in $fixtures.cases){
            if([string]$case.id -notmatch '^[a-z0-9-]+$' -or [string]$case.stage -notin @($validated.manifest.stages)){Fail 'Fixture identity or Stage is invalid.'}
            $fixtureTarget=Under $root ([string]$case.target) 'Fixture Target' -MustExist; $before=Tree-Hash $fixtureTarget; $packageBefore=Tree-Hash (Join-Path $root 'package'); $stateBefore=Tree-Hash $StateRoot
            $caseEvidence=Join-Path $evidence "module-tests/$Module/$($case.id)"; [void][IO.Directory]::CreateDirectory($caseEvidence)
            $input=[ordered]@{formatVersion=1;stage=[string]$case.stage;targetRoot=$fixtureTarget;packageRoot=(Join-Path $root 'package');stateRoot=$StateRoot;evidenceRoot=$caseEvidence;projectId='module-lifecycle-fixture';runId=('f'*32);relativeRoots=@('.');config=[ordered]@{}}
            $run=Invoke-SyntheticAdapter $adapter ($input|ConvertTo-Json -Compress -Depth 100) ([int]$validated.manifest.capabilities.timeoutSeconds) $root $caseEvidence; $outputText=[string]$run.output; $code=[int]$run.code
            if($code-ne0){Fail "Fixture adapter failed: $($case.id): $outputText" 14}; try{$actual=$outputText|ConvertFrom-Json -AsHashtable -Depth 100}catch{Fail "Fixture adapter returned invalid JSON: $($case.id)" 14}
            if($actual.status-cne[string]$case.expectedStatus -or $actual.exitCategory-cne[string]$case.expectedExitCategory){Fail "Fixture result mismatch: $($case.id)" 16}
            if((Tree-Hash $fixtureTarget)-cne$before -or (Tree-Hash (Join-Path $root 'package'))-cne$packageBefore -or (Tree-Hash $StateRoot)-cne$stateBefore){Fail "Fixture mutated Target, candidate Package or StateRoot: $($case.id)" 16}
            $caseResults += [ordered]@{id=[string]$case.id;status=[string]$actual.status;exitCategory=[string]$actual.exitCategory}
        }
        Result 'pass' @{ moduleId=$Module; fixtureCount=$caseResults.Count; fixtures=$caseResults; evidenceRoot=$evidence; executionBoundary='synthetic-fixture-only'; osSandbox=$false; inheritedEnvironment=$false }
    }
    'diff' {
        $root=Candidate-Root; $validated=Validate-Candidate $root; $paths=@(Safe-Files (Join-Path $root 'package') 'Candidate diff input' | ForEach-Object{[IO.Path]::GetRelativePath((Join-Path $root 'package'),$_.FullName).Replace('\','/')}|Sort-Object -CaseSensitive)
        Result 'pass' @{ moduleId=$Module; against='installed-immutable-catalog'; changes=@($paths|ForEach-Object{[ordered]@{path=$_;change='add';sha256=Hash (Join-Path $root "package/$_")}}); replacementRefused=$true }
    }
    'pack' {
        $root=Candidate-Root; $validated=Validate-Candidate $root; $evidence=Directory $EvidenceRoot 'EvidenceRoot' -Create; Assert-Disjoint $evidence $package 'EvidenceRoot and PackageRoot'; Assert-Disjoint $evidence $root 'EvidenceRoot and candidate'
        $relative=Relative $Output 'Pack output'; $destination=Under $evidence $relative 'Pack output'; if([IO.Directory]::Exists($destination)-or[IO.File]::Exists($destination)){Fail 'Pack output already exists.' 17}
        [void][IO.Directory]::CreateDirectory((Join-Path $destination 'package')); Copy-SafeTree (Join-Path $root 'package/modules') (Join-Path $destination 'package/modules') 'Candidate Module pack input'; Copy-SafeTree (Join-Path $root 'package/profiles') (Join-Path $destination 'package/profiles') 'Candidate Profile pack input'
        $files=@(Safe-Files (Join-Path $destination 'package') 'Packed bundle input'|ForEach-Object{[ordered]@{path=[IO.Path]::GetRelativePath((Join-Path $destination 'package'),$_.FullName).Replace('\','/');sha256=Hash $_.FullName;size=$_.Length}}|Sort-Object{$_.path})
        $profileRelative=[IO.Path]::GetRelativePath((Join-Path $destination 'package'),(Join-Path $destination "package/profiles/catalog/$($validated.profile.id)/profile.json")).Replace('\','/')
        $manifest=[ordered]@{formatVersion=1;id="$Module-extension";version=[string]$validated.manifest.version;compatibleApi='1.x';baseVersion=[string](Read-Json (Join-Path $package 'plugin.json')).version;profiles=@([ordered]@{id=[string]$validated.profile.id;version=[string]$validated.profile.version;path=$profileRelative;sha256=Hash (Join-Path $destination "package/$profileRelative")});modules=@([ordered]@{id=$Module;version=[string]$validated.manifest.version;manifestPath="modules/$Module/module.json";manifestSha256=Hash (Join-Path $destination "package/modules/$Module/module.json");allowedCapabilities=[ordered]@{readRoots=@($validated.manifest.capabilities.readRoots);writeRoots=@($validated.manifest.capabilities.writeRoots);processes=@($validated.manifest.capabilities.processes);network=[bool]$validated.manifest.capabilities.network;maxTimeoutSeconds=[int]$validated.manifest.capabilities.timeoutSeconds}});files=$files}
        Write-Json (Join-Path $destination 'bundle-manifest.json') $manifest; if(-not(Test-Json -LiteralPath (Join-Path $destination 'bundle-manifest.json') -SchemaFile (Join-Path $package 'core/contracts/extension-bundle.schema.json') -ErrorAction SilentlyContinue)){Fail 'Packed bundle violates extension-bundle schema.' 12}
        $archive="$destination.zip"; Add-Type -AssemblyName System.IO.Compression; $stream=[IO.File]::Open($archive,[IO.FileMode]::CreateNew); try{$zip=[IO.Compression.ZipArchive]::new($stream,[IO.Compression.ZipArchiveMode]::Create,$false);try{foreach($file in Safe-Files $destination 'Archive input'|Sort-Object{$_.FullName}){$name=[IO.Path]::GetRelativePath($destination,$file.FullName).Replace('\','/');$entry=$zip.CreateEntry($name,[IO.Compression.CompressionLevel]::Optimal);$entry.LastWriteTime=[DateTimeOffset]::new(1980,1,1,0,0,0,[TimeSpan]::Zero);$input=[IO.File]::OpenRead($file.FullName);$outputStream=$entry.Open();try{$input.CopyTo($outputStream)}finally{$outputStream.Dispose();$input.Dispose()}}}finally{$zip.Dispose()}}finally{$stream.Dispose()}
        Result 'candidate' @{ moduleId=$Module; bundle=$relative; bundleManifestSha256=Hash (Join-Path $destination 'bundle-manifest.json'); archive="$relative.zip"; archiveSha256=Hash $archive; deterministic=$true; authoritative=$false }
    }
    'review' {
        $evidence=Directory $EvidenceRoot 'EvidenceRoot' -Create; $bundle=Under $evidence $BundleRoot 'Bundle root' -MustExist; $manifestPath=Under $bundle 'bundle-manifest.json' 'Bundle manifest' -MustExist; if(-not(Test-Json -LiteralPath $manifestPath -SchemaFile (Join-Path $package 'core/contracts/extension-bundle.schema.json') -ErrorAction SilentlyContinue)){Fail 'Bundle is invalid.'}
        if($ReviewAuthority -match '^\s*$' -or $BaseArchiveSha256 -notmatch '^[a-f0-9]{64}$'){Fail 'Review authority or base archive hash is invalid.'}
        $manifest=Read-Json $manifestPath; $proposal=[ordered]@{formatVersion=1;state='proposal';id="$(Get-Date -Format yyyyMMdd)-$($manifest.id)-review";scope='production';decision='unresolved';acceptedBy=[ordered]@{authorityType='human-review';authorityId=$ReviewAuthority;candidateHostVerdictAllowed=$false};bundleManifestSha256=Hash $manifestPath;baseArchiveSha256=$BaseArchiveSha256;moduleCeilings=@($manifest.modules|ForEach-Object{[ordered]@{moduleId=$_.id;allowedCapabilities=$_.allowedCapabilities}});authoritative=$false;requiredAction='Operator must review, change decision to accepted, remove proposal-only fields and validate against extension-review.schema.json.'}
        $path=Under $evidence (Relative $Output 'Review output') 'Review output'; Write-Json $path $proposal; Result 'candidate' @{ reviewProposal=[IO.Path]::GetRelativePath($evidence,$path).Replace('\','/'); bundleManifestSha256=$proposal.bundleManifestSha256; productionAccepted=$false }
    }
    'compose' {
        foreach($value in @($BaseInstallRoot,$BaseReceiptPath,$BaseArchivePath,$BundleRoot,$ReviewRecordPath,$OutputInstallRoot,$CompositionReceiptPath,$TargetRoot,$StateRoot,$EvidenceRoot)){if([string]::IsNullOrWhiteSpace($value)){Fail 'Compose requires all base, bundle, review, output, receipt and root paths.'}}
        $script=Join-Path $package 'core/distribution/Compose-V4Extension.ps1'; $outputText=@(& $script -BaseInstallRoot $BaseInstallRoot -BaseReceiptPath $BaseReceiptPath -BaseArchivePath $BaseArchivePath -BundleRoot $BundleRoot -ReviewRecordPath $ReviewRecordPath -OutputInstallRoot $OutputInstallRoot -CompositionReceiptPath $CompositionReceiptPath -TargetRoot $TargetRoot -StateRoot $StateRoot -EvidenceRoot $EvidenceRoot -AllowSyntheticFixture:$AllowSyntheticFixture 2>&1)-join"`n"; if($LASTEXITCODE-ne0){Fail "Composition authority refused: $outputText" 16}; Result 'pass' @{ delegatedAuthority='core/distribution/Compose-V4Extension.ps1'; composition=($outputText|ConvertFrom-Json -AsHashtable -Depth 100); selected=$false }
    }
    'verify' {
        foreach($value in @($InstallRoot,$ReceiptPath)){if([string]::IsNullOrWhiteSpace($value)){Fail 'Verify requires InstallRoot and ReceiptPath.'}}
        $script=Join-Path $package 'core/distribution/Test-V4ComposedInstallation.ps1'; $arguments=@('-InstallRoot',$InstallRoot,'-ReceiptPath',$ReceiptPath);if($BaseReceiptPath){$arguments+=@('-BaseReceiptPath',$BaseReceiptPath)};if($AllowSyntheticFixture){$arguments+='-AllowSyntheticFixture'};$outputText=@(& $script @arguments 2>&1)-join"`n";if($LASTEXITCODE-ne0){Fail "Verification authority refused: $outputText" 16};Result 'pass' @{delegatedAuthority='core/distribution/Test-V4ComposedInstallation.ps1';verification=($outputText|ConvertFrom-Json -AsHashtable -Depth 100)}
    }
}
