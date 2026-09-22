[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$packageRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$repoRoot = [IO.Path]::GetFullPath((Join-Path $packageRoot '../../..'))
$runRoot = Join-Path $repoRoot 'artifacts/guards/v4/p7-distribution'
$project = Join-Path $packageRoot 'core/host/V4.Guards.Host/V4.Guards.Host.csproj'
$buildRoot = Join-Path $packageRoot 'build'
$builder = Join-Path $packageRoot 'core/distribution/New-V4Distribution.ps1'
$installer = Join-Path $packageRoot 'core/distribution/Install-V4Distribution.ps1'
$prerequisites = Join-Path $packageRoot 'core/distribution/Test-V4Prerequisites.ps1'
$sourceCommit = (git -C $repoRoot rev-parse HEAD).Trim().ToLowerInvariant()
$failures = [Collections.Generic.List[string]]::new()

function Run([string] $Script, [string[]] $Arguments) {
    $output = @(& pwsh -NoLogo -NoProfile -NonInteractive -File $Script @Arguments 2>&1)
    [pscustomobject]@{ Code=$LASTEXITCODE; Output=($output -join "`n") }
}

if (Test-Path -LiteralPath $runRoot) { Remove-Item -LiteralPath $runRoot -Recurse -Force }
[void][IO.Directory]::CreateDirectory($runRoot)
$properties = @('-p:ImportDirectoryBuildProps=false','-p:ImportDirectoryBuildTargets=false','-p:ImportDirectoryPackagesProps=false','-p:ImportDirectorySolutionProps=false','-p:ImportDirectorySolutionTargets=false',"-p:CustomBeforeMicrosoftCommonProps=$(Join-Path $buildRoot 'V4.Build.props')")
$buildArtifacts = Join-Path $runRoot 'build'
Push-Location $buildRoot
try {
    & dotnet restore $project --configfile (Join-Path $buildRoot 'NuGet.config') --artifacts-path $buildArtifacts -nologo @properties
    if ($LASTEXITCODE) { throw 'P7 distribution restore failed.' }
    & dotnet build $project --no-restore --configuration Release --artifacts-path $buildArtifacts -nologo @properties
    if ($LASTEXITCODE) { throw 'P7 distribution build failed.' }
} finally { Pop-Location }
$hostRoot = Join-Path $buildArtifacts 'bin/V4.Guards.Host/release'

$outA = Join-Path $runRoot 'out-a'; $outB = Join-Path $runRoot 'out-b'
$a = Run $builder @('-PackageRoot',$packageRoot,'-HostRoot',$hostRoot,'-OutputDirectory',$outA,'-SourceCommit',$sourceCommit)
$b = Run $builder @('-PackageRoot',$packageRoot,'-HostRoot',$hostRoot,'-OutputDirectory',$outB,'-SourceCommit',$sourceCommit)
if ($a.Code -ne 0) { $failures.Add("first distribution failed: $($a.Output)") }
if ($b.Code -ne 0) { $failures.Add("second distribution failed: $($b.Output)") }
if ($a.Code -eq 0 -and $b.Code -eq 0) {
    $resultA = $a.Output | ConvertFrom-Json; $resultB = $b.Output | ConvertFrom-Json
    if ($resultA.archiveSha256 -cne $resultB.archiveSha256 -or (Get-FileHash $resultA.archivePath).Hash -cne (Get-FileHash $resultB.archivePath).Hash) { $failures.Add('identical inputs did not produce byte-identical archives') }
    if ((Get-Content -Raw "$($resultA.archivePath).sha256").Trim() -cne "$($resultA.archiveSha256)  $([IO.Path]::GetFileName($resultA.archivePath))") { $failures.Add('archive SHA-256 sidecar is invalid') }

    Add-Type -AssemblyName System.IO.Compression
    $zip = [IO.Compression.ZipFile]::OpenRead($resultA.archivePath)
    try {
        $manifestEntry = @($zip.Entries | Where-Object Name -eq 'distribution-manifest.json')
        if ($manifestEntry.Count -ne 1) { $failures.Add('archive has no exact distribution manifest') }
        else {
            $reader = [IO.StreamReader]::new($manifestEntry[0].Open()); try { $text=$reader.ReadToEnd() } finally { $reader.Dispose() }
            if (-not (Test-Json -Json $text -SchemaFile (Join-Path $packageRoot 'core/contracts/distribution-manifest.schema.json') -ErrorAction SilentlyContinue)) { $failures.Add('archive manifest violates schema') }
            $manifest=$text|ConvertFrom-Json
            if ($manifest.source.commit -cne $sourceCommit -or $manifest.source.packageHash -cne $resultA.packageHash) { $failures.Add('archive provenance is not bound') }
        }
    } finally { $zip.Dispose() }

    $tampered = Join-Path $runRoot 'tampered.zip'; Copy-Item -LiteralPath $resultA.archivePath -Destination $tampered
    $zip = [IO.Compression.ZipFile]::Open($tampered,[IO.Compression.ZipArchiveMode]::Update)
    try {
        $entry = @($zip.Entries | Where-Object { $_.FullName -like '*/package/plugin.json' })[0]
        $entry.Delete(); $replacement=$zip.CreateEntry('v4-guards-0.1.0/package/plugin.json',[IO.Compression.CompressionLevel]::NoCompression)
        $writer=[IO.StreamWriter]::new($replacement.Open(),[Text.UTF8Encoding]::new($false)); try{$writer.Write('{"tampered":true}')}finally{$writer.Dispose()}
    } finally { $zip.Dispose() }
    $tamperRun = Run $installer @('-Mode','Install','-ArchivePath',$tampered,'-InstallRoot',(Join-Path $runRoot 'tampered-install'),'-ReceiptPath',(Join-Path $runRoot 'tampered-receipt.json'))
    if ($tamperRun.Code -eq 0 -or $tamperRun.Output -notmatch 'hash drift') { $failures.Add("tampered payload was not rejected: $($tamperRun.Output)") }
}

$positiveReport = Join-Path $runRoot 'prerequisites-positive.json'
$positive = Run $prerequisites @('-PackageRoot',$packageRoot,'-Profile','synthetic_profile','-ReportPath',$positiveReport)
if ($positive.Code -ne 0 -or -not (Test-Json -LiteralPath $positiveReport -SchemaFile (Join-Path $packageRoot 'core/contracts/prerequisite-report.schema.json') -ErrorAction SilentlyContinue)) { $failures.Add("positive prerequisite report failed: $($positive.Output)") }
$negativeReport = Join-Path $runRoot 'prerequisites-negative.json'
$override = '{"dotnet":{"status":"missing"}}'
$negative = Run $prerequisites @('-PackageRoot',$packageRoot,'-Profile','synthetic_profile','-ReportPath',$negativeReport,'-RuntimeOverridesJson',$override)
if ($negative.Code -ne 15 -or -not (Test-Json -LiteralPath $negativeReport -SchemaFile (Join-Path $packageRoot 'core/contracts/prerequisite-report.schema.json') -ErrorAction SilentlyContinue) -or (Get-Content -Raw $negativeReport) -notmatch 'prerequisite-missing') { $failures.Add("missing prerequisite was not reported structurally: $($negative.Output)") }

if ($failures.Count) { throw ($failures -join "`n") }
Write-Host 'V4 P7 distribution tests passed: deterministic archive, provenance, sidecar, tamper rejection and declared prerequisites.'
