# Run at Windows OOBE using Shift+F10 -> OOBE.
# Registration uses Graph, with interactive administrator sign-in. No JSON registration.
$ErrorActionPreference = 'Stop'
if ($env:SystemDrive -eq 'X:') { throw 'Autopilot registration runs in installed Windows, not WinPE.' }
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'An elevated OOBE session is required.' }
Import-Module "$PSScriptRoot\OSDCloudModules\Module.psm1" -Force -ErrorAction Stop
Assert-DemoVM
$settings = Get-DemoSettings
$success = Join-Path $PSScriptRoot 'Completed.txt'
if (Test-Path $success) { throw 'This demo already completed. Review the log before rerunning registration.' }
Start-Transcript -Path "$PSScriptRoot\OOBE.log" -Append -ErrorAction Stop | Out-Null
try {
    Write-Host "Demo revision: $(Get-Content "$PSScriptRoot\revision.txt" -Raw)"
    $groupTag = Read-DemoGroupTag
    Write-Host "Sign in to the DEMO tenant. Group Tag: $groupTag"
    Install-Script Get-WindowsAutopilotInfo -RequiredVersion $settings.AutopilotScriptVersion -Scope AllUsers -Force -ErrorAction Stop
    $installed = Get-InstalledScript Get-WindowsAutopilotInfo -RequiredVersion $settings.AutopilotScriptVersion -ErrorAction Stop
    $scriptPath = Join-Path $installed.InstalledLocation 'Get-WindowsAutopilotInfo.ps1'
    & $scriptPath -Online -GroupTag $groupTag

    # Do not treat closing a window or returning from the script as proof of registration.
    $serial = (Get-CimInstance Win32_BIOS -ErrorAction Stop).SerialNumber
    if ([string]::IsNullOrWhiteSpace($serial)) { throw 'Device serial is unavailable.' }
    $null = Get-Command Get-AutopilotDevice -ErrorAction Stop
    $null = Confirm-DemoRegistration -Serial $serial -GroupTag $groupTag
    Write-Host "Autopilot registration verified: $serial / $groupTag"
    Remove-DemoApps -Names $settings.RemoveApps
    "Completed $(Get-Date -Format o). Registration verified with Group Tag $groupTag; allowlisted apps absent." | Set-Content $success -Encoding UTF8
    Write-Host 'DEMO complete. Restarting to OOBE in 10 seconds.'
    Start-Sleep -Seconds 10
} catch {
    Write-Error "DEMO STOPPED: $($_.Exception.Message)" -ErrorAction Continue
    exit 1
} finally {
    Stop-Transcript | Out-Null
}
Restart-Computer -Force
