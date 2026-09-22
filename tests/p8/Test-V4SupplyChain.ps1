[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$packageRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'));$repoRoot=[IO.Path]::GetFullPath((Join-Path $packageRoot '../../..'));$runRoot=Join-Path $repoRoot 'artifacts/guards/v4/p8-supply-chain';$checker=Join-Path $packageRoot 'core/certification/Test-V4SupplyChain.ps1'
$output=@(& pwsh -NoLogo -NoProfile -NonInteractive -File $checker -PackageRoot $packageRoot 2>&1);if($LASTEXITCODE){throw "Supply-chain positive failed: $($output-join"`n")"};$result=($output-join"`n")|ConvertFrom-Json
if($result.status -cne 'pass' -or -not $result.offlineNuGet -or @($result.dependencyLocks).Count -ne 3 -or @($result.forbiddenRuntimeReferences).Count -ne 0){throw 'Supply-chain result identity is invalid.'}
if(Test-Path $runRoot){Remove-Item -LiteralPath $runRoot -Recurse -Force};Copy-Item -LiteralPath $packageRoot -Destination $runRoot -Recurse
[IO.File]::AppendAllText((Join-Path $runRoot 'core/host/V4.Guards.Host/Program.cs'),"`n// LayerGuard runtime bridge`n",[Text.UTF8Encoding]::new($false))
$negative=@(& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $runRoot 'core/certification/Test-V4SupplyChain.ps1') -PackageRoot $runRoot 2>&1)
if($LASTEXITCODE-eq0-or($negative-join"`n")-notmatch'V3/IFX/LayerGuard runtime path'){throw 'Forbidden legacy runtime reference was not rejected.'}
Write-Host 'V4 P8 supply-chain tests passed: offline sources, exact dependency locks/cache hashes, package content and legacy-runtime rejection.'
