#!/bin/bash
# Erzeugt .env aus .env.beispiel: jeder Wert ZUFALL wird durch eine Zufallszeichenfolge ersetzt, FERNET durch einen Fernet-Schluessel.
# Aufruf im Verzeichnis mit .env.beispiel. Eine vorhandene .env wird NICHT ueberschrieben.
set -euo pipefail
[ -e .env ] && { echo ".env existiert bereits, nichts zu tun"; exit 0; }
umask 077
while IFS= read -r zeile; do
  if [[ "$zeile" == *=ZUFALL ]]; then echo "${zeile%ZUFALL}$(openssl rand -hex 16)"
  elif [[ "$zeile" == *=FERNET ]]; then echo "${zeile%FERNET}$(openssl rand -base64 32 | tr '+/' '-_')"   # Fernet-Schluessel (urlsafe base64, 32 Byte)
  else echo "$zeile"; fi
done < .env.beispiel > .env
echo ".env erzeugt ($(grep -c . .env) Zeilen)"
