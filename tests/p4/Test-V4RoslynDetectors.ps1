[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$packageRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$moduleRoot = Join-Path $packageRoot 'modules/architecture-conformance'
$adapter = Join-Path $moduleRoot 'adapter.ps1'
$schema = Join-Path $moduleRoot 'result.schema.json'
$runRoot = Join-Path $packageRoot 'artifacts/p4c-fixtures'
$failures = [Collections.Generic.List[string]]::new()

function Hash-Tree([string] $Root) {
    $items=[ordered]@{}
    Get-ChildItem -LiteralPath $Root -Recurse -File | Sort-Object FullName | ForEach-Object {
        $items[[IO.Path]::GetRelativePath($Root,$_.FullName).Replace('\','/')] = (Get-FileHash -Algorithm SHA256 $_.FullName).Hash.ToLowerInvariant()
    }
    return ($items | ConvertTo-Json -Compress)
}
function New-Fixture([string] $Name, [string] $Source = '') {
    $root = Join-Path $runRoot $Name
    New-Item -ItemType Directory -Path $root -Force | Out-Null
    if (-not [string]::IsNullOrWhiteSpace($Source)) { [IO.File]::WriteAllText((Join-Path $root 'Sample.cs'), $Source, [Text.UTF8Encoding]::new($false)) }
    return $root
}
function Invoke-Detector([string] $Stage, [string] $Target, [string[]] $Claims) {
    $inputJson = [ordered]@{
        formatVersion=1; stage=$Stage; targetRoot=$Target; packageRoot=$packageRoot
        config=[ordered]@{
            enabledClaims=$Claims
            forbiddenImports=@('Forbidden.Import')
            forbiddenDeclarationNamespaces=@('Forbidden.Placement')
            forbiddenSymbols=@('System.IO.File')
            forbiddenPayloadNamespaces=@('System.IO')
        }
    } | ConvertTo-Json -Depth 20 -Compress
    $before = Hash-Tree $Target
    $previous = $env:V4_STAGE_INPUT_JSON
    try {
        $env:V4_STAGE_INPUT_JSON = $inputJson
        $output = @(& $adapter 2>&1)
    } finally {
        $env:V4_STAGE_INPUT_JSON = $previous
    }
    if ($LASTEXITCODE -notin @(0,$null)) { throw "Adapter exited ${LASTEXITCODE}: $($output -join "`n")" }
    $json = $output -join "`n"
    if (-not (Test-Json -Json $json -SchemaFile $schema -ErrorAction SilentlyContinue)) { $failures.Add("$Stage/$([IO.Path]::GetFileName($Target)): output violates result schema") }
    if ((Hash-Tree $Target) -cne $before) { $failures.Add("$Stage/$([IO.Path]::GetFileName($Target)): detector mutated TargetRoot") }
    if ((Test-Path (Join-Path $Target 'bin')) -or (Test-Path (Join-Path $Target 'obj'))) { $failures.Add("$Stage/$([IO.Path]::GetFileName($Target)): detector created build outputs") }
    return ($json | ConvertFrom-Json)
}
function Assert-Result($Result, [string] $Name, [string] $Category, [string[]] $Claims) {
    if ($Result.exitCategory -cne $Category) { $failures.Add("${Name}: expected $Category, got $($Result.exitCategory)") }
    foreach ($claim in $Claims) {
        $entry = @($Result.coverage | Where-Object claimId -ceq $claim)
        if ($entry.Count -ne 1) { $failures.Add("${Name}: expected one coverage entry for $claim") }
        elseif ($Category -eq 'prerequisite-missing' -and $entry[0].matched -ne 0) { $failures.Add("${Name}: missing-input coverage for $claim is not zero") }
        elseif ($Category -ne 'prerequisite-missing' -and $entry[0].matched -lt 1) { $failures.Add("${Name}: coverage for $claim is zero") }
    }
}

if (Test-Path $runRoot) {
    $resolved = [IO.Path]::GetFullPath($runRoot)
    $prefix = $packageRoot.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    if (-not $resolved.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)) { throw "Unsafe test cleanup path: $resolved" }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
New-Item -ItemType Directory -Path $runRoot -Force | Out-Null

$syntaxClaims = @('ARCH.SOURCE_IMPORT','ARCH.DISABLED_BRANCH','ARCH.DECLARATION_PLACEMENT')
$semanticClaims = @('ARCH.FORBIDDEN_SYMBOL','ARCH.MEMBER_PAYLOAD')
$cleanSource = @'
namespace Allowed;
public sealed class Clean
{
    public string Echo(string value) => value;
}
'@
$violatingSource = @'
using Forbidden.Import;
#if NEVER_DEFINED
internal sealed class Hidden { }
#endif
namespace Forbidden.Placement
{
    public sealed class Bad
    {
        public System.IO.Stream Leak(System.IO.Stream value)
        {
            return System.IO.File.OpenRead("ignored.txt");
        }
    }
}
'@

$clean = New-Fixture 'clean' $cleanSource
Assert-Result (Invoke-Detector 'pre' $clean $syntaxClaims) 'clean syntax' 'success' $syntaxClaims
Assert-Result (Invoke-Detector 'post' $clean $semanticClaims) 'clean semantic' 'success' $semanticClaims

$violating = New-Fixture 'violating' $violatingSource
$syntax = Invoke-Detector 'pre' $violating $syntaxClaims
Assert-Result $syntax 'violating syntax' 'findings-blocking' $syntaxClaims
foreach ($claim in $syntaxClaims) { if (@($syntax.findings.ruleId) -notcontains $claim) { $failures.Add("violating syntax lacks $claim") } }
$semantic = Invoke-Detector 'post' $violating $semanticClaims
Assert-Result $semantic 'violating semantic' 'findings-blocking' $semanticClaims
foreach ($claim in $semanticClaims) { if (@($semantic.findings.ruleId) -notcontains $claim) { $failures.Add("violating semantic lacks $claim") } }

$missing = New-Fixture 'missing'
Assert-Result (Invoke-Detector 'pre' $missing $syntaxClaims) 'missing syntax' 'prerequisite-missing' $syntaxClaims
Assert-Result (Invoke-Detector 'post' $missing $semanticClaims) 'missing semantic' 'prerequisite-missing' $semanticClaims

if ($failures.Count) { throw ($failures -join "`n") }
Write-Host 'V4 P4C Roslyn detector tests passed: syntax/semantic findings, clean coverage, missing-input failure and zero target execution.'
