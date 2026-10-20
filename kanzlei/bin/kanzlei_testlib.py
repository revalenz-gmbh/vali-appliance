"""Gemeinsame Hilfen der Pruefskripte: Namensabbildung ohne DNS, Anmeldung bei Nextcloud wie ein Browser."""
import re
import socket

import requests


def namen_auf_ip(ip):
    """Bildet *.buero.intern in diesem Prozess auf die angegebene IP ab (kein DNS-Eintrag noetig)."""
    orig = socket.getaddrinfo
    socket.getaddrinfo = lambda h, *a, **k: orig(ip if str(h).endswith(".buero.intern") else h, *a, **k)


def neue_sitzung(root_crt):
    s = requests.Session()
    s.verify = root_crt
    return s


def folge_meta_refresh(s, r, max_schritte=4):
    """Die oidc-App leitet nach der Anmeldung per <meta refresh> weiter; ein Browser folgt dem von selbst."""
    for _ in range(max_schritte):
        m = re.search(r'<meta http-equiv="refresh" content="0;url=([^"]+)"', r.text)
        if not m:
            break
        r = s.get(requests.compat.urljoin(r.url, m.group(1).replace("&amp;", "&")), allow_redirects=True, timeout=30)
    return r


def nextcloud_anmelden(s, r, benutzer, passwort):
    """r ist eine Antwort, die bei der Nextcloud-Anmeldeseite endet; meldet an und folgt der Weiterleitung."""
    if "/login" in r.url and "requesttoken" in r.text:
        tok = re.search(r'data-requesttoken="([^"]+)"', r.text).group(1)
        r = s.post(r.url, data={"user": benutzer, "password": passwort, "timezone": "Europe/Berlin",
                                "timezone_offset": "2", "requesttoken": tok},
                   headers={"Origin": "https://cloud.buero.intern", "Referer": r.url},
                   allow_redirects=True, timeout=30)
    return folge_meta_refresh(s, r)
