[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$packageRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$publisher = Join-Path $packageRoot 'core/distribution/Publish-V4SelfContainedDistribution.ps1'
$installer = Join-Path $packageRoot 'core/distribution/Install-V4Distribution.ps1'
$sourceCommit = (git -C $packageRoot rev-parse HEAD).Trim().ToLowerInvariant()
$productVersion = [string]((Get-Content -Raw -LiteralPath (Join-Path $packageRoot 'plugin.json') | ConvertFrom-Json).version)
if ($productVersion -notmatch '^\d+\.\d+\.\d+$') { throw "Invalid product version in plugin.json: $productVersion" }
$rid = [Runtime.InteropServices.RuntimeInformation]::RuntimeIdentifier
if ($rid -notin @('win-x64','win-arm64','linux-x64','linux-arm64')) { throw "Unsupported native test RID: $rid" }
$runRoot = Join-Path ([IO.Path]::GetTempPath()) ('v4-m1-installed-launcher-' + [Guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($runRoot)
$failures = [Collections.Generic.List[string]]::new()

function Get-TextHash([string] $Value) {
    [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($Value))).ToLowerInvariant()
}

function Get-EnvironmentScopeHash([EnvironmentVariableTarget] $Target) {
    $entries = [Collections.Generic.List[string]]::new()
    $values = [Environment]::GetEnvironmentVariables($Target)
    foreach ($name in @($values.Keys | ForEach-Object { [string]$_ } | Sort-Object -CaseSensitive)) {
        $entries.Add($name + "`0" + [string]$values[$name])
    }
    Get-TextHash ($entries -join "`n")
}

function Get-ProfileStateHash {
    $entries = [Collections.Generic.List[string]]::new()
    foreach ($path in @($PROFILE.AllUsersAllHosts,$PROFILE.AllUsersCurrentHost,$PROFILE.CurrentUserAllHosts,$PROFILE.CurrentUserCurrentHost)) {
        if ([IO.File]::Exists($path)) { $entries.Add('file:' + (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash.ToLowerInvariant()) }
        elseif ([IO.Directory]::Exists($path)) { $entries.Add('directory') }
        else { $entries.Add('absent') }
    }
    Get-TextHash ($entries -join "`n")
}

function Get-HostSafetySnapshot {
    [ordered]@{
        userEnvironment = Get-EnvironmentScopeHash ([EnvironmentVariableTarget]::User)
        machineEnvironment = Get-EnvironmentScopeHash ([EnvironmentVariableTarget]::Machine)
        processPath = Get-TextHash ([string][Environment]::GetEnvironmentVariable('Path',[EnvironmentVariableTarget]::Process))
        profiles = Get-ProfileStateHash
    }
}

$hostSafetyBefore = Get-HostSafetySnapshot
function Assert-HostSafetyBoundary([string] $Phase) {
    $current = Get-HostSafetySnapshot
    $drift = @($hostSafetyBefore.Keys | Where-Object { $hostSafetyBefore[$_] -cne $current[$_] })
    if ($drift.Count) {
        throw "BLOCKED — HOST SAFETY INCIDENT: $Phase changed host-owned environment/profile state ($($drift -join ', '))."
    }
}

function Run([string] $Script, [string[]] $Arguments) {
    $output = @(& pwsh -NoLogo -NoProfile -NonInteractive -File $Script @Arguments 2>&1)
    [pscustomobject]@{ Code=$LASTEXITCODE; Text=($output -join "`n") }
}

function Run-WithErrorFile([string] $Name, [scriptblock] $Invocation) {
    $errorPath = Join-Path $runRoot "$Name.stderr.json"
    $standardOutput = @(& $Invocation 2> $errorPath)
    $code = $LASTEXITCODE
    $standardError = if ([IO.File]::Exists($errorPath)) { [IO.File]::ReadAllText($errorPath) } else { '' }
    [pscustomobject]@{ Code=$code; Stdout=($standardOutput -join "`n"); Stderr=$standardError; ErrorPath=$errorPath }
}

function Assert-StructuredLauncherFailure($Result, [string] $Name, [string] $Category, [int] $Code) {
    if ($Result.Code -ne $Code -or [string]::IsNullOrWhiteSpace($Result.Stderr)) {
        $failures.Add("${Name}: stderr was empty or exit code was unstable."); return
    }
    try { $document = $Result.Stderr | ConvertFrom-Json }
    catch { $failures.Add("${Name}: stderr is not one parseable JSON document."); return }
    if ($document.exitCategory -cne $Category -or $document.status -cne 'error' -or -not [string]::IsNullOrEmpty($Result.Stdout)) {
        $failures.Add("${Name}: structured stderr fields or stdout boundary are invalid.")
    }
}

$publish = Run $publisher @('-PackageRoot',$packageRoot,'-RuntimeIdentifier',$rid,'-OutputDirectory',(Join-Path $runRoot 'publish'),'-MeasurementPath',(Join-Path $runRoot 'measurement.json'),'-SourceCommit',$sourceCommit)
if ($publish.Code -ne 0) { throw "Self-contained publish failed: $($publish.Text)" }
Assert-HostSafetyBoundary 'self-contained dotnet publish'
$archive = [string](($publish.Text | ConvertFrom-Json).archivePath)
$rejectedInstallRoot = Join-Path $runRoot 'rejected-install/install'
$rejectedReceipt = Join-Path $runRoot 'rejected-install-receipt.json'
$rejectedInstall = Run $installer @('-Mode','Install','-ArchivePath',$archive,'-InstallRoot',$rejectedInstallRoot,'-ReceiptPath',$rejectedReceipt)
$rejectedTemporary = @(Get-ChildItem -LiteralPath $runRoot -Directory -Recurse -Force -Filter '.v4-install-*' -ErrorAction SilentlyContinue)
if ($rejectedInstall.Code -eq 0 -or $rejectedInstall.Text -notmatch 'manifest root identity' -or
    (Test-Path -LiteralPath $rejectedInstallRoot) -or (Test-Path -LiteralPath $rejectedReceipt) -or $rejectedTemporary.Count -ne 0) {
    $failures.Add("Mismatched InstallRoot leaf was not rejected before installation state: $($rejectedInstall.Text)")
}
Assert-HostSafetyBoundary 'mismatched InstallRoot refusal'
$installRoot = Join-Path $runRoot "installed/v4-guards-$productVersion"
$receipt = Join-Path $runRoot 'receipts/install.json'
$install = Run $installer @('-Mode','Install','-ArchivePath',$archive,'-InstallRoot',$installRoot,'-ReceiptPath',$receipt)
if ($install.Code -ne 0) { throw "Install failed: $($install.Text)" }
Assert-HostSafetyBoundary 'verified install'
$guard = Join-Path $installRoot 'package/guard.ps1'
$guardWeb = Join-Path $installRoot 'package/guard-web.ps1'
if (-not [IO.File]::Exists($guard) -or -not [IO.File]::Exists($guardWeb)) { $failures.Add('Package-root launchers are missing.') }

$oldPath = $env:PATH
try {
    $env:PATH = $PSHOME
    $versionReport = Join-Path $runRoot 'version-prerequisites.json'
    $version = Run $guard @('-PrerequisiteReportPath',$versionReport,'version')
    if ($version.Code -ne 0) { $failures.Add("Installed self-contained Host launcher failed without dotnet on PATH: $($version.Text)") }
    else {
        $versionDocument = $version.Text | ConvertFrom-Json
        if ($versionDocument.status -cne 'pass' -or $versionDocument.command -cne 'version') { $failures.Add('Installed Host launcher returned an invalid version result.') }
        $prerequisites = Get-Content -Raw -LiteralPath $versionReport | ConvertFrom-Json
        if (@($prerequisites.requirements | Where-Object runtime -eq 'dotnet').Count -ne 0) { $failures.Add('Self-contained default Profile still required Host-owned dotnet.') }
    }
    $directVersionReport = Join-Path $runRoot 'version-direct-prerequisites.json'
    $directVersion = Run-WithErrorFile 'direct-version' { & $guard -PrerequisiteReportPath $directVersionReport version }
    if ($directVersion.Code -ne 0 -or -not [string]::IsNullOrEmpty($directVersion.Stderr)) {
        $failures.Add("Installed call-operator version failed or wrote stderr (exit $($directVersion.Code), stdout chars $($directVersion.Stdout.Length), stderr chars $($directVersion.Stderr.Length)).")
    }
    else {
        try { $directVersionDocument = $directVersion.Stdout | ConvertFrom-Json }
        catch { $failures.Add('Installed call-operator version did not return JSON.'); $directVersionDocument = $null }
        if ($null -ne $directVersionDocument -and ($directVersionDocument.status -cne 'pass' -or $directVersionDocument.command -cne 'version')) {
            $failures.Add('Installed call-operator version returned an invalid result.')
        }
    }
} finally { $env:PATH = $oldPath }
Assert-HostSafetyBoundary 'public version launchers'

$internal = Join-Path $installRoot 'package/core/distribution/Invoke-V4Installed.ps1'
$mismatch = Run $internal @('-PackageRoot',(Join-Path $runRoot 'wrong-package'),'-Profile','default','-PrerequisiteReportPath',(Join-Path $runRoot 'mismatch.json'),'-HostArgumentsJson','["version"]')
if ($mismatch.Code -ne 11 -or $mismatch.Text -notmatch 'override does not match') { $failures.Add("PackageRoot override mismatch was not rejected: $($mismatch.Text)") }
Assert-HostSafetyBoundary 'installed-runner refusal'

$layoutScript = Join-Path $installRoot 'package/core/distribution/Resolve-V4InstalledLayout.ps1'
. $layoutScript
$layout = Resolve-V4InstalledLayout -PackageRoot (Join-Path $installRoot 'package') -RequireCompanion
if (-not $layout.SelfContained -or [IO.Path]::GetExtension([string]$layout.HostPath) -cne $(if ($IsWindows) { '.exe' } else { '' })) {
    $failures.Add('Installed layout did not select the native self-contained apphost.')
}

$targetRoot = Join-Path $runRoot 'target with spaces'
$stateRoot = Join-Path $runRoot 'state with spaces'
[void][IO.Directory]::CreateDirectory($targetRoot)
[void][IO.Directory]::CreateDirectory($stateRoot)
[IO.File]::WriteAllText((Join-Path $targetRoot 'sample.csproj'),'<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFramework>net10.0</TargetFramework></PropertyGroup></Project>',[Text.UTF8Encoding]::new($false))
$discover = Run $guard @('-PrerequisiteReportPath',(Join-Path $runRoot 'discover-prerequisites.json'),'profile','discover','--package-root',(Join-Path $installRoot 'package'),'--target-root',$targetRoot)
if ($discover.Code -ne 0 -or ($discover.Text | ConvertFrom-Json).operation -cne 'profile-discover') { $failures.Add("New-Profile discovery required wrapper Profile lore or changed argument identity: $($discover.Text)") }
Assert-HostSafetyBoundary 'public discovery launcher'
$draft = Run $guard @('-PrerequisiteReportPath',(Join-Path $runRoot 'draft-prerequisites.json'),'profile','draft','--package-root',(Join-Path $installRoot 'package'),'--target-root',$targetRoot,'--state-root',$stateRoot,'--profile','onboarding_new')
if ($draft.Code -ne 0 -or ($draft.Text | ConvertFrom-Json).candidateProfile.id -cne 'onboarding_new') { $failures.Add("Unknown Profile draft was blocked by installed-Profile prerequisite selection: $($draft.Text)") }
Assert-HostSafetyBoundary 'public draft launcher'

$directInvalidReport = Join-Path $runRoot 'invalid-direct.json'
$noArgumentsDirect = Run-WithErrorFile 'direct-call-operator' { & $guard -PrerequisiteReportPath $directInvalidReport }
Assert-StructuredLauncherFailure $noArgumentsDirect 'same-process call operator' 'invalid-input' 10
$fileArguments = @('-PrerequisiteReportPath',(Join-Path $runRoot 'invalid-file.json'))
$noArgumentsFile = Run-WithErrorFile 'pwsh-file' { & pwsh -NoLogo -NoProfile -NonInteractive -File $guard @fileArguments }
Assert-StructuredLauncherFailure $noArgumentsFile 'pwsh -File' 'invalid-input' 10
Assert-HostSafetyBoundary 'structured launcher failures'
$nested = Join-Path $installRoot 'package/core/distribution/guard.ps1'
$nestedResult = Run $nested @('-PrerequisiteReportPath',(Join-Path $runRoot 'nested.json'),'version')
if ($nestedResult.Code -ne 10 -or $nestedResult.Text -notmatch 'non-public-entrypoint') { $failures.Add("Nested launcher did not fail with non-public-entrypoint: $($nestedResult.Text)") }
Assert-HostSafetyBoundary 'nested entrypoint refusal'
if (-not $IsWindows) {
    $hostMode = [IO.File]::GetUnixFileMode([string]$layout.HostPath)
    $companionMode = [IO.File]::GetUnixFileMode([string]$layout.CompanionPath)
    if (($hostMode -band [IO.UnixFileMode]::UserExecute) -eq 0 -or ($companionMode -band [IO.UnixFileMode]::UserExecute) -eq 0) {
        $failures.Add('Installed self-contained Linux apphosts are not executable.')
    }
}

$hostBytes = [IO.File]::ReadAllBytes([string]$layout.HostPath)
[IO.File]::AppendAllText([string]$layout.HostPath,'drift',[Text.UTF8Encoding]::new($false))
$tampered = Run $guard @('-PrerequisiteReportPath',(Join-Path $runRoot 'tampered.json'),'version')
if ($tampered.Code -ne 12 -or $tampered.Text -notmatch 'file drift') { $failures.Add("Tampered apphost was not rejected: $($tampered.Text)") }
[IO.File]::WriteAllBytes([string]$layout.HostPath,$hostBytes)
Assert-HostSafetyBoundary 'tamper refusal'

$invalidWeb = Run $guardWeb @('-Profile','default','-PrerequisiteReportPath',(Join-Path $runRoot 'web.json'),'--command','injected')
if ($invalidWeb.Code -ne 10 -or $invalidWeb.Text -notmatch 'refuses Companion option') { $failures.Add("Companion option injection was not rejected: $($invalidWeb.Text)") }
Assert-HostSafetyBoundary 'Web launcher refusal'

$relocated = Join-Path $runRoot "relocated/v4-guards-$productVersion"
[void][IO.Directory]::CreateDirectory((Split-Path -Parent $relocated))
Move-Item -LiteralPath $installRoot -Destination $relocated
$relocatedVersion = Run (Join-Path $relocated 'package/guard.ps1') @('-PrerequisiteReportPath',(Join-Path $runRoot 'relocated.json'),'version')
if ($relocatedVersion.Code -ne 0) { $failures.Add("Complete verified relocation failed: $($relocatedVersion.Text)") }
Assert-HostSafetyBoundary 'relocated public launcher'

Move-Item -LiteralPath $relocated -Destination $installRoot
$uninstall = Run $installer @('-Mode','Uninstall','-InstallRoot',$installRoot,'-ReceiptPath',$receipt)
if ($uninstall.Code -ne 0 -or [IO.Directory]::Exists($installRoot)) { $failures.Add("Verified cleanup failed: $($uninstall.Text)") }
Assert-HostSafetyBoundary 'verified cleanup'

$hostSafetyAfter = Get-HostSafetySnapshot
$safetyDrift = @($hostSafetyBefore.Keys | Where-Object { $hostSafetyBefore[$_] -cne $hostSafetyAfter[$_] })
if ($safetyDrift.Count) {
    throw "BLOCKED — HOST SAFETY INCIDENT: install, launcher or cleanup changed host-owned environment/profile state ($($safetyDrift -join ', '))."
}

if ($failures.Count) { throw ($failures -join "`n") }
Write-Host "M1 installed launcher tests passed for ${rid}: manifest-bound InstallRoot refusal, both public invocation styles, native apphost, operation-aware prerequisites, integrity refusal, relocation, verified cleanup and unchanged environment/profile hashes."
