[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$packageRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$focusedSuites = @(
    'core/profile/validation/Test-V4ProfileAuthority.ps1',
    'core/application/validation/Test-V4ApplicationBoundary.ps1',
    'core/stage/validation/Test-V4StageSemantics.ps1',
    'core/governance/validation/Test-V4GovernanceFoundation.ps1',
    'core/modules/validation/Test-V4ModuleLifecycle.ps1'
)

foreach ($relativePath in $focusedSuites) {
    $suite = Join-Path $packageRoot $relativePath
    & pwsh -NoLogo -NoProfile -NonInteractive -File $suite
    if ($LASTEXITCODE -ne 0) { throw "Focused suite failed: $relativePath" }
}

Write-Host 'V4 M2-M5 focused suites passed: Profile Authority, Application Boundary, Stage Semantics, Governance Foundation and Module Lifecycle.'
