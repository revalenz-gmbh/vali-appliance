#!/bin/bash
# Zeichnet auf dem Proxmox-Host auf, wohin die VMs buero (.94) und vali-gpu (.116) ausserhalb des Buero-Netzes
# verbinden (Ziel nicht 192.168.0.0/16) und welche Namen sie per DNS erfragen.
# Gefiltert wird ueber die MAC-Adressen der VMs, damit IPv4 UND IPv6 erfasst werden (die VMs haben globale IPv6-Adressen).
# Aufruf auf dem Host: ausgehend-aufzeichnen.sh <Sekunden> <Ausgabeverzeichnis>
set -euo pipefail
SEK=${1:-300}; OUT=${2:-/root/autarkie}
mkdir -p "$OUT"
command -v tcpdump >/dev/null || DEBIAN_FRONTEND=noninteractive apt-get install -y -qq tcpdump >/dev/null
VMS='(ether src bc:24:11:11:55:ab or ether src bc:24:11:40:a9:1c)'
LOKAL='not dst net 192.168.0.0/16 and not dst net 10.0.0.0/8 and not dst net 224.0.0.0/4 and not dst net 169.254.0.0/16 and not dst net fe80::/10 and not dst net ff00::/8 and not dst net fc00::/7 and not dst net 2003:a:f03:3200::/64'
timeout "$SEK" tcpdump -nn -q -l -i vmbr0 "$VMS and (ip or ip6) and $LOKAL" > "$OUT/ausgehend.txt" 2>/dev/null &
timeout "$SEK" tcpdump -nn -l -i vmbr0 "$VMS and udp dst port 53" > "$OUT/dns.txt" 2>/dev/null &
wait
echo "Ziele ausserhalb des Buero-Netzes:"; awk '{print $5}' "$OUT/ausgehend.txt" | sed -E 's/\.[0-9]+:$//' | sort | uniq -c | sort -rn | head -20
echo "DNS-Namen:"; grep -oE '[A-Za-z]+\? [A-Za-z0-9._-]+' "$OUT/dns.txt" | awk '{print $2}' | sort | uniq -c | sort -rn | head -30
