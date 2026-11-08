# Status

2026-11-08 — foundation/prototype.

Mandat: Alexander har efter oprydning godkendt et nyt, enkelt GitHub-grundlag: én URL, profilen DEMO, Windows 11 25H2 x64 en-us, online Graph-registrering med Group Tag AutopilotOOBE, verificering, eksakt appallowlist og genstart til OOBE. Ingen JSON-registrering eller genbrug af den kasserede GT Tech Day-implementation.

Arbejdssted: xander-me/OSDCloud-Demo. Selvstændigt offentligt demo-code-repo begrundes med en anonymt læsbar startup-URL og en lille rodstruktur; det private gt-tech-day ejer fortsat eventplanlægning. Vanilla OSDCloud og andre eksisterende repositories ændres ikke.

Udført: læsbart settingsmodul, commit-fast bundlehentning, blank Hyper-V-diskguard, CLI-kald med eksplicitte settings, lokal OOBE.cmd, Graph-baseret onlinekald, serial/tag-verificering før appfjernelse og ingen genstart ved fejl. OOBE starter manuelt med Shift+F10 → OOBE.

Designreview: genbrug eksisterende OSD/Graph-script frem for eget registreringssystem. Ingen auto-login eller credentials i repo. Windows og interaktiv registrering er to forskellige bootfaser. App-listen er præcis og kort. Stopgrænser før diskændring, før cleanup og før reboot.

Implementationsreview: source-hentning og modulimport starter ikke deployment uden DEMO. Central revision fastlægges én gang; OOBE-filer stages lokalt fra samme commit. Recast/OSD's øvrige runtimeafhængigheder kan stadig ændre sig. Serienummer/tag skal kunne bekræftes i Autopilot; gruppemedlemskab og profiltilknytning er separate. Graph-scriptets egen importventetid er ikke begrænset af vores efterfølgende kontrol.

Evidens: se tests/Foundation.Tests.ps1. 5 host-side mocktestgrupper og PowerShell-syntaksvalidering af alle scripts er bestået på PowerShell 7/Linux. Get-AutopilotDevice -serial er kontrolleret i den publicerede WindowsAutopilotIntune 5.4.0-pakke uden at installere den. Windows PowerShell 5.1, WinPE, ISO, Hyper-V, Graph/tenant, OOBE, appliste på det konkrete image og 20-minutters generalprøve er IKKE KØRT. Der er ikke udført installation eller tenantimport ved repo-oprettelsen.

Næste handling: identificér Hyper-V-vært og eksisterende ISO, afprøv hele flowet på blank VM med korrekt demo-tenant og registrér source-/modulversioner samt tider. Først derefter kan foundation kaldes en afprøvet demo.
