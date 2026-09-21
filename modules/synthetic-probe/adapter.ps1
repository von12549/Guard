Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($env:V4_SPIKE_INPUT_JSON)) {
    throw 'V4_SPIKE_INPUT_JSON is required.'
}

$inputData = $env:V4_SPIKE_INPUT_JSON | ConvertFrom-Json
if ($inputData.formatVersion -ne 1 -or $inputData.stage -ne 'analysis') {
    throw 'Unsupported spike input.'
}

$targetRoot = [IO.Path]::GetFullPath([string]$inputData.targetRoot)
$inputPath = [IO.Path]::GetFullPath((Join-Path $targetRoot 'input.txt'))
$targetPrefix = $targetRoot.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
if (-not $inputPath.StartsWith($targetPrefix, [StringComparison]::OrdinalIgnoreCase) -or -not [IO.File]::Exists($inputPath)) {
    throw 'The synthetic target input is missing or unsafe.'
}

$content = [IO.File]::ReadAllText($inputPath).Trim()
$findings = @(if ($content -ne 'synthetic-ok') { 'SYNTHETIC.INPUT' })
$result = [ordered]@{
    formatVersion = 1
    status = if ($findings.Count -eq 0) { 'pass' } else { 'fail' }
    findings = $findings
}
$result | ConvertTo-Json -Compress
