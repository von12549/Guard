[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'

$packageRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$repositoryRoot=[IO.Path]::GetFullPath((Join-Path $packageRoot '../../..'))
$runRoot=Join-Path $repositoryRoot 'artifacts/guards/v4/p4e'
$provider=Join-Path $packageRoot 'modules/build-evidence-provider/adapter.ps1'
$architecture=Join-Path $packageRoot 'modules/architecture-conformance/adapter.ps1'
$providerSchema=Join-Path $packageRoot 'modules/build-evidence-provider/result.schema.json'
$manifestSchema=Join-Path $packageRoot 'modules/build-evidence-provider/build-manifest.schema.json'
$architectureSchema=Join-Path $packageRoot 'modules/architecture-conformance/result.schema.json'
$failures=[Collections.Generic.List[string]]::new()

function Write-Utf8([string]$Path,[string]$Content){$parent=[IO.Path]::GetDirectoryName($Path);if(-not[IO.Directory]::Exists($parent)){[void][IO.Directory]::CreateDirectory($parent)};[IO.File]::WriteAllText($Path,$Content,[Text.UTF8Encoding]::new($false))}
function Hash-Tree([string]$Root){$items=[ordered]@{};Get-ChildItem -LiteralPath $Root -Recurse -File -Force|Sort-Object FullName|ForEach-Object{$items[[IO.Path]::GetRelativePath($Root,$_.FullName).Replace('\','/')]=(Get-FileHash -Algorithm SHA256 $_.FullName).Hash.ToLowerInvariant()};$items|ConvertTo-Json -Compress}
function Copy-Map($Map){$copy=[ordered]@{};foreach($entry in $Map.GetEnumerator()){$copy[$entry.Key]=$entry.Value};$copy}
function Invoke-Module([string]$Adapter,$Payload,[string]$Schema){$prior=$env:V4_STAGE_INPUT_JSON;try{$env:V4_STAGE_INPUT_JSON=($Payload|ConvertTo-Json -Depth 30 -Compress);$output=@(& pwsh -NoProfile -File $Adapter 2>&1);$code=$LASTEXITCODE}finally{$env:V4_STAGE_INPUT_JSON=$prior};if($code-ne0){throw "Adapter failed ($code): $($output-join"`n")"};$json=$output-join"`n";if(-not(Test-Json -Json $json -SchemaFile $Schema -ErrorAction SilentlyContinue)){$failures.Add("Schema failure: $Adapter -> $json")};$json|ConvertFrom-Json}
function Assert-Category($Result,[string]$Name,[string]$Category){if($Result.exitCategory-cne$Category){$failures.Add("${Name}: expected $Category, got $($Result.exitCategory): $($Result.message)")}}

if(Test-Path $runRoot){$resolved=[IO.Path]::GetFullPath($runRoot);$prefix=[IO.Path]::GetFullPath((Join-Path $repositoryRoot 'artifacts/guards/v4')).TrimEnd([IO.Path]::DirectorySeparatorChar)+[IO.Path]::DirectorySeparatorChar;if(-not$resolved.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)){throw "Unsafe cleanup: $resolved"};Remove-Item -LiteralPath $resolved -Recurse -Force}
$target=Join-Path $runRoot 'target';$state=Join-Path $runRoot 'state';$evidence=Join-Path $runRoot 'evidence';foreach($path in @($target,$state,$evidence)){[void][IO.Directory]::CreateDirectory($path)}
Write-Utf8(Join-Path $target 'input.txt')"synthetic-ok`n"
Write-Utf8(Join-Path $target 'Contracts/Synthetic.Contracts.csproj')'<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFramework>net10.0</TargetFramework><AssemblyName>Synthetic.Contracts</AssemblyName></PropertyGroup></Project>'
Write-Utf8(Join-Path $target 'Contracts/Contracts.cs')'namespace Synthetic.Contracts { public interface IPort { } } namespace Synthetic.Forbidden { public sealed class ForbiddenType { } }'
Write-Utf8(Join-Path $target 'Application/Synthetic.Application.csproj')'<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFramework>net10.0</TargetFramework><AssemblyName>Synthetic.Application</AssemblyName></PropertyGroup><ItemGroup><ProjectReference Include="../Contracts/Synthetic.Contracts.csproj" /></ItemGroup></Project>'
Write-Utf8(Join-Path $target 'Application/Application.cs')'namespace Synthetic.Application.Allowed { public sealed class Port : Synthetic.Contracts.IPort { } }'
$targetBefore=Hash-Tree $target;$packageBefore=Hash-Tree $packageRoot
$projectId='synthetic-p4e';$runId='0123456789abcdef0123456789abcdef';$manifestTemplate='projects/{projectId}/build/current/assembly-manifest.json'
$providerConfig=[ordered]@{configuration='Debug';targetFramework='net10.0';manifestPath=$manifestTemplate;projects=@([ordered]@{projectPath='Contracts/Synthetic.Contracts.csproj';assemblyName='Synthetic.Contracts'},[ordered]@{projectPath='Application/Synthetic.Application.csproj';assemblyName='Synthetic.Application'})}
$baseInput=[ordered]@{formatVersion=1;stage='post';targetRoot=$target;packageRoot=$packageRoot;stateRoot=$state;evidenceRoot=$evidence;projectId=$projectId;runId=$runId}
$providerInput=Copy-Map $baseInput;$providerInput.config=$providerConfig
$providerResult=Invoke-Module $provider $providerInput $providerSchema;Assert-Category $providerResult 'provider clean' 'success'
if($providerResult.exitCategory-cne'success'){throw "provider clean failed: $($providerResult|ConvertTo-Json -Depth 20 -Compress)"}
if((Hash-Tree $target)-cne$targetBefore){$failures.Add('provider changed TargetRoot')};if((Hash-Tree $packageRoot)-cne$packageBefore){$failures.Add('provider changed PackageRoot')};if((Test-Path(Join-Path $target 'bin'))-or(Test-Path(Join-Path $target 'obj'))){$failures.Add('provider created target build outputs')}
$manifestPath=Join-Path $evidence "projects/$projectId/build/current/assembly-manifest.json";if(-not(Test-Json -LiteralPath $manifestPath -SchemaFile $manifestSchema -ErrorAction SilentlyContinue)){$failures.Add('build manifest violates schema')}
$manifest=Get-Content -Raw $manifestPath|ConvertFrom-Json;if($manifest.runId-cne$runId-or$manifest.projectId-cne$projectId-or@($manifest.assemblies).Count-ne2){$failures.Add('build manifest lost run/project/assembly binding')}
foreach($entry in $manifest.assemblies){$path=Join-Path $state $entry.statePath;if(-not(Test-Path $path)-or(Get-FileHash -Algorithm SHA256 $path).Hash.ToLowerInvariant()-cne$entry.sha256){$failures.Add("state assembly binding failed: $($entry.assemblyName)")}}

$architectureConfig=[ordered]@{enabledClaims=@('ARCH.TYPE_DEPENDENCY','ARCH.IMPLEMENTATION_LOCATION','ARCH.ASSEMBLY_PLACEMENT');assemblyManifestPath=$manifestTemplate;requireFreshBuildEvidence=$true;maximumEvidenceAgeSeconds=600;expectedBuildConfiguration='Debug';expectedTargetFramework='net10.0';expectedAssemblySources=@([ordered]@{assemblyName='Synthetic.Contracts';sourceProject='Contracts/Synthetic.Contracts.csproj'},[ordered]@{assemblyName='Synthetic.Application';sourceProject='Application/Synthetic.Application.csproj'});forbiddenTypeDependencies=@([ordered]@{sourceAssembly='Synthetic.Application';sourceNamespace='Synthetic.Application.Allowed';forbiddenAssembly='Synthetic.Contracts';forbiddenNamespace='Synthetic.Forbidden';minimumMatches=1});implementationLocations=@([ordered]@{interfaceAssembly='Synthetic.Contracts';interfaceType='Synthetic.Contracts.IPort';implementationAssembly='Synthetic.Application';implementationNamespace='Synthetic.Application.Allowed';minimumMatches=1});assemblyPlacements=@([ordered]@{assemblyName='Synthetic.Application';requiredNamespace='Synthetic.Application.Allowed';minimumMatches=1})}
$architectureInput=Copy-Map $baseInput;$architectureInput.config=$architectureConfig
$architectureResult=Invoke-Module $architecture $architectureInput $architectureSchema;Assert-Category $architectureResult 'fresh architecture' 'success';foreach($claim in $architectureConfig.enabledClaims){if(@($architectureResult.coverage|Where-Object{$_.claimId-ceq$claim-and$_.matched-gt0}).Count-ne1){$failures.Add("fresh architecture lacks coverage: $claim")}}

$staleInput=Copy-Map $architectureInput;$staleInput.runId='ffffffffffffffffffffffffffffffff';Assert-Category (Invoke-Module $architecture $staleInput $architectureSchema) 'stale run' 'integrity-failure'
$driftFile=Join-Path $target 'drift.txt';Write-Utf8 $driftFile 'changed';Assert-Category (Invoke-Module $architecture $architectureInput $architectureSchema) 'target drift' 'integrity-failure';Remove-Item -LiteralPath $driftFile
$applicationEntry=@($manifest.assemblies|Where-Object assemblyName -ceq 'Synthetic.Application')[0];$applicationPath=Join-Path $state $applicationEntry.statePath;$original=[IO.File]::ReadAllBytes($applicationPath);[IO.File]::WriteAllBytes($applicationPath,($original+0));Assert-Category (Invoke-Module $architecture $architectureInput $architectureSchema) 'assembly drift' 'integrity-failure';[IO.File]::WriteAllBytes($applicationPath,$original)

$missingInput=Copy-Map $baseInput;$missingInput.runId='11111111111111111111111111111111';$missingConfig=[ordered]@{configuration='Debug';targetFramework='net10.0';manifestPath=$manifestTemplate;projects=@([ordered]@{projectPath='Missing.csproj';assemblyName='Missing'})};$missingInput.config=$missingConfig;Assert-Category (Invoke-Module $provider $missingInput $providerSchema) 'missing project' 'prerequisite-missing'

$external=Join-Path $runRoot 'external-link-target';[void][IO.Directory]::CreateDirectory($external);Write-Utf8(Join-Path $external 'escape.cs')'namespace Escape; public class Bad {}';$link=Join-Path $target 'linked';try{New-Item -ItemType Junction -Path $link -Target $external -Force|Out-Null;$linkInput=Copy-Map $baseInput;$linkInput.runId='22222222222222222222222222222222';$linkInput.config=$providerConfig;Assert-Category (Invoke-Module $provider $linkInput $providerSchema) 'link traversal' 'unsafe-path'}finally{if(Test-Path $link){Remove-Item -LiteralPath $link -Force}}

if($failures.Count){throw($failures-join"`n")}
Write-Host 'V4 P4E Build Evidence tests passed: isolated build, schema/freshness bindings, stale/target/assembly drift, missing project, link refusal and immutable TargetRoot/PackageRoot.'
