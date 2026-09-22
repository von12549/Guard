[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $PackageRoot,
    [Parameter(Mandatory)][string] $HostRoot,
    [Parameter(Mandatory)][string] $OutputDirectory,
    [Parameter(Mandatory)][ValidatePattern('^[a-fA-F0-9]{40}$')][string] $SourceCommit
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Hash([string] $Path) { (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant() }
function Is-Under([string] $Path, [string] $Root) {
    $relative = [IO.Path]::GetRelativePath($Root, $Path)
    $relative -eq '.' -or (-not [IO.Path]::IsPathRooted($relative) -and $relative -ne '..' -and -not $relative.StartsWith("..$([IO.Path]::DirectorySeparatorChar)"))
}
function Write-Json([string] $Path, $Value) {
    $json = ($Value | ConvertTo-Json -Depth 30).Replace("`r`n", "`n") + "`n"
    [IO.File]::WriteAllText($Path, $json, [Text.UTF8Encoding]::new($false))
}

$package = [IO.Path]::TrimEndingDirectorySeparator([IO.Path]::GetFullPath($PackageRoot))
$hostDirectory = [IO.Path]::TrimEndingDirectorySeparator([IO.Path]::GetFullPath($HostRoot))
$output = [IO.Path]::TrimEndingDirectorySeparator([IO.Path]::GetFullPath($OutputDirectory))
if (-not [IO.Directory]::Exists($package) -or -not [IO.Directory]::Exists($hostDirectory)) { throw 'PackageRoot and HostRoot must exist.' }
if (Is-Under $output $package) { throw 'OutputDirectory must be outside immutable PackageRoot.' }
[void][IO.Directory]::CreateDirectory($output)

$checkOutput = @(& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $package 'core/runtime/Test-V4Package.ps1') -PackageRoot $package 2>&1)
if ($LASTEXITCODE -ne 0) { throw "Package validation failed: $($checkOutput -join "`n")" }
$packageResult = ($checkOutput -join "`n") | ConvertFrom-Json
$plugin = Get-Content -Raw (Join-Path $package 'plugin.json') | ConvertFrom-Json
$rootName = "v4-guards-$($plugin.version)"
$archivePath = Join-Path $output "$rootName.zip"
$sidecarPath = "$archivePath.sha256"
if ([IO.File]::Exists($archivePath) -or [IO.File]::Exists($sidecarPath)) { throw 'Distribution output already exists; use a clean OutputDirectory.' }

$hostDll = Join-Path $hostDirectory 'v4-guards.dll'
if (-not [IO.File]::Exists($hostDll)) { throw 'HostRoot does not contain v4-guards.dll.' }
$hostFiles = @(Get-ChildItem -LiteralPath $hostDirectory -File -Recurse -Force | Where-Object { $_.Extension -in @('.dll','.json') } | Sort-Object FullName)
if (@($hostFiles | Where-Object Name -eq 'v4-guards.runtimeconfig.json').Count -ne 1 -or @($hostFiles | Where-Object Name -eq 'v4-guards.deps.json').Count -ne 1) {
    throw 'HostRoot must contain v4-guards.deps.json and v4-guards.runtimeconfig.json.'
}

$staging = Join-Path $output ('.v4-dist-' + [Guid]::NewGuid().ToString('N'))
try {
    $payloadRoot = Join-Path $staging $rootName
    [void][IO.Directory]::CreateDirectory($payloadRoot)
    $files = [Collections.Generic.List[object]]::new()
    foreach ($authority in @($packageResult.authorityFiles | Sort-Object path)) {
        $relative = [string]$authority.path
        $source = Join-Path $package $relative
        $destination = Join-Path $payloadRoot ("package/$relative")
        [void][IO.Directory]::CreateDirectory((Split-Path -Parent $destination))
        [IO.File]::Copy($source, $destination, $false)
        $files.Add([ordered]@{ path="package/$relative"; kind='package'; sha256=Hash $destination; size=(Get-Item $destination).Length })
    }
    foreach ($file in $hostFiles) {
        $relative = [IO.Path]::GetRelativePath($hostDirectory, $file.FullName).Replace('\','/')
        $destination = Join-Path $payloadRoot ("host/$relative")
        [void][IO.Directory]::CreateDirectory((Split-Path -Parent $destination))
        [IO.File]::Copy($file.FullName, $destination, $false)
        $files.Add([ordered]@{ path="host/$relative"; kind='host'; sha256=Hash $destination; size=$file.Length })
    }
    $manifest = [ordered]@{
        formatVersion=1; id='v4-guards'; version=[string]$plugin.version; rootDirectory=$rootName
        source=[ordered]@{
            commit=$SourceCommit.ToLowerInvariant(); packageHash=[string]$packageResult.packageHash
            contractsManifestSha256=Hash (Join-Path $package 'core/contracts/contracts-manifest.json')
            hostSha256=Hash $hostDll
        }
        files=@($files | Sort-Object path)
    }
    $manifestPath = Join-Path $payloadRoot 'distribution-manifest.json'
    Write-Json $manifestPath $manifest
    if (-not (Test-Json -LiteralPath $manifestPath -SchemaFile (Join-Path $package 'core/contracts/distribution-manifest.schema.json') -ErrorAction SilentlyContinue)) {
        throw 'Distribution manifest violates its schema.'
    }

    Add-Type -AssemblyName System.IO.Compression
    $stream = [IO.File]::Open($archivePath, [IO.FileMode]::CreateNew, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    try {
        $zip = [IO.Compression.ZipArchive]::new($stream, [IO.Compression.ZipArchiveMode]::Create, $false, [Text.Encoding]::UTF8)
        try {
            foreach ($file in @(Get-ChildItem -LiteralPath $payloadRoot -File -Recurse -Force | Sort-Object FullName)) {
                $relative = [IO.Path]::GetRelativePath($staging, $file.FullName).Replace('\','/')
                $entry = $zip.CreateEntry($relative, [IO.Compression.CompressionLevel]::NoCompression)
                $entry.LastWriteTime = [DateTimeOffset]::new(1980,1,1,0,0,0,[TimeSpan]::Zero)
                $input = [IO.File]::OpenRead($file.FullName)
                $target = $entry.Open()
                try { $input.CopyTo($target) } finally { $target.Dispose(); $input.Dispose() }
            }
        } finally { $zip.Dispose() }
    } finally { $stream.Dispose() }
    $archiveHash = Hash $archivePath
    [IO.File]::WriteAllText($sidecarPath, "$archiveHash  $([IO.Path]::GetFileName($archivePath))`n", [Text.UTF8Encoding]::new($false))
    [ordered]@{ formatVersion=1; status='pass'; version=[string]$plugin.version; archivePath=$archivePath; archiveSha256=$archiveHash; manifestSha256=Hash $manifestPath; packageHash=[string]$packageResult.packageHash } | ConvertTo-Json -Depth 10
}
finally {
    if ([IO.Directory]::Exists($staging)) { Remove-Item -LiteralPath $staging -Recurse -Force }
}
