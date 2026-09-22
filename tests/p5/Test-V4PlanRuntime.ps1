[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$packageRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $packageRoot '../../..'))
$runRoot = Join-Path $repositoryRoot 'artifacts/guards/v4/p5/runtime'
$project = Join-Path $packageRoot 'core/host/V4.Guards.Host/V4.Guards.Host.csproj'
$buildRoot = Join-Path $packageRoot 'build'
$dll = Join-Path $runRoot 'build/bin/V4.Guards.Host/debug/v4-guards.dll'
$target = Join-Path $runRoot 'target'
$evidence = Join-Path $runRoot 'evidence'
$failures = [Collections.Generic.List[string]]::new()

function Write-Utf8([string] $Path, [string] $Text) { $parent = [IO.Path]::GetDirectoryName($Path); if (-not [IO.Directory]::Exists($parent)) { [void][IO.Directory]::CreateDirectory($parent) }; [IO.File]::WriteAllText($Path, $Text, [Text.UTF8Encoding]::new($false)) }
function Write-Json([string] $Path, $Value) { Write-Utf8 $Path (($Value | ConvertTo-Json -Depth 100) + "`n") }
function New-Plan([string] $Id, [string[]] $Paths, [string[]] $Dependencies = @(), [string[]] $Boundaries = @(), [string[]] $Areas = @('runtime')) {
    [ordered]@{ formatVersion = 1; id = $Id; title = "Plan $Id"; goal = "Prove $Id"; acceptanceCriteria = @('observable'); plannedPaths = $Paths; areas = $Areas; risks = @("risk-$Id"); decisions = @("decision-$Id"); validationCommands = @("validate-$Id"); dependencies = $Dependencies; boundaries = $Boundaries }
}
function Invoke-Plan([string[]] $Arguments) { $output = @(& dotnet $dll @Arguments 2>&1); [pscustomobject]@{ Code = $LASTEXITCODE; Text = ($output -join "`n") } }
function Expect-Code($Run, [int] $Code, [string] $Name, [string] $Pattern = '') { if ($Run.Code -ne $Code -or ($Pattern -and $Run.Text -notmatch $Pattern)) { $failures.Add("${Name}: expected $Code/$Pattern, got $($Run.Code): $($Run.Text)") } }

if (Test-Path $runRoot) {
    $resolved = [IO.Path]::GetFullPath($runRoot)
    $prefix = [IO.Path]::GetFullPath((Join-Path $repositoryRoot 'artifacts/guards/v4')).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    if (-not $resolved.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { throw "Unsafe cleanup: $resolved" }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
[void][IO.Directory]::CreateDirectory($target); [void][IO.Directory]::CreateDirectory($evidence)
$properties = @('-p:ImportDirectoryBuildProps=false','-p:ImportDirectoryBuildTargets=false','-p:ImportDirectoryPackagesProps=false','-p:ImportDirectorySolutionProps=false','-p:ImportDirectorySolutionTargets=false',"-p:CustomBeforeMicrosoftCommonProps=$(Join-Path $buildRoot 'V4.Build.props')")
Push-Location $buildRoot
try {
    & dotnet restore $project --configfile (Join-Path $buildRoot 'NuGet.config') --artifacts-path (Join-Path $runRoot 'build') -nologo @properties
    if ($LASTEXITCODE) { throw 'P5 runtime restore failed.' }
    & dotnet build $project --no-restore --artifacts-path (Join-Path $runRoot 'build') -nologo @properties
    if ($LASTEXITCODE) { throw 'P5 runtime build failed.' }
}
finally { Pop-Location }

$a = 'plans/20260922-alpha.plan.json'; $b = 'plans/20260922-beta.plan.json'
Write-Json (Join-Path $target $a) (New-Plan '20260922-alpha' @('src/a.txt','plans/20260922-alpha.plan.json'))
Write-Json (Join-Path $target $b) (New-Plan '20260922-beta' @('src/b.txt','plans/20260922-beta.plan.json') @('20260922-alpha'))
Expect-Code (Invoke-Plan @('plan','validate','--package-root',$packageRoot,'--target-root',$target,'--plan',$a)) 0 'single Plan validation' '"status": "pass"'
$compose = @('plan','compose','--package-root',$packageRoot,'--target-root',$target,'--evidence-root',$evidence,'--id','20260922-alpha-beta','--plan',$b,'--plan',$a)
Expect-Code (Invoke-Plan ($compose + @('--output','one.plan-set.json'))) 0 'first composition' '"memberCount": 2'
Expect-Code (Invoke-Plan ($compose + @('--output','two.plan-set.json'))) 0 'second composition'
$oneBytes = [IO.File]::ReadAllBytes((Join-Path $evidence 'one.plan-set.json'))
$twoBytes = [IO.File]::ReadAllBytes((Join-Path $evidence 'two.plan-set.json'))
if (-not [Linq.Enumerable]::SequenceEqual[byte]($oneBytes, $twoBytes)) { $failures.Add('Repeated composition is not byte-for-byte deterministic.') }
$set = Get-Content -Raw (Join-Path $evidence 'one.plan-set.json') | ConvertFrom-Json -AsHashtable -Depth 100
if (($set.members.planId -join ',') -cne '20260922-alpha,20260922-beta' -or ($set.members.order -join ',') -cne '1,2') { $failures.Add('Dependency order is not deterministic.') }
$expectedPaths = @('plans/20260922-alpha.plan.json','plans/20260922-beta.plan.json','src/a.txt','src/b.txt')
if (($set.derivedUnion.plannedPaths -join ',') -cne ($expectedPaths -join ',')) { $failures.Add('Derived planned-path union is not exact and sorted.') }
if ($set.members[0].sha256 -cne (Get-FileHash -Algorithm SHA256 (Join-Path $target $a)).Hash.ToLowerInvariant()) { $failures.Add('Member byte hash is not bound.') }
if (-not (Test-Json -LiteralPath (Join-Path $evidence 'one.plan-set.json') -SchemaFile (Join-Path $packageRoot 'core/contracts/plan-set.schema.json') -ErrorAction SilentlyContinue)) { $failures.Add('Composed plan-set violates its schema.') }

Write-Json (Join-Path $target 'plans/missing.plan.json') (New-Plan '20260922-missing' @('src/missing.txt') @('20260922-not-selected'))
Expect-Code (Invoke-Plan @('plan','compose','--package-root',$packageRoot,'--target-root',$target,'--evidence-root',$evidence,'--id','20260922-missing-set','--plan',$a,'--plan','plans/missing.plan.json','--output','missing.plan-set.json')) 10 'missing dependency' 'unselected dependency'
Write-Json (Join-Path $target 'plans/cycle-a.plan.json') (New-Plan '20260922-cycle-a' @('src/cycle-a.txt') @('20260922-cycle-b'))
Write-Json (Join-Path $target 'plans/cycle-b.plan.json') (New-Plan '20260922-cycle-b' @('src/cycle-b.txt') @('20260922-cycle-a'))
Expect-Code (Invoke-Plan @('plan','compose','--package-root',$packageRoot,'--target-root',$target,'--evidence-root',$evidence,'--id','20260922-cycle-set','--plan','plans/cycle-a.plan.json','--plan','plans/cycle-b.plan.json','--output','cycle.plan-set.json')) 10 'dependency cycle' 'contains a cycle'
Write-Json (Join-Path $target 'plans/duplicate.plan.json') (New-Plan '20260922-alpha' @('src/duplicate.txt'))
Expect-Code (Invoke-Plan @('plan','compose','--package-root',$packageRoot,'--target-root',$target,'--evidence-root',$evidence,'--id','20260922-duplicate-set','--plan',$a,'--plan','plans/duplicate.plan.json','--output','duplicate.plan-set.json')) 10 'duplicate identity' 'Duplicate Plan ID'
Write-Json (Join-Path $target 'plans/owner.plan.json') (New-Plan '20260922-owner' @('src/a.txt'))
Expect-Code (Invoke-Plan @('plan','compose','--package-root',$packageRoot,'--target-root',$target,'--evidence-root',$evidence,'--id','20260922-owner-set','--plan',$a,'--plan','plans/owner.plan.json','--output','owner.plan-set.json')) 10 'conflicting ownership' 'Conflicting planned path ownership'
Write-Json (Join-Path $target 'plans/unsafe.plan.json') (New-Plan '20260922-unsafe' @('../escape.txt'))
Expect-Code (Invoke-Plan @('plan','validate','--package-root',$packageRoot,'--target-root',$target,'--plan','plans/unsafe.plan.json')) 11 'unsafe planned path' 'unsafe-path'

$pairs = @(@('authorization','trust-change'),@('authorization','activation'),@('trust-change','activation'),@('engine-change','remote-change'))
for ($index = 0; $index -lt $pairs.Count; $index++) {
    $left = "plans/boundary-$index-a.plan.json"; $right = "plans/boundary-$index-b.plan.json"
    Write-Json (Join-Path $target $left) (New-Plan "20260922-boundary-$index-a" @("src/boundary-$index-a.txt") @() @($pairs[$index][0]))
    Write-Json (Join-Path $target $right) (New-Plan "20260922-boundary-$index-b" @("src/boundary-$index-b.txt") @() @($pairs[$index][1]))
    Expect-Code (Invoke-Plan @('plan','compose','--package-root',$packageRoot,'--target-root',$target,'--evidence-root',$evidence,'--id',"20260922-boundary-$index-set",'--plan',$left,'--plan',$right,'--output',"boundary-$index.plan-set.json")) 10 "forbidden boundary pair $index" 'Forbidden co-bundling'
}

if ($failures.Count) { throw ($failures -join "`n") }
Write-Host 'V4 P5 Plan runtime tests passed: strict validation, deterministic binding/union, dependency and boundary negatives.'
