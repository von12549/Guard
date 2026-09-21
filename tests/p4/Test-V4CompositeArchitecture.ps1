[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'

$packageRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$repositoryRoot=[IO.Path]::GetFullPath((Join-Path $packageRoot '../../..'))
$runRoot=Join-Path $repositoryRoot 'artifacts/guards/v4/p4f'
$buildRoot=Join-Path $packageRoot 'build'
$project=Join-Path $packageRoot 'core/host/V4.Guards.Host/V4.Guards.Host.csproj'
$dll=Join-Path $runRoot 'bin/V4.Guards.Host/debug/v4-guards.dll'
$schema=Join-Path $packageRoot 'core/contracts/stage-result.schema.json'
$adapter=Join-Path $packageRoot 'modules/architecture-conformance/adapter.ps1'
$adapterSchema=Join-Path $packageRoot 'modules/architecture-conformance/result.schema.json'
$allClaims=@('ARCH.PROJECT_REFERENCE','ARCH.PACKAGE_REFERENCE','ARCH.TARGET_FRAMEWORK','ARCH.GRAPH_COMPLETENESS','ARCH.SOURCE_IMPORT','ARCH.DISABLED_BRANCH','ARCH.DECLARATION_PLACEMENT','ARCH.FORBIDDEN_SYMBOL','ARCH.MEMBER_PAYLOAD','ARCH.TYPE_DEPENDENCY','ARCH.IMPLEMENTATION_LOCATION','ARCH.ASSEMBLY_PLACEMENT')
$preClaims=@($allClaims[0..6]);$postClaims=@($allClaims[7..11])
$failures=[Collections.Generic.List[string]]::new()

function Write-Utf8([string]$Path,[string]$Content){$parent=[IO.Path]::GetDirectoryName($Path);if(-not[IO.Directory]::Exists($parent)){[void][IO.Directory]::CreateDirectory($parent)};[IO.File]::WriteAllText($Path,$Content,[Text.UTF8Encoding]::new($false))}
function Write-Json([string]$Path,$Value){Write-Utf8 $Path (($Value|ConvertTo-Json -Depth 100)+"`n")}
function Read-Json([string]$Path){Get-Content -Raw -LiteralPath $Path|ConvertFrom-Json -AsHashtable -Depth 100}
function Hash([string]$Path){(Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()}
function New-Roots([string]$Name,[ValidateSet('clean','pre-violating','post-violating','zero')]$Kind='clean',[string]$Package=$packageRoot){
    $root=Join-Path $runRoot "cases/$Name";$target=Join-Path $root 'target';$state=Join-Path $root 'state';$evidence=Join-Path $root 'evidence'
    foreach($path in @($target,$state,$evidence)){[void][IO.Directory]::CreateDirectory($path)}
    Write-Utf8(Join-Path $target 'input.txt')"synthetic-ok`n"
    $contracts='<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFramework>net10.0</TargetFramework><AssemblyName>Synthetic.Contracts</AssemblyName></PropertyGroup></Project>'
    $application='<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFramework>net10.0</TargetFramework><AssemblyName>Synthetic.Application</AssemblyName></PropertyGroup><ItemGroup><ProjectReference Include="../Contracts/Synthetic.Contracts.csproj" /></ItemGroup></Project>'
    $contractSource='namespace Synthetic.Contracts { public interface IPort { } } namespace Synthetic.ForbiddenTypes { public sealed class ForbiddenType { } } namespace Synthetic.ForbiddenApi { public static class Calls { public static void Use() { } } } namespace Synthetic.ForbiddenPayload { public sealed class Payload { } } namespace Synthetic.ForbiddenImport { public sealed class Marker { } }'
    $applicationSource='namespace Synthetic.Application.Allowed { public sealed class Port : Synthetic.Contracts.IPort { } }'
    if($Kind-eq'pre-violating'){
        $application='<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFramework>net9.0</TargetFramework><AssemblyName>Synthetic.Application</AssemblyName></PropertyGroup><ItemGroup><ProjectReference Include="../Forbidden/Forbidden.csproj" /><PackageReference Include="Forbidden.Package" Version="1.0.0" /></ItemGroup></Project>'
        $applicationSource="using Synthetic.ForbiddenImport;`n#if NEVER`ninternal sealed class Disabled { }`n#endif`nnamespace Synthetic.ForbiddenPlacement { public sealed class Misplaced { } }"
    }elseif($Kind-eq'post-violating'){
        $applicationSource='namespace Synthetic.Application.Wrong { public sealed class WrongPort : Synthetic.Contracts.IPort { } } namespace Synthetic.Application.Allowed { public sealed class Bad { private readonly Synthetic.ForbiddenTypes.ForbiddenType value = new(); public Synthetic.ForbiddenPayload.Payload Leak() => new(); public void Call() => Synthetic.ForbiddenApi.Calls.Use(); } }'
    }elseif($Kind-eq'zero'){
        $contractSource='namespace Synthetic.Contracts { public interface IPort { } } namespace Synthetic.ForbiddenApi { public static class Calls { public static void Use() { } } } namespace Synthetic.ForbiddenPayload { public sealed class Payload { } } namespace Synthetic.ForbiddenImport { public sealed class Marker { } }'
    }
    Write-Utf8(Join-Path $target 'Contracts/Synthetic.Contracts.csproj')$contracts;Write-Utf8(Join-Path $target 'Contracts/Contracts.cs')$contractSource
    Write-Utf8(Join-Path $target 'Application/Synthetic.Application.csproj')$application;Write-Utf8(Join-Path $target 'Application/Application.cs')$applicationSource
    [pscustomobject]@{Root=$root;Target=$target;State=$state;Evidence=$evidence;Package=$Package}
}
function New-Package([string]$Name){$root=Join-Path $runRoot "packages/$Name";Copy-Item -LiteralPath $packageRoot -Destination $root -Recurse -Force;return $root}
function Update-Module([string]$Package,[string]$ModuleId,[switch]$Adapter){
    $modulePath=Join-Path $Package "modules/$ModuleId/module.json";$module=Read-Json $modulePath
    if($Adapter){$module.adapter.sha256=Hash(Join-Path $Package $module.adapter.path)}
    Write-Json $modulePath $module
    $registryPath=Join-Path $Package 'modules/registry.json';$registry=Read-Json $registryPath;$entry=@($registry.modules|Where-Object{$_.id-ceq$ModuleId})[0];$entry.manifestSha256=Hash $modulePath;Write-Json $registryPath $registry
}
function Invoke-Stage($Roots,[string]$Stage,[string]$Package=$Roots.Package,[string]$PathOverride=''){
    $prior=$env:PATH;if($PathOverride){$env:PATH=$PathOverride}
    try{$output=@(& dotnet $dll stage run --stage $Stage --package-root $Package --target-root $Roots.Target --state-root $Roots.State --evidence-root $Roots.Evidence --profile synthetic_profile 2>&1);$code=$LASTEXITCODE}
    finally{$env:PATH=$prior}
    $text=$output-join"`n";try{$document=$text|ConvertFrom-Json}catch{$document=$null}
    if($null-ne$document){$resultPath=Join-Path $Roots.Evidence "projects/$((Get-Content -Raw (Join-Path $Roots.State 'state.json')|ConvertFrom-Json).projectInstances[0].id)/runs/$($document.runId)/stage-result.json";if(-not(Test-Json -LiteralPath $resultPath -SchemaFile $schema -ErrorAction SilentlyContinue)){$failures.Add("$Stage result violates schema: $text")}}
    [pscustomobject]@{Code=$code;Text=$text;Document=$document}
}
function Expect($Run,[string]$Name,[int]$Code,[string]$Category){if($Run.Code-ne$Code-or$null-eq$Run.Document-or$Run.Document.exitCategory-cne$Category){$failures.Add("${Name}: expected $Code/$Category, got $($Run.Code)/$($Run.Document.exitCategory): $($Run.Text)")}}
function Assert-Claims($Result,[string[]]$Claims,[switch]$Findings){foreach($claim in $Claims){if(@($Result.coverage|Where-Object{$_.claimId-ceq$claim}).Count-ne1){$failures.Add("coverage identity missing: $claim")};if($Findings-and@($Result.findings|Where-Object{$_.ruleId-ceq$claim}).Count-lt1){$failures.Add("violating finding missing: $claim")}}}
function Invoke-Adapter($Payload){$prior=$env:V4_STAGE_INPUT_JSON;try{$env:V4_STAGE_INPUT_JSON=$Payload|ConvertTo-Json -Depth 100 -Compress;$json=& pwsh -NoProfile -File $adapter;$code=$LASTEXITCODE}finally{$env:V4_STAGE_INPUT_JSON=$prior};if($code-ne0-or-not(Test-Json -Json $json -SchemaFile $adapterSchema -ErrorAction SilentlyContinue)){throw "Direct adapter result invalid: $json"};$json|ConvertFrom-Json}

if(Test-Path $runRoot){$resolved=[IO.Path]::GetFullPath($runRoot);$prefix=[IO.Path]::GetFullPath((Join-Path $repositoryRoot 'artifacts/guards/v4')).TrimEnd([IO.Path]::DirectorySeparatorChar)+[IO.Path]::DirectorySeparatorChar;if(-not$resolved.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)){throw "Unsafe cleanup: $resolved"};Remove-Item -LiteralPath $resolved -Recurse -Force}
[void][IO.Directory]::CreateDirectory($runRoot)
$properties=@('-p:ImportDirectoryBuildProps=false','-p:ImportDirectoryBuildTargets=false','-p:ImportDirectoryPackagesProps=false','-p:ImportDirectorySolutionProps=false','-p:ImportDirectorySolutionTargets=false',"-p:CustomBeforeMicrosoftCommonProps=$(Join-Path $buildRoot 'V4.Build.props')")
Push-Location $buildRoot;try{& dotnet restore $project --configfile (Join-Path $buildRoot 'NuGet.config') --artifacts-path $runRoot -nologo @properties;if($LASTEXITCODE){throw'P4F restore failed'};& dotnet build $project --no-restore --artifacts-path $runRoot -nologo @properties;if($LASTEXITCODE){throw'P4F build failed'}}finally{Pop-Location}

$clean=New-Roots 'clean';$cleanPre=Invoke-Stage $clean 'pre';Expect $cleanPre 'clean Pre' 0 'success';Assert-Claims $cleanPre.Document $preClaims
$cleanPost=Invoke-Stage $clean 'post';Expect $cleanPost 'clean Post' 0 'success';Assert-Claims $cleanPost.Document $postClaims
if((@($cleanPost.Document.moduleResults.moduleId)-join',')-cne'synthetic-probe,build-evidence-provider,architecture-conformance'){$failures.Add('clean Post module order is not explicit and composite')}

$preBad=New-Roots 'pre-violating' 'pre-violating';$badPre=Invoke-Stage $preBad 'pre';Expect $badPre 'violating Pre' 16 'findings-blocking';Assert-Claims $badPre.Document $preClaims -Findings
$postBad=New-Roots 'post-violating' 'post-violating';$badPost=Invoke-Stage $postBad 'post';Expect $badPost 'violating Post' 16 'findings-blocking';Assert-Claims $badPost.Document $postClaims -Findings

$baselinePackage=New-Package 'baseline';$baselinePath=Join-Path $baselinePackage 'profiles/catalog/synthetic_profile/baselines/none.json';$baselineFindings=@($badPre.Document.findings|ForEach-Object{[ordered]@{ruleId=$_.ruleId;subject=$_.subject;evidenceKind=$_.evidenceKind;detectorId=$_.detectorId}});Write-Json $baselinePath ([ordered]@{formatVersion=1;findings=$baselineFindings})
$baselineRoots=New-Roots 'baseline-advisory' 'pre-violating' $baselinePackage;$baselineRun=Invoke-Stage $baselineRoots 'pre' $baselinePackage;Expect $baselineRun 'baseline advisory' 0 'success';if($baselineRun.Document.status-cne'advisory'-or@($baselineRun.Document.findings|Where-Object{$_.severity-cne'advisory'}).Count-ne0){$failures.Add('host did not apply the exact layered baseline as advisory')}

$severityPackage=New-Package 'severity';$planPath=Join-Path $severityPackage 'modules/architecture-conformance/rule-execution-plan.json';$plan=Read-Json $planPath;foreach($rule in $plan.rules){if($rule.stage-ceq'pre'){$rule.severity='advisory'}};Write-Json $planPath $plan;$modulePath=Join-Path $severityPackage 'modules/architecture-conformance/module.json';$module=Read-Json $modulePath;@($module.authorities|Where-Object{$_.id-ceq'rule-execution-plan'})[0].sha256=Hash $planPath;Write-Json $modulePath $module;Update-Module $severityPackage 'architecture-conformance'
$severityRoots=New-Roots 'severity-advisory' 'pre-violating' $severityPackage;$severityRun=Invoke-Stage $severityRoots 'pre' $severityPackage;Expect $severityRun 'plan severity advisory' 0 'success';if($severityRun.Document.status-cne'advisory'-or@($severityRun.Document.findings|Where-Object{$_.severity-cne'advisory'}).Count-ne0){$failures.Add('host did not own severity from the rule execution plan')}

$zero=New-Roots 'zero-match' 'zero';$zeroRun=Invoke-Stage $zero 'post';Expect $zeroRun 'zero-match evidence' 16 'findings-blocking';if(@($zeroRun.Document.coverage|Where-Object{$_.claimId-ceq'ARCH.TYPE_DEPENDENCY'-and$_.matched-eq0}).Count-ne1){$failures.Add('zero-match evidence was not retained')}

$missingPackage=New-Package 'missing-evidence';$missingProfilePath=Join-Path $missingPackage 'profiles/catalog/synthetic_profile/profile.json';$missingProfile=Read-Json $missingProfilePath;$missingProfile.stageConfiguration.post.modules=@('synthetic-probe','architecture-conformance');Write-Json $missingProfilePath $missingProfile
$missingRoots=New-Roots 'missing-evidence' 'clean' $missingPackage;$missingRun=Invoke-Stage $missingRoots 'post' $missingPackage;Expect $missingRun 'missing evidence' 15 'prerequisite-missing'
$staleRoots=New-Roots 'stale-evidence' 'clean' $missingPackage;[void](Invoke-Stage $staleRoots 'analysis' $missingPackage);$projectId=(Get-Content -Raw (Join-Path $staleRoots.State 'state.json')|ConvertFrom-Json).projectInstances[0].id;$staleManifest=Join-Path $staleRoots.Evidence "projects/$projectId/build/current/assembly-manifest.json";Write-Json $staleManifest ([ordered]@{formatVersion=1;runId=('f'*32);projectId=$projectId;createdUtc=[DateTimeOffset]::UtcNow.ToString('O');configuration='Debug';targetFramework='net10.0';targetSnapshotSha256=('a'*64);assemblies=@([ordered]@{assemblyName='Synthetic.Contracts';sourceProject='Contracts/Synthetic.Contracts.csproj';configuration='Debug';targetFramework='net10.0';statePath='missing.dll';sha256=('b'*64)})});$staleRun=Invoke-Stage $staleRoots 'post' $missingPackage;Expect $staleRun 'stale evidence' 12 'integrity-failure'

$failurePackage=New-Package 'adapter-failure';$failureAdapter=Join-Path $failurePackage 'modules/synthetic-probe/adapter.ps1';Write-Utf8 $failureAdapter "[ordered]@{formatVersion=1;status='error';exitCategory='adapter-failure';message='synthetic adapter failure';findings=@();coverage=@()}|ConvertTo-Json -Compress`n";Update-Module $failurePackage 'synthetic-probe' -Adapter;$failureRoots=New-Roots 'adapter-failure' 'clean' $failurePackage;Expect (Invoke-Stage $failureRoots 'analysis' $failurePackage) 'adapter failure' 14 'adapter-failure'

$runtimePackage=New-Package 'missing-runtime';$runtimeModulePath=Join-Path $runtimePackage 'modules/synthetic-probe/module.json';$runtimeModule=Read-Json $runtimeModulePath;$runtimeModule.prerequisites=@([ordered]@{runtime='node';versionRange='>=1.0'});Write-Json $runtimeModulePath $runtimeModule;Update-Module $runtimePackage 'synthetic-probe';$runtimeRoots=New-Roots 'missing-runtime' 'clean' $runtimePackage;$limitedPath=@((Get-Command dotnet).Source,(Get-Command pwsh).Source|ForEach-Object{Split-Path -Parent $_})-join[IO.Path]::PathSeparator;Expect (Invoke-Stage $runtimeRoots 'analysis' $runtimePackage $limitedPath) 'missing runtime' 15 'prerequisite-missing'

$platformPackage=New-Package 'unsupported-platform';$platformModulePath=Join-Path $platformPackage 'modules/synthetic-probe/module.json';$platformModule=Read-Json $platformModulePath;$platformModule.supportedPlatforms=@($(if($IsWindows){'linux-x64'}else{'win-x64'}));Write-Json $platformModulePath $platformModule;Update-Module $platformPackage 'synthetic-probe';$platformRoots=New-Roots 'unsupported-platform' 'clean' $platformPackage;Expect (Invoke-Stage $platformRoots 'analysis' $platformPackage) 'unsupported platform' 15 'prerequisite-missing'

$profile=Read-Json(Join-Path $packageRoot 'profiles/catalog/synthetic_profile/profile.json');$architectureConfig=@($profile.moduleSelections|Where-Object{$_.id-ceq'architecture-conformance'})[0].config
$emptyTarget=Join-Path $runRoot 'cases/direct-missing/target';$emptyState=Join-Path $runRoot 'cases/direct-missing/state';$emptyEvidence=Join-Path $runRoot 'cases/direct-missing/evidence';foreach($path in @($emptyTarget,$emptyState,$emptyEvidence)){[void][IO.Directory]::CreateDirectory($path)}
$missingPre=Invoke-Adapter ([ordered]@{formatVersion=1;stage='pre';targetRoot=$emptyTarget;packageRoot=$packageRoot;stateRoot=$emptyState;evidenceRoot=$emptyEvidence;projectId='synthetic';runId=('a'*32);config=$architectureConfig});if($missingPre.exitCategory-cne'prerequisite-missing'){ $failures.Add('direct missing Pre was not structured')};Assert-Claims $missingPre $preClaims
$missingPost=Invoke-Adapter ([ordered]@{formatVersion=1;stage='post';targetRoot=$clean.Target;packageRoot=$packageRoot;stateRoot=$emptyState;evidenceRoot=$emptyEvidence;projectId='synthetic';runId=('a'*32);config=$architectureConfig});if($missingPost.exitCategory-cne'prerequisite-missing'){ $failures.Add('direct missing Post was not structured')};Assert-Claims $missingPost $postClaims

$inPlacePackage=New-Package 'in-place';$inPlaceProfilePath=Join-Path $inPlacePackage 'profiles/catalog/synthetic_profile/profile.json';$inPlaceProfile=Read-Json $inPlaceProfilePath;@($inPlaceProfile.moduleSelections|Where-Object{$_.id-ceq'architecture-conformance'})[0].config.enabledClaims=@('ARCH.TYPE_DEPENDENCY','ARCH.IMPLEMENTATION_LOCATION','ARCH.ASSEMBLY_PLACEMENT');Write-Json $inPlaceProfilePath $inPlaceProfile
$paritySeparatedRoots=New-Roots 'parity-separated' 'clean' $inPlacePackage;$paritySeparated=Invoke-Stage $paritySeparatedRoots 'post' $inPlacePackage;Expect $paritySeparated 'separated parity Post' 0 'success'
$inPlaceState=Join-Path $runRoot 'cases/in-place/state';$inPlaceEvidence=Join-Path $runRoot 'cases/in-place/evidence';foreach($path in @($inPlaceState,$inPlaceEvidence)){[void][IO.Directory]::CreateDirectory($path)};$source=New-Roots 'in-place-source';Copy-Item -LiteralPath (Join-Path $source.Target 'input.txt') -Destination $inPlacePackage;Copy-Item -LiteralPath (Join-Path $source.Target 'Contracts') -Destination $inPlacePackage -Recurse;Copy-Item -LiteralPath (Join-Path $source.Target 'Application') -Destination $inPlacePackage -Recurse;$inPlace=[pscustomobject]@{Target=$inPlacePackage;State=$inPlaceState;Evidence=$inPlaceEvidence;Package=$inPlacePackage};$inPlaceRun=Invoke-Stage $inPlace 'post' $inPlacePackage;Expect $inPlaceRun 'in-place clean Post' 0 'success';if($inPlaceRun.Document.status-cne$paritySeparated.Document.status-or$inPlaceRun.Document.exitCategory-cne$paritySeparated.Document.exitCategory-or@($inPlaceRun.Document.findings).Count-ne@($paritySeparated.Document.findings).Count){$failures.Add('in-place and separated clean verdicts differ')}

if($failures.Count){throw($failures-join"`n")}
Write-Host 'V4 P4F composite tests passed: 12-claim clean/violating/missing evidence, rule-plan severity, layered baseline, non-vacuity, failure matrix and in-place/separated parity.'
