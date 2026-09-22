[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('success','failure','cancelled','skipped')][string] $ContractResult,
    [Parameter(Mandatory)][ValidateSet('success','failure','cancelled','skipped')][string] $LinuxResult,
    [Parameter(Mandatory)][ValidateSet('success','failure','cancelled','skipped')][string] $PackageResult,
    [Parameter(Mandatory)][ValidateSet('success','failure','cancelled','skipped')][string] $WindowsResult,
    [Parameter(Mandatory)][ValidateSet('true','false')][string] $WindowsRequired,
    [Parameter(Mandatory)][ValidateSet('none','smoke','full')][string] $WindowsCoverage
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$failures = [Collections.Generic.List[string]]::new()
foreach ($entry in @([pscustomobject]@{ Name='v4-contract'; Result=$ContractResult }, [pscustomobject]@{ Name='v4-linux'; Result=$LinuxResult }, [pscustomobject]@{ Name='v4-package'; Result=$PackageResult })) {
    if ($entry.Result -cne 'success') { $failures.Add("$($entry.Name) did not succeed: $($entry.Result)") }
}
$required = $WindowsRequired -ceq 'true'
if ($required -and $WindowsCoverage -ceq 'none') { $failures.Add('Windows is required but the selected coverage is none.') }
if (-not $required -and $WindowsCoverage -cne 'none') { $failures.Add('Windows coverage was selected without a required Windows verdict.') }
if ($required -and $WindowsResult -cne 'success') { $failures.Add("Selected Windows coverage did not succeed: $WindowsResult") }
if (-not $required -and $WindowsResult -notin @('success','skipped')) { $failures.Add("Optional Windows result is invalid: $WindowsResult") }

$result = [ordered]@{
    formatVersion = 1
    status = if ($failures.Count -eq 0) { 'pass' } else { 'fail' }
    exitCategory = if ($failures.Count -eq 0) { 'success' } else { 'findings-blocking' }
    windowsRequired = $required
    windowsCoverage = $WindowsCoverage
    failures = @($failures)
}
$json = $result | ConvertTo-Json -Depth 20
if ($failures.Count -gt 0) { [Console]::Error.WriteLine($json); exit 16 }
$json
