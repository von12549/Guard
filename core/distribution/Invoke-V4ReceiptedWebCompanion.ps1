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
$launcher = Join-Path $package 'core/distribution/Invoke-V4InstalledWebCompanion.ps1'
if (-not [IO.File]::Exists($launcher)) { throw 'Installed Web Companion launcher is missing.' }
& $launcher -PackageRoot $package -Profile $Profile -PrerequisiteReportPath $PrerequisiteReportPath -CompanionArgumentsJson $CompanionArgumentsJson
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
