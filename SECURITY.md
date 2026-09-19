# Signaturpruefung

Jedes Release dieses Repos ist ein signierter Git-Tag. Bevor ein Update
eingespielt wird, MUSS die Signatur gegen den unten genannten Fingerabdruck
geprueft werden -- siehe `UPDATE-RUNBOOK.md` fuer die konkreten Schritte.

## Oeffentlicher Schluessel

- **Identitaet:** revalenz Vali-Appliance Releases <technik@revalenz.de>
- **Fingerabdruck:** `5F6E 6D90 7617 F899 1135  D184 7B1C 6E16 4080 1E3F`
- **Key-ID (lang):** `7B1C6E1640801E3F`
- **Typ:** RSA 4096
- **Gueltig bis:** 2026-09-19 + 2 Jahre (bewusst befristet -- Verlaengerung
  wird rechtzeitig vor Ablauf hier vermerkt)
- **Datei in diesem Repo:** [`KEYS.asc`](KEYS.asc)

Der Fingerabdruck ist zusaetzlich auf revalenz.de veroeffentlicht (zweite,
unabhaengige Quelle -- ein kompromittiertes GitHub-Konto allein soll keine
unbemerkt falsch signierten Releases durchsetzen koennen). **Vergleiche
beide Quellen, wenn du diesem Repo zum ersten Mal vertraust.**

## Schluessel importieren und Signatur verifizieren

Jedes Release ist ein signierter Git-Tag. Der Schluessel muss einmalig
importiert und seine Identitaet verifiziert werden:

```bash
gpg --import KEYS.asc
gpg --fingerprint technik@revalenz.de
```

Vergleiche den angezeigten Fingerabdruck gegen den oben dokumentierten
Wert, sowie gegen die unabhaengige Veroeffentlichung auf
[revalenz.de](https://revalenz.de).

Um bei jedem Update die Signatur zu pruefen:

```bash
git tag -v <tag>   # z.B. git tag -v v0.1.0
```

**Erwartetes Ergebnis:** Die Ausgabe enthaelt eine Zeile mit `Good
signature from` UND die Identitaet enthaelt `technik@revalenz.de`. Eine
Zeile `gpg: WARNING: This key is not certified with a trusted signature!`
ist NORMAL — das Vertrauen kommt hier aus dem Out-of-Band-Vergleich des
Fingerabdrucks, nicht aus GPGs eigenem Web-of-Trust.

## Was zu tun ist, wenn eine Signatur nicht passt

Ein Release, dessen Tag-Signatur nicht gegen diesen Fingerabdruck prueft,
NIEMALS einspielen -- unabhaengig davon, wie dringend das Update wirkt.

Nicht einspielen, wenn:
- Die Ausgabe enthaelt `BAD signature` oder `expired` oder aehnliches
- Es gibt keine Signatur-Zeile ueberhaupt
- Die Identitaet enthaelt nicht `technik@revalenz.de`

Bei Zweifeln oder ungueltig wirkenden Signaturen: technik@revalenz.de
kontaktieren, bevor irgendetwas eingespielt wird.
