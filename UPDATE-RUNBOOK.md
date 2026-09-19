# Updates einspielen (fuer den IT-Dienstleister)

## Einmalig: Hinweiskanal abonnieren

Dieser Feed meldet jedes neue Release, ohne dass revalenz aktiv auf eure
Maschine zugreifen muss:

```
https://github.com/revalenz-gmbh/vali-appliance/releases.atom
```
In einem beliebigen RSS/Atom-Reader abonnieren.

## Einmalig: Schluessel importieren

```bash
git clone https://github.com/revalenz-gmbh/vali-appliance.git
cd vali-appliance
gpg --import KEYS.asc
gpg --fingerprint technik@revalenz.de
```
Fingerabdruck **vor dem ersten Vertrauen** gegen `SECURITY.md` UND gegen
die unabhaengige Veroeffentlichung auf revalenz.de vergleichen.

## Bei jedem neuen Release

1. Aenderungen holen:
   ```bash
   git fetch origin --tags
   ```
2. Signatur des neuen Tags pruefen -- **NIEMALS ueberspringen**:
   ```bash
   git tag -v <neue-version>   # z.B. v0.1.1
   ```
   **Erwartetes Ergebnis:** Die Ausgabe enthaelt eine Zeile mit `Good
   signature from` UND die Identitaet enthaelt `technik@revalenz.de`.
   Zusaetzlich ist eine Zeile `gpg: WARNING: This key is not certified
   with a trusted signature!` NORMAL und NICHT besorgniserregend — das
   Vertrauen kommt hier nicht aus GPGs Web-of-Trust, sondern aus dem
   Out-of-Band-Vergleich des Fingerabdrucks gegen `SECURITY.md` und
   revalenz.de.
   
   **Nicht einspielen**, wenn:
   - Die Ausgabe enthaelt `BAD signature` oder `expired` oder aehnliches
   - Es gibt keine Signatur-Zeile ueberhaupt
   - Die Identitaet enthaelt nicht `technik@revalenz.de`
   
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
