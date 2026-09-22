[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$packageRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $packageRoot '../../..'))
$buildRoot = Join-Path $packageRoot 'build'
$project = Join-Path $packageRoot 'core/host/V4.Guards.Host/V4.Guards.Host.csproj'
$runRoot = Join-Path ([IO.Path]::GetTempPath()) ('v4-p0a-' + [Guid]::NewGuid().ToString('N'))
$artifactsRoot = Join-Path $repositoryRoot 'artifacts/guards/v4/p0a'
$failures = [Collections.Generic.List[string]]::new()

function Hash-Tree([string] $Root) {
    $items = [ordered]@{}
    Get-ChildItem -LiteralPath $Root -Recurse -File | Sort-Object FullName | ForEach-Object {
        $relative = [IO.Path]::GetRelativePath($Root, $_.FullName).Replace('\', '/')
        $items[$relative] = (Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName).Hash.ToLowerInvariant()
    }
    return ($items | ConvertTo-Json -Compress)
}

function Invoke-Host([string] $Package, [string] $Target, [string] $State, [string] $Evidence) {
    $dll = Join-Path $artifactsRoot 'bin/V4.Guards.Host/debug/v4-guards.dll'
    $output = @(& dotnet $dll spike run --package-root $Package --target-root $Target --state-root $State --evidence-root $Evidence --module synthetic-probe 2>&1)
    return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = ($output -join "`n") }
}

function Assert-Exit([string] $Name, $Run, [int] $Expected, [string] $Category) {
    if ($Run.ExitCode -ne $Expected) { $failures.Add("${Name}: expected exit $Expected, got $($Run.ExitCode): $($Run.Output)") }
    if ($Run.Output -notmatch ('"exitCategory"\s*:\s*"' + [Regex]::Escape($Category) + '"')) {
        $failures.Add("${Name}: output did not contain structured category $Category")
    }
}

function Assert-ResultContract([string] $Name, $Result) {
    $expected = @('adapterSha256','exitCategory','findings','formatVersion','moduleId','roots','stage','status')
    $actual = @($Result.PSObject.Properties.Name | Sort-Object)
    if (($actual -join ',') -cne ($expected -join ',')) { $failures.Add("${Name}: unexpected result fields [$($actual -join ', ')]") }
    $rootFields = @($Result.roots.PSObject.Properties.Name | Sort-Object)
    if (($rootFields -join ',') -cne 'evidenceRoot,packageRoot,stateRoot,targetRoot') { $failures.Add("${Name}: unexpected root fields") }
    if ($Result.formatVersion -ne 1 -or $Result.stage -ne 'analysis' -or $Result.moduleId -ne 'synthetic-probe' -or
        $Result.status -notin @('pass','fail') -or $Result.exitCategory -ne 'success' -or $null -eq $Result.findings) {
        $failures.Add("${Name}: result contract values are invalid")
    }
}

function New-Roots([string] $Name) {
    $root = Join-Path $runRoot $Name
    $target = Join-Path $root 'target'
    $state = Join-Path $root 'state'
    $evidence = Join-Path $root 'evidence'
    foreach ($path in @($target, $state, $evidence)) { [void][IO.Directory]::CreateDirectory($path) }
    Copy-Item -LiteralPath (Join-Path $packageRoot 'tests/fixtures/synthetic-target/input.txt') -Destination $target
    return [pscustomobject]@{ Root = $root; Target = $target; State = $state; Evidence = $evidence }
}

try {
    [void][IO.Directory]::CreateDirectory($runRoot)
    [void][IO.Directory]::CreateDirectory($artifactsRoot)
    $properties = @(
        '-p:ImportDirectoryBuildProps=false', '-p:ImportDirectoryBuildTargets=false', '-p:ImportDirectoryPackagesProps=false',
        '-p:ImportDirectorySolutionProps=false', '-p:ImportDirectorySolutionTargets=false',
        "-p:CustomBeforeMicrosoftCommonProps=$(Join-Path $buildRoot 'V4.Build.props')"
    )
    Push-Location $buildRoot
    try {
        & dotnet restore $project --configfile (Join-Path $buildRoot 'NuGet.config') --artifacts-path $artifactsRoot -nologo @properties
        if ($LASTEXITCODE -ne 0) { throw 'V4 host restore failed.' }
        & dotnet build $project --no-restore --artifacts-path $artifactsRoot -nologo @properties
        if ($LASTEXITCODE -ne 0) { throw 'V4 host build failed.' }
    } finally { Pop-Location }

    $packageHashBefore = Hash-Tree $packageRoot
    $positive = New-Roots 'positive'
    $targetHashBefore = Hash-Tree $positive.Target
    $inPlace = Invoke-Host $packageRoot $positive.Target $positive.State $positive.Evidence
    Assert-Exit 'in-place package' $inPlace 0 'success'
    $inPlaceResult = Get-Content -Raw (Join-Path $positive.Evidence 'stage-result.json') | ConvertFrom-Json
    Assert-ResultContract 'in-place package' $inPlaceResult

    $separatedPackage = Join-Path $runRoot 'separated-package'
    Copy-Item -LiteralPath $packageRoot -Destination $separatedPackage -Recurse
    $separated = New-Roots 'separated'
    Copy-Item -LiteralPath (Join-Path $positive.Target 'input.txt') -Destination $separated.Target -Force
    $external = Invoke-Host $separatedPackage $separated.Target $separated.State $separated.Evidence
    Assert-Exit 'separated package' $external 0 'success'
    $externalResult = Get-Content -Raw (Join-Path $separated.Evidence 'stage-result.json') | ConvertFrom-Json
    Assert-ResultContract 'separated package' $externalResult
    foreach ($property in @('stage', 'moduleId', 'status', 'exitCategory', 'adapterSha256')) {
        if ($inPlaceResult.$property -cne $externalResult.$property) { $failures.Add("verdict mismatch for $property") }
    }
    if (($inPlaceResult.findings | ConvertTo-Json -Compress) -cne ($externalResult.findings | ConvertTo-Json -Compress)) {
        $failures.Add('verdict mismatch for findings')
    }

    $hashPackage = Join-Path $runRoot 'hash-package'
    Copy-Item -LiteralPath $packageRoot -Destination $hashPackage -Recurse
    [IO.File]::AppendAllText((Join-Path $hashPackage 'modules/synthetic-probe/adapter.ps1'), "`n# drift`n")
    $hashRoots = New-Roots 'hash-drift'
    Assert-Exit 'adapter hash drift' (Invoke-Host $hashPackage $hashRoots.Target $hashRoots.State $hashRoots.Evidence) 12 'integrity-failure'

    $capPackage = Join-Path $runRoot 'capability-package'
    Copy-Item -LiteralPath $packageRoot -Destination $capPackage -Recurse
    $capManifestPath = Join-Path $capPackage 'modules/synthetic-probe/module.json'
    $capManifest = Get-Content -Raw $capManifestPath | ConvertFrom-Json
    $capManifest.capabilities.writeRoots = @('TargetRoot')
    [IO.File]::WriteAllText($capManifestPath, (($capManifest | ConvertTo-Json -Depth 10) + "`n"), [Text.UTF8Encoding]::new($false))
    $capRoots = New-Roots 'capability'
    Assert-Exit 'target write capability' (Invoke-Host $capPackage $capRoots.Target $capRoots.State $capRoots.Evidence) 13 'capability-denied'

    $escapePackage = Join-Path $runRoot 'escape-package'
    Copy-Item -LiteralPath $packageRoot -Destination $escapePackage -Recurse
    $escapeManifestPath = Join-Path $escapePackage 'modules/synthetic-probe/module.json'
    $escapeManifest = Get-Content -Raw $escapeManifestPath | ConvertFrom-Json
    $escapeManifest.adapter.path = '../adapter.ps1'
    [IO.File]::WriteAllText($escapeManifestPath, (($escapeManifest | ConvertTo-Json -Depth 10) + "`n"), [Text.UTF8Encoding]::new($false))
    $escapeRoots = New-Roots 'escape'
    Assert-Exit 'adapter path escape' (Invoke-Host $escapePackage $escapeRoots.Target $escapeRoots.State $escapeRoots.Evidence) 11 'unsafe-path'

    $badPackage = Join-Path $runRoot 'malformed-package'
    Copy-Item -LiteralPath $packageRoot -Destination $badPackage -Recurse
    $badAdapter = Join-Path $badPackage 'modules/synthetic-probe/adapter.ps1'
    [IO.File]::WriteAllText($badAdapter, "'not-json'`n", [Text.UTF8Encoding]::new($false))
    $badManifestPath = Join-Path $badPackage 'modules/synthetic-probe/module.json'
    $badManifest = Get-Content -Raw $badManifestPath | ConvertFrom-Json
    $badManifest.adapter.sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $badAdapter).Hash.ToLowerInvariant()
    [IO.File]::WriteAllText($badManifestPath, (($badManifest | ConvertTo-Json -Depth 10) + "`n"), [Text.UTF8Encoding]::new($false))
    $badRoots = New-Roots 'malformed'
    Assert-Exit 'malformed adapter output' (Invoke-Host $badPackage $badRoots.Target $badRoots.State $badRoots.Evidence) 14 'adapter-failure'

    $linkRoots = New-Roots 'link'
    $actualState = Join-Path $linkRoots.Root 'actual-state'
    [void][IO.Directory]::CreateDirectory($actualState)
    Remove-Item -LiteralPath $linkRoots.State
    $linkType = if ($IsWindows) { 'Junction' } else { 'SymbolicLink' }
    New-Item -ItemType $linkType -Path $linkRoots.State -Target $actualState | Out-Null
    Assert-Exit 'linked state root' (Invoke-Host $packageRoot $linkRoots.Target $linkRoots.State $linkRoots.Evidence) 11 'unsafe-path'

    if ((Hash-Tree $positive.Target) -cne $targetHashBefore) { $failures.Add('the positive target changed') }
    if ((Hash-Tree $packageRoot) -cne $packageHashBefore) { $failures.Add('the package authority changed') }
    if ($failures.Count -gt 0) { throw ($failures -join "`n") }

    $summary = [ordered]@{ formatVersion = 1; status = 'pass'; seed = (git -C $repositoryRoot rev-parse HEAD); checks = @('in-place', 'separated', 'equivalent-verdict', 'hash-drift', 'capability-denial', 'path-escape', 'reparse-root', 'malformed-output', 'authority-read-only') }
    [IO.File]::WriteAllText((Join-Path $artifactsRoot 'summary.json'), (($summary | ConvertTo-Json -Depth 5) + "`n"), [Text.UTF8Encoding]::new($false))
    Write-Host "V4 P0A host spike passed. Evidence: $(Join-Path $artifactsRoot 'summary.json')"
}
finally {
    $resolvedRunRoot = [IO.Path]::GetFullPath($runRoot)
    $tempPrefix = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    if ($resolvedRunRoot.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase) -and [IO.Directory]::Exists($resolvedRunRoot)) {
        Remove-Item -LiteralPath $resolvedRunRoot -Recurse -Force
    }
}
