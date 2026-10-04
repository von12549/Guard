[CmdletBinding()]
param(
    [string] $PackageRoot = '',
    [string] $Profile = '',
    [Parameter(Mandatory)][string] $PrerequisiteReportPath,
    [Parameter(Mandatory)][string] $HostArgumentsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-RedirectableErrorJson([string] $Json) {
    $writer = '[Console]::Error.Write([Console]::In.ReadToEnd())'
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($writer))
    $pwshPath = if ($IsWindows) { Join-Path $PSHOME 'pwsh.exe' } else { Join-Path $PSHOME 'pwsh' }
    $Json | & $pwshPath -NoLogo -NoProfile -NonInteractive -EncodedCommand $encoded
}

function Write-InstalledError([int] $Code, [string] $Category, [string] $Message) {
    $document = [ordered]@{ formatVersion=1; status='error'; operation='installed-launcher'; exitCategory=$Category; message=$Message }
    Write-RedirectableErrorJson ($document | ConvertTo-Json -Compress)
    exit $Code
}

$derivedPackage = [IO.Path]::TrimEndingDirectorySeparator([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..')))
if (-not [string]::IsNullOrWhiteSpace($PackageRoot) -and
    [IO.Path]::TrimEndingDirectorySeparator([IO.Path]::GetFullPath($PackageRoot)) -cne $derivedPackage) {
    Write-InstalledError 11 'unsafe-path' 'PackageRoot override does not match the installed launcher location.'
}
$package = $derivedPackage
try {
    . (Join-Path $PSScriptRoot 'Resolve-V4InstalledLayout.ps1')
    $layout = Resolve-V4InstalledLayout -PackageRoot $package
} catch { Write-InstalledError 12 'integrity-failure' $_.Exception.Message }

try {
    $arguments = @($HostArgumentsJson | ConvertFrom-Json -Depth 20)
    if ($arguments.Count -eq 0) { throw 'HostArgumentsJson must contain at least one string.' }
    if (@($arguments | Where-Object { $_ -isnot [string] }).Count -gt 0) { throw 'HostArgumentsJson must be an array of strings.' }
    $profileIndexes = @(for ($index = 0; $index -lt $arguments.Count; $index++) { if ($arguments[$index] -ceq '--profile') { $index } })
    if ($profileIndexes.Count -gt 1 -or ($profileIndexes.Count -eq 1 -and $profileIndexes[0] + 1 -ge $arguments.Count)) {
        throw 'The host --profile argument must occur at most once and have a value.'
    }
    $hostProfile = if ($profileIndexes.Count -eq 1) { [string]$arguments[$profileIndexes[0] + 1] } else { '' }
    if (-not [string]::IsNullOrWhiteSpace($Profile) -and $Profile -cne $hostProfile) {
        throw 'The declared prerequisite Profile must match the host --profile argument.'
    }
} catch { Write-InstalledError 10 'invalid-input' "Invalid HostArgumentsJson: $($_.Exception.Message)" }

$skipProfile = $arguments[0] -ceq 'version' -or
    ($arguments.Count -ge 2 -and $arguments[0] -ceq 'profile' -and $arguments[1] -in @('discover','draft','configure','review-template'))
if (-not $skipProfile -and [string]::IsNullOrWhiteSpace($hostProfile)) {
    Write-InstalledError 10 'invalid-input' 'This Host operation requires exactly one --profile argument for prerequisite selection.'
}
$prerequisiteProfile = if ($skipProfile) { 'none' } else { $hostProfile }

$pwshPath = if ($IsWindows) { Join-Path $PSHOME 'pwsh.exe' } else { Join-Path $PSHOME 'pwsh' }
$prerequisiteScript = Join-Path $package 'core/distribution/Test-V4Prerequisites.ps1'
$prerequisiteArguments = @('-PackageRoot',$package,'-Profile',$prerequisiteProfile,'-ReportPath',$PrerequisiteReportPath)
if ($skipProfile) { $prerequisiteArguments += '-SkipProfile' }
if ($layout.SelfContained) { $prerequisiteArguments += @('-ExcludeHostRuntime','dotnet') }
$null = & $pwshPath -NoLogo -NoProfile -NonInteractive -File $prerequisiteScript @prerequisiteArguments
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$report = Get-Content -Raw -LiteralPath $PrerequisiteReportPath | ConvertFrom-Json
$hostPath = [string]$layout.HostPath
if ($layout.SelfContained) {
    & $hostPath @arguments
    exit $LASTEXITCODE
}
$dotnet = @($report.requirements | Where-Object { $_.runtime -eq 'dotnet' -and $_.status -eq 'pass' } | Select-Object -First 1)
if ($dotnet.Count -ne 1 -or [string]::IsNullOrWhiteSpace([string]$dotnet[0].executablePath)) {
    Write-InstalledError 15 'prerequisite-missing' 'A validated dotnet executable is unavailable.'
}
& $dotnet[0].executablePath $hostPath @arguments
exit $LASTEXITCODE
