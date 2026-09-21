Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Result([string]$Status,[string]$Category,[string]$Message,[int]$Matched,[int]$Minimum){
    $result=[ordered]@{formatVersion=1;status=$Status;exitCategory=$Category}
    if(-not[string]::IsNullOrWhiteSpace($Message)){$result.message=$Message}
    $result.findings=@();$result.coverage=@([ordered]@{claimId='BUILD.EVIDENCE';matched=$Matched;minimum=$Minimum})
    $result|ConvertTo-Json -Depth 20 -Compress
}
function Relative([string]$Root,[string]$Path){[IO.Path]::GetRelativePath($Root,$Path).Replace('\','/')}
function Resolve-Under([string]$Root,[string]$Relative,[string]$Label){
    if([string]::IsNullOrWhiteSpace($Relative)-or[IO.Path]::IsPathRooted($Relative)){throw "$Label must be relative."}
    $segments=$Relative.Replace('\','/').Split('/',[StringSplitOptions]::RemoveEmptyEntries)
    if($segments.Count-eq0-or$segments-contains'..'-or$segments-contains'.'){throw "$Label contains an unsafe segment: $Relative"}
    $path=[IO.Path]::GetFullPath((Join-Path $Root ($segments-join[IO.Path]::DirectorySeparatorChar)))
    $prefix=$Root.TrimEnd([IO.Path]::DirectorySeparatorChar)+[IO.Path]::DirectorySeparatorChar
    if(-not$path.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)){throw "$Label escapes its root: $Relative"}
    $path
}
function Is-Excluded([string]$Relative){
    $parts=$Relative.Replace('\','/').Split('/',[StringSplitOptions]::RemoveEmptyEntries)
    @($parts|Where-Object{$_-in@('.git','bin','obj','artifacts')}).Count-gt0
}
function Snapshot([string]$Root){
    $lines=[Collections.Generic.List[string]]::new()
    foreach($file in Get-ChildItem -LiteralPath $Root -Recurse -File -Force|Sort-Object FullName){
        $relative=Relative $Root $file.FullName;if(Is-Excluded $relative){continue}
        if(($file.Attributes-band[IO.FileAttributes]::ReparsePoint)-ne0-or$null-ne$file.LinkTarget){throw "Target snapshot crosses a link: $relative"}
        $hash=(Get-FileHash -Algorithm SHA256 -LiteralPath $file.FullName).Hash.ToLowerInvariant();$lines.Add("$relative`:$hash")
    }
    $bytes=[Text.Encoding]::UTF8.GetBytes(($lines-join"`n"));[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
}
function Copy-Snapshot([string]$Source,[string]$Destination){
    [void][IO.Directory]::CreateDirectory($Destination)
    foreach($item in Get-ChildItem -LiteralPath $Source -Recurse -Force|Sort-Object FullName){
        $relative=Relative $Source $item.FullName;if(Is-Excluded $relative){continue}
        if(($item.Attributes-band[IO.FileAttributes]::ReparsePoint)-ne0-or$null-ne$item.LinkTarget){throw "Target copy crosses a link: $relative"}
        $target=Resolve-Under $Destination $relative 'target snapshot item'
        if($item.PSIsContainer){[void][IO.Directory]::CreateDirectory($target)}else{[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target));[IO.File]::Copy($item.FullName,$target,$false)}
    }
}
function Invoke-DotNet([string]$WorkingDirectory,[string[]]$Arguments,[string]$CliHome,[int]$TimeoutSeconds){
    $command=Get-Command dotnet -ErrorAction SilentlyContinue;if($null-eq$command){throw 'dotnet is unavailable.'}
    $start=[Diagnostics.ProcessStartInfo]::new($command.Source);$start.UseShellExecute=$false;$start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true;$start.CreateNoWindow=$true;$start.WorkingDirectory=$WorkingDirectory
    $preserve=@(
        'PATH','DOTNET_ROOT','DOTNET_HOST_PATH','SystemRoot','WINDIR','ComSpec','PATHEXT',
        'TEMP','TMP','TMPDIR','USERPROFILE','HOME','HOMEDRIVE','HOMEPATH','USERNAME',
        'APPDATA','LOCALAPPDATA','ALLUSERSPROFILE','ProgramData','ProgramFiles','ProgramFiles(x86)',
        'CommonProgramFiles','CommonProgramFiles(x86)','OS','PROCESSOR_ARCHITECTURE'
    )
    $values=[ordered]@{};foreach($name in $preserve){$value=[Environment]::GetEnvironmentVariable($name);if(-not[string]::IsNullOrWhiteSpace($value)){$values[$name]=$value}}
    $start.Environment.Clear();foreach($entry in $values.GetEnumerator()){$start.Environment[$entry.Key]=$entry.Value}
    $start.Environment['DOTNET_CLI_HOME']=$CliHome;$start.Environment['DOTNET_CLI_TELEMETRY_OPTOUT']='1';$start.Environment['DOTNET_NOLOGO']='1';$start.Environment['DOTNET_SKIP_FIRST_TIME_EXPERIENCE']='1'
    foreach($argument in $Arguments){$start.ArgumentList.Add($argument)}
    $process=[Diagnostics.Process]::Start($start);$stdout=$process.StandardOutput.ReadToEndAsync();$stderr=$process.StandardError.ReadToEndAsync()
    if(-not$process.WaitForExit($TimeoutSeconds*1000)){$process.Kill($true);throw 'dotnet build timed out.'}
    [Threading.Tasks.Task]::WaitAll($stdout,$stderr)
    if($process.ExitCode-ne0){throw "dotnet failed ($($process.ExitCode)): $($stderr.Result.Trim()) $($stdout.Result.Trim())"}
}

if([string]::IsNullOrWhiteSpace($env:V4_STAGE_INPUT_JSON)){throw 'V4_STAGE_INPUT_JSON is required.'}
$inputData=$env:V4_STAGE_INPUT_JSON|ConvertFrom-Json
if($inputData.formatVersion-ne1-or$inputData.stage-ne'post'){Write-Result 'error' 'invalid-input' 'Build Evidence Provider supports only Post.' 0 1;exit 0}
foreach($name in @('targetRoot','stateRoot','evidenceRoot','packageRoot','projectId','runId')){if(-not($inputData.PSObject.Properties.Name-contains$name)-or[string]::IsNullOrWhiteSpace([string]$inputData.$name)){Write-Result 'error' 'prerequisite-missing' "$name is required." 0 1;exit 0}}
$targetRoot=[IO.Path]::GetFullPath([string]$inputData.targetRoot);$stateRoot=[IO.Path]::GetFullPath([string]$inputData.stateRoot);$evidenceRoot=[IO.Path]::GetFullPath([string]$inputData.evidenceRoot);$packageRoot=[IO.Path]::GetFullPath([string]$inputData.packageRoot);$projectId=[string]$inputData.projectId;$runId=[string]$inputData.runId;$config=$inputData.config
$minimum=@($config.projects).Count
if($runId-cnotmatch'^[a-f0-9]{32}$'-or$minimum-lt1){Write-Result 'error' 'invalid-input' 'Run identity or project list is invalid.' 0 ([Math]::Max(1,$minimum));exit 0}
try{
    $snapshot=Snapshot $targetRoot
    $runRelative="projects/$projectId/build/runs/$runId";$runRoot=Resolve-Under $stateRoot $runRelative 'build run';$sourceRoot=Join-Path $runRoot 'source';$outputRoot=Join-Path $runRoot 'output';$cliHome=Join-Path $runRoot 'cli-home'
    Copy-Snapshot $targetRoot $sourceRoot
    if((Snapshot $sourceRoot)-cne$snapshot){throw 'The isolated source snapshot does not match TargetRoot.'}
    foreach($sentinel in @('Directory.Build.props','Directory.Build.targets','Directory.Packages.props')){if(-not[IO.File]::Exists((Join-Path $sourceRoot $sentinel))){[IO.File]::WriteAllText((Join-Path $sourceRoot $sentinel),'<Project />',[Text.UTF8Encoding]::new($false))}}
    [void][IO.Directory]::CreateDirectory($outputRoot);[void][IO.Directory]::CreateDirectory($cliHome)
    $assemblies=[Collections.Generic.List[object]]::new();$names=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach($project in @($config.projects)){
        $projectPath=Resolve-Under $sourceRoot ([string]$project.projectPath) 'project path';if(-not[IO.File]::Exists($projectPath)){Write-Result 'error' 'prerequisite-missing' "Configured project is missing: $($project.projectPath)" $assemblies.Count $minimum;exit 0}
        $assemblyName=[string]$project.assemblyName;if(-not$names.Add($assemblyName)){throw "Duplicate expected assembly: $assemblyName"}
        $slug=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes([string]$project.projectPath))).Substring(0,12).ToLowerInvariant();$projectOutput=Join-Path $outputRoot $slug;[void][IO.Directory]::CreateDirectory($projectOutput)
        $restore=@('restore',$projectPath,'--configfile',(Join-Path $packageRoot 'build/NuGet.config'),'-p:RestoreIgnoreFailedSources=false','-nologo')
        Invoke-DotNet $sourceRoot $restore $cliHome 120
        $build=@('build',$projectPath,'--no-restore','-c',[string]$config.configuration,'-f',[string]$config.targetFramework,'-o',$projectOutput,'-nologo')
        Invoke-DotNet $sourceRoot $build $cliHome 120
        $assemblyPath=Join-Path $projectOutput "$assemblyName.dll";if(-not[IO.File]::Exists($assemblyPath)){throw "Expected assembly was not produced: $assemblyName"}
        $identity=[Reflection.AssemblyName]::GetAssemblyName($assemblyPath).Name;if($identity-cne$assemblyName){throw "Assembly identity mismatch: expected $assemblyName, found $identity"}
        $assemblies.Add([ordered]@{assemblyName=$assemblyName;sourceProject=([string]$project.projectPath).Replace('\','/');configuration=[string]$config.configuration;targetFramework=[string]$config.targetFramework;statePath=Relative $stateRoot $assemblyPath;sha256=(Get-FileHash -Algorithm SHA256 $assemblyPath).Hash.ToLowerInvariant()})
    }
    $manifestRelative=([string]$config.manifestPath).Replace('{projectId}',$projectId).Replace('{runId}',$runId);$manifestPath=Resolve-Under $evidenceRoot $manifestRelative 'build manifest';[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($manifestPath))
    $manifest=[ordered]@{formatVersion=1;runId=$runId;projectId=$projectId;createdUtc=[DateTimeOffset]::UtcNow.ToString('O');configuration=[string]$config.configuration;targetFramework=[string]$config.targetFramework;targetSnapshotSha256=$snapshot;assemblies=@($assemblies)}
    $temporary="$manifestPath.$runId.tmp";[IO.File]::WriteAllText($temporary,($manifest|ConvertTo-Json -Depth 20)+[Environment]::NewLine,[Text.UTF8Encoding]::new($false));[IO.File]::Move($temporary,$manifestPath,$true)
    Write-Result 'pass' 'success' '' $assemblies.Count $minimum
}catch{$category=if($_.Exception.Message-match'link|reparse|escapes|unsafe'){'unsafe-path'}else{'adapter-failure'};Write-Result 'error' $category $_.Exception.Message 0 ([Math]::Max(1,$minimum))}
