[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../../..'))
$v4Root = Join-Path $repoRoot 'docs/guards/v4'
$proposalPath = Join-Path $v4Root 'plans/03-genesis-bootstrap-and-autonomy.md'
$workflowPath = Join-Path $v4Root 'integrations/github/proposed-v4-guards.yml'
$activeV4Workflow = Join-Path $repoRoot '.github/workflows/v4-guards.yml'
$activeV3Workflow = Join-Path $repoRoot '.github/workflows/v3-ifx-guardrails.yml'
$expectedV3WorkflowHash = '3bfcc942deba649fc6df4825067428a94f07664782ac146ffb20c8f74c0e0e4e'
$failures = [Collections.Generic.List[string]]::new()

function Require-Text([string] $Label, [string] $Text, [string] $Pattern) {
    if ($Text -notmatch $Pattern) { $failures.Add("Missing $Label") }
}

$proposal = Get-Content -Raw -LiteralPath $proposalPath
$workflow = Get-Content -Raw -LiteralPath $workflowPath

Require-Text 'authorized branch identity' $proposal '(?m)`codex/v4-development-base`'
foreach ($state in @('G0_V3_GENESIS','G1_V4_DORMANT_BASE','G2_V4_AUTONOMOUS')) {
    Require-Text "transition state $state" $proposal ([Regex]::Escape($state))
}
Require-Text 'candidate self-judgment prohibition' $proposal '(?i)candidate head judges itself|candidate V4 output cannot accept'
Require-Text 'separate workflow authorization' $proposal '(?i)workflow activation.*authorizes none|separately authorized activation'
Require-Text 'separate V3 trigger change' $proposal ([Regex]::Escape('.github/workflows/v3-ifx-guardrails.yml'))
Require-Text 'future active V4 workflow path' $proposal ([Regex]::Escape('.github/workflows/v4-guards.yml'))
Require-Text 'ruleset requirement' $proposal '(?i)ruleset.*v4-required'

Require-Text 'target base branch filter' $workflow '(?m)^\s+branches:\s*\[codex/v4-development-base\]\s*$'
Require-Text 'pull-request base SHA' $workflow 'github\.event\.pull_request\.base\.sha'
Require-Text 'pull-request head SHA' $workflow 'github\.event\.pull_request\.head\.sha'
Require-Text 'base-owned runner' $workflow 'v4-base/docs/guards/v4/integrations/github/Invoke-V4TrustedBase\.ps1'
Require-Text 'base SHA persisted for the contract verdict' $workflow 'V4_BASE_SHA=\$env:BASE_SHA'
Require-Text 'read-only permissions' $workflow '(?ms)^permissions:\s*\r?\n\s+contents:\s+read\s*$'
Require-Text 'required aggregate always appears' $workflow '(?ms)^\s+v4-required:\s*\r?\n\s+name:\s+v4-required\s*\r?\n\s+if:\s+always\(\)'
Require-Text 'required Windows fail-closed condition' $workflow "WINDOWS_REQUIRED -eq 'true'.*WINDOWS_RESULT -ne 'success'"

$expectedRequired = @('v4-contract','v4-linux','v4-package','v4-required')
$actualRequired = @([Regex]::Matches($workflow, '(?m)^\s+name:\s+(v4-(?:contract|linux|package|required))\s*$') | ForEach-Object { $_.Groups[1].Value } | Sort-Object)
if (($actualRequired -join ',') -cne (($expectedRequired | Sort-Object) -join ',')) {
    $failures.Add("Required context identities drifted: $($actualRequired -join ', ')")
}

if (Test-Path -LiteralPath $activeV4Workflow) { $failures.Add('The active V4 workflow path must not exist during P0C') }
$actualV3Hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $activeV3Workflow).Hash.ToLowerInvariant()
if ($actualV3Hash -cne $expectedV3WorkflowHash) { $failures.Add('The active V3 workflow changed during P0C') }

if ($failures.Count -gt 0) { throw ($failures -join "`n") }
Write-Host 'V4 P0C genesis/autonomy proposal tests passed: inactive workflow, exact contexts, base-owned verdicts and unchanged V3 workflow.'
