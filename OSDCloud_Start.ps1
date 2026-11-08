# Single-file installation function. Windows settings are in the [OS] section below.
function OSDCloudLogic {
    [CmdletBinding()]
    param()
    $ErrorActionPreference = 'Stop'
    if ($env:SystemDrive -ne 'X:' -or -not (Test-Path 'HKLM:\SYSTEM\CurrentControlSet\Control\MiniNT')) { throw 'Start installation from WinPE.' }
    $machine = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
    $manufacturer = ([string]$machine.Manufacturer).Trim()
    $model = ([string]$machine.Model).Trim()
    $hyperV = $manufacturer -ieq 'Microsoft Corporation' -and $model -ieq 'Virtual Machine'
    # Proxmox uses QEMU/KVM. Match known manufacturer/model pairs, not any virtual-looking name.
    $qemu = $manufacturer -ieq 'QEMU' -and $model -iin @(
        'Standard PC (Q35 + ICH9, 2009)',
        'Standard PC (i440FX + PIIX, 1996)',
        'KVM'
    )
    $kvm = $manufacturer -iin @('Red Hat','KVM') -and $model -ieq 'KVM'
    if (-not ($hyperV -or $qemu -or $kvm)) {
        throw "A dedicated Hyper-V or Proxmox/QEMU/KVM VM is required. Detected manufacturer='$manufacturer', model='$model'. Custom SMBIOS identities require review."
    }
    Write-Host "Demo VM recognized: $manufacturer / $model"
    $disks = @(Get-Disk | Where-Object { $_.BusType -ne 'USB' })
    if ($disks.Count -ne 1 -or $disks[0].Number -ne 0) { throw 'Exactly one local virtual disk numbered 0 is required.' }
    #================================================
    #   [PreOS] Demo files and OSD module
    #================================================
    # Download OOBE helpers before any disk change. The install function stays in THIS file.
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    $repository = 'xander-me/OSDCloud-Demo'
    Write-Host -ForegroundColor Cyan 'Downloading the OOBE helpers'
    $headers = @{ 'User-Agent'='OSDCloud-Demo'; 'Cache-Control'='no-cache' }
    $commit = (Invoke-RestMethod "https://api.github.com/repos/$repository/commits/main" -Headers $headers -TimeoutSec 20 -ErrorAction Stop).sha
    if ($commit -cnotmatch '^[a-f0-9]{40}$') { throw 'Invalid demo revision.' }
    $BundlePath = Join-Path $env:TEMP ('OSDCloud-Demo-' + [guid]::NewGuid().ToString('N'))
    New-Item "$BundlePath\OSDCloudModules" -ItemType Directory -Force | Out-Null
    foreach ($file in 'OOBE.ps1','OSDCloudModules/Module.psm1') {
        Invoke-WebRequest -UseBasicParsing -Uri "https://raw.githubusercontent.com/$repository/$commit/$file" -OutFile (Join-Path $BundlePath $file) -TimeoutSec 30 -ErrorAction Stop
    }
    $commit | Set-Content "$BundlePath\revision.txt" -Encoding ASCII
    Write-Host "OOBE helper revision: $commit"
    $OSDVersion = '26.10.16.1'
    Write-Host -ForegroundColor Cyan "Loading OSD $OSDVersion"
    if (-not (Get-Module OSD -ListAvailable | Where-Object { $_.Version -eq [version]$OSDVersion })) {
        Install-Module OSD -RequiredVersion $OSDVersion -Scope AllUsers -Force -ErrorAction Stop
    }
    Import-Module OSD -RequiredVersion $OSDVersion -Force -ErrorAction Stop

    #================================================
    #   [OS] Windows settings -- edit these values
    #================================================
    $Params = @{
        OSName       = 'Windows 11 25H2 x64'
        OSEdition    = 'Pro'
        OSLanguage   = 'da-dk'
        OSActivation = 'Retail'
    }
    $Params | Format-Table -AutoSize | Out-Host
    Write-Host 'OSDCloud will wipe and repartition virtual disk 0. Existing data will be erased.'
    # This demo accepts VMs only. No OEM driver-pack download or firmware update.
    $global:MyOSDCloud = @{
        # Use OSDCloud's own wipe and partitioning steps, including on an existing Windows disk.
        SkipAllDiskSteps = $false
        SkipClearDisk = $false
        SkipNewOSDisk = $false
        DriverPackName = 'none'
        SkipRecoveryPartition = $true
        SetupCompleteNoRestart = $true
        ShutdownSetupComplete = $false
        WindowsUpdate = $false
        WindowsUpdateDrivers = $false
        WindowsDefenderUpdate = $false
    }
    Start-OSDCloud @Params -SkipAutopilot -ZTI -Restart:$false -Shutdown:$false
    if (-not $global:OSDCloud.TimeEnd -or -not (Test-Path 'C:\Windows\System32\Config\SYSTEM')) { throw 'OSDCloud did not report a completed Windows deployment.' }
    #================================================
    #   [PostOS] Stage local OOBE scripts
    #================================================
    $destination = 'C:\ProgramData\OSDCloud-Demo'
    New-Item "$destination\OSDCloudModules" -ItemType Directory -Force | Out-Null
    foreach ($file in 'OOBE.ps1','OSDCloudModules/Module.psm1','revision.txt') {
        $source = Join-Path $BundlePath $file
        $target = Join-Path $destination $file
        Copy-Item -LiteralPath $source -Destination $target -Force -ErrorAction Stop
        if ((Get-FileHash $source -Algorithm SHA256).Hash -ne (Get-FileHash $target -Algorithm SHA256).Hash) { throw "Staging verification failed: $file" }
    }
    @'
@echo off
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File C:\ProgramData\OSDCloud-Demo\OOBE.ps1
if errorlevel 1 (
    echo DEMO STOPPED. Review C:\ProgramData\OSDCloud-Demo\OOBE.log
    exit /b 1
)
'@ | Set-Content 'C:\Windows\System32\OOBE.cmd' -Encoding ASCII
    # [PostOS] OSDCloud completed; boot Windows. OOBE registration runs later.
    Write-Host 'Windows installed. At OOBE press Shift+F10 and run OOBE to register this demo VM.'
    & wpeutil.exe reboot
    if ($LASTEXITCODE -ne 0) { throw 'WinPE reboot failed.' }
}


# Defining OSDCloudLogic does not run it. This call starts the installation.
$ErrorActionPreference = 'Stop'
$log = Join-Path $env:TEMP 'OSDCloud-Demo-Startup.log'
$transcribing = $false
try {
    try {
        Start-Transcript -Path $log -Append -ErrorAction Stop | Out-Null
        $transcribing = $true
    } catch { Write-Warning "Cannot start transcript: $($_.Exception.Message)" }
    OSDCloudLogic
    $null = Read-Host 'The function returned. Press Enter after reviewing its output'
} catch {
    Write-Host -ForegroundColor Red "OSDCloud stopped: $($_.Exception.Message)"
    Write-Host $_.InvocationInfo.PositionMessage
    Write-Host "Startup log: $log"
    $null = Read-Host 'Record the error above, then press Enter'
    throw
} finally {
    if ($transcribing) { Stop-Transcript | Out-Null }
}
