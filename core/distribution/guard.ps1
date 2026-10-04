[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $PrerequisiteReportPath,
    [Parameter(ValueFromRemainingArguments)][string[]] $HostArguments
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-RedirectableErrorJson([string] $Json) {
    $writer = '[Console]::Error.Write([Console]::In.ReadToEnd())'
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($writer))
    $pwshPath = if ($IsWindows) { Join-Path $PSHOME 'pwsh.exe' } else { Join-Path $PSHOME 'pwsh' }
    $Json | & $pwshPath -NoLogo -NoProfile -NonInteractive -EncodedCommand $encoded
}

$launcher = Join-Path $PSScriptRoot 'core/distribution/Invoke-V4Installed.ps1'
if (-not [IO.File]::Exists($launcher)) {
    Write-RedirectableErrorJson '{"formatVersion":1,"status":"error","operation":"launcher","exitCategory":"non-public-entrypoint","message":"Use package/guard.ps1; the nested implementation copy is not a public entrypoint."}'
    exit 10
}
if (@($HostArguments | Where-Object { $null -ne $_ }).Count -eq 0) {
    Write-RedirectableErrorJson '{"formatVersion":1,"status":"error","operation":"launcher","exitCategory":"invalid-input","message":"At least one Host command argument is required."}'
    exit 10
}
try {
    $json = ConvertTo-Json -InputObject ([string[]]@($HostArguments)) -Compress
    & $launcher -PrerequisiteReportPath $PrerequisiteReportPath -HostArgumentsJson $json
    exit $LASTEXITCODE
}
catch {
    $message = $_.Exception.Message.Replace('\\','\\\\').Replace('"','\"').Replace("`r",' ').Replace("`n",' ')
    Write-RedirectableErrorJson "{`"formatVersion`":1,`"status`":`"error`",`"operation`":`"launcher`",`"exitCategory`":`"internal-error`",`"message`":`"$message`"}"
    exit 19
}
