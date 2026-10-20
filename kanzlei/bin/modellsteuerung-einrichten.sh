#!/bin/bash
# Richtet die Modellsteuerung auf vali-gpu ein (als vali, mit sudo). Aufruf auf CT130:
#   modellsteuerung-einrichten.sh <Datei mit Messwerten (Ausgabe von modellwechsel.py)>
set -euo pipefail
. "$(dirname "$0")/umgebung.sh"
cd "$(dirname "$0")/.."
MESS=${1:?Messwertdatei angeben}
SSH="ssh vali@$VALI_GPU_HOST"
tar -C modellsteuerung --exclude=__pycache__ --exclude=.pytest_cache -cf - app.py steuerung.py modellsteuerung.service sudoers-modellsteuerung | $SSH 'rm -rf /tmp/ms && mkdir /tmp/ms && tar -C /tmp/ms -xf -'
$SSH "cat > /tmp/ms/messwerte.log" < "$MESS"
$SSH 'set -e
id modellsteuerung >/dev/null 2>&1 || sudo useradd --system --home /opt/modellsteuerung --shell /usr/sbin/nologin modellsteuerung
sudo mkdir -p /opt/modellsteuerung
sudo install -m 644 /tmp/ms/app.py /tmp/ms/steuerung.py /tmp/ms/messwerte.log /opt/modellsteuerung/
dpkg -s python3-venv >/dev/null 2>&1 || sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq python3-venv
[ -x /opt/modellsteuerung/venv/bin/pip ] || { sudo rm -rf /opt/modellsteuerung/venv; sudo python3 -m venv /opt/modellsteuerung/venv; }
sudo /opt/modellsteuerung/venv/bin/pip install -q fastapi httpx uvicorn
sudo chown -R root:root /opt/modellsteuerung
sudo install -m 440 /tmp/ms/sudoers-modellsteuerung /etc/sudoers.d/modellsteuerung
sudo visudo -cf /etc/sudoers.d/modellsteuerung
sudo install -m 644 /tmp/ms/modellsteuerung.service /etc/systemd/system/modellsteuerung.service
sudo ufw allow from 172.16.0.0/12 to any port 8003:8004 proto tcp >/dev/null
sudo systemctl daemon-reload && sudo systemctl enable modellsteuerung >/dev/null 2>&1 && sudo systemctl restart modellsteuerung
sleep 4; systemctl is-active modellsteuerung'
