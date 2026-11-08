# OSDCloud Demo

Windows 11 25H2 x64, Enterprise Evaluation, engelsk (`en-US`) fra LAN-ISO på Hyper-V eller Proxmox. **Windows/WinPE-forløbet er endnu ikke afprøvet på en VM.**

## Start

Brug denne StartURL i OSDCloud WinPE:

```text
https://raw.githubusercontent.com/xander-me/OSDCloud-Demo/main/OSDCloud_Start.ps1
```

[OSDCloud_Start.ps1](OSDCloud_Start.ps1) indeholder `OSDCloudLogic`, Windows-parametre, de to JSON-konfigurationer og OOBE-scriptet. Funktionen kaldes automatisk nederst. Ingen DEMO-prompt.

Kør kun på en dedikeret Hyper-V-/Proxmox-demo-VM med én lokal disk nummer 0. **OSDClouds normale wipe/partitionering sletter eksisterende data på denne disk.** RAW, GPT og MBR accepteres. Der bruges ingen separat wipekommando. WinPE skal have netværks- og diskdrivere; Proxmox VirtIO kan kræve opdateret ISO.

JSON valideres før installation. Fejl vises og venter på Enter. En ugyldig eller utilgængelig StartURL kan ikke starte den hentede funktion; den indbyggede StartURL-launchers egen fejlhåndtering skal også afprøves i ISO'en.

## Indstillinger

Redigér `$ImageShare` og `$ImageFileName` i `[OS]`-afsnittet. Windows-version, udgave og sprog læses fra ISO'ens image; startup kræver præcis én EnterpriseEval/x64/en-US/26200-kandidat og vælger dens index. JSON står lige nedenunder:

- `OSDeploy.AutopilotOOBE.json`: `GroupTagOptions` er `OptionA` og `OPTION B`; `GroupTag` er standardvalget. Vælg ved OOBE. `PostAction` skal være `Quit`, og `Assign` false, så kontrollen kan fortsætte efter UI'et.
- `OSDeploy.OOBEDeploy.json`: præcis liste over apps til fjernelse. Autopilot, Windows Update og driveropdateringer er slået fra i OOBEDeploy; registreringen håndteres separat af AutopilotOOBE.

Disse JSON-filer konfigurerer værktøjerne; de er ikke en offline Autopilot-profil. Graph-login og online registrering foregår i AutopilotOOBE. Group Tag opretter ikke en Entra-gruppe eller en deploymentprofil.

## Ved Windows OOBE

Tryk **Shift+F10**, skriv **`OOBE`**, og vælg tag i AutopilotOOBE. Registrér med en konto i den rigtige demo-tenant. Vælg Quit for at vende tilbage til scriptet efter registrering.

Scriptet kontrollerer serienummer og et af de konfigurerede tags i tenantens Autopilot-inventar. En allerede eksisterende registrering med et tilladt tag accepteres også; kontrollen beviser ikke, at der netop er udført en ny import, eller at en profil er tildelt. Uden bekræftet registrering stopper appfjernelse og genstart.

Derefter kører `Start-OOBEDeploy`, og fravær af de angivne installerede/provisionerede apps kontrolleres før genstart. Fejl stopper genstart. OSDClouds SetupComplete bevares. OOBE-kommandoen startes manuelt; ingen autologon.

[OOBE.ps1](OOBE.ps1) er en læsbar kopi af det indlejrede OOBE-script; testen kontrollerer, at de er ens. De ældre hjælpere i `OSDCloudModules` bruges ikke af denne startup.

## Afprøvning

OSD er fastlagt til `26.10.16.1`; AutopilotOOBE til `24.1.29.1`. Transitive afhængigheder, registreringsscript og downloadkataloger er ikke alle fastlåst. WinPE genbruger OSD 26.10.16.1, hvis denne version allerede er installeret; ellers kræves Gallery-adgang. OOBE-trinnets modulinstallationer kræver fortsat Gallery-adgang. GitHub-ændringer virker ved næste hentning af StartURL; allerede installerede VM'er bruger deres lokale OOBE-kopi.

Kør host-side mocktests med PowerShell:

```powershell
pwsh -NoProfile -File tests/Startup.Tests.ps1
pwsh -NoProfile -File tests/OOBE.Tests.ps1
```

Næste test: samme ISO i Hyper-V og Proxmox, faktisk disk-wipe, engelsk Enterprise Evaluation OOBE, Graph-login/registrering, appfjernelse og fejlscenarier. Mål varigheden før en 20-minutters live-demo. Gem ikke logs, serienumre, hashes eller tokens i GitHub.

## Hvis en gammel startup vises

Aktuel startup viser `OSDCloud Demo startup revision: 2026-11-08.3`. `Updating OSD PowerShell Module` og et tomt SetupComplete-trin tilhører den tidligere version. Hent en frisk kopi i WinPE:

```powershell
$url = 'https://raw.githubusercontent.com/xander-me/OSDCloud-Demo/main/OSDCloud_Start.ps1?v=20261108-3'
Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile X:\OSDCloud_Start.ps1 -ErrorAction Stop
Get-Content X:\OSDCloud_Start.ps1 -TotalCount 1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File X:\OSDCloud_Start.ps1
```

Den sidste kommando starter automatisk installation med sletning af VM'ens eneste lokale disk 0. Hvis Gallery stadig fejler uden lokal OSD 26.10.16.1, stopper scriptet før diskændringer. Kontroller DNS, proxy, WinPE-uret og HTTPS-adgang; fejlen alene identificerer ikke hvilken af disse der fejler.

## Aktuel LAN-kilde: PCS-SRV1

Startup bruger ISO-filen på `\\PCS-SRV1\Evaluation Edition≥` med det filnavn, brugeren har angivet. Share-navnets afsluttende `≥` er bevaret; i PowerShell-koden bygges tegnet med `[char]0x2265`, så startupfilen kan forblive ASCII. Hvis tegnet var en skrivefejl, fjernes `+ [char]0x2265` fra `$ImageShare`.

Ingen credentials gemmes eller efterspørges. Everyone-rettigheder alene beviser ikke, at WinPE kan bruge SMB som gæst; faktisk adgang skal prøves. Scriptet ændrer ikke klientens SMB-/guest-politik. Test fra WinPE uden diskændringer:

```powershell
$share = '\\PCS-SRV1\Evaluation Edition' + [char]0x2265
Get-ChildItem -LiteralPath $share -Filter '*.iso' -ErrorAction Stop
```

Før diskændringer læses filen, ISO'en monteres read-only, og DISM kontrollerer image metadata. Et mount oprettet af preflight afmonteres igen. OSDCloud får ISO-filen via `MyOSDCloud.ImageFileItem` og det fundne `OSImageIndex` via custom-image-parametergruppen; den kopierer derefter ISO'en fra LAN til måldisken med sit eget normale image-flow. Der faldes ikke tilbage til et internet-image.

ISO-montering kræver funktionel Storage/ISO-understøttelse i det konkrete WinPE. Hvis preflight fejler, stopper den før native wipe; alternativet er at udpakke `sources/install.wim`/`install.esd` på filserveren og tilpasse kilden. De 20 minutters varighed og SMB-/ISO-/DISM-funktion skal prøves i den faktiske VM.

Dette er imagevalg/metadata-kontrol, ikke hashverifikation. En brugerdefineret ISO har ikke automatisk en forventet hash i OSDCloud-kataloget. OOBE/Autopilot-flowet er bevaret og skal fortsat testes med Evaluation-udgaven.

Den tidligere [Proxmox HTTP-installationsvejledning](proxmox/README.md) og installer er bevaret som alternativ; de kræves ikke til dette SMB-forløb.
