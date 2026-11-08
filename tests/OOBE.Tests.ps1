$ErrorActionPreference='Stop'
$source=Get-Content "$PSScriptRoot/../OOBE.ps1" -Raw
function Assert($condition,$message) { if (-not $condition) { throw $message } }
function Get-Content { param($Path,[switch]$Raw); if ($Path -like '*AutopilotOOBE.json') { return '{"PostAction":"Quit","Assign":{"IsPresent":false},"GroupTagOptions":["OptionA","OPTION B"]}' }; '{"RemoveAppx":["Microsoft.BingWeather"]}' }
function Install-Module { param($Name,$RequiredVersion,[switch]$Force,$ErrorAction) }
function Import-Module { param($Name,$RequiredVersion,[switch]$Force,$ErrorAction) }
function Start-AutopilotOOBE { if ($script:mode -eq 'UIFailure') { throw 'UI failure' } }
function Get-CimInstance { param($ClassName); [pscustomobject]@{SerialNumber='TEST-ONLY'} }
function Get-AutopilotDevice { param($serial,$ErrorAction); if ($script:mode -ne 'Unregistered') { [pscustomobject]@{serialNumber='TEST-ONLY';groupTag='OPTION B'} } }
function Start-Sleep { param($Seconds) }
function Start-OOBEDeploy { $script:cleanup++; if ($script:mode -eq 'CleanupFailure') { throw 'Cleanup failure' } }
function Get-AppxPackage { param([switch]$AllUsers,$ErrorAction); if ($script:mode -eq 'AppRemains') { [pscustomobject]@{Name='Microsoft.BingWeather'} } }
function Get-AppxProvisionedPackage { param([switch]$Online,$ErrorAction) }
function Restart-Computer { param([switch]$Force); $script:reboots++ }
function Read-Host { param($Prompt); $script:pauses++ }
$oldUser=$env:USERNAME
try {
    $env:USERNAME='defaultuser0'
    foreach ($mode in 'UIFailure','Unregistered','CleanupFailure','AppRemains','Success') {
        $script:mode=$mode; $script:cleanup=0; $script:reboots=0; $script:pauses=0; $caught=$false
        try { Invoke-Expression $source } catch { $caught=$true }
        if ($mode -eq 'Success') { Assert (-not $caught -and $script:reboots -eq 1 -and $script:cleanup -eq 1) 'Success flow failed' }
        else { Assert ($caught -and $script:reboots -eq 0 -and $script:pauses -eq 1) "$mode did not stop visibly" }
        if ($mode -in 'UIFailure','Unregistered') { Assert ($script:cleanup -eq 0) 'Cleanup before verified registration' }
        Write-Host "PASS OOBE $mode"
    }
} finally { $env:USERNAME=$oldUser }
