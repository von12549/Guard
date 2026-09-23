[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $BaseInstallRoot,
    [Parameter(Mandatory)][string] $BaseReceiptPath,
    [Parameter(Mandatory)][string] $BaseArchivePath,
    [Parameter(Mandatory)][string] $BundleRoot,
    [Parameter(Mandatory)][string] $ReviewRecordPath,
    [Parameter(Mandatory)][string] $OutputInstallRoot,
    [Parameter(Mandatory)][string] $CompositionReceiptPath,
    [Parameter(Mandatory)][string] $TargetRoot,
    [Parameter(Mandatory)][string] $StateRoot,
    [Parameter(Mandatory)][string] $EvidenceRoot,
    [switch] $AllowSyntheticFixture
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Fail([string] $Message) { throw $Message }
function Hash([string] $Path) { (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant() }
function Read-Json([string] $Path) { Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json -AsHashtable -Depth 100 }
function Write-Json([string] $Path, $Value) {
    $json = (($Value | ConvertTo-Json -Depth 100).Replace("`r`n", "`n") + "`n")
    [IO.File]::WriteAllText($Path, $json, [Text.UTF8Encoding]::new($false))
}
function Is-Under([string] $Path, [string] $Root) {
    $relative = [IO.Path]::GetRelativePath($Root, $Path)
    $relative -eq '.' -or (-not [IO.Path]::IsPathRooted($relative) -and $relative -ne '..' -and -not $relative.StartsWith("..$([IO.Path]::DirectorySeparatorChar)"))
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
function Safe-File([string] $Root, [string] $Relative) {
    $pathText = $Relative.Replace('\','/')
    if ([string]::IsNullOrWhiteSpace($Relative) -or [IO.Path]::IsPathRooted($Relative) -or
        $pathText -match '^[A-Za-z]:' -or
        @($pathText.Split('/') | Where-Object { $_ -in @('', '.', '..') }).Count -gt 0) {
        Fail "Unsafe relative file path: $Relative"
    }
    $full = [IO.Path]::GetFullPath((Join-Path $Root $Relative))
    if (-not (Is-Under $full $Root) -or -not [IO.File]::Exists($full)) { Fail "Missing or escaping file: $Relative" }
    Assert-NoLinks $full
    $full
}
function Assert-Disjoint([string] $A, [string] $B, [string] $Label) {
    if ((Is-Under $A $B) -or (Is-Under $B $A)) { Fail "Overlapping roots: $Label" }
}
function Same-Capabilities($A, $B) {
    foreach ($field in @('readRoots','writeRoots','processes')) {
        $left = @($A[$field] | Sort-Object)
        $right = @($B[$field] | Sort-Object)
        if (($left -join "`0") -cne ($right -join "`0")) { return $false }
    }
    $A.network -eq $B.network -and [int]$A.maxTimeoutSeconds -eq [int]$B.maxTimeoutSeconds
}
function Subset-Capabilities($Actual, $Ceiling) {
    foreach ($field in @('readRoots','writeRoots','processes')) {
        foreach ($value in @($Actual[$field])) {
            if (@($Ceiling[$field]) -cnotcontains [string]$value) { return $false }
        }
    }
    if ($Actual.network -and -not $Ceiling.network) { return $false }
    [int]$Actual.timeoutSeconds -le [int]$Ceiling.maxTimeoutSeconds
}

$base = [IO.Path]::TrimEndingDirectorySeparator([IO.Path]::GetFullPath($BaseInstallRoot))
$baseReceiptFile = [IO.Path]::GetFullPath($BaseReceiptPath)
$baseArchiveFile = [IO.Path]::GetFullPath($BaseArchivePath)
$bundleRootPath = [IO.Path]::TrimEndingDirectorySeparator([IO.Path]::GetFullPath($BundleRoot))
$reviewFile = [IO.Path]::GetFullPath($ReviewRecordPath)
$output = [IO.Path]::TrimEndingDirectorySeparator([IO.Path]::GetFullPath($OutputInstallRoot))
$receiptFile = [IO.Path]::GetFullPath($CompositionReceiptPath)
$target = [IO.Path]::TrimEndingDirectorySeparator([IO.Path]::GetFullPath($TargetRoot))
$state = [IO.Path]::TrimEndingDirectorySeparator([IO.Path]::GetFullPath($StateRoot))
$evidence = [IO.Path]::TrimEndingDirectorySeparator([IO.Path]::GetFullPath($EvidenceRoot))
$outputParent = [IO.Path]::GetDirectoryName($output)
$receiptParent = [IO.Path]::GetDirectoryName($receiptFile)
foreach ($path in @($base,$baseReceiptFile,$baseArchiveFile,$bundleRootPath,$reviewFile,$target,$state,$evidence,$outputParent,$receiptParent)) {
    if (-not ([IO.File]::Exists($path) -or [IO.Directory]::Exists($path))) { Fail "Input or parent path is missing: $path" }
    Assert-NoLinks $path
}
foreach ($root in @($base,$bundleRootPath,$target,$state,$evidence)) {
    if (-not [IO.Directory]::Exists($root)) { Fail "Required root is not a directory: $root" }
}
if ([IO.File]::Exists($output) -or [IO.Directory]::Exists($output) -or [IO.File]::Exists($receiptFile) -or [IO.Directory]::Exists($receiptFile)) {
    Fail 'Output installation and composition receipt must be absent.'
}
if ($output -eq [IO.Path]::GetPathRoot($output) -or $receiptFile -eq [IO.Path]::GetPathRoot($receiptFile)) { Fail 'Output path cannot be a filesystem root.' }
foreach ($pair in @(@($base,$bundleRootPath),@($base,$target),@($base,$state),@($base,$evidence),
        @($bundleRootPath,$target),@($bundleRootPath,$state),@($bundleRootPath,$evidence),
        @($target,$state),@($target,$evidence),@($state,$evidence))) {
    Assert-Disjoint $pair[0] $pair[1] "$($pair[0]) / $($pair[1])"
}
foreach ($root in @($base,$bundleRootPath,$target,$state,$evidence)) {
    Assert-Disjoint $output $root "OutputInstallRoot / $root"
}
if (Is-Under $receiptFile $output) { Fail 'Composition receipt must be outside output installation.' }
foreach ($root in @($base,$bundleRootPath,$target,$state)) {
    if (Is-Under $receiptFile $root) { Fail "Composition receipt must not write into an input, TargetRoot or StateRoot: $root" }
}
if (Is-Under $reviewFile $output) { Fail 'Review record must be outside output installation.' }
if (Is-Under $baseReceiptFile $output) { Fail 'Base receipt must be outside output installation.' }
if (Is-Under $baseArchiveFile $output) { Fail 'Base archive must be outside output installation.' }

$verifier = Join-Path $PSScriptRoot 'Test-V4ComposedInstallation.ps1'
$baseOutput = @(& $verifier -InstallRoot $base -ReceiptPath $baseReceiptFile)
$baseProof = ($baseOutput -join "`n") | ConvertFrom-Json -AsHashtable -Depth 100
if ($baseProof.status -cne 'pass' -or $baseProof.kind -cne 'base-release') { Fail 'Base installation is not a verified public-release installation.' }
if (-not [IO.File]::Exists($baseArchiveFile) -or (Hash $baseArchiveFile) -cne [string]$baseProof.baseArchiveSha256) {
    Fail 'Selected public-release archive differs from the installed receipt.'
}
$baseReceipt = Read-Json $baseReceiptFile
$baseManifest = Read-Json (Join-Path $base 'distribution-manifest.json')
$bundlePath = Safe-File $bundleRootPath 'bundle-manifest.json'
Assert-Schema $bundlePath 'extension-bundle'
Assert-Schema $reviewFile 'extension-review'
$bundle = Read-Json $bundlePath
$review = Read-Json $reviewFile
$bundleHash = Hash $bundlePath
$reviewHash = Hash $reviewFile
if ($bundle.baseVersion -cne $baseProof.productVersion -or $review.bundleManifestSha256 -cne $bundleHash -or
    $review.baseArchiveSha256 -cne $baseProof.baseArchiveSha256) { Fail 'Bundle/review/base identity mismatch.' }
if ($review.scope -ceq 'production') {
    if ($review.acceptedBy.authorityType -cne 'human-review' -or $review.acceptedBy.authorityId -cne 'xiaolong-feng') {
        Fail 'Production bundle lacks the designated human-review authority.'
    }
} elseif ($review.scope -ceq 'synthetic-test-only') {
    if (-not $AllowSyntheticFixture -or $review.acceptedBy.authorityType -cne 'test-fixture') {
        Fail 'Synthetic fixture review is not an approved production bundle.'
    }
} else { Fail 'Unknown review scope.' }

$listed = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($file in $bundle.files) {
    $relative = [string]$file.path
    if (-not $listed.Add($relative)) { Fail "Duplicate or case-colliding bundle file: $relative" }
    $parts = $relative.Replace('\','/').Split('/')
    if (($parts.Count -lt 4 -or $parts[0] -cne 'profiles' -or $parts[1] -cne 'catalog') -and
        ($parts.Count -lt 3 -or $parts[0] -cne 'modules')) { Fail "Bundle file is outside Profile/module catalogs: $relative" }
    $source = Safe-File (Join-Path $bundleRootPath 'package') $relative
    if ((Hash $source) -cne [string]$file.sha256 -or (Get-Item -LiteralPath $source).Length -ne [long]$file.size) {
        Fail "Bundle file hash/size drift: $relative"
    }
    if ([IO.File]::Exists((Join-Path $base 'package' $relative))) { Fail "Bundle attempts to replace base file: $relative" }
}
for ($index = 1; $index -lt $bundle.files.Count; $index++) {
    if ([StringComparer]::Ordinal.Compare([string]$bundle.files[$index - 1].path,[string]$bundle.files[$index].path) -ge 0) {
        Fail 'Bundle file inventory must be in strict ordinal path order.'
    }
}
$bundleItems = @(Get-ChildItem -LiteralPath $bundleRootPath -Recurse -Force)
foreach ($item in $bundleItems) {
    if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or $null -ne $item.LinkTarget) { Fail "Bundle link: $($item.FullName)" }
}
$actualBundleFiles = @($bundleItems | Where-Object { -not $_.PSIsContainer } | ForEach-Object {
    [IO.Path]::GetRelativePath($bundleRootPath,$_.FullName).Replace('\','/')
})
$expectedBundleFiles = @('bundle-manifest.json') + @($bundle.files | ForEach-Object { "package/$($_.path)" })
if ($actualBundleFiles.Count -ne $expectedBundleFiles.Count) { Fail 'Bundle file count differs from manifest.' }
foreach ($path in $actualBundleFiles) { if ($expectedBundleFiles -cnotcontains $path) { Fail "Undeclared bundle file: $path" } }

$baseProfiles = @(Get-ChildItem -LiteralPath (Join-Path $base 'package/profiles/catalog') -Directory | ForEach-Object Name)
$baseRegistry = Read-Json (Join-Path $base 'package/modules/registry.json')
$baseModuleIds = @($baseRegistry.modules | ForEach-Object { [string]$_.id })
$profileIds = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($profile in $bundle.profiles) {
    $id = [string]$profile.id
    if (-not $profileIds.Add($id) -or $baseProfiles -contains $id) { Fail "Duplicate or base Profile ID: $id" }
    if ([string]$profile.path -cne "profiles/catalog/$id/profile.json" -or $listed.Contains([string]$profile.path) -eq $false) {
        Fail "Profile manifest path is not canonical or inventoried: $id"
    }
    $path = Safe-File (Join-Path $bundleRootPath 'package') ([string]$profile.path)
    Assert-Schema $path 'profile'
    $document = Read-Json $path
    if ($document.id -cne $id -or $document.version -cne [string]$profile.version -or
        (Hash $path) -cne [string]$profile.sha256) { Fail "Profile identity drift: $id" }
}
$moduleIds = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$reviewIds = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($ceiling in $review.moduleCeilings) {
    if (-not $reviewIds.Add([string]$ceiling.moduleId)) { Fail "Duplicate review module ceiling: $($ceiling.moduleId)" }
}
foreach ($module in $bundle.modules) {
    $id = [string]$module.id
    if (-not $moduleIds.Add($id) -or $baseModuleIds -contains $id) { Fail "Duplicate or base module ID: $id" }
    if ([string]$module.manifestPath -cne "modules/$id/module.json" -or
        -not $listed.Contains([string]$module.manifestPath)) { Fail "Module manifest path is not canonical or inventoried: $id" }
    $path = Safe-File (Join-Path $bundleRootPath 'package') ([string]$module.manifestPath)
    Assert-Schema $path 'module'
    $document = Read-Json $path
    if ($document.id -cne $id -or $document.version -cne [string]$module.version -or
        (Hash $path) -cne [string]$module.manifestSha256) { Fail "Module identity drift: $id" }
    $ceiling = @($review.moduleCeilings | Where-Object moduleId -CEQ $id)
    if ($ceiling.Count -ne 1 -or -not (Same-Capabilities $module.allowedCapabilities $ceiling[0].allowedCapabilities) -or
        -not (Subset-Capabilities $document.capabilities $ceiling[0].allowedCapabilities)) {
        Fail "Module capabilities exceed or differ from reviewed ceiling: $id"
    }
}
if ($moduleIds.Count -ne $reviewIds.Count) { Fail 'Review module ceiling set differs from bundle module set.' }
foreach ($file in $bundle.files) {
    $parts = ([string]$file.path).Replace('\','/').Split('/')
    if ($parts[0] -ceq 'profiles' -and -not $profileIds.Contains($parts[2])) { Fail "Undeclared Profile file: $($file.path)" }
    if ($parts[0] -ceq 'modules' -and -not $moduleIds.Contains($parts[1])) { Fail "Undeclared module file: $($file.path)" }
}

$temporary = Join-Path $outputParent ('.v4-compose-' + [Guid]::NewGuid().ToString('N'))
$receiptTemporary = Join-Path $receiptParent ('.v4-compose-receipt-' + [Guid]::NewGuid().ToString('N') + '.json')
$ownerId = [Guid]::NewGuid().ToString('N')
$promoted = $false
try {
    if (-not (Is-Under $temporary $outputParent) -or [IO.Directory]::Exists($temporary)) { Fail 'Unsafe or existing staging path.' }
    [void][IO.Directory]::CreateDirectory($temporary)
    [IO.File]::WriteAllText((Join-Path $temporary '.composition-owner'), $ownerId, [Text.UTF8Encoding]::new($false))
    foreach ($item in Get-ChildItem -LiteralPath $base -Force) {
        Copy-Item -LiteralPath $item.FullName -Destination $temporary -Recurse -Force
    }
    [void][IO.Directory]::CreateDirectory((Join-Path $temporary 'provenance'))
    Move-Item -LiteralPath (Join-Path $temporary 'distribution-manifest.json') -Destination (Join-Path $temporary 'provenance/base-distribution-manifest.json')
    Copy-Item -LiteralPath $bundlePath -Destination (Join-Path $temporary 'provenance/bundle-manifest.json')
    Copy-Item -LiteralPath $reviewFile -Destination (Join-Path $temporary 'provenance/review-record.json')
    foreach ($file in $bundle.files) {
        $relative = [string]$file.path
        $destination = Join-Path $temporary "package/$relative"
        [void][IO.Directory]::CreateDirectory((Split-Path -Parent $destination))
        Copy-Item -LiteralPath (Join-Path $bundleRootPath "package/$relative") -Destination $destination
    }
    foreach ($module in $bundle.modules) {
        $baseRegistry.modules += [ordered]@{ id=[string]$module.id; manifestPath=[string]$module.manifestPath;
            manifestSha256=[string]$module.manifestSha256; allowedCapabilities=$module.allowedCapabilities }
    }
    $registryEntries = [Collections.Generic.List[object]]::new()
    foreach ($entry in $baseRegistry.modules) { [void]$registryEntries.Add($entry) }
    $registryEntries.Sort([Comparison[object]]{
        param($left,$right)
        [StringComparer]::Ordinal.Compare([string]$left.id,[string]$right.id)
    })
    $baseRegistry.modules = $registryEntries.ToArray()
    Write-Json (Join-Path $temporary 'package/modules/registry.json') $baseRegistry
    $checker = Join-Path $temporary 'package/core/runtime/Test-V4Package.ps1'
    $pwsh = if ($IsWindows) { Join-Path $PSHOME 'pwsh.exe' } else { Join-Path $PSHOME 'pwsh' }
    $packageOutput = @(& $pwsh -NoLogo -NoProfile -NonInteractive -File $checker -PackageRoot (Join-Path $temporary 'package') 2>&1)
    if ($LASTEXITCODE -ne 0) { Fail "Composed Package Check failed: $($packageOutput -join "`n")" }
    $packageResult = ($packageOutput -join "`n") | ConvertFrom-Json -AsHashtable -Depth 100
    $packageHash = [string]$packageResult.packageHash
    foreach ($profile in $bundle.profiles) {
        $report = Join-Path $evidence ('.v4-compose-doctor-' + [Guid]::NewGuid().ToString('N') + '.json')
        try {
            $doctor = @(& $pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $temporary 'package/core/distribution/Test-V4Prerequisites.ps1') -PackageRoot (Join-Path $temporary 'package') -Profile ([string]$profile.id) -ReportPath $report 2>&1)
            if ($LASTEXITCODE -ne 0) { Fail "Composed Profile prerequisites failed: $($doctor -join "`n")" }
        } finally {
            if ([IO.File]::Exists($report)) { Remove-Item -LiteralPath $report -Force }
        }
    }
    $composition = [ordered]@{
        formatVersion=1; kind='local-extension-composition'; productVersion=[string]$baseProof.productVersion
        base=[ordered]@{ sourceCommit=[string]$baseProof.sourceCommit; archiveSha256=[string]$baseProof.baseArchiveSha256;
            manifestSha256=[string]$baseProof.manifestSha256;
            packageHash=[string]$baseProof.packageHash }
        bundle=[ordered]@{ id=[string]$bundle.id; version=[string]$bundle.version; manifestSha256=$bundleHash }
        review=[ordered]@{ id=[string]$review.id; scope=[string]$review.scope;
            authorityId=[string]$review.acceptedBy.authorityId; sha256=$reviewHash }
        composedPackageHash=$packageHash
    }
    $compositionPath = Join-Path $temporary 'provenance/composition-manifest.json'
    Write-Json $compositionPath $composition
    Assert-Schema $compositionPath 'composition-manifest'
    $fileEntries = [Collections.Generic.List[object]]::new()
    foreach ($file in Get-ChildItem -LiteralPath $temporary -Recurse -File -Force) {
        if ($file.FullName -ceq (Join-Path $temporary '.composition-owner')) { continue }
        [void]$fileEntries.Add([ordered]@{
            path=[IO.Path]::GetRelativePath($temporary,$file.FullName).Replace('\','/')
            sha256=Hash $file.FullName
            size=$file.Length
        })
    }
    $fileEntries.Sort([Comparison[object]]{
        param($left,$right)
        [StringComparer]::Ordinal.Compare([string]$left.path,[string]$right.path)
    })
    $files = $fileEntries.ToArray()
    $identityText = "$($baseProof.baseArchiveSha256)`n$bundleHash`n$reviewHash`n$packageHash`n"
    $identityHash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($identityText))).ToLowerInvariant()
    $receipt = [ordered]@{
        formatVersion=1; kind='local-extension-composition'; id=$identityHash.Substring(0,32)
        status=if($review.scope -ceq 'production'){'installed'}else{'synthetic-test-only'}
        installRoot=$output; productVersion=[string]$baseProof.productVersion
        compositionManifestSha256=Hash $compositionPath; packageHash=$packageHash
        baseArchiveSha256=[string]$baseProof.baseArchiveSha256; baseReceiptSha256=[string]$baseProof.receiptSha256;
        bundleManifestSha256=$bundleHash
        reviewRecordSha256=$reviewHash; files=$files
    }
    Write-Json $receiptTemporary $receipt
    Assert-Schema $receiptTemporary 'composition-receipt'
    Remove-Item -LiteralPath (Join-Path $temporary '.composition-owner') -Force
    Move-Item -LiteralPath $temporary -Destination $output
    $promoted = $true
    Move-Item -LiteralPath $receiptTemporary -Destination $receiptFile
    $proofOutput = @(& $verifier -InstallRoot $output -ReceiptPath $receiptFile -BaseReceiptPath $baseReceiptFile -AllowSyntheticFixture:$AllowSyntheticFixture)
    $proof = ($proofOutput -join "`n") | ConvertFrom-Json -AsHashtable -Depth 100
    if ($proof.status -cne 'pass' -or $proof.kind -cne 'local-extension-composition') {
        Fail 'Promoted composition failed receipt verification.'
    }
    [ordered]@{ formatVersion=1; status='pass'; kind='local-extension-composition'; installRoot=$output;
        receiptPath=$receiptFile; receiptSha256=Hash $receiptFile; packageHash=$packageHash;
        baseArchiveSha256=[string]$baseProof.baseArchiveSha256; bundleManifestSha256=$bundleHash;
        reviewRecordSha256=$reviewHash; scope=[string]$review.scope } | ConvertTo-Json -Depth 10
}
catch { throw }
finally {
    $marker = Join-Path $temporary '.composition-owner'
    if ([IO.Directory]::Exists($temporary) -and [IO.File]::Exists($marker) -and
        (Is-Under $temporary $outputParent) -and
        [IO.File]::ReadAllText($marker) -ceq $ownerId) {
        Remove-Item -LiteralPath $temporary -Recurse -Force
    }
    if ([IO.File]::Exists($receiptTemporary) -and (Is-Under $receiptTemporary $receiptParent)) {
        Remove-Item -LiteralPath $receiptTemporary -Force
    }
}
