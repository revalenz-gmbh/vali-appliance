#!/usr/bin/env bash
set -uo pipefail
HIER="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$HIER/../classify-connections.sh"
FIX="$HIER/fixtures"
fails=0

assert_exit() {
  local desc="$1" expected="$2" actual="$3"
  if [ "$expected" != "$actual" ]; then
    echo "FEHLGESCHLAGEN: $desc (erwartet exit $expected, bekam $actual)"
    fails=$((fails+1))
  else
    echo "ok: $desc"
  fi
}

assert_contains() {
  local desc="$1" needle="$2" haystack_file="$3"
  if grep -qF "$needle" "$haystack_file"; then
    echo "ok: $desc"
  else
    echo "FEHLGESCHLAGEN: $desc (erwarteter Text nicht im Bericht: $needle)"
    fails=$((fails+1))
  fi
}

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

"$SCRIPT" "$FIX/allowlist-basic.conf" "$FIX/observed-all-allowed.tsv" "$tmpdir/report-ok.txt"
rc=$?
assert_exit "alles erlaubt -> exit 0" 0 "$rc"
assert_contains "DNS als ERLAUBT markiert" "ERLAUBT (dns)" "$tmpdir/report-ok.txt"
assert_contains "github.com-HTTPS als ERLAUBT markiert" "ERLAUBT (release-feed, passt zu github.com)" "$tmpdir/report-ok.txt"

"$SCRIPT" "$FIX/allowlist-basic.conf" "$FIX/observed-with-violation.tsv" "$tmpdir/report-fail.txt"
rc=$?
assert_exit "ein Verstoss -> exit 1" 1 "$rc"
assert_contains "Port 22 als UNERWARTET markiert" "tcp/22" "$tmpdir/report-fail.txt"
assert_contains "Verstoss-Grund genannt" "UNERWARTET (Port/Protokoll nicht in Positivliste)" "$tmpdir/report-fail.txt"

"$SCRIPT" "$FIX/allowlist-basic.conf" "$FIX/observed-no-trailing-newline.tsv" "$tmpdir/report-no-newline.txt"
rc=$?
assert_exit "letzte Zeile ohne Newline -> exit 1" 1 "$rc"
assert_contains "tcp/22 bei fehlender Newline erkannt" "tcp/22" "$tmpdir/report-no-newline.txt"
assert_contains "Verstoss bei fehlender Newline gemeldet" "UNERWARTET (Port/Protokoll nicht in Positivliste)" "$tmpdir/report-no-newline.txt"

"$SCRIPT" "$FIX/allowlist-basic.conf" "$FIX/observed-hostname-spoofing.tsv" "$tmpdir/report-spoofing.txt"
rc=$?
assert_exit "gefaelschte Hostnamen -> exit 1" 1 "$rc"
assert_contains "github.com.exfil.attacker.net NICHT als ERLAUBT durchgelassen (Praefix-Spoofing)" "198.51.100.9  github.com.exfil.attacker.net  -> UNERWARTET" "$tmpdir/report-spoofing.txt"
assert_contains "stealgithub.commercial.evil.io NICHT als ERLAUBT durchgelassen (Label-Grenzen-Spoofing)" "198.51.100.10  stealgithub.commercial.evil.io  -> UNERWARTET" "$tmpdir/report-spoofing.txt"

echo "---"
if [ "$fails" -gt 0 ]; then
  echo "$fails Test(s) fehlgeschlagen"
  exit 1
fi
echo "Alle Tests bestanden"
