[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$packageRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$workRoot = [IO.Path]::Combine([IO.Path]::GetTempPath(),'v4-guards-work',[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($packageRoot))).Substring(0,12).ToLowerInvariant())
if(-not(Test-Path -LiteralPath (Join-Path $workRoot '.git'))){[void][IO.Directory]::CreateDirectory($workRoot);& git -C $workRoot init -q;& git -C $workRoot -c user.name=v4-guards-test -c user.email=v4-guards-test@example.invalid -c commit.gpgsign=false commit -q --allow-empty -m 'V4 test work root';if($LASTEXITCODE){throw 'V4 test work root initialization failed.'}}
$buildRoot = Join-Path $packageRoot 'build'
$project = Join-Path $packageRoot 'core/host/V4.Guards.Host/V4.Guards.Host.csproj'
$artifactsRoot = Join-Path $workRoot 'm4-stage-semantics'
$hostOutput = Join-Path $artifactsRoot 'host'
$runRoot = Join-Path $artifactsRoot 'runs'
$profileSchema = Join-Path $packageRoot 'core/stage/contracts/semantic-profile.schema.json'
$providerSchema = Join-Path $packageRoot 'core/stage/contracts/built-in-provider.schema.json'
$resultSchema = Join-Path $packageRoot 'core/stage/contracts/stage-result.schema.json'
$catalogSchema = Join-Path $packageRoot 'core/stage/contracts/stage-semantics-contract.schema.json'
$failures = [Collections.Generic.List[string]]::new()

function Fail([string] $Message) { $script:failures.Add($Message) }
function Hash-Tree([string] $Root) {
    $items = [ordered]@{}
    foreach ($file in @(Get-ChildItem -LiteralPath $Root -Recurse -File -Force | Sort-Object FullName)) {
        $items[[IO.Path]::GetRelativePath($Root,$file.FullName).Replace('\','/')] = (Get-FileHash -Algorithm SHA256 -LiteralPath $file.FullName).Hash.ToLowerInvariant()
    }
    $items | ConvertTo-Json -Compress
}
function Invoke-Host([string[]] $Arguments) {
    $lines = @(& dotnet (Join-Path $hostOutput 'v4-guards.dll') @Arguments 2>&1 | ForEach-Object { $_.ToString() })
    [pscustomobject]@{ Code=$LASTEXITCODE; Text=($lines -join "`n") }
}
function New-Roots([string] $Name) {
    $root=Join-Path $runRoot $Name; $target=Join-Path $root 'target'; $state=Join-Path $root 'state'; $evidence=Join-Path $root 'evidence'
    foreach($path in @($target,$state,$evidence)){New-Item -ItemType Directory -Force -Path $path|Out-Null}
    [IO.File]::WriteAllText((Join-Path $target 'input.txt'),"semantic-ok`n",[Text.UTF8Encoding]::new($false))
    & git -C $target init -q
    & git -C $target -c user.name=v4-guards-test -c user.email=v4-guards-test@example.invalid -c commit.gpgsign=false add input.txt
    & git -C $target -c user.name=v4-guards-test -c user.email=v4-guards-test@example.invalid -c commit.gpgsign=false commit -qm seed
    if($LASTEXITCODE){throw "Git fixture initialization failed: $Name"}
    [pscustomobject]@{Root=$root;Target=$target;State=$state;Evidence=$evidence;TargetHash=(Hash-Tree $target)}
}
function Invoke-Stage($Roots,[string]$Stage,[switch]$WithDependencies){
    $arguments=@('stage','run','--stage',$Stage,'--package-root',$packageRoot,'--target-root',$Roots.Target,'--state-root',$Roots.State,'--evidence-root',$Roots.Evidence,'--profile','semantic_profile')
    if($WithDependencies){$arguments+='--with-dependencies'}
    Invoke-Host $arguments
}
function Parse-Result([string]$Label,$Run,[int]$Code){
    if($Run.Code-ne$Code){Fail "$Label returned $($Run.Code), expected ${Code}: $($Run.Text)";return $null}
    try{$result=$Run.Text|ConvertFrom-Json -Depth 100}catch{Fail "$Label did not return JSON: $($Run.Text)";return $null}
    $state=Get-Content -Raw (Join-Path $script:currentRoots.State 'state.json')|ConvertFrom-Json
    $projectId=@($state.projectInstances)[0].id
    $resultPath=Join-Path $script:currentRoots.Evidence "projects/$projectId/runs/$($result.runId)/stage-result.json"
    if(-not(Test-Json -LiteralPath $resultPath -SchemaFile $resultSchema -ErrorAction SilentlyContinue)){Fail "$Label result violates the v2 Stage schema"}
    $result|Add-Member -NotePropertyName ResultPath -NotePropertyValue $resultPath
    $result|Add-Member -NotePropertyName ProjectId -NotePropertyValue $projectId
    $result
}

foreach($path in @('core/stage/profiles/semantic_profile.json')){
    if(-not(Test-Json -LiteralPath (Join-Path $packageRoot $path) -SchemaFile $profileSchema -ErrorAction SilentlyContinue)){Fail "$path violates semantic-profile.schema.json"}
}
if(-not(Test-Json -LiteralPath (Join-Path $packageRoot 'core/stage/stage-semantics-contract.json') -SchemaFile $catalogSchema -ErrorAction SilentlyContinue)){Fail 'stage-semantics-contract.json violates its schema'}
foreach($path in @('core/stage/providers/guard-readiness.provider.json','core/stage/providers/workspace-analysis.provider.json')){
    if(-not(Test-Json -LiteralPath (Join-Path $packageRoot $path) -SchemaFile $providerSchema -ErrorAction SilentlyContinue)){Fail "$path violates built-in-provider.schema.json"}
}
$provider=Get-Content -Raw (Join-Path $packageRoot 'core/stage/providers/guard-readiness.provider.json')|ConvertFrom-Json -AsHashtable
$provider.resultKind='post-gate'
if(Test-Json -Json ($provider|ConvertTo-Json -Depth 20 -Compress) -SchemaFile $providerSchema -ErrorAction SilentlyContinue){Fail 'Provider result-kind/stage mismatch was accepted'}

if(Test-Path -LiteralPath $artifactsRoot){Remove-Item -LiteralPath $artifactsRoot -Recurse -Force}
New-Item -ItemType Directory -Force -Path $runRoot,$hostOutput|Out-Null
$properties=@('-p:ImportDirectoryBuildProps=false','-p:ImportDirectoryBuildTargets=false','-p:ImportDirectoryPackagesProps=false','-p:ImportDirectorySolutionProps=false','-p:ImportDirectorySolutionTargets=false',"-p:CustomBeforeMicrosoftCommonProps=$(Join-Path $buildRoot 'V4.Build.props')")
Push-Location $buildRoot
try{
    & dotnet restore $project --configfile (Join-Path $buildRoot 'NuGet.config') --artifacts-path $artifactsRoot -nologo @properties
    if($LASTEXITCODE){throw 'M4 Host restore failed'}
    & dotnet build $project --no-restore --artifacts-path $artifactsRoot -o $hostOutput -nologo @properties
    if($LASTEXITCODE){throw 'M4 Host build failed'}
}finally{Pop-Location}

$packageBefore=Hash-Tree $packageRoot
$script:currentRoots=New-Roots 'dependency-execution'
$direct=Parse-Result 'direct pre without providers' (Invoke-Stage $script:currentRoots 'pre') 15
if($null-ne$direct){
    if($direct.outcome-cne'fail'-or$direct.exitCategory-cne'prerequisite-missing'-or$direct.coverage[0].matched-ne0){Fail 'Direct pre did not fail closed on missing providers'}
}
$dependent=Parse-Result 'pre with dependencies' (Invoke-Stage $script:currentRoots 'pre' -WithDependencies) 0
if($null-ne$dependent){
    if((@($dependent.executedStages)-join',')-cne'bootstrap,analysis,pre'){Fail 'With-dependencies order is not bootstrap,analysis,pre'}
    if((@($dependent.stageExecutions.source)-join',')-cne'executed,executed,executed'){Fail 'Missing providers were not visibly executed'}
    if($dependent.evidenceTrust.producerClass-cne'local-advisory'-or$dependent.evidenceTrust.authoritative-ne$false){Fail 'Local Evidence was presented as authoritative'}
    if(@($dependent.coverage|Where-Object{$_.minimum-lt1}).Count-ne0){Fail 'Semantic coverage is vacuous'}
    if($dependent.timings.totalMilliseconds-lt0-or@($dependent.timings.stages).Count-ne3-or@($dependent.timings.modules).Count-ne3){Fail 'Semantic timing coverage is incomplete'}
    $inspect=Invoke-Host @('stage','inspect','--package-root',$packageRoot,'--evidence-root',$script:currentRoots.Evidence,'--project',$dependent.ProjectId,'--run',$dependent.runId)
    if($inspect.Code-ne0){Fail "Stage inspect failed: $($inspect.Text)"}else{$inspected=$inspect.Text|ConvertFrom-Json -Depth 100;if($inspected.evidenceTrust.contentIdentitySha256-cne$dependent.evidenceTrust.contentIdentitySha256){Fail 'Stage inspect changed content identity'}}
}

$script:currentRoots=New-Roots 'cross-run-reuse'
$bootstrap=Parse-Result 'direct bootstrap' (Invoke-Stage $script:currentRoots 'bootstrap') 0
$analysis=Parse-Result 'direct analysis' (Invoke-Stage $script:currentRoots 'analysis') 0
$reused=Parse-Result 'direct pre with exact providers' (Invoke-Stage $script:currentRoots 'pre') 0
if($null-ne$reused){
    if((@($reused.stageExecutions.source)-join',')-cne'reused,reused,executed'){Fail 'Exact provider Evidence was not visibly reused'}
    if((@($reused.evidenceTrust.dependencies.decision)-join',')-cne'reused-exact-local-advisory,reused-exact-local-advisory'){Fail 'Reuse diagnostics are not explicit local advisory decisions'}
}

if($null-ne$bootstrap-and$null-ne$analysis){
    foreach($result in @($bootstrap,$analysis)){
        $json=Get-Content -Raw $result.ResultPath|ConvertFrom-Json -AsHashtable -Depth 100
        $json.producedAt='2020-01-01T00:00:00.0000000+00:00'
        [IO.File]::WriteAllText($result.ResultPath,($json|ConvertTo-Json -Depth 100)+[Environment]::NewLine,[Text.UTF8Encoding]::new($false))
    }
    $stale=Parse-Result 'stale provider refusal' (Invoke-Stage $script:currentRoots 'post') 15
    if($null-ne$stale-and$stale.findings[0].subject-cnotmatch'bootstrap:stale,analysis:stale'){Fail 'Stale provider Evidence was not diagnosed'}
}

$script:currentRoots=New-Roots 'tamper-refusal'
$tamperBootstrap=Parse-Result 'tamper bootstrap' (Invoke-Stage $script:currentRoots 'bootstrap') 0
$tamperAnalysis=Parse-Result 'tamper analysis' (Invoke-Stage $script:currentRoots 'analysis') 0
if($null-ne$tamperBootstrap-and$null-ne$tamperAnalysis){
    $providerPath=Join-Path (Split-Path -Parent $tamperBootstrap.ResultPath) 'stages/bootstrap/providers/guard-readiness.json'
    [IO.File]::AppendAllText($providerPath," `n",[Text.UTF8Encoding]::new($false))
    $tampered=Parse-Result 'tampered provider refusal' (Invoke-Stage $script:currentRoots 'post') 15
    if($null-ne$tampered-and$tampered.findings[0].subject-cnotmatch'bootstrap:mismatch'){Fail 'Tampered provider Evidence was not refused'}
}

[IO.File]::WriteAllText((Join-Path $script:currentRoots.Target 'input.txt'),"changed`n",[Text.UTF8Encoding]::new($false))
$mismatch=Parse-Result 'workspace mismatch refusal' (Invoke-Stage $script:currentRoots 'pre') 15
if($null-ne$mismatch-and$mismatch.findings[0].subject-cnotmatch'mismatch'){Fail 'Workspace drift was not diagnosed as mismatch'}

if((Hash-Tree $packageRoot)-cne$packageBefore){Fail 'M4 Stage execution changed PackageRoot'}
if($failures.Count-gt0){throw($failures-join"`n")}
Write-Host 'M4 Stage semantics passed: isolated v2 authorities, explicit provider placement, fail-closed direct gates, ordered dependencies, exact local advisory reuse, stale/mismatch refusal, timing and inspect diagnostics.'
