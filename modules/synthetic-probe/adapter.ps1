Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($env:V4_STAGE_INPUT_JSON) -and [string]::IsNullOrWhiteSpace($env:V4_SPIKE_INPUT_JSON)) {
    throw 'V4_STAGE_INPUT_JSON is required.'
}

$inputJson = if (-not [string]::IsNullOrWhiteSpace($env:V4_STAGE_INPUT_JSON)) { $env:V4_STAGE_INPUT_JSON } else { $env:V4_SPIKE_INPUT_JSON }
$inputData = $inputJson | ConvertFrom-Json
if ($inputData.formatVersion -ne 1 -or $inputData.stage -notin @('bootstrap','analysis','pre','post')) {
    throw 'Unsupported Stage input.'
}

$targetRoot = [IO.Path]::GetFullPath([string]$inputData.targetRoot)
$inputPath = [IO.Path]::GetFullPath((Join-Path $targetRoot 'input.txt'))
$targetPrefix = $targetRoot.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
if (-not $inputPath.StartsWith($targetPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'The synthetic target input is unsafe.'
}
if (-not [IO.File]::Exists($inputPath)) {
    [ordered]@{
        formatVersion = 1
        status = 'error'
        exitCategory = 'prerequisite-missing'
        message = 'TargetRoot/input.txt is required.'
        findings = @()
    } | ConvertTo-Json -Compress
    exit 0
}

$content = [IO.File]::ReadAllText($inputPath).Trim()
$findings = @(if ($content -ne 'synthetic-ok') { 'SYNTHETIC.INPUT' })
$result = [ordered]@{
    formatVersion = 1
    status = if ($findings.Count -eq 0) { 'pass' } else { 'fail' }
    findings = $findings
}
$result | ConvertTo-Json -Compress
