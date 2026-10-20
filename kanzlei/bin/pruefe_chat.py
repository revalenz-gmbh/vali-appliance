#!/usr/bin/env python3
"""Prueft Open WebUI: nur Anmeldung ueber Nextcloud, danach sind die Modelle sichtbar.

Aufruf: TESTANWALT_PASSWORT=... pruefe_chat.py <LAN-IP der buero> [root.crt]
"""
import os
import re
import socket
import sys
from pathlib import Path

import requests

IP = sys.argv[1]
ROOT = sys.argv[2] if len(sys.argv) > 2 else str(Path(__file__).parent.parent / "zertifikat" / "root.crt")
USER = "testanwalt"
PASSWORT = os.environ["TESTANWALT_PASSWORT"]
BASIS = "https://chat.buero.intern"

_orig = socket.getaddrinfo
socket.getaddrinfo = lambda h, *a, **k: _orig(IP if str(h).endswith(".buero.intern") else h, *a, **k)
fehler = 0


def pruefe(name, ok, detail=""):
    global fehler
    print(("PASS " if ok else "FAIL ") + name + (f" -> {detail}" if detail and not ok else ""))
    fehler += 0 if ok else 1


s = requests.Session()
s.verify = ROOT

# Konfiguration: kein lokales Anmeldeformular, Nextcloud als OAuth-Anbieter
cfg = s.get(BASIS + "/api/config", timeout=30).json()
pruefe("Anmeldeformular ist aus", cfg.get("features", {}).get("enable_login_form") is False, cfg.get("features"))
pruefe("Nextcloud ist OAuth-Anbieter", "oidc" in cfg.get("oauth", {}).get("providers", {}), cfg.get("oauth"))

# Anmeldung ueber Nextcloud (wie ein Browser, inkl. meta refresh der oidc-App)
r = s.get(BASIS + "/oauth/oidc/login", allow_redirects=True, timeout=30)
if "/login" in r.url and "requesttoken" in r.text:
    tok = re.search(r'data-requesttoken="([^"]+)"', r.text).group(1)
    r = s.post(r.url, data={"user": USER, "password": PASSWORT, "timezone": "Europe/Berlin", "timezone_offset": "2",
                            "requesttoken": tok},
               headers={"Origin": "https://cloud.buero.intern", "Referer": r.url}, allow_redirects=True, timeout=30)
for _ in range(4):
    m = re.search(r'<meta http-equiv="refresh" content="0;url=([^"]+)"', r.text)
    if not m:
        break
    r = s.get(requests.compat.urljoin(r.url, m.group(1).replace("&amp;", "&")), allow_redirects=True, timeout=30)
pruefe("Anmeldung endet in Open WebUI", r.url.startswith(BASIS), r.url)
me = s.get(BASIS + "/api/v1/auths/", timeout=30)
pruefe("Open WebUI kennt den Benutzer", me.status_code == 200 and "testanwalt" in me.text.lower(), f"{me.status_code} {me.text[:120]}")
mod = s.get(BASIS + "/api/models", timeout=60)
namen = [m.get("id") for m in mod.json().get("data", [])] if mod.status_code == 200 else []
pruefe("Modell gemma4:31b ist sichtbar", "gemma4:31b" in namen, namen)
sys.exit(1 if fehler else 0)
