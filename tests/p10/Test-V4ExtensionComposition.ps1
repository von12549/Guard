[CmdletBinding()]
param(
    [string] $BaseInstallRoot = '',
    [string] $BaseReceiptPath = '',
    [string] $BaseArchivePath = '',
    [string] $BaseReceiptTemplatePath = '',
    [string] $FixtureSourceCommit = '',
    [string] $EvidenceParent = (Join-Path $PSScriptRoot '../../../../../artifacts/guards/p10-composition')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Hash([string] $Path) { (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant() }
function Write-Json([string] $Path, $Value) {
    [void][IO.Directory]::CreateDirectory((Split-Path -Parent $Path))
    [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth 100).Replace("`r`n", "`n") + "`n"), [Text.UTF8Encoding]::new($false))
}
function Read-Json([string] $Path) { Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json -AsHashtable -Depth 100 }
function Assert([bool] $Condition, [string] $Message) { if (-not $Condition) { throw $Message } }

$packageSource = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$composer = Join-Path $packageSource 'core/distribution/Compose-V4Extension.ps1'
$verifier = Join-Path $packageSource 'core/distribution/Test-V4ComposedInstallation.ps1'
$parent = [IO.Path]::GetFullPath($EvidenceParent)
[void][IO.Directory]::CreateDirectory($parent)
$providedBaseInputs = @($BaseInstallRoot,$BaseReceiptPath,$BaseArchivePath | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
if ($providedBaseInputs.Count -ne 0 -and $providedBaseInputs.Count -ne 3) { throw 'Provide all three base paths or none.' }
$selfContainedCandidate = $providedBaseInputs.Count -eq 0
if (-not $selfContainedCandidate -and $FixtureSourceCommit) { throw 'FixtureSourceCommit is only for self-contained candidate smoke tests.' }
if ($selfContainedCandidate) {
    $candidate = Read-Json (Join-Path $packageSource 'plugin.json')
    Assert ($candidate.version -ceq '1.1.1' -and $candidate.apiVersion -ceq '1.0') 'Self-contained P10 certification requires the 1.1.1 candidate'
    $fixtureRoot = Join-Path $parent ('candidate-fixture-' + [Guid]::NewGuid().ToString('N'))
    [void][IO.Directory]::CreateDirectory($fixtureRoot)
    $repository = [IO.Path]::GetFullPath((Join-Path $packageSource '../../..'))
    $buildRoot = Join-Path $packageSource 'build'
    $buildArtifacts = Join-Path $fixtureRoot 'build'
    $hostProject = Join-Path $packageSource 'core/host/V4.Guards.Host/V4.Guards.Host.csproj'
    $companionProject = Join-Path $packageSource 'integrations/web/V4.Guards.WebCompanion/V4.Guards.WebCompanion.csproj'
    $properties = @('-p:ImportDirectoryBuildProps=false','-p:ImportDirectoryBuildTargets=false',
        '-p:ImportDirectoryPackagesProps=false','-p:ImportDirectorySolutionProps=false',
        '-p:ImportDirectorySolutionTargets=false',"-p:CustomBeforeMicrosoftCommonProps=$(Join-Path $buildRoot 'V4.Build.props')")
    $originalAppData = $env:APPDATA
    if ($IsWindows) {
        $env:APPDATA = Join-Path $fixtureRoot 'roaming-app-data'
        [void][IO.Directory]::CreateDirectory($env:APPDATA)
    }
    Push-Location $buildRoot
    try {
        foreach ($project in @($hostProject,$companionProject)) {
            & dotnet restore $project --configfile (Join-Path $buildRoot 'NuGet.config') --artifacts-path $buildArtifacts -nologo @properties
            Assert ($LASTEXITCODE -eq 0) "Candidate fixture restore failed: $project"
            & dotnet build $project --no-restore --configuration Release --artifacts-path $buildArtifacts -nologo @properties
            Assert ($LASTEXITCODE -eq 0) "Candidate fixture build failed: $project"
        }
    } finally {
        Pop-Location
        if ($IsWindows) { $env:APPDATA = $originalAppData }
    }
    $sourceCommit = if ($FixtureSourceCommit) { $FixtureSourceCommit.ToLowerInvariant() }
        else { (& git -C $repository rev-parse HEAD).Trim().ToLowerInvariant() }
    Assert ($sourceCommit -match '^[a-f0-9]{40}$') 'Candidate fixture source commit is unavailable'
    $distribution = Join-Path $packageSource 'core/distribution/New-V4Distribution.ps1'
    $distributionArguments = @('-PackageRoot',$packageSource,
        '-HostRoot',(Join-Path $buildArtifacts 'bin/V4.Guards.Host/release'),
        '-CompanionRoot',(Join-Path $buildArtifacts 'bin/V4.Guards.WebCompanion/release'),
        '-OutputDirectory',(Join-Path $fixtureRoot 'distribution'),'-SourceCommit',$sourceCommit)
    $archiveText = @(& pwsh -NoLogo -NoProfile -NonInteractive -File $distribution @distributionArguments 2>&1) -join "`n"
    Assert ($LASTEXITCODE -eq 0) "Candidate fixture distribution failed: $archiveText"
    $archiveResult = $archiveText | ConvertFrom-Json -AsHashtable -Depth 100
    Assert ($archiveResult.status -ceq 'pass' -and $archiveResult.version -ceq '1.1.1') 'Candidate fixture archive identity drift'
    $BaseArchivePath = [string]$archiveResult.archivePath
    $BaseInstallRoot = Join-Path $fixtureRoot 'installed/v4-guards-1.1.1'
    $BaseReceiptPath = Join-Path $fixtureRoot 'candidate.install.json'
    $installArguments = @('-Mode','Install','-ArchivePath',$BaseArchivePath,'-InstallRoot',$BaseInstallRoot,'-ReceiptPath',$BaseReceiptPath)
    $installText = @(& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $packageSource 'core/distribution/Install-V4Distribution.ps1') @installArguments 2>&1) -join "`n"
    Assert ($LASTEXITCODE -eq 0) "Candidate fixture install failed: $installText"
    $installedManifest = Read-Json (Join-Path $BaseInstallRoot 'distribution-manifest.json')
    foreach ($relative in @('core/distribution/Compose-V4Extension.ps1',
        'core/distribution/Test-V4ComposedInstallation.ps1',
        'core/distribution/Invoke-V4ReceiptedWebCompanion.ps1',
        'core/contracts/extension-bundle.schema.json',
        'core/contracts/extension-review.schema.json',
        'core/contracts/composition-manifest.schema.json',
        'core/contracts/composition-receipt.schema.json')) {
        Assert (@($installedManifest.files | Where-Object path -CEQ "package/$relative").Count -eq 1) "Candidate archive did not bind exactly one package/$relative"
    }
}
$base = [IO.Path]::GetFullPath($BaseInstallRoot)
$case = Join-Path $parent ([DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ') + '-' + [Guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($case)
if (-not [string]::IsNullOrWhiteSpace($BaseReceiptTemplatePath)) {
    $rebasedReceipt = Read-Json $BaseReceiptTemplatePath
    $rebasedReceipt.installRoot = $base
    $BaseReceiptPath = Join-Path $case 'base-install.receipt.json'
    Write-Json $BaseReceiptPath $rebasedReceipt
}
$bundleRoot = Join-Path $case 'bundle'
$bundlePackage = Join-Path $bundleRoot 'package'
$profileId = 'p10_composed'
$moduleId = 'p10-synthetic-probe'
$moduleRoot = Join-Path $bundlePackage "modules/$moduleId"
$profileRoot = Join-Path $bundlePackage "profiles/catalog/$profileId"
[void][IO.Directory]::CreateDirectory($moduleRoot)
[void][IO.Directory]::CreateDirectory($profileRoot)
$sourceModule = Join-Path $base 'package/modules/synthetic-probe'

Copy-Item -LiteralPath (Join-Path $sourceModule 'adapter.ps1') -Destination (Join-Path $moduleRoot 'adapter.ps1')
Copy-Item -LiteralPath (Join-Path $sourceModule 'config.schema.json') -Destination (Join-Path $moduleRoot 'config.schema.json')
$lock = Read-Json (Join-Path $sourceModule 'dependencies.lock.json')
$lock.moduleId = $moduleId
Write-Json (Join-Path $moduleRoot 'dependencies.lock.json') $lock
$module = Read-Json (Join-Path $sourceModule 'module.json')
$module.id = $moduleId
$module.adapter.path = "modules/$moduleId/adapter.ps1"
$module.configSchema = "modules/$moduleId/config.schema.json"
$module.dependencyLock.path = "modules/$moduleId/dependencies.lock.json"
$module.dependencyLock.sha256 = Hash (Join-Path $moduleRoot 'dependencies.lock.json')
Write-Json (Join-Path $moduleRoot 'module.json') $module

$stageConfiguration = [ordered]@{}
foreach ($stage in @('bootstrap','analysis','pre','post')) {
    $stageConfiguration[$stage] = [ordered]@{ enabled=$true; modules=@($moduleId) }
}
$profile = [ordered]@{
    formatVersion=1; id=$profileId; version='1.0.0'
    projectIdentity=[ordered]@{id='p10-composed';relativeRoots=@('.')}
    moduleSelections=@([ordered]@{id=$moduleId;versionRange='>=1.0.0 <2.0.0';config=[ordered]@{}})
    stageConfiguration=$stageConfiguration; rules=@('SYNTHETIC.INPUT'); baselineRefs=@()
}
Write-Json (Join-Path $profileRoot 'profile.json') $profile

$bundleFiles = [Collections.Generic.List[object]]::new()
foreach ($file in Get-ChildItem -LiteralPath $bundlePackage -File -Recurse) {
    [void]$bundleFiles.Add([ordered]@{path=[IO.Path]::GetRelativePath($bundlePackage,$file.FullName).Replace('\','/');sha256=Hash $file.FullName;size=$file.Length})
}
$bundleFiles.Sort([Comparison[object]]{
    param($left,$right)
    [StringComparer]::Ordinal.Compare([string]$left.path,[string]$right.path)
})
$files = $bundleFiles.ToArray()
$capabilities = [ordered]@{readRoots=@('TargetRoot');writeRoots=@();processes=@('pwsh');network=$false;maxTimeoutSeconds=30}
$baseReceipt = Read-Json $BaseReceiptPath
$bundle = [ordered]@{
    formatVersion=1; id='p10-synthetic-extension'; version='1.0.0'; compatibleApi='1.x'; baseVersion=[string]$baseReceipt.version
    profiles=@([ordered]@{id=$profileId;version='1.0.0';path="profiles/catalog/$profileId/profile.json";sha256=Hash (Join-Path $profileRoot 'profile.json')})
    modules=@([ordered]@{id=$moduleId;version='1.0.0';manifestPath="modules/$moduleId/module.json";manifestSha256=Hash (Join-Path $moduleRoot 'module.json');allowedCapabilities=$capabilities})
    files=$files
}
Write-Json (Join-Path $bundleRoot 'bundle-manifest.json') $bundle
$reviewPath = Join-Path $case 'synthetic-review.json'
$review = [ordered]@{
    formatVersion=1; id='20260923-p10-synthetic-fixture'; scope='synthetic-test-only'; decision='accepted'
    acceptedBy=[ordered]@{authorityType='test-fixture';authorityId='p10-synthetic-fixture';candidateHostVerdictAllowed=$false}
    bundleManifestSha256=Hash (Join-Path $bundleRoot 'bundle-manifest.json')
    baseArchiveSha256=[string]$baseReceipt.archiveSha256
    moduleCeilings=@([ordered]@{moduleId=$moduleId;allowedCapabilities=$capabilities})
}
Write-Json $reviewPath $review

$target = Join-Path $case 'target'
$state = Join-Path $case 'state'
$evidence = Join-Path $case 'evidence'
foreach ($path in @($target,$state,$evidence)) { [void][IO.Directory]::CreateDirectory($path) }
[IO.File]::WriteAllText((Join-Path $target 'input.txt'), "synthetic-ok`n", [Text.UTF8Encoding]::new($false))
$targetHash = Hash (Join-Path $target 'input.txt')
$compositions = @()
foreach ($index in 1..2) {
    $output = Join-Path $case "composed-$index"
    $receipt = Join-Path $case "composition-$index.receipt.json"
    $resultText = @(& $composer -BaseInstallRoot $base -BaseReceiptPath $BaseReceiptPath -BaseArchivePath $BaseArchivePath -BundleRoot $bundleRoot -ReviewRecordPath $reviewPath -OutputInstallRoot $output -CompositionReceiptPath $receipt -TargetRoot $target -StateRoot $state -EvidenceRoot $evidence -AllowSyntheticFixture) -join "`n"
    $result = $resultText | ConvertFrom-Json -AsHashtable -Depth 100
    Assert ($result.status -ceq 'pass') "Composition $index did not pass"
    $proofText = @(& $verifier -InstallRoot $output -ReceiptPath $receipt -BaseReceiptPath $BaseReceiptPath -AllowSyntheticFixture) -join "`n"
    $proof = $proofText | ConvertFrom-Json -AsHashtable -Depth 100
    Assert ($proof.status -ceq 'pass') "Composition receipt $index did not verify"
    $compositions += [ordered]@{ output=$output; receipt=$receipt; packageHash=$result.packageHash; files=(Read-Json $receipt).files }
}
Assert ($compositions[0].packageHash -ceq $compositions[1].packageHash) 'Identical composition package hashes differ'
$inventoryA = @($compositions[0].files | ForEach-Object { "$($_.path)|$($_.size)|$($_.sha256)" }) -join "`n"
$inventoryB = @($compositions[1].files | ForEach-Object { "$($_.path)|$($_.size)|$($_.sha256)" }) -join "`n"
Assert ($inventoryA -ceq $inventoryB) 'Identical composition full-file inventories differ'

# An abrupt process termination bypasses PowerShell's finally block. Its private staging
# directory must remain visibly orphaned; a retry may create a new sibling, not claim or
# delete the unknown earlier directory.
$interruptionRoot = Join-Path $case 'interrupted-compose'
[void][IO.Directory]::CreateDirectory($interruptionRoot)
$interruptedOutput = Join-Path $interruptionRoot 'install'
$interruptedReceipt = Join-Path $interruptionRoot 'composition.receipt.json'
$childStart = [Diagnostics.ProcessStartInfo]::new((Get-Command pwsh -CommandType Application | Select-Object -First 1).Source)
$childStart.UseShellExecute = $false
$childStart.RedirectStandardOutput = $true
$childStart.RedirectStandardError = $true
$childStart.CreateNoWindow = $true
foreach ($argument in @('-NoLogo','-NoProfile','-NonInteractive','-File',$composer,
    '-BaseInstallRoot',$base,'-BaseReceiptPath',$BaseReceiptPath,'-BaseArchivePath',$BaseArchivePath,
    '-BundleRoot',$bundleRoot,'-ReviewRecordPath',$reviewPath,'-OutputInstallRoot',$interruptedOutput,
    '-CompositionReceiptPath',$interruptedReceipt,'-TargetRoot',$target,'-StateRoot',$state,
    '-EvidenceRoot',$evidence,'-AllowSyntheticFixture')) {
    [void]$childStart.ArgumentList.Add([string]$argument)
}
$child = [Diagnostics.Process]::new()
$child.StartInfo = $childStart
$orphan = $null
try {
    Assert ($child.Start()) 'Interrupted composition child did not start'
    $childStdout = $child.StandardOutput.ReadToEndAsync()
    $childStderr = $child.StandardError.ReadToEndAsync()
    $deadline = [DateTime]::UtcNow.AddSeconds(120)
    while ([DateTime]::UtcNow -lt $deadline -and -not $child.HasExited) {
        $candidates = @(Get-ChildItem -LiteralPath $interruptionRoot -Directory -Force |
            Where-Object { $_.Name -like '.v4-compose-*' -and (Test-Path -LiteralPath (Join-Path $_.FullName '.composition-owner')) })
        if ($candidates.Count -eq 1) { $orphan = $candidates[0].FullName; break }
        [Threading.Thread]::Sleep(10)
    }
    Assert ($null -ne $orphan) 'Interrupted composition did not reach owned staging within the deadline'
    $child.Kill($true)
    Assert ($child.WaitForExit(10000)) 'Interrupted composition child did not terminate'
} finally {
    if (-not $child.HasExited) { $child.Kill($true); [void]$child.WaitForExit(10000) }
    $child.Dispose()
}
Assert ((Test-Path -LiteralPath $orphan) -and -not (Test-Path -LiteralPath $interruptedOutput) -and
    -not (Test-Path -LiteralPath $interruptedReceipt)) 'Interrupted composition promoted output or lost its orphan evidence'
$orphanOwnerHash = Hash (Join-Path $orphan '.composition-owner')
$retryText = @(& $composer -BaseInstallRoot $base -BaseReceiptPath $BaseReceiptPath -BaseArchivePath $BaseArchivePath -BundleRoot $bundleRoot -ReviewRecordPath $reviewPath -OutputInstallRoot $interruptedOutput -CompositionReceiptPath $interruptedReceipt -TargetRoot $target -StateRoot $state -EvidenceRoot $evidence -AllowSyntheticFixture) -join "`n"
$retry = $retryText | ConvertFrom-Json -AsHashtable -Depth 100
Assert ($retry.status -ceq 'pass' -and $retry.packageHash -ceq $compositions[0].packageHash) 'Retry after interrupted staging did not reproduce the package'
$retryProof = (@(& $verifier -InstallRoot $interruptedOutput -ReceiptPath $interruptedReceipt -BaseReceiptPath $BaseReceiptPath -AllowSyntheticFixture) -join "`n") | ConvertFrom-Json -AsHashtable -Depth 100
Assert ($retryProof.status -ceq 'pass' -and (Hash (Join-Path $orphan '.composition-owner')) -ceq $orphanOwnerHash) 'Retry altered orphan staging or failed receipt verification'
$unreceiptedRoot = Join-Path $case 'unreceipted-output'
[void][IO.Directory]::CreateDirectory($unreceiptedRoot)
$unreceiptedOutput = Join-Path $unreceiptedRoot 'install'
$unreceiptedReceipt = Join-Path $unreceiptedRoot 'composition.receipt.json'
Copy-Item -LiteralPath $compositions[0].output -Destination $unreceiptedOutput -Recurse
$unreceiptedVerificationRejected = $false
try { $null = & $verifier -InstallRoot $unreceiptedOutput -ReceiptPath $unreceiptedReceipt -BaseReceiptPath $BaseReceiptPath -AllowSyntheticFixture }
catch { $unreceiptedVerificationRejected = $true }
$unreceiptedRetryRejected = $false
try { $null = & $composer -BaseInstallRoot $base -BaseReceiptPath $BaseReceiptPath -BaseArchivePath $BaseArchivePath -BundleRoot $bundleRoot -ReviewRecordPath $reviewPath -OutputInstallRoot $unreceiptedOutput -CompositionReceiptPath $unreceiptedReceipt -TargetRoot $target -StateRoot $state -EvidenceRoot $evidence -AllowSyntheticFixture }
catch { $unreceiptedRetryRejected = $_.Exception.Message -match 'Output installation and composition receipt must be absent' }
Assert ($unreceiptedVerificationRejected -and $unreceiptedRetryRejected -and -not (Test-Path -LiteralPath $unreceiptedReceipt)) 'Unreceipted promoted output was treated as recoverable or verified automatically'

$dotnet = (Get-Command dotnet -CommandType Application | Select-Object -First 1).Source
$hostDll = Join-Path $compositions[0].output 'host/v4-guards.dll'
$package = Join-Path $compositions[0].output 'package'
$queryText = @(& $dotnet $hostDll query profiles --package-root $package 2>&1) -join "`n"
Assert ($LASTEXITCODE -eq 0 -and $queryText.Contains($profileId)) 'Standard Host query profiles cannot see composed Profile'
$doctorText = @(& $dotnet $hostDll query doctor --package-root $package --profile $profileId 2>&1) -join "`n"
Assert ($LASTEXITCODE -eq 0 -and $doctorText.Contains('"status": "pass"')) 'Standard Host query doctor did not pass'
$stageText = @(& $dotnet $hostDll stage run --stage analysis --package-root $package --target-root $target --state-root $state --evidence-root $evidence --profile $profileId 2>&1) -join "`n"
Assert ($LASTEXITCODE -eq 0) "Standard Host Stage run failed: $stageText"
$stageResult = $stageText | ConvertFrom-Json -AsHashtable -Depth 100
Assert ($stageResult.status -ceq 'pass' -and $stageResult.profile.id -ceq $profileId) 'Composed Stage result identity drift'
$stateDocument = Read-Json (Join-Path $state 'state.json')
$projectId = [string]$stateDocument.projectInstances[0].id
$runsText = @(& $dotnet $hostDll query runs --package-root $package --state-root $state --evidence-root $evidence --project $projectId 2>&1) -join "`n"
Assert ($LASTEXITCODE -eq 0 -and $runsText.Contains([string]$stageResult.runId)) 'Standard Host query runs cannot see composed run'
$evidenceText = @(& $dotnet $hostDll query evidence --package-root $package --state-root $state --evidence-root $evidence --project $projectId --run ([string]$stageResult.runId) 2>&1) -join "`n"
Assert ($LASTEXITCODE -eq 0 -and $evidenceText.Contains([string]$stageResult.runId)) 'Standard Host query evidence cannot see composed run'
$dependencyText = @(& $dotnet $hostDll stage run --stage analysis --package-root $package --target-root $target --state-root $state --evidence-root $evidence --profile $profileId --with-dependencies 2>&1) -join "`n"
Assert ($LASTEXITCODE -eq 0) "Composed Stage dependency run failed: $dependencyText"
$dependencyResult = $dependencyText | ConvertFrom-Json -AsHashtable -Depth 100
Assert (($dependencyResult.executedStages -join ',') -ceq 'bootstrap,analysis' -and $dependencyResult.status -ceq 'pass') 'Composed dependency Stage order or verdict drift'
$zeroTarget = Join-Path $case 'zero-match-target'
$zeroState = Join-Path $case 'zero-match-state'
$zeroEvidence = Join-Path $case 'zero-match-evidence'
foreach ($path in @($zeroTarget,$zeroState,$zeroEvidence)) { [void][IO.Directory]::CreateDirectory($path) }
[IO.File]::WriteAllText((Join-Path $zeroTarget 'input.txt'), "synthetic-ok`n", [Text.UTF8Encoding]::new($false))
$zeroText = @(& $dotnet $hostDll stage run --stage pre --package-root $package --target-root $zeroTarget --state-root $zeroState --evidence-root $zeroEvidence --profile synthetic_profile 2>&1) -join "`n"
$zeroExit = $LASTEXITCODE
$zeroResult = $zeroText | ConvertFrom-Json -AsHashtable -Depth 100
$zeroCoverage = @($zeroResult.coverage | Where-Object { $_.claimId -ceq 'ARCH.PROJECT_REFERENCE' -and $_.matched -eq 0 -and $_.minimum -eq 1 })
Assert ($zeroExit -ne 0 -and $zeroResult.status -ceq 'error' -and $zeroResult.exitCategory -ceq 'prerequisite-missing' -and $zeroCoverage.Count -eq 1) 'Composed installation accepted a project-model zero-match control'
Assert ((Hash (Join-Path $target 'input.txt')) -ceq $targetHash) 'TargetRoot was changed by composition or Stage'
$baseProof = (@(& $verifier -InstallRoot $base -ReceiptPath $BaseReceiptPath) -join "`n") | ConvertFrom-Json -AsHashtable -Depth 100
Assert ($baseProof.status -ceq 'pass') 'Released base installation changed during prototype'

$installedLauncherPath = Join-Path $compositions[0].output 'package/core/distribution/Invoke-V4ReceiptedWebCompanion.ps1'
$installedLauncherUsed = Test-Path -LiteralPath $installedLauncherPath -PathType Leaf
$receiptedLauncher = if ($installedLauncherUsed) { $installedLauncherPath }
    else { Join-Path $packageSource 'core/distribution/Invoke-V4ReceiptedWebCompanion.ps1' }
Assert (Test-Path -LiteralPath $receiptedLauncher -PathType Leaf) 'Receipted Web Companion launcher is missing'
$launcherRejected = $false
try {
    $null = & $receiptedLauncher -InstallRoot $compositions[0].output -ReceiptPath $compositions[0].receipt -BaseReceiptPath $BaseReceiptPath -Profile $profileId -PrerequisiteReportPath (Join-Path $evidence 'not-started.json') -CompanionArgumentsJson '[]'
} catch { $launcherRejected = $true }
Assert $launcherRejected 'Receipted launcher accepted a synthetic receipt without explicit test-fixture switch'

$companionArguments = @('--target-root',$target,'--state-root',$state,'--evidence-root',$evidence,'--plan-root','plans','--port','0') | ConvertTo-Json -Compress
$start = [Diagnostics.ProcessStartInfo]::new((Get-Command pwsh -CommandType Application | Select-Object -First 1).Source)
$start.UseShellExecute = $false
$start.RedirectStandardOutput = $true
$start.RedirectStandardError = $true
$start.CreateNoWindow = $true
foreach ($argument in @('-NoLogo','-NoProfile','-NonInteractive','-File',$receiptedLauncher,
    '-InstallRoot',$compositions[0].output,'-ReceiptPath',$compositions[0].receipt,'-BaseReceiptPath',$BaseReceiptPath,
    '-Profile',$profileId,'-PrerequisiteReportPath',(Join-Path $evidence 'companion-prerequisites.json'),
    '-CompanionArgumentsJson',$companionArguments,'-AllowSyntheticFixture')) {
    [void]$start.ArgumentList.Add([string]$argument)
}
$companion = [Diagnostics.Process]::new()
$companion.StartInfo = $start
$client = $null
$companionStarted = $false
try {
    Assert ($companion.Start()) 'Receipted Web Companion process did not start'
    $companionStarted = $true
    $readyTask = $companion.StandardOutput.ReadLineAsync()
    Assert ($readyTask.Wait([TimeSpan]::FromSeconds(180)) -and $null -ne $readyTask.Result) 'Receipted Web Companion readiness timed out'
    $ready = $readyTask.Result | ConvertFrom-Json -AsHashtable -Depth 20
    Assert ($ready.status -ceq 'ready' -and $ready.address -match '^http://127\.0\.0\.1:[0-9]+$') 'Receipted Web Companion readiness was invalid'
    $handler = [Net.Http.HttpClientHandler]::new()
    $handler.CookieContainer = [Net.CookieContainer]::new()
    $client = [Net.Http.HttpClient]::new($handler)
    $session = $client.GetStringAsync("$($ready.address)/api/v1/session").GetAwaiter().GetResult() | ConvertFrom-Json -AsHashtable -Depth 30
    Assert ($session.authority -ceq 'v4-host' -and @($session.allowedProfiles) -contains $profileId) 'Web Companion did not project composed Profile from Host'
    $readiness = $client.GetStringAsync("$($ready.address)/api/v1/readiness/$profileId").GetAwaiter().GetResult() | ConvertFrom-Json -AsHashtable -Depth 30
    Assert ($readiness.status -ceq 'pass' -or $readiness.report.status -ceq 'pass') 'Web Companion composed Profile readiness did not pass'
} finally {
    if ($null -ne $client) { $client.Dispose() }
    if ($companionStarted -and -not $companion.HasExited) { $companion.Kill($true); [void]$companion.WaitForExit(10000) }
    $companion.Dispose()
}

$syntheticRejected = $false
try { $null = & $verifier -InstallRoot $compositions[0].output -ReceiptPath $compositions[0].receipt -BaseReceiptPath $BaseReceiptPath } catch { $syntheticRejected = $true }
Assert $syntheticRejected 'Synthetic receipt was accepted without explicit test-fixture switch'

$tamperedReceipt = Join-Path $case 'tampered.receipt.json'
$tampered = Read-Json $compositions[0].receipt
$tampered.files[0].sha256 = ('0' * 64)
Write-Json $tamperedReceipt $tampered
$driftRejected = $false
try { $null = & $verifier -InstallRoot $compositions[0].output -ReceiptPath $tamperedReceipt -BaseReceiptPath $BaseReceiptPath -AllowSyntheticFixture } catch { $driftRejected = $true }
Assert $driftRejected 'Receipt inventory drift was accepted'

$unsortedReceipt = Join-Path $case 'unsorted.receipt.json'
$document = Read-Json $compositions[0].receipt
[array]::Reverse($document.files)
Write-Json $unsortedReceipt $document
$unsortedReceiptRejected = $false
try { $null = & $verifier -InstallRoot $compositions[0].output -ReceiptPath $unsortedReceipt -BaseReceiptPath $BaseReceiptPath -AllowSyntheticFixture }
catch { $unsortedReceiptRejected = $_.Exception.Message -match 'strict ordinal path order' }
Assert $unsortedReceiptRejected 'Non-canonical composition receipt inventory order was accepted'

$badReviewPath = Join-Path $case 'bad-review.json'
$badReview = Read-Json $reviewPath
$badReview.baseArchiveSha256 = ('0' * 64)
Write-Json $badReviewPath $badReview
$badOutput = Join-Path $case 'must-not-promote'
$badReceipt = Join-Path $case 'must-not-receipt.json'
$badRejected = $false
try {
    $null = & $composer -BaseInstallRoot $base -BaseReceiptPath $BaseReceiptPath -BaseArchivePath $BaseArchivePath -BundleRoot $bundleRoot -ReviewRecordPath $badReviewPath -OutputInstallRoot $badOutput -CompositionReceiptPath $badReceipt -TargetRoot $target -StateRoot $state -EvidenceRoot $evidence -AllowSyntheticFixture
} catch { $badRejected = $true }
Assert ($badRejected -and -not (Test-Path -LiteralPath $badOutput) -and -not (Test-Path -LiteralPath $badReceipt)) 'Wrong base archive identity reached output promotion'

$narrowReviewPath = Join-Path $case 'narrow-review.json'
$narrowReview = Read-Json $reviewPath
$narrowReview.moduleCeilings[0].allowedCapabilities.readRoots = @()
Write-Json $narrowReviewPath $narrowReview
$capabilityRejected = $false
try {
    $null = & $composer -BaseInstallRoot $base -BaseReceiptPath $BaseReceiptPath -BaseArchivePath $BaseArchivePath -BundleRoot $bundleRoot -ReviewRecordPath $narrowReviewPath -OutputInstallRoot $badOutput -CompositionReceiptPath $badReceipt -TargetRoot $target -StateRoot $state -EvidenceRoot $evidence -AllowSyntheticFixture
} catch { $capabilityRejected = $true }
Assert ($capabilityRejected -and -not (Test-Path -LiteralPath $badOutput)) 'Capability review mismatch reached output promotion'

$targetReceipt = Join-Path $target 'must-not-write.receipt.json'
$targetReceiptRejected = $false
try {
    $null = & $composer -BaseInstallRoot $base -BaseReceiptPath $BaseReceiptPath -BaseArchivePath $BaseArchivePath -BundleRoot $bundleRoot -ReviewRecordPath $reviewPath -OutputInstallRoot $badOutput -CompositionReceiptPath $targetReceipt -TargetRoot $target -StateRoot $state -EvidenceRoot $evidence -AllowSyntheticFixture
} catch { $targetReceiptRejected = $true }
Assert ($targetReceiptRejected -and -not (Test-Path -LiteralPath $targetReceipt) -and -not (Test-Path -LiteralPath $badOutput)) 'External receipt path was permitted to write TargetRoot'

$negativeResults = [ordered]@{}
function New-Variant([string] $Name) {
    $root = Join-Path $case "negatives/$Name"
    [void][IO.Directory]::CreateDirectory($root)
    $variantBundle = Join-Path $root 'bundle'
    $variantReview = Join-Path $root 'review.json'
    Copy-Item -LiteralPath $bundleRoot -Destination $variantBundle -Recurse
    Copy-Item -LiteralPath $reviewPath -Destination $variantReview
    [ordered]@{ Name=$Name; Root=$root; Bundle=$variantBundle; Review=$variantReview }
}
function Bind-VariantReview($Variant) {
    $record = Read-Json $Variant.Review
    $record.bundleManifestSha256 = Hash (Join-Path $Variant.Bundle 'bundle-manifest.json')
    Write-Json $Variant.Review $record
}
function Bind-VariantFile($BundleDocument, [string] $Relative, [string] $FullPath) {
    $entry = @($BundleDocument.files | Where-Object path -CEQ $Relative)
    Assert ($entry.Count -eq 1) "Variant inventory entry is not unique: $Relative"
    $entry[0].sha256 = Hash $FullPath
    $entry[0].size = (Get-Item -LiteralPath $FullPath).Length
}
function Expect-VariantReject($Variant, [string] $ExpectedError, [string] $ReceiptOverride = '', [string] $OutputOverride = '', [string] $BaseReceiptOverride = '') {
    $destination = if ($OutputOverride) { $OutputOverride } else { Join-Path $Variant.Root 'must-not-promote' }
    $receiptDestination = if ($ReceiptOverride) { $ReceiptOverride } else { Join-Path $Variant.Root 'must-not-receipt.json' }
    $selectedBaseReceipt = if ($BaseReceiptOverride) { $BaseReceiptOverride } else { $BaseReceiptPath }
    $failure = ''
    try {
        $null = & $composer -BaseInstallRoot $base -BaseReceiptPath $selectedBaseReceipt -BaseArchivePath $BaseArchivePath -BundleRoot $Variant.Bundle -ReviewRecordPath $Variant.Review -OutputInstallRoot $destination -CompositionReceiptPath $receiptDestination -TargetRoot $target -StateRoot $state -EvidenceRoot $evidence -AllowSyntheticFixture
    } catch { $failure = [string]$_.Exception.Message }
    Assert ($failure -match $ExpectedError) "Negative case $($Variant.Name) failed at the wrong boundary: $failure"
    if (-not $OutputOverride) { Assert (-not (Test-Path -LiteralPath $destination)) "Negative case $($Variant.Name) promoted output" }
    if (-not $ReceiptOverride) { Assert (-not (Test-Path -LiteralPath $receiptDestination)) "Negative case $($Variant.Name) emitted success receipt" }
    $staging = @(Get-ChildItem -LiteralPath $Variant.Root -Force | Where-Object { $_.Name -like '.v4-compose-*' })
    Assert ($staging.Count -eq 0) "Negative case $($Variant.Name) left owned staging data"
    $script:negativeResults[$Variant.Name] = $ExpectedError
}

$variant = New-Variant 'corrupt-file-hash'
[IO.File]::AppendAllText((Join-Path $variant.Bundle "package/modules/$moduleId/adapter.ps1"), "`n# drift")
Expect-VariantReject $variant 'Bundle file hash/size drift'

$variant = New-Variant 'missing-bundle-file'
Remove-Item -LiteralPath (Join-Path $variant.Bundle "package/modules/$moduleId/adapter.ps1") -Force
Expect-VariantReject $variant 'Missing or escaping file'

$variant = New-Variant 'extra-bundle-file'
[IO.File]::WriteAllText((Join-Path $variant.Bundle "package/modules/$moduleId/extra.txt"), 'undeclared', [Text.UTF8Encoding]::new($false))
Expect-VariantReject $variant 'Bundle file count differs from manifest'

$variant = New-Variant 'bundle-symlink'
$link = Join-Path $variant.Bundle "package/modules/$moduleId/extra-link.txt"
try {
    $null = New-Item -ItemType SymbolicLink -Path $link -Target (Join-Path $variant.Bundle "package/modules/$moduleId/adapter.ps1") -ErrorAction Stop
    Expect-VariantReject $variant 'Bundle link'
} catch {
    if (Test-Path -LiteralPath $link) { throw }
    $script:negativeResults['bundle-symlink'] = 'not-run: symbolic-link creation unavailable'
}

$variant = New-Variant 'duplicate-profile-id'
$document = Read-Json (Join-Path $variant.Bundle 'bundle-manifest.json')
$document.profiles += [ordered]@{id=$profileId;version='1.0.1';path="profiles/catalog/$profileId/profile.json";sha256=[string]$document.profiles[0].sha256}
Write-Json (Join-Path $variant.Bundle 'bundle-manifest.json') $document
Bind-VariantReview $variant
Expect-VariantReject $variant 'Duplicate or base Profile ID'

$variant = New-Variant 'duplicate-module-id'
$document = Read-Json (Join-Path $variant.Bundle 'bundle-manifest.json')
$document.modules += [ordered]@{id=$moduleId;version='1.0.1';manifestPath="modules/$moduleId/module.json";manifestSha256=[string]$document.modules[0].manifestSha256;allowedCapabilities=$document.modules[0].allowedCapabilities}
Write-Json (Join-Path $variant.Bundle 'bundle-manifest.json') $document
Bind-VariantReview $variant
Expect-VariantReject $variant 'Duplicate or base module ID'

$variant = New-Variant 'base-profile-id-collision'
$document = Read-Json (Join-Path $variant.Bundle 'bundle-manifest.json')
$document.profiles[0].id = 'synthetic_profile'
Write-Json (Join-Path $variant.Bundle 'bundle-manifest.json') $document
Bind-VariantReview $variant
Expect-VariantReject $variant 'Duplicate or base Profile ID'

$variant = New-Variant 'case-colliding-file'
$document = Read-Json (Join-Path $variant.Bundle 'bundle-manifest.json')
$document.files += [ordered]@{path=([string]$document.files[0].path).ToUpperInvariant();sha256=[string]$document.files[0].sha256;size=[long]$document.files[0].size}
Write-Json (Join-Path $variant.Bundle 'bundle-manifest.json') $document
Bind-VariantReview $variant
Expect-VariantReject $variant 'Duplicate or case-colliding bundle file'

$variant = New-Variant 'unsorted-bundle-inventory'
$document = Read-Json (Join-Path $variant.Bundle 'bundle-manifest.json')
[array]::Reverse($document.files)
Write-Json (Join-Path $variant.Bundle 'bundle-manifest.json') $document
Bind-VariantReview $variant
Expect-VariantReject $variant 'Bundle file inventory must be in strict ordinal path order'

$variant = New-Variant 'parent-traversal'
$document = Read-Json (Join-Path $variant.Bundle 'bundle-manifest.json')
$document.files[0].path = '../escape'
Write-Json (Join-Path $variant.Bundle 'bundle-manifest.json') $document
Bind-VariantReview $variant
Expect-VariantReject $variant 'extension-bundle schema validation failed'

$variant = New-Variant 'absolute-path'
$document = Read-Json (Join-Path $variant.Bundle 'bundle-manifest.json')
$document.files[0].path = 'C:/outside/file.json'
Write-Json (Join-Path $variant.Bundle 'bundle-manifest.json') $document
Bind-VariantReview $variant
Expect-VariantReject $variant 'extension-bundle schema validation failed'

$variant = New-Variant 'incompatible-base-version'
$document = Read-Json (Join-Path $variant.Bundle 'bundle-manifest.json')
$document.baseVersion = '1.2.0'
Write-Json (Join-Path $variant.Bundle 'bundle-manifest.json') $document
Bind-VariantReview $variant
Expect-VariantReject $variant 'Bundle/review/base identity mismatch'

$variant = New-Variant 'review-manifest-mismatch'
$record = Read-Json $variant.Review
$record.bundleManifestSha256 = ('0' * 64)
Write-Json $variant.Review $record
Expect-VariantReject $variant 'Bundle/review/base identity mismatch'

$variant = New-Variant 'production-review-spoof'
$record = Read-Json $variant.Review
$record.scope = 'production'
Write-Json $variant.Review $record
Expect-VariantReject $variant 'Production bundle lacks the designated human-review authority'

$variant = New-Variant 'target-write-capability'
$document = Read-Json (Join-Path $variant.Bundle 'bundle-manifest.json')
$document.modules[0].allowedCapabilities.writeRoots = @('TargetRoot')
Write-Json (Join-Path $variant.Bundle 'bundle-manifest.json') $document
Bind-VariantReview $variant
Expect-VariantReject $variant 'extension-bundle schema validation failed'

$variant = New-Variant 'over-capability'
$modulePath = Join-Path $variant.Bundle "package/modules/$moduleId/module.json"
$document = Read-Json $modulePath
$document.capabilities.timeoutSeconds = 31
Write-Json $modulePath $document
$bundleDocument = Read-Json (Join-Path $variant.Bundle 'bundle-manifest.json')
$bundleDocument.modules[0].manifestSha256 = Hash $modulePath
Bind-VariantFile $bundleDocument "modules/$moduleId/module.json" $modulePath
Write-Json (Join-Path $variant.Bundle 'bundle-manifest.json') $bundleDocument
Bind-VariantReview $variant
Expect-VariantReject $variant 'Module capabilities exceed or differ from reviewed ceiling'

$variant = New-Variant 'invalid-profile-schema'
$profilePath = Join-Path $variant.Bundle "package/profiles/catalog/$profileId/profile.json"
$document = Read-Json $profilePath
$document.unexpected = $true
Write-Json $profilePath $document
$bundleDocument = Read-Json (Join-Path $variant.Bundle 'bundle-manifest.json')
$bundleDocument.profiles[0].sha256 = Hash $profilePath
Bind-VariantFile $bundleDocument "profiles/catalog/$profileId/profile.json" $profilePath
Write-Json (Join-Path $variant.Bundle 'bundle-manifest.json') $bundleDocument
Bind-VariantReview $variant
Expect-VariantReject $variant 'profile schema validation failed'

$variant = New-Variant 'invalid-module-schema'
$modulePath = Join-Path $variant.Bundle "package/modules/$moduleId/module.json"
$document = Read-Json $modulePath
$document.unexpected = $true
Write-Json $modulePath $document
$bundleDocument = Read-Json (Join-Path $variant.Bundle 'bundle-manifest.json')
$bundleDocument.modules[0].manifestSha256 = Hash $modulePath
Bind-VariantFile $bundleDocument "modules/$moduleId/module.json" $modulePath
Write-Json (Join-Path $variant.Bundle 'bundle-manifest.json') $bundleDocument
Bind-VariantReview $variant
Expect-VariantReject $variant 'module schema validation failed'

$variant = New-Variant 'missing-runtime'
$modulePath = Join-Path $variant.Bundle "package/modules/$moduleId/module.json"
$document = Read-Json $modulePath
$document.prerequisites += [ordered]@{runtime='node';versionRange='>=999.0'}
Write-Json $modulePath $document
$bundleDocument = Read-Json (Join-Path $variant.Bundle 'bundle-manifest.json')
$bundleDocument.modules[0].manifestSha256 = Hash $modulePath
Bind-VariantFile $bundleDocument "modules/$moduleId/module.json" $modulePath
Write-Json (Join-Path $variant.Bundle 'bundle-manifest.json') $bundleDocument
Bind-VariantReview $variant
Expect-VariantReject $variant 'Composed Profile prerequisites failed'

$variant = New-Variant 'wrong-base-receipt'
$wrongReceipt = Join-Path $variant.Root 'wrong-base.receipt.json'
$document = Read-Json $BaseReceiptPath
$document.archiveSha256 = ('0' * 64)
Write-Json $wrongReceipt $document
Expect-VariantReject $variant 'Selected public-release archive differs from the installed receipt' -BaseReceiptOverride $wrongReceipt

$missingBaseReceiptRejected = $false
try { $null = & $verifier -InstallRoot $compositions[0].output -ReceiptPath $compositions[0].receipt -AllowSyntheticFixture } catch { $missingBaseReceiptRejected = $_.Exception.Message -match 'requires the external base receipt' }
Assert $missingBaseReceiptRejected 'Composed verifier accepted a missing external base receipt'

$variant = New-Variant 'existing-output'
Expect-VariantReject $variant 'Output installation and composition receipt must be absent' -OutputOverride $compositions[0].output

$variant = New-Variant 'output-under-target'
Expect-VariantReject $variant 'Overlapping roots' -OutputOverride (Join-Path $target 'must-not-promote')
Assert (-not (Test-Path -LiteralPath (Join-Path $target 'must-not-promote'))) 'Output-under-Target negative case wrote TargetRoot'

$variant = New-Variant 'output-under-package'
Expect-VariantReject $variant 'Overlapping roots' -OutputOverride (Join-Path $base 'must-not-promote')
Assert (-not (Test-Path -LiteralPath (Join-Path $base 'must-not-promote'))) 'Output-under-Package negative case wrote PackageRoot'

function New-InstalledVariant([string] $Name) {
    $root = Join-Path $case "negatives/$Name"
    [void][IO.Directory]::CreateDirectory($root)
    $install = Join-Path $root 'install'
    $receiptPath = Join-Path $root 'receipt.json'
    Copy-Item -LiteralPath $compositions[0].output -Destination $install -Recurse
    $document = Read-Json $compositions[0].receipt
    $document.installRoot = $install
    Write-Json $receiptPath $document
    [ordered]@{Install=$install;Receipt=$receiptPath}
}
function Expect-InstalledReject([string] $Name, $Variant) {
    $failure = ''
    try { $null = & $verifier -InstallRoot $Variant.Install -ReceiptPath $Variant.Receipt -BaseReceiptPath $BaseReceiptPath -AllowSyntheticFixture }
    catch { $failure = [string]$_.Exception.Message }
    Assert ($failure -match 'Installed file set differs from receipt') "Installed variant $Name was not rejected for file-set drift: $failure"
    $script:negativeResults[$Name] = 'Installed file set differs from receipt'
}

$installedVariant = New-InstalledVariant 'missing-installed-file'
Remove-Item -LiteralPath (Join-Path $installedVariant.Install "package/profiles/catalog/$profileId/profile.json") -Force
Expect-InstalledReject 'missing-installed-file' $installedVariant

$installedVariant = New-InstalledVariant 'extra-installed-file'
[IO.File]::WriteAllText((Join-Path $installedVariant.Install 'unexpected.txt'), 'undeclared', [Text.UTF8Encoding]::new($false))
Expect-InstalledReject 'extra-installed-file' $installedVariant

Assert ((Hash (Join-Path $target 'input.txt')) -ceq $targetHash) 'Negative matrix changed TargetRoot'
$baseProof = (@(& $verifier -InstallRoot $base -ReceiptPath $BaseReceiptPath) -join "`n") | ConvertFrom-Json -AsHashtable -Depth 100
Assert ($baseProof.status -ceq 'pass') 'Negative matrix changed the released base installation'

$summary = [ordered]@{formatVersion=1;status='pass';scope='synthetic-test-only';selfContainedCandidate=$selfContainedCandidate;installedLauncherUsed=$installedLauncherUsed;baseVersion=[string]$baseReceipt.version;caseRoot=$case;profile=$profileId;module=$moduleId;packageHash=$compositions[0].packageHash;fileCount=$compositions[0].files.Count;deterministic=$true;interruptedStagingRetained=$true;interruptedRetryVerified=$true;orphanStagingPath=$orphan;unreceiptedOutputRejected=$true;projectModelZeroMatchRejected=$true;hostProfiles=$true;hostDoctor=$true;hostStage=$true;hostDependencies=$true;hostRuns=$true;hostEvidence=$true;webSession=$true;webReadiness=$true;targetUnchanged=$true;baseUnchanged=$true;launcherFailClosed=$true;syntheticDeniedByDefault=$true;receiptDriftRejected=$true;unsortedReceiptRejected=$true;wrongBaseRejected=$true;capabilityMismatchRejected=$true;targetReceiptRejected=$true;missingBaseReceiptRejected=$true;negativeCases=$negativeResults}
Write-Json (Join-Path $case 'summary.json') $summary
$summary | ConvertTo-Json -Depth 10
