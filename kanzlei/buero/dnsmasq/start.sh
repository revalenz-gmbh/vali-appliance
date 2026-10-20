#!/bin/bash
# Erzeugt die dnsmasq-Konfiguration fuer die Zone buero.intern.
#   ohne Argument:  immer schreiben (vor dem Start von dnsmasq, ExecStartPre)
#   --nachziehen:   nur bei geaenderter Buero-Adresse neu schreiben und dnsmasq neu starten (Timer)
# Alle Namen der Zone zeigen auf die aktuelle Buero-Adresse.
set -euo pipefail
KONF=/etc/dnsmasq.d/buero-intern.conf
# Buero-Adresse = erste globale IPv4-Adresse, ohne interne Bruecke (10.77.0.0/24) und Docker-Netze.
# Bewusst nicht ueber die Standardroute: sie fehlt kurz, wenn DHCP die Adresse wechselt.
IP=$(ip -4 -o addr show scope global \
  | grep -vE ' (docker0|br-[0-9a-f]+|veth[^ ]*) ' \
  | awk '{print $4}' | cut -d/ -f1 | grep -v '^10\.77\.0\.' | head -1 || true)
[ -n "$IP" ] || { echo "keine Buero-Adresse gefunden" >&2; exit 1; }
NEU=$(cat <<EOF
# erzeugt von start.sh, nicht von Hand aendern
bind-interfaces
listen-address=$IP
no-resolv
no-hosts
address=/buero.intern/$IP
EOF
)
if [ "${1:-}" = "--nachziehen" ]; then
  [ "$(cat "$KONF" 2>/dev/null)" = "$NEU" ] && exit 0
  printf '%s\n' "$NEU" > "$KONF"
  systemctl restart dnsmasq
else
  printf '%s\n' "$NEU" > "$KONF"
fi
