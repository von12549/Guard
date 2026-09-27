[CmdletBinding()]
param(
    [string] $PackageRoot = (Join-Path $PSScriptRoot '../..'),
    [string] $Profile = 'default',
    [Parameter(Mandatory)][string] $PrerequisiteReportPath,
    [Parameter(Mandatory)][string] $CompanionArgumentsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$package = [IO.Path]::TrimEndingDirectorySeparator([IO.Path]::GetFullPath($PackageRoot))
$distributionRoot = [IO.Directory]::GetParent($package).FullName
$hostDll = Join-Path $distributionRoot 'host/v4-guards.dll'
$companionDll = Join-Path $distributionRoot 'companion/v4-web-companion.dll'
if (-not [IO.File]::Exists($hostDll) -or -not [IO.File]::Exists($companionDll)) {
    [Console]::Error.WriteLine('Installed Host or Web Companion entry assembly is missing.'); exit 12
}

try {
    $arguments = @($CompanionArgumentsJson | ConvertFrom-Json -Depth 20)
    if ($arguments.Count -eq 0 -or @($arguments | Where-Object { $_ -isnot [string] }).Count -gt 0) {
        throw 'CompanionArgumentsJson must be a non-empty array of strings.'
    }
    if (($arguments.Count % 2) -ne 0) { throw 'CompanionArgumentsJson must contain --name value pairs.' }
    $allowed = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($name in @('--target-root','--state-root','--evidence-root','--plan-root','--port')) { [void]$allowed.Add($name) }
    for ($index = 0; $index -lt $arguments.Count; $index += 2) {
        $name = [string]$arguments[$index]
        $value = [string]$arguments[$index + 1]
        if (-not $allowed.Contains($name)) { throw "Installed launcher refuses Companion option: $name" }
        if ([string]::IsNullOrWhiteSpace($value) -or $value.IndexOfAny([char[]]@(0,10,13)) -ge 0) {
            throw "Installed launcher refuses an empty or control-character value for $name."
        }
    }
} catch { [Console]::Error.WriteLine("Invalid CompanionArgumentsJson: $($_.Exception.Message)"); exit 10 }

$pwshPath = if ($IsWindows) { Join-Path $PSHOME 'pwsh.exe' } else { Join-Path $PSHOME 'pwsh' }
$prerequisiteScript = Join-Path $package 'core/distribution/Test-V4Prerequisites.ps1'
$null = & $pwshPath -NoLogo -NoProfile -NonInteractive -File $prerequisiteScript -PackageRoot $package -Profile $Profile -ReportPath $PrerequisiteReportPath
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$report = Get-Content -Raw -LiteralPath $PrerequisiteReportPath | ConvertFrom-Json
$dotnet = @($report.requirements | Where-Object { $_.runtime -eq 'dotnet' -and $_.status -eq 'pass' } | Select-Object -First 1)
if ($dotnet.Count -ne 1 -or [string]::IsNullOrWhiteSpace([string]$dotnet[0].executablePath)) {
    [Console]::Error.WriteLine('A validated dotnet executable is unavailable.'); exit 15
}

& $dotnet[0].executablePath $companionDll '--package-root' $package '--host' $hostDll @arguments
exit $LASTEXITCODE
