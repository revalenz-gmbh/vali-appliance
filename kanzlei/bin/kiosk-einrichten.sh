#!/bin/bash
# Richtet an der Appliance einen Kiosk-Browser auf dem Proxmox-Host ein (Intel-Grafik, Monitor, USB-Tastatur/Maus).
# Der Browser darf nur start./cloud./vali./chat.buero.intern oeffnen. Aufruf auf CT130: bin/kiosk-einrichten.sh
set -euo pipefail
. "$(dirname "$0")/umgebung.sh"
cd "$(dirname "$0")/.."
H=root@$PVE_HOST
scp -q zertifikat/root.crt kiosk/kiosk-start.sh kiosk/kiosk.service kiosk/kiosk-richtlinie.json $H:/root/
ssh $H bash -s <<'REMOTE'
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get install -y --no-install-recommends cage chromium libnss3-tools udiskie udisks2 exfatprogs ntfs-3g curl fonts-dejavu-core >/dev/null
id kiosk >/dev/null 2>&1 || useradd --system --create-home --home-dir /var/lib/kiosk --shell /usr/sbin/nologin -G video,render,input,plugdev kiosk
sed -i '/buero\.intern/d' /etc/hosts; echo '10.77.0.2 start.buero.intern cloud.buero.intern vali.buero.intern chat.buero.intern' >> /etc/hosts
install -m 755 /root/kiosk-start.sh /usr/local/bin/kiosk-start
mkdir -p /etc/chromium/policies/managed && install -m 644 /root/kiosk-richtlinie.json /etc/chromium/policies/managed/kiosk.json
install -d -o kiosk -g kiosk /var/lib/kiosk/.pki/nssdb
chown -R kiosk:kiosk /var/lib/kiosk
[ -e /var/lib/kiosk/.pki/nssdb/cert9.db ] || runuser -u kiosk -- certutil -d sql:/var/lib/kiosk/.pki/nssdb -N --empty-password </dev/null
runuser -u kiosk -- certutil -d sql:/var/lib/kiosk/.pki/nssdb -D -n "Buero CA" 2>/dev/null || true
install -m 644 /root/root.crt /var/lib/kiosk/buero-ca.crt
runuser -u kiosk -- certutil -d sql:/var/lib/kiosk/.pki/nssdb -A -t "C,," -n "Buero CA" -i /var/lib/kiosk/buero-ca.crt
install -m 644 /root/kiosk.service /etc/systemd/system/kiosk.service
systemctl daemon-reload && systemctl enable kiosk.service >/dev/null 2>&1
rm -f /root/root.crt /root/kiosk-start.sh /root/kiosk.service /root/kiosk-richtlinie.json
REMOTE
echo "Kiosk eingerichtet. Start mit: ssh $H systemctl start kiosk"
