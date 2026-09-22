[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('Install','Uninstall')][string] $Mode,
    [Parameter(Mandatory)][string] $InstallRoot,
    [Parameter(Mandatory)][string] $ReceiptPath,
    [string] $ArchivePath = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Hash([string] $Path) { (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant() }
function Is-Under([string] $Path, [string] $Root) {
    $relative = [IO.Path]::GetRelativePath($Root, $Path)
    $relative -eq '.' -or (-not [IO.Path]::IsPathRooted($relative) -and $relative -ne '..' -and -not $relative.StartsWith("..$([IO.Path]::DirectorySeparatorChar)"))
}
function Write-Json([string] $Path, $Value) {
    [void][IO.Directory]::CreateDirectory((Split-Path -Parent $Path))
    $json = ($Value | ConvertTo-Json -Depth 30).Replace("`r`n", "`n") + "`n"
    [IO.File]::WriteAllText($Path, $json, [Text.UTF8Encoding]::new($false))
}
function Assert-SafeRoot([string] $Path) {
    $root = [IO.Path]::GetPathRoot($Path)
    if ([string]::IsNullOrWhiteSpace($root) -or $Path.TrimEnd('\','/') -eq $root.TrimEnd('\','/')) { throw 'InstallRoot cannot be a filesystem root.' }
    $parent = Split-Path -Parent $Path
    if ([string]::IsNullOrWhiteSpace($parent)) { throw 'InstallRoot must have an explicit parent.' }
    $probe = $parent
    while (-not [IO.Directory]::Exists($probe)) { $probe = Split-Path -Parent $probe; if ([string]::IsNullOrWhiteSpace($probe)) { throw 'InstallRoot parent cannot be resolved.' } }
    while ($null -ne $probe) {
        $item = Get-Item -LiteralPath $probe -Force
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or $null -ne $item.LinkTarget) { throw "InstallRoot parent crosses a link or reparse point: $probe" }
        $next = Split-Path -Parent $probe
        if ([string]::IsNullOrWhiteSpace($next) -or $next -eq $probe) { break }
        $probe = $next
    }
}
function Validate-Receipt($Receipt, [string] $Schema) {
    $json = $Receipt | ConvertTo-Json -Depth 30 -Compress
    if (-not (Test-Json -Json $json -SchemaFile $Schema -ErrorAction SilentlyContinue)) { throw 'Install receipt violates its schema.' }
}

$install = [IO.Path]::TrimEndingDirectorySeparator([IO.Path]::GetFullPath($InstallRoot))
$receiptFile = [IO.Path]::GetFullPath($ReceiptPath)
Assert-SafeRoot $install
if (Is-Under $receiptFile $install) { throw 'ReceiptPath must be outside InstallRoot.' }
$receiptSchema = Join-Path $PSScriptRoot '../contracts/install-receipt.schema.json'
$manifestSchema = Join-Path $PSScriptRoot '../contracts/distribution-manifest.schema.json'

if ($Mode -eq 'Uninstall') {
    if (-not [IO.File]::Exists($receiptFile)) { throw 'Install receipt is missing.' }
    $receipt = Get-Content -Raw -LiteralPath $receiptFile | ConvertFrom-Json -AsHashtable -Depth 100
    Validate-Receipt $receipt $receiptSchema
    if ($receipt.status -cne 'installed' -or [string]$receipt.installRoot -cne $install) { throw 'Receipt does not authorize this installed root.' }
    if (-not [IO.Directory]::Exists($install)) { throw 'Installed root is missing.' }
    $actualPaths = @(Get-ChildItem -LiteralPath $install -File -Recurse -Force | ForEach-Object { [IO.Path]::GetRelativePath($install,$_.FullName).Replace('\','/') } | Sort-Object)
    $expectedPaths = @($receipt.files.path | Sort-Object)
    if (($actualPaths -join "`0") -cne ($expectedPaths -join "`0")) { throw 'Installed file set drift prevents uninstall.' }
    foreach ($file in $receipt.files) {
        $path = Join-Path $install ([string]$file.path)
        $item = Get-Item -LiteralPath $path -Force
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or $null -ne $item.LinkTarget -or (Hash $path) -cne [string]$file.sha256 -or $item.Length -ne [long]$file.size) {
            throw "Installed file drift prevents uninstall: $($file.path)"
        }
    }
    Remove-Item -LiteralPath $install -Recurse -Force
    $receipt.status = 'uninstalled'
    Write-Json $receiptFile $receipt
    [ordered]@{ formatVersion=1; status='pass'; mode='uninstall'; installRoot=$install; receiptPath=$receiptFile } | ConvertTo-Json
    exit 0
}

if ([string]::IsNullOrWhiteSpace($ArchivePath)) { throw 'ArchivePath is required for Install.' }
$archive = [IO.Path]::GetFullPath($ArchivePath)
if (-not [IO.File]::Exists($archive)) { throw 'Distribution archive is missing.' }
if (Is-Under $archive $install) { throw 'ArchivePath must be outside InstallRoot.' }
if ([IO.Directory]::Exists($install) -or [IO.File]::Exists($install)) { throw 'InstallRoot must not already exist.' }
if ([IO.File]::Exists($receiptFile)) {
    $old = Get-Content -Raw -LiteralPath $receiptFile | ConvertFrom-Json -AsHashtable -Depth 100
    Validate-Receipt $old $receiptSchema
    if ($old.status -cne 'uninstalled' -or [string]$old.installRoot -cne $install) { throw 'Existing receipt does not permit reinstall.' }
}

Add-Type -AssemblyName System.IO.Compression
$zip = [IO.Compression.ZipFile]::OpenRead($archive)
$temporary = Join-Path (Split-Path -Parent $install) ('.v4-install-' + [Guid]::NewGuid().ToString('N'))
$installedThisRun = $false
try {
    $entries = @($zip.Entries | Where-Object { -not [string]::IsNullOrEmpty($_.Name) })
    $names = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($entry in $entries) {
        $name = $entry.FullName.Replace('\','/')
        if (-not $names.Add($name)) { throw "Duplicate archive entry: $name" }
        $segments = $name.Split('/',[StringSplitOptions]::RemoveEmptyEntries)
        $unixType = (($entry.ExternalAttributes -shr 16) -band 0xF000)
        if ($segments.Count -lt 2 -or $segments -contains '..' -or $segments -contains '.' -or [IO.Path]::IsPathRooted($name) -or $unixType -eq 0xA000) { throw "Unsafe archive entry: $name" }
    }
    $roots = @($entries | ForEach-Object { $_.FullName.Replace('\','/').Split('/')[0] } | Sort-Object -Unique)
    if ($roots.Count -ne 1 -or $roots[0] -notmatch '^v4-guards-[0-9]+\.[0-9]+\.[0-9]+$') { throw 'Archive must contain exactly one versioned root.' }
    $rootName = $roots[0]
    $manifestEntry = @($entries | Where-Object { $_.FullName.Replace('\','/') -ceq "$rootName/distribution-manifest.json" })
    if ($manifestEntry.Count -ne 1) { throw 'Distribution manifest entry is missing or duplicated.' }
    $reader = [IO.StreamReader]::new($manifestEntry[0].Open(), [Text.Encoding]::UTF8, $true)
    try { $manifestText = $reader.ReadToEnd() } finally { $reader.Dispose() }
    if (-not (Test-Json -Json $manifestText -SchemaFile $manifestSchema -ErrorAction SilentlyContinue)) { throw 'Distribution manifest violates its schema.' }
    $manifest = $manifestText | ConvertFrom-Json -AsHashtable -Depth 100
    if ([string]$manifest.rootDirectory -cne $rootName) { throw 'Distribution root and manifest differ.' }
    $declared = @($manifest.files.path | ForEach-Object { "$rootName/$_" } | Sort-Object)
    $actual = @($entries | Where-Object { $_ -ne $manifestEntry[0] } | ForEach-Object { $_.FullName.Replace('\','/') } | Sort-Object)
    if (($declared -join "`0") -cne ($actual -join "`0")) { throw 'Archive payload does not exactly match the distribution manifest.' }
    foreach ($file in $manifest.files) {
        $entryName = "$rootName/$($file.path)"
        $entry = @($entries | Where-Object { $_.FullName.Replace('\','/') -ceq $entryName })[0]
        $sha = [Security.Cryptography.SHA256]::Create(); $source = $entry.Open()
        try { $entryHash = [Convert]::ToHexString($sha.ComputeHash($source)).ToLowerInvariant() } finally { $source.Dispose(); $sha.Dispose() }
        if ($entryHash -cne [string]$file.sha256 -or $entry.Length -ne [long]$file.size) { throw "Archive payload hash drift: $($file.path)" }
    }

    [void][IO.Directory]::CreateDirectory($temporary)
    foreach ($entry in $entries) {
        $relative = ($entry.FullName.Replace('\','/') -replace ('^' + [Regex]::Escape($rootName) + '/'), '')
        $destination = [IO.Path]::GetFullPath((Join-Path $temporary $relative))
        if (-not (Is-Under $destination $temporary)) { throw "Archive extraction escaped InstallRoot: $relative" }
        [void][IO.Directory]::CreateDirectory((Split-Path -Parent $destination))
        $source = $entry.Open(); $target = [IO.File]::Open($destination,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
        try { $source.CopyTo($target) } finally { $target.Dispose(); $source.Dispose() }
    }
    Move-Item -LiteralPath $temporary -Destination $install
    $installedThisRun = $true
    $receiptFiles = @(Get-ChildItem -LiteralPath $install -File -Recurse -Force | Sort-Object FullName | ForEach-Object { [ordered]@{ path=[IO.Path]::GetRelativePath($install,$_.FullName).Replace('\','/'); sha256=Hash $_.FullName; size=$_.Length } })
    $archiveHash = Hash $archive
    $manifestHash = Hash (Join-Path $install 'distribution-manifest.json')
    $receipt = [ordered]@{ formatVersion=1; id=$archiveHash.Substring(0,32); status='installed'; version=[string]$manifest.version; installRoot=$install; archiveSha256=$archiveHash; manifestSha256=$manifestHash; files=$receiptFiles }
    Validate-Receipt $receipt $receiptSchema
    Write-Json $receiptFile $receipt
    [ordered]@{ formatVersion=1; status='pass'; mode='install'; version=[string]$manifest.version; installRoot=$install; receiptPath=$receiptFile; archiveSha256=$archiveHash } | ConvertTo-Json
}
catch {
    if ($installedThisRun -and [IO.Directory]::Exists($install)) { Remove-Item -LiteralPath $install -Recurse -Force }
    throw
}
finally {
    $zip.Dispose()
    if ([IO.Directory]::Exists($temporary)) { Remove-Item -LiteralPath $temporary -Recurse -Force }
}
