# Reproduce OSDCloud StartURL's Invoke-Expression launch; no network/disk/deployment calls.
$ErrorActionPreference='Stop'
$source=Get-Content "$PSScriptRoot/../OSDCloud_Start.ps1" -Raw
function Run-StartupCase([string]$Mode) {
    $global:StartupCase=$Mode
    $global:StartupPromptsAtInstall=-1; $global:StartupPrompts=@(); $global:StartupInstallCalls=0; $global:StartupRequests=0; $global:StartupStoppedTranscript=$false
    function Read-Host { param($Prompt); $global:StartupPrompts += $Prompt; return '' }
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
    function OSDCloudLogic { param($BundlePath); $global:StartupPromptsAtInstall=$global:StartupPrompts.Count; $global:StartupInstallCalls++ }
    $beforeDrive=$env:SystemDrive; $beforeTemp=$env:TEMP; $beforeTLS=[Net.ServicePointManager]::SecurityProtocol
    $global:StartupCaught=''
    try {
        $env:SystemDrive=if ($Mode -eq 'NotWinPE') { 'C:' } else { 'X:' }; $env:TEMP=[IO.Path]::GetTempPath()
        # This is the execution mechanism used by Invoke-WebPSScript, rather than -File.
        Invoke-Expression $source
    } catch { $global:StartupCaught=$_.Exception.Message }
    finally { $env:SystemDrive=$beforeDrive; $env:TEMP=$beforeTemp; [Net.ServicePointManager]::SecurityProtocol=$beforeTLS }
}
foreach ($mode in 'GitHubFailure','ModuleFailure') {
    Run-StartupCase $mode
    if ($global:StartupInstallCalls -ne 0 -or $global:StartupPrompts.Count -ne 1 -or $global:StartupCaught -notlike 'TEST:*' -or -not $global:StartupStoppedTranscript) { throw "Failure did not pause and terminate safely: $mode" }
    Write-Host "PASS $mode pauses for the error and never calls installation"
}
Run-StartupCase 'Success'
if ($global:StartupInstallCalls -ne 1 -or $global:StartupRequests -ne 1 -or $global:StartupPromptsAtInstall -ne 0 -or $global:StartupCaught) { throw 'Automatic startup asked for input or failed before the mocked installer.' }
Write-Host 'PASS automatic startup reaches the mocked installer with no input prompt'
Run-StartupCase 'NotWinPE'
if ($global:StartupInstallCalls -ne 0 -or $global:StartupRequests -ne 0 -or $global:StartupCaught -ne 'Run this startup script from WinPE.' -or $global:StartupPrompts.Count -ne 1) { throw 'Non-WinPE startup did not stop before network/installation.' }
Write-Host 'PASS non-WinPE startup stops before contacting GitHub or starting installation'
Write-Host '4 startup mock cases passed. WinPE itself remains untested here.'
