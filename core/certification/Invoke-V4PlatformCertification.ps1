[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $RepositoryRoot,
    [Parameter(Mandatory)][ValidateSet('linux','windows')][string] $Platform,
    [Parameter(Mandatory)][ValidatePattern('^[a-f0-9]{40}$')][string] $SourceCommit,
    [Parameter(Mandatory)][string] $ReportPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Hash([string] $Path) { (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant() }
function Write-Json([string] $Path, $Value) { [void][IO.Directory]::CreateDirectory((Split-Path -Parent $Path)); [IO.File]::WriteAllText($Path,(($Value|ConvertTo-Json -Depth 100).Replace("`r`n","`n")+"`n"),[Text.UTF8Encoding]::new($false)) }
$toolPath=@(@('pwsh','dotnet','git')|ForEach-Object{Split-Path -Parent (Get-Command $_ -ErrorAction Stop).Source})+@([Environment]::GetEnvironmentVariable('PATH')-split[IO.Path]::PathSeparator)|Where-Object{$_}|Select-Object -Unique
$toolPath=$toolPath-join[IO.Path]::PathSeparator
function Invoke-Clean([string] $Executable,[string[]] $Arguments,[string] $WorkingDirectory,[int] $TimeoutSeconds=2400) {
    $command=(Get-Command $Executable -ErrorAction Stop).Source
    $start=[Diagnostics.ProcessStartInfo]::new($command);$start.UseShellExecute=$false;$start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true;$start.CreateNoWindow=$true;$start.WorkingDirectory=$WorkingDirectory;$start.Environment.Clear()
    foreach($name in @('PATH','PATHEXT','SystemRoot','WINDIR','TEMP','TMP','HOME','USERPROFILE','DOTNET_ROOT','ProgramFiles','ProgramFiles(x86)','LOCALAPPDATA','APPDATA','NUGET_PACKAGES')){$value=[Environment]::GetEnvironmentVariable($name);if($value){$start.Environment[$name]=$value}}
    $start.Environment['PATH']=$toolPath
    $start.Environment['CI']='true';$start.Environment['DOTNET_CLI_TELEMETRY_OPTOUT']='1';$start.Environment['POWERSHELL_TELEMETRY_OPTOUT']='1'
    foreach($argument in $Arguments){[void]$start.ArgumentList.Add($argument)}
    $process=[Diagnostics.Process]::Start($start);if($null-eq$process){throw "$Executable did not start."};$stdout=$process.StandardOutput.ReadToEndAsync();$stderr=$process.StandardError.ReadToEndAsync()
    if(-not$process.WaitForExit($TimeoutSeconds*1000)){$process.Kill($true);throw "$Executable timed out."};[Threading.Tasks.Task]::WaitAll(@($stdout,$stderr));[pscustomobject]@{Code=$process.ExitCode;Output=$stdout.Result.Trim();Error=$stderr.Result.Trim()}
}

$repository=[IO.Path]::TrimEndingDirectorySeparator([IO.Path]::GetFullPath($RepositoryRoot))
$package=Join-Path $repository 'docs/guards/v4';$contractPath=Join-Path $package 'integrations/github/ci-contract.json'
if(($Platform -eq 'linux' -and -not $IsLinux) -or ($Platform -eq 'windows' -and -not $IsWindows)){throw "Platform certification requested $Platform on $([Runtime.InteropServices.RuntimeInformation]::OSDescription)."}
$actualCommit=(& git -C $repository rev-parse HEAD).Trim().ToLowerInvariant();if($LASTEXITCODE -or $actualCommit -cne $SourceCommit){throw "Repository HEAD does not match SourceCommit $SourceCommit."}
if(@(& git -C $repository status --porcelain --untracked-files=no).Count-ne0){throw 'Platform certification requires a clean tracked worktree.'}
$contract=Get-Content -Raw $contractPath|ConvertFrom-Json -AsHashtable -Depth 100
$discovered=@(Get-ChildItem (Join-Path $package 'tests') -File -Recurse -Filter 'Test-*.ps1'|ForEach-Object{[IO.Path]::GetRelativePath($repository,$_.FullName).Replace('\','/')}|Sort-Object)
$approved=@($contract.approvedTests.path|Sort-Object);if(($discovered-join"`0")-cne($approved-join"`0")){throw 'CI contract does not bind the exact certification test set.'}
$property=if($Platform-eq'linux'){'linux'}else{'windowsFull'};$selected=@($contract.approvedTests|Where-Object{$_[$property]-eq$true})
$results=[Collections.Generic.List[object]]::new()
foreach($test in $contract.approvedTests){$path=Join-Path $repository ([string]$test.path);if((Hash $path)-cne[string]$test.sha256){throw "Approved test hash drift: $($test.path)"}}
foreach($test in $selected){
    $run=Invoke-Clean 'pwsh' @('-NoLogo','-NoProfile','-NonInteractive','-File',(Join-Path $repository ([string]$test.path))) $repository
    $combined=($run.Output+"`n"+$run.Error).Trim();if($combined){Write-Host $combined};if($run.Code){throw "Certification test failed: $($test.path)"}
    $resultHash=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($combined))).ToLowerInvariant()
    $results.Add([ordered]@{path=[string]$test.path;sha256=[string]$test.sha256;resultSha256=$resultHash})
}
$packageRun=Invoke-Clean 'pwsh' @('-NoLogo','-NoProfile','-NonInteractive','-File',(Join-Path $package 'core/runtime/Test-V4Package.ps1'),'-PackageRoot',$package) $repository
if($packageRun.Code){throw "Package validation failed: $($packageRun.Error)"};$packageResult=$packageRun.Output|ConvertFrom-Json
if(@(& git -C $repository status --porcelain --untracked-files=no).Count-ne0){throw 'Certification tests modified tracked repository content.'}
$dotnet=((& dotnet --list-sdks|Select-Object -Last 1)-split' ')[0];$gitVersion=((& git --version)-replace'^git version\s+','').Trim()
$document=[ordered]@{formatVersion=1;status='pass';platform=$Platform;coverage=if($Platform-eq'linux'){'complete'}else{'full'};sourceCommit=$SourceCommit;packageHash=[string]$packageResult.packageHash;osDescription=[Runtime.InteropServices.RuntimeInformation]::OSDescription;architecture=[Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString().ToLowerInvariant();toolchain=[ordered]@{pwsh=$PSVersionTable.PSVersion.ToString();dotnet=$dotnet;git=$gitVersion};tests=@($results);secretEnvironmentNames=@()}
Write-Json ([IO.Path]::GetFullPath($ReportPath)) $document
if(-not(Test-Json -LiteralPath $ReportPath -SchemaFile (Join-Path $package 'core/contracts/platform-certification.schema.json') -ErrorAction SilentlyContinue)){throw 'Platform certification report violates its schema.'}
$document|ConvertTo-Json -Depth 100
