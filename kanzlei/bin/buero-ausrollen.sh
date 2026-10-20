#!/bin/bash
# Kopiert den Arbeitsbereich auf die VM buero und richtet Namensdienst und Eingang ein.
# Aufruf auf CT130: buero-ausrollen.sh [Dienst ...]   (ohne Angabe: alle Dienste der Compose-Datei)
set -euo pipefail
. "$(dirname "$0")/umgebung.sh"
cd "$(dirname "$0")/.."
SSH="ssh -J root@$PVE_HOST vali@10.77.0.2"
DIENSTE="$*"
tar -C buero -cf - . |  $SSH 'sudo mkdir -p /opt/kanzlei/buero && sudo chown vali /opt/kanzlei /opt/kanzlei/buero && tar --overwrite -C /opt/kanzlei/buero -xf -'
tar -cf - bin/neue-geheimnisse.sh | $SSH 'sudo mkdir -p /opt/kanzlei/bin && sudo chown vali /opt/kanzlei /opt/kanzlei/bin && tar -C /opt/kanzlei -xf -'
$SSH 'set -e
cd /opt/kanzlei/buero
sudo install -m 755 dnsmasq/start.sh /usr/local/sbin/dnsmasq-buero-start.sh
sudo mkdir -p /etc/systemd/system/dnsmasq.service.d
sudo install -m 644 dnsmasq/dnsmasq-buero.conf /etc/systemd/system/dnsmasq.service.d/buero.conf
sudo rm -f /etc/networkd-dispatcher/routable.d/50-dnsmasq-buero
sudo install -m 644 dnsmasq/dnsmasq-buero-nachziehen.service dnsmasq/dnsmasq-buero-nachziehen.timer /etc/systemd/system/
sudo systemctl daemon-reload && sudo systemctl enable dnsmasq >/dev/null 2>&1 && sudo systemctl restart dnsmasq && sudo systemctl enable --now dnsmasq-buero-nachziehen.timer >/dev/null 2>&1
mkdir -p ca; sudo install -m 644 caddy-data/caddy/pki/authorities/local/root.crt ca/root.crt 2>/dev/null || true
[ -e .env ] || /bin/bash /opt/kanzlei/bin/neue-geheimnisse.sh
sudo docker compose up -d '"$DIENSTE"' 2>&1 | tail -4
sudo docker compose exec -T caddy caddy reload --config /etc/caddy/Caddyfile 2>&1 | tail -1 || true'
