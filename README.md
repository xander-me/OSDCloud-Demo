# OSDCloud Demo

En enkel GT Tech Day-demo: **Windows → Autopilot → appfjernelse → OOBE**.

**Foundation/prototype. Scripts er ikke afprøvet i Windows/Hyper-V/Proxmox endnu.**

## Indstillinger

Åbn **[OSDCloudModules/Module.psm1](OSDCloudModules/Module.psm1)**. Indstillingerne står øverst:

```powershell
OSName       = 'Windows 11 25H2 x64'
OSEdition    = 'Pro'
OSLanguage   = 'en-us'          # English (United States)
OSActivation = 'Retail'

```

Samme sted ligger den korte liste over apps, der fjernes, hvis de er installeret: Solitaire, News og Clipchamp. Der matches eksakte pakkenavne.

## Start fra én URL

I en forberedt amd64 OSDCloud WinPE på en **dedikeret Hyper-V- eller Proxmox-VM med én tom virtuel disk**:

```powershell
$ErrorActionPreference = 'Stop'
$url = 'https://raw.githubusercontent.com/xander-me/OSDCloud-Demo/main/OSDCloud_Start.ps1'
Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile X:\OSDCloud_Start.ps1 -ErrorAction Stop
powershell.exe -NoProfile -ExecutionPolicy Bypass -File X:\OSDCloud_Start.ps1
```

Skriv **DEMO**. Startup viser source-commit og settings, installerer Windows og gemmer OOBE-trinnet lokalt fra samme source-commit. Hentning af filer fejler uden fallback. Til den endelige generalprøve bruges samme faste commit i både download-URL og scriptets `-Revision`-parameter. Branch-URL'en bruges til centrale ændringer; kun betroede writers bør kunne ændre den.

## Ved Windows OOBE

Tryk **Shift+F10**, skriv **`OOBE`**, og log ind med en administrator fra den rigtige demo-tenant.

1. Indtast Group Tag ved prompten, fx `AutopilotOOBE` eller `Site-Copenhagen`. Tomt input stopper før registrering.
2. `Get-WindowsAutopilotInfo -Online -GroupTag $groupTag` registrerer via Graph med det indtastede tag.
3. Scriptet verificerer serienummer og Group Tag i Autopilot, før det fortsætter.
4. Apps på listen fjernes, og fravær kontrolleres.
5. Maskinen genstarter til OOBE efter succes.

`OOBE.cmd` starter **ikke automatisk**. Ingen JSON-import, autologon eller lokale administratorændringer er tilføjet. Ingen apps eller tenant er ændret ved oprettelsen af dette repo. Et group tag opretter ikke en Entra-gruppe: demo-tenantens gruppe-/profiltildeling skal være forberedt, og registrering alene beviser ikke profiltilknytning/enrollment.

## Filer

| Fil | Formål |
| --- | --- |
| [OSDCloud_Start.ps1](OSDCloud_Start.ps1) | URL-entrypoint; vælg DEMO |
| [OSDCloudModules/Module.psm1](OSDCloudModules/Module.psm1) | Windows-settings, tag, appliste og hjælpefunktioner |
| [OOBE.ps1](OOBE.ps1) | Graph-registrering, verificering, cleanup og genstart |
| [STATUS.md](STATUS.md) | Afprøvning og næste handling |

## Før live-demo

WinPE skal have PowerShell, WMI/StorageWMI, netværk, TLS og fungerende Gallery-adgang eller det fastlagte OSD-modul preinstalleret. OSD er fastlagt til `26.10.16.1`; registreringsscript til `3.9`. Deres transitive afhængigheder og eventuelle upstream-downloads er ikke alle fastlåst. Prøvekør den samlede kæde og registrér de faktiske versioner; især V1 OSD's egen SetupComplete kan hente upstream helpers. Dette repo bygger ikke en ISO eller ændrer de separate OSDCloud-repositories.

Afprøv Windows-installation, faktisk OOBE-handoff, Graph-login/import, appfjernelse og genstart. Bekræft demo-tenant og grupperegel før import. Rehearsal skal måle den samlede tid; Graph-scriptets import-/synkroniseringsventetid kan overstige 20 minutter. Opbevar ikke hardwarehash, tokens, serienumre eller kundedata i GitHub.

Kilder: [Microsofts online-registrering](https://learn.microsoft.com/en-us/autopilot/add-devices), [Group Tag og grupper](https://learn.microsoft.com/en-us/autopilot/enrollment-autopilot). Layout inspireret af [AkosBakos/OSDCloud](https://github.com/AkosBakos/OSDCloud); ingen af dets scripts er kopieret.


## Hvis startupvinduet lukker

Startup viser nu fire trin og bliver stående ved fejl, indtil du trykker Enter. Kopiér fejlteksten før vinduet lukkes. Log: `%TEMP%\OSDCloud-Demo-Startup.log` (normalt `X:\Windows\Temp\OSDCloud-Demo-Startup.log` i WinPE). `DEMO` accepteres også med små bogstaver og omgivende mellemrum. TLS 1.2 aktiveres før GitHub-kald.

Ved OSDCloud V1 `StartURL`, der peger på `main`-URL'en, hentes opdateret startupkode ved næste boot; ISO'en skal ikke genbygges for denne scriptrettelse. Genstart kun det dedikerede test-VM-forløb. Den oprindelige fejlårsag skal stadig identificeres ud fra den synlige fejl/log; diagnosticering alene beviser ikke, at deployment virker i WinPE.


## Hyper-V og Proxmox

Begge platforme accepteres nu i VM-kontrollen, både ved WinPE-installation og i OOBE-trinnet. Proxmox genkendes via de normale QEMU/Q35-, QEMU/i440FX- eller KVM-identiteter. Kravet er fortsat præcis én lokal RAW-disk nummer 0. En ændret SMBIOS-identitet kan kræve gennemgang; fejlteksten viser de registrerede manufacturer/model-værdier.

Ved Proxmox skal WinPE kunne se disk og netværk. VirtIO-controller/netkort kan kræve drivere i bootmediet; valg af VM-platform i scriptet installerer ikke WinPE-drivere. Hverken den samlede Hyper-V- eller Proxmox-installation er verificeret her. Hvis `StartURL` peger på `main`, hentes rettelsen ved næste boot uden ISO-genbygning.


Group Tag vælges nu først ved Windows OOBE; den indgår ikke i WinPE-profilen. Nye installationer henter automatisk de opdaterede scripts fra main. En VM, der allerede er installeret, bruger sin tidligere staged kopi under `C:\ProgramData\OSDCloud-Demo`; opdatér både OOBE.ps1 og modulet fra samme nye commit (samt revision.txt), før denne VM kan bruge den nye prompt. En ændring på GitHub opdaterer ikke de lokale OOBE-filer af sig selv.
