[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$packageRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$repoRoot = $packageRoot
$workRoot = [IO.Path]::Combine([IO.Path]::GetTempPath(),'v4-guards-work',[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($packageRoot))).Substring(0,12).ToLowerInvariant())
if(-not(Test-Path -LiteralPath (Join-Path $workRoot '.git'))){[void][IO.Directory]::CreateDirectory($workRoot);& git -C $workRoot init -q;& git -C $workRoot -c user.name=v4-guards-test -c user.email=v4-guards-test@example.invalid -c commit.gpgsign=false commit -q --allow-empty -m 'V4 test work root';if($LASTEXITCODE){throw 'V4 test work root initialization failed.'}}
$runRoot = Join-Path $workRoot 'p7-docs'
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
