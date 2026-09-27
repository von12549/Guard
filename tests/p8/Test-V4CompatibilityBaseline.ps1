[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$packageRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'));$repoRoot=$packageRoot;$workRoot=[IO.Path]::Combine([IO.Path]::GetTempPath(),'v4-guards-work',[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($packageRoot))).Substring(0,12).ToLowerInvariant());if(-not(Test-Path -LiteralPath (Join-Path $workRoot '.git'))){[void][IO.Directory]::CreateDirectory($workRoot);& git -C $workRoot init -q;& git -C $workRoot -c user.name=v4-guards-test -c user.email=v4-guards-test@example.invalid -c commit.gpgsign=false commit -q --allow-empty -m 'V4 test work root';if($LASTEXITCODE){throw 'V4 test work root initialization failed.'}};$runRoot=Join-Path $workRoot 'p8-compatibility'
$baselinePath=Join-Path $packageRoot 'core/certification/compatibility-baseline.json';$schema=Join-Path $packageRoot 'core/contracts/compatibility-baseline.schema.json'
if(-not(Test-Json -LiteralPath $baselinePath -SchemaFile $schema -ErrorAction SilentlyContinue)){throw 'Compatibility baseline violates its schema.'}
$baseline=Get-Content -Raw $baselinePath|ConvertFrom-Json -AsHashtable -Depth 100;$seen=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
foreach($entry in $baseline.files){if(-not$seen.Add([string]$entry.path)){throw "Duplicate compatibility path: $($entry.path)"};$path=Join-Path $packageRoot ([string]$entry.path);if(-not(Test-Path $path)-or(Get-FileHash $path).Hash.ToLowerInvariant()-cne[string]$entry.sha256){throw "Compatibility drift: $($entry.path)"}}
$roles=@($baseline.files.role|Sort-Object -Unique);if(($roles-join',')-cne'cli,configuration,report'){throw 'Compatibility baseline does not cover CLI, configuration and report roles.'}
if(Test-Path $runRoot){Remove-Item -LiteralPath $runRoot -Recurse -Force};Copy-Item -LiteralPath $packageRoot -Destination $runRoot -Recurse
[IO.File]::AppendAllText((Join-Path $runRoot 'core/contracts/cli-contract.json')," `n",[Text.UTF8Encoding]::new($false))
$output=@(& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $runRoot 'core/runtime/Test-V4Package.ps1') -PackageRoot $runRoot 2>&1)
if($LASTEXITCODE-eq0-or($output-join"`n")-notmatch'compatibility baseline hash drift'){throw 'Compatibility drift was not rejected by Package Check.'}
Copy-Item -LiteralPath (Join-Path $packageRoot 'core/contracts/cli-contract.json') -Destination (Join-Path $runRoot 'core/contracts/cli-contract.json') -Force
$compositionContracts=@('extension-bundle.schema.json','extension-review.schema.json','composition-manifest.schema.json','composition-receipt.schema.json')
foreach($name in $compositionContracts){
    $relative="core/contracts/$name"
    if(@($baseline.files|Where-Object path -CEQ $relative).Count-ne1){throw "Composition schema is not bound exactly once: $relative"}
    $fixture=Join-Path $runRoot $relative
    [IO.File]::AppendAllText($fixture," `n",[Text.UTF8Encoding]::new($false))
    $output=@(& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $runRoot 'core/runtime/Test-V4Package.ps1') -PackageRoot $runRoot 2>&1)
    $plain=($output-join"`n")-replace '\x1b\[[0-9;]*m',''
    $pattern='compatibility baseline hash drift:[\s|]*'+[regex]::Escape($relative)
    if($LASTEXITCODE -eq 0 -or $plain -notmatch $pattern){throw "Composition schema drift was not rejected: $relative"}
    Copy-Item -LiteralPath (Join-Path $packageRoot $relative) -Destination $fixture -Force
}
Write-Host "V4 P8 compatibility baseline passed: $($baseline.files.Count) frozen CLI/config/report authorities and five drift controls."
