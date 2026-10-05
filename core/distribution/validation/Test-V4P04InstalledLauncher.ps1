[CmdletBinding()]
param([Parameter(Mandatory)][string] $ArchivePath)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$packageRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$archive = (Resolve-Path -LiteralPath $ArchivePath).Path
$plugin = Get-Content -Raw -LiteralPath (Join-Path $packageRoot 'plugin.json') | ConvertFrom-Json
$runRoot = Join-Path ([IO.Path]::GetTempPath()) ('v4-p04 public launcher ' + [Guid]::NewGuid().ToString('N'))
$installRoot = Join-Path $runRoot "installed/v4-guards-$($plugin.version)"
$targetRoot = Join-Path $runRoot 'target with spaces'
$stateRoot = Join-Path $runRoot 'state'
$evidenceRoot = Join-Path $runRoot 'evidence'
$otherCwd = Join-Path $runRoot 'unrelated working directory'
$receiptPath = Join-Path $runRoot 'receipts/install.json'
$installer = Join-Path $packageRoot 'core/distribution/Install-V4Distribution.ps1'
$process = $null
$installed = $false
$failure = $null

function Hash-Text([string] $Text) {
    [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($Text))).ToLowerInvariant()
}
function Safety-Snapshot {
    $result = [ordered]@{}
    foreach ($scope in @('User','Machine')) {
        $values = [Environment]::GetEnvironmentVariables([EnvironmentVariableTarget]::$scope)
        $result[$scope] = Hash-Text ((@($values.Keys | Sort-Object | ForEach-Object { "$_=$($values[$_])" })) -join "`n")
    }
    $result.ProcessPath = Hash-Text ([string]$env:PATH)
    $result.Profiles = @($PROFILE.AllUsersAllHosts,$PROFILE.AllUsersCurrentHost,$PROFILE.CurrentUserAllHosts,$PROFILE.CurrentUserCurrentHost | ForEach-Object {
        if ([IO.File]::Exists($_)) { (Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash } else { 'absent' }
    })
    $result | ConvertTo-Json -Compress
}
function Tree-Hash([string] $Root) {
    Hash-Text ((@(Get-ChildItem -LiteralPath $Root -File -Recurse -Force | Sort-Object FullName | ForEach-Object {
        "$([IO.Path]::GetRelativePath($Root,$_.FullName).Replace('\','/')):$((Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash)"
    })) -join "`n")
}
function New-LauncherStart([switch] $CallOperator) {
    $start = [Diagnostics.ProcessStartInfo]::new((Get-Command pwsh -ErrorAction Stop).Source)
    $start.UseShellExecute = $false; $start.RedirectStandardOutput = $true; $start.RedirectStandardError = $true; $start.CreateNoWindow = $true
    $start.WorkingDirectory = $otherCwd
    $scriptPath = Join-Path $installRoot 'package/guard-web.ps1'
    # Omit --port in both modes and exercise the public entry from another cwd.
    $arguments = @('-Profile','synthetic_profile','-PrerequisiteReportPath',(Join-Path $evidenceRoot 'prerequisites.json'),
        '--target-root',$targetRoot,'--state-root',$stateRoot,'--evidence-root',$evidenceRoot,'--plan-root','plans')
    foreach ($argument in @('-NoLogo','-NoProfile','-NonInteractive')) { [void]$start.ArgumentList.Add($argument) }
    if ($CallOperator) {
        $tokens = [Collections.Generic.List[string]]::new()
        $tokens.Add("'" + $scriptPath.Replace("'","''") + "'")
        for ($i=0; $i -lt $arguments.Count; $i+=2) {
            $tokens.Add($arguments[$i]); $tokens.Add("'" + $arguments[$i+1].Replace("'","''") + "'")
        }
        [void]$start.ArgumentList.Add('-EncodedCommand')
        [void]$start.ArgumentList.Add([Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes('& ' + ($tokens -join ' '))))
    } else {
        [void]$start.ArgumentList.Add('-File'); [void]$start.ArgumentList.Add($scriptPath)
        foreach ($argument in $arguments) { [void]$start.ArgumentList.Add($argument) }
    }
    $start
}
function Stop-TestCompanion {
    if ($null -ne $script:process) {
        if (-not $script:process.HasExited) { $script:process.Kill($true); [void]$script:process.WaitForExit(10000) }
        $script:process.Dispose(); $script:process = $null
    }
}

$safetyBefore = Safety-Snapshot
try {
    foreach ($path in @($runRoot,$targetRoot,(Join-Path $targetRoot 'plans'),$stateRoot,$evidenceRoot,$otherCwd,(Split-Path -Parent $receiptPath))) {
        [void][IO.Directory]::CreateDirectory($path)
    }
    [IO.File]::WriteAllText((Join-Path $targetRoot 'input.txt'),"synthetic-ok`n",[Text.UTF8Encoding]::new($false))
    $install = @(& pwsh -NoLogo -NoProfile -NonInteractive -File $installer -Mode Install -ArchivePath $archive -InstallRoot $installRoot -ReceiptPath $receiptPath 2>&1)
    if ($LASTEXITCODE) { throw "Install failed: $($install -join "`n")" }
    $installed = $true
    $packageBefore = Tree-Hash (Join-Path $installRoot 'package'); $targetBefore = Tree-Hash $targetRoot
    foreach ($callOperator in @($false,$true)) {
        $process = [Diagnostics.Process]::new(); $process.StartInfo = New-LauncherStart -CallOperator:$callOperator
        if (-not $process.Start()) { throw 'Public launcher did not start.' }
        $readyTask = $process.StandardOutput.ReadLineAsync()
        if (-not $readyTask.Wait([TimeSpan]::FromSeconds(45))) { throw 'Public launcher readiness timed out.' }
        $line = $readyTask.Result
        if (-not $line) { throw "Public launcher produced no ready report: $($process.StandardError.ReadToEnd())" }
        $ready = $line | ConvertFrom-Json
        if ($ready.status -cne 'ready' -or $ready.address -notmatch '^http://127\.0\.0\.1:[0-9]+$' -or ([Uri]$ready.address).Port -le 0) { throw "Invalid ready report: $line" }
        $expectedRoots = @{PackageRoot=(Join-Path $installRoot 'package');TargetRoot=$targetRoot;StateRoot=$stateRoot;EvidenceRoot=$evidenceRoot}
        foreach ($name in $expectedRoots.Keys) {
            $actual = @($ready.roots | Where-Object name -ceq $name)
            if ($actual.Count -ne 1 -or [IO.Path]::GetFullPath($actual[0].path) -cne [IO.Path]::GetFullPath($expectedRoots[$name])) { throw "Ready root mismatch: $name" }
        }
        $client = [Net.Http.HttpClient]::new()
        try {
            $session = $client.GetStringAsync("$($ready.address)/api/v1/session").GetAwaiter().GetResult() | ConvertFrom-Json
            if ($session.authority -cne 'v4-host') { throw 'Public launcher did not preserve Host authority.' }
        } finally { $client.Dispose(); Stop-TestCompanion }
    }
    if ((Tree-Hash (Join-Path $installRoot 'package')) -cne $packageBefore -or (Tree-Hash $targetRoot) -cne $targetBefore) { throw 'Public launch changed PackageRoot or TargetRoot.' }
} catch { $failure = $_.Exception.Message }
finally {
    Stop-TestCompanion
    if ($installed) {
        $uninstall = @(& pwsh -NoLogo -NoProfile -NonInteractive -File $installer -Mode Uninstall -InstallRoot $installRoot -ReceiptPath $receiptPath 2>&1)
        if ($LASTEXITCODE -or (Test-Path -LiteralPath $installRoot)) { $failure = "Verified uninstall failed: $($uninstall -join "`n")" }
    }
    if ((Safety-Snapshot) -cne $safetyBefore) { $failure = 'HOST SAFETY INCIDENT: environment, Process PATH or Profile baseline changed.' }
}
if ($failure) { throw $failure }
Write-Host "V4 P04 installed public launcher passed: -File/call operator, omitted port, spaces, alternate cwd, actual roots, host safety and verified uninstall. Evidence: $runRoot"
