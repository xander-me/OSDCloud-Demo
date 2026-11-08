# One URL starts the demo automatically from WinPE; VM and blank-disk checks remain.
[CmdletBinding()]
param([string]$Revision = 'main')
$ErrorActionPreference = 'Stop'
$log = Join-Path $env:TEMP 'OSDCloud-Demo-Startup.log'
$transcribing = $false
try {
    try {
        Start-Transcript -Path $log -Append -ErrorAction Stop | Out-Null
        $transcribing = $true
    } catch { Write-Warning "Cannot start transcript: $($_.Exception.Message)" }
    if ($env:SystemDrive -ne 'X:') { throw 'Run this startup script from WinPE.' }
    Write-Host 'Starting Windows 11 25H2 x64 / Dansk / Pro automatically.'

    # Windows PowerShell/WinPE may otherwise negotiate an older TLS version.
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    $repository = 'xander-me/OSDCloud-Demo'
    $headers = @{ 'User-Agent'='OSDCloud-Demo'; 'Cache-Control'='no-cache' }
    Write-Host '[1/4] Connecting to GitHub and resolving the demo revision...'
    $commit = (Invoke-RestMethod "https://api.github.com/repos/$repository/commits/$([uri]::EscapeDataString($Revision))" -Headers $headers -TimeoutSec 20 -ErrorAction Stop).sha
    if ($commit -cnotmatch '^[a-f0-9]{40}$') { throw 'GitHub returned an invalid source revision.' }
    Write-Host "Demo source revision: $commit"
    $bundle = Join-Path $env:TEMP ('OSDCloud-Demo-' + [guid]::NewGuid().ToString('N'))
    New-Item "$bundle\OSDCloudModules" -ItemType Directory -Force | Out-Null
    Write-Host '[2/4] Downloading the demo files...'
    foreach ($file in 'OSDCloudModules/Module.psm1','OOBE.ps1') {
        Write-Host "Downloading $file"
        Invoke-WebRequest -UseBasicParsing -Uri "https://raw.githubusercontent.com/$repository/$commit/$file" -OutFile (Join-Path $bundle $file) -TimeoutSec 30 -ErrorAction Stop
    }
    $commit | Set-Content "$bundle\revision.txt" -Encoding ASCII
    Write-Host '[3/4] Loading the demo module...'
    Import-Module "$bundle\OSDCloudModules\Module.psm1" -Force -ErrorAction Stop
    Write-Host '[4/4] Checking the VM and starting OSDCloud...'
    OSDCloudLogic -BundlePath $bundle
    # A successful deployment normally reboots WinPE. Do not silently close if it returns.
    Write-Host 'The deployment command returned. Check its messages before continuing.'
    $null = Read-Host 'Press Enter to close this startup window'
} catch {
    Write-Host -ForegroundColor Red "DEMO STOPPED: $($_.Exception.Message)"
    Write-Host "Location: $($_.InvocationInfo.PositionMessage)"
    Write-Host "Startup log: $log"
    Write-Host 'Copy or photograph the error above. No automatic retry or fallback will run.'
    $null = Read-Host 'Press Enter only after recording the error'
    throw
} finally {
    if ($transcribing) { Stop-Transcript | Out-Null }
}
