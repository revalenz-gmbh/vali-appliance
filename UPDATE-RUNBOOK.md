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
git clone git@github.com:revalenz-gmbh/vali-appliance.git
cd vali-appliance
gpg --import KEYS.asc
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
   Erwartet: `gpg: Good signature from "revalenz Vali-Appliance
   Releases <technik@revalenz.de>"`. Steht dort irgendetwas anderes
   (falsche Identitaet, "BAD signature", kein Ergebnis): **nicht
   einspielen**, `technik@revalenz.de` kontaktieren.
3. Aenderungsprotokoll lesen (`CHANGELOG.md` im neuen Tag) -- insbesondere,
   ob die Aenderung sicherheitsrelevant ist.
4. Auf den neuen Stand wechseln:
   ```bash
   git checkout <neue-version>
   ```
5. Den eigentlichen Anwendungs-Redeploy-Schritt (Firewall neu anwenden,
   Dienste neu starten) macht ihr wie in
   [`autarkie/RUNBOOK.md`](autarkie/RUNBOOK.md) beschrieben -- dieses
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
