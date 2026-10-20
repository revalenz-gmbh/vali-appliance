# Runbook für den IT-Dienstleister: Vali-Kanzlei-Arbeitsplatz

Stand 2026-10-19, Pilotrechner im Labor. Adressen und Namen sind die des Labors; beim Kunden ändern sich nur die Adressen im Büronetz.
Kennzeichnung: **[geprüft]** = Befehl auf der Maschine ausgeführt, **[nicht geprüft]** = aus Herstellerangaben, nicht auf dieser Maschine ausprobiert.

## 1. Überblick

| Teil | Wo | Adresse im Büronetz | intern (`10.77.0.0/24`) |
|---|---|---|---|
| Proxmox-Host `pve` | Rechner | `<PVE_HOST>` | `10.77.0.1` |
| VM 101 `buero` (Eingang, Nextcloud, Open WebUI, Anmeldung) | Host | DHCP, MAC `bc:24:11:11:55:ab` | `10.77.0.2` |
| VM 100 `vali-gpu` (Vali, OpenFGA, Whisper, Ollama, Modellsteuerung) | Host | DHCP, nur für SSH | `10.77.0.3` |

Die Anwender nutzen nur `buero`:

| Name | Zweck |
|---|---|
| `https://vali.buero.intern` | Diktat hochladen, Protokolle |
| `https://cloud.buero.intern` | Nextcloud (Dateien, Protokolle bearbeiten, Anmeldung für alles) |
| `https://chat.buero.intern` | Open WebUI (Schreibhilfe) |

Die interne Brücke `vmbr1` hat keinen physischen Anschluss. Ollama, Vali, Whisper und die Modellsteuerung sind aus dem Büronetz nicht erreichbar.

## 2. Einrichtung im Büronetz

1. **IP-Reservierung** für die MAC `bc:24:11:11:55:ab` (VM `buero`) im Router/DHCP-Server. Die Appliance kommt auch mit wechselnder Adresse zurecht:
   der Namensdienst auf `buero` zieht innerhalb von 15 Sekunden nach **[geprüft]**; die Regel im Router (Abschnitt 2.2) muss dann angepasst werden.
2. **Namen auflösen**, eine der beiden Möglichkeiten:
   - drei A-Einträge `vali.buero.intern`, `cloud.buero.intern`, `chat.buero.intern` → Büro-Adresse von `buero`, oder
   - **bedingte Weiterleitung** für die Zone `buero.intern` an die Büro-Adresse von `buero` (Port 53). Der Namensdienst dort (`dnsmasq`) beantwortet nur diese
     Zone und lehnt alles andere ab **[geprüft: `dig @<IP> example.com` bleibt ohne Antwort]**. Die Appliance ist kein Gateway und kein allgemeiner DNS-Server.
3. **Wurzelzertifikat** auf allen Geräten als vertrauenswürdig eintragen. Datei: `vali-appliance-kanzlei/zertifikat/root.crt` (Aussteller „Caddy Local Authority – 2026 ECC Root“,
   gültig bis 2036-08-27 **[geprüft]**). Die Zertifikate der drei Namen erneuert Caddy selbstständig.
   Auf einer VM erneut auslesen: `sudo cat /opt/kanzlei/buero/caddy-data/caddy/pki/authorities/local/root.crt`.
   - Windows (Administrator): `certutil -addstore -f ROOT root.crt` oder per Gruppenrichtlinie **[nicht geprüft]**
   - macOS: `sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain root.crt` **[nicht geprüft]**
   - Debian/Ubuntu: Datei nach `/usr/local/share/ca-certificates/vali-buero.crt`, dann `sudo update-ca-certificates` **[nicht geprüft]**
   - iPhone/iPad: Datei per AirDrop/Mail öffnen, Profil installieren, danach *Einstellungen → Allgemein → Info → Zertifikatsvertrauenseinstellungen* aktivieren **[nicht geprüft]**
   - Android: *Einstellungen → Sicherheit → Zertifikat installieren → CA-Zertifikat* **[nicht geprüft]**
   Ohne diesen Schritt zeigt der Browser eine Warnung, und die Diktat-App auf dem Smartphone kann das Mikrofon nicht nutzen.

## 3. Nutzer anlegen

Auf `buero` (`ssh vali@<IP von buero>`, im Labor über den Host: `ssh -J root@<PVE_HOST> vali@10.77.0.2`):

```bash
cd /opt/kanzlei/buero
OCC="sudo docker exec -u www-data nextcloud php occ"
sudo docker exec -u www-data -e OC_PASS='<Startpasswort>' nextcloud php occ user:add --password-from-env --display-name="Vorname Nachname" benutzername   # [geprüft]
$OCC user:setting benutzername settings email benutzer@kanzlei.example                                       # [geprüft] PFLICHT: ohne E-Mail meldet Open WebUI "email is missing" und lässt niemanden herein
```

- Die **E-Mail-Adresse ist Pflicht**, sonst nimmt Open WebUI die Anmeldung nicht an.
- Der Benutzername in Nextcloud ist zugleich der Name in Vali; nachträgliches Umbenennen führt zu einem zweiten Konto.
- **Erste Anmeldung in Vali:** Der Anwender (oder Sie) hinterlegt einmal ein Nextcloud-App-Passwort in Vali unter *Einstellungen → Nextcloud*. Ohne es zeigt Vali beim Anlegen
  eines Projekts die Meldung „… kein Nextcloud App-Passwort hinterlegt …“ **[geprüft]** und schreibt keine Dateien nach Nextcloud. Ein App-Passwort erzeugen:
  `$OCC user:auth-tokens:add benutzername --name vali` **[geprüft]** (oder in Nextcloud unter *Persönliche Einstellungen → Sicherheit*).
- Passwort ändern: `sudo docker exec -u www-data -e OC_PASS='<neu>' nextcloud php occ user:resetpassword --password-from-env benutzername`.

## 4. Betrieb

```bash
# buero
cd /opt/kanzlei/buero && sudo docker compose ps                         # [geprüft]
sudo docker compose logs --tail 50 caddy oauth2-proxy nextcloud open-webui
systemctl status dnsmasq dnsmasq-buero-nachziehen.timer                  # Namensdienst und Adress-Timer
# vali-gpu
cd ~/kanzlei && sudo docker compose ps                                   # [geprüft]
curl -s 10.77.0.3:8002/status                                            # Modellsteuerung: phase, bereit, wechselt_zu   [geprüft]
systemctl status ollama modellsteuerung
sudo docker logs --tail 50 nexus-api
```

- **GPU-Umschaltung:** Gemma 31B und Whisper passen nicht gleichzeitig in die Karte. Die Modellsteuerung (`modellsteuerung.service`) schaltet automatisch um
  (Dauer ca. 13 Sekunden **[geprüft]**, Messbericht `docs/superpowers/messungen/2026-10-19-modellwechsel.md`). Pilot: ein Anwender gleichzeitig.
  Läuft Whisper gerade einen Auftrag, wartet eine Chat-Anfrage, bis er fertig ist.
- **Nach jedem `docker compose up` auf `vali-gpu`** `sudo systemctl restart modellsteuerung` ausführen (das Ausrollskript tut das). Compose startet sonst den Whisper-Container
  neben einem geladenen Sprachmodell.

## 5. Updates

Reihenfolge: Sicherung prüfen → Host → `vali-gpu` → `buero`. Nach jedem Schritt `pruefe_anmeldepfad.py` und `pruefe_diktat_e2e.py` (`vali-appliance-kanzlei/bin/`) ausführen.

- **Host (Proxmox):** `apt update && apt full-upgrade`, danach Neustart. Beide VMs starten selbst (Autostart) **[geprüft: Neustart des Hosts]**.
- **Ubuntu in den VMs:** `sudo apt update && sudo apt upgrade`, bei neuem Kernel Neustart.
- **Container (`buero`):** In `docker-compose.yml` die Abbildnummer ändern, dann `sudo docker compose pull <dienst> && sudo docker compose up -d <dienst>`.
  Nextcloud: nur eine Hauptversion nach der anderen; danach `sudo docker exec -u www-data nextcloud php occ upgrade` **[nicht geprüft]**.
- **Ollama:** `curl -fsSL https://ollama.com/install.sh | sh` **[nicht geprüft für Updates]**; dort bleibt die Konfiguration in `/etc/systemd/system/ollama.service.d/override.conf` erhalten.
- **Vali (`nexus-api`):** Das Vali-Backend ist nicht Teil dieses Repos und kommt als fertiges Container-Abbild vom Anbieter. Neuen Tag in `vali-gpu/.env` (`VALI_BACKEND_IMAGE`) eintragen und `bin/vali-gpu-ausrollen.sh nexus-api` ausführen.

## 6. Sicherung und Wiederherstellung

Die Sicherung läuft mit `vzdump` auf dem Host. **Das Sicherungsziel (externe Platte oder NAS) ist noch nicht festgelegt**; die NVMe im Rechner reicht für beide VMs samt Modellen nicht.

```bash
vzdump 101 --storage local --mode snapshot --compress zstd         # VM buero, 42 s, 6,8 GB   [geprüft]
zstd -t /var/lib/vz/dump/vzdump-qemu-101-*.vma.zst                 # Datei prüfen              [geprüft]
qmrestore /var/lib/vz/dump/vzdump-qemu-101-<Zeit>.vma.zst 901 --storage local-lvm   # Probe-Wiederherstellung [geprüft]
```

Die Wiederherstellungsprobe (VM auf eine freie ID, Netz `net0` entfernt, `net1` an eine leere Brücke) ergab: die VM startet, Nextcloud antwortet mit `"installed":true`, alle sechs Container laufen.
VM 100 (`vali-gpu`) enthält 40 GB Modelle und Caches; sie lassen sich neu herunterladen (`ollama pull`, Whisper-Cache von einer anderen Maschine). Besser ist es, die Modellordner von der Sicherung auszunehmen.
Wichtig: **Nextcloud-Daten, Vali-Datenbank (`~/kanzlei/nexus-db`) und die `.env`-Dateien** gehören in jede Sicherung. Die `.env`-Dateien enthalten Schlüssel; ohne den `NEXUS_SECRET_KEY` sind gespeicherte App-Passwörter unlesbar.

## 7. Fehlersuche

| Symptom | Prüfen / Abhilfe |
|---|---|
| Browser meldet Zertifikatsfehler | Wurzelzertifikat fehlt auf dem Gerät (Abschnitt 2.3) |
| `vali.buero.intern` löst nicht auf | DNS-Eintrag/Weiterleitung (2.2); `dig @<IP von buero> vali.buero.intern` muss die IP liefern |
| Name löst auf eine alte Adresse auf | Router-Regel auf die neue Adresse von `buero` setzen; `systemctl status dnsmasq-buero-nachziehen.timer` |
| Anmeldeschleife / „Sitzung abgelaufen“ | Cookies für `*.buero.intern` löschen; `sudo docker logs oauth2-proxy`; prüfen, dass der Benutzer in Nextcloud existiert |
| Open WebUI: „E-Mail fehlt“ | Nextcloud-Benutzer braucht eine E-Mail-Adresse (Abschnitt 3) |
| 502 auf `vali.buero.intern` | `nexus-api` läuft? `curl 10.77.0.3:8001/health` von `buero`; Firewall `sudo ufw status` auf `vali-gpu` |
| Caddy nimmt die geänderte `Caddyfile` nicht an | Datei wurde ersetzt, der Container sieht noch die alte: `sudo docker compose restart caddy` |
| Protokoll bleibt „queued“ | `curl 10.77.0.3:8002/status`; `nvidia-smi`; steht `wechselt_zu` dauerhaft, ist ein Wechsel hängen geblieben: `systemctl restart modellsteuerung` |
| Whisper startet nicht (CUDA out of memory) | Ein Sprachmodell ist noch geladen: `OLLAMA_HOST=10.77.0.3:11434 ollama ps`, dann `ollama stop <modell>` und `systemctl restart modellsteuerung` |
| Dateien erscheinen nicht in Nextcloud | App-Passwort fehlt oder ist abgelaufen: *Einstellungen → Nextcloud* in Vali neu eintragen |

## 8. Bekannte Einschränkungen

- Pilot: ein Anwender gleichzeitig; Whisper und Sprachmodell wechseln sich auf der GPU ab.
- Kontext 65536 (Einstellung von `agent-sekretaer`) halbiert die Geschwindigkeit (13 statt 27 Token/s); ob 32768 für übliche Diktate reicht, ist noch offen.
- Die VMs haben ungefilterten Zugang ins Internet; eine Firewall nach dem Autarkie-Nachweis ist noch nicht eingerichtet.
- Nur Nextcloud, Open WebUI und Vali sind eingerichtet; Talk, Bildanalyse und der Dateiindex von Vali sind aus.

## 9. Kiosk an der Appliance
Monitor, Tastatur und Maus an der Appliance zeigen im Vollbild `https://cloud.buero.intern` (Einmalanmeldung fuer Vali und Open WebUI). Der Browser (Chromium unter `cage`, Benutzer `kiosk`, Intel-Grafik des Hosts) darf nur `cloud.`, `vali.` und `chat.buero.intern` oeffnen (`/etc/chromium/policies/managed/kiosk.json`). Die Namen stehen in `/etc/hosts` des Hosts (10.77.0.2), die Buero-CA im Zertifikatsspeicher des Benutzers `kiosk`.
- Einrichten/Aktualisieren: `bin/kiosk-einrichten.sh` (auf CT130), danach `systemctl restart kiosk` auf dem Host.
- Host-Konsole: `Strg+Alt+F2` (getty); Dienst anhalten: `systemctl stop kiosk`.
- USB-Medien (z. B. MP3-Recorder) haengt `udiskie` unter `/media/kiosk` ein; sie erscheinen im Dateiauswahlfenster des Browsers.
- Der Browser belegt etwa 1 GB des knappen Hauptspeichers (Host ca. 3,6 GB verfuegbar).
