#!/usr/bin/env python3
"""Prueft den Anmeldepfad Nextcloud-OIDC -> oauth2-proxy -> Caddy -> Header X-Authentik-Username.

Aufruf: TESTANWALT_PASSWORT=... pruefe_anmeldepfad.py <LAN-IP der buero> [root.crt]
Die Namen *.buero.intern werden in diesem Prozess auf die angegebene IP abgebildet,
auf dem pruefenden Rechner ist kein DNS-Eintrag noetig.
"""
import os
import re
import socket
import sys
from pathlib import Path

import requests

IP = sys.argv[1]
ROOT = sys.argv[2] if len(sys.argv) > 2 else str(Path(__file__).parent.parent / "zertifikat" / "root.crt")
USER = os.environ.get("TESTANWALT", "testanwalt")
PASSWORT = os.environ["TESTANWALT_PASSWORT"]
BASIS = "https://vali.buero.intern/"

_orig = socket.getaddrinfo


def _getaddrinfo(host, *args, **kw):
    return _orig(IP if str(host).endswith(".buero.intern") else host, *args, **kw)


socket.getaddrinfo = _getaddrinfo
fehler = 0


def pruefe(name, ok, detail=""):
    global fehler
    print(("PASS " if ok else "FAIL ") + name + (f" -> {detail}" if detail and not ok else ""))
    fehler += 0 if ok else 1


def neue_sitzung():
    s = requests.Session()
    s.verify = ROOT
    return s


def anmelden(s):
    """Voller Code-Ablauf: vali/ -> oauth2/start -> Nextcloud-Login -> zurueck nach vali/."""
    r = s.get(BASIS, allow_redirects=True, timeout=30)
    if "login" in r.url and "requesttoken" in r.text:
        tok = re.search(r'data-requesttoken="([^"]+)"', r.text).group(1)
        r = s.post(r.url, data={"user": USER, "password": PASSWORT, "timezone": "Europe/Berlin",
                                "timezone_offset": "2", "requesttoken": tok},
                   headers={"Origin": "https://cloud.buero.intern", "Referer": r.url},  # wie ein Browser
                   allow_redirects=True, timeout=30)
    # die oidc-App leitet nach der Anmeldung per <meta refresh> weiter (ein Browser folgt dem von selbst)
    for _ in range(3):
        m = re.search(r'<meta http-equiv="refresh" content="0;url=([^"]+)"', r.text)
        if not m:
            break
        r = s.get(requests.compat.urljoin(r.url, m.group(1).replace("&amp;", "&")), allow_redirects=True, timeout=30)
    return r


# (a) ohne Sitzung: Weiterleitung auf die Anmeldung, nie 200
s0 = neue_sitzung()
r = s0.get(BASIS, allow_redirects=False, timeout=30)
pruefe("a ohne Sitzung wird weitergeleitet", r.status_code in (301, 302, 303), r.status_code)
pruefe("a Weiterleitung fuehrt nicht ins Backend", "X-Authentik" not in r.text)

# (c1) eingeschleuster Header ohne Sitzung hilft nicht
r = s0.get(BASIS, headers={"X-Authentik-Username": "admin"}, allow_redirects=False, timeout=30)
pruefe("c ohne Sitzung: eingeschleuster Header ergibt keinen Zugang", r.status_code in (301, 302, 303), r.status_code)

# (a2) die API ist ohne Sitzung ebenfalls nicht erreichbar
r = s0.get(BASIS + "api/v1/me", allow_redirects=False, timeout=30)
pruefe("a die API leitet ohne Sitzung um", r.status_code in (301, 302, 303), r.status_code)

# (b) mit Sitzung des Testanwalts
s = neue_sitzung()
r = anmelden(s)
pruefe("b Anmeldung endet im Vali-Frontend", r.status_code == 200 and "text/html" in r.headers.get("content-type", ""), f"{r.status_code} {r.url}")
me = s.get(BASIS + "api/v1/me", timeout=30)
pruefe("b Backend kennt den Benutzer testanwalt", me.status_code == 200 and me.json().get("username") == USER, f"{me.status_code} {me.text[:120]}")

# (c2) eingeschleuster Header mit Sitzung: das Backend sieht trotzdem nur den echten Benutzer
r = s.get(BASIS + "api/v1/me", headers={"X-Authentik-Username": "admin", "X-Authentik-Groups": "admin"}, timeout=30)
d = r.json() if r.status_code == 200 else {}
pruefe("c mit Sitzung: eingeschleuster Header wird ueberschrieben", d.get("username") == USER, d)
pruefe("c mit Sitzung: eingeschleuste Gruppen kommen nicht an", d.get("groups") == [], d.get("groups"))

# (d) Das Backend ist am Proxy vorbei nicht erreichbar (Firewall von vali-gpu)
try:
    requests.get(f"http://{os.environ['VALI_GPU_HOST']}:8001/api/v1/me", headers={"X-Authentik-Username": "admin"}, timeout=4)
    pruefe("d Backend direkt aus dem Buero-Netz nicht erreichbar", False, "Antwort erhalten")
except requests.exceptions.RequestException:
    pruefe("d Backend direkt aus dem Buero-Netz nicht erreichbar", True)

# (e) alte Authentik-Pfade des Frontends werden auf oauth2-proxy umgelegt
r = s0.get(BASIS + "outpost.goauthentik.io/start?rd=https://vali.buero.intern/", allow_redirects=False, timeout=30)
pruefe("e Authentik-Startpfad leitet auf /oauth2/start", r.status_code in (301, 302) and "/oauth2/start" in r.headers.get("location", ""), r.headers.get("location"))

# (f) Umschaltstatus der Modellsteuerung ist nur mit Sitzung lesbar, und das Frontend zeigt ihn an
r = s0.get(BASIS + "modell/status", allow_redirects=False, timeout=30)
pruefe("f Umschaltstatus ohne Sitzung nicht lesbar", r.status_code in (301, 302, 303), r.status_code)
r = s.get(BASIS + "modell/status", timeout=30)
pruefe("f Umschaltstatus mit Sitzung lesbar", r.status_code == 200 and "wechselt_zu" in r.json(), f"{r.status_code} {r.text[:100]}")
pruefe("f Schreibzugriff auf die Steuerung ist gesperrt", s.post(BASIS + "modell/status", timeout=30).status_code in (404, 405, 422), "POST erreichte die Steuerung")
pruefe("f Frontend enthaelt die Anzeige", 'data-testid="modellwechsel"' in s.get(BASIS, timeout=30).text)
sys.exit(1 if fehler else 0)
