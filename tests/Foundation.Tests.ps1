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
Write-Host "$passed host-side test groups and all script syntax checks passed. Windows/Hyper-V/Graph remain untested."
