Write-Host 'OSDCloud Demo startup revision: 2026-11-08.2' -ForegroundColor Cyan

function OSDCloudLogic {
    $ErrorActionPreference = 'Stop'
    #================================================
    #   [PreOS] WinPE, VM and target disk
    #================================================
    if (-not (Test-Path 'HKLM:\SYSTEM\CurrentControlSet\Control\MiniNT')) {
        throw 'Start this script from OSDCloud WinPE.'
    }
    $computer = Get-CimInstance Win32_ComputerSystem
    $isVM = ($computer.Manufacturer -eq 'Microsoft Corporation' -and $computer.Model -eq 'Virtual Machine') -or
        ($computer.Manufacturer -match 'QEMU|Red Hat|KVM' -and $computer.Model -match 'Standard PC|KVM|Virtual')
    if (-not $isVM) { throw "Only Hyper-V/Proxmox demo VMs are supported: $($computer.Manufacturer) / $($computer.Model)" }
    $disks = @(Get-Disk | Where-Object { $_.BusType -notin @('USB', 'SD', 'MMC') })
    if ($disks.Count -ne 1 -or $disks[0].Number -ne 0) {
        throw 'The demo requires exactly one local target disk, numbered 0.'
    }
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Write-Host 'Loading OSD PowerShell module' -ForegroundColor Cyan
    $osdVersion = '26.10.16.1'
    $installedOSD = Get-Module -Name OSD -ListAvailable |
        Where-Object { $_.Version -eq [version]$osdVersion } | Select-Object -First 1
    if (-not $installedOSD) {
        try {
            Install-Module OSD -RequiredVersion $osdVersion -Force -ErrorAction Stop
        }
        catch {
            throw "OSD $osdVersion is not installed and PowerShell Gallery installation failed. Check WinPE DNS, proxy, clock and HTTPS access to www.powershellgallery.com, or include OSD $osdVersion in the boot image. No disk changes have started. Details: $($_.Exception.Message)"
        }
    }
    Import-Module OSD -RequiredVersion $osdVersion -Force -ErrorAction Stop

    #================================================
    #   [OS] Windows settings and native OSDCloud wipe
    #================================================
    $Global:MyOSDCloud = @{
        DriverPackName = 'none'
        SkipRecoveryPartition = $true
        SkipAllDiskSteps = $false
        SkipClearDisk = $false
        SkipNewOSDisk = $false
        SetupCompleteNoRestart = $true
        ShutdownSetupComplete = $false
        WindowsUpdate = $false
        WindowsUpdateDrivers = $false
        WindowsDefenderUpdate = $false
    }
    $Params = @{
        OSVersion = 'Windows 11'
        OSBuild = '25H2'
        OSEdition = 'Pro'
        OSLanguage = 'da-dk'
        OSActivation = 'Retail'
        ZTI = $true
        Firmware = $false
        Restart = $false
        Shutdown = $false
        SkipAutopilot = $true
    }

    #================================================
    #   OOBE settings (validated before disk modification)
    #================================================
    $OOBEDeployJson = @'
    {
        "Autopilot":  {
                        "IsPresent":  false
                    },
        "RemoveAppx":  [
                        "Microsoft.549981C3F5F10",
                            "Microsoft.BingWeather",
                            "Microsoft.GetHelp",
                            "Microsoft.Getstarted",
                            "Microsoft.Microsoft3DViewer",
                            "Microsoft.MicrosoftOfficeHub",
                            "Microsoft.MicrosoftSolitaireCollection",
                            "Microsoft.MixedReality.Portal",
                            "Microsoft.Office.OneNote",
                            "Microsoft.People",
                            "Microsoft.SkypeApp",
                            "Microsoft.Wallet",
                            "Microsoft.WindowsCamera",
                            "microsoft.windowscommunicationsapps",
                            "Microsoft.WindowsFeedbackHub",
                            "Microsoft.WindowsMaps",
                            "Microsoft.Xbox.TCUI",
                            "Microsoft.XboxApp",
                            "Microsoft.XboxGameOverlay",
                            "Microsoft.XboxGamingOverlay",
                            "Microsoft.XboxIdentityProvider",
                            "Microsoft.XboxSpeechToTextOverlay",
                            "Microsoft.YourPhone",
                            "Microsoft.ZuneMusic",
                            "Microsoft.ZuneVideo"
                    ],
        "UpdateDrivers":  {
                            "IsPresent":  false
                        },
        "UpdateWindows":  {
                            "IsPresent":  false
                        }
    }
'@
    $AutopilotOOBEJson = @'
    {
        "Assign": { "IsPresent": false },
        "GroupTag": "OptionA",
        "GroupTagOptions": ["OptionA", "OPTION B"],
        "Hidden": ["AssignedComputerName", "AssignedUser", "PostAction", "Assign", "AddToGroup", "Run", "Docs"],
        "PostAction": "Quit",
        "Title": "Autopilot registration"
    }
'@

    $deploy = $OOBEDeployJson | ConvertFrom-Json -ErrorAction Stop
    $autopilot = $AutopilotOOBEJson | ConvertFrom-Json -ErrorAction Stop
    if ($autopilot.PostAction -ne 'Quit' -or $autopilot.Assign.IsPresent -or
        -not $autopilot.GroupTagOptions -or $autopilot.GroupTag -notin $autopilot.GroupTagOptions) {
        throw 'Invalid Autopilot settings: use Quit, Assign false and a default tag from GroupTagOptions.'
    }
    if (-not $deploy.RemoveAppx -or $deploy.Autopilot.IsPresent -or
        $deploy.UpdateWindows.IsPresent -or $deploy.UpdateDrivers.IsPresent) {
        throw 'Use the app allowlist with Autopilot and automatic updates disabled in OOBEDeploy.'
    }
    Write-Host ($Params | Out-String) -ForegroundColor Cyan
    Write-Host 'OSDCloud will erase and partition the VM target disk 0.' -ForegroundColor Yellow
    $Global:OSDCloud = $null
    Start-OSDCloud @Params
    if (-not $Global:OSDCloud.TimeEnd -or -not (Test-Path 'C:\Windows\System32\Config\SYSTEM')) {
        throw 'OSDCloud did not finish installing Windows. OOBE staging and reboot stopped.'
    }

    #================================================
    #   [PostOS] Stage JSON and the local OOBE command
    #================================================
    New-Item 'C:\ProgramData\OSDeploy' -ItemType Directory -Force | Out-Null
    $OOBEDeployJson | Out-File 'C:\ProgramData\OSDeploy\OSDeploy.OOBEDeploy.json' -Encoding utf8 -Force
    $AutopilotOOBEJson | Out-File 'C:\ProgramData\OSDeploy\OSDeploy.AutopilotOOBE.json' -Encoding utf8 -Force
    $OOBEScript = @'
# Run manually at Windows OOBE: Shift+F10, then OOBE.
$ErrorActionPreference = 'Stop'
try {
    if ($env:USERNAME -ne 'defaultuser0') { throw 'Run this at Windows OOBE as defaultuser0.' }
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $configPath = 'C:\ProgramData\OSDeploy'
    $autopilot = Get-Content "$configPath\OSDeploy.AutopilotOOBE.json" -Raw | ConvertFrom-Json
    $deploy = Get-Content "$configPath\OSDeploy.OOBEDeploy.json" -Raw | ConvertFrom-Json
    if ($autopilot.PostAction -ne 'Quit' -or $autopilot.Assign.IsPresent) {
        throw 'Use PostAction Quit and Assign false so registration can be checked before cleanup.'
    }
    Install-Module OSD -RequiredVersion '26.10.16.1' -Force -ErrorAction Stop
    Import-Module OSD -RequiredVersion '26.10.16.1' -Force -ErrorAction Stop
    Install-Module AutopilotOOBE -RequiredVersion '24.1.29.1' -Force -ErrorAction Stop
    Import-Module AutopilotOOBE -RequiredVersion '24.1.29.1' -Force -ErrorAction Stop
    Start-AutopilotOOBE

    # Check tenant state after the UI returns. This also permits an existing
    # registration with one of the configured tags; it does not prove a new import.
    Import-Module WindowsAutopilotIntune -ErrorAction Stop
    $serial = (Get-CimInstance Win32_BIOS).SerialNumber.Trim()
    if ([string]::IsNullOrWhiteSpace($serial)) { throw 'No device serial number was found.' }
    $registered = $false
    for ($attempt = 0; $attempt -lt 12; $attempt++) {
        $devices = @(Get-AutopilotDevice -serial $serial -ErrorAction Stop |
            Where-Object { $_.serialNumber -eq $serial })
        if ($devices.Count -eq 1 -and $devices[0].groupTag -in $autopilot.GroupTagOptions) {
            $registered = $true
            Write-Host "Autopilot registration found. Group Tag: $($devices[0].groupTag)" -ForegroundColor Green
            break
        }
        Start-Sleep -Seconds 10
    }
    if (-not $registered) { throw 'Autopilot serial/tag could not be verified. Cleanup and restart stopped.' }

    Start-OOBEDeploy
    # Confirm the requested packages are absent, including provisioned copies.
    $remaining = @(Get-AppxPackage -AllUsers -ErrorAction Stop |
        Where-Object { $_.Name -in $deploy.RemoveAppx })
    $remaining += @(Get-AppxProvisionedPackage -Online -ErrorAction Stop |
        Where-Object { $_.DisplayName -in $deploy.RemoveAppx })
    if ($remaining.Count) { throw 'Some allowlisted apps remain. Check OOBEDeploy logs before restarting.' }
    Restart-Computer -Force
}
catch {
    Write-Host "OOBE failed: $($_.Exception.Message)" -ForegroundColor Red
    Read-Host 'Press Enter to return to the command prompt'
    throw
}
'@
    $OOBEScript | Out-File 'C:\ProgramData\OSDeploy\OOBE.ps1' -Encoding utf8 -Force
    $OOBECmd = @'
@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\ProgramData\OSDeploy\OOBE.ps1
if errorlevel 1 pause
'@
    $OOBECmd | Out-File 'C:\Windows\System32\OOBE.cmd' -Encoding ascii -Force
    # Preserve the SetupComplete.cmd created by OSDCloud.
    New-Item 'C:\OSDCloud\Logs' -ItemType Directory -Force | Out-Null
    $Global:OSDCloud | Out-File 'C:\OSDCloud\Logs\OSDCloud_Variables.log' -Force
    Write-Host 'At Windows OOBE: Shift+F10, then run OOBE.' -ForegroundColor Cyan
    Start-Sleep -Seconds 20
    wpeutil reboot
    if ($LASTEXITCODE -ne 0) { throw 'WinPE reboot failed.' }
}

try {
    OSDCloudLogic
}
catch {
    Write-Host "Deployment stopped: $($_.Exception.Message)" -ForegroundColor Red
    Read-Host 'Press Enter after recording the error'
    throw
}
