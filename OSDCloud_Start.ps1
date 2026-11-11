# Run in OSDCloud WinPE, locally or using this script's GitHub Raw URL.
# WARNING: Installation starts automatically and erases the target disk.

$ErrorActionPreference = 'Stop'

# 1. Windows settings - edit these in GitHub.
$OSDVersion = '26.10.16.1'
$WindowsSettings = @{
    OSName        = 'Windows 11 25H2 x64'
    OSEdition     = 'Enterprise'
    OSLanguage    = 'en-us'
    OSActivation  = 'Volume'
    ZTI           = $true       # Start without installation questions.
    SkipAutopilot = $true
    SkipODT       = $true
    Restart       = $false      # Leave the result on screen for the demo.
}

# 2. Load OSD. Install missing prerequisites without confirmation prompts.
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

if (-not (Get-Module OSD -ListAvailable | Where-Object Version -EQ $OSDVersion)) {
    Install-PackageProvider -Name NuGet -MinimumVersion '2.8.5.201' -Force -Confirm:$false | Out-Null
    Install-Module OSD -RequiredVersion $OSDVersion -Scope AllUsers -Force -AllowClobber -Confirm:$false
}

Import-Module OSD -RequiredVersion $OSDVersion -Force

# 3. Clear settings from earlier runs, then start the normal OSDCloud workflow.
$Global:StartOSDCloudGUI = $null
$Global:MyOSDCloud = @{}

Write-Host 'Starting Windows 11 25H2 Enterprise (en-us)' -ForegroundColor Cyan
Start-OSDCloud @WindowsSettings
