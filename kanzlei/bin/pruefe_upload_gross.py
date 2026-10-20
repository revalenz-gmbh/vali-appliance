#!/usr/bin/env python3
"""Prueft, dass eine grosse Aufnahme (z. B. 150 MB vom MP3-Rekorder) ueber beide Wege angenommen wird:
Upload im Vali-Frontend (API) und Ablage im Nextcloud-Ordner Vali/<Projekt>/inbox/.
Die Verarbeitung wird NICHT abgewartet; die angelegten Auftraege werden danach wieder geloescht.

Aufruf: TESTANWALT_PASSWORT=... NC_APP_PASSWORT=... pruefe_upload_gross.py <LAN-IP der buero> <audio.mp3> [root.crt]
"""
import os
import sys
import time
from pathlib import Path

import requests

sys.path.insert(0, str(Path(__file__).parent))
import kanzlei_testlib as t  # noqa: E402

IP, AUDIO = sys.argv[1], sys.argv[2]
ROOT = sys.argv[3] if len(sys.argv) > 3 else str(Path(__file__).parent.parent / "zertifikat" / "root.crt")
USER, BASIS = "testanwalt", "https://vali.buero.intern/"
t.namen_auf_ip(IP)
fehler = 0


def pruefe(name, ok, detail=""):
    global fehler
    print(("PASS " if ok else "FAIL ") + name + (f" -> {detail}" if detail and not ok else ""), flush=True)
    fehler += 0 if ok else 1
    return ok


groesse = os.path.getsize(AUDIO)
print(f"Datei: {groesse / 1e6:.0f} MB", flush=True)
s = t.neue_sitzung(ROOT)
t.nextcloud_anmelden(s, s.get(BASIS, allow_redirects=True, timeout=30), USER, os.environ["TESTANWALT_PASSWORT"])
s.put(BASIS + "api/v1/me/nextcloud", json={"app_password": os.environ["NC_APP_PASSWORT"]}, timeout=60)
name = f"gross-{int(time.time())}"
r = s.post(BASIS + "api/v1/projects", json={"name": name, "project_type": "legal"}, timeout=60)
slug = r.json().get("slug") or name
jobs = []

# Weg 1: Upload im Frontend
t0 = time.monotonic()
with open(AUDIO, "rb") as f:
    r = s.post(BASIS + "api/v1/transcribe", files={"file": (Path(AUDIO).name, f, "audio/mpeg")},
               data={"project_id": slug, "language": "de", "audio_type": "meeting", "model": "agent-sekretaer:latest"}, timeout=900)
if pruefe("Frontend-Upload wird angenommen", r.status_code == 201, f"{r.status_code} {r.text[:200]}"):
    jobs.append(r.json()["job_id"])
print(f"  Dauer {time.monotonic() - t0:.0f} s", flush=True)

# Weg 2: Datei in den Nextcloud-Ordner legen (wie ein Sync-Ordner), Vali holt sie per Inbox-Watcher
dav = f"https://cloud.buero.intern/remote.php/dav/files/{USER}/Vali/{slug}/inbox/"
requests.request("MKCOL", dav, auth=(USER, os.environ["NC_APP_PASSWORT"]), verify=ROOT, timeout=60)
with open(AUDIO, "rb") as f:
    r = requests.put(dav + "inbox-" + Path(AUDIO).name, data=f, auth=(USER, os.environ["NC_APP_PASSWORT"]), verify=ROOT, timeout=900)
pruefe("Ablage im Nextcloud-Ordner (WebDAV PUT)", r.status_code in (201, 204), f"{r.status_code} {r.text[:200]}")
vorher = set(jobs)
gefunden = None
for _ in range(24):  # Inbox-Watcher prueft alle 60 s
    time.sleep(10)
    alle = s.get(BASIS + "api/v1/jobs", timeout=30).json()
    for j in alle.get("jobs", alle if isinstance(alle, list) else []):
        if (j.get("project_id") or j.get("project_slug")) == slug and j.get("job_id") not in vorher:
            gefunden = j["job_id"]
    if gefunden:
        break
pruefe("Inbox-Watcher legt einen Auftrag an", gefunden is not None, "kein neuer Auftrag nach 4 Minuten")
if gefunden:
    jobs.append(gefunden)

for j in jobs:  # aufraeumen: Verarbeitung nicht abwarten
    s.delete(BASIS + f"api/v1/jobs/{j}", timeout=60)
sys.exit(1 if fehler else 0)
