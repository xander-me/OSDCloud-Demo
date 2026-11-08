# Edit the demo settings here.
function Get-DemoSettings {
    [pscustomobject]@{
        Windows = @{
            OSName       = 'Windows 11 25H2 x64'
            OSEdition    = 'Pro'
            OSLanguage   = 'en-us'                 # English (United States)
            OSActivation = 'Retail'
        }
        RemoveApps = @(
            'Microsoft.MicrosoftSolitaireCollection'  # Solitaire
            'Microsoft.BingNews'                      # News
            'Clipchamp.Clipchamp'                     # Clipchamp
        )
        OSDVersion = '26.10.16.1'
        AutopilotScriptVersion = '3.9'
    }
}

# Supporting functions. These do not run when the module is imported.
function Assert-DemoVM {
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
}

function Start-DemoInstallation {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$BundlePath)
    $ErrorActionPreference = 'Stop'
    if ($env:SystemDrive -ne 'X:' -or -not (Test-Path 'HKLM:\SYSTEM\CurrentControlSet\Control\MiniNT')) { throw 'Start installation from WinPE.' }
    Assert-DemoVM
    $disks = @(Get-Disk | Where-Object { $_.BusType -ne 'USB' })
    if ($disks.Count -ne 1 -or $disks[0].Number -ne 0 -or $disks[0].PartitionStyle -ne 'RAW') { throw 'Exactly one blank virtual disk numbered 0 is required.' }
    foreach ($file in 'OOBE.ps1','OSDCloudModules/Module.psm1','revision.txt') {
        if (-not (Test-Path (Join-Path $BundlePath $file) -PathType Leaf)) { throw "Missing demo file: $file" }
    }
    $settings = Get-DemoSettings
    $settings.Windows | Format-Table -AutoSize | Out-Host
    Write-Host 'Autopilot Group Tag will be entered at Windows OOBE.'
    Write-Host 'Installing on the sole blank virtual disk 0.'
    if (-not (Get-Module OSD -ListAvailable | Where-Object { $_.Version -eq [version]$settings.OSDVersion })) {
        Install-Module OSD -RequiredVersion $settings.OSDVersion -Scope AllUsers -Force -ErrorAction Stop
    }
    Import-Module OSD -RequiredVersion $settings.OSDVersion -Force -ErrorAction Stop
    $global:MyOSDCloud = @{ SetupCompleteNoRestart=$true; ShutdownSetupComplete=$false; WindowsUpdate=$false; WindowsUpdateDrivers=$false; WindowsDefenderUpdate=$false }
    $windows = $settings.Windows
    Start-OSDCloudCLI @windows -SkipAutopilot -ZTI -Restart:$false -Shutdown:$false
    if (-not $global:OSDCloud.TimeEnd -or -not (Test-Path 'C:\Windows\System32\Config\SYSTEM')) { throw 'OSDCloud did not report a completed Windows deployment.' }
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
    Write-Host 'Windows installed. At OOBE press Shift+F10 and run OOBE to register this demo VM.'
    & wpeutil.exe reboot
    if ($LASTEXITCODE -ne 0) { throw 'WinPE reboot failed.' }
}

function Read-DemoGroupTag {
    $groupTag = ([string](Read-Host 'Enter the Autopilot Group Tag')).Trim()
    if ([string]::IsNullOrWhiteSpace($groupTag) -or $groupTag -match '[\x00-\x1f\x7f]') {
        throw 'Enter a non-empty Group Tag without control characters. No registration was started.'
    }
    return $groupTag
}

function Confirm-DemoRegistration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Serial,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$GroupTag,
        [ValidateRange(1,12)][int]$Attempts=12,
        [ValidateRange(0,10)][int]$DelaySeconds=10
    )
    for ($attempt=0; $attempt -lt $Attempts; $attempt++) {
        $registered = @(Get-AutopilotDevice -serial $Serial -ErrorAction Stop | Where-Object { $_.serialNumber -eq $Serial -and $_.groupTag -eq $GroupTag })
        if ($registered.Count -eq 1) { return $registered[0] }
        if ($attempt -lt $Attempts - 1) { Start-Sleep -Seconds $DelaySeconds }
    }
    throw 'Autopilot serial and Group Tag could not be verified. Stop before app removal or restart.'
}

function Remove-DemoApps {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string[]]$Names)
    $ErrorActionPreference = 'Stop'
    $installed = @(Get-AppxPackage -AllUsers | Where-Object { $_.Name -cin $Names })
    if (@($installed | Where-Object { $_.NonRemovable -eq $true }).Count) { throw 'An allowlisted app is marked NonRemovable. Review the app list.' }
    Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -cin $Names } | ForEach-Object {
        Write-Host "Removing provisioned app: $($_.DisplayName)"
        Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -AllUsers -ErrorAction Stop | Out-Null
    }
    Get-AppxPackage -AllUsers | Where-Object { $_.Name -cin $Names } | ForEach-Object {
        Write-Host "Removing installed app: $($_.Name)"
        Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction Stop
    }
    $remaining = @(Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -cin $Names })
    $remaining += @(Get-AppxPackage -AllUsers | Where-Object { $_.Name -cin $Names })
    if ($remaining.Count) { throw 'Some allowlisted apps remain. Do not mark cleanup complete.' }
    Write-Host 'App cleanup verified. Apps absent from the allowlist were not selected for removal.'
}

Export-ModuleMember -Function Get-DemoSettings,Assert-DemoVM,Start-DemoInstallation,Read-DemoGroupTag,Confirm-DemoRegistration,Remove-DemoApps
