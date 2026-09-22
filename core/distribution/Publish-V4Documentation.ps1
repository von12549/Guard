[CmdletBinding()]
param(
    [string] $PackageRoot = (Join-Path $PSScriptRoot '../..'),
    [ValidateSet('Write','Check')][string] $Mode = 'Check'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Read-Json([string] $Path) { Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json -AsHashtable -Depth 100 }
function Type-Label($Schema, [string] $Name) {
    $property = $Schema.properties[$Name]
    if ($property.ContainsKey('type')) { return [string]$property.type }
    if ($property.ContainsKey('enum')) { return 'enum: ' + (@($property.enum) -join ', ') }
    if ($property.ContainsKey('const')) { return 'constant' }
    if ($property.ContainsKey('$ref')) { return 'schema reference' }
    return 'structured value'
}
function Save-Or-Check([string] $Path, [string] $Content) {
    $normalized = $Content.Replace("`r`n","`n").TrimEnd() + "`n"
    if ($Mode -eq 'Write') {
        [void][IO.Directory]::CreateDirectory((Split-Path -Parent $Path))
        [IO.File]::WriteAllText($Path,$normalized,[Text.UTF8Encoding]::new($false)); return
    }
    if (-not [IO.File]::Exists($Path) -or [IO.File]::ReadAllText($Path).Replace("`r`n","`n") -cne $normalized) { throw "Generated documentation drift: $Path" }
}

$root = [IO.Path]::TrimEndingDirectorySeparator([IO.Path]::GetFullPath($PackageRoot))
$cli = Read-Json (Join-Path $root 'core/contracts/cli-contract.json')
$commandLines = [Collections.Generic.List[string]]::new()
$commandLines.Add('# V4 command reference')
$commandLines.Add('')
$commandLines.Add('Generated from `core/contracts/cli-contract.json`. Do not edit by hand.')
$commandLines.Add('')
$commandLines.Add("API version: ``$($cli.apiVersion)``")
$commandLines.Add('')
$commandLines.Add('| Command | Stability | Mutability | Required roots | Syntax |')
$commandLines.Add('| --- | --- | --- | --- | --- |')
foreach ($command in $cli.commands) {
    $roots = if (@($command.requiredRoots).Count) { @($command.requiredRoots) -join ', ' } else { 'none' }
    $commandLines.Add("| ``$($command.id)`` | $($command.stability) | $($command.mutability) | $roots | ``$($command.syntax)`` |")
}
$commandLines.Add('')
$commandLines.Add('## Exit categories')
$commandLines.Add('')
$commandLines.Add('| Category | Code |')
$commandLines.Add('| --- | ---: |')
foreach ($exit in $cli.exitCategories | Sort-Object code) { $commandLines.Add("| ``$($exit.id)`` | $($exit.code) |") }
Save-Or-Check (Join-Path $root 'docs/commands.md') ($commandLines -join "`n")

$configLines = [Collections.Generic.List[string]]::new()
$configLines.Add('# V4 configuration reference')
$configLines.Add('')
$configLines.Add('Generated from package schemas and module manifests. Do not edit by hand.')
foreach ($schemaName in @('plugin','profile','module','runtime-requirements')) {
    $schema = Read-Json (Join-Path $root "core/contracts/$schemaName.schema.json")
    $configLines.Add('')
    $configLines.Add("## ``$schemaName``")
    $configLines.Add('')
    $configLines.Add('| Property | Required | Shape |')
    $configLines.Add('| --- | --- | --- |')
    foreach ($name in @($schema.properties.Keys | Sort-Object)) {
        $required = if (@($schema.required) -contains $name) { 'yes' } else { 'no' }
        $configLines.Add("| ``$name`` | $required | $(Type-Label $schema $name) |")
    }
}
$configLines.Add('')
$configLines.Add('## Installed modules')
$configLines.Add('')
$configLines.Add('| Module | Version | Platforms | Prerequisites | Stages |')
$configLines.Add('| --- | --- | --- | --- | --- |')
$registry = Read-Json (Join-Path $root 'modules/registry.json')
foreach ($entry in $registry.modules | Sort-Object id) {
    $module = Read-Json (Join-Path $root ([string]$entry.manifestPath))
    $prerequisites = @($module.prerequisites | ForEach-Object { "$($_.runtime) $($_.versionRange)" }) -join '; '
    $configLines.Add("| ``$($module.id)`` | $($module.version) | $(@($module.supportedPlatforms) -join ', ') | $prerequisites | $(@($module.stages) -join ', ') |")
}
Save-Or-Check (Join-Path $root 'docs/configuration.md') ($configLines -join "`n")
[ordered]@{ formatVersion=1; status='pass'; mode=$Mode.ToLowerInvariant(); files=@('docs/commands.md','docs/configuration.md') } | ConvertTo-Json
