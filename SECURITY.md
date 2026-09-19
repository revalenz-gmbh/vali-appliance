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

## Schluessel importieren

```bash
gpg --import KEYS.asc
```

## Was zu tun ist, wenn eine Signatur nicht passt

Ein Release, dessen Tag-Signatur nicht gegen diesen Fingerabdruck prueft,
NIEMALS einspielen -- unabhaengig davon, wie dringend das Update wirkt.
Bei Zweifeln: technik@revalenz.de kontaktieren, bevor irgendetwas
eingespielt wird.
