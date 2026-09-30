[CmdletBinding()]
param(
    [string] $Profile = 'default',
    [Parameter(Mandatory)][string] $PrerequisiteReportPath,
    [Parameter(ValueFromRemainingArguments)][string[]] $CompanionArguments
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (@($CompanionArguments).Count -eq 0) { throw 'At least one Companion option is required.' }
$launcher = Join-Path $PSScriptRoot 'core/distribution/Invoke-V4InstalledWebCompanion.ps1'
& $launcher -Profile $Profile -PrerequisiteReportPath $PrerequisiteReportPath `
    -CompanionArgumentsJson (ConvertTo-Json -InputObject @($CompanionArguments) -Compress)
exit $LASTEXITCODE
