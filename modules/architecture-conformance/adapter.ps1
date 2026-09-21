Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($env:V4_STAGE_INPUT_JSON)) { throw 'V4_STAGE_INPUT_JSON is required.' }
$inputData = $env:V4_STAGE_INPUT_JSON | ConvertFrom-Json
if ($inputData.formatVersion -ne 1 -or $inputData.stage -notin @('pre','post')) { throw 'Architecture Conformance supports only Pre and Post.' }

$targetRoot = [IO.Path]::GetFullPath([string]$inputData.targetRoot)
$config = $inputData.config
$enabled = @($config.enabledClaims)
$projects = @(Get-ChildItem -LiteralPath $targetRoot -Recurse -File -Filter '*.csproj' | Sort-Object FullName)
$coverage = [Collections.Generic.List[object]]::new()
$findings = [Collections.Generic.List[object]]::new()

function Add-Finding([string] $RuleId, [string] $Subject) {
    $findings.Add([ordered]@{ ruleId=$RuleId; subject=$Subject; evidenceKind='project-model-raw'; detectorId='project-model'; severity='blocking' })
}
function Relative([string] $Path) { [IO.Path]::GetRelativePath($targetRoot, $Path).Replace('\','/') }
function Enabled([string] $Claim) { return $enabled -contains $Claim }

if ($projects.Count -eq 0) {
    foreach ($claim in $enabled) { $coverage.Add([ordered]@{ claimId=$claim; matched=0; minimum=1 }) }
    [ordered]@{ formatVersion=1; status='error'; exitCategory='prerequisite-missing'; message='No declared project files were found.'; findings=@(); coverage=@($coverage) } | ConvertTo-Json -Depth 20 -Compress
    exit 0
}

foreach ($project in $projects) {
    try { $xml = [xml][IO.File]::ReadAllText($project.FullName) }
    catch { throw "Project XML is invalid: $(Relative $project.FullName): $($_.Exception.Message)" }
    $projectSubject = Relative $project.FullName

    if (Enabled 'ARCH.PROJECT_REFERENCE') {
        foreach ($reference in @($xml.SelectNodes("//*[local-name()='ProjectReference']"))) {
            $include = [string]$reference.Include
            foreach ($forbidden in @($config.forbiddenProjectReferences)) {
                if ($include -like $forbidden) { Add-Finding 'ARCH.PROJECT_REFERENCE' "$projectSubject -> $include" }
            }
        }
    }
    if (Enabled 'ARCH.PACKAGE_REFERENCE') {
        foreach ($reference in @($xml.SelectNodes("//*[local-name()='PackageReference']"))) {
            $identity = if ($reference.Include) { [string]$reference.Include } else { [string]$reference.Update }
            if (@($config.forbiddenPackages) -contains $identity) { Add-Finding 'ARCH.PACKAGE_REFERENCE' "$projectSubject -> $identity" }
        }
    }
    if (Enabled 'ARCH.TARGET_FRAMEWORK') {
        $frameworks = @($xml.SelectNodes("//*[local-name()='TargetFramework' or local-name()='TargetFrameworks']") | ForEach-Object { ([string]$_.InnerText).Split(';',[StringSplitOptions]::RemoveEmptyEntries) } | ForEach-Object { $_.Trim() })
        if ($frameworks.Count -eq 0) { Add-Finding 'ARCH.TARGET_FRAMEWORK' "$projectSubject -> <missing>" }
        foreach ($framework in $frameworks) {
            if (@($config.allowedTargetFrameworks) -notcontains $framework) { Add-Finding 'ARCH.TARGET_FRAMEWORK' "$projectSubject -> $framework" }
        }
    }
    if ((Enabled 'ARCH.GRAPH_COMPLETENESS') -and $config.requireResolvedProjectReferences) {
        foreach ($reference in @($xml.SelectNodes("//*[local-name()='ProjectReference']"))) {
            $resolved = [IO.Path]::GetFullPath((Join-Path $project.DirectoryName ([string]$reference.Include)))
            $prefix = $targetRoot.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
            if (-not $resolved.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) -or -not [IO.File]::Exists($resolved)) {
                Add-Finding 'ARCH.GRAPH_COMPLETENESS' "$projectSubject -> $([string]$reference.Include)"
            }
        }
    }
}

foreach ($claim in $enabled) { $coverage.Add([ordered]@{ claimId=$claim; matched=$projects.Count; minimum=1 }) }
$status = if ($findings.Count -eq 0) { 'pass' } else { 'fail' }
$category = if ($status -eq 'pass') { 'success' } else { 'findings-blocking' }
[ordered]@{ formatVersion=1; status=$status; exitCategory=$category; findings=@($findings); coverage=@($coverage) } | ConvertTo-Json -Depth 20 -Compress
