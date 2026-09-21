[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$packageRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $packageRoot '../../..'))
$buildRoot = Join-Path $packageRoot 'build'
$project = Join-Path $packageRoot 'core/host/V4.Guards.Host/V4.Guards.Host.csproj'
$artifactsRoot = Join-Path $repositoryRoot 'artifacts/guards/v4/p2b'
$runRoot = Join-Path $artifactsRoot 'fixture'
$failures = [Collections.Generic.List[string]]::new()

function Hash-Tree([string] $Root) {
    $items = [ordered]@{}
    Get-ChildItem -LiteralPath $Root -Recurse -File | Sort-Object FullName | ForEach-Object {
        $relative = [IO.Path]::GetRelativePath($Root, $_.FullName).Replace('\', '/')
        $items[$relative] = (Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName).Hash.ToLowerInvariant()
    }
    return ($items | ConvertTo-Json -Compress)
}

function Invoke-Host([string[]] $Arguments) {
    $dll = Join-Path $artifactsRoot 'bin/V4.Guards.Host/debug/v4-guards.dll'
    $output = @(& dotnet $dll @Arguments 2>&1)
    [pscustomobject]@{ Code = $LASTEXITCODE; Output = ($output -join "`n") }
}

function Success([string] $Name, $Run) {
    if ($Run.Code -ne 0) { $failures.Add("${Name}: expected success, got $($Run.Code): $($Run.Output)"); return $null }
    try { return $Run.Output | ConvertFrom-Json }
    catch { $failures.Add("${Name}: invalid JSON output: $($Run.Output)"); return $null }
}

function Failure([string] $Name, $Run, [int] $Code, [string] $Category) {
    if ($Run.Code -ne $Code) { $failures.Add("${Name}: expected exit $Code, got $($Run.Code): $($Run.Output)") }
    if ($Run.Output -notmatch ('"exitCategory"\s*:\s*"' + [Regex]::Escape($Category) + '"')) { $failures.Add("${Name}: missing category $Category") }
}

function Bind([string] $Target, [string] $Profile = 'synthetic_profile') {
    Success "bind $Target" (Invoke-Host @('state','bind','--package-root',$packageRoot,'--target-root',$Target,'--state-root',$state,'--evidence-root',$evidence,'--profile',$Profile))
}

function Put([string] $ProjectId, [string] $Path, [string] $Content) {
    Success "put $Path" (Invoke-Host @('state','put','--package-root',$packageRoot,'--state-root',$state,'--evidence-root',$evidence,'--project',$ProjectId,'--relative-path',$Path,'--content',$Content))
}

function Preview([string] $Scope, [string] $ProjectId = '') {
    $args = @('reset',$Scope,'--mode','preview','--package-root',$packageRoot,'--state-root',$state,'--evidence-root',$evidence)
    if ($Scope -eq 'project') { $args += @('--project',$ProjectId) }
    Success "$Scope preview" (Invoke-Host $args)
}

function Apply([string] $Scope, [string] $Hash, [string] $ProjectId = '') {
    $args = @('reset',$Scope,'--mode','apply','--package-root',$packageRoot,'--state-root',$state,'--evidence-root',$evidence,'--accept-manifest-hash',$Hash)
    if ($Scope -eq 'project') { $args += @('--project',$ProjectId) }
    Success "$Scope apply" (Invoke-Host $args)
}

if (Test-Path -LiteralPath $runRoot) { Remove-Item -LiteralPath $runRoot -Recurse -Force }
New-Item -ItemType Directory -Path $runRoot -Force | Out-Null
$properties = @(
    '-p:ImportDirectoryBuildProps=false', '-p:ImportDirectoryBuildTargets=false', '-p:ImportDirectoryPackagesProps=false',
    '-p:ImportDirectorySolutionProps=false', '-p:ImportDirectorySolutionTargets=false',
    "-p:CustomBeforeMicrosoftCommonProps=$(Join-Path $buildRoot 'V4.Build.props')"
)
Push-Location $buildRoot
try {
    & dotnet restore $project --configfile (Join-Path $buildRoot 'NuGet.config') --artifacts-path $artifactsRoot -nologo @properties
    if ($LASTEXITCODE) { throw 'V4 P2B restore failed.' }
    & dotnet build $project --no-restore --artifacts-path $artifactsRoot -nologo @properties
    if ($LASTEXITCODE) { throw 'V4 P2B build failed.' }
} finally { Pop-Location }

$targetA = Join-Path $runRoot 'target-a'; $targetB = Join-Path $runRoot 'target-b'; $targetC = Join-Path $runRoot 'target-c'
$state = Join-Path $runRoot 'state'; $evidence = Join-Path $runRoot 'evidence'
foreach ($path in @($targetA,$targetB,$targetC,$state,$evidence)) { New-Item -ItemType Directory -Path $path -Force | Out-Null }
foreach ($target in @($targetA,$targetB,$targetC)) { [IO.File]::WriteAllText((Join-Path $target 'sentinel.txt'), "$target`n", [Text.UTF8Encoding]::new($false)) }
$packageBefore = Hash-Tree $packageRoot; $targetABefore = Hash-Tree $targetA; $targetBBefore = Hash-Tree $targetB; $targetCBefore = Hash-Tree $targetC

$a = Bind $targetA; $b = Bind $targetB 'default'
if ($null -eq $a -or $null -eq $b) { throw ($failures -join "`n") }
[void](Put $a.projectId 'cache/a.txt' 'a-v1'); [void](Put $b.projectId 'cache/b.txt' 'b-v1')
[IO.File]::WriteAllText((Join-Path $evidence "projects/$($a.projectId)/a.log"), 'evidence-a', [Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $evidence "projects/$($b.projectId)/b.log"), 'evidence-b', [Text.UTF8Encoding]::new($false))
New-Item -ItemType Directory -Path (Join-Path $state 'unclaimed') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $evidence 'unclaimed') -Force | Out-Null
[IO.File]::WriteAllText((Join-Path $state 'unclaimed/keep.txt'), 'keep-state', [Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $evidence 'unclaimed/keep.txt'), 'keep-evidence', [Text.UTF8Encoding]::new($false))

$previewA = Preview 'project' $a.projectId
if ($null -ne $previewA) {
    if (-not (Test-Json -LiteralPath $previewA.manifestPath -SchemaFile (Join-Path $packageRoot 'core/contracts/reset-manifest.schema.json') -ErrorAction SilentlyContinue)) { $failures.Add('project reset preview violates reset-manifest.schema.json') }
    [IO.File]::WriteAllText((Join-Path $state "projects/$($a.projectId)/data/cache/a.txt"), 'a-v2', [Text.UTF8Encoding]::new($false))
    $race = Invoke-Host @('reset','project','--mode','apply','--package-root',$packageRoot,'--state-root',$state,'--evidence-root',$evidence,'--project',$a.projectId,'--accept-manifest-hash',$previewA.manifestHash)
    Failure 'changed-after-preview' $race 18 'reset-refused'
}

$previewA2 = Preview 'project' $a.projectId
$applyA = if ($null -ne $previewA2) { Apply 'project' $previewA2.manifestHash $a.projectId } else { $null }
if ($null -eq $applyA -or $applyA.idempotent -or (Test-Path -LiteralPath (Join-Path $state "projects/$($a.projectId)")) -or (Test-Path -LiteralPath (Join-Path $evidence "projects/$($a.projectId)"))) { $failures.Add('project reset did not remove exactly project A claims') }
if (-not (Test-Path -LiteralPath (Join-Path $state "projects/$($b.projectId)")) -or -not (Test-Path -LiteralPath (Join-Path $evidence "projects/$($b.projectId)"))) { $failures.Add('project reset removed project B') }
if ($null -ne $previewA2) {
    $replay = Apply 'project' $previewA2.manifestHash $a.projectId
    if ($null -eq $replay -or -not $replay.idempotent -or $replay.receiptId -cne $applyA.receiptId) { $failures.Add('project reset replay is not idempotent') }
}

$c = Bind $targetC
if ($null -ne $c) {
    [void](Put $c.projectId 'cache/c.txt' 'c-v1')
    [IO.File]::WriteAllText((Join-Path $state "projects/$($c.projectId)/data/.git"), 'gitdir: elsewhere', [Text.UTF8Encoding]::new($false))
    Failure '.git marker refusal' (Invoke-Host @('reset','project','--mode','preview','--package-root',$packageRoot,'--state-root',$state,'--evidence-root',$evidence,'--project',$c.projectId)) 18 'reset-refused'
    Remove-Item -LiteralPath (Join-Path $state "projects/$($c.projectId)/data/.git") -Force

    $outside = Join-Path $runRoot 'outside-link-target'; New-Item -ItemType Directory -Path $outside -Force | Out-Null
    $link = Join-Path $state "projects/$($c.projectId)/data/link"
    try {
        if ($IsWindows) { New-Item -ItemType Junction -Path $link -Target $outside | Out-Null }
        else { New-Item -ItemType SymbolicLink -Path $link -Target $outside | Out-Null }
        Failure 'link/reparse refusal' (Invoke-Host @('reset','project','--mode','preview','--package-root',$packageRoot,'--state-root',$state,'--evidence-root',$evidence,'--project',$c.projectId)) 11 'unsafe-path'
    } catch { $failures.Add("link/reparse fixture could not be created: $($_.Exception.Message)") }
    finally { if (Test-Path -LiteralPath $link) { Remove-Item -LiteralPath $link -Force } }
}

Failure 'authority overlap refusal' (Invoke-Host @('reset','factory','--mode','preview','--package-root',$packageRoot,'--state-root',$packageRoot,'--evidence-root',$evidence)) 11 'unsafe-path'

$factoryPreview = Preview 'factory'
$factoryApply = if ($null -ne $factoryPreview) { Apply 'factory' $factoryPreview.manifestHash } else { $null }
if ($null -eq $factoryApply -or $factoryApply.idempotent) { $failures.Add('factory reset did not apply') }
if (@(Get-ChildItem -LiteralPath (Join-Path $state 'projects') -Force -ErrorAction SilentlyContinue).Count -ne 0) { $failures.Add('factory reset left bound state project paths') }
if (@(Get-ChildItem -LiteralPath (Join-Path $evidence 'projects') -Force -ErrorAction SilentlyContinue).Count -ne 0) { $failures.Add('factory reset left bound evidence project paths') }
if ((Get-Content -Raw (Join-Path $state 'unclaimed/keep.txt')) -cne 'keep-state' -or (Get-Content -Raw (Join-Path $evidence 'unclaimed/keep.txt')) -cne 'keep-evidence') { $failures.Add('reset changed unclaimed mutable paths') }
if ($null -ne $factoryPreview) {
    $factoryReplay = Apply 'factory' $factoryPreview.manifestHash
    if ($null -eq $factoryReplay -or -not $factoryReplay.idempotent) { $failures.Add('factory reset replay is not idempotent') }
}

if (-not (Test-Json -LiteralPath (Join-Path $state 'state.json') -SchemaFile (Join-Path $packageRoot 'core/contracts/state.schema.json') -ErrorAction SilentlyContinue)) { $failures.Add('post-reset state document violates state schema') }
if ((Hash-Tree $packageRoot) -cne $packageBefore) { $failures.Add('reset changed PackageRoot') }
if ((Hash-Tree $targetA) -cne $targetABefore -or (Hash-Tree $targetB) -cne $targetBBefore -or (Hash-Tree $targetC) -cne $targetCBefore) { $failures.Add('reset changed a TargetRoot') }

if ($failures.Count -gt 0) { throw ($failures -join "`n") }
Write-Host 'V4 P2B reset tests passed: Preview/Apply, race refusal, project/factory scope, link/git/authority negatives, receipts and idempotency.'
