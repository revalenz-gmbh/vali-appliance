#!/bin/bash
# Richtet das Update-Fenster ein: Proxy auf dem Host (nur im offenen Fenster aktiv) und Proxy-Einstellungen in den VMs.
# Aufruf auf CT130: bin/update-fenster-einrichten.sh
set -euo pipefail
. "$(dirname "$0")/umgebung.sh"
cd "$(dirname "$0")/.."
H=root@$PVE_HOST
SSH_BUERO="ssh -J $H vali@10.77.0.2"
SSH_GPU="ssh vali@$VALI_GPU_HOST"
scp -q update-fenster/tinyproxy.conf update-fenster/update-ziele.txt update-fenster/update-fenster.service update-fenster/update-fenster $H:/root/
ssh $H bash -s <<'REMOTE'
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get install -y --no-install-recommends tinyproxy >/dev/null
systemctl disable --now tinyproxy >/dev/null 2>&1 || true
install -m 644 /root/tinyproxy.conf /etc/tinyproxy/update-fenster.conf
install -m 644 /root/update-ziele.txt /etc/tinyproxy/update-ziele.txt
install -m 644 /root/update-fenster.service /etc/systemd/system/update-fenster.service
install -m 755 /root/update-fenster /usr/local/sbin/update-fenster
rm -f /root/tinyproxy.conf /root/update-ziele.txt /root/update-fenster.service /root/update-fenster
systemctl daemon-reload
REMOTE
for SSH in "$SSH_BUERO" "$SSH_GPU"; do
  $SSH 'set -e
echo "Acquire::http::Proxy \"http://10.77.0.1:3129/\";
Acquire::https::Proxy \"http://10.77.0.1:3129/\";" | sudo tee /etc/apt/apt.conf.d/90update-fenster >/dev/null
sudo mkdir -p /etc/systemd/system/docker.service.d
printf "[Service]\nEnvironment=\"HTTP_PROXY=http://10.77.0.1:3129\"\nEnvironment=\"HTTPS_PROXY=http://10.77.0.1:3129\"\nEnvironment=\"NO_PROXY=localhost,127.0.0.1,10.77.0.0/24,.buero.intern\"\n" | sudo tee /etc/systemd/system/docker.service.d/update-fenster.conf >/dev/null
sudo systemctl daemon-reload'
done
echo "Update-Fenster eingerichtet. Docker uebernimmt den Proxy beim naechsten Neustart des Dienstes (bin/update-ausfuehren.sh macht das im Wartungsfenster)."
