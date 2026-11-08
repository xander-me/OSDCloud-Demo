# Host-side mock checks. No installation, network, real Appx or tenant calls.
$ErrorActionPreference='Stop'
Import-Module "$PSScriptRoot/../OSDCloudModules/Module.psm1" -Force
# Load only the inline definition, never the real startup invocation.
$tokens=$null; $parseErrors=$null
$ast=[System.Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot '../OSDCloud_Start.ps1'),[ref]$tokens,[ref]$parseErrors)
$definition=$ast.Find({param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'OSDCloudLogic'},$false)
. ([scriptblock]::Create($definition.Extent.Text))
$passed=0
function Check($Name,[scriptblock]$Action) { & $Action; $script:passed++; Write-Host "PASS $Name" }
function MustThrow([scriptblock]$Action) {
    $failed=$false
    try { & $Action | Out-Null } catch { $failed=$true }
    if (-not $failed) { throw 'Expected a failure.' }
}
Check 'OOBE settings keep the supplied app list and no fixed Group Tag' {
    $s=Get-DemoSettings
    if ($s.PSObject.Properties.Name -contains 'GroupTag' -or $s.RemoveApps.Count -ne 25 -or 'Microsoft.WindowsCamera' -notin $s.RemoveApps) { throw 'Unexpected OOBE settings.' }
}
$global:DemoTestGroupTag=''
function global:Read-Host { param($Prompt); $global:DemoTestGroupTag }
Check 'OOBE accepts and trims the chosen Group Tag' {
    $global:DemoTestGroupTag='  Site-Copenhagen  '
    if ((Read-DemoGroupTag) -cne 'Site-Copenhagen') { throw 'Entered tag changed.' }
}
Check 'OOBE refuses blank tags and control characters' {
    foreach ($value in @('', '   ', "Bad`nTag", "Bad`tTag")) {
        $global:DemoTestGroupTag=$value
        MustThrow { Read-DemoGroupTag }
    }
}
Remove-Item Function:global:Read-Host
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
Check 'Both platforms reject missing, multiple or differently numbered target disks' {
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
                @{Disks=@([pscustomobject]@{Number=1;PartitionStyle='RAW';BusType='SCSI'})},
                @{Disks=@([pscustomobject]@{Number=0;PartitionStyle='RAW';BusType='SCSI'},[pscustomobject]@{Number=1;PartitionStyle='RAW';BusType='SCSI'})}
            )) {
                $global:DemoTestDisks=$case.Disks
                $failure=''
                try { OSDCloudLogic } catch { $failure=$_.Exception.Message }
                if ($failure -ne 'Exactly one local virtual disk numbered 0 is required.') { throw "Disk guard did not stop at the expected boundary: $failure" }
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
    $global:DemoTestDevices=@([pscustomobject]@{serialNumber='TEST-VM';groupTag='Site-Copenhagen'})
    $result=Confirm-DemoRegistration -Serial TEST-VM -GroupTag Site-Copenhagen -Attempts 1 -DelaySeconds 0
    if ($result.serialNumber -ne 'TEST-VM') { throw 'Wrong device accepted.' }
    foreach ($devices in @(
        @(),
        @([pscustomobject]@{serialNumber='OTHER';groupTag='Site-Copenhagen'}),
        @([pscustomobject]@{serialNumber='TEST-VM';groupTag='WRONG'})
    )) {
        $global:DemoTestDevices=$devices
        MustThrow { Confirm-DemoRegistration -Serial TEST-VM -GroupTag Site-Copenhagen -Attempts 1 -DelaySeconds 0 }
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
        [pscustomobject]@{DisplayName='microsoft.bingnews';PackageName='News'},
        [pscustomobject]@{DisplayName='Microsoft.BingNews.Extra';PackageName='Unrelated'}
    )
    $global:DemoTestInstalled=@(
        [pscustomobject]@{Name='microsoft.bingnews';PackageFullName='InstalledNews';NonRemovable=$false},
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
Check 'RAW, GPT and MBR targets reach the mocked engine with OSDCloud native wipe enabled' {
    $global:DemoTestMachine=[pscustomobject]@{Manufacturer='QEMU';Model='Standard PC (Q35 + ICH9, 2009)'}
    function global:Test-Path { param($Path,$PathType); return $true }
    function global:Get-Disk { [pscustomobject]@{Number=0;PartitionStyle=$global:DemoTestPartitionStyle;BusType='SCSI'} }
    function global:Get-Module { param($Name,[switch]$ListAvailable); [pscustomobject]@{Version=[version]'26.10.16.1'} }
    function global:Import-Module { param($Name,$RequiredVersion,[switch]$Force,$ErrorAction) }
    function global:Start-OSDCloud {
        param($OSName,$OSEdition,$OSLanguage,$OSActivation,[switch]$SkipAutopilot,[switch]$ZTI,[switch]$Restart,[switch]$Shutdown)
        $global:DemoTestWindowsArguments=@{} + $PSBoundParameters
        throw 'TEST: stop before any deployment operation'
    }
    function global:Invoke-RestMethod { param($Uri,$Headers,$TimeoutSec,$ErrorAction); [pscustomobject]@{sha=('a'*40)} }
    function global:Invoke-WebRequest { param([switch]$UseBasicParsing,$Uri,$OutFile,$TimeoutSec,$ErrorAction) }
    function global:New-Item { param($Path,$ItemType,[switch]$Force) }
    function global:Set-Content { param($Path,$Value,$Encoding) }
    $previousTemp=$env:TEMP; $env:TEMP=[IO.Path]::GetTempPath()
    $previousDrive=$env:SystemDrive
    $previousOverrides=Get-Variable MyOSDCloud -Scope Global -ErrorAction SilentlyContinue
    try {
        $env:SystemDrive='X:'
        foreach ($style in 'RAW','GPT','MBR') {
            $global:DemoTestPartitionStyle=$style
            $failure=''
            try { OSDCloudLogic } catch { $failure=$_.Exception.Message }
            if ($failure -ne 'TEST: stop before any deployment operation') { throw "Mock engine not reached: $failure" }
            $args=$global:DemoTestWindowsArguments
            if ($args.OSName -ne 'Windows 11 25H2 x64' -or $args.OSLanguage -ne 'da-dk' -or $args.OSEdition -ne 'Pro' -or $args.OSActivation -ne 'Retail' -or -not $args.ZTI -or -not $args.SkipAutopilot -or $args.Restart -or $args.Shutdown) { throw 'Incorrect Windows engine parameters.' }
            if ($global:MyOSDCloud.DriverPackName -ne 'none' -or -not $global:MyOSDCloud.SkipRecoveryPartition) { throw 'VM settings not applied.' }
            foreach ($name in 'SkipAllDiskSteps','SkipClearDisk','SkipNewOSDisk') {
                if ($global:MyOSDCloud[$name] -ne $false) { throw "OSDCloud native disk step disabled: $name" }
            }
        }
    } finally {
        $env:SystemDrive=$previousDrive; $env:TEMP=$previousTemp
        if ($previousOverrides) { $global:MyOSDCloud=$previousOverrides.Value } else { Remove-Variable MyOSDCloud -Scope Global -ErrorAction SilentlyContinue }
        Remove-Item Function:global:Test-Path,Function:global:Get-Disk,Function:global:Get-Module,Function:global:Import-Module,Function:global:Start-OSDCloud,Function:global:Invoke-RestMethod,Function:global:Invoke-WebRequest,Function:global:New-Item,Function:global:Set-Content
    }
}
Check 'Installation refuses a normal OS session before loading OSD' {
    $previous=$env:SystemDrive
    try { $env:SystemDrive='C:'; MustThrow { OSDCloudLogic } }
    finally { $env:SystemDrive=$previous }
}
Get-ChildItem (Join-Path $PSScriptRoot '..') -Recurse -Include *.ps1,*.psm1 | ForEach-Object {
    $tokens=$null; $errors=$null
    $null=[System.Management.Automation.Language.Parser]::ParseFile($_.FullName,[ref]$tokens,[ref]$errors)
    if ($errors) { throw ($errors | Out-String) }
}
Write-Host "$passed host-side test groups and all script syntax checks passed. Windows/Hyper-V/Proxmox/Graph runtime remains untested."
