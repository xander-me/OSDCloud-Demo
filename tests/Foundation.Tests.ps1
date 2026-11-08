# Current single-file deployment regression suite. All deployment effects are mocked.
$ErrorActionPreference = 'Stop'
foreach ($file in Get-ChildItem "$PSScriptRoot/.." -Recurse -File | Where-Object { $_.Extension -in '.ps1','.psm1' }) {
    $tokens=$null; $parseErrors=$null
    $null=[System.Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$tokens,[ref]$parseErrors)
    if ($parseErrors.Count) { throw ($parseErrors | Out-String) }
}
Write-Host 'PASS PowerShell syntax'
& "$PSScriptRoot/Startup.Tests.ps1"
& "$PSScriptRoot/OOBE.Tests.ps1"
