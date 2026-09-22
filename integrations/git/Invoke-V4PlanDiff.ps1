[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $PackageRoot,
    [Parameter(Mandatory)][string] $RepositoryRoot,
    [Parameter(Mandatory)][string] $EvidenceRoot,
    [Parameter(Mandatory)][string] $PlanSetPath,
    [Parameter(Mandatory)][string] $BaseRef,
    [Parameter(Mandatory)][string] $HeadRef,
    [string] $ReportPath = 'plan-diff.json'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Result([hashtable] $Result, [string] $Path) {
    $parent = [IO.Path]::GetDirectoryName($Path)
    if (-not [IO.Directory]::Exists($parent)) { [void][IO.Directory]::CreateDirectory($parent) }
    $temporary = Join-Path $parent ".$([IO.Path]::GetFileName($Path))-$([Guid]::NewGuid().ToString('N')).tmp"
    try {
        [IO.File]::WriteAllText($temporary, (($Result | ConvertTo-Json -Depth 100) + "`n"), [Text.UTF8Encoding]::new($false))
        [IO.File]::Move($temporary, $Path, $true)
    }
    finally { if ([IO.File]::Exists($temporary)) { [IO.File]::Delete($temporary) } }
}

function Resolve-Directory([string] $Value, [string] $Label) {
    $full = [IO.Path]::GetFullPath($Value)
    if (-not [IO.Directory]::Exists($full)) { throw "$Label does not exist: $full" }
    return $full.TrimEnd([IO.Path]::DirectorySeparatorChar)
}

function Resolve-Relative([string] $Root, [string] $Value, [string] $Label, [switch] $MustExist) {
    if ([string]::IsNullOrWhiteSpace($Value) -or [IO.Path]::IsPathRooted($Value) -or $Value -match '^[A-Za-z]:' -or $Value -match '[*?]') {
        throw "$Label must be an exact relative path: $Value"
    }
    $normalized = $Value.Replace('\', '/')
    if (@($normalized.Split('/') | Where-Object { $_ -in @('', '.', '..') }).Count -gt 0) { throw "$Label is unsafe: $Value" }
    $full = [IO.Path]::GetFullPath((Join-Path $Root $normalized))
    $prefix = $Root.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    if (-not $full.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { throw "$Label escapes its root: $Value" }
    if ($MustExist -and -not [IO.File]::Exists($full)) { throw "$Label is missing: $Value" }
    return $full
}

function Exact-Array($Actual, [string[]] $Expected, [string] $Label) {
    $left = @($Actual | ForEach-Object { [string]$_ } | Sort-Object -Unique -CaseSensitive)
    $right = @($Expected | Sort-Object -Unique -CaseSensitive)
    if (($left -join "`0") -cne ($right -join "`0")) { throw "Plan-set $Label is not the exact member union." }
}

function Invoke-GitNames([string] $Repository, [string] $Base, [string] $Head) {
    foreach ($value in @($Base, $Head)) {
        if ($value -notmatch '^[A-Za-z0-9][A-Za-z0-9._/-]*$' -or $value.Contains('..') -or $value.Contains('//')) {
            throw "Unsafe Git ref: $value"
        }
    }
    $start = [Diagnostics.ProcessStartInfo]::new('git')
    $start.UseShellExecute = $false
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.CreateNoWindow = $true
    foreach ($argument in @('-C', $Repository, '-c', 'core.quotepath=false', 'diff', '--name-only', '--no-renames', '-z', "$Base...$Head", '--')) {
        [void]$start.ArgumentList.Add($argument)
    }
    $process = [Diagnostics.Process]::Start($start)
    if ($null -eq $process) { throw 'Git did not start.' }
    $stdout = $process.StandardOutput.ReadToEndAsync()
    $stderr = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit(30000)) { $process.Kill($true); throw 'Git diff timed out.' }
    [Threading.Tasks.Task]::WaitAll(@($stdout, $stderr))
    if ($process.ExitCode -ne 0) { throw "Git diff failed: $($stderr.Result.Trim())" }
    return @($stdout.Result.Split([char]0, [StringSplitOptions]::RemoveEmptyEntries) | ForEach-Object { $_.Replace('\', '/') } | Sort-Object -Unique -CaseSensitive)
}

$exitCode = 19
$result = $null
$reportFull = $null
try {
    $package = Resolve-Directory $PackageRoot 'PackageRoot'
    $repository = Resolve-Directory $RepositoryRoot 'RepositoryRoot'
    $evidence = Resolve-Directory $EvidenceRoot 'EvidenceRoot'
    $planSetFull = Resolve-Relative $evidence $PlanSetPath 'PlanSetPath' -MustExist
    $reportFull = Resolve-Relative $evidence $ReportPath 'ReportPath'
    $schema = Join-Path $package 'core/contracts/plan-set.schema.json'
    $planSchema = Join-Path $package 'core/contracts/plan.schema.json'
    if (-not (Test-Json -LiteralPath $planSetFull -SchemaFile $schema -ErrorAction SilentlyContinue)) { throw 'Plan-set violates its schema.' }
    $planSet = Get-Content -Raw -LiteralPath $planSetFull | ConvertFrom-Json -AsHashtable -Depth 100

    $orders = @($planSet.members | ForEach-Object { [int]$_.order })
    if (($orders -join ',') -cne ((1..$planSet.members.Count) -join ',')) { throw 'Plan-set member order is not contiguous.' }
    if (@($planSet.members.planId | Sort-Object -Unique -CaseSensitive).Count -ne $planSet.members.Count) { throw 'Plan-set contains duplicate member IDs.' }
    if (@($planSet.members.path | Sort-Object -Unique -CaseSensitive).Count -ne $planSet.members.Count) { throw 'Plan-set contains duplicate member paths.' }

    $plans = @()
    foreach ($member in $planSet.members) {
        $memberPath = Resolve-Relative $repository ([string]$member.path) 'Plan member path' -MustExist
        $actualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $memberPath).Hash.ToLowerInvariant()
        if ($actualHash -cne [string]$member.sha256) { throw "Plan member hash drift: $($member.path)" }
        if (-not (Test-Json -LiteralPath $memberPath -SchemaFile $planSchema -ErrorAction SilentlyContinue)) { throw "Plan member violates its schema: $($member.path)" }
        $plan = Get-Content -Raw -LiteralPath $memberPath | ConvertFrom-Json -AsHashtable -Depth 100
        if ($plan.id -cne $member.planId) { throw "Plan member identity drift: $($member.path)" }
        if ((@($plan.dependencies | Sort-Object -Unique -CaseSensitive) -join "`0") -cne (@($member.dependsOn | Sort-Object -Unique -CaseSensitive) -join "`0")) {
            throw "Plan member dependencies drift: $($member.path)"
        }
        $plans += $plan
    }
    Exact-Array $planSet.derivedUnion.plannedPaths @($plans | ForEach-Object { @($_.plannedPaths) }) 'plannedPaths'
    Exact-Array $planSet.derivedUnion.areas @($plans | ForEach-Object { @($_.areas) }) 'areas'
    Exact-Array $planSet.derivedUnion.risks @($plans | ForEach-Object { @($_.risks) }) 'risks'
    Exact-Array $planSet.derivedUnion.decisions @($plans | ForEach-Object { @($_.decisions) }) 'decisions'
    Exact-Array $planSet.derivedUnion.validationCommands @($plans | ForEach-Object { @($_.validationCommands) }) 'validationCommands'
    Exact-Array $planSet.derivedUnion.boundaries @($plans | ForEach-Object { @($_.boundaries) }) 'boundaries'
    $canonicalMembers = @($planSet.members | ForEach-Object { [ordered]@{ order = [int]$_.order; planId = [string]$_.planId; path = [string]$_.path; sha256 = [string]$_.sha256; dependsOn = @($_.dependsOn | ForEach-Object { [string]$_ }) } })
    $union = $planSet.derivedUnion
    $canonicalUnion = [ordered]@{
        plannedPaths = @($union.plannedPaths | ForEach-Object { [string]$_ }); areas = @($union.areas | ForEach-Object { [string]$_ })
        risks = @($union.risks | ForEach-Object { [string]$_ }); decisions = @($union.decisions | ForEach-Object { [string]$_ })
        validationCommands = @($union.validationCommands | ForEach-Object { [string]$_ }); boundaries = @($union.boundaries | ForEach-Object { [string]$_ })
    }
    $canonical = [ordered]@{ formatVersion = 1; id = [string]$planSet.id; members = $canonicalMembers; derivedUnion = $canonicalUnion }
    $canonicalJson = $canonical | ConvertTo-Json -Compress -Depth 100 -EscapeHandling EscapeNonAscii
    $compositionHash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($canonicalJson))).ToLowerInvariant()
    if ($compositionHash -cne [string]$planSet.compositionHash) { throw 'Plan-set composition hash drift.' }

    $changed = @(Invoke-GitNames $repository $BaseRef $HeadRef)
    $planned = @($planSet.derivedUnion.plannedPaths | ForEach-Object { [string]$_ } | Sort-Object -Unique -CaseSensitive)
    $undeclared = @($changed | Where-Object { $_ -cnotin $planned })
    $unchanged = @($planned | Where-Object { $_ -cnotin $changed })
    if ($undeclared.Count -gt 0 -or $unchanged.Count -gt 0) {
        $exitCode = 16
        $result = [ordered]@{ formatVersion = 1; status = 'fail'; exitCategory = 'findings-blocking'; planSetId = $planSet.id; baseRef = $BaseRef; headRef = $HeadRef; changedPaths = $changed; plannedPaths = $planned; undeclaredPaths = $undeclared; unchangedPaths = $unchanged }
    }
    else {
        $exitCode = 0
        $result = [ordered]@{ formatVersion = 1; status = 'pass'; exitCategory = 'success'; planSetId = $planSet.id; baseRef = $BaseRef; headRef = $HeadRef; changedPaths = $changed; plannedPaths = $planned; undeclaredPaths = @(); unchangedPaths = @() }
    }
}
catch {
    $exitCode = 12
    $result = [ordered]@{ formatVersion = 1; status = 'error'; exitCategory = 'integrity-failure'; message = $_.Exception.Message }
}

if ($null -ne $reportFull) { Write-Result $result $reportFull }
if ($exitCode -eq 0) { $result | ConvertTo-Json -Depth 100 } else { [Console]::Error.WriteLine(($result | ConvertTo-Json -Depth 100)) }
exit $exitCode
