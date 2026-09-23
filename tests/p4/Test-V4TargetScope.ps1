[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$package = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$repository = [IO.Path]::GetFullPath((Join-Path $package '../../..'))
$adapter = Join-Path $package 'modules/architecture-conformance/adapter.ps1'
$case = Join-Path $repository ('artifacts/guards/v4/target-scope/' + [Guid]::NewGuid().ToString('N'))
$target = Join-Path $case 'target'
$source = Join-Path $target 'src'
$tests = Join-Path $target 'tests'
$guard = Join-Path $target 'docs/guards'
foreach ($path in @($source,$tests,$guard)) { [void][IO.Directory]::CreateDirectory($path) }
function Write-Text([string] $Path, [string] $Value) {
    [IO.File]::WriteAllText($Path,$Value,[Text.UTF8Encoding]::new($false))
}
function Hash-Tree([string] $Root) {
    $rows = @(Get-ChildItem -LiteralPath $Root -Recurse -File | ForEach-Object {
        "$([IO.Path]::GetRelativePath($Root,$_.FullName).Replace('\','/')):$((Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName).Hash.ToLowerInvariant())"
    })
    [array]::Sort($rows,[StringComparer]::Ordinal)
    return ($rows -join "`n")
}
function Invoke-Adapter([string[]] $Roots) {
    $inputJson = [ordered]@{
        formatVersion=1;stage='pre';targetRoot=$target;packageRoot=$package;relativeRoots=$Roots
        config=[ordered]@{enabledClaims=@('ARCH.GRAPH_COMPLETENESS');requireResolvedProjectReferences=$true}
    } | ConvertTo-Json -Depth 20 -Compress
    $previous = $env:V4_STAGE_INPUT_JSON
    try {
        $env:V4_STAGE_INPUT_JSON = $inputJson
        $output = @(& pwsh -NoLogo -NoProfile -NonInteractive -File $adapter 2>&1)
        if ($LASTEXITCODE -ne 0) { throw "Adapter process failed: $($output -join "`n")" }
    } finally { $env:V4_STAGE_INPUT_JSON = $previous }
    $json = $output -join "`n"
    if (-not (Test-Json -Json $json -SchemaFile (Join-Path $package 'modules/architecture-conformance/result.schema.json'))) {
        throw "Adapter result violates schema: $json"
    }
    return $json | ConvertFrom-Json
}
function Assert-Category($Result,[string] $Category,[string] $Name) {
    if ($Result.exitCategory -cne $Category) { throw "$Name expected $Category, got $($Result.exitCategory)" }
}

Write-Text (Join-Path $source 'App.csproj') '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFramework>net10.0</TargetFramework></PropertyGroup></Project>'
Write-Text (Join-Path $guard 'Guard.csproj') '<Project Sdk="Microsoft.NET.Sdk"><ItemGroup><ProjectReference Include="Missing.csproj" /></ItemGroup></Project>'
$before = Hash-Tree $target
$scoped = Invoke-Adapter @('src','tests')
Assert-Category $scoped 'success' 'IFX scope'
if (@($scoped.coverage | Where-Object { $_.claimId -ceq 'ARCH.GRAPH_COMPLETENESS' -and $_.matched -eq 1 }).Count -ne 1 -or @($scoped.findings).Count -ne 0) {
    throw 'IFX scope did not exclude the guard project or preserve nonzero coverage.'
}
$guardOnly = Invoke-Adapter @('docs/guards')
Assert-Category $guardOnly 'findings-blocking' 'guard-only scope'
if (@($guardOnly.findings | Where-Object ruleId -CEQ 'ARCH.GRAPH_COMPLETENESS').Count -ne 1) { throw 'Guard-only scope did not detect its missing reference.' }

Write-Text (Join-Path $source 'App.csproj') '<Project Sdk="Microsoft.NET.Sdk"><ItemGroup><ProjectReference Include="../docs/guards/Guard.csproj" /></ItemGroup></Project>'
$outside = Invoke-Adapter @('src')
Assert-Category $outside 'findings-blocking' 'out-of-scope reference'
if (@($outside.findings | Where-Object ruleId -CEQ 'ARCH.GRAPH_COMPLETENESS').Count -ne 1) { throw 'Out-of-scope project reference was accepted.' }
Write-Text (Join-Path $source 'App.csproj') '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFramework>net10.0</TargetFramework></PropertyGroup></Project>'

foreach ($entry in @(
    @{ Name='missing'; Roots=@('absent') },
    @{ Name='traversal'; Roots=@('../src') },
    @{ Name='absolute'; Roots=@($source) },
    @{ Name='overlap'; Roots=@('src','src/nested') },
    @{ Name='case-collision'; Roots=@('src','SRC') }
)) {
    if ($entry.Name -eq 'overlap') { [void][IO.Directory]::CreateDirectory((Join-Path $source 'nested')) }
    Assert-Category (Invoke-Adapter $entry.Roots) 'unsafe-path' $entry.Name
}
$link = Join-Path $target 'linked-src'
try {
    $null = New-Item -ItemType SymbolicLink -Path $link -Target $source -ErrorAction Stop
    Assert-Category (Invoke-Adapter @('linked-src')) 'unsafe-path' 'linked root'
} catch {
    if (Test-Path -LiteralPath $link) { throw }
}
if ((Hash-Tree $target) -cne $before) {
    # The temporary App.csproj mutation above was restored byte-for-byte; the optional link
    # and nested empty directory do not enter the file-hash inventory.
    throw 'Scoped detector changed TargetRoot files.'
}

$copy = Join-Path $case 'package'
Copy-Item -LiteralPath $package -Destination $copy -Recurse
$profilePath = Join-Path $copy 'profiles/catalog/synthetic_profile/profile.json'
$profile = Get-Content -Raw -LiteralPath $profilePath | ConvertFrom-Json -AsHashtable
$profile.projectIdentity.relativeRoots = @('src','tests')
$selection = @($profile.moduleSelections | Where-Object id -CEQ 'architecture-conformance')[0]
$selection.config.enabledClaims = @('ARCH.GRAPH_COMPLETENESS')
$profile.rules = @('ARCH.GRAPH_COMPLETENESS')
$profile.stageConfiguration.pre.modules = @('architecture-conformance')
Write-Text $profilePath (($profile | ConvertTo-Json -Depth 50) + "`n")
$buildRoot = Join-Path $package 'build'
$hostProject = Join-Path $package 'core/host/V4.Guards.Host/V4.Guards.Host.csproj'
$artifacts = Join-Path $case 'build'
$props = @('-p:ImportDirectoryBuildProps=false','-p:ImportDirectoryBuildTargets=false',
    '-p:ImportDirectoryPackagesProps=false','-p:ImportDirectorySolutionProps=false',
    '-p:ImportDirectorySolutionTargets=false',"-p:CustomBeforeMicrosoftCommonProps=$(Join-Path $buildRoot 'V4.Build.props')")
Push-Location $buildRoot
try {
    & dotnet restore $hostProject --configfile (Join-Path $buildRoot 'NuGet.config') --artifacts-path $artifacts -nologo @props
    if ($LASTEXITCODE -ne 0) { throw 'Target-scope Host restore failed.' }
    & dotnet build $hostProject --no-restore --artifacts-path $artifacts -nologo @props
    if ($LASTEXITCODE -ne 0) { throw 'Target-scope Host build failed.' }
} finally { Pop-Location }
$state = Join-Path $case 'state'
$evidence = Join-Path $case 'evidence'
foreach ($path in @($state,$evidence)) { [void][IO.Directory]::CreateDirectory($path) }
$hostDll = Join-Path $artifacts 'bin/V4.Guards.Host/debug/v4-guards.dll'
$hostOutput = @(& dotnet $hostDll stage run --stage pre --package-root $copy --target-root $target --state-root $state --evidence-root $evidence --profile synthetic_profile 2>&1)
if ($LASTEXITCODE -ne 0) { throw "Scoped Host run failed: $($hostOutput -join "`n")" }
$hostResult = ($hostOutput -join "`n") | ConvertFrom-Json
Assert-Category $hostResult 'success' 'Host propagation'
if (@($hostResult.coverage | Where-Object { $_.claimId -ceq 'ARCH.GRAPH_COMPLETENESS' -and $_.matched -eq 1 }).Count -ne 1) {
    throw 'Host did not propagate the Profile relative roots.'
}
Write-Host 'V4 target-scope tests passed: scoped scan, guard exclusion, out-of-scope reference, unsafe roots and Host propagation.'
