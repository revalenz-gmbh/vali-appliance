#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 <allowlist.conf> <observed.tsv> [report_out]" >&2
  exit 2
}

[ $# -ge 2 ] || usage
ALLOWLIST="$1"
OBSERVED="$2"
REPORT="${3:-/dev/stdout}"

[ -f "$ALLOWLIST" ] || { echo "Positivliste nicht gefunden: $ALLOWLIST" >&2; exit 2; }
[ -f "$OBSERVED" ] || { echo "Beobachtungsdatei nicht gefunden: $OBSERVED" >&2; exit 2; }

allowed_count=0
unexpected_count=0

{
  echo "# Autarkie-Klassifizierung $(date -Is)"
  echo "# proto/port  dst_ip  hostname  -> urteil (grund)"
} > "$REPORT"

while IFS=$'	' read -r proto port dst_ip hostname || [ -n "$proto" ]; do
  [ -z "$proto" ] && continue
  key="${proto}/${port}"

  match_line=$(awk -F'\t' -v k="$key" '$1==k {print; exit}' "$ALLOWLIST")

  if [ -z "$match_line" ]; then
    echo "${key}  ${dst_ip}  ${hostname:-?}  -> UNERWARTET (Port/Protokoll nicht in Positivliste)" >> "$REPORT"
    unexpected_count=$((unexpected_count+1))
    continue
  fi

  purpose=$(echo "$match_line" | cut -f2)
  hosts=$(echo "$match_line" | cut -f3)

  if [ "$hosts" = "any" ]; then
    echo "${key}  ${dst_ip}  ${hostname:-?}  -> ERLAUBT (${purpose})" >> "$REPORT"
    allowed_count=$((allowed_count+1))
    continue
  fi

  matched=""
  IFS=',' read -ra allowed_hosts <<< "$hosts"
  for h in "${allowed_hosts[@]}"; do
    # Anschlag an einer Label-Grenze verankert (exakter Hostname oder
    # ".$h"-Suffix), NICHT als Teilstring irgendwo im String - sonst
    # wuerden z.B. "github.com.exfil.attacker.net" oder
    # "stealgithub.commercial.evil.io" faelschlich als github.com
    # durchgehen (der Reverse-DNS-Hostname eines Angreifers ist frei waehlbar).
    if [[ "$hostname" == "$h" || "$hostname" == *".$h" ]]; then
      matched="$h"
      break
    fi
  done

  if [ -n "$matched" ]; then
    echo "${key}  ${dst_ip}  ${hostname:-?}  -> ERLAUBT (${purpose}, passt zu ${matched})" >> "$REPORT"
    allowed_count=$((allowed_count+1))
  else
    echo "${key}  ${dst_ip}  ${hostname:-?}  -> UNERWARTET (Hostname passt zu keinem Eintrag der Positivliste: ${hosts})" >> "$REPORT"
    unexpected_count=$((unexpected_count+1))
  fi
done < "$OBSERVED"

{
  echo "---"
  echo "Ergebnis: ${allowed_count} erlaubt, ${unexpected_count} unerwartet"
} >> "$REPORT"

if [ "$unexpected_count" -gt 0 ]; then
  exit 1
fi
exit 0
