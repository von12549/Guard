[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$packageRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$project = Join-Path $packageRoot 'core/host/V4.Guards.Host/V4.Guards.Host.csproj'
$buildRoot = Join-Path $packageRoot 'build'
$workBase = [IO.Path]::Combine([IO.Path]::GetTempPath(),'v4-guards-work',[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($packageRoot))).Substring(0,12).ToLowerInvariant())
if (-not (Test-Path -LiteralPath (Join-Path $workBase '.git'))) {
    [void][IO.Directory]::CreateDirectory($workBase)
    & git -C $workBase init -q
    & git -C $workBase -c user.name=v4-guards-test -c user.email=v4-guards-test@example.invalid -c commit.gpgsign=false commit -q --allow-empty -m 'V4 test work root'
    if ($LASTEXITCODE) { throw 'V4 test work root initialization failed.' }
}
$case = Join-Path $workBase ('p11-profile-' + [Guid]::NewGuid().ToString('N'))
$artifacts = Join-Path $workBase 'p11-profile-artifacts'
$target = Join-Path $case 'target'
$state = Join-Path $case 'state'
$candidate = Join-Path $case 'candidate'
$reviewPath = Join-Path $case 'profile-review.json'
$failures = [Collections.Generic.List[string]]::new()

function Write-Utf8([string] $Path, [string] $Text) {
    [void][IO.Directory]::CreateDirectory((Split-Path -Parent $Path))
    [IO.File]::WriteAllText($Path, $Text.Replace("`r`n","`n"), [Text.UTF8Encoding]::new($false))
}
function Write-Json([string] $Path, $Value) {
    Write-Utf8 $Path (($Value | ConvertTo-Json -Depth 100) + "`n")
}
function Hash([string] $Path) { (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant() }
function Target-Hash {
    $lines = @(Get-ChildItem -LiteralPath $target -File -Recurse | Sort-Object FullName | ForEach-Object {
        "$([IO.Path]::GetRelativePath($target,$_.FullName).Replace('\','/')):$(Hash $_.FullName)"
    })
    $text = ($lines -join "`n") + "`n"
    [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($text))).ToLowerInvariant()
}
function Invoke-Host([string[]] $Arguments) {
    $dll = Join-Path $artifacts 'bin/V4.Guards.Host/debug/v4-guards.dll'
    $output = @(& dotnet $dll @Arguments 2>&1)
    [pscustomobject]@{ Code=$LASTEXITCODE; Text=($output -join "`n") }
}
function Assert([bool] $Condition, [string] $Message) { if (-not $Condition) { $failures.Add($Message) } }
function Expect-Code($Run, [int] $Code, [string] $Name, [string] $Pattern) {
    if ($Run.Code -ne $Code -or $Run.Text -notmatch $Pattern) {
        $failures.Add("${Name}: expected $Code/$Pattern, got $($Run.Code): $($Run.Text)")
    }
}
function Assert-Schema([string] $Path, [string] $Schema) {
    $schemaPath = Join-Path $packageRoot "core/profile/contracts/$Schema.schema.json"
    if (-not (Test-Path -LiteralPath $schemaPath)) { $schemaPath = Join-Path $packageRoot "core/contracts/$Schema.schema.json" }
    if (-not (Test-Json -LiteralPath $Path -SchemaFile $schemaPath -ErrorAction SilentlyContinue)) {
        $failures.Add("Schema validation failed: $Schema => $Path")
    }
}

try {
    if (Test-Path -LiteralPath $case) { Remove-Item -LiteralPath $case -Recurse -Force }
    [void][IO.Directory]::CreateDirectory($target)
    [void][IO.Directory]::CreateDirectory($state)
    $properties = @(
        '-p:ImportDirectoryBuildProps=false', '-p:ImportDirectoryBuildTargets=false', '-p:ImportDirectoryPackagesProps=false',
        '-p:ImportDirectorySolutionProps=false', '-p:ImportDirectorySolutionTargets=false',
        "-p:CustomBeforeMicrosoftCommonProps=$(Join-Path $buildRoot 'V4.Build.props')"
    )
    Push-Location $buildRoot
    try {
        & dotnet restore $project --configfile (Join-Path $buildRoot 'NuGet.config') --artifacts-path $artifacts -nologo @properties
        if ($LASTEXITCODE) { throw 'M2 Host restore failed.' }
        & dotnet build $project --no-restore --artifacts-path $artifacts -nologo @properties
        if ($LASTEXITCODE) { throw 'M2 Host build failed.' }
    } finally { Pop-Location }

    $marker = Join-Path $target 'target-code-executed.txt'
    Write-Utf8 (Join-Path $target 'src/App/App.csproj') @"
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup><TargetFramework>net10.0</TargetFramework></PropertyGroup>
  <Target Name="UnsafeTargetCode" BeforeTargets="Build"><WriteLinesToFile File="$marker" Lines="executed" /></Target>
</Project>
"@
    Write-Utf8 (Join-Path $target 'src/App/Program.cs') "namespace Sample; public static class Program { public static void Main() { } }`n"
    Write-Utf8 (Join-Path $target 'tests/App.Tests/App.Tests.csproj') '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFramework>net10.0</TargetFramework></PropertyGroup></Project>'
    Write-Utf8 (Join-Path $target 'package.json') '{"name":"sample","engines":{"node":">=20"}}'
    $targetBefore = Target-Hash

    $discoverArgs = @('profile','discover','--package-root',$packageRoot,'--target-root',$target)
    $discover1 = Invoke-Host $discoverArgs
    $discover2 = Invoke-Host $discoverArgs
    Expect-Code $discover1 0 'discover' '"operation"\s*:\s*"profile-discover"'
    Assert ($discover1.Text -ceq $discover2.Text) 'Discovery output is not byte-deterministic.'
    $discoveryPath = Join-Path $case 'discovery-output.json'
    Write-Utf8 $discoveryPath ($discover1.Text + "`n")
    Assert-Schema $discoveryPath 'profile-discovery'
    if ($discover1.Code -eq 0) {
        $discovery = $discover1.Text | ConvertFrom-Json -AsHashtable -Depth 100
        Assert (@($discovery.facts | Where-Object kind -ceq 'language').Count -ge 1) 'Discovery did not report a language fact.'
        Assert (@($discovery.facts | Where-Object kind -ceq 'framework').Count -ge 1) 'Discovery did not report a framework fact.'
        Assert (@($discovery.facts | Where-Object kind -ceq 'module').Count -eq 3) 'Discovery did not report the installed Module catalog.'
        Assert (@($discovery.questions | Where-Object kind -ceq 'ambiguous-module').Count -eq 1) 'Discovery did not preserve the ambiguous Module question.'
        Assert (@($discovery.prohibitions) -contains 'execute-target-code') 'Discovery does not declare its target execution prohibition.'
    }
    Assert (-not (Test-Path -LiteralPath $marker)) 'Discovery executed Target code.'
    Assert ((Target-Hash) -ceq $targetBefore) 'Discovery changed TargetRoot.'

    $draftArgs = @('profile','draft','--package-root',$packageRoot,'--target-root',$target,'--state-root',$state,'--profile','sample_guard')
    $draftRun = Invoke-Host $draftArgs
    Expect-Code $draftRun 0 'draft' '"authority"\s*:\s*"state-draft-non-authoritative"'
    if ($draftRun.Code -ne 0) { throw "Draft failed: $($draftRun.Text)" }
    $draft = $draftRun.Text | ConvertFrom-Json -AsHashtable -Depth 100
    $draftPath = [string]$draft.storagePath
    Assert (Test-Path -LiteralPath $draftPath) 'Draft was not stored below StateRoot.'
    Assert ([IO.Path]::GetRelativePath($state,$draftPath) -notmatch '^\.\.') 'Draft escaped StateRoot.'
    Assert-Schema $draftPath 'profile-draft'
    Assert ($draft.coverage.status -ceq 'unprotected') 'Conservative draft is not labelled unprotected.'
    Assert (@($draft.candidateProfile.moduleSelections).Count -eq 0) 'Draft silently selected a Module.'
    $draftAgain = Invoke-Host $draftArgs
    Expect-Code $draftAgain 0 'draft idempotence' '"status"\s*:\s*"draft"'
    Assert ($draftRun.Text -ceq $draftAgain.Text) 'Idempotent draft output changed.'
    Assert ((Target-Hash) -ceq $targetBefore) 'Draft changed TargetRoot.'

    $draftHashBeforeConfigure = Hash $draftPath
    $candidateProfile = ($draft.candidateProfile | ConvertTo-Json -Depth 100) | ConvertFrom-Json -AsHashtable -Depth 100
    $candidateProfile.moduleSelections = @([ordered]@{
        id='architecture-conformance'; versionRange='>=1.0.0 <2.0.0'
        config=[ordered]@{ enabledClaims=@('ARCH.TARGET_FRAMEWORK'); allowedTargetFrameworks=@('net10.0') }
    })
    $candidateProfile.stageConfiguration.pre = [ordered]@{enabled=$true;modules=@('architecture-conformance')}
    $candidateProfile.rules = @('ARCH.TARGET_FRAMEWORK')
    $candidateDocument = [ordered]@{
        formatVersion=1;status='candidate';authority='human-authored-unaccepted'
        sourceDraftSha256=$draftHashBeforeConfigure;discoverySha256=[string]$draft.discoverySha256
        targetSnapshotSha256=[string]$draft.targetSnapshotSha256;candidateProfile=$candidateProfile
    }
    $candidateInputPath = Join-Path $case 'human-candidate.json'
    Write-Json $candidateInputPath $candidateDocument
    Assert-Schema $candidateInputPath 'profile-candidate'
    $candidateInputHash = Hash $candidateInputPath
    $configureArgs = @('profile','configure','--package-root',$packageRoot,'--target-root',$target,'--state-root',$state,'--draft',$draftPath,'--candidate',$candidateInputPath)
    $configure = Invoke-Host $configureArgs
    Expect-Code $configure 0 'configure' '"authority"\s*:\s*"state-configured-non-authoritative"'
    if ($configure.Code -eq 0) {
        $configured = $configure.Text | ConvertFrom-Json -AsHashtable -Depth 100
        $configuredPath = [string]$configured.storagePath
        Assert-Schema $configuredPath 'profile-draft'
        Assert ($configured.coverage.status -ceq 'candidate-unaccepted') 'Configured candidate implied accepted protection.'
        Assert ($configured.sourceDraftSha256 -ceq $draftHashBeforeConfigure) 'Configured Draft lost its original Draft binding.'
        Assert ($configured.candidateSourceSha256 -ceq $candidateInputHash) 'Configured Draft lost its human candidate binding.'
        Assert ((Hash $draftPath) -ceq $draftHashBeforeConfigure) 'Configure changed the original Draft bytes.'
        Assert ((Hash $candidateInputPath) -ceq $candidateInputHash) 'Configure changed the human candidate bytes.'
        Assert ([IO.Path]::GetRelativePath($state,$configuredPath) -notmatch '^\.\.') 'Configured Draft escaped StateRoot.'
        $configureAgain = Invoke-Host $configureArgs
        Assert ($configureAgain.Code -eq 0 -and $configureAgain.Text -ceq $configure.Text) 'Configure is not deterministic and idempotent.'

        $templateArgs = @('profile','review-template','--package-root',$packageRoot,'--target-root',$target,'--state-root',$state,'--draft',$configuredPath)
        $template = Invoke-Host $templateArgs
        Expect-Code $template 0 'review template' '"status"\s*:\s*"incomplete"'
        if ($template.Code -eq 0) {
            $templateDocument = $template.Text | ConvertFrom-Json -AsHashtable -Depth 100
            $templatePath = [string]$templateDocument.storagePath
            Assert-Schema $templatePath 'profile-review-template'
            Assert (-not (Test-Json -LiteralPath $templatePath -SchemaFile (Join-Path $packageRoot 'core/profile/contracts/profile-review.schema.json') -ErrorAction SilentlyContinue)) 'Incomplete template unexpectedly satisfies the accepted review schema.'
            Assert (-not $templateDocument.ContainsKey('acceptedBy')) 'Review template fabricated acceptedBy.'
            Assert (@($templateDocument.fixtureSlots | Where-Object status -ceq 'missing').Count -eq 2) 'Review template fabricated fixture results.'
            $templateAgain = Invoke-Host $templateArgs
            Assert ($templateAgain.Code -eq 0 -and $templateAgain.Text -ceq $template.Text) 'Review template is not deterministic and idempotent.'
        }

        $missingRule = ($candidateDocument | ConvertTo-Json -Depth 100) | ConvertFrom-Json -AsHashtable -Depth 100
        $missingRule.candidateProfile.rules = @()
        $missingRulePath = Join-Path $case 'missing-rule-candidate.json'
        Write-Json $missingRulePath $missingRule
        Expect-Code (Invoke-Host @('profile','configure','--package-root',$packageRoot,'--target-root',$target,'--state-root',$state,'--draft',$draftPath,'--candidate',$missingRulePath)) 16 'unselected architecture claim' 'do not select enabled architecture claim'
    }
    Assert ((Target-Hash) -ceq $targetBefore) 'Configure or review-template changed TargetRoot.'

    $ambiguousChoices = @()
    $storedDiscoveryPath = Join-Path (Split-Path -Parent $draftPath) 'discovery.json'
    $storedDiscovery = Get-Content -Raw -LiteralPath $storedDiscoveryPath | ConvertFrom-Json -AsHashtable -Depth 100
    foreach ($question in @($storedDiscovery.questions | Where-Object kind -ceq 'ambiguous-module')) {
        $ambiguousChoices += [ordered]@{ questionId=[string]$question.id; decision='no-module-selected'; rationale='This fixture keeps the scaffold explicitly unprotected.' }
    }
    $policy = [ordered]@{}
    foreach ($name in @('gateSelection','severity','exceptions','baselines','unsupportedCoverage','ambiguousModules')) {
        $policy[$name] = [ordered]@{ decision='not-applicable'; rationale='The reviewed scaffold remains explicitly unprotected.' }
    }
    $review = [ordered]@{
        formatVersion=1; id='20261001-sample-guard-review'; decision='accepted'
        acceptedBy=[ordered]@{authorityType='human-review';authorityId='xiaolong-feng';candidateHostVerdictAllowed=$false}
        draftSha256=Hash $draftPath; discoverySha256=[string]$draft.discoverySha256
        candidateProfileSha256=[string]$draft.candidateProfileSha256; targetSnapshotSha256=[string]$draft.targetSnapshotSha256
        policyDecisions=$policy; ambiguousModuleChoices=$ambiguousChoices; moduleBindings=@()
        fixtures=@(
            [ordered]@{id='clean';classification='positive';expected='pass';actual='pass';evidenceSha256=('a'*64)},
            [ordered]@{id='violation';classification='negative';expected='findings-blocking';actual='findings-blocking';evidenceSha256=('b'*64)}
        )
        coverageDecision=[ordered]@{status='unprotected';rationale='No Module or Stage is selected; this candidate cannot claim protection.'}
    }
    Write-Json $reviewPath $review
    Assert-Schema $reviewPath 'profile-review'
    $validateArgs = @('profile','validate','--package-root',$packageRoot,'--target-root',$target,'--state-root',$state,'--draft',$draftPath,'--review',$reviewPath)
    $validation = Invoke-Host $validateArgs
    Expect-Code $validation 0 'validate' '"status"\s*:\s*"pass"'
    $validationPath = Join-Path $case 'validation-output.json'
    Write-Utf8 $validationPath ($validation.Text + "`n")
    Assert-Schema $validationPath 'profile-validation'
    if ($validation.Code -eq 0) {
        $validationDocument = $validation.Text | ConvertFrom-Json -AsHashtable -Depth 100
        Assert (-not [bool]$validationDocument.coverage.nonVacuous) 'Empty candidate was reported as non-vacuous.'
        Assert ($validationDocument.coverage.status -ceq 'unprotected') 'Empty candidate was reported as protected.'
        Assert ([bool]$validationDocument.readiness.targetAdoptionRequired) 'Validation did not preserve the Target adoption boundary.'
        Assert ([bool]$validationDocument.readiness.ciActivationRequired) 'Validation did not preserve the CI activation boundary.'
    }

    $protectedReview = ($review | ConvertTo-Json -Depth 100) | ConvertFrom-Json -AsHashtable -Depth 100
    $protectedReview.coverageDecision.status = 'protected'
    $protectedPath = Join-Path $case 'protected-review.json'
    Write-Json $protectedPath $protectedReview
    Expect-Code (Invoke-Host @('profile','validate','--package-root',$packageRoot,'--target-root',$target,'--state-root',$state,'--draft',$draftPath,'--review',$protectedPath)) 16 'protected no-op' 'cannot be accepted as protected'

    Write-Utf8 (Join-Path $target 'src/App/Program.cs') "namespace Sample; public static class Program { public static void Main(string[] args) { } }`n"
    Expect-Code (Invoke-Host $validateArgs) 17 'stale snapshot' 'stale'
    Write-Utf8 (Join-Path $target 'src/App/Program.cs') "namespace Sample; public static class Program { public static void Main() { } }`n"
    Assert ((Target-Hash) -ceq $targetBefore) 'Stale-snapshot test did not restore TargetRoot.'

    $oversized = Join-Path $target 'src/App/Oversized.cs'
    [IO.File]::WriteAllBytes($oversized, [byte[]]::new(1048577))
    Expect-Code (Invoke-Host $discoverArgs) 10 'oversized discovery input' 'exceeds 1048576 bytes'
    Remove-Item -LiteralPath $oversized -Force
    Assert ((Target-Hash) -ceq $targetBefore) 'Oversize negative did not restore TargetRoot.'

    $promotionArgs = @('profile','promote','--package-root',$packageRoot,'--target-root',$target,'--state-root',$state,'--draft',$draftPath,'--review',$reviewPath,'--output-root',$candidate,'--base-archive-sha256',('0'*64))
    $promotion = Invoke-Host $promotionArgs
    Expect-Code $promotion 0 'promote' '"kind"\s*:\s*"profile-promotion-candidate"'
    if ($promotion.Code -eq 0) {
        $promotionDocument = $promotion.Text | ConvertFrom-Json -AsHashtable -Depth 100
        $receiptPath = Join-Path $candidate 'promotion-receipt.json'
        Assert-Schema $receiptPath 'profile-promotion'
        Assert-Schema (Join-Path $candidate 'bundle/bundle-manifest.json') 'extension-bundle'
        Assert-Schema (Join-Path $candidate 'extension-review.json') 'extension-review'
        Assert-Schema ([string]$promotionDocument.profilePath) 'profile'
        Assert (-not [bool]$promotionDocument.boundaries.targetChanged) 'Promotion receipt claims a Target change.'
        Assert (-not [bool]$promotionDocument.boundaries.compositionCreated) 'Promotion receipt claims composition creation.'
        Assert (-not [bool]$promotionDocument.boundaries.ciActivated) 'Promotion receipt claims CI activation.'
    }
    Expect-Code (Invoke-Host $promotionArgs) 17 'existing promotion output' 'already exists'
    Assert ((Target-Hash) -ceq $targetBefore) 'Promotion changed TargetRoot.'
    Assert (-not (Test-Path -LiteralPath (Join-Path $target '.guard'))) 'M2 created Target-owned .guard authority.'
    Assert (-not (Test-Path -LiteralPath $marker)) 'M2 executed Target code.'

    $authorityContractPath = Join-Path $packageRoot 'core/profile/contracts/profile-authority-contract.json'
    Assert-Schema $authorityContractPath 'profile-authority-contract'
    $cli = Get-Content -Raw -LiteralPath $authorityContractPath | ConvertFrom-Json
    foreach ($id in @('profile.discover','profile.draft','profile.configure','profile.review-template','profile.validate','profile.promote')) {
        Assert (@($cli.commands | Where-Object id -ceq $id).Count -eq 1) "CLI contract is missing $id."
    }

    if ($failures.Count) { throw ($failures -join "`n") }
    [ordered]@{
        formatVersion=1;status='pass';discoveryDeterministic=$true;targetExecutionDenied=$true
        stateDraftNonAuthoritative=$true;configuredCandidateNonAuthoritative=$true;incompleteReviewTemplate=$true;staleSnapshotRejected=$true;emptyCoverageUnprotected=$true
        positiveAndNegativeFixturesRequired=$true;promotionCandidateCreated=$true;targetUnchanged=$true
        compositionCreated=$false;compositionSelected=$false;ciActivated=$false
    } | ConvertTo-Json -Depth 10
}
finally {
    if (Test-Path -LiteralPath $case) { Remove-Item -LiteralPath $case -Recurse -Force }
}
