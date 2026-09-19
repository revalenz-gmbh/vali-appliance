#!/usr/bin/env bash
set -euo pipefail

# Live-Drill gegen eine echte Wegwerf-VM: Firewall gemaess allowlist.conf
# aufsetzen und funktional pruefen, dass die Positivliste tatsaechlich
# durchgesetzt wird (DNS geht, Port 80 nicht). Ersetzt die zwei losen
# Scratch-Skripte (run-tests.sh, test-functional.sh), die vorher
# unversioniert im Worktree-Root lagen und die Ziel-VM hart codiert hatten.
#
# Ziel-Host: erstes Argument, sonst Umgebungsvariable DRILL_VM, sonst die
# zum Zeitpunkt dieses Fix-Waves verfuegbare Wegwerf-VM als Vorgabe -
# damit dieser Nachweis jederzeit gegen eine neue VM wiederholbar bleibt,
# statt aus dem Nichts neu hergeleitet werden zu muessen.
#
# Usage: run-live-drill.sh [user@host]
#        DRILL_VM=user@host run-live-drill.sh

usage() {
  echo "Usage: $0 [user@host]" >&2
  echo "  Ziel-VM auch per Umgebungsvariable DRILL_VM setzbar." >&2
  echo "  Vorgabe: admin@10.20.5.116 (Wegwerf-VM dieses Fix-Waves)." >&2
  exit 2
}

HIER="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUTARKIE_DIR="$(cd "$HIER/../.." && pwd)"

DRILL_VM="${1:-${DRILL_VM:-admin@10.20.5.116}}"
[ -n "$DRILL_VM" ] || usage

echo "=== Ziel: $DRILL_VM ==="

echo "=== Schritt 1: allowlist.conf + setup-firewall.sh kopieren ==="
scp "$AUTARKIE_DIR/allowlist.conf" "$AUTARKIE_DIR/setup-firewall.sh" "$DRILL_VM:/tmp/"
ssh "$DRILL_VM" "chmod +x /tmp/setup-firewall.sh"

echo "=== Schritt 2: setup-firewall.sh ausfuehren (braucht root) ==="
ssh "$DRILL_VM" "sudo /tmp/setup-firewall.sh /tmp/allowlist.conf"

echo "=== Schritt 3: Firewall-Status pruefen ==="
ssh "$DRILL_VM" "sudo ufw status verbose"

echo "=== Schritt 4: Funktionscheck - DNS sollte gehen ==="
ssh "$DRILL_VM" "timeout 5 getent hosts github.com && echo DNS_OK || echo DNS_FEHLGESCHLAGEN"

echo "=== Schritt 5: Funktionscheck - Port 80 sollte blockiert sein (Timeout/Fehler) ==="
ssh "$DRILL_VM" "timeout 5 curl -s -o /dev/null -w '%{http_code}\n' http://example.com || echo PORT80_BLOCKIERT_WIE_ERWARTET"

echo "=== Fertig ==="
