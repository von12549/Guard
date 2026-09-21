Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($env:V4_STAGE_INPUT_JSON)) {
    throw 'V4_STAGE_INPUT_JSON is required.'
}

$inputData = $env:V4_STAGE_INPUT_JSON | ConvertFrom-Json
if ($inputData.formatVersion -ne 1 -or $inputData.stage -notin @('pre','post')) {
    throw 'Architecture Conformance supports only Pre and Post.'
}

[ordered]@{
    formatVersion = 1
    status = 'pass'
    findings = @()
    coverage = @()
} | ConvertTo-Json -Compress
