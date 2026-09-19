# Updates einspielen (fuer den IT-Dienstleister)

## Einmalig: Installationsort

Alle Schritte in diesem Dokument -- und die absoluten Pfade in
`autarkie/RUNBOOK.md` -- gehen davon aus, dass das Repo unter
`/opt/vali-appliance` liegt. Einmalig dorthin klonen:

```bash
sudo git clone https://github.com/revalenz-gmbh/vali-appliance.git /opt/vali-appliance
cd /opt/vali-appliance
```

Alle folgenden Schritte (Schluessel-Import, Verifikation, Checkout,
Redeploy) finden in diesem Verzeichnis statt -- nicht in einer separaten,
unverifizierten Kopie des Repos irgendwo anders.

## Einmalig: Hinweiskanal abonnieren

Dieser Feed meldet jedes neue Release, ohne dass revalenz aktiv auf eure
Maschine zugreifen muss:

```
https://github.com/revalenz-gmbh/vali-appliance/releases.atom
```
In einem beliebigen RSS/Atom-Reader abonnieren.

## Einmalig: Schluessel importieren

Im installierten Verzeichnis (`/opt/vali-appliance`, siehe oben):

```bash
gpg --import KEYS.asc
gpg --fingerprint technik@revalenz.de
```
Fingerabdruck **vor dem ersten Vertrauen** gegen `SECURITY.md` vergleichen.
Der Fingerabdruck soll zusaetzlich auf revalenz.de veroeffentlicht werden
(zweite, unabhaengige Quelle) -- **das ist zum Zeitpunkt dieses Schreibens
noch nicht geschehen**. Bis dahin ist `KEYS.asc` in diesem Repo die
einzige Quelle. Wer zusaetzliche Sicherheit will: Fingerabdruck
telefonisch oder persoenlich bei technik@revalenz.de erfragen und mit dem
in `SECURITY.md` hinterlegten Wert vergleichen.

## Bei jedem neuen Release

1. Aenderungen holen:
   ```bash
   git fetch origin --tags
   ```
   Falls git das Holen eines Tags verweigert, weil es einen bestehenden
   lokalen Tag "clobbern" wuerde: das ist ein Manipulationssignal (ein
   bereits veroeffentlichter Tag wurde nachtraeglich verschoben/ersetzt)
   -- anhalten, `technik@revalenz.de` kontaktieren, NICHT erzwungen
   weiterholen.
2. Signatur des neuen Tags pruefen -- **NIEMALS ueberspringen**. Der
   Abgleich gegen den Fingerabdruck ist das eigentliche Pass/Fail-
   Kriterium, nicht das bloße Lesen von Text in der Ausgabe:
   ```bash
   git verify-tag --raw <neue-version> 2>&1 | grep -q \
     'VALIDSIG 5F6E6D907617F8991135D1847B1C6E1640801E3F'   # z.B. v0.1.1
   ```
   **Erwartetes Ergebnis:** Exit-Code `0` von diesem `grep -q` -- die
   Zeile `VALIDSIG` mit genau diesem Fingerabdruck ist in der Ausgabe
   vorhanden.

   Zur menschlichen Gegenkontrolle kann zusaetzlich `git tag -v
   <neue-version>` angeschaut werden: die Ausgabe sollte eine Zeile mit
   `Good signature from` enthalten und die Identitaet sollte
   `technik@revalenz.de` nennen. Das ist aber nur eine Lesehilfe --
   **eine Identitaet mit `technik@revalenz.de` allein ist KEIN
   Nachweis**, denn jede Person kann einen beliebigen Schluessel mit
   dieser E-Mail-Adresse als UID erzeugen. Massgeblich ist ausschliesslich
   der `VALIDSIG`-Abgleich oben. Eine Zeile `gpg: WARNING: This key is
   not certified with a trusted signature!` ist NORMAL und NICHT
   besorgniserregend -- das Vertrauen kommt hier nicht aus GPGs
   Web-of-Trust, sondern aus dem Out-of-Band-Vergleich des
   Fingerabdrucks gegen `SECURITY.md`.

   **Nicht einspielen**, wenn:
   - Der `grep -q` oben liefert einen Exit-Code ungleich `0` (kein
     `VALIDSIG` mit dem dokumentierten Fingerabdruck) -- das ist das
     massgebliche Kriterium
   - Die Ausgabe von `git tag -v` enthaelt zusaetzlich `BAD signature`
     oder `expired` oder aehnliches
   - Es gibt keine Signatur-Zeile ueberhaupt

   In jedem dieser Faelle: **nicht einspielen**, `technik@revalenz.de`
   kontaktieren.
3. Aenderungsprotokoll lesen (aus dem neuen Tag, ohne ihn auszuchecken):
   ```bash
   git show <neue-version>:CHANGELOG.md
   ```
   Insbesondere, ob die Aenderung sicherheitsrelevant ist.
4. Auf den neuen Stand wechseln:
   ```bash
   git checkout <neue-version>
   ```
5. Wenn sich in diesem Update die Datei `allowlist.conf` geaendert hat
   (in `CHANGELOG.md` dokumentiert), muss die Firewall-Positivliste neu
   angewendet werden:
   ```bash
   sudo /opt/vali-appliance/autarkie/setup-firewall.sh
   ```
   Details dazu finden sich unter "Positivliste aendern" in
   [`autarkie/RUNBOOK.md`](autarkie/RUNBOOK.md).

   **Hinweis:** Dieses Repo enthaelt derzeit nur die Autarkie-Nachweis-
   Komponente. Falls sich spaeter weitere Komponenten (z.B. die
   eigentliche Vali-Anwendung) hinzugesellen, werden ihre
   Redeploy-Schritte hier oder in separaten Dokumenten beschrieben --
   zum jetzigen Zeitpunkt sind keine weiteren Aktionen noetig. Dieses
   Dokument regelt nur das *Holen und Verifizieren* eines Updates, nicht
   den Betrieb der einzelnen Komponenten.
6. Autarkie-Nachweis kurz gegenpruefen (Smoke-Check, 60 Sekunden) --
   belegt, dass die Appliance nach einer Firewall-relevanten Aenderung
   weiterhin autark ist:
   ```bash
   sudo /opt/vali-appliance/autarkie/autarkie-check.sh -d 60
   ```
   Fuer einen gruendlicheren Nachweis nach einem Update (z.B. bei
   groesseren Aenderungen an `allowlist.conf`) siehe die
   `systemd-run`-Anleitung fuer den vollen 48h-Nachweis in
   [`autarkie/RUNBOOK.md`](autarkie/RUNBOOK.md).

## Rollback

Falls ein Update Probleme macht: einfach auf den vorherigen, ebenfalls
signierten Tag zurueckwechseln.
```bash
git tag --sort=-creatordate | head -5   # letzte Versionen, neueste zuerst
git checkout <vorherige-version>
```
Der vorherige Redeploy-Schritt (Schritt 5 oben) ist damit ebenfalls
rueckgaengig zu machen -- ein Rollback des Codes allein reicht nicht,
wenn sich z.B. die Firewall-Konfiguration geaendert hatte.
