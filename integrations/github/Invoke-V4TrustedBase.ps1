[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('Contract','Linux','Package','Windows')][string] $Mode,
    [Parameter(Mandatory)][string] $HeadRoot,
    [Parameter(Mandatory)][ValidatePattern('^[a-f0-9]{40}$')][string] $BaseSha,
    [Parameter(Mandatory)][ValidatePattern('^[a-f0-9]{40}$')][string] $HeadSha,
    [string] $StateRoot,
    [string] $EvidenceRoot,
    [string] $ArtifactRoot,
    [ValidateSet('smoke','full')][string] $Coverage = 'smoke',
    [ValidateSet('auto','smoke','full')][string] $RequestedWindowsCoverage = 'auto',
    [switch] $Certification,
    [string] $GitHubOutput
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$packageRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$baseRoot = $packageRoot
$head = [IO.Path]::GetFullPath($HeadRoot)
$contractPath = Join-Path $PSScriptRoot 'ci-contract.json'
$contractSchema = Join-Path $packageRoot 'core/contracts/ci-contract.schema.json'
$artifactSchema = Join-Path $packageRoot 'core/contracts/ci-artifact-manifest.schema.json'
$contractHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $contractPath).Hash.ToLowerInvariant()
$policyPath = Join-Path $PSScriptRoot 'trust-policy.json'
$resultPath = $null

function Fail([string] $Message, [int] $Code = 12) { $exception = [Exception]::new($Message); $exception.Data['ExitCode'] = $Code; throw $exception }
function Hash([string] $Path) { (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant() }
function Is-Under([string] $Path, [string] $Root) { $relative = [IO.Path]::GetRelativePath($Root, $Path); $relative -eq '.' -or (-not [IO.Path]::IsPathRooted($relative) -and $relative -ne '..' -and -not $relative.StartsWith("..$([IO.Path]::DirectorySeparatorChar)", [StringComparison]::Ordinal)) }
function Resolve-Directory([string] $Value, [string] $Label, [switch] $Create) {
    if ([string]::IsNullOrWhiteSpace($Value)) { Fail "$Mode requires -$Label." 10 }
    $full = [IO.Path]::GetFullPath($Value)
    if ($Label -in @('StateRoot','EvidenceRoot','ArtifactRoot')) {
        foreach ($authority in @($baseRoot,$head)) { if ((Is-Under $full $authority) -or (Is-Under $authority $full)) { Fail "$Label overlaps an authority root." 11 } }
    }
    if ($Create -and -not [IO.Directory]::Exists($full)) { [void][IO.Directory]::CreateDirectory($full) }
    if (-not [IO.Directory]::Exists($full)) { Fail "$Label does not exist: $full" 10 }
    return $full.TrimEnd([IO.Path]::DirectorySeparatorChar)
}
function Assert-ExternalRoots([hashtable] $Roots) {
    foreach ($entry in $Roots.GetEnumerator()) {
        foreach ($authority in @([pscustomobject]@{Name='BaseRoot';Path=$baseRoot},[pscustomobject]@{Name='HeadRoot';Path=$head})) {
            if ((Is-Under $entry.Value $authority.Path) -or (Is-Under $authority.Path $entry.Value)) { Fail "$($entry.Key) overlaps $($authority.Name)." 11 }
        }
    }
    $entries = @($Roots.GetEnumerator())
    for ($left=0;$left-lt$entries.Count;$left++){for($right=$left+1;$right-lt$entries.Count;$right++){if((Is-Under $entries[$left].Value $entries[$right].Value)-or(Is-Under $entries[$right].Value $entries[$left].Value)){Fail "$($entries[$left].Key) overlaps $($entries[$right].Key)." 11}}}
}
function Write-Json([string] $Path, $Value) {
    $parent = [IO.Path]::GetDirectoryName($Path); if (-not [IO.Directory]::Exists($parent)) { [void][IO.Directory]::CreateDirectory($parent) }
    $temporary = Join-Path $parent ".$([IO.Path]::GetFileName($Path))-$([Guid]::NewGuid().ToString('N')).tmp"
    try { [IO.File]::WriteAllText($temporary, (($Value | ConvertTo-Json -Depth 100) + "`n"), [Text.UTF8Encoding]::new($false)); [IO.File]::Move($temporary, $Path, $true) }
    finally { if ([IO.File]::Exists($temporary)) { [IO.File]::Delete($temporary) } }
}
function Invoke-Git([string] $Repository, [string[]] $Arguments) {
    $output = @(& git -c core.longpaths=true -C $Repository @Arguments 2>&1); if ($LASTEXITCODE) { Fail "Git failed ($($Arguments -join ' ')): $($output -join "`n")" }
    return @($output | ForEach-Object { [string]$_ })
}
function Get-ChangedPaths {
    $start = [Diagnostics.ProcessStartInfo]::new('git'); $start.UseShellExecute = $false; $start.RedirectStandardOutput = $true; $start.RedirectStandardError = $true; $start.CreateNoWindow = $true
    foreach ($argument in @('-C',$head,'-c','core.longpaths=true','-c','core.quotepath=false','diff','--name-only','--no-renames','-z',"$BaseSha...$HeadSha",'--')) { [void]$start.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::Start($start); if ($null -eq $process) { Fail 'Git diff did not start.' }
    $stdout = $process.StandardOutput.ReadToEndAsync(); $stderr = $process.StandardError.ReadToEndAsync(); if (-not $process.WaitForExit(30000)) { $process.Kill($true); Fail 'Git diff timed out.' }
    [Threading.Tasks.Task]::WaitAll(@($stdout,$stderr)); if ($process.ExitCode) { Fail "Git diff failed: $($stderr.Result.Trim())" }
    return @($stdout.Result.Split([char]0,[StringSplitOptions]::RemoveEmptyEntries) | ForEach-Object { $_.Replace('\','/') } | Sort-Object -Unique -CaseSensitive)
}
function Invoke-Isolated([string] $Executable, [string[]] $Arguments, [string] $WorkingDirectory, [int] $TimeoutSeconds = 1200) {
    $command = (Get-Command $Executable -ErrorAction Stop).Source
    $start = [Diagnostics.ProcessStartInfo]::new($command); $start.UseShellExecute = $false; $start.RedirectStandardOutput = $true; $start.RedirectStandardError = $true; $start.CreateNoWindow = $true; $start.WorkingDirectory = $WorkingDirectory; $start.Environment.Clear()
    foreach ($name in @('PATH','PATHEXT','SystemRoot','WINDIR','TEMP','TMP','HOME','USERPROFILE','DOTNET_ROOT','ProgramFiles','ProgramFiles(x86)','LOCALAPPDATA','APPDATA','NUGET_PACKAGES')) { $value = [Environment]::GetEnvironmentVariable($name); if (-not [string]::IsNullOrWhiteSpace($value)) { $start.Environment[$name] = $value } }
    $start.Environment['CI'] = 'true'; $start.Environment['DOTNET_CLI_TELEMETRY_OPTOUT'] = '1'; $start.Environment['POWERSHELL_TELEMETRY_OPTOUT'] = '1'
    foreach ($argument in $Arguments) { [void]$start.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::Start($start); if ($null -eq $process) { Fail "$Executable did not start." }
    $stdout = $process.StandardOutput.ReadToEndAsync(); $stderr = $process.StandardError.ReadToEndAsync(); if (-not $process.WaitForExit($TimeoutSeconds * 1000)) { $process.Kill($true); Fail "$Executable timed out." }
    [Threading.Tasks.Task]::WaitAll(@($stdout,$stderr)); [pscustomobject]@{ Code=$process.ExitCode; Output=$stdout.Result.Trim(); Error=$stderr.Result.Trim() }
}
function Test-ApprovedTests([string] $Repository, [string] $Property, [hashtable] $AuthorizedHeads = @{}) {
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($test in $contract.approvedTests) {
        if (-not $seen.Add([string]$test.path)) { Fail "Duplicate approved test path: $($test.path)" }
        $authorized = $AuthorizedHeads.ContainsKey([string]$test.path); if ($authorized -and $null -eq $AuthorizedHeads[[string]$test.path]) { continue }
        $path = [IO.Path]::GetFullPath((Join-Path $Repository ([string]$test.path)))
        if (-not (Is-Under $path $Repository) -or -not [IO.File]::Exists($path)) { Fail "Approved test is missing or unsafe: $($test.path)" }
        $expected = if ($authorized) { [string]$AuthorizedHeads[[string]$test.path] } else { [string]$test.sha256 }
        if ((Hash $path) -cne $expected) { Fail "Approved test hash drift: $($test.path)" }
    }
    $selected = @($contract.approvedTests | Where-Object { $_[$Property] -eq $true -and -not ($AuthorizedHeads.ContainsKey([string]$_.path) -and $null -eq $AuthorizedHeads[[string]$_.path]) })
    if ($selected.Count -eq 0) { Fail "No approved tests selected for $Property." }
    return $selected
}
function New-IsolatedHead([string] $State) {
    $target = Join-Path $State 'target'
    if ([IO.Directory]::Exists($target)) { Fail "Isolated target already exists: $target" 17 }
    $clone = Invoke-Isolated 'git' @('-c','core.longpaths=true','clone','--quiet','--no-local','--config','core.longpaths=true',$head,$target) $State 300
    if ($clone.Code) { Fail "Isolated target clone failed: $($clone.Error)" }
    $checkout = Invoke-Isolated 'git' @('-c','core.longpaths=true','-C',$target,'checkout','--quiet','--detach',$HeadSha) $State 120
    if ($checkout.Code) { Fail "Isolated target checkout failed: $($checkout.Error)" }
    return $target
}
function Invoke-Tests([string] $Repository, [object[]] $Tests) {
    $executed = [Collections.Generic.List[string]]::new()
    foreach ($test in $Tests) {
        $path = Join-Path $Repository ([string]$test.path)
        $run = Invoke-Isolated 'pwsh' @('-NoLogo','-NoProfile','-NonInteractive','-File',$path) $Repository 1800
        if ($run.Output) { Write-Host $run.Output }; if ($run.Error) { Write-Host $run.Error }
        if ($run.Code) { Fail "Approved test failed ($($test.path)): exit $($run.Code)" 16 }
        $executed.Add([string]$test.path)
    }
    return @($executed)
}
function Get-SourceHash([string] $Package) {
    $lines = @(Get-ChildItem -LiteralPath (Join-Path $Package 'core/host') -File -Recurse | Sort-Object FullName | ForEach-Object { "$([IO.Path]::GetRelativePath($Package,$_.FullName).Replace('\','/')):$((Hash $_.FullName))" })
    return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes(($lines -join "`n")))).ToLowerInvariant()
}
function Copy-TrackedPackage([string] $Repository, [string] $Destination) {
    [void][IO.Directory]::CreateDirectory($Destination)
    $paths = @(Invoke-Git $Repository @('ls-files'))
    if ($paths.Count -eq 0) { Fail 'Candidate has no tracked V4 package files.' }
    foreach ($relative in $paths) {
        if ([IO.Path]::IsPathRooted($relative) -or @($relative.Split('/') | Where-Object { $_ -in @('', '.', '..') }).Count -gt 0) { Fail "Tracked package path escaped: $relative" }
        $packageRelative = $relative
        $source = Join-Path $Repository $relative; $target = Join-Path $Destination $packageRelative; $parent = [IO.Path]::GetDirectoryName($target)
        if (-not [IO.Directory]::Exists($parent)) { [void][IO.Directory]::CreateDirectory($parent) }
        [IO.File]::Copy($source,$target,$true)
    }
}
function Verify-Artifact([string] $Root) {
    $manifestPath = Join-Path $Root ([string]$contract.artifact.manifestPath)
    if (-not [IO.File]::Exists($manifestPath) -or -not (Test-Json -LiteralPath $manifestPath -SchemaFile $artifactSchema -ErrorAction SilentlyContinue)) { Fail 'CI artifact manifest is missing or invalid.' }
    $manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json -AsHashtable -Depth 100
    if ($manifest.baseSha -cne $BaseSha -or $manifest.headSha -cne $HeadSha -or $manifest.contractSha256 -cne $contractHash) { Fail 'CI artifact provenance drift.' }
    if (-not $manifest.ContainsKey('verdictComponents') -or (@($manifest.verdictComponents | ForEach-Object { "$($_.path):$($_.sha256)" }) -join "`n") -cne (@($verdictComponents | ForEach-Object { "$($_.path):$($_.sha256)" }) -join "`n")) { Fail 'CI artifact verdict component drift.' }
    $declared = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($file in $manifest.files) {
        if (-not $declared.Add([string]$file.path)) { Fail "Duplicate artifact path: $($file.path)" }
        $full = [IO.Path]::GetFullPath((Join-Path $Root ([string]$file.path)))
        $item = if ([IO.File]::Exists($full)) { Get-Item -LiteralPath $full -Force } else { $null }
        if (-not (Is-Under $full $Root) -or $null -eq $item -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or $null -ne $item.LinkTarget -or (Hash $full) -cne [string]$file.sha256 -or $item.Length -ne [long]$file.size) { Fail "CI artifact file drift: $($file.path)" }
    }
    $actual = @(Get-ChildItem -LiteralPath $Root -File -Recurse | Where-Object { $_.FullName -cne $manifestPath } | ForEach-Object { [IO.Path]::GetRelativePath($Root,$_.FullName).Replace('\','/') } | Sort-Object -Unique -CaseSensitive)
    if (($actual -join "`0") -cne ((@($declared) | Sort-Object -CaseSensitive) -join "`0")) { Fail 'CI artifact file set is not exact.' }
    $check = Invoke-Isolated 'pwsh' @('-NoLogo','-NoProfile','-NonInteractive','-File',(Join-Path $packageRoot 'core/runtime/Test-V4Package.ps1'),'-PackageRoot',(Join-Path $Root ([string]$contract.artifact.packagePath))) $baseRoot 300
    if ($check.Code) { Fail "Artifact package validation failed: $($check.Error)" }
    try { $package = $check.Output | ConvertFrom-Json } catch { Fail 'Artifact package checker did not return JSON.' }
    if ($package.packageHash -cne $manifest.packageHash) { Fail 'Artifact package hash drift.' }
    return $manifest
}
function Test-Glob([string] $Path, [string] $Pattern) {
    $text = $Pattern.Replace('\','/'); $builder = [Text.StringBuilder]::new('^')
    for ($index = 0; $index -lt $text.Length; $index++) {
        if ($index + 2 -lt $text.Length -and $text.Substring($index, 3) -eq '**/') { [void]$builder.Append('(?:.*/)?'); $index += 2 }
        elseif ($index + 1 -lt $text.Length -and $text.Substring($index, 2) -eq '**') { [void]$builder.Append('.*'); $index++ }
        elseif ($text[$index] -eq '*') { [void]$builder.Append('[^/]*') }
        elseif ($text[$index] -eq '?') { [void]$builder.Append('[^/]') }
        else { [void]$builder.Append([Regex]::Escape([string]$text[$index])) }
    }
    [void]$builder.Append('$'); return [Regex]::IsMatch($Path, $builder.ToString(), [Text.RegularExpressions.RegexOptions]::CultureInvariant)
}
function Test-Protected([string] $Path) {
    if (@($trustPolicy.verdictComponents) -ccontains $Path) { return $true }
    foreach ($pattern in $trustPolicy.certificationComponents) { if (Test-Glob $Path ([string]$pattern)) { return $true } }
    return @($contract.approvedTests | ForEach-Object { [string]$_.path }) -ccontains $Path
}
function Get-TreeHash([string] $Root, [string] $Path) { $full = [IO.Path]::GetFullPath((Join-Path $Root $Path)); if (-not (Is-Under $full $Root)) { Fail "Unsafe protected path: $Path" 11 }; if ([IO.File]::Exists($full)) { Hash $full } else { $null } }
function Read-Authorization([string] $Full, [string] $Relative) {
    if (-not (Test-Json -LiteralPath $Full -SchemaFile (Join-Path $baseRoot ([string]$trustPolicy.authorizationSchema)) -ErrorAction SilentlyContinue)) { Fail "Authorization record violates its schema: $Relative" 10 }
    $record = Get-Content -Raw -LiteralPath $Full | ConvertFrom-Json -AsHashtable -Depth 20
    if ("$([string]$trustPolicy.authorizationDirectory)/$($record.id).json" -cne $Relative) { Fail "Authorization record id does not match its path: $Relative" 10 }
    $paths = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal); foreach ($entry in $record.entries) { if (-not $paths.Add([string]$entry.path)) { Fail "Duplicate authorization entry: $($entry.path)" 10 } }
    return $record
}
function Get-BaseAuthorizations {
    $directory = Join-Path $baseRoot ([string]$trustPolicy.authorizationDirectory); if (-not [IO.Directory]::Exists($directory)) { return @() }
    return @(Get-ChildItem -LiteralPath $directory -File -Filter '*.json' | Sort-Object Name | ForEach-Object { $relative = "$([string]$trustPolicy.authorizationDirectory)/$($_.Name)"; [pscustomobject]@{ Path=$relative; Record=(Read-Authorization $_.FullName $relative) } })
}
function Resolve-TrustChange([string[]] $Changed) {
    $prefix = "$([string]$trustPolicy.authorizationDirectory)/"
    $protected = @($Changed | Where-Object { Test-Protected $_ }); $records = @($Changed | Where-Object { $_.StartsWith($prefix, [StringComparison]::Ordinal) })
    $plans = @($Changed | Where-Object { $_ -match '^docs/plans/[^/]+\.plan\.json$' }); $planSets = @($Changed | Where-Object { $_ -match '^docs/plans/[^/]+\.plan-set\.json$' })
    $plan = $null; $planPath = $null
    if ($planSets.Count -eq 0 -and $plans.Count -eq 1) {
        $planPath = $plans[0]; $planFull = Join-Path $head $planPath
        if ([IO.File]::Exists($planFull) -and (Test-Json -LiteralPath $planFull -SchemaFile (Join-Path $baseRoot 'core/contracts/plan.schema.json') -ErrorAction SilentlyContinue)) { $plan = Get-Content -Raw -LiteralPath $planFull | ConvertFrom-Json -AsHashtable -Depth 100 }
    }
    $boundaries = if ($null -ne $plan) { @($plan.boundaries) } else { @() }
    if ($boundaries -contains 'authorization') {
        $planDocument = $planPath -replace '\.plan\.json$','.md'; $added = [Collections.Generic.List[string]]::new()
        foreach ($path in $Changed) {
            if ($path -ceq $planPath -or $path -ceq $planDocument) { continue }
            $isRecord = $path.StartsWith($prefix, [StringComparison]::Ordinal) -and $path.Substring($prefix.Length) -match '^[0-9]{8}-[a-z0-9-]+\.json$'
            if (-not $isRecord -or $null -ne (Get-TreeHash $baseRoot $path) -or $null -eq (Get-TreeHash $head $path)) { Fail "An authorization Plan may only add authorization records and its own Plan pair: $path" 16 }
            $added.Add($path)
        }
        if ($added.Count -eq 0) { Fail 'An authorization Plan must add at least one authorization record.' 10 }
        $planIds = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal); foreach ($existing in @(Get-BaseAuthorizations)) { [void]$planIds.Add([string]$existing.Record.planId) }
        foreach ($recordPath in $added) {
            $record = Read-Authorization (Join-Path $head $recordPath) $recordPath
            if ([string]$record.planId -ceq [string]$plan.id) { Fail "An authorization record cannot authorize its own Plan: $recordPath" 16 }
            if (-not $planIds.Add([string]$record.planId)) { Fail "An authorization record already exists for Plan $($record.planId)." 16 }
            foreach ($entry in $record.entries) {
                if (-not (Test-Protected ([string]$entry.path))) { Fail "Authorization entry is not a protected path: $($entry.path)" 10 }
                if ((Get-TreeHash $baseRoot ([string]$entry.path)) -cne $entry.baseSha256) { Fail "Authorization entry does not bind the current base content: $($entry.path)" 16 }
            }
        }
        return [ordered]@{ status='authorization-added'; protectedPaths=@(); authorization=@($added); authorizedHeads=@{} }
    }
    if ($protected.Count -eq 0) {
        if ($records.Count -gt 0) { Fail "Authorization records change only through an authorization Plan or by consumption: $($records -join ', ')" 16 }
        return [ordered]@{ status='none'; protectedPaths=@(); authorization=$null; authorizedHeads=@{} }
    }
    $testPaths = @($contract.approvedTests | ForEach-Object { [string]$_.path }); $drifted = @($protected | Where-Object { $testPaths -ccontains $_ })
    $unauthorized = if ($drifted.Count -gt 0) { "Approved test hash drift without trust-change authorization: $($drifted -join ', ')" } else { "Unauthorized trusted-component change: $($protected -join ', ')" }
    if ($boundaries -notcontains 'trust-change') { Fail "$unauthorized (the root Plan has no trust-change boundary)" 16 }
    $matched = @(Get-BaseAuthorizations | Where-Object { [string]$_.Record.planId -ceq [string]$plan.id })
    if ($matched.Count -eq 0) { Fail "$unauthorized (no base-held authorization record for Plan $($plan.id))" 16 }
    if ($matched.Count -gt 1) { Fail "Multiple base-held authorization records for Plan $($plan.id)." 16 }
    $record = $matched[0].Record; $recordPath = $matched[0].Path; $entries = @{}
    foreach ($entry in $record.entries) { $entries[[string]$entry.path] = $entry }
    foreach ($path in $protected) { if (-not $entries.ContainsKey($path)) { Fail "Protected change is not covered by the authorization: $path" 16 } }
    foreach ($path in @($entries.Keys | Sort-Object -CaseSensitive)) {
        if ($protected -cnotcontains $path) { Fail "Authorization entry has no matching protected change: $path" 16 }
        if ((Get-TreeHash $baseRoot $path) -cne $entries[$path].baseSha256 -or (Get-TreeHash $head $path) -cne $entries[$path].headSha256) { Fail "Authorization hash mismatch: $path" 16 }
    }
    if ($records -cnotcontains $recordPath -or $null -ne (Get-TreeHash $head $recordPath)) { Fail "Authorization record was not consumed in the same diff: $recordPath" 16 }
    $others = @($records | Where-Object { $_ -cne $recordPath }); if ($others.Count -gt 0) { Fail "A trust change may only consume its own authorization record: $($others -join ', ')" 16 }
    $candidateContract = Join-Path $head 'integrations/github/ci-contract.json'
    if (-not [IO.File]::Exists($candidateContract) -or -not (Test-Json -LiteralPath $candidateContract -SchemaFile (Join-Path $head 'core/contracts/ci-contract.schema.json') -ErrorAction SilentlyContinue)) { Fail 'Candidate CI contract is missing or invalid after the trust change.' 16 }
    foreach ($test in (Get-Content -Raw -LiteralPath $candidateContract | ConvertFrom-Json -AsHashtable -Depth 100).approvedTests) { if ((Get-TreeHash $head ([string]$test.path)) -cne [string]$test.sha256) { Fail "Candidate CI contract does not bind the candidate approved test: $($test.path)" 16 } }
    $heads = @{}; foreach ($path in $drifted) { $heads[$path] = $entries[$path].headSha256 }
    return [ordered]@{ status='authorized'; protectedPaths=$protected; authorization=$recordPath; authorizedHeads=$heads }
}
function Get-TrustSummary($Trust) { [ordered]@{ status=$Trust.status; protectedPaths=@($Trust.protectedPaths); authorization=$Trust.authorization } }

if (-not [IO.File]::Exists($contractPath) -or -not (Test-Json -LiteralPath $contractPath -SchemaFile $contractSchema -ErrorAction SilentlyContinue)) { Fail 'Base CI contract is missing or invalid.' }
$contract = Get-Content -Raw -LiteralPath $contractPath | ConvertFrom-Json -AsHashtable -Depth 100
try { $trustPolicy = if ([IO.File]::Exists($policyPath)) { Get-Content -Raw -LiteralPath $policyPath | ConvertFrom-Json -AsHashtable -Depth 20 } else { $null } } catch { $trustPolicy = $null }
if ($trustPolicy -isnot [hashtable] -or $trustPolicy['formatVersion'] -ne 1 -or $trustPolicy['protectApprovedTests'] -ne $true -or [string]$trustPolicy['authorizationDirectory'] -notmatch '^[a-z0-9-]+(?:/[a-z0-9-]+)*$' -or [string]::IsNullOrWhiteSpace([string]$trustPolicy['authorizationSchema']) -or @($trustPolicy['verdictComponents']).Count -eq 0 -or @($trustPolicy['certificationComponents']).Count -eq 0 -or @($trustPolicy['verdictComponents']) -cnotcontains 'integrations/github/trust-policy.json') { Fail 'Base trust policy is missing or invalid.' }
$verdictComponents = @($trustPolicy.verdictComponents | ForEach-Object { $full = [IO.Path]::GetFullPath((Join-Path $baseRoot ([string]$_))); if (-not (Is-Under $full $baseRoot) -or -not [IO.File]::Exists($full)) { Fail "Base verdict component is missing: $_" }; [ordered]@{ path=[string]$_; sha256=Hash $full } })
$baseHead = @(Invoke-Git $baseRoot @('rev-parse','HEAD')); if ($baseHead.Count -ne 1 -or $baseHead[0] -cne $BaseSha) { Fail "Trusted runner repository is not at BaseSha $BaseSha." }
$baseDirty = @(Invoke-Git $baseRoot @('status','--porcelain','--untracked-files=all')); if ($baseDirty.Count -gt 0) { Fail "Trusted base worktree is not clean: $($baseDirty | Select-Object -First 3)" }
if (-not [IO.Directory]::Exists($head) -or (Is-Under $head $baseRoot) -or (Is-Under $baseRoot $head)) { Fail 'HeadRoot must exist and be separate from the trusted base.' 11 }
$resolvedHead = @(Invoke-Git $head @('rev-parse','HEAD')); if ($resolvedHead.Count -ne 1 -or $resolvedHead[0] -cne $HeadSha) { Fail "HeadRoot is not at HeadSha $HeadSha." }
$headDirty = @(Invoke-Git $head @('status','--porcelain','--untracked-files=no')); if ($headDirty.Count -gt 0) { Fail "HeadRoot tracked files do not match HeadSha: $($headDirty | Select-Object -First 3)" }
$mergeBase = @(Invoke-Git $head @('merge-base',$BaseSha,$HeadSha)); if ($mergeBase.Count -ne 1 -or $mergeBase[0] -cne $BaseSha) { Fail 'BaseSha is not the merge base of the candidate head.' }

try {
    if ($Mode -eq 'Contract') {
        $evidence = Resolve-Directory $EvidenceRoot 'EvidenceRoot' -Create; $resultPath = Join-Path $evidence 'contract.json'
        Assert-ExternalRoots ([ordered]@{EvidenceRoot=$evidence})
        $rootPlan = $null; $changed = @()
        if ($Certification) {
            if ($BaseSha -cne $HeadSha -or $RequestedWindowsCoverage -cne 'full') { Fail 'Certification requires identical base/head SHAs and explicit full Windows coverage.' 10 }
            $selection = [pscustomobject]@{ windowsRequired=$true; selectedCoverage='full' }
            if ($GitHubOutput) { [IO.File]::AppendAllText([IO.Path]::GetFullPath($GitHubOutput), "windows-required=true`nwindows-coverage=full`n", [Text.UTF8Encoding]::new($false)) }
        }
        else {
            $changed = @(Get-ChangedPaths); if ($changed.Count -eq 0) { Fail 'Candidate head has no changed paths.' 10 }
            $planSets = @($changed | Where-Object { $_ -match '^docs/plans/[^/]+\.plan-set\.json$' })
            $plans = @($changed | Where-Object { $_ -match '^docs/plans/[^/]+\.plan\.json$' })
            if ($planSets.Count -eq 1) { $rootPlan = $planSets[0] }
            elseif ($planSets.Count -eq 0 -and $plans.Count -eq 1) { $rootPlan = $plans[0] }
            else { Fail 'The candidate must select exactly one root Plan or one root plan-set.' 10 }
            if ($rootPlan.EndsWith('.plan-set.json',[StringComparison]::Ordinal)) {
                $copy = Join-Path $evidence 'candidate.plan-set.json'; Copy-Item -LiteralPath (Join-Path $head $rootPlan) -Destination $copy
                $diff = Invoke-Isolated 'pwsh' @('-NoLogo','-NoProfile','-NonInteractive','-File',(Join-Path $packageRoot 'integrations/git/Invoke-V4PlanDiff.ps1'),'-PackageRoot',$packageRoot,'-RepositoryRoot',$head,'-EvidenceRoot',$evidence,'-PlanSetPath','candidate.plan-set.json','-BaseRef',$BaseSha,'-HeadRef',$HeadSha,'-ReportPath','plan-diff.json') $baseRoot 300
                if ($diff.Code) { Fail "Plan-set diff validation failed: $($diff.Error)" 16 }
            }
            else {
                $full = Join-Path $head $rootPlan; if (-not (Test-Json -LiteralPath $full -SchemaFile (Join-Path $packageRoot 'core/contracts/plan.schema.json') -ErrorAction SilentlyContinue)) { Fail 'Root Plan violates plan.schema.json.' 10 }
                $plan = Get-Content -Raw -LiteralPath $full | ConvertFrom-Json -AsHashtable -Depth 100
                if (@($plan.dependencies).Count -ne 0) { Fail 'A single root Plan cannot have unselected dependencies.' 10 }
                $declared = @($plan.plannedPaths | ForEach-Object { ([string]$_).Replace('\','/') } | Sort-Object -Unique -CaseSensitive)
                if (($declared -join "`0") -cne (($changed | Sort-Object -Unique -CaseSensitive) -join "`0")) { Fail 'Root Plan paths do not exactly match the candidate diff.' 16 }
                $boundaries = @($plan.boundaries); foreach ($pair in @(@('authorization','trust-change'),@('authorization','activation'),@('trust-change','activation'),@('engine-change','remote-change'))) { if ($boundaries -contains $pair[0] -and $boundaries -contains $pair[1]) { Fail "Forbidden root Plan boundary combination: $($pair -join ' + ')." 10 } }
            }
            $classifierReport = Join-Path $evidence 'windows-selection.json'
            $changedJson = ConvertTo-Json -InputObject @($changed) -Compress
            $classifyArgs = @('-NoLogo','-NoProfile','-NonInteractive','-File',(Join-Path $PSScriptRoot 'Get-V4WindowsSelection.ps1'),'-ContractPath',$contractPath,'-ChangedPathsJson',$changedJson,'-RequestedCoverage',$RequestedWindowsCoverage,'-ReportPath',$classifierReport)
            if ($GitHubOutput) { $classifyArgs += @('-GitHubOutput',$GitHubOutput) }
            $selectionRun = Invoke-Isolated 'pwsh' $classifyArgs $baseRoot 120; if ($selectionRun.Code) { Fail "Windows classification failed: $($selectionRun.Error)" 10 }
            $selection = Get-Content -Raw $classifierReport | ConvertFrom-Json
            $trust = Resolve-TrustChange $changed
        }
        if ($Certification) { $trust = [ordered]@{ status='none'; protectedPaths=@(); authorization=$null } }
        $result = [ordered]@{ formatVersion=1; mode='contract'; status='pass'; baseSha=$BaseSha; headSha=$HeadSha; rootPlan=$rootPlan; changedPaths=$changed; windowsRequired=$selection.windowsRequired; windowsCoverage=$selection.selectedCoverage; trustChange=(Get-TrustSummary $trust); verdictComponents=$verdictComponents }
    }
    elseif ($Mode -eq 'Linux') {
        $state = Resolve-Directory $StateRoot 'StateRoot' -Create; $evidence = Resolve-Directory $EvidenceRoot 'EvidenceRoot' -Create; $artifact = Resolve-Directory $ArtifactRoot 'ArtifactRoot' -Create; $resultPath = Join-Path $evidence 'linux.json'
        Assert-ExternalRoots ([ordered]@{StateRoot=$state;EvidenceRoot=$evidence;ArtifactRoot=$artifact})
        if (@(Get-ChildItem -LiteralPath $artifact -Force).Count -gt 0) { Fail 'ArtifactRoot must be empty before Linux production.' 17 }
        $trust = if ($BaseSha -ceq $HeadSha) { [ordered]@{ status='none'; protectedPaths=@(); authorization=$null; authorizedHeads=@{} } } else { Resolve-TrustChange @(Get-ChangedPaths) }
        $target = New-IsolatedHead $state; $tests = @(Test-ApprovedTests $target 'linux' $trust.authorizedHeads); $executed = @(Invoke-Tests $target $tests)
        $targetPackage = $target; $packageCheck = Invoke-Isolated 'pwsh' @('-NoLogo','-NoProfile','-NonInteractive','-File',(Join-Path $packageRoot 'core/runtime/Test-V4Package.ps1'),'-PackageRoot',$targetPackage) $target 300
        if ($packageCheck.Code) { Fail "Candidate package validation failed: $($packageCheck.Error)" }; $packageResult = $packageCheck.Output | ConvertFrom-Json
        $project = Join-Path $targetPackage 'core/host/V4.Guards.Host/V4.Guards.Host.csproj'; $build = Join-Path $state 'build'; [void][IO.Directory]::CreateDirectory($build)
        $properties = @('-p:ImportDirectoryBuildProps=false','-p:ImportDirectoryBuildTargets=false','-p:ImportDirectoryPackagesProps=false','-p:ImportDirectorySolutionProps=false','-p:ImportDirectorySolutionTargets=false',"-p:CustomBeforeMicrosoftCommonProps=$(Join-Path $targetPackage 'build/V4.Build.props')")
        $restore = Invoke-Isolated 'dotnet' (@('restore',$project,'--configfile',(Join-Path $targetPackage 'build/NuGet.config'),'--artifacts-path',$build,'-nologo') + $properties) $target 600; if ($restore.Code) { Fail "Candidate host restore failed: $($restore.Error)" 14 }
        $compile = Invoke-Isolated 'dotnet' (@('build',$project,'--no-restore','--configuration','Release','--artifacts-path',$build,'-nologo') + $properties) $target 600; if ($compile.Code) { Fail "Candidate host build failed: $($compile.Error)" 14 }
        $trackedDrift = @(Invoke-Git $target @('status','--porcelain','--untracked-files=no')); if ($trackedDrift.Count -gt 0) { Fail "Approved tests modified tracked candidate files: $($trackedDrift -join ', ')" }
        Copy-TrackedPackage $target (Join-Path $artifact 'package')
        $hostOutput = Join-Path $build 'bin/V4.Guards.Host/release'; if (-not [IO.Directory]::Exists($hostOutput)) { Fail 'Candidate host output is missing.' }
        Copy-Item -LiteralPath $hostOutput -Destination (Join-Path $artifact 'host') -Recurse
        $hostPath = Join-Path $artifact ([string]$contract.artifact.hostPath); if (-not [IO.File]::Exists($hostPath)) { Fail 'Built host DLL is missing from the artifact.' }
        $files = @(Get-ChildItem -LiteralPath $artifact -File -Recurse | Sort-Object FullName | ForEach-Object { [ordered]@{ path=[IO.Path]::GetRelativePath($artifact,$_.FullName).Replace('\','/'); sha256=Hash $_.FullName; size=$_.Length } })
        $manifest = [ordered]@{ formatVersion=1; baseSha=$BaseSha; headSha=$HeadSha; contractSha256=$contractHash; packageHash=$packageResult.packageHash; buildEvidence=[ordered]@{ configuration='Release'; targetFramework='net10.0'; sourceSha256=Get-SourceHash $targetPackage; hostPath=[string]$contract.artifact.hostPath; hostSha256=Hash $hostPath; secretEnvironmentNames=@() }; verdictComponents=$verdictComponents; linuxTests=$executed; files=$files }
        $manifestPath = Join-Path $artifact ([string]$contract.artifact.manifestPath); Write-Json $manifestPath $manifest
        if (-not (Test-Json -LiteralPath $manifestPath -SchemaFile $artifactSchema -ErrorAction SilentlyContinue)) { Fail 'Produced CI artifact manifest violates its schema.' }
        [void](Verify-Artifact $artifact)
        $result = [ordered]@{ formatVersion=1; mode='linux'; status='pass'; baseSha=$BaseSha; headSha=$HeadSha; packageHash=$packageResult.packageHash; artifactManifestSha256=Hash $manifestPath; tests=$executed; trustChange=(Get-TrustSummary $trust); verdictComponents=$verdictComponents }
    }
    elseif ($Mode -eq 'Package') {
        $evidence = Resolve-Directory $EvidenceRoot 'EvidenceRoot' -Create; $artifact = Resolve-Directory $ArtifactRoot 'ArtifactRoot'; $resultPath = Join-Path $evidence 'package.json'
        Assert-ExternalRoots ([ordered]@{EvidenceRoot=$evidence;ArtifactRoot=$artifact})
        $manifest = Verify-Artifact $artifact
        $result = [ordered]@{ formatVersion=1; mode='package'; status='pass'; baseSha=$BaseSha; headSha=$HeadSha; packageHash=$manifest.packageHash; reusedArtifact=$true; verdictComponents=$verdictComponents }
    }
    else {
        $state = Resolve-Directory $StateRoot 'StateRoot' -Create; $evidence = Resolve-Directory $EvidenceRoot 'EvidenceRoot' -Create; $artifact = Resolve-Directory $ArtifactRoot 'ArtifactRoot'; $resultPath = Join-Path $evidence 'windows.json'
        Assert-ExternalRoots ([ordered]@{StateRoot=$state;EvidenceRoot=$evidence;ArtifactRoot=$artifact})
        [void](Verify-Artifact $artifact)
        $trust = if ($BaseSha -ceq $HeadSha) { [ordered]@{ status='none'; protectedPaths=@(); authorization=$null; authorizedHeads=@{} } } else { Resolve-TrustChange @(Get-ChangedPaths) }
        $target = New-IsolatedHead $state; $property = if ($Coverage -ceq 'full') { 'windowsFull' } else { 'windowsSmoke' }; $tests = @(Test-ApprovedTests $target $property $trust.authorizedHeads); $executed = @(Invoke-Tests $target $tests)
        $result = [ordered]@{ formatVersion=1; mode='windows'; status='pass'; baseSha=$BaseSha; headSha=$HeadSha; coverage=$Coverage; reusedArtifact=$true; tests=$executed; trustChange=(Get-TrustSummary $trust); verdictComponents=$verdictComponents }
    }
    Write-Json $resultPath $result; $result | ConvertTo-Json -Depth 100; exit 0
}
catch {
    $code = if ($_.Exception.Data.Contains('ExitCode')) { [int]$_.Exception.Data['ExitCode'] } else { 19 }
    $errorResult = [ordered]@{ formatVersion=1; mode=$Mode.ToLowerInvariant(); status='error'; exitCategory=if($code -eq 10){'invalid-input'}elseif($code -eq 11){'unsafe-path'}elseif($code -eq 16){'findings-blocking'}elseif($code -eq 17){'state-conflict'}else{'integrity-failure'}; message=$_.Exception.Message }
    if ($resultPath) { try { Write-Json $resultPath $errorResult } catch {} }
    [Console]::Error.WriteLine(($errorResult | ConvertTo-Json -Depth 20)); exit $code
}
