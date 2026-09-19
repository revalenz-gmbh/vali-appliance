# Signaturpruefung

Jedes Release dieses Repos ist ein signierter Git-Tag. Bevor ein Update
eingespielt wird, MUSS die Signatur gegen den unten genannten Fingerabdruck
geprueft werden -- siehe `UPDATE-RUNBOOK.md` fuer die konkreten Schritte.

## Oeffentlicher Schluessel

- **Identitaet:** revalenz Vali-Appliance Releases (verwendnung zum bau
  der vali-appliance) <technik@revalenz.de>
- **Fingerabdruck:** `5F6E 6D90 7617 F899 1135  D184 7B1C 6E16 4080 1E3F`
- **Key-ID (lang):** `7B1C6E1640801E3F`
- **Typ:** RSA 4096
- **Gueltig bis:** 2028-09-18 (bewusst befristet -- Verlaengerung wird
  rechtzeitig vor Ablauf hier vermerkt). Bei einer Verlaengerung bleibt
  der **Fingerabdruck unveraendert** (nur das Ablaufdatum am bestehenden
  Schluessel wird verlaengert) -- genau deshalb ist der Fingerabdruck und
  nicht das Ablaufdatum oder die UID der richtige langfristige
  Pruefanker.
- **Datei in diesem Repo:** [`KEYS.asc`](KEYS.asc)

Der Fingerabdruck soll zusaetzlich auf revalenz.de veroeffentlicht werden
(zweite, unabhaengige Quelle -- ein kompromittiertes GitHub-Konto allein
soll keine unbemerkt falsch signierten Releases durchsetzen koennen) --
**das ist zum Zeitpunkt dieses Schreibens noch nicht geschehen**. Bis
dahin ist `KEYS.asc` in diesem Repo die einzige Quelle. Wer dem Schluessel
zum ersten Mal vertraut und zusaetzliche Sicherheit will: Fingerabdruck
telefonisch oder persoenlich bei technik@revalenz.de erfragen und mit dem
hier hinterlegten Wert vergleichen.

## Schluessel importieren und Signatur verifizieren

Jedes Release ist ein signierter Git-Tag. Der Schluessel muss einmalig
importiert und seine Identitaet verifiziert werden:

```bash
gpg --import KEYS.asc
gpg --fingerprint technik@revalenz.de
```

Vergleiche den angezeigten Fingerabdruck gegen den oben dokumentierten
Wert, sowie -- sobald verfuegbar -- gegen die unabhaengige
Veroeffentlichung auf revalenz.de.

Um bei jedem Update die Signatur zu pruefen, ist der Abgleich gegen den
Fingerabdruck das eigentliche Pass/Fail-Kriterium, nicht das blosse Lesen
von Text in der Ausgabe:

```bash
GPG_STATUS=$(git verify-tag --raw <tag> 2>&1) && \
  printf '%s\n' "$GPG_STATUS" | grep -q \
    '^\[GNUPG:\] VALIDSIG 5F6E6D907617F8991135D1847B1C6E1640801E3F '
```

**Erwartetes Ergebnis:** Exit-Code `0` von diesem Befehl -- das heisst,
`git verify-tag` selbst ist erfolgreich durchgelaufen UND die Statuszeile
`VALIDSIG` beginnt exakt mit diesem Fingerabdruck. Nur dann ist der Tag
tatsaechlich mit dem oben dokumentierten Schluessel signiert.

⚠️ **Zwei Stolperfallen, die genau hier lauern:**
- Das Muster muss am Zeilenanfang verankert sein (`^\[GNUPG:\] VALIDSIG
  ... `, mit Leerzeichen am Ende). Ein unverankertes `grep -q 'VALIDSIG
  <fingerabdruck>'` liesse sich mit einem praeparierten Schluessel
  austricksen, dessen UID selbst den Text `VALIDSIG <fingerabdruck>`
  enthaelt -- das waere kein Nachweis, nur eine Zeichenkette in der
  falschen Zeile.
- `git verify-tag`s eigener Exit-Code muss mitgeprueft werden (`GPG_STATUS=$(...) &&`
  davor), sonst wuerde ein Tag, das mit einem **zurueckgezogenen**
  Schluessel signiert wurde, trotzdem als gueltig durchgehen -- `git
  verify-tag` selbst schlaegt dabei fehl, aber ein reines `grep -q` auf die
  Ausgabe wuerde das nicht bemerken.

Zur menschlichen Gegenkontrolle kann zusaetzlich `git tag -v <tag>`
angeschaut werden (z.B. `git tag -v v0.1.0`): die Ausgabe sollte eine
Zeile mit `Good signature from` enthalten und die Identitaet sollte
`technik@revalenz.de` nennen. Das ist aber nur eine Lesehilfe fuer den
Menschen -- **eine Identitaet mit `technik@revalenz.de` allein ist KEIN
Nachweis**, denn jede Person kann einen beliebigen Schluessel mit dieser
E-Mail-Adresse als UID erzeugen. Massgeblich ist ausschliesslich der
`VALIDSIG`-Abgleich oben. Eine Zeile `gpg: WARNING: This key is not
certified with a trusted signature!` ist NORMAL -- das Vertrauen kommt hier
aus dem Out-of-Band-Vergleich des Fingerabdrucks, nicht aus GPGs eigenem
Web-of-Trust.

## Was zu tun ist, wenn eine Signatur nicht passt

Ein Release, dessen Tag-Signatur nicht gegen diesen Fingerabdruck prueft,
NIEMALS einspielen -- unabhaengig davon, wie dringend das Update wirkt.

Nicht einspielen, wenn:
- Der `grep -q` oben liefert einen Exit-Code ungleich `0` (kein
  `VALIDSIG` mit dem dokumentierten Fingerabdruck in der Ausgabe) -- das
  ist das massgebliche Kriterium
- Die Ausgabe von `git tag -v` enthaelt zusaetzlich `BAD signature` oder
  `expired` oder aehnliches
- Es gibt keine Signatur-Zeile ueberhaupt

Bei Zweifeln oder ungueltig wirkenden Signaturen: technik@revalenz.de
kontaktieren, bevor irgendetwas eingespielt wird.
