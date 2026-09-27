[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$packageRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $packageRoot '../../..'))
$runRoot = Join-Path $repositoryRoot 'artifacts/guards/v4/p5/git-diff'
$integration = Join-Path $packageRoot 'integrations/git/Invoke-V4PlanDiff.ps1'
$project = Join-Path $packageRoot 'core/host/V4.Guards.Host/V4.Guards.Host.csproj'
$buildRoot = Join-Path $packageRoot 'build'
$dll = Join-Path $runRoot 'build/bin/V4.Guards.Host/debug/v4-guards.dll'
$failures = [Collections.Generic.List[string]]::new()

function Write-Utf8([string] $Path, [string] $Text) { $parent = [IO.Path]::GetDirectoryName($Path); if (-not [IO.Directory]::Exists($parent)) { [void][IO.Directory]::CreateDirectory($parent) }; [IO.File]::WriteAllText($Path, $Text, [Text.UTF8Encoding]::new($false)) }
function Write-Json([string] $Path, $Value) { Write-Utf8 $Path (($Value | ConvertTo-Json -Depth 100) + "`n") }
function New-Plan([string] $Id, [string[]] $Paths, [string[]] $Dependencies = @()) { [ordered]@{ formatVersion = 1; id = $Id; title = $Id; goal = "Prove $Id"; acceptanceCriteria = @('exact diff'); plannedPaths = $Paths; areas = @('git-integration'); risks = @(); decisions = @(); validationCommands = @('git-diff'); dependencies = $Dependencies; boundaries = @() } }
function New-Case([string] $Name, [switch] $ExtraChanged, [switch] $UnchangedPlanned) {
    $root = Join-Path $runRoot "cases/$Name"; $repo = Join-Path $root 'repo'; $evidence = Join-Path $root 'evidence'; [void][IO.Directory]::CreateDirectory($repo); [void][IO.Directory]::CreateDirectory($evidence)
    & git -C $repo init -q; & git -C $repo config user.email p5@example.invalid; & git -C $repo config user.name 'V4 P5'; & git -C $repo commit --allow-empty -q -m base
    $base = (& git -C $repo rev-parse HEAD).Trim()
    $aPaths = @('plans/20260922-git-a.plan.json','src/a.txt'); $bPaths = @('plans/20260922-git-b.plan.json','src/b.txt')
    if ($UnchangedPlanned) { $bPaths += 'src/never-changed.txt' }
    Write-Json (Join-Path $repo 'plans/20260922-git-a.plan.json') (New-Plan '20260922-git-a' $aPaths)
    Write-Json (Join-Path $repo 'plans/20260922-git-b.plan.json') (New-Plan '20260922-git-b' $bPaths @('20260922-git-a'))
    Write-Utf8 (Join-Path $repo 'src/a.txt') "a`n"; Write-Utf8 (Join-Path $repo 'src/b.txt') "b`n"
    if ($ExtraChanged) { Write-Utf8 (Join-Path $repo 'src/undeclared.txt') "undeclared`n" }
    & git -C $repo add --all; & git -C $repo commit -q -m head
    $head = (& git -C $repo rev-parse HEAD).Trim()
    $compose = @('plan','compose','--package-root',$packageRoot,'--target-root',$repo,'--evidence-root',$evidence,'--id',"20260922-$Name-set",'--plan','plans/20260922-git-b.plan.json','--plan','plans/20260922-git-a.plan.json','--output','bundle.plan-set.json')
    $composeOutput = @(& dotnet $dll @compose 2>&1); if ($LASTEXITCODE) { throw "Composition failed for ${Name}: $($composeOutput -join "`n")" }
    [pscustomobject]@{ Repository = $repo; Evidence = $evidence; Base = $base; Head = $head }
}
function Invoke-Diff($Case, [string] $Report) { $output = @(& pwsh -NoProfile -File $integration -PackageRoot $packageRoot -RepositoryRoot $Case.Repository -EvidenceRoot $Case.Evidence -PlanSetPath bundle.plan-set.json -BaseRef $Case.Base -HeadRef $Case.Head -ReportPath $Report 2>&1); [pscustomobject]@{ Code = $LASTEXITCODE; Text = ($output -join "`n"); Report = (Join-Path $Case.Evidence $Report) } }
function Expect($Run, [int] $Code, [string] $Category, [string] $Name) { if ($Run.Code -ne $Code -or -not (Test-Path $Run.Report)) { $failures.Add("${Name}: expected code $Code and a report, got $($Run.Code): $($Run.Text)"); return }; $report = Get-Content -Raw $Run.Report | ConvertFrom-Json; if ($report.exitCategory -cne $Category) { $failures.Add("${Name}: expected $Category, got $($report.exitCategory)") } }

if (Test-Path $runRoot) {
    $resolved = [IO.Path]::GetFullPath($runRoot); $prefix = [IO.Path]::GetFullPath((Join-Path $repositoryRoot 'artifacts/guards/v4')).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    if (-not $resolved.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { throw "Unsafe cleanup: $resolved" }; Remove-Item -LiteralPath $resolved -Recurse -Force
}
[void][IO.Directory]::CreateDirectory($runRoot)
$properties = @('-p:ImportDirectoryBuildProps=false','-p:ImportDirectoryBuildTargets=false','-p:ImportDirectoryPackagesProps=false','-p:ImportDirectorySolutionProps=false','-p:ImportDirectorySolutionTargets=false',"-p:CustomBeforeMicrosoftCommonProps=$(Join-Path $buildRoot 'V4.Build.props')")
Push-Location $buildRoot
try { & dotnet restore $project --configfile (Join-Path $buildRoot 'NuGet.config') --artifacts-path (Join-Path $runRoot 'build') -nologo @properties; if ($LASTEXITCODE) { throw 'P5 Git restore failed.' }; & dotnet build $project --no-restore --artifacts-path (Join-Path $runRoot 'build') -nologo @properties; if ($LASTEXITCODE) { throw 'P5 Git build failed.' } }
finally { Pop-Location }

$exact = New-Case 'git-exact'; Expect (Invoke-Diff $exact 'exact.json') 0 'success' 'exact diff'
$under = New-Case 'git-under' -ExtraChanged; $underRun = Invoke-Diff $under 'under.json'; Expect $underRun 16 'findings-blocking' 'undeclared changed path'; if ((Get-Content -Raw $underRun.Report | ConvertFrom-Json).undeclaredPaths -cnotcontains 'src/undeclared.txt') { $failures.Add('Undeclared path was not reported.') }
$over = New-Case 'git-over' -UnchangedPlanned; $overRun = Invoke-Diff $over 'over.json'; Expect $overRun 16 'findings-blocking' 'unchanged planned path'; if ((Get-Content -Raw $overRun.Report | ConvertFrom-Json).unchangedPaths -cnotcontains 'src/never-changed.txt') { $failures.Add('Unchanged planned path was not reported.') }
$bundlePath = Join-Path $exact.Evidence 'bundle.plan-set.json'; $bundle = Get-Content -Raw $bundlePath | ConvertFrom-Json -AsHashtable -Depth 100; $validCompositionHash = $bundle.compositionHash; $bundle.compositionHash = 'f' * 64; Write-Json $bundlePath $bundle
$compositionDrift = Invoke-Diff $exact 'composition-drift.json'; Expect $compositionDrift 12 'integrity-failure' 'composition hash drift'; $bundle.compositionHash = $validCompositionHash; Write-Json $bundlePath $bundle
Write-Utf8 (Join-Path $exact.Repository 'plans/20260922-git-a.plan.json') "{}"; $drift = Invoke-Diff $exact 'drift.json'; Expect $drift 12 'integrity-failure' 'member hash drift'

if ($failures.Count) { throw ($failures -join "`n") }
Write-Host 'V4 P5 Git integration tests passed: exact diff, undeclared, unchanged, composition-hash and member-hash drift cases.'
