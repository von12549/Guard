[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$packageRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$contractPath = Join-Path $packageRoot 'integrations/github/ci-contract.json'
$classifier = Join-Path $packageRoot 'integrations/github/Get-V4WindowsSelection.ps1'
$required = Join-Path $packageRoot 'integrations/github/Test-V4Required.ps1'
$contract = Get-Content -Raw $contractPath | ConvertFrom-Json
$failures = [Collections.Generic.List[string]]::new()

function Invoke-Selection([string[]] $Paths, [string] $Requested = 'auto') {
    $pathsJson = ConvertTo-Json -InputObject @($Paths) -Compress
    $output = @(& pwsh -NoProfile -File $classifier -ContractPath $contractPath -ChangedPathsJson $pathsJson -RequestedCoverage $Requested 2>&1)
    [pscustomobject]@{ Code=$LASTEXITCODE; Text=($output -join "`n"); Document=if($LASTEXITCODE -eq 0){($output -join "`n")|ConvertFrom-Json}else{$null} }
}
function Expect-Selection([string] $Name, [string[]] $Paths, [string] $Coverage, [string] $Requested = 'auto') {
    $run = Invoke-Selection $Paths $Requested
    if ($run.Code -ne 0 -or $run.Document.selectedCoverage -cne $Coverage -or [bool]$run.Document.windowsRequired -ne ($Coverage -cne 'none')) { $failures.Add("${Name}: expected $Coverage, got $($run.Code)/$($run.Document.selectedCoverage): $($run.Text)") }
}
function Invoke-Required([string] $WindowsResult, [string] $WindowsRequired, [string] $Coverage, [string] $Linux='success', [string] $Package='success') {
    $output = @(& pwsh -NoProfile -File $required -ContractResult success -LinuxResult $Linux -PackageResult $Package -WindowsResult $WindowsResult -WindowsRequired $WindowsRequired -WindowsCoverage $Coverage 2>&1)
    [pscustomobject]@{ Code=$LASTEXITCODE; Text=($output -join "`n") }
}

Expect-Selection 'ordinary docs-only change' @('docs/guards/v4/plans/note.md','docs/guards/plans/20260922-example.plan.json') 'none'
foreach ($pattern in $contract.windowsSensitivePatterns) {
    $path = if ($pattern.EndsWith('/**')) { $pattern.Substring(0,$pattern.Length-3) + '/probe.txt' } else { [string]$pattern }
    Expect-Selection "sensitive pattern $pattern" @($path,'docs/guards/plans/20260922-example.plan.json') 'smoke'
}
Expect-Selection 'explicit smoke' @('docs/guards/v4/plans/note.md') 'smoke' 'smoke'
Expect-Selection 'explicit full certification' @('docs/guards/v4/plans/note.md') 'full' 'full'
$outside = Invoke-Selection @('src/Application/App.cs'); if ($outside.Code -eq 0) { $failures.Add('Non-V4 changed path unexpectedly classified.') }

if ((Invoke-Required skipped false none).Code -ne 0) { $failures.Add('Optional skipped Windows verdict did not pass.') }
if ((Invoke-Required success true smoke).Code -ne 0) { $failures.Add('Required successful Windows smoke did not pass.') }
if ((Invoke-Required skipped true smoke).Code -eq 0) { $failures.Add('Forced skip of required Windows smoke unexpectedly passed.') }
if ((Invoke-Required failure true full).Code -eq 0) { $failures.Add('Failed full Windows certification unexpectedly passed.') }
if ((Invoke-Required skipped false none failure).Code -eq 0) { $failures.Add('Failed Linux verdict unexpectedly passed.') }
if ((Invoke-Required skipped false none success skipped).Code -eq 0) { $failures.Add('Skipped package verdict unexpectedly passed.') }

if ($failures.Count) { throw ($failures -join "`n") }
Write-Host "V4 P6 classifier tests passed: ordinary, $($contract.windowsSensitivePatterns.Count) sensitive, explicit coverage and required-verdict negatives."
