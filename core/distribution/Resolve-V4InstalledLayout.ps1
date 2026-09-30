Set-StrictMode -Version Latest

function Resolve-V4InstalledLayout {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $PackageRoot,
        [switch] $RequireCompanion
    )

    function Hash([string] $Path) { (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant() }
    function Assert-Entry($Manifest, [string] $DistributionRoot, [string] $Relative) {
        $entry = @($Manifest.files | Where-Object { $_.path -ceq $Relative })
        if ($entry.Count -ne 1) { throw "Distribution manifest does not bind $Relative." }
        $full = Join-Path $DistributionRoot $Relative
        if (-not [IO.File]::Exists($full)) { throw "Installed distribution file is missing: $Relative" }
        $item = Get-Item -LiteralPath $full -Force
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or $null -ne $item.LinkTarget -or
            $item.Length -ne [long]$entry[0].size -or (Hash $full) -cne [string]$entry[0].sha256) {
            throw "Installed distribution file drift: $Relative"
        }
        $full
    }

    $package = [IO.Path]::TrimEndingDirectorySeparator([IO.Path]::GetFullPath($PackageRoot))
    if (-not [IO.Directory]::Exists($package)) { throw 'Derived PackageRoot is missing.' }
    $distribution = [IO.Directory]::GetParent($package).FullName
    $manifestPath = Join-Path $distribution 'distribution-manifest.json'
    $schemaPath = Join-Path $package 'core/contracts/distribution-manifest.schema.json'
    if (-not [IO.File]::Exists($manifestPath) -or
        -not (Test-Json -LiteralPath $manifestPath -SchemaFile $schemaPath -ErrorAction SilentlyContinue)) {
        throw 'Installed distribution manifest is missing or invalid.'
    }
    $manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
    if ([string]$manifest.rootDirectory -cne [IO.Path]::GetFileName($distribution)) {
        throw 'Installed distribution root identity does not match its manifest.'
    }
    $pwshPath = if ($IsWindows) { Join-Path $PSHOME 'pwsh.exe' } else { Join-Path $PSHOME 'pwsh' }
    $checkOutput = @(& $pwshPath -NoLogo -NoProfile -NonInteractive -File (Join-Path $package 'core/runtime/Test-V4Package.ps1') -PackageRoot $package 2>&1)
    if ($LASTEXITCODE -ne 0) { throw "Installed PackageRoot validation failed: $($checkOutput -join "`n")" }
    $packageResult = ($checkOutput -join "`n") | ConvertFrom-Json
    if ([string]$packageResult.packageHash -cne [string]$manifest.source.packageHash) {
        throw 'Installed PackageRoot hash does not match the distribution manifest.'
    }

    $runtimePath = Join-Path $package 'core/distribution/runtime-manifest.json'
    $selfContained = [IO.File]::Exists($runtimePath)
    if ($selfContained) {
        $runtimeSchema = Join-Path $package 'core/distribution/contracts/distribution-runtime.schema.json'
        if (-not (Test-Json -LiteralPath $runtimePath -SchemaFile $runtimeSchema -ErrorAction SilentlyContinue)) {
            throw 'Installed runtime manifest is invalid.'
        }
        $runtime = Get-Content -Raw -LiteralPath $runtimePath | ConvertFrom-Json
        if ($runtime.rid -cne [Runtime.InteropServices.RuntimeInformation]::RuntimeIdentifier) {
            throw "Installed runtime $($runtime.rid) does not match this host."
        }
        $suffix = if ($runtime.rid.StartsWith('win-')) { '.exe' } else { '' }
        $hostRelative = "host/v4-guards$suffix"
        $companionRelative = "companion/v4-web-companion$suffix"
    } else {
        $runtime = $null
        $hostRelative = 'host/v4-guards.dll'
        $companionRelative = 'companion/v4-web-companion.dll'
    }
    $hostPath = Assert-Entry $manifest $distribution $hostRelative
    $companionPath = if ($RequireCompanion) { Assert-Entry $manifest $distribution $companionRelative } else { $null }
    [pscustomobject]@{
        PackageRoot=$package; DistributionRoot=$distribution; SelfContained=$selfContained; Runtime=$runtime
        HostPath=$hostPath; CompanionPath=$companionPath; Manifest=$manifest
    }
}
