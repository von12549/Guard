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

function Run([string] $Script, [string[]] $Arguments) {
    $output = @(& pwsh -NoLogo -NoProfile -NonInteractive -File $Script @Arguments 2>&1)
    [pscustomobject]@{ Code=$LASTEXITCODE; Text=($output -join "`n") }
}

$publish = Run $publisher @('-PackageRoot',$packageRoot,'-RuntimeIdentifier',$rid,'-OutputDirectory',(Join-Path $runRoot 'publish'),'-MeasurementPath',(Join-Path $runRoot 'measurement.json'),'-SourceCommit',$sourceCommit)
if ($publish.Code -ne 0) { throw "Self-contained publish failed: $($publish.Text)" }
$archive = [string](($publish.Text | ConvertFrom-Json).archivePath)
$installRoot = Join-Path $runRoot "installed/v4-guards-$productVersion"
$receipt = Join-Path $runRoot 'receipts/install.json'
$install = Run $installer @('-Mode','Install','-ArchivePath',$archive,'-InstallRoot',$installRoot,'-ReceiptPath',$receipt)
if ($install.Code -ne 0) { throw "Install failed: $($install.Text)" }
$guard = Join-Path $installRoot 'package/guard.ps1'
$guardWeb = Join-Path $installRoot 'package/guard-web.ps1'
if (-not [IO.File]::Exists($guard) -or -not [IO.File]::Exists($guardWeb)) { $failures.Add('Package-root launchers are missing.') }

$oldPath = $env:PATH
try {
    $env:PATH = $PSHOME
    $versionReport = Join-Path $runRoot 'version-prerequisites.json'
    $version = Run $guard @('-Profile','default','-PrerequisiteReportPath',$versionReport,'version')
    if ($version.Code -ne 0) { $failures.Add("Installed self-contained Host launcher failed without dotnet on PATH: $($version.Text)") }
    else {
        $versionDocument = $version.Text | ConvertFrom-Json
        if ($versionDocument.status -cne 'pass' -or $versionDocument.command -cne 'version') { $failures.Add('Installed Host launcher returned an invalid version result.') }
        $prerequisites = Get-Content -Raw -LiteralPath $versionReport | ConvertFrom-Json
        if (@($prerequisites.requirements | Where-Object runtime -eq 'dotnet').Count -ne 0) { $failures.Add('Self-contained default Profile still required Host-owned dotnet.') }
    }
} finally { $env:PATH = $oldPath }

$internal = Join-Path $installRoot 'package/core/distribution/Invoke-V4Installed.ps1'
$mismatch = Run $internal @('-PackageRoot',(Join-Path $runRoot 'wrong-package'),'-Profile','default','-PrerequisiteReportPath',(Join-Path $runRoot 'mismatch.json'),'-HostArgumentsJson','["version"]')
if ($mismatch.Code -ne 11 -or $mismatch.Text -notmatch 'override does not match') { $failures.Add("PackageRoot override mismatch was not rejected: $($mismatch.Text)") }

$layoutScript = Join-Path $installRoot 'package/core/distribution/Resolve-V4InstalledLayout.ps1'
. $layoutScript
$layout = Resolve-V4InstalledLayout -PackageRoot (Join-Path $installRoot 'package') -RequireCompanion
if (-not $layout.SelfContained -or [IO.Path]::GetExtension([string]$layout.HostPath) -cne $(if ($IsWindows) { '.exe' } else { '' })) {
    $failures.Add('Installed layout did not select the native self-contained apphost.')
}
if (-not $IsWindows) {
    $hostMode = [IO.File]::GetUnixFileMode([string]$layout.HostPath)
    $companionMode = [IO.File]::GetUnixFileMode([string]$layout.CompanionPath)
    if (($hostMode -band [IO.UnixFileMode]::UserExecute) -eq 0 -or ($companionMode -band [IO.UnixFileMode]::UserExecute) -eq 0) {
        $failures.Add('Installed self-contained Linux apphosts are not executable.')
    }
}

$hostBytes = [IO.File]::ReadAllBytes([string]$layout.HostPath)
[IO.File]::AppendAllText([string]$layout.HostPath,'drift',[Text.UTF8Encoding]::new($false))
$tampered = Run $guard @('-Profile','default','-PrerequisiteReportPath',(Join-Path $runRoot 'tampered.json'),'version')
if ($tampered.Code -ne 12 -or $tampered.Text -notmatch 'file drift') { $failures.Add("Tampered apphost was not rejected: $($tampered.Text)") }
[IO.File]::WriteAllBytes([string]$layout.HostPath,$hostBytes)

$invalidWeb = Run $guardWeb @('-Profile','default','-PrerequisiteReportPath',(Join-Path $runRoot 'web.json'),'--command','injected')
if ($invalidWeb.Code -ne 10 -or $invalidWeb.Text -notmatch 'refuses Companion option') { $failures.Add("Companion option injection was not rejected: $($invalidWeb.Text)") }

$relocated = Join-Path $runRoot "relocated/v4-guards-$productVersion"
[void][IO.Directory]::CreateDirectory((Split-Path -Parent $relocated))
Move-Item -LiteralPath $installRoot -Destination $relocated
$relocatedVersion = Run (Join-Path $relocated 'package/guard.ps1') @('-Profile','default','-PrerequisiteReportPath',(Join-Path $runRoot 'relocated.json'),'version')
if ($relocatedVersion.Code -ne 0) { $failures.Add("Complete verified relocation failed: $($relocatedVersion.Text)") }

if ($failures.Count) { throw ($failures -join "`n") }
Write-Host "M1 installed launcher tests passed for ${rid}: derived PackageRoot, native apphost, no Host dotnet prerequisite, integrity refusal and verified relocation."
