[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $InstallRoot,
    [Parameter(Mandatory)][string] $ReceiptPath,
    [string] $BaseReceiptPath = '',
    [string] $Profile = 'default',
    [Parameter(Mandatory)][string] $PrerequisiteReportPath,
    [Parameter(Mandatory)][string] $CompanionArgumentsJson,
    [switch] $AllowSyntheticFixture
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$install = [IO.Path]::TrimEndingDirectorySeparator([IO.Path]::GetFullPath($InstallRoot))
$verifier = Join-Path $PSScriptRoot 'Test-V4ComposedInstallation.ps1'
$proofText = @(& $verifier -InstallRoot $install -ReceiptPath $ReceiptPath -BaseReceiptPath $BaseReceiptPath -AllowSyntheticFixture:$AllowSyntheticFixture) -join "`n"
$proof = $proofText | ConvertFrom-Json -AsHashtable -Depth 100
if ($proof.status -cne 'pass') { throw 'Receipt verification did not pass.' }

$package = Join-Path $install 'package'
$resolver = Join-Path $package 'core/distribution/Resolve-V4InstalledLayout.ps1'
if (-not [IO.File]::Exists($resolver)) { throw 'Installed layout resolver is missing.' }
. $resolver
$layout = Resolve-V4InstalledLayout -PackageRoot $package -RequireCompanion -ExpectedPackageHash ([string]$proof.packageHash)

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
        if (-not $allowed.Contains($name)) { throw "Receipted launcher refuses Companion option: $name" }
        if ([string]::IsNullOrWhiteSpace($value) -or $value.IndexOfAny([char[]]@(0,10,13)) -ge 0) {
            throw "Receipted launcher refuses an empty or control-character value for $name."
        }
    }
} catch { throw "Invalid CompanionArgumentsJson: $($_.Exception.Message)" }

$pwshPath = if ($IsWindows) { Join-Path $PSHOME 'pwsh.exe' } else { Join-Path $PSHOME 'pwsh' }
$prerequisiteScript = Join-Path $package 'core/distribution/Test-V4Prerequisites.ps1'
$prerequisiteArguments = @('-PackageRoot',$package,'-Profile',$Profile,'-ReportPath',$PrerequisiteReportPath)
if ($layout.SelfContained) { $prerequisiteArguments += @('-ExcludeHostRuntime','dotnet') }
$null = & $pwshPath -NoLogo -NoProfile -NonInteractive -File $prerequisiteScript @prerequisiteArguments
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$report = Get-Content -Raw -LiteralPath $PrerequisiteReportPath | ConvertFrom-Json
$hostPath = [string]$layout.HostPath
$companionPath = [string]$layout.CompanionPath
if ($layout.SelfContained) {
    & $companionPath '--package-root' $package '--host' $hostPath @arguments
    exit $LASTEXITCODE
}
$dotnet = @($report.requirements | Where-Object { $_.runtime -eq 'dotnet' -and $_.status -eq 'pass' } | Select-Object -First 1)
if ($dotnet.Count -ne 1 -or [string]::IsNullOrWhiteSpace([string]$dotnet[0].executablePath)) {
    [Console]::Error.WriteLine('A validated dotnet executable is unavailable.'); exit 15
}

& $dotnet[0].executablePath $companionPath '--package-root' $package '--host' $hostPath @arguments
exit $LASTEXITCODE
