# Status

Aktuelt: inline OSDCloudLogic i OSDCloud_Start.ps1, kald nederst og Windows-settings i samme fils [OS]-afsnit; automatisk StartURL uden DEMO-prompt; Windows 11 25H2 x64 / da-dk / Pro. Group Tag vælges ved OOBE. VM-/én-måldisk-guard og fejlpauser bevares. OSDClouds egen wipe/partitionering bruges også på tidligere installeret disk; blank disk kræves ikke længere. Tidligere notater nedenfor beskriver udviklingen.

2026-11-08 — foundation/prototype.

Mandat: Alexander har efter oprydning godkendt et nyt, enkelt GitHub-grundlag: én URL, profilen DEMO, Windows 11 25H2 x64 en-us, online Graph-registrering med Group Tag AutopilotOOBE, verificering, eksakt appallowlist og genstart til OOBE. Ingen JSON-registrering eller genbrug af den kasserede GT Tech Day-implementation.

Arbejdssted: xander-me/OSDCloud-Demo, `main`. Foundation publiceret via [PR #1](https://github.com/xander-me/OSDCloud-Demo/pull/1), mergecommit `37cd90f`. Afprøvning følges i [issue #2](https://github.com/xander-me/OSDCloud-Demo/issues/2). Selvstændigt offentligt demo-code-repo begrundes med en anonymt læsbar startup-URL og en lille rodstruktur; det private gt-tech-day ejer fortsat eventplanlægning. Vanilla OSDCloud og andre eksisterende repositories ændres ikke.

Udført: læsbart settingsmodul, commit-fast bundlehentning, blank Hyper-V-diskguard, CLI-kald med eksplicitte settings, lokal OOBE.cmd, Graph-baseret onlinekald, serial/tag-verificering før appfjernelse og ingen genstart ved fejl. OOBE starter manuelt med Shift+F10 → OOBE.

Designreview: genbrug eksisterende OSD/Graph-script frem for eget registreringssystem. Ingen auto-login eller credentials i repo. Windows og interaktiv registrering er to forskellige bootfaser. App-listen er præcis og kort. Stopgrænser før diskændring, før cleanup og før reboot.

Implementationsreview: source-hentning og modulimport starter ikke deployment uden DEMO. Central revision fastlægges én gang; OOBE-filer stages lokalt fra samme commit. Recast/OSD's øvrige runtimeafhængigheder kan stadig ændre sig. Serienummer/tag skal kunne bekræftes i Autopilot; gruppemedlemskab og profiltilknytning er separate. Graph-scriptets egen importventetid er ikke begrænset af vores efterfølgende kontrol.

Evidens: se tests/Foundation.Tests.ps1. 5 host-side mocktestgrupper og PowerShell-syntaksvalidering af alle scripts er bestået på PowerShell 7/Linux. Get-AutopilotDevice -serial er kontrolleret i den publicerede WindowsAutopilotIntune 5.4.0-pakke uden at installere den. Windows PowerShell 5.1, WinPE, ISO, Hyper-V, Graph/tenant, OOBE, appliste på det konkrete image og 20-minutters generalprøve er IKKE KØRT. Der er ikke udført installation eller tenantimport ved repo-oprettelsen.

Næste handling: identificér Hyper-V-vært og eksisterende ISO, afprøv hele flowet på blank VM med korrekt demo-tenant og registrér source-/modulversioner samt tider. Først derefter kan foundation kaldes en afprøvet demo.


Startupfejl rapporteret af Alexander: efter DEMO åbner/lukker et PowerShell-vindue, uden at en fejl kan aflæses. Årsag endnu ikke bekræftet i VM. Startup er ændret til trinvis feedback, transcript, TLS 1.2 og pause før fejl genkastes; også pause hvis deployment uventet returnerer. Input trimmes og sammenlignes uden casefølsomhed. Fire nye mockcases via Invoke-Expression (StartURL-mekanismen) bestået: GitHub-fejl, modulfejl, gyldigt input og annullering. Oprindelige fem foundation-testgrupper og alle script-syntaxchecks bestået igen. Ingen faktisk WinPE-installation kørt. Næste handling: bruger genstarter den dedikerede VM med samme main-StartURL og sender fejltekst eller startup-log. Ingen påstand om identificeret grundårsag.


Platformudvidelse: Alexander har bedt om både Hyper-V og Proxmox. Assert-DemoVM accepterer nu Hyper-V samt kendte QEMU/Q35-, QEMU/i440FX- og KVM manufacturer/model-par. Samme kontrol bruges af installation og OOBE. Ukendte/fysiske identiteter afvises med registrerede værdier. Den eksisterende én-RAW-disk-0-grænse er uændret. Fire ekstra mocktestgrupper dækker platforme, afvisninger og diskfejl på begge platforme; samlet ni foundation-grupper plus fire startupcases. Faktisk WinPE/Hyper-V/Proxmox/Graph-runtime er fortsat ikke kørt her; VirtIO-driverbehov må afprøves i brugerens ISO. Næste handling: genstart Proxmox-testen fra samme main-StartURL og aflæs synligt startupresultat.


Seneste ændring: Alexander ønsker Group Tag tilføjet senere ved OOBE. Fast GroupTag er fjernet fra Windows-settings; Read-DemoGroupTag spørger før registreringsscriptet installeres/køres. Input trimmes, tomt input og kontroltegn stopper; samme valgte tag bruges til Graph-import og efterfølgende serial/tag-verificering. WinPE foretager intet tagvalg. To ekstra mockcases dækker prompt og ugyldigt input; registreringstests bruger et andet eksempel-tag. Nye installationer henter main; allerede installerede VM'er kræver opdatering af staged OOBE/module/revision sammen. Ingen Windows-/tenantoperation kørt her.


Seneste mandat: brugeren har indsat OSDCloudLogic som nyt udgangspunkt og bedt om at fjerne forfatterrelaterede tilpasninger og tilføje Windows 11 25H2 DK. Installationsfunktionen hedder nu OSDCloudLogic og bruger Start-OSDCloud med OSName Windows 11 25H2 x64 / Pro / da-dk / Retail. Tidligere Start-DemoInstallation-navn er en kompatibilitetsalias til ældre downloadede startupfiler. Den indsendte 25-app-liste er bevaret som eksakt, case-insensitiv allowlist. ComputerPrefix/navne/GroupX, Autopilot-JSON, eksterne personlige helper-URL'er, OEM-key-/TPM-/cleanup-kæde og tom SetupComplete er ikke genindført. Group Tag ved OOBE og direkte Graph-registrering fra forrige beslutning bevares. Ingen firmware/OEM-pack for VM'er; automatiske fulde Windows-/driveropdateringer er fravalgt i 20-minutters demoen og dokumenteret. Faktisk dansk installation og app-listens resultat afventer brugerens test. Ingen VM eller tenant ændret her.

Validering af DK-ændringen: 13 foundation-mocktestgrupper og 4 startupcases bestået; alle PowerShell-filer syntaxkontrolleret og diffcheck bestået. Ny test kører OSDCloudLogic frem til et mocked Start-OSDCloud og kontrollerer da-dk/25H2/x64/Pro/Retail samt ingen firmware, automatisk reboot eller diskoperation i testen. Virkelig DK/Windows/VM/tenant-test er fortsat åben.


Seneste mandat: brugeren har bedt om at fjerne den overflødige DEMO-bekræftelse. Den er fjernet; der er ingen inputpause før OSDCloudLogic. Fire startupcases dækker automatisk fremdrift uden Read-Host før mocked installation, GitHub-fejl, modulfejl og stop uden for WinPE. Foundation-testene dækker fortsat VM-/diskgrænser og OOBE-tag. Fejl- og uventet-retur-pauser er bevaret, så lukkede PowerShell-vinduer ikke skjuler fejl. Ingen Windows-/disk-/tenantoperation kørt her; faktisk VM-test mangler stadig.


Rettelse efter brugerens GitHub-commit bda89b7: OSDCloud_Start.ps1 var erstattet af en funktionsdefinition uden kald, med OSBuild="2HH2" og den tidligere fravalgte JSON/forfatter-helper-kæde. Det forklarer et vindue, der lukker uden aktivitet. Brugeren bekræftede at bevare Group Tag ved OOBE og direkte Graph-registrering. Den automatiske launcher fra be4a305 er genindført; den kalder modulets eksisterende OSDCloudLogic med Windows 11 25H2 / da-dk. Brugerens commit er bevaret i Git-historikken. Den aktuelle startupkode indeholder ikke længere det ugyldige OSBuild. Fejlpauser/log bevares. Startup-regressionstesten fejlede på bda89b7 uden at udføre deployment; efter rettelsen bestod alle 4 startupcases og 13 foundation-grupper inklusive syntaks. Ingen VM- eller tenantoperation udført.


Seneste mandat: Alexander bad om at slette disken som normal OSDCloud og understregede, at OSDClouds egen wipe-feature skal bruges. RAW-kravet er fjernet; én lokal disk 0 på genkendt VM kræves stadig. MyOSDCloud sætter SkipAllDiskSteps/SkipClearDisk/SkipNewOSDisk=false, og den eksisterende Start-OSDCloud -ZTI udfører sin normale Clear-LocalDisk/partitionering. Ingen separat wipekommando eller diskkørsel tilføjet/udført her. Den fastlagte OSD-kilde er inspiceret: dens normale WinPE-disksektion rydder disken før nye partitioner, med bekræftelse fravalgt via ZTI på én disk. RAW/GPT/MBR testes frem til mocked engine med native-diskflag; manglende/flere/forkert nummererede diske afvises på begge platforme. Virkelig wipe/Windows/VM/tenant-runtime afventer fortsat brugerens test.


Seneste brugerpræference: behold single-file-funktionen i OSDCloud_Start.ps1 og ret startupfejlen dér. Efter afklaring bevares den tidligere aftalte Graph/OOBE-flow, ikke den gamle JSON/GroupX/forfatter-hostede kæde. OSDCloudLogic og Windows-settings er nu flyttet tilbage i startupfilen med et eksplicit kald nederst og fejlpauser/log. Ingen import af installationsfunktionen fra modulet. Modulet er kun OOBE-hjælpere/appliste; Group Tag indtastes ved OOBE. Dansk 25H2, Hyper-V/Proxmox, én lokal disk 0 og native OSDCloud wipe bevares. De seks startupcases udfører den konkrete inline-kode via Invoke-Expression med mocked engine/network; 12 supporting testgrupper og syntakschecks består. Ingen reel Windows/disk/tenantoperation udført. Den først foreslåede uændrede genaktivering af den gamle helper-kæde blev afvist af automatisk approval review; denne implementering udelader den kæde og følger brugerens afklaring. Næste handling: test samme StartURL på brugerens VM.

## 2026-11-08 — Aktuel rettelse: inline JSON-flow

Dette afsnit erstatter tidligere beskrivelser af den aktive direkte Graph/helper-arkitektur. Brugeren ønsker sin inline OSDCloudLogic bevaret og AutopilotOOBE JSON anvendt.

Rettet: gyldig GroupTag/GroupTagOptions, PostAction Quit, automatisk funktionskald, WinPE/VM/diskkontrol, eksplicit Retail, OSDClouds native wipeflag, ingen automatisk engine-reboot, completion-kontrol før staging, lokal OOBE.cmd med AutopilotOOBE og OOBEDeploy, bevaring af SetupComplete og stop/pause ved fejl. Overflødig Surface-driverpakkehentning er fjernet fra VM-flowet. Automatiske Windows-/driveropdateringer og profilventetid er fravalgt for demoen.

Tenantkontrol accepterer en eksisterende serial/tag-registrering med et konfigureret tag; den beviser ikke en ny import eller profiltildeling. Afhængigheder er kun delvist versionsfastlagt. OOBE.ps1 og den indlejrede kopi holdes ens via test.

Næste handling: afprøv samme ISO på Hyper-V/Proxmox med én disk, verificér dansk OOBE og den valgte Group Tag i den korrekte demo-tenant; mål hele forløbet. Windows/WinPE/ISO/Graph/tenant-runtime er IKKE kørt her.

Validering: 9 startup-mockcases og 5 OOBE-mockcases bestået samt syntakskontrol af alle PowerShell-filer og git diff --check. Ingen disk-, app- eller tenantoperation udført. tests/Foundation.Tests.ps1 er samlet indgang til de aktuelle tests; ældre tests af den erstattede helper-arkitektur er erstattet. Alle ændringer publiceres via PR; ingen lokale ændringer forventes efter merge.


## 2026-11-08 — Gallery-fejl og gammel startup

Brugerens output indeholder tidligere tekster, smart quotes i da-dk og tom SetupComplete. Den publicerede main-fil er kontrolleret via GitHub og indeholder ikke disse trin/quotes. Årsagen til den gamle kopi (cache eller tidligere download) er ikke bekræftet. Tilføjet synlig startuprevision 2026-11-08.2 og vejledning til frisk hentning. WinPE bruger installeret OSD 26.10.16.1 uden Gallery-kald; manglende version og fejlet Gallery-installation stopper med forklaring før diskændringer. Ingen fallback til en vilkårlig ældre modulversion. OOBE-flow og JSON er uændret. Mocktests kontrollerer genbrug uden Install-Module og stop ved Gallery-fejl; Windows/WinPE-netværksfejlen er ikke reproduceret lokalt.

## 2026-11-08 — Proxmox lokal image-server

Tilføjet proxmox/install-image-server.sh og dansk vejledning efter brugerens ønske. Ny unprivileged Debian LXC med Nginx, dedikeret read-only hostmappe, DHCP eller statisk IPv4, eksisterende ID afvises og fejl sletter ikke containeren. Ingen værtsnetværksændring/pakkeinstallation. Bash syntax, ShellCheck og tre mockscenarier består; ingen rigtig Proxmox-installation er kørt. Windows/Autopilot-scriptet er uændret. Næste handling: bruger kører installer, tilføjer dansk 25H2 WIM/ESD og tester HTTP fra WinPE; derefter tilpasses Windows-startup med faktisk URL og Pro-index.
