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
