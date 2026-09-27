[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$packageRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $packageRoot '../../..'))
$adapter = Join-Path $packageRoot 'modules/architecture-conformance/adapter.ps1'
$schema = Join-Path $packageRoot 'modules/architecture-conformance/result.schema.json'
$runRoot = Join-Path $repositoryRoot 'artifacts/guards/v4/p4d'
$failures = [Collections.Generic.List[string]]::new()

function Hash-Tree([string] $Root) {
    $items=[ordered]@{}
    Get-ChildItem -LiteralPath $Root -Recurse -File | Sort-Object FullName | ForEach-Object {
        $items[[IO.Path]::GetRelativePath($Root,$_.FullName).Replace('\','/')] = (Get-FileHash -Algorithm SHA256 $_.FullName).Hash.ToLowerInvariant()
    }
    return ($items | ConvertTo-Json -Compress)
}
function Write-Utf8([string] $Path, [string] $Content) {
    $parent=[IO.Path]::GetDirectoryName($Path); if(-not [IO.Directory]::Exists($parent)){[void][IO.Directory]::CreateDirectory($parent)}
    [IO.File]::WriteAllText($Path,$Content,[Text.UTF8Encoding]::new($false))
}
function New-CompiledFixture([string] $Name, [switch] $Violating) {
    $root=Join-Path $runRoot $Name; $source=Join-Path $root 'source'; $evidence=Join-Path $root 'evidence'; $assemblies=Join-Path $evidence 'assemblies'; $target=Join-Path $root 'target'
    foreach($path in @($source,$assemblies,$target)){[void][IO.Directory]::CreateDirectory($path)}
    Write-Utf8 (Join-Path $target 'input.txt') "synthetic-ok`n"
    $contracts=Join-Path $source 'Contracts'; $application=Join-Path $source 'Application'
    Write-Utf8 (Join-Path $contracts 'Synthetic.Contracts.csproj') '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFramework>net10.0</TargetFramework><AssemblyName>Synthetic.Contracts</AssemblyName><RootNamespace>Synthetic.Contracts</RootNamespace></PropertyGroup></Project>'
    Write-Utf8 (Join-Path $contracts 'Contracts.cs') 'namespace Synthetic.Contracts { public interface IPort { } } namespace Synthetic.Forbidden { public sealed class ForbiddenType { } }'
    Write-Utf8 (Join-Path $application 'Synthetic.Application.csproj') '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFramework>net10.0</TargetFramework><AssemblyName>Synthetic.Application</AssemblyName><RootNamespace>Synthetic.Application</RootNamespace></PropertyGroup><ItemGroup><ProjectReference Include="../Contracts/Synthetic.Contracts.csproj" /></ItemGroup></Project>'
    $appSource = if($Violating){'namespace Synthetic.Application.Wrong { public sealed class Port : Synthetic.Contracts.IPort { public Synthetic.Forbidden.ForbiddenType Value { get; } = new(); } }'}else{'namespace Synthetic.Application.Allowed { public sealed class Port : Synthetic.Contracts.IPort { } }'}
    Write-Utf8 (Join-Path $application 'Application.cs') $appSource
    $props=@('-p:ImportDirectoryBuildProps=false','-p:ImportDirectoryBuildTargets=false','-p:ImportDirectoryPackagesProps=false','-p:ImportDirectorySolutionProps=false','-p:ImportDirectorySolutionTargets=false')
    & dotnet restore (Join-Path $application 'Synthetic.Application.csproj') --configfile (Join-Path $packageRoot 'build/NuGet.config') -nologo @props | Out-Host
    if($LASTEXITCODE){throw "$Name fixture restore failed"}
    & dotnet build (Join-Path $application 'Synthetic.Application.csproj') --no-restore -c Debug -o $assemblies -nologo @props | Out-Host
    if($LASTEXITCODE){throw "$Name fixture build failed"}
    $manifest=[ordered]@{formatVersion=1;assemblies=@()}
    foreach($assemblyName in @('Synthetic.Contracts','Synthetic.Application')){
        $path=Join-Path $assemblies "$assemblyName.dll"
        $manifest.assemblies += [ordered]@{assemblyName=$assemblyName;path="assemblies/$assemblyName.dll";sha256=(Get-FileHash -Algorithm SHA256 $path).Hash.ToLowerInvariant()}
    }
    Write-Utf8 (Join-Path $evidence 'assembly-manifest.json') ($manifest|ConvertTo-Json -Depth 10)
    [pscustomobject]@{Root=$root;Target=$target;Evidence=$evidence;Manifest=$manifest;SourceNamespace=$(if($Violating){'Synthetic.Application.Wrong'}else{'Synthetic.Application.Allowed'})}
}
function Configuration($Fixture,[string[]]$Claims,[switch]$ZeroMatch){
    $sourceNamespace=if($ZeroMatch){'Synthetic.Application.Absent'}else{$Fixture.SourceNamespace}
    [ordered]@{
        enabledClaims=$Claims
        assemblyManifestPath='assembly-manifest.json'
        forbiddenTypeDependencies=@([ordered]@{sourceAssembly='Synthetic.Application';sourceNamespace=$sourceNamespace;forbiddenAssembly='Synthetic.Contracts';forbiddenNamespace='Synthetic.Forbidden';minimumMatches=1})
        implementationLocations=@([ordered]@{interfaceAssembly='Synthetic.Contracts';interfaceType='Synthetic.Contracts.IPort';implementationAssembly='Synthetic.Application';implementationNamespace='Synthetic.Application.Allowed';minimumMatches=1})
        assemblyPlacements=@([ordered]@{assemblyName='Synthetic.Application';requiredNamespace='Synthetic.Application.Allowed';minimumMatches=1})
    }
}
function Invoke-Adapter($Fixture,$Config,[string]$NuGetPackages=''){
    $before=Hash-Tree $Fixture.Target
    $inputJson=[ordered]@{formatVersion=1;stage='post';targetRoot=$Fixture.Target;packageRoot=$packageRoot;evidenceRoot=$Fixture.Evidence;config=$Config}|ConvertTo-Json -Depth 20 -Compress
    $priorInput=$env:V4_STAGE_INPUT_JSON; $priorPackages=$env:NUGET_PACKAGES
    try{
        $env:V4_STAGE_INPUT_JSON=$inputJson
        if(-not [string]::IsNullOrWhiteSpace($NuGetPackages)){$env:NUGET_PACKAGES=$NuGetPackages}
        $output=@(& pwsh -NoProfile -File $adapter 2>&1)
        $code=$LASTEXITCODE
    }finally{$env:V4_STAGE_INPUT_JSON=$priorInput;$env:NUGET_PACKAGES=$priorPackages}
    if($code -ne 0){throw "Adapter process failed ($code): $($output-join"`n")"}
    $json=$output-join"`n"
    if(-not(Test-Json -Json $json -SchemaFile $schema -ErrorAction SilentlyContinue)){$failures.Add('adapter output violates result schema')}
    if((Hash-Tree $Fixture.Target)-cne$before){$failures.Add('adapter mutated TargetRoot')}
    if((Test-Path(Join-Path $Fixture.Target 'bin'))-or(Test-Path(Join-Path $Fixture.Target 'obj'))){$failures.Add('adapter created target build outputs')}
    $json|ConvertFrom-Json
}
function Assert-Category($Result,[string]$Name,[string]$Category){if($Result.exitCategory-cne$Category){$failures.Add("${Name}: expected $Category, got $($Result.exitCategory)")}}

if(Test-Path $runRoot){
    $resolved=[IO.Path]::GetFullPath($runRoot);$prefix=[IO.Path]::GetFullPath((Join-Path $repositoryRoot 'artifacts/guards/v4')).TrimEnd([IO.Path]::DirectorySeparatorChar)+[IO.Path]::DirectorySeparatorChar
    if(-not$resolved.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)){throw "Unsafe cleanup path: $resolved"}
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
[void][IO.Directory]::CreateDirectory($runRoot)
$claims=@('ARCH.TYPE_DEPENDENCY','ARCH.IMPLEMENTATION_LOCATION','ARCH.ASSEMBLY_PLACEMENT')

$clean=New-CompiledFixture 'clean'
$cleanResult=Invoke-Adapter $clean (Configuration $clean $claims)
Assert-Category $cleanResult 'clean' 'success'
foreach($claim in $claims){$entry=@($cleanResult.coverage|Where-Object claimId -ceq $claim);if($entry.Count-ne1-or$entry[0].matched-lt1){$failures.Add("clean: non-zero coverage missing for $claim")}}

$bad=New-CompiledFixture 'violating' -Violating
$badResult=Invoke-Adapter $bad (Configuration $bad $claims)
Assert-Category $badResult 'violating' 'findings-blocking'
foreach($claim in $claims){if(@($badResult.findings.ruleId)-notcontains$claim){$failures.Add("violating: finding missing for $claim")}}
if(@($badResult.findings|Where-Object{$_.detectorId-cne'archunitnet'-or$_.evidenceKind-cne'compiled-assembly'}).Count){$failures.Add('violating: finding lost ArchUnitNET evidence identity')}

$zeroResult=Invoke-Adapter $clean (Configuration $clean @('ARCH.TYPE_DEPENDENCY') -ZeroMatch)
Assert-Category $zeroResult 'zero-match' 'findings-blocking'
if(@($zeroResult.coverage|Where-Object{$_.claimId-ceq'ARCH.TYPE_DEPENDENCY'-and$_.matched-eq0}).Count-ne1){$failures.Add('zero-match: coverage did not fail closed at zero')}

$missingRoot=Join-Path $runRoot 'missing';$missingEvidence=Join-Path $missingRoot 'evidence';$missingTarget=Join-Path $missingRoot 'target';[void][IO.Directory]::CreateDirectory($missingEvidence);[void][IO.Directory]::CreateDirectory($missingTarget);Write-Utf8(Join-Path $missingTarget 'input.txt')"ok`n";Write-Utf8(Join-Path $missingEvidence 'assembly-manifest.json')(@{formatVersion=1;assemblies=@(@{assemblyName='Synthetic.Contracts';path='assemblies/missing.dll';sha256=('0'*64)})}|ConvertTo-Json -Depth 10)
$missing=[pscustomobject]@{Target=$missingTarget;Evidence=$missingEvidence;SourceNamespace='Synthetic.Application.Allowed'}
Assert-Category (Invoke-Adapter $missing (Configuration $missing $claims)) 'missing assembly' 'prerequisite-missing'

$driftRoot=Join-Path $runRoot 'hash-drift';Copy-Item -LiteralPath $clean.Root -Destination $driftRoot -Recurse;$drift=[pscustomobject]@{Root=$driftRoot;Target=(Join-Path $driftRoot 'target');Evidence=(Join-Path $driftRoot 'evidence');SourceNamespace=$clean.SourceNamespace};$driftManifest=Get-Content -Raw(Join-Path $drift.Evidence 'assembly-manifest.json')|ConvertFrom-Json;$driftManifest.assemblies[0].sha256='0'*64;Write-Utf8(Join-Path $drift.Evidence 'assembly-manifest.json')($driftManifest|ConvertTo-Json -Depth 10)
Assert-Category (Invoke-Adapter $drift (Configuration $drift $claims)) 'hash drift' 'integrity-failure'

$emptyPackages=Join-Path $runRoot 'empty-packages';[void][IO.Directory]::CreateDirectory($emptyPackages)
Assert-Category (Invoke-Adapter $clean (Configuration $clean $claims) $emptyPackages) 'missing ArchUnitNET dependency' 'prerequisite-missing'

if($failures.Count){throw($failures-join"`n")}
Write-Host 'V4 P4D ArchUnitNET adapter tests passed: clean/violating compiled claims, zero-match, missing dependency/assembly, hash drift and zero target execution.'
