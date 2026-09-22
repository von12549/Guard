[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$packageRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$repoRoot = [IO.Path]::GetFullPath((Join-Path $packageRoot '../../..'))
$runRoot = Join-Path $repoRoot 'artifacts/guards/v4/p7-docs'
$generator = Join-Path $packageRoot 'core/distribution/Publish-V4Documentation.ps1'

if (Test-Path -LiteralPath $runRoot) { Remove-Item -LiteralPath $runRoot -Recurse -Force }
[void][IO.Directory]::CreateDirectory($runRoot)
& pwsh -NoLogo -NoProfile -NonInteractive -File $generator -PackageRoot $packageRoot -Mode Check | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Checked-in V4 generated documentation drifted.' }

$copy = Join-Path $runRoot 'package'
Copy-Item -LiteralPath $packageRoot -Destination $copy -Recurse
[IO.File]::AppendAllText((Join-Path $copy 'docs/commands.md'), "drift`n", [Text.UTF8Encoding]::new($false))
$output = @(& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $copy 'core/distribution/Publish-V4Documentation.ps1') -PackageRoot $copy -Mode Check 2>&1)
if ($LASTEXITCODE -eq 0 -or ($output -join "`n") -notmatch 'Generated documentation drift') { throw 'Documentation drift was not rejected.' }

& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $copy 'core/distribution/Publish-V4Documentation.ps1') -PackageRoot $copy -Mode Write | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Documentation regeneration failed.' }
& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $copy 'core/distribution/Publish-V4Documentation.ps1') -PackageRoot $copy -Mode Check | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Regenerated documentation is not deterministic.' }

Write-Host 'V4 P7 documentation tests passed: schema generation, drift rejection and deterministic regeneration.'
