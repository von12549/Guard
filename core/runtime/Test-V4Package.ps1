[CmdletBinding()]
param(
    [string] $PackageRoot = (Join-Path $PSScriptRoot '../..')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Fail([string] $Message) { throw "V4 package check failed: $Message" }

function Is-Under([string] $Path, [string] $Root) {
    $relative = [IO.Path]::GetRelativePath($Root, $Path)
    return $relative -eq '.' -or (-not [IO.Path]::IsPathRooted($relative) -and $relative -ne '..' -and
        -not $relative.StartsWith("..$([IO.Path]::DirectorySeparatorChar)", [StringComparison]::Ordinal))
}

function Assert-NoLinks([string] $Root, [string] $Path, [string] $Label) {
    $current = Get-Item -LiteralPath $Path -Force
    while ($null -ne $current -and (Is-Under $current.FullName $Root)) {
        if (($current.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or $null -ne $current.LinkTarget) {
            Fail "$Label crosses a link or reparse point: $($current.FullName)"
        }
        if ($current.FullName -ceq $Root) { break }
        $current = if ($current -is [IO.FileInfo]) { $current.Directory } else { $current.Parent }
    }
}

function Resolve-AuthorityPath([string] $Root, [string] $Relative, [string] $Label, [ValidateSet('File','Directory')] [string] $Kind) {
    if ([string]::IsNullOrWhiteSpace($Relative) -or [IO.Path]::IsPathRooted($Relative)) { Fail "$Label must be a relative path" }
    $segments = $Relative.Replace('\','/').Split('/', [StringSplitOptions]::RemoveEmptyEntries)
    if ($segments -contains '..') { Fail "$Label contains parent traversal" }
    $full = [IO.Path]::GetFullPath((Join-Path $Root $Relative))
    if (-not (Is-Under $full $Root)) { Fail "$Label escapes PackageRoot" }
    if ($Kind -eq 'File' -and -not [IO.File]::Exists($full)) { Fail "$Label is missing: $Relative" }
    if ($Kind -eq 'Directory' -and -not [IO.Directory]::Exists($full)) { Fail "$Label is missing: $Relative" }
    Assert-NoLinks $Root $full $Label
    return $full
}

function Read-Object([string] $Path, [string] $Label) {
    try { return Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json -AsHashtable -Depth 100 }
    catch { Fail "$Label is not valid JSON: $($_.Exception.Message)" }
}

function Assert-Schema([string] $DocumentPath, [string] $SchemaPath, [string] $Label) {
    $json = Get-Content -Raw -LiteralPath $DocumentPath
    $valid = Test-Json -Json $json -SchemaFile $SchemaPath -ErrorAction SilentlyContinue
    if (-not $valid) { Fail "$Label does not satisfy $([IO.Path]::GetFileName($SchemaPath))" }
}

function File-Hash([string] $Path) { (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant() }

$root = [IO.Path]::GetFullPath($PackageRoot)
if (-not [IO.Directory]::Exists($root)) { Fail "PackageRoot does not exist: $root" }
$root = [IO.Path]::TrimEndingDirectorySeparator($root)
Assert-NoLinks $root $root 'PackageRoot'

$contracts = Resolve-AuthorityPath $root 'core/contracts' 'contracts directory' Directory
$pluginPath = Resolve-AuthorityPath $root 'plugin.json' 'plugin manifest' File
Assert-Schema $pluginPath (Join-Path $contracts 'plugin.schema.json') 'plugin manifest'
$plugin = Read-Object $pluginPath 'plugin manifest'

$contractManifestPath = Resolve-AuthorityPath $root $plugin.contractsManifest 'contracts manifest' File
$contractManifest = Read-Object $contractManifestPath 'contracts manifest'
if ($contractManifest.formatVersion -ne 1 -or $contractManifest.apiVersion -cne $plugin.apiVersion -or $contractManifest.files.Count -lt 1) {
    Fail 'contracts manifest identity is invalid'
}
$contractPaths = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
foreach ($entry in $contractManifest.files) {
    if (-not $contractPaths.Add([string]$entry.path)) { Fail "duplicate contract manifest path: $($entry.path)" }
    $contractPath = Resolve-AuthorityPath $root ([string]$entry.path) "contract $($entry.path)" File
    if ((File-Hash $contractPath) -cne [string]$entry.sha256) { Fail "contract hash drift: $($entry.path)" }
}

$modulesRoot = Resolve-AuthorityPath $root $plugin.modulesCatalog 'modules catalog' Directory
$registryPath = Resolve-AuthorityPath $root (Join-Path $plugin.modulesCatalog 'registry.json') 'module registry' File
Assert-Schema $registryPath (Join-Path $contracts 'module-registry.schema.json') 'module registry'
$registry = Read-Object $registryPath 'module registry'
$modules = @{}
$registeredDirectories = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
foreach ($entry in $registry.modules) {
    if ($modules.ContainsKey($entry.id)) { Fail "duplicate module registry ID: $($entry.id)" }
    $expectedManifest = "$($plugin.modulesCatalog)/$($entry.id)/module.json"
    if ([string]$entry.manifestPath -cne $expectedManifest) { Fail "module registry path is not canonical for $($entry.id)" }
    $manifestPath = Resolve-AuthorityPath $root $entry.manifestPath "module $($entry.id) manifest" File
    if ((File-Hash $manifestPath) -cne $entry.manifestSha256) { Fail "module manifest hash drift: $($entry.id)" }
    Assert-Schema $manifestPath (Join-Path $contracts 'module.schema.json') "module $($entry.id)"
    $module = Read-Object $manifestPath "module $($entry.id)"
    if ($module.id -cne $entry.id) { Fail "module registry/manifest ID mismatch: $($entry.id)" }

    foreach ($rootName in @($module.capabilities.readRoots)) {
        if (@($entry.allowedCapabilities.readRoots) -notcontains $rootName) { Fail "module $($entry.id) exceeds registered read-root capability: $rootName" }
    }
    foreach ($rootName in @($module.capabilities.writeRoots)) {
        if (@($entry.allowedCapabilities.writeRoots) -notcontains $rootName) { Fail "module $($entry.id) exceeds registered write-root capability: $rootName" }
    }
    foreach ($processName in @($module.capabilities.processes)) {
        if (@($entry.allowedCapabilities.processes) -notcontains $processName) { Fail "module $($entry.id) exceeds registered process capability: $processName" }
    }
    if ($module.capabilities.network -and -not $entry.allowedCapabilities.network) { Fail "module $($entry.id) exceeds registered network capability" }
    if ([int]$module.capabilities.timeoutSeconds -gt [int]$entry.allowedCapabilities.maxTimeoutSeconds) { Fail "module $($entry.id) exceeds registered timeout capability" }

    $adapterPath = Resolve-AuthorityPath $root $module.adapter.path "module $($module.id) adapter" File
    if ((File-Hash $adapterPath) -cne $module.adapter.sha256) { Fail "adapter hash drift: $($module.id)" }
    $lockPath = Resolve-AuthorityPath $root $module.dependencyLock.path "module $($module.id) dependency lock" File
    if ((File-Hash $lockPath) -cne $module.dependencyLock.sha256) { Fail "dependency lock hash drift: $($module.id)" }
    [void](Resolve-AuthorityPath $root $module.configSchema "module $($module.id) config schema" File)
    [void](Resolve-AuthorityPath $root $module.resultSchema "module $($module.id) result schema" File)
    $authorityIds = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($authority in $module.authorities) {
        if (-not $authorityIds.Add([string]$authority.id)) { Fail "module $($module.id) has duplicate authority ID: $($authority.id)" }
        $authorityPath = Resolve-AuthorityPath $root $authority.path "module $($module.id) authority $($authority.id)" File
        if ((File-Hash $authorityPath) -cne $authority.sha256) { Fail "module authority hash drift: $($module.id):$($authority.id)" }
    }
    $modules[$module.id] = $module
    [void]$registeredDirectories.Add([string]$module.id)
}
foreach ($directory in @(Get-ChildItem -LiteralPath $modulesRoot -Directory -Force | Sort-Object Name)) {
    if (-not $registeredDirectories.Contains($directory.Name)) { Fail "undisclosed module directory: $($directory.Name)" }
}

$profilesRoot = Resolve-AuthorityPath $root $plugin.profilesCatalog 'profiles catalog' Directory
$profiles = @{}
foreach ($directory in @(Get-ChildItem -LiteralPath $profilesRoot -Directory -Force | Sort-Object Name)) {
    $manifestPath = Join-Path $directory.FullName 'profile.json'
    if (-not [IO.File]::Exists($manifestPath)) { Fail "profile directory has no profile.json: $($directory.Name)" }
    Assert-NoLinks $root $manifestPath 'profile manifest'
    Assert-Schema $manifestPath (Join-Path $contracts 'profile.schema.json') "profile $($directory.Name)"
    $profile = Read-Object $manifestPath "profile $($directory.Name)"
    if ($profiles.ContainsKey($profile.id)) { Fail "duplicate profile ID: $($profile.id)" }
    if ($directory.Name -cne $profile.id) { Fail "profile directory/id mismatch: $($directory.Name)" }

    $selected = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($selection in $profile.moduleSelections) {
        if (-not $selected.Add([string]$selection.id)) { Fail "profile $($profile.id) selects duplicate module $($selection.id)" }
        if (-not $modules.ContainsKey($selection.id)) { Fail "profile $($profile.id) selects undeclared module $($selection.id)" }
        $configSchema = Resolve-AuthorityPath $root $modules[$selection.id].configSchema "module $($selection.id) config schema" File
        $configJson = $selection.config | ConvertTo-Json -Depth 100 -Compress
        if (-not (Test-Json -Json $configJson -SchemaFile $configSchema -ErrorAction SilentlyContinue)) {
            Fail "profile $($profile.id) has invalid config for module $($selection.id)"
        }
    }
    foreach ($stageName in @('bootstrap','analysis','pre','post')) {
        $stage = $profile.stageConfiguration[$stageName]
        foreach ($moduleId in $stage.modules) {
            if (-not $selected.Contains([string]$moduleId)) { Fail "profile $($profile.id) stage $stageName uses an unselected module $moduleId" }
            if (@($modules[$moduleId].stages) -notcontains $stageName) { Fail "module $moduleId does not support stage $stageName" }
        }
    }
    foreach ($baselineRef in @($profile.baselineRefs)) {
        $baselinePath = Resolve-AuthorityPath $directory.FullName ([string]$baselineRef) "profile $($profile.id) baseline" File
        Assert-Schema $baselinePath (Join-Path $contracts 'finding-baseline.schema.json') "profile $($profile.id) baseline"
    }
    $profiles[$profile.id] = $profile
}

if (-not $profiles.ContainsKey($plugin.defaultProfile)) { Fail "default profile is not installed: $($plugin.defaultProfile)" }

$authorityFiles = [Collections.Generic.List[object]]::new()
$authorityRoots = @('build','core','integrations','modules','profiles','restore','stages')
$files = [Collections.Generic.List[IO.FileInfo]]::new()
$files.Add((Get-Item -LiteralPath $pluginPath))
foreach ($name in $authorityRoots) {
    $path = Join-Path $root $name
    if ([IO.Directory]::Exists($path)) {
        foreach ($file in Get-ChildItem -LiteralPath $path -File -Recurse -Force) { $files.Add($file) }
    }
}
foreach ($file in @($files | Sort-Object FullName -Unique)) {
    Assert-NoLinks $root $file.FullName 'package authority file'
    $relative = [IO.Path]::GetRelativePath($root, $file.FullName).Replace('\','/')
    if ($relative -match '(^|/)(?:state|artifacts|\.work)(?:/|$)') { Fail "mutable path entered package authority: $relative" }
    $authorityFiles.Add([ordered]@{ path = $relative; sha256 = File-Hash $file.FullName })
}
$identity = ($authorityFiles | ForEach-Object { "$($_.path):$($_.sha256)" }) -join "`n"
$packageHash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($identity))).ToLowerInvariant()

[ordered]@{
    formatVersion = 1
    status = 'pass'
    packageHash = $packageHash
    profiles = @($profiles.Keys | Sort-Object)
    modules = @($modules.Keys | Sort-Object)
    authorityFiles = @($authorityFiles)
} | ConvertTo-Json -Depth 20
