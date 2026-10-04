[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$packageRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$repositoryRoot = $packageRoot
$workRoot = [IO.Path]::Combine([IO.Path]::GetTempPath(),'v4-guards-work',[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($packageRoot))).Substring(0,12).ToLowerInvariant())
if(-not(Test-Path -LiteralPath (Join-Path $workRoot '.git'))){[void][IO.Directory]::CreateDirectory($workRoot);& git -C $workRoot init -q;& git -C $workRoot -c user.name=v4-guards-test -c user.email=v4-guards-test@example.invalid -c commit.gpgsign=false commit -q --allow-empty -m 'V4 test work root';if($LASTEXITCODE){throw 'V4 test work root initialization failed.'}}
$buildRoot = Join-Path $packageRoot 'build'
$project = Join-Path $packageRoot 'core/host/V4.Guards.Host/V4.Guards.Host.csproj'
$artifactsRoot = Join-Path $workRoot 'p4b'
$runRoot = Join-Path $artifactsRoot 'fixture'
$failures = [Collections.Generic.List[string]]::new()

function Hash-Tree([string] $Root) {
    $items=[ordered]@{}; Get-ChildItem -LiteralPath $Root -Recurse -File | Sort-Object FullName | ForEach-Object { $items[[IO.Path]::GetRelativePath($Root,$_.FullName).Replace('\','/')] = (Get-FileHash -Algorithm SHA256 $_.FullName).Hash.ToLowerInvariant() }; $items | ConvertTo-Json -Compress
}
function New-Roots([string] $Name, [string] $ProjectXml) {
    $root=Join-Path $runRoot $Name; $target=Join-Path $root 'target'; $state=Join-Path $root 'state'; $evidence=Join-Path $root 'evidence'
    foreach($path in @($target,$state,$evidence)){ New-Item -ItemType Directory -Path $path -Force | Out-Null }
    [IO.File]::WriteAllText((Join-Path $target 'input.txt'),"synthetic-ok`n",[Text.UTF8Encoding]::new($false))
    if($ProjectXml){
        [IO.File]::WriteAllText((Join-Path $target 'Sample.csproj'),$ProjectXml,[Text.UTF8Encoding]::new($false))
        [IO.File]::WriteAllText((Join-Path $target 'Sample.cs'),'namespace Synthetic.ProjectModel { public sealed class Sample { } }',[Text.UTF8Encoding]::new($false))
    }
    [pscustomobject]@{Target=$target;State=$state;Evidence=$evidence;Before=(Hash-Tree $target)}
}
function Run($Roots) {
    $dll=Join-Path $artifactsRoot 'bin/V4.Guards.Host/debug/v4-guards.dll'
    $output=@(& dotnet $dll stage run --stage pre --package-root $packageRoot --target-root $Roots.Target --state-root $Roots.State --evidence-root $Roots.Evidence --profile synthetic_profile 2>&1)
    [pscustomobject]@{Code=$LASTEXITCODE;Output=($output -join "`n")}
}
function Result([string] $Name,$Roots,$Run,[int] $Code,[string] $Category) {
    if($Run.Code -ne $Code){$failures.Add("${Name}: expected $Code, got $($Run.Code): $($Run.Output)");return $null}
    try{$result=$Run.Output|ConvertFrom-Json}catch{$failures.Add("${Name}: invalid JSON");return $null}
    if($result.exitCategory -cne $Category){$failures.Add("${Name}: expected $Category")}
    if((Hash-Tree $Roots.Target) -cne $Roots.Before){$failures.Add("${Name}: detector changed TargetRoot")}
    if((Test-Path (Join-Path $Roots.Target 'obj')) -or (Test-Path (Join-Path $Roots.Target 'bin'))){$failures.Add("${Name}: detector executed a target build")}
    $result
}
function Run-Adapter($Roots,$Config) {
    $prior=$env:V4_STAGE_INPUT_JSON
    try {
        $env:V4_STAGE_INPUT_JSON=([ordered]@{formatVersion=1;stage='pre';targetRoot=$Roots.Target;config=$Config}|ConvertTo-Json -Depth 20 -Compress)
        $output=@(& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $packageRoot 'modules/architecture-conformance/adapter.ps1') 2>&1)
        if($LASTEXITCODE){$failures.Add("adapter process failed: $($output-join' ')");return $null}
        $output-join"`n"|ConvertFrom-Json
    } finally {$env:V4_STAGE_INPUT_JSON=$prior}
}

if(Test-Path $runRoot){Remove-Item -LiteralPath $runRoot -Recurse -Force}; New-Item -ItemType Directory -Path $runRoot -Force|Out-Null
$properties=@('-p:ImportDirectoryBuildProps=false','-p:ImportDirectoryBuildTargets=false','-p:ImportDirectoryPackagesProps=false','-p:ImportDirectorySolutionProps=false','-p:ImportDirectorySolutionTargets=false',"-p:CustomBeforeMicrosoftCommonProps=$(Join-Path $buildRoot 'V4.Build.props')")
Push-Location $buildRoot
try{& dotnet restore $project --configfile (Join-Path $buildRoot 'NuGet.config') --artifacts-path $artifactsRoot -nologo @properties;if($LASTEXITCODE){throw 'P4B restore failed'};& dotnet build $project --no-restore --artifacts-path $artifactsRoot -nologo @properties;if($LASTEXITCODE){throw 'P4B build failed'}}finally{Pop-Location}

$clean=New-Roots 'clean' '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFramework>net10.0</TargetFramework></PropertyGroup></Project>'
$cleanResult=Result 'clean' $clean (Run $clean) 0 'success'
if($null -ne $cleanResult){
    $projectClaims=@('ARCH.PROJECT_REFERENCE','ARCH.PACKAGE_REFERENCE','ARCH.TARGET_FRAMEWORK','ARCH.GRAPH_COMPLETENESS')
    $claims=@($cleanResult.coverage|Where-Object claimId -in $projectClaims)
    if(@($cleanResult.moduleResults).Count -ne 2 -or $claims.Count -ne 4 -or @($claims|Where-Object matched -lt 1).Count -ne 0){$failures.Add('clean result lost module aggregation or non-zero Project Model coverage')}
}

$badXml='<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFramework>net9.0</TargetFramework></PropertyGroup><ItemGroup><ProjectReference Include="../Forbidden/Forbidden.csproj" /><PackageReference Include="Forbidden.Package" Version="1.0.0" /></ItemGroup></Project>'
$bad=New-Roots 'violating' $badXml
$badResult=Result 'violating' $bad (Run $bad) 16 'findings-blocking'
if($null -ne $badResult){$ids=@($badResult.findings.ruleId|Sort-Object -Unique);foreach($id in @('ARCH.PROJECT_REFERENCE','ARCH.PACKAGE_REFERENCE','ARCH.TARGET_FRAMEWORK','ARCH.GRAPH_COMPLETENESS')){if($ids -notcontains $id){$failures.Add("violating result lacks $id")}}}

$missing=New-Roots 'missing' ''
$missingResult=Result 'missing projects' $missing (Run $missing) 15 'prerequisite-missing'
if($null -ne $missingResult -and @($missingResult.coverage|Where-Object {$_.claimId -like 'ARCH.*' -and $_.matched -ne 0}).Count -ne 0){$failures.Add('missing project coverage is not zero')}

$central=New-Roots 'central-props' ''
Copy-Item -LiteralPath (Join-Path $packageRoot 'tests/fixtures/ifx-like-central-props/Directory.Build.props') -Destination $central.Target
Copy-Item -LiteralPath (Join-Path $packageRoot 'tests/fixtures/ifx-like-central-props/IFX.sln') -Destination $central.Target
foreach($relative in @('src/App/App.csproj','tests/App.Tests/App.Tests.csproj')){
    $destination=Join-Path $central.Target $relative;[void][IO.Directory]::CreateDirectory((Split-Path -Parent $destination));Copy-Item -LiteralPath (Join-Path $packageRoot "tests/fixtures/ifx-like-central-props/$relative") -Destination $destination
}
[IO.File]::WriteAllText((Join-Path $central.Target 'src/App/App.cs'),'namespace IFX.App; public sealed class AppMarker { }',[Text.UTF8Encoding]::new($false))
$central.Before=Hash-Tree $central.Target
$centralResult=Result 'central props' $central (Run $central) 0 'success'
if($null -ne $centralResult){
    $frameworkCoverage=@($centralResult.coverage|Where-Object claimId -ceq 'ARCH.TARGET_FRAMEWORK')
    if($frameworkCoverage.Count-ne1-or$frameworkCoverage[0].matched-ne2){$failures.Add('central props did not provide framework coverage for both projects')}
    if(@($centralResult.findings|Where-Object {$_.ruleId-ceq'ARCH.TARGET_FRAMEWORK'-and$_.subject-match'<missing>'}).Count-ne0){$failures.Add('central props was misclassified as a missing framework')}
}
$dll=Join-Path $artifactsRoot 'bin/V4.Guards.Host/debug/v4-guards.dll'
$discoveryOutput=@(& dotnet $dll profile discover --package-root $packageRoot --target-root $central.Target 2>&1)
if($LASTEXITCODE){$failures.Add("central props discovery failed: $($discoveryOutput-join' ')")}else{
    $discovery=($discoveryOutput-join"`n")|ConvertFrom-Json
    $centralFacts=@($discovery.facts|Where-Object { $_.kind-ceq'framework'-and$_.normalizedValue-ceq'dotnet:net10.0'-and$_.sourcePath-ceq'Directory.Build.props' })
    if($centralFacts.Count-ne2){$failures.Add('discovery did not evidence Directory.Build.props as the inherited framework source for both projects')}
    $rootCandidate=@($discovery.questions|Where-Object { $_.id -ceq 'root-solution-project-root' })
    if($rootCandidate.Count-ne1-or@($rootCandidate[0].candidateValues)-notcontains'.'){$failures.Add('root solution did not produce an explicit reviewable project-root candidate')}
}

$unsupported=New-Roots 'conditional-props' '<Project Sdk="Microsoft.NET.Sdk" />'
[IO.File]::WriteAllText((Join-Path $unsupported.Target 'Directory.Build.props'),'<Project><PropertyGroup Condition="''$(Configuration)'' == ''Debug''"><TargetFramework>net10.0</TargetFramework></PropertyGroup></Project>',[Text.UTF8Encoding]::new($false))
$unsupported.Before=Hash-Tree $unsupported.Target
$unsupportedRun=Run $unsupported
$unsupportedResult=Result 'conditional central props' $unsupported $unsupportedRun 15 'prerequisite-missing'
if($null-ne$unsupportedResult){
    if(@($unsupportedResult.findings|Where-Object {$_.subject-match'Unsupported target-framework coverage'}).Count-ne1){$failures.Add('conditional props did not report explicit unsupported coverage')}
    if(@($unsupportedResult.findings|Where-Object {$_.ruleId-ceq'ARCH.TARGET_FRAMEWORK'-and$_.subject-match'<missing>'}).Count-ne0){$failures.Add('conditional props was misclassified as a missing-framework violation')}
}

foreach($negative in @(
    [pscustomobject]@{Name='project-reference without policy';Claim='ARCH.PROJECT_REFERENCE';Config=[ordered]@{enabledClaims=@('ARCH.PROJECT_REFERENCE')}},
    [pscustomobject]@{Name='graph-completeness without resolution requirement';Claim='ARCH.GRAPH_COMPLETENESS';Config=[ordered]@{enabledClaims=@('ARCH.GRAPH_COMPLETENESS')}}
)){
    $result=Run-Adapter $clean $negative.Config
    if($null-eq$result){continue}
    $claimCoverage=@($result.coverage|Where-Object claimId -ceq $negative.Claim)
    if($result.status-cne'error'-or$result.exitCategory-cne'invalid-input'-or$claimCoverage.Count-ne1-or$claimCoverage[0].matched-ne0){
        $failures.Add("$($negative.Name) did not fail closed with zero coverage")
    }
}

if($failures.Count){throw($failures-join"`n")}
Write-Host 'V4 P4B Project Model tests passed: clean coverage, central-props inheritance/source evidence, root-solution candidate, unsupported conditional coverage, semantic-config fail-closed controls, four blocking claims, missing-input failure and zero target execution.'
