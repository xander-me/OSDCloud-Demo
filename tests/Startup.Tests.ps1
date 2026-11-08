$ErrorActionPreference = 'Stop'
$source = Get-Content "$PSScriptRoot/../OSDCloud_Start.ps1" -Raw
$tokens=$null; $errors=$null
$ast=[System.Management.Automation.Language.Parser]::ParseInput($source,[ref]$tokens,[ref]$errors)
if ($errors.Count) { throw ($errors | Out-String) }
$body=$ast.Find({param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'OSDCloudLogic'},$true)
Invoke-Expression $body.Extent.Text
function Assert($condition,$message) { if (-not $condition) { throw $message } }
function Test-Path { param($Path); if ($script:mode -eq 'NotWinPE' -and $Path -like 'HKLM:*') { return $false }; return $true }
function Get-CimInstance { param($ClassName); if ($script:mode -eq 'Physical') { return [pscustomobject]@{Manufacturer='Dell';Model='PC'} }; if ($script:mode -eq 'HyperV') { return [pscustomobject]@{Manufacturer='Microsoft Corporation';Model='Virtual Machine'} }; [pscustomobject]@{Manufacturer='QEMU';Model='Standard PC (Q35 + ICH9, 2009)'} }
function Get-Disk { if ($script:mode -eq 'MultipleDisks') { [pscustomobject]@{Number=1;BusType='SCSI'} }; [pscustomobject]@{Number=0;BusType='SCSI';PartitionStyle='GPT'} }
function Get-Module { param($Name,[switch]$ListAvailable); if ($script:mode -ne 'ModuleFailure') { [pscustomobject]@{Version=[version]'26.10.16.1'} } }
function Install-Module { param($Name,$RequiredVersion,[switch]$Force,$ErrorAction); $script:installs++; if ($script:mode -eq 'ModuleFailure') { throw 'Module failed' } }
function Import-Module { param($Name,$RequiredVersion,[switch]$Force,$ErrorAction) }
function Start-OSDCloud {
    param($OSVersion,$OSBuild,$OSEdition,$OSLanguage,$OSActivation,$ZTI,$Firmware,$Restart,$Shutdown,$SkipAutopilot)
    $script:calls++; $script:settings=@{}+$PSBoundParameters
    Assert (-not $Global:MyOSDCloud.SkipClearDisk -and -not $Global:MyOSDCloud.SkipNewOSDisk -and -not $Global:MyOSDCloud.SkipAllDiskSteps) 'Native wipe disabled'
    if ($script:mode -eq 'EngineFailure') { throw 'Engine failed' }
    if ($script:mode -ne 'Incomplete') { $Global:OSDCloud=@{TimeEnd=Get-Date} }
}
function New-Item { param($Path,$ItemType,[switch]$Force) }
function Out-File { param([Parameter(ValueFromPipeline)] $InputObject,[Parameter(Position=0)]$FilePath,$Encoding,[switch]$Force); process { $script:files[$FilePath]=[string]$InputObject } }
function Start-Sleep { param($Seconds) }
function wpeutil { param($command); $script:reboot++; $global:LASTEXITCODE=0 }
foreach ($mode in 'NotWinPE','Physical','MultipleDisks','ModuleFailure','EngineFailure','Incomplete','HyperV','Proxmox') {
    $script:mode=$mode; $script:installs=0; $script:calls=0; $script:reboot=0; $script:files=@{}; $caught=$false
    try { OSDCloudLogic } catch { $caught=$true }
    if ($mode -in 'HyperV','Proxmox') {
        Assert ($script:installs -eq 0) 'Installed OSD unnecessarily contacted Gallery'
        Assert (-not $caught -and $script:reboot -eq 1 -and $script:calls -eq 1) "$mode did not complete mocked staging"
        Assert ($script:settings.OSBuild -eq '25H2' -and $script:settings.OSLanguage -eq 'da-dk' -and $script:settings.OSActivation -eq 'Retail') 'Wrong Windows settings'
        Assert (-not $script:settings.Restart -and -not $script:settings.Shutdown -and $script:settings.SkipAutopilot) 'Unexpected engine handoff'
        $config=$script:files['C:\ProgramData\OSDeploy\OSDeploy.AutopilotOOBE.json'] | ConvertFrom-Json
        Assert ($config.PostAction -eq 'Quit' -and $config.GroupTagOptions.Count -eq 2) 'Invalid Autopilot JSON'
        Assert (-not $script:files.ContainsKey('C:\Windows\Setup\Scripts\SetupComplete.cmd')) 'SetupComplete overwritten'
        Assert ($script:files['C:\ProgramData\OSDeploy\OOBE.ps1'].Trim() -eq (Get-Content "$PSScriptRoot/../OOBE.ps1" -Raw).Trim()) 'Embedded OOBE differs'
    } else { Assert ($caught -and $script:reboot -eq 0 -and $script:files.Count -eq 0) "$mode did not stop before staging/reboot" }
    Write-Host "PASS startup $mode"
}
# A broken central setting must fail before the engine is reached.
$bad=$body.Extent.Text.Replace('"GroupTag": "OptionA",','"GroupTag": "OptionA", "bad",')
Invoke-Expression $bad
$script:calls=0; $caught=$false
try { OSDCloudLogic } catch { $caught=$true }
Assert ($caught -and $script:calls -eq 0) 'Malformed JSON reached engine'
Write-Host 'PASS malformed JSON stops before installation'
