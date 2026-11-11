# Run in OSDCloud WinPE: .\Start-TechDayOSDCloud.ps1
# Store this script in GitHub and run it using its Raw URL.

$ErrorActionPreference = 'Stop'

# 1. Demo settings - change these in GitHub before running the script again.
$DemoTitle = 'Tech Day - Config from GitHub - v1'
$DemoColor = '#0078D4'
$OSDVersion = '26.10.16.1'

$WindowsSettings = @{
    Name       = 'Windows 11 25H2 x64'
    Version    = 'Windows 11'
    ReleaseID  = '25H2'
    Edition    = 'Enterprise'
    Language   = 'en-us'
    Activation = 'Volume'
    ImageIndex = 0
}

# 2. Load OSD. Download it only if this version is missing from WinPE.
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

if (-not (Get-Module OSD -ListAvailable | Where-Object Version -EQ $OSDVersion)) {
    Install-Module OSD -RequiredVersion $OSDVersion -Force
}

Import-Module OSD -RequiredVersion $OSDVersion -Force

# 3. Apply the Windows defaults used by the native OSDCloud GUI.
$Global:OSDModuleResource.OSDCloud.Default = $WindowsSettings
$Global:OSDModuleResource.StartOSDCloudGUI.ClearDiskConfirm = $true
$Global:OSDModuleResource.StartOSDCloudGUI.restartComputer = $false

# 4. Open the GUI. For the demo, show the choices and then close it.
# Starting an installation in the GUI can erase the selected disk.
Write-Host $DemoTitle -ForegroundColor Cyan
Start-OSDCloudGUI -BrandName $DemoTitle -BrandColor $DemoColor
