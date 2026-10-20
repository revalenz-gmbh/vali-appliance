#!/bin/bash
# Prueft Namensdienst und Eingang der Appliance von einem Client im Buero-Netz.
# Aufruf: pruefe-eingang.sh <LAN-IP der buero> [Wurzelzertifikat]
. "$(dirname "$0")/umgebung.sh"
set -u
IP=${1:?LAN-IP der buero angeben}
ROOT=${2:-$(dirname "$0")/../zertifikat/root.crt}
FEHLER=0
for NAME in vali cloud chat; do
  GOT=$(dig +short +time=3 +tries=1 @"$IP" "$NAME.buero.intern" | grep -v "^;;" | head -1)
  if [ "$GOT" = "$IP" ]; then echo "PASS dns $NAME.buero.intern -> $GOT"
  else echo "FAIL dns $NAME.buero.intern -> '${GOT}' (erwartet $IP)"; FEHLER=1; fi
  CODE=$(curl -s -m 8 -o /dev/null -w '%{http_code}' --cacert "$ROOT" \
         --resolve "$NAME.buero.intern:443:$IP" "https://$NAME.buero.intern/")
  case "$CODE" in
    200|302) echo "PASS https $NAME.buero.intern -> $CODE" ;;
    *)       echo "FAIL https $NAME.buero.intern -> $CODE"; FEHLER=1 ;;
  esac
done
# ausserhalb der Zone darf der Namensdienst nicht antworten (keine allgemeine DNS-Rolle)
AUSSEN=$(dig +short +time=3 +tries=1 @"$IP" example.com | grep -v "^;;" | head -1)
if [ -z "$AUSSEN" ]; then echo "PASS dns example.com bleibt unbeantwortet"
else echo "FAIL dns example.com -> $AUSSEN"; FEHLER=1; fi

# Adresswechsel: nur mit IP_WECHSEL=1 (aendert kurz die Adresse der buero, Zugang ueber die interne Bruecke)
if [ "${IP_WECHSEL:-0}" = "1" ]; then
  SSH="ssh -J root@$PVE_HOST vali@10.77.0.2"
  NEU=${NEUE_ADRESSE:?NEUE_ADRESSE setzen (freie Adresse im Buero-Netz fuer den Wechseltest)}
  $SSH "sudo ip addr del $IP/24 dev eth0; sudo ip addr add $NEU/24 dev eth0; sudo systemctl restart dnsmasq"
  GOT=$(dig +short +time=3 +tries=1 @"$NEU" vali.buero.intern | grep -v "^;;" | head -1)
  if [ "$GOT" = "$NEU" ]; then echo "PASS ip-wechsel dnsmasq antwortet mit neuer Adresse $NEU"
  else echo "FAIL ip-wechsel -> '${GOT}' (erwartet $NEU)"; FEHLER=1; fi
  # zurueck: DHCP holt die Adresse wieder; der Timer muss dnsmasq nachziehen
  $SSH "sudo ip addr del $NEU/24 dev eth0; sudo netplan apply"
  for i in $(seq 1 14); do
    sleep 3
    GOT=$(dig +short +time=2 +tries=1 @"$IP" vali.buero.intern | grep -v "^;;" | head -1)
    [ "$GOT" = "$IP" ] && break
  done
  if [ "$GOT" = "$IP" ]; then echo "PASS ip-wechsel Rueckkehr auf $IP durch den Timer"
  else echo "FAIL ip-wechsel Rueckkehr -> '${GOT}'"; FEHLER=1; fi
fi
exit $FEHLER
