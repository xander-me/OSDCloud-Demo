# Host-side mock checks. No installation, network, real Appx or tenant calls.
$ErrorActionPreference='Stop'
Import-Module "$PSScriptRoot/../OSDCloudModules/Module.psm1" -Force
$passed=0
function Check($Name,[scriptblock]$Action) { & $Action; $script:passed++; Write-Host "PASS $Name" }
function MustThrow([scriptblock]$Action) {
    $failed=$false
    try { & $Action | Out-Null } catch { $failed=$true }
    if (-not $failed) { throw 'Expected a failure.' }
}
Check 'Readable settings select the agreed Windows and Group Tag' {
    $s=Get-DemoSettings
    if ($s.Windows.OSName -ne 'Windows 11 25H2 x64' -or $s.Windows.OSLanguage -ne 'en-us' -or $s.GroupTag -ne 'AutopilotOOBE') { throw 'Unexpected demo settings.' }
}
$global:DemoTestMachine=$null
function global:Get-CimInstance { param($ClassName,$ErrorAction); $global:DemoTestMachine }
Check 'Hyper-V is accepted' {
    $global:DemoTestMachine=[pscustomobject]@{Manufacturer='Microsoft Corporation';Model='Virtual Machine'}
    Assert-DemoVM
}
Check 'Proxmox Q35, i440FX and KVM identities are accepted' {
    foreach ($pair in @(
        @('QEMU','Standard PC (Q35 + ICH9, 2009)'),
        @('QEMU','Standard PC (i440FX + PIIX, 1996)'),
        @('QEMU','KVM'),
        @('Red Hat','KVM'),
        @('KVM','KVM')
    )) {
        $global:DemoTestMachine=[pscustomobject]@{Manufacturer=$pair[0];Model=$pair[1]}
        Assert-DemoVM
    }
}
Check 'Physical, unknown and partial VM identities remain rejected' {
    foreach ($pair in @(
        @('Dell Inc.','OptiPlex'),
        @('Microsoft Corporation','Surface Pro'),
        @('QEMU','Unrecognized model'),
        @('Other','KVM'),
        @('','')
    )) {
        $global:DemoTestMachine=[pscustomobject]@{Manufacturer=$pair[0];Model=$pair[1]}
        MustThrow { Assert-DemoVM }
    }
}
Check 'Both platforms still reject missing, nonblank or multiple disks before module loading' {
    function global:Test-Path { param($Path); if ($Path -eq 'HKLM:\SYSTEM\CurrentControlSet\Control\MiniNT') { return $true }; throw 'Unexpected filesystem access after disk guard.' }
    function global:Get-Disk { $global:DemoTestDisks }
    $previous=$env:SystemDrive
    try {
        $env:SystemDrive='X:'
        foreach ($machine in @(
            [pscustomobject]@{Manufacturer='Microsoft Corporation';Model='Virtual Machine'},
            [pscustomobject]@{Manufacturer='QEMU';Model='Standard PC (Q35 + ICH9, 2009)'}
        )) {
            $global:DemoTestMachine=$machine
            foreach ($case in @(
                @{Disks=@()},
                @{Disks=@([pscustomobject]@{Number=0;PartitionStyle='GPT';BusType='SCSI'})},
                @{Disks=@([pscustomobject]@{Number=1;PartitionStyle='RAW';BusType='SCSI'})},
                @{Disks=@([pscustomobject]@{Number=0;PartitionStyle='RAW';BusType='SCSI'},[pscustomobject]@{Number=1;PartitionStyle='RAW';BusType='SCSI'})}
            )) {
                $global:DemoTestDisks=$case.Disks
                $failure=''
                try { Start-DemoInstallation -BundlePath $PSScriptRoot } catch { $failure=$_.Exception.Message }
                if ($failure -ne 'Exactly one blank virtual disk numbered 0 is required.') { throw "Disk guard did not stop at the expected boundary: $failure" }
            }
        }
    } finally {
        $env:SystemDrive=$previous
        Remove-Item Function:global:Test-Path,Function:global:Get-Disk
    }
}
$global:DemoTestDevices=@()
function global:Get-AutopilotDevice { param($serial,$ErrorAction); $global:DemoTestDevices }
Check 'Registration is accepted only for matching serial and Group Tag' {
    $global:DemoTestDevices=@([pscustomobject]@{serialNumber='TEST-VM';groupTag='AutopilotOOBE'})
    $result=Confirm-DemoRegistration -Serial TEST-VM -GroupTag AutopilotOOBE -Attempts 1 -DelaySeconds 0
    if ($result.serialNumber -ne 'TEST-VM') { throw 'Wrong device accepted.' }
    foreach ($devices in @(
        @(),
        @([pscustomobject]@{serialNumber='OTHER';groupTag='AutopilotOOBE'}),
        @([pscustomobject]@{serialNumber='TEST-VM';groupTag='WRONG'})
    )) {
        $global:DemoTestDevices=$devices
        MustThrow { Confirm-DemoRegistration -Serial TEST-VM -GroupTag AutopilotOOBE -Attempts 1 -DelaySeconds 0 }
    }
}
$global:DemoTestProvisioned=@(); $global:DemoTestInstalled=@(); $global:DemoTestRemoved=@()
function global:Get-AppxProvisionedPackage { param([switch]$Online); $global:DemoTestProvisioned }
function global:Get-AppxPackage { param([switch]$AllUsers); $global:DemoTestInstalled }
function global:Remove-AppxProvisionedPackage {
    param([switch]$Online,$PackageName,[switch]$AllUsers,$ErrorAction)
    $global:DemoTestRemoved += $PackageName
    $global:DemoTestProvisioned=@($global:DemoTestProvisioned | Where-Object { $_.PackageName -ne $PackageName })
}
function global:Remove-AppxPackage {
    param($Package,[switch]$AllUsers,$ErrorAction)
    $global:DemoTestRemoved += $Package
    $global:DemoTestInstalled=@($global:DemoTestInstalled | Where-Object { $_.PackageFullName -ne $Package })
}
Check 'Cleanup removes only exact listed apps, with a safe rerun' {
    $global:DemoTestProvisioned=@(
        [pscustomobject]@{DisplayName='Microsoft.BingNews';PackageName='News'},
        [pscustomobject]@{DisplayName='Microsoft.BingNews.Extra';PackageName='Unrelated'}
    )
    $global:DemoTestInstalled=@(
        [pscustomobject]@{Name='Microsoft.BingNews';PackageFullName='InstalledNews';NonRemovable=$false},
        [pscustomobject]@{Name='Microsoft.WindowsStore';PackageFullName='Store';NonRemovable=$false}
    )
    Remove-DemoApps -Names Microsoft.BingNews
    Remove-DemoApps -Names Microsoft.BingNews
    if ($global:DemoTestRemoved.Count -ne 2 -or 'Store' -in $global:DemoTestRemoved -or 'Unrelated' -in $global:DemoTestRemoved) { throw 'Cleanup escaped its allowlist.' }
}
Check 'A protected app prevents removal' {
    $global:DemoTestInstalled=@([pscustomobject]@{Name='Microsoft.BingNews';PackageFullName='Protected';NonRemovable=$true})
    $before=$global:DemoTestRemoved.Count
    MustThrow { Remove-DemoApps -Names Microsoft.BingNews }
    if ($global:DemoTestRemoved.Count -ne $before) { throw 'Removal occurred despite a protected app.' }
}
Check 'Installation refuses a normal OS session before loading OSD' {
    $previous=$env:SystemDrive
    try { $env:SystemDrive='C:'; MustThrow { Start-DemoInstallation -BundlePath $PSScriptRoot } }
    finally { $env:SystemDrive=$previous }
}
Get-ChildItem (Join-Path $PSScriptRoot '..') -Recurse -Include *.ps1,*.psm1 | ForEach-Object {
    $tokens=$null; $errors=$null
    $null=[System.Management.Automation.Language.Parser]::ParseFile($_.FullName,[ref]$tokens,[ref]$errors)
    if ($errors) { throw ($errors | Out-String) }
}
Write-Host "$passed host-side test groups and all script syntax checks passed. Windows/Hyper-V/Proxmox/Graph runtime remains untested."
