#!/usr/bin/env python3
"""Durchlauf Diktat -> Transkript -> Protokoll -> Nextcloud als Testanwalt (Abnahme, Task 9).

Aufruf: TESTANWALT_PASSWORT=... NC_APP_PASSWORT=... pruefe_diktat_e2e.py <LAN-IP der buero> <audio.mp3> [root.crt]
Voraussetzung: Nutzer testanwalt in Nextcloud; App-Passwort z. B. per
  occ user:auth-tokens:add testanwalt e2e
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
USER = "testanwalt"
BASIS = "https://vali.buero.intern/"
FRIST_S = int(os.environ.get("E2E_FRIST_S", "900"))
t.namen_auf_ip(IP)
fehler = 0


def pruefe(name, ok, detail=""):
    global fehler
    print(("PASS " if ok else "FAIL ") + name + (f" -> {detail}" if detail and not ok else ""), flush=True)
    fehler += 0 if ok else 1
    return ok


s = t.neue_sitzung(ROOT)
r = t.nextcloud_anmelden(s, s.get(BASIS, allow_redirects=True, timeout=30), USER, os.environ["TESTANWALT_PASSWORT"])
if not pruefe("Anmeldung", s.get(BASIS + "api/v1/me", timeout=30).status_code == 200):
    sys.exit(1)

# App-Passwort hinterlegen (Erstanmeldung) -- ohne diesen Schritt kann Vali nicht nach Nextcloud schreiben
r = s.put(BASIS + "api/v1/me/nextcloud", json={"app_password": os.environ["NC_APP_PASSWORT"]}, timeout=60)
pruefe("App-Passwort gespeichert", r.status_code == 200, f"{r.status_code} {r.text[:200]}")

name = f"e2e-{int(time.time())}"
r = s.post(BASIS + "api/v1/projects", json={"name": name, "project_type": "legal"}, timeout=60)
pruefe("Projekt angelegt", r.status_code == 201, f"{r.status_code} {r.text[:200]}")
slug = r.json().get("slug") or r.json().get("project_id") or name

with open(AUDIO, "rb") as f:
    r = s.post(BASIS + "api/v1/transcribe", files={"file": (Path(AUDIO).name, f, "audio/mpeg")},
               data={"project_id": slug, "language": "de", "audio_type": "meeting", "model": "agent-sekretaer:latest"},
               timeout=600)
if not pruefe("Upload angenommen", r.status_code == 201, f"{r.status_code} {r.text[:300]}"):
    sys.exit(1)
job = r.json().get("job_id")
print("Job", job, flush=True)

ende = time.monotonic() + FRIST_S
status = ""
while time.monotonic() < ende:
    j = s.get(BASIS + f"api/v1/jobs/{job}", timeout=30).json()
    status = j.get("status")
    if status in ("completed", "failed", "error"):
        break
    time.sleep(10)
pruefe("Transkription fertig", status == "completed", status)
if status != "completed":
    sys.exit(1)
text = s.get(BASIS + f"api/v1/jobs/{job}/transcript", timeout=30).text.lower()
pruefe("Transkript enthaelt Inhalt des Diktats", "mietvertrag" in text or "kaution" in text, text[:200])

r = s.post(BASIS + f"api/v1/jobs/{job}/protocol", data={"agent": "agent-sekretaer:latest"}, timeout=60)
pruefe("Protokoll angestossen", r.status_code == 201, f"{r.status_code} {r.text[:200]}")
ende = time.monotonic() + FRIST_S
pstatus = ""
while time.monotonic() < ende:
    p = s.get(BASIS + f"api/v1/jobs/{job}/protocol", timeout=30).json()
    pstatus = p.get("status", "")
    if pstatus in ("completed", "failed", "error"):
        break
    time.sleep(10)
pruefe("Protokoll fertig", pstatus == "completed", p)

# Ergebnis in Nextcloud: nach dem Anstossen schreibt Vali das DOCX in Vali/<Projekt>/
dav = requests.request("PROPFIND", f"https://cloud.buero.intern/remote.php/dav/files/{USER}/Vali/{slug}/",
                       auth=(USER, os.environ["NC_APP_PASSWORT"]), headers={"Depth": "infinity"},
                       verify=ROOT, timeout=60)
gefunden = [l for l in dav.text.split("<d:href>") if ".docx" in l]
pruefe("Protokoll als DOCX in Nextcloud", dav.status_code == 207 and bool(gefunden), f"{dav.status_code}")
sys.exit(1 if fehler else 0)
