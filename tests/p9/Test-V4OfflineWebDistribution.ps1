[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$packageRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $packageRoot '../../..'))
$buildRoot = Join-Path $packageRoot 'build'
$hostProject = Join-Path $packageRoot 'core/host/V4.Guards.Host/V4.Guards.Host.csproj'
$companionProject = Join-Path $packageRoot 'integrations/web/V4.Guards.WebCompanion/V4.Guards.WebCompanion.csproj'
$builder = Join-Path $packageRoot 'core/distribution/New-V4Distribution.ps1'
$installer = Join-Path $packageRoot 'core/distribution/Install-V4Distribution.ps1'
$runRoot = Join-Path $repositoryRoot 'artifacts/guards/v4/p9e'
$hostOutput = Join-Path $runRoot 'host'
$companionA = Join-Path $runRoot 'companion-a'
$companionB = Join-Path $runRoot 'companion-b'
$hostile = Join-Path $runRoot 'hostile-parent'
$plugin = Get-Content -Raw (Join-Path $packageRoot 'plugin.json') | ConvertFrom-Json
$installRoot = Join-Path $hostile "installed/v4-guards-$($plugin.version)"
$receiptPath = Join-Path $hostile 'receipts/install.json'
$targetRoot = Join-Path $runRoot 'target'
$stateRoot = Join-Path $runRoot 'mutable/state'
$evidenceRoot = Join-Path $runRoot 'mutable/evidence'
$sourceCommit = (git -C $repositoryRoot rev-parse HEAD).Trim().ToLowerInvariant()
$failures = [Collections.Generic.List[string]]::new()
$companion = $null
$client = $null

function Fail([string] $Message) { $script:failures.Add($Message) }
function Hash([string] $Path) { (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant() }
function Tree-Hash([string] $Root) {
    $identity = @(Get-ChildItem -LiteralPath $Root -File -Recurse -Force | Sort-Object FullName | ForEach-Object {
        "$([IO.Path]::GetRelativePath($Root,$_.FullName).Replace('\','/')):$(Hash $_.FullName)"
    }) -join "`n"
    [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($identity))).ToLowerInvariant()
}
function Run-Script([string] $Script, [string[]] $Arguments, [string] $WorkingDirectory = $repositoryRoot) {
    Push-Location $WorkingDirectory
    try { $output = @(& pwsh -NoLogo -NoProfile -NonInteractive -File $Script @Arguments 2>&1); [pscustomobject]@{ Code=$LASTEXITCODE; Output=($output -join "`n") } }
    finally { Pop-Location }
}
function Build-Project([string] $Project, [string] $Output, [string] $Artifacts) {
    $properties = @(
        '-p:ImportDirectoryBuildProps=false','-p:ImportDirectoryBuildTargets=false','-p:ImportDirectoryPackagesProps=false',
        '-p:ImportDirectorySolutionProps=false','-p:ImportDirectorySolutionTargets=false',
        "-p:CustomBeforeMicrosoftCommonProps=$(Join-Path $buildRoot 'V4.Build.props')"
    )
    Push-Location $buildRoot
    try {
        & dotnet restore $Project --configfile (Join-Path $buildRoot 'NuGet.config') --artifacts-path $Artifacts -nologo @properties
        if ($LASTEXITCODE) { throw "Restore failed for $Project" }
        & dotnet build $Project --no-restore --configuration Release --artifacts-path $Artifacts -o $Output -nologo @properties
        if ($LASTEXITCODE) { throw "Build failed for $Project" }
    } finally { Pop-Location }
}
function New-LauncherStart([string[]] $Arguments) {
    $start = [Diagnostics.ProcessStartInfo]::new((Get-Command pwsh -ErrorAction Stop).Source)
    $start.UseShellExecute = $false; $start.RedirectStandardOutput = $true; $start.RedirectStandardError = $true; $start.CreateNoWindow = $true
    $start.WorkingDirectory = $hostile
    foreach ($argument in @('-NoLogo','-NoProfile','-NonInteractive','-File',(Join-Path $installRoot 'package/core/distribution/Invoke-V4InstalledWebCompanion.ps1'),
        '-PackageRoot',(Join-Path $installRoot 'package'),'-Profile','synthetic_profile','-PrerequisiteReportPath',(Join-Path $evidenceRoot 'companion-prerequisites.json'),
        '-CompanionArgumentsJson',($Arguments | ConvertTo-Json -Compress))) { [void]$start.ArgumentList.Add($argument) }
    $start
}
function Start-InstalledCompanion() {
    $arguments = @('--target-root',$targetRoot,'--state-root',$stateRoot,'--evidence-root',$evidenceRoot,'--plan-root','plans','--port','0')
    $process = [Diagnostics.Process]::new(); $process.StartInfo = New-LauncherStart $arguments
    if (-not $process.Start()) { throw 'Installed Web Companion did not start.' }
    $readyTask = $process.StandardOutput.ReadLineAsync()
    if (-not $readyTask.Wait([TimeSpan]::FromSeconds(45))) { try { $process.Kill($true) } catch { }; throw 'Installed Web Companion readiness timed out.' }
    $line = $readyTask.Result
    try { $ready = $line | ConvertFrom-Json }
    catch { $errorText=$process.StandardError.ReadToEnd(); try{$process.Kill($true)}catch{}; throw "Installed readiness was not JSON: $line $errorText" }
    if ($ready.status -cne 'ready' -or $ready.address -notmatch '^http://127\.0\.0\.1:[0-9]+$') { try{$process.Kill($true)}catch{}; throw "Installed readiness was invalid: $line" }
    [pscustomobject]@{ Process=$process; Address=[string]$ready.address }
}

if (Test-Path -LiteralPath $runRoot) { Remove-Item -LiteralPath $runRoot -Recurse -Force }
foreach ($path in @($runRoot,$hostile,$targetRoot,(Join-Path $targetRoot 'plans'),$stateRoot,$evidenceRoot)) { [void][IO.Directory]::CreateDirectory($path) }
[IO.File]::WriteAllText((Join-Path $targetRoot 'input.txt'),"synthetic-ok`n",[Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $hostile 'Directory.Build.props'),'<Project><Target Name="Hostile" BeforeTargets="Build"><Error Text="hostile parent loaded" /></Target></Project>',[Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $hostile 'Directory.Build.targets'),'<Project><Target Name="Hostile" BeforeTargets="Build"><Error Text="hostile target loaded" /></Target></Project>',[Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $hostile 'Directory.Packages.props'),'<Project><PropertyGroup><ManagePackageVersionsCentrally>true</ManagePackageVersionsCentrally></PropertyGroup></Project>',[Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $hostile 'global.json'),'{'+'"sdk":{"version":"0.0.0","rollForward":"disable"}}',[Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $hostile 'NuGet.config'),'<configuration><packageSources><clear /></packageSources></configuration>',[Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $hostile 'Microsoft.PowerShell_profile.ps1'),'throw "hostile profile loaded"',[Text.UTF8Encoding]::new($false))

try {
    Build-Project $hostProject $hostOutput (Join-Path $runRoot 'host-artifacts')
    Build-Project $companionProject $companionA (Join-Path $runRoot 'companion-a-artifacts')
    Build-Project $companionProject $companionB (Join-Path $runRoot 'companion-b-artifacts')
    if ((Hash (Join-Path $companionA 'v4-web-companion.dll')) -cne (Hash (Join-Path $companionB 'v4-web-companion.dll'))) { Fail 'Independent Companion builds were not byte-identical.' }
    if (Test-Path (Join-Path $companionA 'wwwroot')) { Fail 'Companion output contains a loose wwwroot.' }

    $distA = Run-Script $builder @('-PackageRoot',$packageRoot,'-HostRoot',$hostOutput,'-CompanionRoot',$companionA,'-OutputDirectory',(Join-Path $runRoot 'dist-a'),'-SourceCommit',$sourceCommit)
    $distB = Run-Script $builder @('-PackageRoot',$packageRoot,'-HostRoot',$hostOutput,'-CompanionRoot',$companionB,'-OutputDirectory',(Join-Path $runRoot 'dist-b'),'-SourceCommit',$sourceCommit)
    if ($distA.Code -ne 0 -or $distB.Code -ne 0) { throw "Offline distributions failed: $($distA.Output) $($distB.Output)" }
    $resultA=$distA.Output|ConvertFrom-Json; $resultB=$distB.Output|ConvertFrom-Json
    if ($resultA.archiveSha256 -cne $resultB.archiveSha256) { Fail 'Independent builds did not produce byte-identical offline archives.' }

    $install = Run-Script $installer @('-Mode','Install','-ArchivePath',$resultA.archivePath,'-InstallRoot',$installRoot,'-ReceiptPath',$receiptPath) $hostile
    if ($install.Code -ne 0) { throw "Offline install failed: $($install.Output)" }
    $installedHash = Tree-Hash $installRoot
    $packageBefore = Tree-Hash (Join-Path $installRoot 'package'); $targetBefore = Tree-Hash $targetRoot

    $companion = Start-InstalledCompanion
    $handler=[Net.Http.HttpClientHandler]::new();$handler.CookieContainer=[Net.CookieContainer]::new();$client=[Net.Http.HttpClient]::new($handler)
    foreach ($asset in @(@{Path='/';Source='index.html'},@{Path='/app.js';Source='app.js'},@{Path='/styles.css';Source='styles.css'})) {
        $actual=$client.GetByteArrayAsync("$($companion.Address)$($asset.Path)").GetAwaiter().GetResult()
        $expected=[IO.File]::ReadAllBytes((Join-Path $packageRoot "integrations/web/V4.Guards.WebCompanion/wwwroot/$($asset.Source)"))
        $actualHash=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($actual))
        $expectedHash=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($expected))
        if ($actualHash -cne $expectedHash) { Fail "Installed embedded asset bytes drifted: $($asset.Source)" }
    }
    $session=$client.GetStringAsync("$($companion.Address)/api/v1/session").GetAwaiter().GetResult()|ConvertFrom-Json
    if ($session.authority -cne 'v4-host' -or $session.allowedCommand -cne 'stage.run') { Fail 'Installed Companion did not preserve Host authority.' }
    $app=[Text.Encoding]::UTF8.GetString($client.GetByteArrayAsync("$($companion.Address)/app.js").GetAwaiter().GetResult())
    if ($app -match '(?i)innerHTML|outerHTML|insertAdjacentHTML|document\.write' -or $app -notmatch 'textContent' -or $app -notmatch 'renderMarkdown') { Fail 'Installed Markdown renderer is not text-only.' }
    if ((Tree-Hash (Join-Path $installRoot 'package')) -cne $packageBefore -or (Tree-Hash $targetRoot) -cne $targetBefore) { Fail 'Installed UI reads changed PackageRoot or TargetRoot.' }

    try { $companion.Process.Kill($true); [void]$companion.Process.WaitForExit(10000) } catch { }
    $companion.Process.Dispose(); $companion=$null; $client.Dispose();$client=$null

    $override = Run-Script (Join-Path $installRoot 'package/core/distribution/Invoke-V4InstalledWebCompanion.ps1') @('-PackageRoot',(Join-Path $installRoot 'package'),'-Profile','synthetic_profile','-PrerequisiteReportPath',(Join-Path $evidenceRoot 'override.json'),'-CompanionArgumentsJson',(@('--host','attacker.dll','--target-root',$targetRoot) | ConvertTo-Json -Compress)) $hostile
    if ($override.Code -ne 10 -or $override.Output -notmatch 'refuses Companion option' -or (Test-Path (Join-Path $hostile 'attacker.dll'))) { Fail 'Installed launcher did not refuse a Host override without shell effects.' }
    $escape = Run-Script (Join-Path $installRoot 'package/core/distribution/Invoke-V4InstalledWebCompanion.ps1') @('-PackageRoot',(Join-Path $installRoot 'package'),'-Profile','synthetic_profile','-PrerequisiteReportPath',(Join-Path $evidenceRoot 'escape.json'),'-CompanionArgumentsJson',(@('--target-root',$targetRoot,'--state-root',$stateRoot,'--evidence-root',$evidenceRoot,'--plan-root','../plans','--port','0') | ConvertTo-Json -Compress)) $hostile
    if ($escape.Code -ne 11 -or $escape.Output -notmatch 'unsafe-path') { Fail 'Installed Companion did not refuse Plan-root path escape.' }

    $driftPath=Join-Path $installRoot 'companion/v4-web-companion.dll';$original=[IO.File]::ReadAllBytes($driftPath)
    [IO.File]::AppendAllText($driftPath,'drift',[Text.UTF8Encoding]::new($false))
    $drift=Run-Script $installer @('-Mode','Uninstall','-InstallRoot',$installRoot,'-ReceiptPath',$receiptPath) $hostile
    if ($drift.Code -eq 0 -or $drift.Output -notmatch 'drift prevents uninstall') { Fail 'Companion drift did not prevent uninstall.' }
    [IO.File]::WriteAllBytes($driftPath,$original)
    $uninstall=Run-Script $installer @('-Mode','Uninstall','-InstallRoot',$installRoot,'-ReceiptPath',$receiptPath) $hostile
    if ($uninstall.Code -ne 0 -or (Test-Path $installRoot)) { Fail "Verified offline uninstall failed: $($uninstall.Output)" }
    $reinstall=Run-Script $installer @('-Mode','Install','-ArchivePath',$resultA.archivePath,'-InstallRoot',$installRoot,'-ReceiptPath',$receiptPath) $hostile
    if ($reinstall.Code -ne 0 -or (Tree-Hash $installRoot) -cne $installedHash) { Fail "Offline reinstall was not identical: $($reinstall.Output)" }
    $final=Run-Script $installer @('-Mode','Uninstall','-InstallRoot',$installRoot,'-ReceiptPath',$receiptPath) $hostile
    if ($final.Code -ne 0 -or (Test-Path $installRoot)) { Fail 'Final offline uninstall failed.' }
}
finally {
    if ($null -ne $client) { $client.Dispose() }
    if ($null -ne $companion -and -not $companion.Process.HasExited) { try{$companion.Process.Kill($true);[void]$companion.Process.WaitForExit(10000)}catch{};$companion.Process.Dispose() }
}

if ($failures.Count) { throw "V4 P9.5 offline distribution tests failed:`n - $($failures -join "`n - ")" }
Write-Host "V4 P9.5 offline distribution tests passed: embedded assets, deterministic build/archive, installed launch, injection/path/XSS refusal, hostile parent and identical lifecycle on $([Runtime.InteropServices.RuntimeInformation]::OSDescription)."
