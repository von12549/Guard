[CmdletBinding()]
param([string] $PackageRoot = (Join-Path $PSScriptRoot '../..'))

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Hash([string] $Path) { (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant() }
function Read-Json([string] $Path) { Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json -AsHashtable -Depth 100 }

$root = [IO.Path]::TrimEndingDirectorySeparator([IO.Path]::GetFullPath($PackageRoot))
$packageOutput = @(& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $root 'core/runtime/Test-V4Package.ps1') -PackageRoot $root 2>&1)
if ($LASTEXITCODE) { throw "Package validation failed: $($packageOutput -join "`n")" }
$package = ($packageOutput -join "`n") | ConvertFrom-Json

$nugetConfig = Get-Content -Raw -LiteralPath (Join-Path $root 'build/NuGet.config')
if ($nugetConfig -notmatch '<clear\s*/>' -or $nugetConfig -match '<add\s+key=') { throw 'V4 NuGet.config must remain offline with no package source.' }
if ((Get-Content -Raw -LiteralPath (Join-Path $root 'core/host/V4.Guards.Host/V4.Guards.Host.csproj')) -match '<PackageReference') { throw 'V4 host must not acquire an undeclared NuGet package.' }
if ((Get-Content -Raw -LiteralPath (Join-Path $root 'integrations/web/V4.Guards.WebCompanion/V4.Guards.WebCompanion.csproj')) -match '<PackageReference') { throw 'V4 Web Companion must not acquire an undeclared NuGet package.' }

$packageCache = if ($env:NUGET_PACKAGES) { [IO.Path]::GetFullPath($env:NUGET_PACKAGES) } else { Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::UserProfile)) '.nuget/packages' }
$locks = [Collections.Generic.List[object]]::new()
foreach ($entry in (Read-Json (Join-Path $root 'modules/registry.json')).modules) {
    $module = Read-Json (Join-Path $root ([string]$entry.manifestPath))
    $lockPath = Join-Path $root ([string]$module.dependencyLock.path)
    if ((Hash $lockPath) -cne [string]$module.dependencyLock.sha256) { throw "Dependency lock hash drift: $($entry.id)" }
    $lock = Read-Json $lockPath
    foreach ($dependency in @($lock.dependencies)) {
        $names = @($dependency.Keys | Sort-Object)
        if (-not $dependency.ContainsKey('id') -or -not $dependency.ContainsKey('source') -or (-not $dependency.ContainsKey('version') -and -not $dependency.ContainsKey('versionRange'))) { throw "Incomplete dependency lock entry: $($entry.id)" }
        if ([string]$dependency.source -eq 'nuget-global-packages') {
            if (-not $dependency.ContainsKey('version') -or -not $dependency.ContainsKey('sha512')) { throw "NuGet dependency is not version/hash pinned: $($dependency.id)" }
            $id = ([string]$dependency.id).ToLowerInvariant(); $version = [string]$dependency.version
            $shaPath = Join-Path $packageCache "$id/$version/$id.$version.nupkg.sha512"
            if (-not [IO.File]::Exists($shaPath) -or [IO.File]::ReadAllText($shaPath).Trim() -cne [string]$dependency.sha512) { throw "NuGet cache binding drift: $($dependency.id) $version" }
        }
    }
    $locks.Add([ordered]@{ moduleId=[string]$entry.id; path=[string]$module.dependencyLock.path; sha256=Hash $lockPath; dependencyCount=@($lock.dependencies).Count })
}

$runtimeRoots = @('core/host','core/runtime','core/distribution','integrations/web','modules','profiles','build')
$forbidden = [Regex]::new('(?i)(docs[\\/]guards[\\/]V3|V3_ifx|LayerGuard|IFX\.Migration|ifx_profile)')
$matches = [Collections.Generic.List[string]]::new()
foreach ($relativeRoot in $runtimeRoots) {
    foreach ($file in @(Get-ChildItem -LiteralPath (Join-Path $root $relativeRoot) -File -Recurse -Force)) {
        if ($file.Extension -notin @('.ps1','.cs','.json','.xml','.props','.targets','.csproj','.config')) { continue }
        if ($forbidden.IsMatch([IO.File]::ReadAllText($file.FullName))) { $matches.Add([IO.Path]::GetRelativePath($root,$file.FullName).Replace('\','/')) }
    }
}
if ($matches.Count) { throw "V3/IFX/LayerGuard runtime path detected: $($matches -join ', ')" }

[ordered]@{
    formatVersion=1; status='pass'; packageHash=[string]$package.packageHash
    offlineNuGet=$true; dependencyLocks=@($locks | Sort-Object moduleId); forbiddenRuntimeReferences=@()
    architectureRuntimeDependencies=@('pwsh','dotnet','roslyn','archunitnet')
} | ConvertTo-Json -Depth 20
