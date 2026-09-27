[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../../..'))
$packageRoot = Join-Path $repoRoot 'docs/guards/v4'
$workflowPath = Join-Path $packageRoot 'integrations/github/proposed-v4-guards.yml'
$contractPath = Join-Path $packageRoot 'integrations/github/ci-contract.json'
$activeV4 = Join-Path $repoRoot '.github/workflows/v4-guards.yml'
$activeV3 = Join-Path $repoRoot '.github/workflows/v3-ifx-guardrails.yml'
$expectedV3Hash = '3bfcc942deba649fc6df4825067428a94f07664782ac146ffb20c8f74c0e0e4e'
$workflow = Get-Content -Raw $workflowPath
$contract = Get-Content -Raw $contractPath | ConvertFrom-Json -AsHashtable -Depth 100
$failures = [Collections.Generic.List[string]]::new()

function Require([string] $Name, [string] $Pattern) { if ($workflow -notmatch $Pattern) { $failures.Add("Missing workflow contract: $Name") } }

if (-not (Test-Json -LiteralPath $contractPath -SchemaFile (Join-Path $packageRoot 'core/contracts/ci-contract.schema.json') -ErrorAction SilentlyContinue)) { $failures.Add('CI contract violates its schema.') }
$contexts = @([Regex]::Matches($workflow,'(?m)^    name: (v4-(?:contract|linux|package|required))$') | ForEach-Object { $_.Groups[1].Value } | Sort-Object)
if (($contexts -join ',') -cne ((@($contract.requiredContexts)|Sort-Object)-join',')) { $failures.Add("Stable required contexts drifted: $($contexts -join ',')") }
Require 'unconditional required verdict' '(?ms)^  v4-required:\r?\n    name: v4-required\r?\n    if: always\(\)'
Require 'read-only permissions' '(?ms)^permissions:\r?\n  contents: read\s*$'
Require 'superseded run cancellation' '(?m)^  cancel-in-progress: true$'
Require 'trusted-base runner' 'v4-base/docs/guards/v4/integrations/github/Invoke-V4TrustedBase\.ps1'
Require 'trusted required aggregator' 'v4-base/docs/guards/v4/integrations/github/Test-V4Required\.ps1'
Require 'head SHA checkout' 'ref: \$\{\{ github\.event\.pull_request\.head\.sha \|\| github\.sha \}\}'
Require 'credential removal' 'persist-credentials: false'
Require 'Linux full producer' '-Mode Linux .* -ArtifactRoot '
Require 'single upload' 'actions/upload-artifact@v4'
Require 'artifact digest output' 'artifact-digest: \$\{\{ steps\.upload\.outputs\.artifact-digest \}\}'
Require 'package artifact reuse' '(?ms)^  v4-package:.*?actions/download-artifact@v5.*?-Mode Package'
Require 'Windows artifact reuse' '(?ms)^  v4-windows:.*?actions/download-artifact@v5.*?-Mode Windows'
Require 'base classifier output condition' "if: needs\.v4-contract\.outputs\.windows-required == 'true'"
Require 'manual full certification' "-Certification','-RequestedWindowsCoverage','full'"
if (@([Regex]::Matches($workflow,'actions/upload-artifact@v4')).Count -ne 1) { $failures.Add('Workflow must produce exactly one uploaded artifact.') }
if ($workflow -match '\$\{\{\s*secrets\.') { $failures.Add('Workflow references a secret.') }
foreach ($forbidden in @('docs/guards/V3','V3_ifx','src/Frontend','IFX.Migration','Database')) { if ($workflow.Contains($forbidden,[StringComparison]::OrdinalIgnoreCase)) { $failures.Add("Workflow invokes excluded suite/path: $forbidden") } }
if (Test-Path $activeV4) { $failures.Add('Active V4 workflow exists before activation authorization.') }
if ((Get-FileHash -Algorithm SHA256 $activeV3).Hash.ToLowerInvariant() -cne $expectedV3Hash) { $failures.Add('Active V3 workflow changed during dormant P6.') }
if (($contract.excludedSuites | Sort-Object) -join ',' -cne (@('ifx-database','ifx-frontend','ifx-solution','v3-package-candidate') -join ',')) { $failures.Add('Excluded suite contract drifted.') }
$discoveredTests = @(Get-ChildItem -LiteralPath (Join-Path $packageRoot 'tests') -File -Filter 'Test-*.ps1' -Recurse | ForEach-Object { [IO.Path]::GetRelativePath($repoRoot,$_.FullName).Replace('\','/') } | Sort-Object)
$approvedTests = @($contract.approvedTests.path | Sort-Object)
if (($discoveredTests -join "`0") -cne ($approvedTests -join "`0")) { $failures.Add('CI contract does not hash-bind the exact V4 test set.') }
foreach ($test in $contract.approvedTests) { if ((Get-FileHash -Algorithm SHA256 (Join-Path $repoRoot $test.path)).Hash.ToLowerInvariant() -cne $test.sha256) { $failures.Add("Approved test hash drift: $($test.path)") } }

if ($failures.Count) { throw ($failures -join "`n") }
Write-Host 'V4 P6 workflow contract tests passed: stable contexts, single artifact reuse, base-owned verdicts, no secrets/IFX suites and inactive activation boundary.'
