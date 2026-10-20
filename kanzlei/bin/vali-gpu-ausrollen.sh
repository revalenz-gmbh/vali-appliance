#!/bin/bash
# Kopiert den Arbeitsbereich vali-gpu auf die VM und startet die angegebenen Dienste (ohne Angabe: alle).
# Aufruf auf CT130: vali-gpu-ausrollen.sh [Dienst ...]
set -euo pipefail
. "$(dirname "$0")/umgebung.sh"
cd "$(dirname "$0")/.."
SSH="ssh vali@$VALI_GPU_HOST"
DIENSTE="$*"
$SSH 'mkdir -p ~/kanzlei/bin'
tar -C vali-gpu --exclude=modelle -cf - . | $SSH 'tar -C ~/kanzlei -xf -'
tar -cf - bin/neue-geheimnisse.sh bin/openfga-einrichten.sh | $SSH 'tar -C ~/kanzlei -xf -'
$SSH 'set -e; cd ~/kanzlei
[ -e .env ] || /bin/bash bin/neue-geheimnisse.sh
sudo docker compose up -d '"$DIENSTE"' 2>&1 | tail -6
# Ollama-Einstellungen (gemeinsames Kontextfenster, siehe Runbook); Neustart nur bei Aenderung
if ! sudo cmp -s ollama/override.conf /etc/systemd/system/ollama.service.d/override.conf; then
  sudo install -D -m 644 ollama/override.conf /etc/systemd/system/ollama.service.d/override.conf
  sudo systemctl daemon-reload && sudo systemctl restart ollama
fi
# compose startet ghost-transcriber ggf. neu: die Modellsteuerung gleicht den Zustand wieder an (nie beide Seiten geladen)
sudo systemctl restart modellsteuerung 2>/dev/null || true'
