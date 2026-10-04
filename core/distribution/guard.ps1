[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $PrerequisiteReportPath,
    [Parameter(ValueFromRemainingArguments)][string[]] $HostArguments
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$launcher = Join-Path $PSScriptRoot 'core/distribution/Invoke-V4Installed.ps1'
if (-not [IO.File]::Exists($launcher)) {
    [Console]::Error.WriteLine('{"formatVersion":1,"status":"error","operation":"launcher","exitCategory":"non-public-entrypoint","message":"Use package/guard.ps1; the nested implementation copy is not a public entrypoint."}')
    exit 10
}
if (@($HostArguments | Where-Object { $null -ne $_ }).Count -eq 0) {
    [Console]::Error.WriteLine('{"formatVersion":1,"status":"error","operation":"launcher","exitCategory":"invalid-input","message":"At least one Host command argument is required."}')
    exit 10
}
try {
    $json = ConvertTo-Json -InputObject ([string[]]@($HostArguments)) -Compress
    & $launcher -PrerequisiteReportPath $PrerequisiteReportPath -HostArgumentsJson $json
    exit $LASTEXITCODE
}
catch {
    $message = $_.Exception.Message.Replace('\\','\\\\').Replace('"','\"').Replace("`r",' ').Replace("`n",' ')
    [Console]::Error.WriteLine("{`"formatVersion`":1,`"status`":`"error`",`"operation`":`"launcher`",`"exitCategory`":`"internal-error`",`"message`":`"$message`"}")
    exit 19
}
