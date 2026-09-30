[CmdletBinding()]
param(
    [string] $PackageRoot = (Join-Path $PSScriptRoot '../..'),
    [Parameter(Mandatory)][ValidateSet('win-x64','win-arm64','linux-x64','linux-arm64')][string] $RuntimeIdentifier,
    [Parameter(Mandatory)][string] $OutputDirectory,
    [Parameter(Mandatory)][string] $MeasurementPath,
    [Parameter(Mandatory)][ValidatePattern('^[a-fA-F0-9]{40}$')][string] $SourceCommit
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Json([string] $Path, $Value) {
    [void][IO.Directory]::CreateDirectory((Split-Path -Parent $Path))
    $json = ($Value | ConvertTo-Json -Depth 30).Replace("`r`n", "`n") + "`n"
    [IO.File]::WriteAllText($Path, $json, [Text.UTF8Encoding]::new($false))
}
function Invoke-DotNet([string[]] $Arguments) {
    $output = @(& dotnet @Arguments 2>&1)
    if ($LASTEXITCODE -ne 0) { throw "dotnet failed with exit code ${LASTEXITCODE}:`n$($output -join "`n")" }
}
function Get-TreeSize([string] $Root) {
    [long](@(Get-ChildItem -LiteralPath $Root -File -Recurse -Force | Measure-Object -Property Length -Sum).Sum)
}
function Is-Under([string] $Path, [string] $Root) {
    $relative = [IO.Path]::GetRelativePath($Root, $Path)
    $relative -eq '.' -or (-not [IO.Path]::IsPathRooted($relative) -and $relative -ne '..' -and
        -not $relative.StartsWith("..$([IO.Path]::DirectorySeparatorChar)", [StringComparison]::Ordinal))
}
function Copy-CleanPackage([string] $Source, [string] $Destination) {
    $check = @(& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $Source 'core/runtime/Test-V4Package.ps1') -PackageRoot $Source 2>&1)
    if ($LASTEXITCODE -ne 0) { throw "Package validation failed before publish: $($check -join "`n")" }
    $result = ($check -join "`n") | ConvertFrom-Json
    foreach ($entry in @($result.authorityFiles | Sort-Object path)) {
        $relative = [string]$entry.path
        if ($relative -match '(^|/)(?:bin|obj)(?:/|$)') { continue }
        $sourcePath = Join-Path $Source $relative
        $destinationPath = Join-Path $Destination $relative
        [void][IO.Directory]::CreateDirectory((Split-Path -Parent $destinationPath))
        [IO.File]::Copy($sourcePath, $destinationPath, $false)
    }
}

$package = [IO.Path]::TrimEndingDirectorySeparator([IO.Path]::GetFullPath($PackageRoot))
$output = [IO.Path]::TrimEndingDirectorySeparator([IO.Path]::GetFullPath($OutputDirectory))
$measurement = [IO.Path]::GetFullPath($MeasurementPath)
if (-not [IO.Directory]::Exists($package)) { throw 'PackageRoot does not exist.' }
if ([IO.Directory]::Exists($output) -or [IO.File]::Exists($output)) { throw 'OutputDirectory must not already exist.' }
if ([IO.File]::Exists($measurement)) { throw 'MeasurementPath must not already exist.' }
if (Is-Under $output $package) { throw 'OutputDirectory must be outside immutable PackageRoot.' }
if (Is-Under $measurement $package) { throw 'MeasurementPath must be outside immutable PackageRoot.' }

[void][IO.Directory]::CreateDirectory($output)
$work = Join-Path $output '.publish-work'
$artifacts = Join-Path $work 'artifacts'
$hostRoot = Join-Path $work 'host'
$companionRoot = Join-Path $work 'companion'
$cleanPackage = Join-Path $work 'package'
$archiveOutput = Join-Path $output 'distribution'
[void][IO.Directory]::CreateDirectory($work)
Copy-CleanPackage $package $cleanPackage
$runtimeManifest = [ordered]@{
    formatVersion=1; rid=$RuntimeIdentifier; deploymentModel='self-contained'
    features=[ordered]@{ singleFile=$false; trimmed=$false; readyToRun=$false }
}
Write-Json (Join-Path $cleanPackage 'core/distribution/runtime-manifest.json') $runtimeManifest
if (-not (Test-Json -LiteralPath (Join-Path $cleanPackage 'core/distribution/runtime-manifest.json') `
    -SchemaFile (Join-Path $cleanPackage 'core/distribution/contracts/distribution-runtime.schema.json') -ErrorAction SilentlyContinue)) {
    throw 'Generated runtime manifest violates its schema.'
}

$buildProps = Join-Path $package 'build/V4.Build.props'
$nugetConfig = Join-Path $package 'build/NuGet.config'
$common = @(
    '--configfile', $nugetConfig, '--artifacts-path', $artifacts, '-r', $RuntimeIdentifier, '-nologo',
    '-p:ImportDirectoryBuildProps=false', '-p:ImportDirectoryBuildTargets=false',
    '-p:ImportDirectoryPackagesProps=false', '-p:ImportDirectorySolutionProps=false',
    '-p:ImportDirectorySolutionTargets=false', "-p:CustomBeforeMicrosoftCommonProps=$buildProps"
)
$publishProperties = @(
    '--no-restore', '--configuration', 'Release', '--artifacts-path', $artifacts, '-r', $RuntimeIdentifier,
    '--self-contained', 'true', '-p:PublishSingleFile=false', '-p:PublishTrimmed=false',
    '-p:PublishReadyToRun=false', '-p:UseAppHost=true', '-nologo',
    '-p:ImportDirectoryBuildProps=false', '-p:ImportDirectoryBuildTargets=false',
    '-p:ImportDirectoryPackagesProps=false', '-p:ImportDirectorySolutionProps=false',
    '-p:ImportDirectorySolutionTargets=false', "-p:CustomBeforeMicrosoftCommonProps=$buildProps"
)
$hostProject = Join-Path $package 'core/host/V4.Guards.Host/V4.Guards.Host.csproj'
$companionProject = Join-Path $package 'integrations/web/V4.Guards.WebCompanion/V4.Guards.WebCompanion.csproj'
$publishWatch = [Diagnostics.Stopwatch]::StartNew()
Invoke-DotNet (@('restore', $hostProject) + $common)
Invoke-DotNet (@('publish', $hostProject) + $publishProperties + @('-o', $hostRoot))
Invoke-DotNet (@('restore', $companionProject) + $common)
Invoke-DotNet (@('publish', $companionProject) + $publishProperties + @('-o', $companionRoot))
$publishWatch.Stop()

$archiveWatch = [Diagnostics.Stopwatch]::StartNew()
$distributionText = @(& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $package 'core/distribution/New-V4Distribution.ps1') `
    -PackageRoot $cleanPackage -HostRoot $hostRoot -CompanionRoot $companionRoot -OutputDirectory $archiveOutput `
    -SourceCommit $SourceCommit -RuntimeIdentifier $RuntimeIdentifier -DeploymentModel self-contained 2>&1)
if ($LASTEXITCODE -ne 0) { throw "Distribution build failed: $($distributionText -join "`n")" }
$archiveWatch.Stop()
$distribution = ($distributionText -join "`n") | ConvertFrom-Json

$hostApp = Join-Path $hostRoot $(if ($RuntimeIdentifier.StartsWith('win-')) { 'v4-guards.exe' } else { 'v4-guards' })
$companionApp = Join-Path $companionRoot $(if ($RuntimeIdentifier.StartsWith('win-')) { 'v4-web-companion.exe' } else { 'v4-web-companion' })
$nativeRid = [Runtime.InteropServices.RuntimeInformation]::RuntimeIdentifier
$hostProbe = 'fail'
$hostDuration = 0L
if ($RuntimeIdentifier -eq $nativeRid) {
    $startWatch = [Diagnostics.Stopwatch]::StartNew()
    $versionOutput = @(& $hostApp version 2>&1)
    $hostCode = $LASTEXITCODE
    $startWatch.Stop()
    $hostDuration = $startWatch.ElapsedMilliseconds
    $versionDocument = try { ($versionOutput -join "`n") | ConvertFrom-Json } catch { $null }
    if ($hostCode -ne 0 -or $null -eq $versionDocument -or $versionDocument.status -cne 'pass' -or
        $versionDocument.id -cne 'v4-guards' -or [string]$versionDocument.version -notmatch '^\d+\.\d+\.\d+$') {
        throw "Self-contained Host cold-start probe failed: $($versionOutput -join "`n")"
    }
    $hostProbe = 'pass'
}

Add-Type -AssemblyName System.IO.Compression
$zip = [IO.Compression.ZipFile]::OpenRead([string]$distribution.archivePath)
try { $archiveCount = @($zip.Entries | Where-Object { -not [string]::IsNullOrEmpty($_.Name) }).Count }
finally { $zip.Dispose() }
$plugin = Get-Content -Raw -LiteralPath (Join-Path $package 'plugin.json') | ConvertFrom-Json
$report = [ordered]@{
    formatVersion = 1
    version = [string]$plugin.version
    runtime = [ordered]@{ rid=$RuntimeIdentifier; deploymentModel='self-contained' }
    sourceCommit = $SourceCommit.ToLowerInvariant()
    offlineRestore = $true
    features = [ordered]@{ singleFile=$false; trimmed=$false; readyToRun=$false }
    sizes = [ordered]@{
        hostPublishedBytes=Get-TreeSize $hostRoot
        companionPublishedBytes=Get-TreeSize $companionRoot
        archiveBytes=(Get-Item -LiteralPath ([string]$distribution.archivePath)).Length
    }
    fileCounts = [ordered]@{
        host=@(Get-ChildItem -LiteralPath $hostRoot -File -Recurse -Force).Count
        companion=@(Get-ChildItem -LiteralPath $companionRoot -File -Recurse -Force).Count
        archive=$archiveCount
    }
    durationsMs = [ordered]@{
        restoreAndPublish=$publishWatch.ElapsedMilliseconds
        archive=$archiveWatch.ElapsedMilliseconds
        hostColdStart=$hostDuration
    }
    probes = [ordered]@{
        hostVersion=$hostProbe
        companionAppHost=$(if ([IO.File]::Exists($companionApp)) { 'pass' } else { 'fail' })
    }
}
Write-Json $measurement $report
if (-not (Test-Json -LiteralPath $measurement -SchemaFile (Join-Path $package 'core/distribution/contracts/distribution-measurement.schema.json') -ErrorAction SilentlyContinue)) {
    throw 'Distribution measurement violates its schema.'
}

[ordered]@{
    formatVersion=1; status='pass'; rid=$RuntimeIdentifier; archivePath=[string]$distribution.archivePath
    archiveSha256=[string]$distribution.archiveSha256; measurementPath=$measurement
    hostRoot=$hostRoot; companionRoot=$companionRoot
} | ConvertTo-Json -Depth 10
