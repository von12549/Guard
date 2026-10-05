[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$sourceRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$preflight = Join-Path $sourceRoot 'core/distribution/Invoke-V4Preflight.ps1'
$packageCheck = Join-Path $sourceRoot 'core/runtime/Test-V4Package.ps1'
$package = & $packageCheck -PackageRoot $sourceRoot | ConvertFrom-Json
if ($package.status -cne 'pass') { throw 'Source package did not validate before preflight tests.' }
$version = (Get-Content -Raw -LiteralPath (Join-Path $sourceRoot 'plugin.json') | ConvertFrom-Json).version
$tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$runRoot = Join-Path $tempRoot ('v4-p04 preflight ' + [Guid]::NewGuid().ToString('N'))
$target = Join-Path $runRoot 'target with spaces'
$unrelated = Join-Path $runRoot 'unrelated workspace'
$failures = [Collections.Generic.List[string]]::new()

function Invoke-Preflight([string] $Mode, [string] $Report, [string] $Baseline = '', [string[]] $Workspaces = @(), [string] $Version = $version) {
    $args = @('-Mode',$Mode,'-RunRoot',$runRoot,'-PackageRoot',$sourceRoot,'-TargetRoot',$target,
        '-StateRoot','state','-EvidenceRoot','evidence','-ReceiptPath','receipts/install.json',
        '-ReportPath',$Report,'-ExpectedVersion',$Version,'-ExpectedPackageHash',$package.packageHash)
    if ($Baseline) { $args += @('-BaselineReportPath',$Baseline) }
    if ($Workspaces.Count) { $args += @('-OpenWorkspaceRoots',$Workspaces) }
    $output = & pwsh -NoProfile -File $preflight @args 2>&1
    [pscustomobject]@{ Code=$LASTEXITCODE; Output=($output -join "`n") }
}

try {
    [void][IO.Directory]::CreateDirectory($target)
    [void][IO.Directory]::CreateDirectory($unrelated)
    [void][IO.Directory]::CreateDirectory((Join-Path $runRoot 'reports'))
    [IO.File]::WriteAllText((Join-Path $target 'project.csproj'),'<Project Sdk="Microsoft.NET.Sdk" />',[Text.UTF8Encoding]::new($false))
    & git -C $target init --quiet
    if ($LASTEXITCODE) { throw 'Synthetic Target Git init failed.' }
    & git -C $target add -- project.csproj
    if ($LASTEXITCODE) { throw 'Synthetic Target Git add failed.' }
    & git -C $target -c user.name=GuardTest -c user.email=guard-test@example.invalid commit --quiet -m fixture
    if ($LASTEXITCODE) { throw 'Synthetic Target Git commit failed.' }

    Push-Location $unrelated
    try { $preview = Invoke-Preflight 'Preview' 'reports/preview.json' '' @($unrelated) }
    finally { Pop-Location }
    $previewPath = Join-Path $runRoot 'reports/preview.json'
    if ($preview.Code -ne 0 -or -not [IO.File]::Exists($previewPath)) { $failures.Add("Different-cwd Preview failed: $($preview.Output)") }
    else {
        $document = Get-Content -Raw -LiteralPath $previewPath | ConvertFrom-Json
        if ($document.passed -ne $true -or $document.safety.equal -ne $true -or $document.target.equal -ne $true -or
            $document.roots.targetRoot -cne $target -or $document.ideRisk.reportedTargetOrAncestorWorkspace -ne $false -or
            @($document.steps | Where-Object { $null -eq $_.passed }).Count -gt 0) {
            $failures.Add('Preview report omitted a safety boolean, misresolved roots or blocked unrelated IDE workspace.')
        }
    }
    if ([IO.Directory]::Exists((Join-Path $runRoot 'state')) -or [IO.Directory]::Exists((Join-Path $runRoot 'evidence'))) {
        $failures.Add('Preview created StateRoot or EvidenceRoot.')
    }

    $prepare = Invoke-Preflight 'Prepare' 'evidence/preflight-report.json'
    $baselinePath = Join-Path $runRoot 'evidence/preflight-report.json'
    if ($prepare.Code -ne 0 -or -not [IO.File]::Exists($baselinePath)) { $failures.Add("Prepare failed: $($prepare.Output)") }
    else {
        $baseline = Get-Content -Raw -LiteralPath $baselinePath | ConvertFrom-Json
        if ($baseline.passed -ne $true -or $baseline.safety.equal -ne $true -or $baseline.target.equal -ne $true) {
            $failures.Add('Prepare did not record a complete passing baseline.')
        }
    }
    $checkpoint = Invoke-Preflight 'Checkpoint' 'evidence/checkpoint.json' 'evidence/preflight-report.json' @($target)
    if ($checkpoint.Code -ne 0 -or (Get-Content -Raw -LiteralPath (Join-Path $runRoot 'evidence/checkpoint.json') | ConvertFrom-Json).ideRisk.reportedTargetOrAncestorWorkspace -ne $true) {
        $failures.Add("Checkpoint failed to preserve baseline or identify reported Target workspace: $($checkpoint.Output)")
    }

    $badVersion = Invoke-Preflight 'Preview' 'reports/bad-version.json' '' @() '0.0.0'
    $badReport = Get-Content -Raw -LiteralPath (Join-Path $runRoot 'reports/bad-version.json') | ConvertFrom-Json
    if ($badVersion.Code -eq 0 -or $badReport.passed -ne $false -or $badReport.safety.equal -ne $true -or
        @($badReport.steps | Where-Object id -eq 'preflight-failure').Count -ne 1) {
        $failures.Add('Version fault did not leave a complete fail-closed report with after-safety evidence.')
    }

    [IO.File]::WriteAllText((Join-Path $target 'generated.bin'),'unexpected',[Text.UTF8Encoding]::new($false))
    $drift = Invoke-Preflight 'Checkpoint' 'evidence/target-drift.json' 'evidence/preflight-report.json'
    $driftReport = Get-Content -Raw -LiteralPath (Join-Path $runRoot 'evidence/target-drift.json') | ConvertFrom-Json
    if ($drift.Code -eq 0 -or $driftReport.passed -ne $false -or $driftReport.error -notmatch 'drift') {
        $failures.Add('Target ordinary drift was not detected and retained.')
    }
    if (-not [IO.File]::Exists((Join-Path $target 'generated.bin'))) { $failures.Add('Drift handling removed the generated Target file.') }
}
finally {
    $resolved = [IO.Path]::GetFullPath($runRoot)
    if (-not $resolved.StartsWith($tempRoot,[StringComparison]::OrdinalIgnoreCase) -or
        -not [IO.Path]::GetFileName($resolved).StartsWith('v4-p04 preflight ',[StringComparison]::Ordinal)) {
        throw 'Refusing to clean an unexpected preflight test directory.'
    }
    if ([IO.Directory]::Exists($resolved)) { Remove-Item -LiteralPath $resolved -Recurse -Force }
}
if ($failures.Count) { throw "Preflight regressions failed:`n - $($failures -join "`n - ")" }
Write-Host 'P04 preflight regressions passed: independent safety and Target baselines, different cwd, spaces, IDE scope, explicit prepare and fail-closed faults.'
