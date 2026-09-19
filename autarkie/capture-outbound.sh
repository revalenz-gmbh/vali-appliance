#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 [-i interface] [-d duration_seconds] [-o output.tsv]" >&2
  echo "  -i interface: Standard 'any' (alle Interfaces, auch Zweit-NICs)." >&2
  echo "                Nur einschraenken, wenn wirklich nur ein Interface" >&2
  echo "                relevant ist." >&2
  exit 2
}

[ "$(id -u)" -eq 0 ] || { echo "Muss als root laufen (sudo) - tcpdump braucht CAP_NET_RAW." >&2; exit 2; }

IFACE="any"
DURATION=60
OUT="/tmp/autarkie-observed-$(date +%Y%m%d-%H%M%S).tsv"

while getopts "i:d:o:" opt; do
  case "$opt" in
    i) IFACE="$OPTARG" ;;
    d) DURATION="$OPTARG" ;;
    o) OUT="$OPTARG" ;;
    *) usage ;;
  esac
done

command -v tcpdump >/dev/null || { echo "tcpdump fehlt (apt install tcpdump)" >&2; exit 2; }

# Speicherplatz-Wache: TMP_RAW sammelt das gesamte gefilterte Rohmaterial
# unaggregiert, solange die Aufnahme laeuft (das RUNBOOK empfiehlt bis zu
# 48h). Ohne Wache koennte ein langer Lauf die Platte fuellen, waehrend
# er scheinbar "die Autarkie belegt" - lieber vorher laut abbrechen.
MIN_FREE_KB=1048576
avail_kb=$(df -Pk /tmp | awk 'NR==2 {print $4}')
if [ -z "$avail_kb" ] || [ "$avail_kb" -lt "$MIN_FREE_KB" ]; then
  echo "Zu wenig freier Speicher unter /tmp (${avail_kb:-?} KB, benoetigt mind. ${MIN_FREE_KB} KB) - Aufnahme abgebrochen, bevor die Platte volllaeuft." >&2
  exit 2
fi

echo "Erfasse ${DURATION}s ausgehenden Verkehr auf ${IFACE} ..." >&2

TMP_RAW=$(mktemp)
TMP_ERR=$(mktemp)
trap 'rm -f "$TMP_RAW" "$TMP_ERR"' EXIT

# Filter ist IP-Versions-uebergreifend: das reine tcp[tcpflags]-SYN-Idiom
# ist ein IPv4-spezifisches BPF-Idiom (kein IPv6-Zweig im kompilierten
# Programm - mit `tcpdump -d` nachvollziehbar). ufw erlaubt ausgehendes
# TCP/443 auch ueber IPv6 (Ubuntu: IPV6=yes per Default), darum wuerde
# IPv6-TCP sonst komplett unsichtbar bleiben. Fuer IPv6 werden deshalb ALLE
# TCP-Pakete erfasst (nicht nur SYN, da das Nachschlagen der TCP-Flags bei
# IPv6 durch Extension Header nicht immer zuverlaessig moeglich ist) - der
# nachfolgende `sort -u` dampft das wieder auf eindeutige Ziele ein. Das ist
# groberkoernig als die IPv4-Seite (dedupliziert pro Ziel statt pro neuer
# Verbindung), aber bewusst in Kauf genommen, um IPv6-TCP ueberhaupt zu sehen.
FILTER='((ip and tcp and tcp[tcpflags] & tcp-syn != 0 and tcp[tcpflags] & tcp-ack == 0) or (ip6 and tcp)) or udp'

set +e
timeout "$((DURATION + 2))" tcpdump -i "$IFACE" -n -q -tt -U -Q out "$FILTER" \
  > "$TMP_RAW" 2>"$TMP_ERR" &
TCPDUMP_PID=$!
sleep "$DURATION"
kill "$TCPDUMP_PID" 2>/dev/null || true
wait "$TCPDUMP_PID"
TCPDUMP_RC=$?
set -e

# tcpdump gibt beim geordneten Beenden (SIGTERM/SIGINT) eine
# Paketstatistik auf stderr aus ("N packets captured ..."). Das ist der
# einzige verlaessliche Beleg, dass die Aufnahme tatsaechlich lief - ohne
# diese Pruefung wuerde JEDER Fehlschlag (falsches Interface, fehlende
# Rechte, Geraet belegt, Absturz) eine leere TSV erzeugen, die
# classify-connections.sh als "0 erlaubt, 0 unerwartet" (Exit 0) meldet -
# nicht von einem echten, sauberen Lauf zu unterscheiden.
if [ "$TCPDUMP_RC" -ne 0 ]; then
  echo "FEHLER: tcpdump ist mit Exit-Code ${TCPDUMP_RC} beendet - Aufnahme NICHT verwertbar:" >&2
  cat "$TMP_ERR" >&2
  exit 2
fi

captured_n=$(grep -E '^[0-9]+ packets captured' "$TMP_ERR" | head -1 | awk '{print $1}' || true)
if [ -z "$captured_n" ]; then
  echo "FEHLER: tcpdump hat keine Paketstatistik ausgegeben - Aufnahme vermutlich fehlgeschlagen:" >&2
  cat "$TMP_ERR" >&2
  exit 2
fi
if [ "$captured_n" -eq 0 ]; then
  echo "FEHLER: tcpdump hat 0 Pakete erfasst - kein plausibler Nachweis (falsches Interface? keine Berechtigung? Geraet ohne Verkehr?). Das ist KEIN sauberer Lauf, sondern ein Fehlschlag:" >&2
  cat "$TMP_ERR" >&2
  exit 2
fi

awk '
  /UDP/ { proto="udp" }
  !/UDP/ { proto="tcp" }
  {
    for (i=1; i<=NF; i++) {
      if ($i == ">") {
        dst=$(i+1)
        sub(/:$/, "", dst)
        n=split(dst, a, ".")
        port=a[n]
        ip=substr(dst, 1, length(dst)-length(port)-1)
        if (port ~ /^[0-9]+$/) print proto "\t" port "\t" ip
      }
    }
  }
' "$TMP_RAW" | sort -u | while IFS=$'\t' read -r proto port ip; do
  hostname=$(getent hosts "$ip" 2>/dev/null | awk '{print $2}' | head -1) || true
  printf '%s\t%s\t%s\t%s\n' "$proto" "$port" "$ip" "${hostname:-}"
done > "$OUT"

echo "Beobachtung geschrieben: $OUT ($(wc -l < "$OUT") eindeutige Ziele, ${captured_n} Pakete erfasst)" >&2
