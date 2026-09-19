#!/usr/bin/env bash
set -euo pipefail
HIER="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ALLOWLIST="${1:-$HIER/allowlist.conf}"

command -v ufw >/dev/null || { echo "ufw fehlt (apt install ufw)" >&2; exit 2; }
[ -f "$ALLOWLIST" ] || { echo "Positivliste nicht gefunden: $ALLOWLIST" >&2; exit 2; }

echo "Setze Default-Deny (ausgehend UND eingehend) ..."
ufw --force reset >/dev/null
ufw default deny incoming
ufw default deny outgoing

echo "Erlaube eingehend: SSH (Wartung durch IT-Dienstleister) ..."
ufw allow in 22/tcp comment 'SSH-Wartung'

echo "Erlaube ausgehend gemaess ${ALLOWLIST} ..."
while IFS=$'	' read -r key purpose _hosts; do
  proto="${key%/*}"
  port="${key##*/}"
  ufw allow out "${port}/${proto}" comment "$purpose"
done < <(grep -vE '^\s*#|^\s*$' "$ALLOWLIST")

ufw logging on
ufw --force enable

echo "Firewall aktiv. Status:"
ufw status verbose
