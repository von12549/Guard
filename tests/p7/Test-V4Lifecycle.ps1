[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$packageRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$repoRoot = [IO.Path]::GetFullPath((Join-Path $packageRoot '../../..'))
$runRoot = Join-Path $repoRoot 'artifacts/guards/v4/p7-lifecycle'
$buildRoot = Join-Path $packageRoot 'build'
$project = Join-Path $packageRoot 'core/host/V4.Guards.Host/V4.Guards.Host.csproj'
$builder = Join-Path $packageRoot 'core/distribution/New-V4Distribution.ps1'
$installer = Join-Path $packageRoot 'core/distribution/Install-V4Distribution.ps1'
$sourceCommit = (git -C $repoRoot rev-parse HEAD).Trim().ToLowerInvariant()
$failures = [Collections.Generic.List[string]]::new()

function Run-Script([string] $Script, [string[]] $Arguments) {
    $output = @(& pwsh -NoLogo -NoProfile -NonInteractive -File $Script @Arguments 2>&1)
    [pscustomobject]@{ Code=$LASTEXITCODE; Output=($output -join "`n") }
}
function Tree-Hash([string] $Root) {
    $identity = @(Get-ChildItem -LiteralPath $Root -File -Recurse -Force | Sort-Object FullName | ForEach-Object { "$([IO.Path]::GetRelativePath($Root,$_.FullName).Replace('\','/')):$((Get-FileHash $_.FullName).Hash.ToLowerInvariant())" }) -join "`n"
    [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($identity))).ToLowerInvariant()
}
function Invoke-Installed([string[]] $Arguments, [string] $ReportName) {
    $launcher = Join-Path $installRoot 'package/core/distribution/Invoke-V4Installed.ps1'
    Run-Script $launcher @('-PackageRoot',(Join-Path $installRoot 'package'),'-Profile','synthetic_profile','-PrerequisiteReportPath',(Join-Path $evidenceRoot $ReportName),'-HostArgumentsJson',($Arguments | ConvertTo-Json -Compress))
}

if (Test-Path -LiteralPath $runRoot) { Remove-Item -LiteralPath $runRoot -Recurse -Force }
[void][IO.Directory]::CreateDirectory($runRoot)
$buildArtifacts = Join-Path $runRoot 'build'
$properties = @('-p:ImportDirectoryBuildProps=false','-p:ImportDirectoryBuildTargets=false','-p:ImportDirectoryPackagesProps=false','-p:ImportDirectorySolutionProps=false','-p:ImportDirectorySolutionTargets=false',"-p:CustomBeforeMicrosoftCommonProps=$(Join-Path $buildRoot 'V4.Build.props')")
Push-Location $buildRoot
try {
    & dotnet restore $project --configfile (Join-Path $buildRoot 'NuGet.config') --artifacts-path $buildArtifacts -nologo @properties
    if ($LASTEXITCODE) { throw 'P7 lifecycle restore failed.' }
    & dotnet build $project --no-restore --configuration Release --artifacts-path $buildArtifacts -nologo @properties
    if ($LASTEXITCODE) { throw 'P7 lifecycle build failed.' }
} finally { Pop-Location }

$distribution = Run-Script $builder @('-PackageRoot',$packageRoot,'-HostRoot',(Join-Path $buildArtifacts 'bin/V4.Guards.Host/release'),'-OutputDirectory',(Join-Path $runRoot 'distribution'),'-SourceCommit',$sourceCommit)
if ($distribution.Code -ne 0) { throw "Lifecycle distribution failed: $($distribution.Output)" }
$archive = ($distribution.Output | ConvertFrom-Json).archivePath
$hostile = Join-Path $runRoot 'hostile-parent'
$installRoot = Join-Path $hostile 'installed/v4-guards-0.1.0'
$receiptPath = Join-Path $hostile 'receipts/install.json'
$targetRoot = Join-Path $runRoot 'external-target'
$stateRoot = Join-Path $runRoot 'mutable/state'
$evidenceRoot = Join-Path $runRoot 'mutable/evidence'
foreach ($path in @($hostile,$targetRoot,$stateRoot,$evidenceRoot)) { [void][IO.Directory]::CreateDirectory($path) }
[IO.File]::WriteAllText((Join-Path $targetRoot 'input.txt'),"synthetic-ok`n",[Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $hostile 'Directory.Build.props'),'<Project><Target Name="Hostile" BeforeTargets="Build"><Error Text="hostile parent loaded" /></Target></Project>',[Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $hostile 'Directory.Build.targets'),'<Project><Target Name="HostileTarget" BeforeTargets="Build"><Error Text="hostile target loaded" /></Target></Project>',[Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $hostile 'Directory.Packages.props'),'<Project><PropertyGroup><ManagePackageVersionsCentrally>true</ManagePackageVersionsCentrally></PropertyGroup></Project>',[Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $hostile 'global.json'),'{"sdk":{"version":"0.0.0","rollForward":"disable"}}',[Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $hostile 'NuGet.config'),'<configuration><packageSources><clear /></packageSources></configuration>',[Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $hostile 'Microsoft.PowerShell_profile.ps1'),'throw "hostile profile loaded"',[Text.UTF8Encoding]::new($false))

Push-Location $hostile
try {
    $install = Run-Script $installer @('-Mode','Install','-ArchivePath',$archive,'-InstallRoot',$installRoot,'-ReceiptPath',$receiptPath)
    if ($install.Code -ne 0) { $failures.Add("install failed: $($install.Output)") }
    if (-not (Test-Json -LiteralPath $receiptPath -SchemaFile (Join-Path $packageRoot 'core/contracts/install-receipt.schema.json') -ErrorAction SilentlyContinue)) { $failures.Add('install receipt violates schema') }
    $installedHash = if (Test-Path $installRoot) { Tree-Hash $installRoot } else { '' }

    $mismatch = Run-Script (Join-Path $installRoot 'package/core/distribution/Invoke-V4Installed.ps1') @('-PackageRoot',(Join-Path $installRoot 'package'),'-Profile','default','-PrerequisiteReportPath',(Join-Path $evidenceRoot 'mismatch-prerequisites.json'),'-HostArgumentsJson',(@('stage','run','--stage','analysis','--package-root',(Join-Path $installRoot 'package'),'--target-root',$targetRoot,'--state-root',$stateRoot,'--evidence-root',$evidenceRoot,'--profile','synthetic_profile') | ConvertTo-Json -Compress))
    if ($mismatch.Code -ne 10 -or $mismatch.Output -notmatch 'must match the host --profile') { $failures.Add('profile/prerequisite selection mismatch was not rejected') }

    $stage = Invoke-Installed @('stage','run','--stage','analysis','--package-root',(Join-Path $installRoot 'package'),'--target-root',$targetRoot,'--state-root',$stateRoot,'--evidence-root',$evidenceRoot,'--profile','synthetic_profile') 'stage-prerequisites.json'
    if ($stage.Code -ne 0 -or $stage.Output -notmatch '"status"\s*:\s*"pass"') { $failures.Add("installed host run failed: $($stage.Output)") }
    $stateDocument = Get-Content -Raw (Join-Path $stateRoot 'state.json') | ConvertFrom-Json
    $projectId = [string]$stateDocument.projectInstances[0].id
    $preview = Invoke-Installed @('reset','project','--mode','preview','--package-root',(Join-Path $installRoot 'package'),'--state-root',$stateRoot,'--evidence-root',$evidenceRoot,'--project',$projectId) 'reset-preview-prerequisites.json'
    if ($preview.Code -ne 0) { $failures.Add("installed reset preview failed: $($preview.Output)") }
    else {
        $previewResult = $preview.Output | ConvertFrom-Json
        $apply = Invoke-Installed @('reset','project','--mode','apply','--package-root',(Join-Path $installRoot 'package'),'--state-root',$stateRoot,'--evidence-root',$evidenceRoot,'--project',$projectId,'--accept-manifest-hash',[string]$previewResult.manifestHash) 'reset-apply-prerequisites.json'
        if ($apply.Code -ne 0 -or $apply.Output -notmatch '"status"\s*:\s*"pass"') { $failures.Add("installed reset apply failed: $($apply.Output)") }
    }
    if ((Get-Content -Raw (Join-Path $targetRoot 'input.txt')).Trim() -cne 'synthetic-ok') { $failures.Add('installed lifecycle changed TargetRoot') }

    $driftPath = Join-Path $installRoot 'package/docs/commands.md'
    $original = [IO.File]::ReadAllBytes($driftPath)
    [IO.File]::AppendAllText($driftPath,"drift`n",[Text.UTF8Encoding]::new($false))
    $driftUninstall = Run-Script $installer @('-Mode','Uninstall','-InstallRoot',$installRoot,'-ReceiptPath',$receiptPath)
    if ($driftUninstall.Code -eq 0 -or $driftUninstall.Output -notmatch 'drift prevents uninstall') { $failures.Add('uninstall did not refuse installed-file drift') }
    [IO.File]::WriteAllBytes($driftPath,$original)
    $uninstall = Run-Script $installer @('-Mode','Uninstall','-InstallRoot',$installRoot,'-ReceiptPath',$receiptPath)
    if ($uninstall.Code -ne 0 -or (Test-Path $installRoot)) { $failures.Add("verified uninstall failed: $($uninstall.Output)") }

    $reinstall = Run-Script $installer @('-Mode','Install','-ArchivePath',$archive,'-InstallRoot',$installRoot,'-ReceiptPath',$receiptPath)
    if ($reinstall.Code -ne 0 -or (Tree-Hash $installRoot) -cne $installedHash) { $failures.Add("reinstall was not identical: $($reinstall.Output)") }
    $final = Run-Script $installer @('-Mode','Uninstall','-InstallRoot',$installRoot,'-ReceiptPath',$receiptPath)
    if ($final.Code -ne 0 -or (Test-Path $installRoot)) { $failures.Add('final uninstall failed') }
} finally { Pop-Location }

if ($failures.Count) { throw ($failures -join "`n") }
Write-Host 'V4 P7 lifecycle tests passed: isolated install, external run, reset, drift refusal, uninstall and identical reinstall under hostile parent configuration.'
