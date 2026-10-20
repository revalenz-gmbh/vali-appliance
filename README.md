# Vali-Appliance

Ein autarkes, beim Kunden lokal laufendes Vali-System (Talk-Aufnahme +
Protokoll) fuer Steuerkanzleien, Praxen und andere Stellen, bei denen
Kundendaten das eigene Haus nicht unbemerkt verlassen duerfen (§ 203 StGB,
DSGVO Art. 9). Offen wartbare Linux-Maschine, gepflegt vom
kundeneigenen IT-Dienstleister -- kein laufender Zugriff von revalenz.

## Stand / Umfang

Dieses Repo liefert zum jetzigen Zeitpunkt nur das Autarkie-Nachweis-
Subsystem plus den Release-/Signiermechanismus drumherum -- **nicht die
eigentliche Vali-Anwendung**. Die ist (noch) nicht ueber dieses Repo
verteilt. Ausserdem: **es wurde noch kein Release geschnitten** (`git tag
-l` ist derzeit leer) -- wer den Release-Feed/Atom-Feed abonniert und
zunaechst nichts sieht, ist nicht im Rueckstand, es gibt schlicht noch
kein erstes Release.

## Inhalt

- `kanzlei/` -- Aufbau des Kanzlei-Arbeitsplatzes auf einem Rechner (Proxmox, Einmalanmeldung, Nextcloud, Schreibhilfe, Modellsteuerung, Kiosk) -- **ohne** das Vali-Backend. Siehe `kanzlei/README.md`.

- `autarkie/` -- Default-Deny-Firewall + Nachweisskript, das den
  tatsaechlichen ausgehenden Netzwerkverkehr gegen eine dokumentierte
  Positivliste prueft. Siehe `autarkie/RUNBOOK.md`.
- `KEYS.asc` + `SECURITY.md` -- oeffentlicher Signierschluessel und die
  Vertrauens-/Verifikationsdokumentation dazu.
- `UPDATE-RUNBOOK.md` -- Anleitung fuer den IT-Dienstleister, um Updates
  zu holen, zu verifizieren und einzuspielen.
- `cut-release.sh` + `CHANGELOG.md` -- Werkzeug fuer den Maintainer
  (revalenz), um ein neues Release zu schneiden, sowie das
  Aenderungsprotokoll selbst. `cut-release.sh` ist **nur fuer den
  Maintainer**, nicht fuer den IT-Dienstleister der Kunden gedacht.

## Updates einspielen

Siehe `UPDATE-RUNBOOK.md` im Repo-Root -- Releases sind signierte Git-Tags,
der eingebaute Atom-Feed dieses Repos
(`https://github.com/revalenz-gmbh/vali-appliance/releases.atom`) ist der
Hinweiskanal.

## Sicherheit / Signaturpruefung

Siehe `SECURITY.md`.

## Lizenz

Apache License 2.0, siehe `LICENSE`. Das Vali-Backend ist nicht Teil dieses Repos und steht nicht unter dieser Lizenz.
