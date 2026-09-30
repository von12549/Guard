[CmdletBinding()]
param(
    [string] $Profile = 'default',
    [Parameter(Mandatory)][string] $PrerequisiteReportPath,
    [Parameter(ValueFromRemainingArguments)][string[]] $HostArguments
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (@($HostArguments).Count -eq 0) { throw 'At least one Host command argument is required.' }
$launcher = Join-Path $PSScriptRoot 'core/distribution/Invoke-V4Installed.ps1'
& $launcher -Profile $Profile -PrerequisiteReportPath $PrerequisiteReportPath `
    -HostArgumentsJson (ConvertTo-Json -InputObject @($HostArguments) -Compress)
exit $LASTEXITCODE
