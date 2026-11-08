# One URL starts the demo from WinPE. No deployment runs until DEMO is selected.
[CmdletBinding()]
param([string]$Revision = 'main')
$ErrorActionPreference = 'Stop'
if ($env:SystemDrive -ne 'X:') { throw 'Run this startup script from WinPE.' }
if ((Read-Host 'Type DEMO to install Windows 11 25H2 x64 / English / Pro') -cne 'DEMO') { throw 'Cancelled.' }

$repository = 'xander-me/OSDCloud-Demo'
$headers = @{ 'User-Agent'='OSDCloud-Demo'; 'Cache-Control'='no-cache' }
# Resolve the branch once, then download every file from that same commit.
$commit = (Invoke-RestMethod "https://api.github.com/repos/$repository/commits/$([uri]::EscapeDataString($Revision))" -Headers $headers -TimeoutSec 20 -ErrorAction Stop).sha
if ($commit -cnotmatch '^[a-f0-9]{40}$') { throw 'Invalid source revision.' }
$bundle = Join-Path $env:TEMP ('OSDCloud-Demo-' + [guid]::NewGuid().ToString('N'))
New-Item "$bundle\OSDCloudModules" -ItemType Directory -Force | Out-Null
foreach ($file in 'OSDCloudModules/Module.psm1','OOBE.ps1') {
    Invoke-WebRequest -UseBasicParsing -Uri "https://raw.githubusercontent.com/$repository/$commit/$file" -OutFile (Join-Path $bundle $file) -TimeoutSec 30 -ErrorAction Stop
}
$commit | Set-Content "$bundle\revision.txt" -Encoding ASCII
Write-Host "Demo source revision: $commit"
Import-Module "$bundle\OSDCloudModules\Module.psm1" -Force -ErrorAction Stop
Start-DemoInstallation -BundlePath $bundle
