[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $PackageRoot,
    [string] $Profile = 'default',
    [Parameter(Mandatory)][string] $ReportPath,
    [string] $RuntimeOverridesJson = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Json([string] $Path, $Value) {
    $parent = Split-Path -Parent $Path
    if (-not [string]::IsNullOrWhiteSpace($parent)) { [void][IO.Directory]::CreateDirectory($parent) }
    $json = ($Value | ConvertTo-Json -Depth 30).Replace("`r`n", "`n") + "`n"
    [IO.File]::WriteAllText($Path, $json, [Text.UTF8Encoding]::new($false))
}

function Read-Json([string] $Path, [string] $Label) {
    if (-not [IO.File]::Exists($Path)) { throw "$Label is missing: $Path" }
    try { Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json -AsHashtable -Depth 100 }
    catch { throw "$Label is invalid JSON: $($_.Exception.Message)" }
}

function Parse-Version([string] $Text) {
    $match = [Regex]::Match($Text, '[0-9]+(?:\.[0-9]+){0,3}')
    if (-not $match.Success) { return $null }
    try { return [version]$match.Value } catch { return $null }
}

function Test-Range([version] $Version, [string] $Range) {
    foreach ($token in $Range.Split(' ', [StringSplitOptions]::RemoveEmptyEntries)) {
        if ($token -notmatch '^(>=|>|<=|<)([0-9]+(?:\.[0-9]+){0,3})$') { return $false }
        $bound = [version]$Matches[2]
        $comparison = $Version.CompareTo($bound)
        if (($Matches[1] -eq '>=' -and $comparison -lt 0) -or ($Matches[1] -eq '>' -and $comparison -le 0) -or
            ($Matches[1] -eq '<=' -and $comparison -gt 0) -or ($Matches[1] -eq '<' -and $comparison -ge 0)) { return $false }
    }
    return $true
}

function Detect-Runtime([string] $Runtime, [string] $VersionRange, $Overrides) {
    if ($null -ne $Overrides -and $Overrides.ContainsKey($Runtime)) {
        $override = $Overrides[$Runtime]
        if ($override.status -eq 'missing') { return $null }
        return [ordered]@{ Path = [string]$override.path; Version = Parse-Version ([string]$override.version) }
    }
    if ($Runtime -eq 'pwsh') {
        $path = if ($IsWindows) { Join-Path $PSHOME 'pwsh.exe' } else { Join-Path $PSHOME 'pwsh' }
        return [ordered]@{ Path = $path; Version = [version]$PSVersionTable.PSVersion }
    }
    $command = Get-Command $Runtime -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -eq $command) { return $null }
    $output = switch ($Runtime) {
        'dotnet' {
            $sdkVersions = @(& $command.Source --list-sdks 2>$null | ForEach-Object { Parse-Version ([string]$_) } | Where-Object { $null -ne $_ } | Sort-Object -Descending)
            $compatible = @($sdkVersions | Where-Object { Test-Range $_ $VersionRange } | Select-Object -First 1)
            if ($compatible.Count -eq 1) { $compatible[0].ToString() }
            elseif ($sdkVersions.Count -gt 0) { $sdkVersions[0].ToString() }
            else { & $command.Source --version 2>$null }
        }
        'node' { & $command.Source --version 2>$null }
        'git' { & $command.Source --version 2>$null }
    }
    return [ordered]@{ Path = [IO.Path]::GetFullPath($command.Source); Version = Parse-Version (($output | Out-String).Trim()) }
}

try {
    $root = [IO.Path]::TrimEndingDirectorySeparator([IO.Path]::GetFullPath($PackageRoot))
    $report = [IO.Path]::GetFullPath($ReportPath)
    $checker = Join-Path $root 'core/runtime/Test-V4Package.ps1'
    $checkOutput = @(& pwsh -NoLogo -NoProfile -NonInteractive -File $checker -PackageRoot $root 2>&1)
    if ($LASTEXITCODE -ne 0) { throw "Package validation failed before prerequisite detection: $($checkOutput -join "`n")" }

    $requirementsPath = Join-Path $root 'core/distribution/runtime-requirements.json'
    if (-not (Test-Json -LiteralPath $requirementsPath -SchemaFile (Join-Path $root 'core/contracts/runtime-requirements.schema.json') -ErrorAction SilentlyContinue)) {
        throw 'Package runtime requirements violate their schema.'
    }
    $profilePath = Join-Path $root "profiles/catalog/$Profile/profile.json"
    $profileData = Read-Json $profilePath "profile $Profile"
    if ([string]$profileData.id -cne $Profile) { throw 'Profile path and identity differ.' }
    $registry = Read-Json (Join-Path $root 'modules/registry.json') 'module registry'
    $moduleById = @{}
    foreach ($entry in $registry.modules) { $moduleById[[string]$entry.id] = $entry }

    $declared = [Collections.Generic.List[object]]::new()
    $hostRequirements = Read-Json $requirementsPath 'runtime requirements'
    foreach ($item in $hostRequirements.requirements) {
        $declared.Add([ordered]@{ runtime=[string]$item.runtime; versionRange=[string]$item.versionRange; source='host' })
    }
    $selectedModules = @($profileData.moduleSelections | ForEach-Object { [string]$_.id } | Sort-Object -Unique)
    foreach ($moduleId in $selectedModules) {
        if (-not $moduleById.ContainsKey($moduleId)) { throw "Profile selects an unregistered module: $moduleId" }
        $manifest = Read-Json (Join-Path $root ([string]$moduleById[$moduleId].manifestPath)) "module $moduleId"
        foreach ($item in $manifest.prerequisites) {
            $declared.Add([ordered]@{ runtime=[string]$item.runtime; versionRange=[string]$item.versionRange; source="module:$moduleId" })
        }
    }

    $overrides = if ([string]::IsNullOrWhiteSpace($RuntimeOverridesJson)) { $null } else { $RuntimeOverridesJson | ConvertFrom-Json -AsHashtable -Depth 20 }
    $results = [Collections.Generic.List[object]]::new()
    foreach ($group in @($declared | Group-Object { "$($_.runtime)`0$($_.versionRange)" } | Sort-Object Name)) {
        $first = $group.Group[0]
        $detected = Detect-Runtime $first.runtime $first.versionRange $overrides
        $entry = [ordered]@{
            runtime = $first.runtime
            versionRange = $first.versionRange
            sources = @($group.Group.source | Sort-Object -Unique)
            status = 'missing'
        }
        if ($null -ne $detected -and $null -ne $detected.Version) {
            $entry.detectedVersion = $detected.Version.ToString()
            $entry.executablePath = [string]$detected.Path
            $entry.status = if (Test-Range $detected.Version $first.versionRange) { 'pass' } else { 'incompatible' }
        }
        $results.Add($entry)
    }
    $failed = @($results | Where-Object status -ne 'pass').Count -gt 0
    $document = [ordered]@{
        formatVersion = 1
        status = if ($failed) { 'error' } else { 'pass' }
        exitCategory = if ($failed) { 'prerequisite-missing' } else { 'success' }
        profile = $Profile
        selectedModules = $selectedModules
        requirements = @($results)
    }
    Write-Json $report $document
    if (-not (Test-Json -LiteralPath $report -SchemaFile (Join-Path $root 'core/contracts/prerequisite-report.schema.json') -ErrorAction SilentlyContinue)) {
        throw 'Generated prerequisite report violates its schema.'
    }
    $document | ConvertTo-Json -Depth 30
    if ($failed) { exit 15 }
    exit 0
}
catch {
    [Console]::Error.WriteLine($_.Exception.Message)
    exit 10
}
