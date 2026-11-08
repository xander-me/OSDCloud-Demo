# Exercise the single-file StartURL through Invoke-Expression. All effects are mocked.
$ErrorActionPreference='Stop'
$source=Get-Content "$PSScriptRoot/../OSDCloud_Start.ps1" -Raw
function Run-StartupCase([string]$Mode) {
    $global:StartupMode=$Mode; $global:StartupPrompts=@(); $global:StartupEngineCalls=0; $global:StartupRequests=0
    $global:StartupStoppedTranscript=$false; $global:StartupCaught=''; $global:StartupEngineArgs=$null
    function Read-Host { param($Prompt); $global:StartupPrompts += $Prompt; return '' }
    function Start-Transcript { param($Path,[switch]$Append,$ErrorAction) }
    function Stop-Transcript { $global:StartupStoppedTranscript=$true }
    function Test-Path { param($Path); return $true }
    function Get-CimInstance {
        param($ClassName,$ErrorAction)
        if ($global:StartupMode -eq 'Physical') { return [pscustomobject]@{Manufacturer='Dell Inc.';Model='Physical PC'} }
        [pscustomobject]@{Manufacturer='QEMU';Model='Standard PC (Q35 + ICH9, 2009)'}
    }
    function Get-Disk {
        if ($global:StartupMode -eq 'MultipleDisks') { [pscustomobject]@{Number=1;BusType='SCSI';PartitionStyle='GPT'} }
        [pscustomobject]@{Number=0;BusType='SCSI';PartitionStyle='GPT'}
    }
    function Invoke-RestMethod {
        param($Uri,$Headers,$TimeoutSec,$ErrorAction)
        $global:StartupRequests++
        if ($global:StartupMode -eq 'GitHubFailure') { throw 'TEST: GitHub connection failed' }
        [pscustomobject]@{sha=('a'*40)}
    }
    function Invoke-WebRequest { param([switch]$UseBasicParsing,$Uri,$OutFile,$TimeoutSec,$ErrorAction) }
    function New-Item { param($Path,$ItemType,[switch]$Force) }
    function Set-Content { param($Path,$Value,$Encoding) }
    function Get-Module { param($Name,[switch]$ListAvailable); [pscustomobject]@{Version=[version]'26.10.16.1'} }
    function Import-Module {
        param($Name,$RequiredVersion,[switch]$Force,$ErrorAction)
        if ($global:StartupMode -eq 'ModuleFailure') { throw 'TEST: module failed to load' }
    }
    function Start-OSDCloud {
        param($OSName,$OSEdition,$OSLanguage,$OSActivation,[switch]$SkipAutopilot,[switch]$ZTI,[switch]$Restart,[switch]$Shutdown)
        if ($global:StartupPrompts.Count) { throw 'Unexpected prompt before installation.' }
        $global:StartupEngineCalls++
        $global:StartupEngineArgs=@{}+$PSBoundParameters
        throw 'TEST: stopped at mocked OSD engine; no disk operation performed'
    }
    $drive=$env:SystemDrive; $temp=$env:TEMP; $tls=[Net.ServicePointManager]::SecurityProtocol
    $overrides=Get-Variable MyOSDCloud -Scope Global -ErrorAction SilentlyContinue
    try {
        $env:SystemDrive=if ($Mode -eq 'NotWinPE') {'C:'} else {'X:'}; $env:TEMP=[IO.Path]::GetTempPath()
        Invoke-Expression $source
    } catch { $global:StartupCaught=$_.Exception.Message }
    finally {
        $env:SystemDrive=$drive; $env:TEMP=$temp; [Net.ServicePointManager]::SecurityProtocol=$tls
        if ($overrides) { $global:MyOSDCloud=$overrides.Value } else { Remove-Variable MyOSDCloud -Scope Global -ErrorAction SilentlyContinue }
    }
}
foreach ($mode in 'GitHubFailure','ModuleFailure','NotWinPE','Physical','MultipleDisks') {
    Run-StartupCase $mode
    if ($global:StartupEngineCalls -ne 0 -or $global:StartupPrompts.Count -ne 1 -or -not $global:StartupCaught -or -not $global:StartupStoppedTranscript) { throw "Failure did not stop visibly before the engine: $mode" }
    Write-Host "PASS $mode stops before installation and pauses on error"
}
Run-StartupCase 'EngineReached'
if ($global:StartupEngineCalls -ne 1 -or $global:StartupEngineArgs.OSName -ne 'Windows 11 25H2 x64' -or $global:StartupEngineArgs.OSLanguage -ne 'da-dk' -or $global:StartupCaught -notlike 'TEST: stopped at mocked OSD engine*') { throw 'Inline function was not called with the Danish settings.' }
Write-Host 'PASS single-file definition is invoked automatically with Windows 11 25H2 / da-dk'
Write-Host '6 startup mock cases passed; no disk, download, app removal or tenant operation executed.'
