[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$packageRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $packageRoot '../../..'))
$project = Join-Path $packageRoot 'core/host/V4.Guards.Host/V4.Guards.Host.csproj'
$buildRoot = Join-Path $packageRoot 'build'
$artifactsRoot = Join-Path $repositoryRoot 'artifacts/guards/v4/p8-stable-cli'
$runRoot = Join-Path ([IO.Path]::GetTempPath()) ('v4-p8-cli-' + [Guid]::NewGuid().ToString('N'))
$failures = [Collections.Generic.List[string]]::new()

function Invoke-Host([string[]] $Arguments) {
    $dll = Join-Path $artifactsRoot 'bin/V4.Guards.Host/debug/v4-guards.dll'
    $output = @(& dotnet $dll @Arguments 2>&1)
    [pscustomobject]@{ Code = $LASTEXITCODE; Text = ($output -join "`n") }
}
function Expect($Run, [int] $Code, [string] $Name, [string] $Pattern) {
    if ($Run.Code -ne $Code -or $Run.Text -notmatch $Pattern) {
        $failures.Add("${Name}: expected $Code/$Pattern, got $($Run.Code): $($Run.Text)")
    }
}

try {
    if (Test-Path $artifactsRoot) { Remove-Item -LiteralPath $artifactsRoot -Recurse -Force }
    [void][IO.Directory]::CreateDirectory($artifactsRoot)
    [void][IO.Directory]::CreateDirectory($runRoot)
    $properties = @(
        '-p:ImportDirectoryBuildProps=false', '-p:ImportDirectoryBuildTargets=false', '-p:ImportDirectoryPackagesProps=false',
        '-p:ImportDirectorySolutionProps=false', '-p:ImportDirectorySolutionTargets=false',
        "-p:CustomBeforeMicrosoftCommonProps=$(Join-Path $buildRoot 'V4.Build.props')"
    )
    Push-Location $buildRoot
    try {
        & dotnet restore $project --configfile (Join-Path $buildRoot 'NuGet.config') --artifacts-path $artifactsRoot -nologo @properties
        if ($LASTEXITCODE) { throw 'Stable CLI host restore failed.' }
        & dotnet build $project --no-restore --artifacts-path $artifactsRoot -nologo @properties
        if ($LASTEXITCODE) { throw 'Stable CLI host build failed.' }
    } finally { Pop-Location }

    $plugin = Get-Content -Raw (Join-Path $packageRoot 'plugin.json') | ConvertFrom-Json
    $version = Invoke-Host @('version')
    Expect $version 0 'version' '"version"\s*:\s*"1\.1\.1"'
    if ($version.Code -eq 0) {
        $versionResult = $version.Text | ConvertFrom-Json
        if ($versionResult.version -cne $plugin.version -or $versionResult.apiVersion -cne $plugin.apiVersion) {
            $failures.Add('Version command does not match plugin metadata.')
        }
    }

    $positive = Invoke-Host @('contract','validate','--package-root',$packageRoot,'--schema','plugin','--document',(Join-Path $packageRoot 'plugin.json'))
    Expect $positive 0 'contract positive' '"command"\s*:\s*"contract\.validate"'

    $invalidDocument = Join-Path $runRoot 'invalid-plugin.json'
    [IO.File]::WriteAllText($invalidDocument, "{`"formatVersion`":1}`n", [Text.UTF8Encoding]::new($false))
    Expect (Invoke-Host @('contract','validate','--package-root',$packageRoot,'--schema','plugin','--document',$invalidDocument)) 16 'contract invalid document' '"exitCategory"\s*:\s*"findings-blocking"'
    Expect (Invoke-Host @('contract','validate','--package-root',$packageRoot,'--schema','unregistered','--document',(Join-Path $packageRoot 'plugin.json'))) 10 'contract unregistered schema' 'Schema is not registered'

    $tamperedPackage = Join-Path $runRoot 'tampered-package'
    Copy-Item -LiteralPath $packageRoot -Destination $tamperedPackage -Recurse
    [IO.File]::AppendAllText((Join-Path $tamperedPackage 'core/contracts/plugin.schema.json'), " `n", [Text.UTF8Encoding]::new($false))
    Expect (Invoke-Host @('contract','validate','--package-root',$tamperedPackage,'--schema','plugin','--document',(Join-Path $tamperedPackage 'plugin.json'))) 12 'contract schema drift' '"exitCategory"\s*:\s*"integrity-failure"'

    $cli = Get-Content -Raw (Join-Path $packageRoot 'core/contracts/cli-contract.json') | ConvertFrom-Json
    foreach ($id in @('contract.validate','reset.project','reset.factory')) {
        $syntax = [string](@($cli.commands | Where-Object id -ceq $id)[0].syntax)
        if ($syntax -notmatch '--package-root <path>') { $failures.Add("$id does not declare PackageRoot in its syntax.") }
    }
    foreach ($entry in Get-ChildItem (Join-Path $packageRoot 'modules') -Filter module.json -Recurse) {
        $module = Get-Content -Raw $entry.FullName | ConvertFrom-Json
        if ($module.version -cne '1.0.0') { $failures.Add("$($module.id) changed despite having no component release in V4 1.1.1.") }
        if (@($module.supportedPlatforms) -contains 'osx-arm64') { $failures.Add("macOS remains declared by $($module.id).") }
        if ((@($module.supportedPlatforms | Sort-Object) -join ',') -cne 'linux-x64,win-x64') { $failures.Add("$($module.id) platform declaration is not the certified Linux/Windows set.") }
    }

    if ($failures.Count) { throw ($failures -join "`n") }
    Write-Host 'V4 stable CLI tests passed: product version 1.1.1, API-compatible module versions, contract validation behavior, required-root syntax and Linux/Windows-only declarations.'
}
finally {
    if (Test-Path $runRoot) { Remove-Item -LiteralPath $runRoot -Recurse -Force }
}
