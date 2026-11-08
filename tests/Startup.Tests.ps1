# Reproduce OSDCloud StartURL's Invoke-Expression launch; no network/disk/deployment calls.
$ErrorActionPreference='Stop'
$source=Get-Content "$PSScriptRoot/../OSDCloud_Start.ps1" -Raw
function Run-StartupCase([string]$Mode,[string]$Choice='DEMO') {
    $global:StartupCase=$Mode; $global:StartupChoice=$Choice
    $global:StartupPrompts=@(); $global:StartupInstallCalls=0; $global:StartupRequests=0; $global:StartupStoppedTranscript=$false
    function Read-Host { param($Prompt); $global:StartupPrompts += $Prompt; if ($global:StartupPrompts.Count -eq 1) { return $global:StartupChoice }; return '' }
    function Start-Transcript { param($Path,[switch]$Append,$ErrorAction) }
    function Stop-Transcript { $global:StartupStoppedTranscript=$true }
    function Invoke-RestMethod {
        param($Uri,$Headers,$TimeoutSec,$ErrorAction)
        $global:StartupRequests++
        if ($global:StartupCase -eq 'GitHubFailure') { throw 'TEST: GitHub connection failed' }
        [pscustomobject]@{sha=('a'*40)}
    }
    function Invoke-WebRequest { param([switch]$UseBasicParsing,$Uri,$OutFile,$TimeoutSec,$ErrorAction) }
    function New-Item { param($Path,$ItemType,[switch]$Force) }
    function Set-Content { param($Path,$Value,$Encoding) }
    function Import-Module {
        param($Name,[switch]$Force,$ErrorAction)
        if ($global:StartupCase -eq 'ModuleFailure') { throw 'TEST: module failed to load' }
    }
    function Start-DemoInstallation { param($BundlePath); $global:StartupInstallCalls++ }
    $beforeDrive=$env:SystemDrive; $beforeTemp=$env:TEMP; $beforeTLS=[Net.ServicePointManager]::SecurityProtocol
    $global:StartupCaught=''
    try {
        $env:SystemDrive='X:'; $env:TEMP=[IO.Path]::GetTempPath()
        # This is the execution mechanism used by Invoke-WebPSScript, rather than -File.
        Invoke-Expression $source
    } catch { $global:StartupCaught=$_.Exception.Message }
    finally { $env:SystemDrive=$beforeDrive; $env:TEMP=$beforeTemp; [Net.ServicePointManager]::SecurityProtocol=$beforeTLS }
}
foreach ($mode in 'GitHubFailure','ModuleFailure') {
    Run-StartupCase $mode
    if ($global:StartupInstallCalls -ne 0 -or $global:StartupPrompts.Count -ne 2 -or $global:StartupCaught -notlike 'TEST:*' -or -not $global:StartupStoppedTranscript) { throw "Failure did not pause and terminate safely: $mode" }
    Write-Host "PASS $mode pauses for the error and never calls installation"
}
Run-StartupCase 'Success' ' demo '
if ($global:StartupInstallCalls -ne 1 -or $global:StartupRequests -ne 1 -or $global:StartupPrompts.Count -ne 2 -or $global:StartupCaught) { throw 'Valid DEMO input did not reach the mocked installer.' }
Write-Host 'PASS trimmed, case-insensitive DEMO reaches the mocked installer through Invoke-Expression'
Run-StartupCase 'Success' 'cancel'
if ($global:StartupInstallCalls -ne 0 -or $global:StartupRequests -ne 0) { throw 'Cancelled startup performed work.' }
Write-Host 'PASS cancelled selection never contacts GitHub or starts installation'
Write-Host '4 startup mock cases passed. WinPE itself remains untested here.'
