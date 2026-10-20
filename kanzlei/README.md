# Kanzlei-Arbeitsplatz (Appliance-Aufbau)

Aufbau eines lokalen Arbeitsplatzes für Kanzleien auf einem einzelnen Rechner mit Proxmox und einer GPU: Diktate
hochladen, Protokolle erzeugen lassen, in Nextcloud bearbeiten, dazu eine Schreibhilfe. Alles läuft im Haus, es gibt
eine gemeinsame Anmeldung (Nextcloud) für alle Teile.

**Nicht enthalten:** das Vali-Backend (Diktat → Protokoll) und seine Modell-Vorgaben. Es wird als fertiges
Container-Abbild beigestellt (`VALI_BACKEND_IMAGE` in `vali-gpu/.env`). Ohne Vali laufen Eingang, Anmeldung,
Nextcloud, Schreibhilfe, Modellsteuerung und Kiosk; die Diktat-Prüfungen setzen es voraus.

## Inhalt
- `RUNBOOK-IT-DIENSTLEISTER.md` – Betrieb, Updates, Fehlersuche. `NETZ.md` – Adressplan.
- `bin/` – Einrichten und Prüfen (Adressen vorher in `~/.kanzlei-umgebung`: `PVE_HOST`, `VALI_GPU_HOST`; siehe `bin/umgebung.sh`).
- `buero/` – Eingang (Caddy mit eigener CA), Nextcloud, Einmalanmeldung, Open WebUI, Namensdienst, Startseite.
- `vali-gpu/` – Vali-Backend (extern), OpenFGA, Whisper, Ollama-Anbindung.
- `modellsteuerung/` – schaltet die GPU zwischen Whisper und Sprachmodell um (mit Tests).
- `messung/` – Messwerkzeug für Modellwechsel.
- `kiosk/` – Browser im Vollbild an der Appliance.
- `zertifikat/` – hier die eigene `root.crt` ablegen (nicht im Repo).

## Hinweise
Die Zugangsdaten und Schlüssel erzeugt `bin/neue-geheimnisse.sh` je Installation. Das Paket wurde bisher an einem
Lenovo ThinkStation P3 Ultra Gen 2 SFF mit RTX PRO 4000 SFF erprobt (Proxmox 9). Lizenz: siehe `LICENSE` im Repo-Root.
