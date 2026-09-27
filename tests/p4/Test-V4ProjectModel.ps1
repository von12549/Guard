[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$packageRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $packageRoot '../../..'))
$buildRoot = Join-Path $packageRoot 'build'
$project = Join-Path $packageRoot 'core/host/V4.Guards.Host/V4.Guards.Host.csproj'
$artifactsRoot = Join-Path $repositoryRoot 'artifacts/guards/v4/p4b'
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

if($failures.Count){throw($failures-join"`n")}
Write-Host 'V4 P4B Project Model tests passed: clean coverage, four blocking claims, missing-input failure and zero target execution.'
