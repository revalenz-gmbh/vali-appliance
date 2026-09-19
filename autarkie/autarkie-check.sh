#!/usr/bin/env bash
set -euo pipefail
HIER="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DURATION=60
ALLOWLIST="$HIER/allowlist.conf"
OUTDIR="/var/log/autarkie-check"
IFACE="any"

while getopts "d:a:o:" opt; do
  case "$opt" in
    d) DURATION="$OPTARG" ;;
    a) ALLOWLIST="$OPTARG" ;;
    o) OUTDIR="$OPTARG" ;;
    *) echo "Usage: $0 [-d duration_seconds] [-a allowlist.conf] [-o outdir]" >&2; exit 2 ;;
  esac
done

# Das ganze Skript laeuft laut RUNBOOK.md bereits unter sudo - kein
# eigenes "sudo mkdir" noetig (und keine widerspruechliche Annahme, ob nur
# dieser eine Befehl privilegiert ist).
mkdir -p "$OUTDIR"
STAMP=$(date +%Y%m%d-%H%M%S)
OBSERVED="$OUTDIR/observed-$STAMP.tsv"
REPORT="$OUTDIR/report-$STAMP.txt"

if ! "$HIER/capture-outbound.sh" -i "$IFACE" -d "$DURATION" -o "$OBSERVED"; then
  echo "Aufnahme fehlgeschlagen - Pruefung NICHT aussagekraeftig (siehe Fehler oben)." >&2
  exit 2
fi

set +e
"$HIER/classify-connections.sh" "$ALLOWLIST" "$OBSERVED" "$REPORT"
rc=$?
set -e

# Herkunftsnachweis voranstellen: das Bericht-Artefakt soll auch fuer eine
# spaetere/externe Pruefung nachvollziehbar sein, OHNE classify-connections.sh
# anzufassen (das bleibt eigenstaendig testbar/aufrufbar ohne Header).
PROVENANCE=$(mktemp)
{
  echo "# Herkunftsnachweis"
  echo "# Geraet: $(hostname)"
  echo "# Erfassungs-Interface: $IFACE"
  echo "# Erfassungsdauer: ${DURATION}s"
  echo "# Zeitstempel: $(date -Is)"
  echo "# Positivliste: $ALLOWLIST (sha256: $(sha256sum "$ALLOWLIST" | cut -d' ' -f1))"
  echo "#"
} > "$PROVENANCE"
cat "$PROVENANCE" "$REPORT" > "$REPORT.tmp" && mv "$REPORT.tmp" "$REPORT"
rm -f "$PROVENANCE"

echo "Bericht: $REPORT"
cat "$REPORT"
exit "$rc"
