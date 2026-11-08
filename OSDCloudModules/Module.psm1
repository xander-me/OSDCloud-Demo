# Edit the demo settings here.
function Get-DemoSettings {
    [pscustomobject]@{
        # Exact app names from the supplied demo list; missing apps are ignored.
        RemoveApps = @(
            'Microsoft.549981C3F5F10'
            'Microsoft.BingWeather'
            'Microsoft.GetHelp'
            'Microsoft.Getstarted'
            'Microsoft.Microsoft3DViewer'
            'Microsoft.MicrosoftOfficeHub'
            'Microsoft.MicrosoftSolitaireCollection'
            'Microsoft.MixedReality.Portal'
            'Microsoft.Office.OneNote'
            'Microsoft.People'
            'Microsoft.SkypeApp'
            'Microsoft.Wallet'
            'Microsoft.WindowsCamera'
            'microsoft.windowscommunicationsapps'
            'Microsoft.WindowsFeedbackHub'
            'Microsoft.WindowsMaps'
            'Microsoft.Xbox.TCUI'
            'Microsoft.XboxApp'
            'Microsoft.XboxGameOverlay'
            'Microsoft.XboxGamingOverlay'
            'Microsoft.XboxIdentityProvider'
            'Microsoft.XboxSpeechToTextOverlay'
            'Microsoft.YourPhone'
            'Microsoft.ZuneMusic'
            'Microsoft.ZuneVideo'
        )
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

# PreOS -> Windows -> stage OOBE -> reboot.
# No ComputerPrefix: the Group Tag is entered later in Windows OOBE.

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
    $installed = @(Get-AppxPackage -AllUsers | Where-Object { $_.Name -in $Names })
    if (@($installed | Where-Object { $_.NonRemovable -eq $true }).Count) { throw 'An allowlisted app is marked NonRemovable. Review the app list.' }
    Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -in $Names } | ForEach-Object {
        Write-Host "Removing provisioned app: $($_.DisplayName)"
        Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -AllUsers -ErrorAction Stop | Out-Null
    }
    Get-AppxPackage -AllUsers | Where-Object { $_.Name -in $Names } | ForEach-Object {
        Write-Host "Removing installed app: $($_.Name)"
        Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction Stop
    }
    $remaining = @(Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -in $Names })
    $remaining += @(Get-AppxPackage -AllUsers | Where-Object { $_.Name -in $Names })
    if ($remaining.Count) { throw 'Some allowlisted apps remain. Do not mark cleanup complete.' }
    Write-Host 'App cleanup verified. Apps absent from the allowlist were not selected for removal.'
}

# OOBE helpers only. Installation lives in OSDCloud_Start.ps1.
Export-ModuleMember -Function Get-DemoSettings,Assert-DemoVM,Read-DemoGroupTag,Confirm-DemoRegistration,Remove-DemoApps
