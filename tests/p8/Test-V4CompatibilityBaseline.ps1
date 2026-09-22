[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$packageRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'));$repoRoot=[IO.Path]::GetFullPath((Join-Path $packageRoot '../../..'));$runRoot=Join-Path $repoRoot 'artifacts/guards/v4/p8-compatibility'
$baselinePath=Join-Path $packageRoot 'core/certification/compatibility-baseline.json';$schema=Join-Path $packageRoot 'core/contracts/compatibility-baseline.schema.json'
if(-not(Test-Json -LiteralPath $baselinePath -SchemaFile $schema -ErrorAction SilentlyContinue)){throw 'Compatibility baseline violates its schema.'}
$baseline=Get-Content -Raw $baselinePath|ConvertFrom-Json -AsHashtable -Depth 100;$seen=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
foreach($entry in $baseline.files){if(-not$seen.Add([string]$entry.path)){throw "Duplicate compatibility path: $($entry.path)"};$path=Join-Path $packageRoot ([string]$entry.path);if(-not(Test-Path $path)-or(Get-FileHash $path).Hash.ToLowerInvariant()-cne[string]$entry.sha256){throw "Compatibility drift: $($entry.path)"}}
$roles=@($baseline.files.role|Sort-Object -Unique);if(($roles-join',')-cne'cli,configuration,report'){throw 'Compatibility baseline does not cover CLI, configuration and report roles.'}
if(Test-Path $runRoot){Remove-Item -LiteralPath $runRoot -Recurse -Force};Copy-Item -LiteralPath $packageRoot -Destination $runRoot -Recurse
[IO.File]::AppendAllText((Join-Path $runRoot 'core/contracts/cli-contract.json')," `n",[Text.UTF8Encoding]::new($false))
$output=@(& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $runRoot 'core/runtime/Test-V4Package.ps1') -PackageRoot $runRoot 2>&1)
if($LASTEXITCODE-eq0-or($output-join"`n")-notmatch'compatibility baseline hash drift'){throw 'Compatibility drift was not rejected by Package Check.'}
Write-Host "V4 P8 compatibility baseline passed: $($baseline.files.Count) frozen CLI/config/report authorities and drift rejection."
