#!/usr/bin/env bash
# Run as root on a Proxmox VE host. Creates a NEW container only.
set -Eeuo pipefail

# Override with environment variables, or accept the interactive defaults.
CTID="${CTID:-}"
BRIDGE="${BRIDGE:-vmbr0}"
ROOTFS_STORAGE="${ROOTFS_STORAGE:-}"
TEMPLATE_STORAGE="${TEMPLATE_STORAGE:-local}"
IMAGE_DIR="${IMAGE_DIR:-/var/lib/vz/osdcloud-images}"
DEBIAN_MAJOR="${DEBIAN_MAJOR:-12}"
# DHCP by default. Static example: IP_CIDR=192.168.1.50/24 GATEWAY=192.168.1.1
IP_CIDR="${IP_CIDR:-dhcp}"
GATEWAY="${GATEWAY:-}"
created=0
on_error() {
    local rc=$1 line=$2
    printf 'Setup stopped at line %s (exit %s).\n' "$line" "$rc" >&2
    if ((created)); then printf 'Container %s is retained for inspection; no automatic deletion.\n' "$CTID" >&2; fi
    exit "$rc"
}
trap 'on_error "$?" "$LINENO"' ERR
fail() { printf '%s\n' "$*" >&2; exit 1; }
[[ $EUID -eq 0 ]] || fail 'Run as root on the Proxmox host.'
for command in pct pveam pvesm pvesh ip curl; do
    command -v "$command" >/dev/null || fail "Required host command missing: $command"
done
[[ $(uname -m) == x86_64 ]] || fail 'This installer uses an amd64 template.'
[[ -n $CTID ]] || CTID=$(pvesh get /cluster/nextid)
if ! [[ $CTID =~ ^[1-9][0-9]+$ ]] || (( CTID < 100 )); then fail 'CTID must be an integer of at least 100.'; fi
# Check cluster-wide VMIDs as well as containers. pct create also checks allocation.
next_id=$(pvesh get /cluster/nextid --vmid "$CTID")
[[ $next_id == "$CTID" ]] || fail "ID $CTID is already allocated. Choose another CTID."
[[ $BRIDGE =~ ^[a-zA-Z0-9_.-]+$ ]] || fail 'Invalid bridge name.'
ip link show dev "$BRIDGE" >/dev/null
if [[ -z $ROOTFS_STORAGE ]]; then
    pvesm status --content rootdir
    read -r -p 'Storage for the 4 GB container disk (e.g. local-lvm): ' ROOTFS_STORAGE
fi
for storage in "$ROOTFS_STORAGE" "$TEMPLATE_STORAGE"; do
    [[ $storage =~ ^[a-zA-Z0-9_-]+$ ]] || fail 'Invalid storage name.'
done
check_storage() {
    pvesm status --storage "$1" --content "$2" |
        awk -v name="$1" '$1 == name && $3 == "active" {found=1} END {exit !found}'
}
check_storage "$ROOTFS_STORAGE" rootdir || fail 'Root disk storage must be active and support containers.'
check_storage "$TEMPLATE_STORAGE" vztmpl || fail 'Template storage must be active and support templates.'
[[ $DEBIAN_MAJOR =~ ^(12|13)$ ]] || fail 'Choose Debian 12 or 13 (host must support it).'
[[ $IMAGE_DIR == /* && $IMAGE_DIR != / && $IMAGE_DIR != *[[:space:],]* && $IMAGE_DIR != *:* ]] || fail 'Use an absolute image folder without spaces, commas or colons.'
[[ ! -L $IMAGE_DIR ]] || fail 'The image folder must not be a symlink.'
if [[ $IP_CIDR != dhcp ]]; then
    [[ $IP_CIDR =~ ^[0-9.]+/[0-9]+$ && $GATEWAY =~ ^[0-9.]+$ ]] || fail 'Set IP_CIDR to an IPv4 address/prefix and GATEWAY to an IPv4 address.'
fi
net="name=eth0,bridge=$BRIDGE,ip=$IP_CIDR,type=veth,firewall=1"
[[ $IP_CIDR == dhcp ]] || net+=",gw=$GATEWAY"
printf 'Creating CT %s on %s; disk storage %s; network %s; images %s\n' "$CTID" "$BRIDGE" "$ROOTFS_STORAGE" "$IP_CIDR" "$IMAGE_DIR"

pveam update
template=$(pveam available --section system |
    awk -v major="$DEBIAN_MAJOR" '$2 ~ ("^debian-" major "-standard_.*_amd64.tar.(zst|xz|gz)$") {print $2}' |
    sort -V | tail -n 1)
[[ -n $template ]] || fail "No Debian $DEBIAN_MAJOR template found. Check pveam available."
pveam download "$TEMPLATE_STORAGE" "$template"
# Only this dedicated folder is exposed. Existing permissions are not changed.
if [[ ! -e $IMAGE_DIR ]]; then install -d -m 0755 "$IMAGE_DIR"; fi
[[ -d $IMAGE_DIR ]] || fail 'IMAGE_DIR is not a directory.'
pct create "$CTID" "$TEMPLATE_STORAGE:vztmpl/$template" \
    --hostname osdcloud-images --unprivileged 1 --cores 1 --memory 512 --swap 256 \
    --rootfs "$ROOTFS_STORAGE:4" --net0 "$net" --onboot 1 \
    --mp0 "$IMAGE_DIR,mp=/srv/osdcloud-images,ro=1"
created=1
pct start "$CTID"
# Wait for network/DNS readiness without an unlimited retry loop.
ready=0
for ((attempt=0; attempt<30; attempt++)); do
    if pct exec "$CTID" -- getent hosts deb.debian.org >/dev/null 2>&1; then ready=1; break; fi
    sleep 2
done
((ready)) || fail "CT $CTID has no working DNS/network. Inspect its bridge, DHCP and firewall."
pct exec "$CTID" -- bash -s <<'CONTAINER'
set -Eeuo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get -o Acquire::Retries=3 -o Acquire::http::Timeout=30 update
apt-get -o Acquire::Retries=3 -o Acquire::http::Timeout=30 install -y --no-install-recommends nginx curl ca-certificates
cat > /etc/nginx/sites-available/osdcloud-images <<'NGINX'
server {
    listen 80 default_server;
    server_name _;
    root /srv/osdcloud-images;
    autoindex off;
    sendfile on;
    disable_symlinks on;
    location = /health { default_type text/plain; return 200 "OSDCloud image server ready\n"; }
    location / {
        limit_except GET HEAD { deny all; }
        try_files $uri =404;
    }
}
NGINX
rm -f /etc/nginx/sites-enabled/default
ln -s /etc/nginx/sites-available/osdcloud-images /etc/nginx/sites-enabled/osdcloud-images
nginx -t
systemctl enable nginx
systemctl restart nginx
curl --fail --silent --show-error http://127.0.0.1/health
CONTAINER
address=$(pct exec "$CTID" -- ip -4 -o addr show dev eth0 scope global | awk 'NR==1 {split($4,a,"/"); print a[1]}')
[[ -n $address ]] || fail "No IPv4 address found on CT $CTID eth0."
curl --fail --silent --show-error --connect-timeout 5 --max-time 10 "http://$address/health"
printf '\nReady: http://%s/health\nImage folder on Proxmox: %s\nExample image URL after copying install.wim: http://%s/install.wim\nContainer ID: %s\n' "$address" "$IMAGE_DIR" "$address" "$CTID"
printf 'Copy only intended public-to-the-demo-LAN image files here, readable by the container (e.g. mode 0644).\nUse a DHCP reservation or static IP for a stable URL. Test access from WinPE before deployment.\nThe bind-mounted image folder is not included in container backups.\n'
