[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('Preview','Prepare','Checkpoint')][string] $Mode,
    [Parameter(Mandatory)][string] $RunRoot,
    [Parameter(Mandatory)][string] $PackageRoot,
    [Parameter(Mandatory)][string] $TargetRoot,
    [Parameter(Mandatory)][string] $StateRoot,
    [Parameter(Mandatory)][string] $EvidenceRoot,
    [Parameter(Mandatory)][string] $ReceiptPath,
    [Parameter(Mandatory)][string] $ReportPath,
    [Parameter(Mandatory)][string] $ExpectedVersion,
    [Parameter(Mandatory)][ValidatePattern('^[a-f0-9]{64}$')][string] $ExpectedPackageHash,
    [string[]] $OpenWorkspaceRoots = @(),
    [string] $BaselineReportPath = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Hash-Text([string] $Value) {
    [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($Value))).ToLowerInvariant()
}
function Snapshot {
    $environments = @{}
    foreach ($scope in @('User','Machine')) {
        $values = [Environment]::GetEnvironmentVariables([EnvironmentVariableTarget]::$scope)
        $pairs = @($values.Keys | Sort-Object | ForEach-Object { "$_=$($values[$_])" })
        $environments[$scope] = Hash-Text ($pairs -join "`n")
    }
    $profileNames = @('all-users-all-hosts','all-users-current-host','current-user-all-hosts','current-user-current-host')
    $profilePaths = @($PROFILE.AllUsersAllHosts,$PROFILE.AllUsersCurrentHost,$PROFILE.CurrentUserAllHosts,$PROFILE.CurrentUserCurrentHost)
    $profiles = @()
    for ($i=0; $i -lt 4; $i++) {
        $exists = [IO.File]::Exists($profilePaths[$i])
        $profiles += [ordered]@{
            scope = $profileNames[$i]
            exists = [bool]$exists
            sha256 = if ($exists) { (Get-FileHash -LiteralPath $profilePaths[$i] -Algorithm SHA256).Hash.ToLowerInvariant() } else { $null }
        }
    }
    [ordered]@{
        userEnvironmentSha256 = $environments.User
        machineEnvironmentSha256 = $environments.Machine
        processPathSha256 = Hash-Text ([string]$env:PATH)
        profiles = $profiles
    }
}
function Step([string] $Id, [bool] $Passed, [string] $Result, [string] $EvidencePath = '', [string] $EvidenceSha256 = '') {
    $script:steps.Add([ordered]@{
        id = $Id; atUtc = [DateTimeOffset]::UtcNow.ToString('O'); passed = [bool]$Passed
        result = $Result; evidencePath = if ($EvidencePath) { $EvidencePath } else { $null }
        evidenceSha256 = if ($EvidenceSha256) { $EvidenceSha256 } else { $null }
    })
}
function Is-Under([string] $Path, [string] $Root) {
    $relative = [IO.Path]::GetRelativePath($Root,$Path)
    $relative -eq '.' -or (-not [IO.Path]::IsPathRooted($relative) -and $relative -ne '..' -and
        -not $relative.StartsWith("..$([IO.Path]::DirectorySeparatorChar)",[StringComparison]::Ordinal))
}
function Assert-NoLinks([string] $Path) {
    $probe = $Path
    while (-not ([IO.Directory]::Exists($probe) -or [IO.File]::Exists($probe))) {
        $parent = [IO.Path]::GetDirectoryName($probe)
        if (-not $parent -or $parent -eq $probe) { throw "Path parent cannot be resolved: $Path" }
        $probe = $parent
    }
    while ($probe) {
        $item = Get-Item -LiteralPath $probe -Force
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or $null -ne $item.LinkTarget) {
            throw "Path crosses a link or reparse point: $probe"
        }
        $parent = [IO.Path]::GetDirectoryName($probe)
        if (-not $parent -or $parent -eq $probe) { break }
        $probe = $parent
    }
}
function Resolve-Root([string] $Value, [string] $Label) {
    if ([string]::IsNullOrWhiteSpace($Value)) { throw "$Label is empty." }
    $isAbsolute = [IO.Path]::IsPathFullyQualified($Value)
    $resolved = [IO.Path]::TrimEndingDirectorySeparator([IO.Path]::GetFullPath(
        $(if ($isAbsolute) { $Value } else { [IO.Path]::Combine($script:resolvedRunRoot,$Value) })))
    if (-not $isAbsolute -and -not (Is-Under $resolved $script:resolvedRunRoot)) {
        throw "$Label escapes RunRoot."
    }
    if ($resolved -eq [IO.Path]::GetPathRoot($resolved)) { throw "$Label cannot be a filesystem root." }
    Assert-NoLinks $resolved
    $resolved
}
function Assert-EmptyOrMissing([string] $Path, [string] $Label) {
    if ([IO.File]::Exists($Path)) { throw "$Label is a file." }
    if ([IO.Directory]::Exists($Path) -and @(Get-ChildItem -LiteralPath $Path -Force).Count -gt 0) {
        throw "$Label already contains files; select a new run directory."
    }
}
function Snapshot-Target([string] $Path) {
    $head = & git -C $Path rev-parse HEAD
    if ($LASTEXITCODE -ne 0 -or @($head).Count -ne 1) { throw 'Target Git HEAD could not be read.' }
    $ordinary = @(& git -C $Path status --porcelain=v1 --untracked-files=all)
    if ($LASTEXITCODE -ne 0) { throw 'Target ordinary status could not be read.' }
    $ignored = @(& git -C $Path ls-files --others --ignored --exclude-standard)
    if ($LASTEXITCODE -ne 0) { throw 'Target ignored inventory could not be read.' }
    [ordered]@{
        head = [string]$head; ordinaryCount = $ordinary.Count; ordinarySha256 = Hash-Text ($ordinary -join "`n")
        ignoredCount = $ignored.Count; ignoredSha256 = Hash-Text ($ignored -join "`n")
    }
}

$steps = [Collections.Generic.List[object]]::new()
$before = Snapshot
$after = $null
$errorText = $null
$packageHash = $null
$resolved = $null
$targetBefore = $null
$targetAfter = $null
$ideRisk = $null
$externalBaseline = $null
Step 'safety-before' $true 'Hash-only baseline captured before package or tool invocation.'
try {
    if (-not [IO.Path]::IsPathFullyQualified($RunRoot)) { throw 'RunRoot must be an explicit absolute path.' }
    $resolvedRunRoot = [IO.Path]::TrimEndingDirectorySeparator([IO.Path]::GetFullPath($RunRoot))
    if (-not [IO.Directory]::Exists($resolvedRunRoot)) { throw 'RunRoot does not exist.' }
    Assert-NoLinks $resolvedRunRoot
    $package = Resolve-Root $PackageRoot 'PackageRoot'
    $target = Resolve-Root $TargetRoot 'TargetRoot'
    $state = Resolve-Root $StateRoot 'StateRoot'
    $evidence = Resolve-Root $EvidenceRoot 'EvidenceRoot'
    $receipt = Resolve-Root $ReceiptPath 'ReceiptPath'
    $report = Resolve-Root $ReportPath 'ReportPath'
    if (($Mode -ne 'Checkpoint' -and -not [IO.Directory]::Exists($package)) -or -not [IO.Directory]::Exists($target)) {
        throw 'The required PackageRoot or TargetRoot is missing.'
    }
    $roots = @($package,$target,$state,$evidence)
    for ($i=0; $i -lt $roots.Count; $i++) {
        for ($j=$i+1; $j -lt $roots.Count; $j++) {
            if ((Is-Under $roots[$i] $roots[$j]) -or (Is-Under $roots[$j] $roots[$i])) {
                throw 'Package, Target, State and Evidence roots must be pairwise disjoint.'
            }
        }
    }
    foreach ($path in @($receipt,$report)) {
        if ((Is-Under $path $package) -or (Is-Under $path $target)) {
            throw 'Receipt and report must be outside PackageRoot and TargetRoot.'
        }
    }
    if ($report -eq $receipt -or [IO.File]::Exists($report) -or ($Mode -ne 'Checkpoint' -and [IO.File]::Exists($receipt))) {
        throw 'Report or receipt already exists; use fresh output paths.'
    }
    $resolved = [ordered]@{ packageRoot=$package; targetRoot=$target; stateRoot=$state; evidenceRoot=$evidence; receiptPath=$receipt; reportPath=$report }
    Step 'topology' $true 'Absolute, link-free, non-overlapping roots and fresh outputs validated.'
    $targetBefore = Snapshot-Target $target
    Step 'target-before' $true 'Target ordinary and ignored inventories captured as counts and hashes.'
    if ($Mode -eq 'Checkpoint') {
        if (-not $BaselineReportPath) { throw 'Checkpoint requires BaselineReportPath.' }
        $baselinePath = Resolve-Root $BaselineReportPath 'BaselineReportPath'
        if (-not [IO.File]::Exists($baselinePath)) { throw 'Baseline report is missing.' }
        $externalBaseline = Get-Content -Raw -LiteralPath $baselinePath | ConvertFrom-Json
        if ($externalBaseline.passed -cne $true -or $externalBaseline.safety.equal -cne $true -or
            $externalBaseline.target.equal -cne $true -or @($externalBaseline.steps | Where-Object { $_.passed -cne $true }).Count -gt 0) {
            throw 'Baseline report is incomplete or failed.'
        }
        $safetyMatches = ($externalBaseline.safety.before | ConvertTo-Json -Depth 12 -Compress) -ceq ($before | ConvertTo-Json -Depth 12 -Compress)
        $targetMatches = ($externalBaseline.target.before | ConvertTo-Json -Compress) -ceq ($targetBefore | ConvertTo-Json -Compress)
        Step 'external-baseline-before' ([bool]($safetyMatches -and $targetMatches))
            $(if ($safetyMatches -and $targetMatches) { 'Original host and Target baselines still match.' } else { 'Original host or Target baseline drifted; stop.' })
        if (-not ($safetyMatches -and $targetMatches)) { throw 'Original host or Target baseline drifted.' }
    }
    $reportedWorkspaceOverlap = $false
    foreach ($workspace in $OpenWorkspaceRoots) {
        $openRoot = Resolve-Root $workspace 'OpenWorkspaceRoot'
        if ((Is-Under $target $openRoot) -or (Is-Under $openRoot $target)) { $reportedWorkspaceOverlap = $true }
    }
    $codeCount = @(Get-Process -Name Code -ErrorAction SilentlyContinue).Count
    $ideRisk = [ordered]@{
        codeProcessCount = $codeCount; reportedTargetOrAncestorWorkspace = [bool]$reportedWorkspaceOverlap
        assessment = if ($reportedWorkspaceOverlap) { 'target-workspace-reported' } elseif ($codeCount -gt 0) { 'workspace-unknown' } else { 'no-code-process-observed' }
        guidance = if ($reportedWorkspaceOverlap) { 'Pause automated scanning or building of the Target; preserve any drift evidence.' }
            elseif ($codeCount -gt 0) { 'Process names do not reveal every open workspace. Confirm the Target is not being scanned or built.' }
            else { 'Continue Target ordinary and ignored drift checks; process absence is not proof of immutability.' }
    }
    Step 'ide-risk' $true $ideRisk.guidance

    if ($Mode -eq 'Checkpoint') {
        Step 'package-identity' $true 'Checkpoint retains the previously verified package identity; no package operation was invoked.'
        Step 'directories' $true 'Checkpoint created no StateRoot, EvidenceRoot or receipt directory.'
    } else {
        $pluginPath = Join-Path $package 'plugin.json'
        $packageCheck = Join-Path $package 'core/runtime/Test-V4Package.ps1'
        if (-not [IO.File]::Exists($pluginPath) -or -not [IO.File]::Exists($packageCheck)) { throw 'Package identity files are missing.' }
        $plugin = Get-Content -Raw -LiteralPath $pluginPath | ConvertFrom-Json
        if ($plugin.version -cne $ExpectedVersion) { throw "Package version mismatch: expected $ExpectedVersion." }
        $check = & $packageCheck -PackageRoot $package | ConvertFrom-Json
        if ($check.status -cne 'pass' -or $check.packageHash -cne $ExpectedPackageHash) {
            throw 'Package validation or expected package hash mismatch.'
        }
        $packageHash = $check.packageHash
        Step 'package-identity' $true 'Version and complete package authority match expected immutable identities.' $pluginPath ((Get-FileHash -LiteralPath $pluginPath -Algorithm SHA256).Hash.ToLowerInvariant())

        Assert-EmptyOrMissing $state 'StateRoot'
        Assert-EmptyOrMissing $evidence 'EvidenceRoot'
        if ($Mode -eq 'Prepare') {
            [void][IO.Directory]::CreateDirectory($state)
            [void][IO.Directory]::CreateDirectory($evidence)
            [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($receipt))
            Step 'directories' $true 'Fresh StateRoot, EvidenceRoot and receipt parent prepared without adopting Target.'
        } else {
            Step 'directories' $true 'Preview only; no StateRoot, EvidenceRoot or receipt directory created.'
        }
    }
} catch {
    $errorText = $_.Exception.Message
    Step 'preflight-failure' $false $errorText
} finally {
    try {
        if ($resolved -and $targetBefore) {
            $targetAfter = Snapshot-Target $resolved.targetRoot
            $targetEqual = ($targetBefore | ConvertTo-Json -Compress) -ceq ($targetAfter | ConvertTo-Json -Compress)
            if ($externalBaseline) {
                $targetEqual = $targetEqual -and (($externalBaseline.target.before | ConvertTo-Json -Compress) -ceq ($targetAfter | ConvertTo-Json -Compress))
            }
            Step 'target-after' ([bool]$targetEqual) $(if ($targetEqual) { 'Target HEAD, ordinary and ignored inventories unchanged.' } else { 'Target drift detected; preserve files and process/time evidence before attribution.' })
            if (-not $targetEqual) { $errorText = 'Target drift detected; stop and preserve evidence.' }
        }
        $after = Snapshot
        $equal = ($before | ConvertTo-Json -Depth 12 -Compress) -ceq ($after | ConvertTo-Json -Depth 12 -Compress)
        if ($externalBaseline) {
            $equal = $equal -and (($externalBaseline.safety.before | ConvertTo-Json -Depth 12 -Compress) -ceq ($after | ConvertTo-Json -Depth 12 -Compress))
        }
        Step 'safety-after' ([bool]$equal) $(if ($equal) { 'Host environment, Process PATH and four Profiles unchanged.' } else { 'HOST SAFETY INCIDENT: hash-only baseline changed; stop and preserve evidence.' })
        if (-not $equal) { $errorText = 'HOST SAFETY INCIDENT: environment or Profile drift detected.' }
    } catch {
        $errorText = 'Safety comparison failed: ' + $_.Exception.Message
        Step 'safety-after' $false $errorText
    }
    $passed = -not $errorText -and $null -ne $after -and @($steps | Where-Object { -not $_.passed }).Count -eq 0
    $record = [ordered]@{
        formatVersion=1; status=$(if ($passed) {'pass'} else {'fail'}); mode=$Mode
        atUtc=[DateTimeOffset]::UtcNow.ToString('O'); passed=[bool]$passed
        expectedVersion=$ExpectedVersion; expectedPackageHash=$ExpectedPackageHash
        packageHash=$packageHash; roots=$resolved; steps=@($steps)
        target=[ordered]@{ before=$targetBefore; after=$targetAfter; equal=[bool]($targetBefore -and $targetAfter -and (($targetBefore | ConvertTo-Json -Compress) -ceq ($targetAfter | ConvertTo-Json -Compress))) }
        ideRisk=$ideRisk
        safety=[ordered]@{ before=$before; after=$after; equal=[bool]($null -ne $after -and ($before | ConvertTo-Json -Depth 12 -Compress) -ceq ($after | ConvertTo-Json -Depth 12 -Compress)) }
        error=$errorText
    }
    try {
        $reportDestination = if ($resolved) { $resolved.reportPath } elseif ([IO.Path]::IsPathFullyQualified($ReportPath)) { [IO.Path]::GetFullPath($ReportPath) } else { $null }
        if (-not $reportDestination -or [IO.File]::Exists($reportDestination)) { throw 'A new absolute ReportPath is required for fail-closed evidence.' }
        $parent = [IO.Path]::GetDirectoryName($reportDestination)
        if (-not [IO.Directory]::Exists($parent)) { throw 'ReportPath parent does not exist.' }
        Assert-NoLinks $reportDestination
        $json = ($record | ConvertTo-Json -Depth 20).Replace("`r`n","`n") + "`n"
        [IO.File]::WriteAllText($reportDestination,$json,[Text.UTF8Encoding]::new($false))
        $saved = Get-Content -Raw -LiteralPath $reportDestination | ConvertFrom-Json
        if ($null -eq $saved.passed -or $null -eq $saved.safety.equal -or @($saved.steps | Where-Object { $null -eq $_.passed }).Count -gt 0) {
            throw 'Preflight report is incomplete.'
        }
        [Console]::Out.WriteLine(($record | ConvertTo-Json -Depth 20 -Compress))
    } catch {
        [Console]::Error.WriteLine('preflight-report-failure: ' + $_.Exception.Message)
        exit 12
    }
    if (-not $passed) { exit 12 }
}
