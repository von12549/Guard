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
$evidenceRoot = [IO.Path]::GetFullPath([string]$inputData.evidenceRoot)
$requiredEvidenceFields = @('workspaceEvidencePath','workspaceEvidenceSha256','workspaceEvidenceTargetCommit')
$presentEvidenceFields = @($requiredEvidenceFields | Where-Object { $inputData.PSObject.Properties.Name -contains $_ })
$configPropertyNames = @($inputData.config.PSObject.Properties | ForEach-Object { $_.Name })
$expectWorkspaceEvidence = $configPropertyNames -contains 'expectWorkspaceEvidence' -and [bool]$inputData.config.expectWorkspaceEvidence
$workspaceEvidence = $null
if ($expectWorkspaceEvidence) {
    if ($presentEvidenceFields.Count -ne $requiredEvidenceFields.Count) { throw 'V4 Host workspace evidence binding is incomplete.' }
    $workspaceEvidencePath = [IO.Path]::GetFullPath([string]$inputData.workspaceEvidencePath)
    $evidencePrefix = $evidenceRoot.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    if (-not $workspaceEvidencePath.StartsWith($evidencePrefix, [StringComparison]::OrdinalIgnoreCase) -or
        -not [IO.File]::Exists($workspaceEvidencePath)) { throw 'V4 Host workspace evidence path is outside EvidenceRoot or missing.' }
    $workspaceEvidenceSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $workspaceEvidencePath).Hash.ToLowerInvariant()
    if ($workspaceEvidenceSha256 -cne [string]$inputData.workspaceEvidenceSha256) { throw 'V4 Host workspace evidence hash drift.' }
    $workspaceEvidence = Get-Content -Raw -LiteralPath $workspaceEvidencePath | ConvertFrom-Json
    if ($workspaceEvidence.formatVersion -ne 1 -or $workspaceEvidence.scope -cne 'v4-workspace-evidence-v1' -or
        $workspaceEvidence.targetCommit -cne [string]$inputData.workspaceEvidenceTargetCommit -or
        $workspaceEvidence.pathOrder -cne 'ordinal' -or @($workspaceEvidence.files).Count -ne $workspaceEvidence.fileCount) {
        throw 'V4 Host workspace evidence identity drift.'
    }
}
elseif ($presentEvidenceFields.Count -ne 0) {
    throw 'V4 Host exposed workspace evidence without an EvidenceRoot capability.'
}
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

if ($expectWorkspaceEvidence) {
    $inputEntry = @($workspaceEvidence.files | Where-Object { $_.path -ceq 'input.txt' })
    if ($inputEntry.Count -ne 1 -or $inputEntry[0].extension -cne '.txt' -or
        $inputEntry[0].sha256 -cne (Get-FileHash -Algorithm SHA256 -LiteralPath $inputPath).Hash.ToLowerInvariant() -or
        [string]$inputEntry[0].text -cne [IO.File]::ReadAllText($inputPath)) {
        throw 'V4 Host workspace evidence content drift.'
    }
}

$content = [IO.File]::ReadAllText($inputPath).Trim()
$findings = @(if ($content -ne 'synthetic-ok') { 'SYNTHETIC.INPUT' })
$result = [ordered]@{
    formatVersion = 1
    status = if ($findings.Count -eq 0) { 'pass' } else { 'fail' }
    findings = $findings
}
$result | ConvertTo-Json -Compress
