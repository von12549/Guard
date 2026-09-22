[CmdletBinding()]
param(
    [string] $PackageRoot = (Join-Path $PSScriptRoot '../..'),
    [string] $Profile = 'default',
    [Parameter(Mandatory)][string] $PrerequisiteReportPath,
    [Parameter(Mandatory)][string] $HostArgumentsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$package = [IO.Path]::TrimEndingDirectorySeparator([IO.Path]::GetFullPath($PackageRoot))
$distributionRoot = [IO.Directory]::GetParent($package).FullName
$hostDll = Join-Path $distributionRoot 'host/v4-guards.dll'
if (-not [IO.File]::Exists($hostDll)) { [Console]::Error.WriteLine('Installed host/v4-guards.dll is missing.'); exit 12 }

try {
    $arguments = @($HostArgumentsJson | ConvertFrom-Json -Depth 20)
    if (@($arguments | Where-Object { $_ -isnot [string] }).Count -gt 0) { throw 'HostArgumentsJson must be an array of strings.' }
    $profileIndexes = @(for ($index = 0; $index -lt $arguments.Count; $index++) { if ($arguments[$index] -ceq '--profile') { $index } })
    if ($profileIndexes.Count -gt 1 -or ($profileIndexes.Count -eq 1 -and ($profileIndexes[0] + 1 -ge $arguments.Count -or $arguments[$profileIndexes[0] + 1] -cne $Profile))) {
        throw 'The declared prerequisite Profile must match the host --profile argument.'
    }
} catch { [Console]::Error.WriteLine("Invalid HostArgumentsJson: $($_.Exception.Message)"); exit 10 }

$pwshPath = if ($IsWindows) { Join-Path $PSHOME 'pwsh.exe' } else { Join-Path $PSHOME 'pwsh' }
$prerequisiteScript = Join-Path $package 'core/distribution/Test-V4Prerequisites.ps1'
$null = & $pwshPath -NoLogo -NoProfile -NonInteractive -File $prerequisiteScript -PackageRoot $package -Profile $Profile -ReportPath $PrerequisiteReportPath
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$report = Get-Content -Raw -LiteralPath $PrerequisiteReportPath | ConvertFrom-Json
$dotnet = @($report.requirements | Where-Object { $_.runtime -eq 'dotnet' -and $_.status -eq 'pass' } | Select-Object -First 1)
if ($dotnet.Count -ne 1 -or [string]::IsNullOrWhiteSpace([string]$dotnet[0].executablePath)) {
    [Console]::Error.WriteLine('A validated dotnet executable is unavailable.'); exit 15
}
& $dotnet[0].executablePath $hostDll @arguments
exit $LASTEXITCODE
