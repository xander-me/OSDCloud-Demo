# Status

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
