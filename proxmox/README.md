# Lokal Windows-image-server på Proxmox

Kør [install-image-server.sh](install-image-server.sh) som root i **Proxmox-værtens Shell**. Scriptet opretter en ny unprivileged Debian 12 LXC med Nginx: 1 CPU, 512 MB RAM og 4 GB systemdisk. Det bruger Proxmox' templateværktøj og [read-only bind mount](https://github.com/proxmox/pve-docs/blob/master/pct.adoc). Nginx bruger [statisk filservering](https://nginx.org/en/docs/http/ngx_http_core_module.html).

```bash
curl -fL https://raw.githubusercontent.com/xander-me/OSDCloud-Demo/main/proxmox/install-image-server.sh -o /root/install-image-server.sh
less /root/install-image-server.sh
bash /root/install-image-server.sh
```

Du bliver spurgt om storage til containerens systemdisk, f.eks. `local-lvm`. En ledig ID vælges automatisk; en eksisterende VM/container ændres ikke. Standard: `vmbr0`, DHCP, template-storage `local`, image-mappe `/var/lib/vz/osdcloud-images`. Host og container skal kunne hente templates/Debian-pakker fra internettet.

Eksempel med egne indstillinger (erstat IP-adresser/storage):

```bash
CTID=150 ROOTFS_STORAGE=local-lvm BRIDGE=vmbr0 \
IP_CIDR=192.168.1.50/24 GATEWAY=192.168.1.1 \
IMAGE_DIR=/var/lib/vz/osdcloud-images \
bash /root/install-image-server.sh
```

DHCP kræver en DHCP-server. Reservér containerens adresse, så image-URL'en forbliver stabil. Hvis et VLAN er nødvendigt, konfigureres det i containerens netkort i Proxmox. Installer understøttede Debian-templates; Debian 13 kan vælges med `DEBIAN_MAJOR=13`, hvis værten understøtter det.

## Tilføj Windows-image

Brug en dedikeret mappe med kun de imagefiler, som demo-netværket må hente. HTTP er uden login; ingen port-forwarding til internettet. Scriptet ændrer ikke værtsnetværk/firewall og installerer ingen pakker på Proxmox-værten. Firewall skal tillade TCP 80 fra demo-VM'en til containeren. Den viste health-test fra værten beviser ikke adgang fra VM'en.

Kopiér en Windows 11 25H2 dansk WIM/ESD fra dit installationsmedie, f.eks.:

```bash
install -m 0644 /sti/til/install.wim /var/lib/vz/osdcloud-images/install.wim
```

Hvis du kun har ISO'en, kan du montere den read-only og hente `sources/install.wim` eller `sources/install.esd`:

```bash
mkdir -p /mnt/osdcloud-windows-iso
mount -o loop,ro /sti/til/Windows11.iso /mnt/osdcloud-windows-iso
ls /mnt/osdcloud-windows-iso/sources/install.*
# Brug det filnavn, som faktisk findes:
install -m 0644 /mnt/osdcloud-windows-iso/sources/install.wim /var/lib/vz/osdcloud-images/install.wim
umount /mnt/osdcloud-windows-iso
```

Eksisterende filer/mapper får ikke automatisk ændret rettigheder. Nginx skal kunne læse filerne og traversere mapperne. Bind mount er read-only i containeren og indgår ikke i containerbackup. Opbevar en separat kopi af images. Ved en fejl beholdes en eventuelt oprettet container til fejlsøgning; genkørsel med samme ID afvises.

## Kontrollér fra WinPE

Brug adressen, som installer-scriptet viser:

```powershell
Invoke-WebRequest -UseBasicParsing -Method Head -Uri 'http://192.168.1.50/install.wim'
```

Forvent HTTP 200. Filindholdet/imageindex skal stadig verificeres. HTTP 200 er ikke en hashkontrol. Lokal hosting alene giver ikke en katalog/hashgaranti for en brugerdefineret WIM.

Send den fungerende image-URL og Pro-index videre til ændringen i OSDCloud_Start.ps1. Startup er endnu ikke ændret til en lokal URL: `ImageFileUrl`/`OSImageIndex` bruger en anden OSDCloud parametergruppe end de nuværende OSVersion/OSBuild/OSLanguage-parametre og skal derfor tilpasses samlet. Version, arkitektur, udgave og sprog kommer fra det valgte image. Autopilot/OOBE beholder sin nuværende konfiguration.

Valideret her: Bash-syntaks, ShellCheck og tre mockforløb (succes, optaget ID, fejlet containerinstallation). **Ikke kørt på en rigtig Proxmox-vært.**
