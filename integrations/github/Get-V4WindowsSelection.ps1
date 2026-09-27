[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $ContractPath,
    [string[]] $ChangedPath = @(),
    [string] $ChangedPathsJson,
    [ValidateSet('auto','smoke','full')][string] $RequestedCoverage = 'auto',
    [string] $GitHubOutput,
    [string] $ReportPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-Glob([string] $Path, [string] $Pattern) {
    $text = $Pattern.Replace('\','/')
    $builder = [Text.StringBuilder]::new('^')
    for ($index = 0; $index -lt $text.Length; $index++) {
        if ($index + 2 -lt $text.Length -and $text.Substring($index, 3) -eq '**/') { [void]$builder.Append('(?:.*/)?'); $index += 2 }
        elseif ($index + 1 -lt $text.Length -and $text.Substring($index, 2) -eq '**') { [void]$builder.Append('.*'); $index++ }
        elseif ($text[$index] -eq '*') { [void]$builder.Append('[^/]*') }
        elseif ($text[$index] -eq '?') { [void]$builder.Append('[^/]') }
        else { [void]$builder.Append([Regex]::Escape([string]$text[$index])) }
    }
    [void]$builder.Append('$')
    return [Regex]::IsMatch($Path.Replace('\','/'), $builder.ToString(), [Text.RegularExpressions.RegexOptions]::CultureInvariant)
}

function Write-Utf8([string] $Path, [string] $Text) {
    $parent = [IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($Path))
    if (-not [IO.Directory]::Exists($parent)) { [void][IO.Directory]::CreateDirectory($parent) }
    [IO.File]::WriteAllText([IO.Path]::GetFullPath($Path), $Text, [Text.UTF8Encoding]::new($false))
}

$contractFull = [IO.Path]::GetFullPath($ContractPath)
$integrationRoot = [IO.Path]::GetDirectoryName($contractFull)
$packageRoot = [IO.Path]::GetFullPath((Join-Path $integrationRoot '../..'))
$schema = Join-Path $packageRoot 'core/contracts/ci-contract.schema.json'
if (-not [IO.File]::Exists($contractFull) -or -not (Test-Json -LiteralPath $contractFull -SchemaFile $schema -ErrorAction SilentlyContinue)) {
    throw 'CI contract is missing or violates ci-contract.schema.json.'
}
$contract = Get-Content -Raw -LiteralPath $contractFull | ConvertFrom-Json -AsHashtable -Depth 100
$inputPaths = @($ChangedPath)
if ($ChangedPathsJson) {
    try { $decoded = @($ChangedPathsJson | ConvertFrom-Json -Depth 10) } catch { throw "ChangedPathsJson is invalid: $($_.Exception.Message)" }
    $inputPaths += $decoded
}
$normalized = @($inputPaths | ForEach-Object {
    $value = ([string]$_).Replace('\','/')
    if ([string]::IsNullOrWhiteSpace($value) -or [IO.Path]::IsPathRooted($value) -or $value -match '^[A-Za-z]:' -or @($value.Split('/') | Where-Object { $_ -in @('', '.', '..') }).Count -gt 0) { throw "Unsafe changed path: $_" }
    $value
} | Sort-Object -Unique -CaseSensitive)
if ($normalized.Count -eq 0) { throw 'At least one changed path is required.' }

$outside = @($normalized | Where-Object { $path = $_; @($contract.allowedChangedPatterns | Where-Object { Test-Glob $path $_ }).Count -eq 0 })
if ($outside.Count -gt 0) { throw "Changed paths are outside the V4-only CI scope: $($outside -join ', ')" }
$sensitive = @($normalized | Where-Object { $path = $_; @($contract.windowsSensitivePatterns | Where-Object { Test-Glob $path $_ }).Count -gt 0 })
$coverage = switch ($RequestedCoverage) {
    'full' { 'full' }
    'smoke' { 'smoke' }
    default { if ($sensitive.Count -gt 0) { 'smoke' } else { 'none' } }
}
$required = $coverage -ne 'none'
$result = [ordered]@{
    formatVersion = 1
    status = 'pass'
    requestedCoverage = $RequestedCoverage
    windowsRequired = $required
    selectedCoverage = $coverage
    changedPaths = $normalized
    sensitivePaths = $sensitive
}
$json = ($result | ConvertTo-Json -Depth 20)
if ($ReportPath) { Write-Utf8 $ReportPath ($json + "`n") }
if ($GitHubOutput) {
    [IO.File]::AppendAllText([IO.Path]::GetFullPath($GitHubOutput), "windows-required=$($required.ToString().ToLowerInvariant())`nwindows-coverage=$coverage`n", [Text.UTF8Encoding]::new($false))
}
$json
