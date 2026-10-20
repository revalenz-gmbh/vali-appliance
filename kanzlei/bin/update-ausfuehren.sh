#!/bin/bash
# Spielt Sicherheitsupdates ein: Fenster oeffnen, VMs aktualisieren, Fenster schliessen. Aufruf auf CT130: bin/update-ausfuehren.sh [Minuten]
# Vorher eine Sicherung ziehen (vzdump). Dienste in den VMs starten kurz neu (Docker), also ausserhalb der Arbeitszeit ausfuehren.
set -euo pipefail
. "$(dirname "$0")/umgebung.sh"
H=root@$PVE_HOST
MIN=${1:-30}
SSH_BUERO="ssh -J $H vali@10.77.0.2"
SSH_GPU="ssh vali@$VALI_GPU_HOST"
ssh $H "update-fenster oeffnen $MIN"
trap 'ssh $H "update-fenster schliessen"' EXIT
for ziel in "BUERO:$SSH_BUERO" "GPU:$SSH_GPU"; do
  name=${ziel%%:*}; SSH=${ziel#*:}
  echo "== $name: Sicherheitsupdates =="
  $SSH 'sudo apt-get update -qq && sudo unattended-upgrade -v 2>&1 | tail -5; [ -e /var/run/reboot-required ] && echo "NEUSTART NOETIG" || true'
done
echo "== BUERO: Abbilder gleicher Version erneuern =="
$SSH_BUERO 'sudo systemctl restart docker; sleep 5; cd /opt/kanzlei/buero && sudo docker compose pull 2>&1 | tail -4 && sudo docker compose up -d 2>&1 | tail -3'
echo "Fertig. Fenster schliesst jetzt (trap). Danach: bin/pruefe-eingang.sh <IP der buero> ausfuehren."
