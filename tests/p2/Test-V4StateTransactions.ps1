[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$packageRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $packageRoot '../../..'))
$buildRoot = Join-Path $packageRoot 'build'
$project = Join-Path $packageRoot 'core/host/V4.Guards.Host/V4.Guards.Host.csproj'
$artifactsRoot = Join-Path $repositoryRoot 'artifacts/guards/v4/p2a'
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

function Assert-Success([string] $Name, $Run) {
    if ($Run.Code -ne 0) { $failures.Add("${Name}: expected success, got $($Run.Code): $($Run.Output)"); return $null }
    try { return $Run.Output | ConvertFrom-Json }
    catch { $failures.Add("${Name}: output is not JSON: $($Run.Output)"); return $null }
}

function Assert-Failure([string] $Name, $Run, [int] $Code, [string] $Category) {
    if ($Run.Code -ne $Code) { $failures.Add("${Name}: expected exit $Code, got $($Run.Code): $($Run.Output)") }
    if ($Run.Output -notmatch ('"exitCategory"\s*:\s*"' + [Regex]::Escape($Category) + '"')) {
        $failures.Add("${Name}: missing category $Category")
    }
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
    if ($LASTEXITCODE) { throw 'V4 P2A restore failed.' }
    & dotnet build $project --no-restore --artifacts-path $artifactsRoot -nologo @properties
    if ($LASTEXITCODE) { throw 'V4 P2A build failed.' }
} finally { Pop-Location }

$targetA = Join-Path $runRoot 'target-a'; $targetB = Join-Path $runRoot 'target-b'
$state = Join-Path $runRoot 'state'; $evidence = Join-Path $runRoot 'evidence'
foreach ($path in @($targetA,$targetB,$state,$evidence)) { New-Item -ItemType Directory -Path $path -Force | Out-Null }
[IO.File]::WriteAllText((Join-Path $targetA 'sentinel.txt'), "target-a`n", [Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $targetB 'sentinel.txt'), "target-b`n", [Text.UTF8Encoding]::new($false))
$packageBefore = Hash-Tree $packageRoot; $targetBefore = Hash-Tree $targetA

$bindArgs = @('state','bind','--package-root',$packageRoot,'--target-root',$targetA,'--state-root',$state,'--evidence-root',$evidence,'--profile','synthetic_profile')
$first = Assert-Success 'first bind' (Invoke-Host $bindArgs)
$second = Assert-Success 'idempotent bind' (Invoke-Host $bindArgs)
if ($null -ne $first -and ($first.projectId -notmatch '^[a-f0-9]{32}$' -or -not $first.created)) { $failures.Add('first bind identity/created flag is invalid') }
if ($null -ne $first -and $null -ne $second -and ($first.projectId -cne $second.projectId -or $second.created)) { $failures.Add('repeated binding is not idempotent') }

$bindB = Assert-Success 'second target bind' (Invoke-Host @('state','bind','--package-root',$packageRoot,'--target-root',$targetB,'--state-root',$state,'--evidence-root',$evidence,'--profile','default'))
if ($null -ne $first -and $null -ne $bindB -and $first.projectId -ceq $bindB.projectId) { $failures.Add('different canonical targets collided') }

if ($null -ne $first) {
    $put = Assert-Success 'state put' (Invoke-Host @('state','put','--package-root',$packageRoot,'--state-root',$state,'--evidence-root',$evidence,'--project',$first.projectId,'--relative-path','cache/value.txt','--content','atomic-value'))
    $written = Join-Path $state "projects/$($first.projectId)/data/cache/value.txt"
    if ($null -eq $put -or -not (Test-Path -LiteralPath $written) -or (Get-Content -Raw $written) -cne 'atomic-value') { $failures.Add('atomic state payload was not written') }
    Assert-Failure 'state path traversal' (Invoke-Host @('state','put','--package-root',$packageRoot,'--state-root',$state,'--evidence-root',$evidence,'--project',$first.projectId,'--relative-path','../escape.txt','--content','bad')) 11 'unsafe-path'
}

Assert-Failure 'mutable root overlaps target' (Invoke-Host @('state','bind','--package-root',$packageRoot,'--target-root',$targetA,'--state-root',$targetA,'--evidence-root',$evidence,'--profile','default')) 11 'unsafe-path'

$stateDocumentPath = Join-Path $state 'state.json'
if (-not (Test-Json -LiteralPath $stateDocumentPath -SchemaFile (Join-Path $packageRoot 'core/contracts/state.schema.json') -ErrorAction SilentlyContinue)) {
    $failures.Add('persisted state.json does not satisfy state.schema.json')
}

if ($null -ne $first) {
    $recoveryId = ('1' * 32); $payload = [Text.UTF8Encoding]::new($false).GetBytes('recovered-value')
    $payloadHash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($payload)).ToLowerInvariant()
    $destinationRelative = "projects/$($first.projectId)/data/recovered.txt"
    $tempRelative = "projects/$($first.projectId)/data/.v4-tx-$recoveryId.tmp"
    [IO.File]::WriteAllBytes((Join-Path $state $tempRelative), $payload)
    $journal = [ordered]@{ formatVersion = 1; id = $recoveryId; kind = 'state-write'; status = 'prepared'; projectId = $first.projectId; destinationPath = $destinationRelative; tempPath = $tempRelative; payloadHash = $payloadHash }
    $journal | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $state "transactions/$recoveryId.json") -Encoding utf8
    $recovered = Assert-Success 'prepared recovery' (Invoke-Host @('state','recover','--package-root',$packageRoot,'--state-root',$state,'--evidence-root',$evidence))
    if ($null -eq $recovered -or $recovered.recoveredTransactions -lt 1 -or (Get-Content -Raw (Join-Path $state $destinationRelative)) -cne 'recovered-value') { $failures.Add('prepared transaction was not recovered') }

    $driftId = ('2' * 32); $driftTemp = "projects/$($first.projectId)/data/.v4-tx-$driftId.tmp"
    [IO.File]::WriteAllText((Join-Path $state $driftTemp), 'drift', [Text.UTF8Encoding]::new($false))
    $driftJournal = [ordered]@{ formatVersion = 1; id = $driftId; kind = 'state-write'; status = 'prepared'; projectId = $first.projectId; destinationPath = "projects/$($first.projectId)/data/drift.txt"; tempPath = $driftTemp; payloadHash = ('0' * 64) }
    $driftJournal | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $state "transactions/$driftId.json") -Encoding utf8
    Assert-Failure 'recovery hash drift' (Invoke-Host @('state','recover','--package-root',$packageRoot,'--state-root',$state,'--evidence-root',$evidence)) 17 'state-conflict'
    $driftStatus = (Get-Content -Raw (Join-Path $state "transactions/$driftId.json") | ConvertFrom-Json).status
    if ($driftStatus -cne 'incomplete') { $failures.Add('drifted transaction was not marked incomplete') }
}

if ((Hash-Tree $packageRoot) -cne $packageBefore) { $failures.Add('state commands changed PackageRoot') }
if ((Hash-Tree $targetA) -cne $targetBefore) { $failures.Add('state commands changed TargetRoot') }

if ($failures.Count -gt 0) { throw ($failures -join "`n") }
Write-Host 'V4 P2A state tests passed: deterministic binding, atomic write, schema validity, prepared recovery and drift refusal.'
