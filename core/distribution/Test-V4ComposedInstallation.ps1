[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $InstallRoot,
    [Parameter(Mandatory)][string] $ReceiptPath,
    [string] $BaseReceiptPath = '',
    [switch] $AllowSyntheticFixture
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Fail([string] $Message) { throw $Message }
function Hash([string] $Path) { (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant() }
function Read-Json([string] $Path) { Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json -AsHashtable -Depth 100 }
function Is-Under([string] $Path, [string] $Root) {
    $relative = [IO.Path]::GetRelativePath($Root, $Path)
    $relative -eq '.' -or (-not [IO.Path]::IsPathRooted($relative) -and $relative -ne '..' -and -not $relative.StartsWith("..$([IO.Path]::DirectorySeparatorChar)"))
}
function Same-Path([string] $A, [string] $B) {
    $comparison = if ($IsWindows) { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
    [IO.Path]::TrimEndingDirectorySeparator([IO.Path]::GetFullPath($A)).Equals(
        [IO.Path]::TrimEndingDirectorySeparator([IO.Path]::GetFullPath($B)), $comparison)
}
function Assert-NoLinks([string] $Path) {
    $current = [IO.Path]::GetFullPath($Path)
    while ($current) {
        if ([IO.File]::Exists($current) -or [IO.Directory]::Exists($current)) {
            $item = Get-Item -LiteralPath $current -Force
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or $null -ne $item.LinkTarget) {
                Fail "Link or reparse point is not allowed: $current"
            }
        }
        $parent = [IO.Path]::GetDirectoryName($current)
        if ([string]::IsNullOrEmpty($parent) -or $parent -eq $current) { break }
        $current = $parent
    }
}
function Assert-Schema([string] $Path, [string] $Name) {
    $schema = Join-Path $PSScriptRoot "../contracts/$Name.schema.json"
    if (-not (Test-Json -LiteralPath $Path -SchemaFile $schema -ErrorAction SilentlyContinue)) {
        Fail "$Name schema validation failed: $Path"
    }
}
function Assert-File([string] $Root, [string] $Relative) {
    if ([string]::IsNullOrWhiteSpace($Relative) -or [IO.Path]::IsPathRooted($Relative) -or
        @($Relative.Replace('\','/').Split('/') | Where-Object { $_ -in @('', '.', '..') }).Count -gt 0) {
        Fail "Unsafe relative path: $Relative"
    }
    $path = [IO.Path]::GetFullPath((Join-Path $Root $Relative))
    if (-not (Is-Under $path $Root) -or -not [IO.File]::Exists($path)) { Fail "Missing or escaping file: $Relative" }
    Assert-NoLinks $path
    $path
}
function Assert-Inventory([string] $Root, $Files) {
    $items = @(Get-ChildItem -LiteralPath $Root -Recurse -Force)
    foreach ($item in $items) {
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or $null -ne $item.LinkTarget) {
            Fail "Installed link or reparse point: $($item.FullName)"
        }
    }
    $actual = @($items | Where-Object { -not $_.PSIsContainer } | ForEach-Object {
        [IO.Path]::GetRelativePath($Root, $_.FullName).Replace('\','/')
    })
    $declared = @($Files | ForEach-Object { [string]$_.path })
    $caseSet = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($path in $actual + $declared) {
        if ($path -notin $actual -or $path -notin $declared) { Fail "Installed file set differs from receipt: $path" }
    }
    foreach ($path in $declared) {
        if (-not $caseSet.Add($path)) { Fail "Duplicate or case-colliding receipt path: $path" }
    }
    if ($actual.Count -ne $declared.Count) { Fail 'Installed file count differs from receipt.' }
    foreach ($file in $Files) {
        $path = Assert-File $Root ([string]$file.path)
        $item = Get-Item -LiteralPath $path -Force
        if ((Hash $path) -cne [string]$file.sha256 -or $item.Length -ne [long]$file.size) {
            Fail "Installed file drift: $($file.path)"
        }
    }
}
function Package-Hash([string] $PackageRoot) {
    $checker = Assert-File $PackageRoot 'core/runtime/Test-V4Package.ps1'
    $pwsh = if ($IsWindows) { Join-Path $PSHOME 'pwsh.exe' } else { Join-Path $PSHOME 'pwsh' }
    $output = @(& $pwsh -NoLogo -NoProfile -NonInteractive -File $checker -PackageRoot $PackageRoot 2>&1)
    if ($LASTEXITCODE -ne 0) { Fail "Package Check failed: $($output -join "`n")" }
    $result = ($output -join "`n") | ConvertFrom-Json -AsHashtable -Depth 100
    if ($result.status -cne 'pass' -or [string]$result.packageHash -notmatch '^[a-f0-9]{64}$') {
        Fail 'Package Check output is invalid.'
    }
    [string]$result.packageHash
}

$install = [IO.Path]::TrimEndingDirectorySeparator([IO.Path]::GetFullPath($InstallRoot))
$receiptFile = [IO.Path]::GetFullPath($ReceiptPath)
if (-not [IO.Directory]::Exists($install) -or -not [IO.File]::Exists($receiptFile)) { Fail 'Installation or receipt is missing.' }
if (Is-Under $receiptFile $install) { Fail 'ReceiptPath must be outside InstallRoot.' }
Assert-NoLinks $install
Assert-NoLinks $receiptFile
$receipt = Read-Json $receiptFile
$receiptInstall = [string]$receipt.installRoot
if (-not (Same-Path $receiptInstall $install)) { Fail 'Receipt installRoot differs from selected installation.' }
$package = Join-Path $install 'package'
if (-not [IO.Directory]::Exists($package)) { Fail 'Installed PackageRoot is missing.' }

if ($receipt.ContainsKey('kind') -and $receipt.kind -ceq 'local-extension-composition') {
    if ([string]::IsNullOrWhiteSpace($BaseReceiptPath)) { Fail 'A composed installation requires the external base receipt.' }
    $externalBaseReceiptPath = [IO.Path]::GetFullPath($BaseReceiptPath)
    if (-not [IO.File]::Exists($externalBaseReceiptPath) -or (Is-Under $externalBaseReceiptPath $install)) {
        Fail 'External base receipt is missing or inside the composed installation.'
    }
    Assert-NoLinks $externalBaseReceiptPath
    $externalBaseReceipt = Read-Json $externalBaseReceiptPath
    Assert-Schema $externalBaseReceiptPath 'install-receipt'
    $externalBaseInstall = [string]$externalBaseReceipt.installRoot
    $baseProofText = @(& $PSCommandPath -InstallRoot $externalBaseInstall -ReceiptPath $externalBaseReceiptPath) -join "`n"
    $baseProof = $baseProofText | ConvertFrom-Json -AsHashtable -Depth 100
    if ($baseProof.status -cne 'pass' -or $baseProof.kind -cne 'base-release') { Fail 'External base receipt verification failed.' }
    Assert-Schema $receiptFile 'composition-receipt'
    for ($index = 1; $index -lt $receipt.files.Count; $index++) {
        if ([StringComparer]::Ordinal.Compare([string]$receipt.files[$index - 1].path,[string]$receipt.files[$index].path) -ge 0) {
            Fail 'Composition receipt inventory is not in strict ordinal path order.'
        }
    }
    if ($receipt.status -ceq 'synthetic-test-only' -and -not $AllowSyntheticFixture) {
        Fail 'Synthetic fixture receipt cannot be used as an approved installation.'
    }
    if ($receipt.status -notin @('installed', 'synthetic-test-only')) { Fail 'Composition receipt status is not usable.' }
    Assert-Inventory $install $receipt.files
    if ([IO.File]::Exists((Join-Path $install 'distribution-manifest.json'))) {
        Fail 'Composed installation must not claim the base distribution manifest as its own.'
    }
    if ([IO.File]::Exists((Join-Path $install 'provenance/base-install-receipt.json'))) {
        Fail 'Platform-specific base receipt must remain outside the composed installation.'
    }
    $manifestPath = Assert-File $install 'provenance/composition-manifest.json'
    $baseManifestPath = Assert-File $install 'provenance/base-distribution-manifest.json'
    $bundlePath = Assert-File $install 'provenance/bundle-manifest.json'
    $reviewPath = Assert-File $install 'provenance/review-record.json'
    Assert-Schema $manifestPath 'composition-manifest'
    Assert-Schema $baseManifestPath 'distribution-manifest'
    Assert-Schema $bundlePath 'extension-bundle'
    Assert-Schema $reviewPath 'extension-review'
    $manifest = Read-Json $manifestPath
    $baseManifest = Read-Json $baseManifestPath
    $bundle = Read-Json $bundlePath
    $review = Read-Json $reviewPath
    $packageHash = Package-Hash $package
    if ((Hash $manifestPath) -cne [string]$receipt.compositionManifestSha256 -or
        (Hash $baseManifestPath) -cne [string]$manifest.base.manifestSha256 -or
        (Hash $externalBaseReceiptPath) -cne [string]$receipt.baseReceiptSha256 -or
        (Hash $bundlePath) -cne [string]$manifest.bundle.manifestSha256 -or
        (Hash $reviewPath) -cne [string]$manifest.review.sha256 -or
        $packageHash -cne [string]$receipt.packageHash -or
        $packageHash -cne [string]$manifest.composedPackageHash -or
        [string]$baseManifest.source.packageHash -cne [string]$manifest.base.packageHash -or
        [string]$baseManifest.source.commit -cne [string]$manifest.base.sourceCommit -or
        [string]$baseProof.baseArchiveSha256 -cne [string]$manifest.base.archiveSha256 -or
        [string]$baseProof.manifestSha256 -cne [string]$manifest.base.manifestSha256 -or
        [string]$baseProof.sourceCommit -cne [string]$manifest.base.sourceCommit -or
        [string]$baseProof.packageHash -cne [string]$manifest.base.packageHash -or
        [string]$receipt.baseArchiveSha256 -cne [string]$manifest.base.archiveSha256 -or
        [string]$receipt.bundleManifestSha256 -cne [string]$manifest.bundle.manifestSha256 -or
        [string]$receipt.reviewRecordSha256 -cne [string]$manifest.review.sha256 -or
        [string]$manifest.bundle.id -cne [string]$bundle.id -or
        [string]$manifest.bundle.version -cne [string]$bundle.version -or
        [string]$manifest.review.id -cne [string]$review.id -or
        [string]$manifest.review.scope -cne [string]$review.scope -or
        [string]$manifest.review.authorityId -cne [string]$review.acceptedBy.authorityId -or
        [string]$review.bundleManifestSha256 -cne [string]$manifest.bundle.manifestSha256 -or
        [string]$review.baseArchiveSha256 -cne [string]$manifest.base.archiveSha256 -or
        [string]$receipt.productVersion -cne [string]$manifest.productVersion) {
        Fail 'Composed provenance or receipt identity drift.'
    }
    if ($review.scope -ceq 'production') {
        if ($receipt.status -cne 'installed' -or $review.acceptedBy.authorityType -cne 'human-review' -or
            $review.acceptedBy.authorityId -cne 'xiaolong-feng') { Fail 'Production review authority is invalid.' }
    } elseif ($review.scope -ceq 'synthetic-test-only') {
        if ($receipt.status -cne 'synthetic-test-only' -or $review.acceptedBy.authorityType -cne 'test-fixture') {
            Fail 'Synthetic fixture review authority is invalid.'
        }
    } else { Fail 'Review scope is invalid.' }
    [ordered]@{ formatVersion=1; status='pass'; kind='local-extension-composition'; installRoot=$install;
        productVersion=[string]$receipt.productVersion; packageHash=$packageHash;
        receiptSha256=(Hash $receiptFile); baseArchiveSha256=[string]$receipt.baseArchiveSha256;
        bundleManifestSha256=[string]$receipt.bundleManifestSha256; scope=[string]$review.scope } | ConvertTo-Json -Depth 10
}
else {
    Assert-Schema $receiptFile 'install-receipt'
    if ($receipt.status -cne 'installed') { Fail 'Base installation receipt is not installed.' }
    Assert-Inventory $install $receipt.files
    $manifestPath = Assert-File $install 'distribution-manifest.json'
    Assert-Schema $manifestPath 'distribution-manifest'
    $manifest = Read-Json $manifestPath
    $packageHash = Package-Hash $package
    if ((Hash $manifestPath) -cne [string]$receipt.manifestSha256 -or
        $packageHash -cne [string]$manifest.source.packageHash -or
        [string]$manifest.version -cne [string]$receipt.version) {
        Fail 'Base distribution identity drift.'
    }
    $manifestFiles = @($manifest.files | ForEach-Object { [string]$_.path } | Sort-Object)
    $receiptFiles = @($receipt.files | Where-Object path -cne 'distribution-manifest.json' |
        ForEach-Object { [string]$_.path } | Sort-Object)
    if (($manifestFiles -join "`0") -cne ($receiptFiles -join "`0")) { Fail 'Base manifest/receipt file sets differ.' }
    [ordered]@{ formatVersion=1; status='pass'; kind='base-release'; installRoot=$install;
        productVersion=[string]$receipt.version; packageHash=$packageHash;
        receiptSha256=(Hash $receiptFile); baseArchiveSha256=[string]$receipt.archiveSha256;
        sourceCommit=[string]$manifest.source.commit; manifestSha256=(Hash $manifestPath) } | ConvertTo-Json -Depth 10
}
