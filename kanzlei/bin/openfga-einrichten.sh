#!/bin/bash
# Legt in OpenFGA einen Store und das Berechtigungsmodell an und traegt die IDs in .env ein.
# Aufruf auf vali-gpu im Verzeichnis mit docker-compose.yml und .env. Idempotent.
set -euo pipefail
MODELL=${1:-src/openfga/model.json}
grep -q '^OPENFGA_STORE_ID=.\+' .env && { echo "Store existiert bereits, nichts zu tun"; exit 0; }
API=http://127.0.0.1:8080
STORE=$(curl -sf -X POST "$API/stores" -H 'content-type: application/json' -d '{"name":"vali"}' | python3 -c 'import sys,json;print(json.load(sys.stdin)["id"])')
MODELL_ID=$(curl -sf -X POST "$API/stores/$STORE/authorization-models" -H 'content-type: application/json' --data @"$MODELL" | python3 -c 'import sys,json;print(json.load(sys.stdin)["authorization_model_id"])')
sed -i "s/^OPENFGA_STORE_ID=.*/OPENFGA_STORE_ID=$STORE/;s/^OPENFGA_MODEL_ID=.*/OPENFGA_MODEL_ID=$MODELL_ID/" .env
echo "Store $STORE, Modell $MODELL_ID"
