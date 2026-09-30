[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$packageRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$publisher = Join-Path $packageRoot 'core/distribution/Publish-V4SelfContainedDistribution.ps1'
$builder = Join-Path $packageRoot 'core/distribution/New-V4Distribution.ps1'
$sourceCommit = (git -C $packageRoot rev-parse HEAD).Trim().ToLowerInvariant()
$rid = [Runtime.InteropServices.RuntimeInformation]::RuntimeIdentifier
if ($rid -notin @('win-x64','win-arm64','linux-x64','linux-arm64')) { throw "Unsupported native test RID: $rid" }
$workRoot = [IO.Path]::Combine([IO.Path]::GetTempPath(),'v4-guards-work','m1-self-contained')
$runRoot = Join-Path $workRoot ([Guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($runRoot)
$failures = [Collections.Generic.List[string]]::new()

function Run([string] $Script, [string[]] $Arguments) {
    $output = @(& pwsh -NoLogo -NoProfile -NonInteractive -File $Script @Arguments 2>&1)
    [pscustomobject]@{ Code=$LASTEXITCODE; Text=($output -join "`n") }
}

$firstMeasurement = Join-Path $runRoot 'first-measurement.json'
$first = Run $publisher @('-PackageRoot',$packageRoot,'-RuntimeIdentifier',$rid,'-OutputDirectory',(Join-Path $runRoot 'first'),'-MeasurementPath',$firstMeasurement,'-SourceCommit',$sourceCommit)
if ($first.Code -ne 0) { throw "First self-contained publish failed: $($first.Text)" }
$firstResult = $first.Text | ConvertFrom-Json
if (-not (Test-Json -LiteralPath $firstMeasurement -SchemaFile (Join-Path $packageRoot 'core/distribution/contracts/distribution-measurement.schema.json') -ErrorAction SilentlyContinue)) {
    $failures.Add('First measurement violates its schema.')
} else {
    $measurement = Get-Content -Raw -LiteralPath $firstMeasurement | ConvertFrom-Json
    if ($measurement.runtime.rid -cne $rid -or $measurement.runtime.deploymentModel -cne 'self-contained' -or $measurement.probes.hostVersion -cne 'pass') {
        $failures.Add('Measurement does not bind the native self-contained runtime and passing Host probe.')
    }
}

$secondMeasurement = Join-Path $runRoot 'second-measurement.json'
$second = Run $publisher @('-PackageRoot',$packageRoot,'-RuntimeIdentifier',$rid,'-OutputDirectory',(Join-Path $runRoot 'second'),'-MeasurementPath',$secondMeasurement,'-SourceCommit',$sourceCommit)
if ($second.Code -ne 0) { $failures.Add("Second self-contained publish failed: $($second.Text)") }
else {
    $secondResult = $second.Text | ConvertFrom-Json
    if ($firstResult.archiveSha256 -cne $secondResult.archiveSha256) { $failures.Add('Identical self-contained inputs did not produce byte-identical archives.') }
}

$hostCopy = Join-Path $runRoot 'missing-apphost'
Copy-Item -LiteralPath ([string]$firstResult.hostRoot) -Destination $hostCopy -Recurse
$hostApp = Join-Path $hostCopy $(if ($rid.StartsWith('win-')) { 'v4-guards.exe' } else { 'v4-guards' })
Remove-Item -LiteralPath $hostApp -Force
$reject = Run $builder @(
    '-PackageRoot',(Join-Path $firstResult.hostRoot '../package'),
    '-HostRoot',$hostCopy,'-CompanionRoot',[string]$firstResult.companionRoot,
    '-OutputDirectory',(Join-Path $runRoot 'reject'),'-SourceCommit',$sourceCommit,
    '-RuntimeIdentifier',$rid,'-DeploymentModel','self-contained'
)
if ($reject.Code -eq 0 -or $reject.Text -notmatch 'native application hosts') { $failures.Add("Missing self-contained apphost was not rejected: $($reject.Text)") }

if ($failures.Count) { throw ($failures -join "`n") }
Write-Host "M1 self-contained distribution tests passed for ${rid}: offline publish, native start, measurement, deterministic archive and apphost refusal."
