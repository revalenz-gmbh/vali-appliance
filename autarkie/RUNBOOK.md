# Autarkie-Nachweis fuehren

**Zweck:** Belegen, dass die Vali-Appliance ausschliesslich mit dem
dokumentierten, minimalen Satz an Zielen kommuniziert (DNS, NTP,
Release-Feed) — kein Kundendatum verlaesst das Haus unbemerkt.

## Ausfuehren

Kurzer Testlauf (z.B. zur Abnahme vor Ort): `-d 60` (60 Sekunden).
```bash
sudo /opt/vali-appliance/autarkie/autarkie-check.sh -d 60
```

Fuer den vollen 48h-Nachweis **immer per `systemd-run` starten, nie als
nackten Vordergrund-Befehl ueber SSH** — eine abbrechende SSH-Sitzung
wuerde sonst den laufenden Nachweis mitreissen (genau dieses Muster hat in
dieser Infrastruktur schon einmal einen langen Lauf gekillt):
```bash
sudo systemd-run --unit=autarkie-check \
  /opt/vali-appliance/autarkie/autarkie-check.sh -d 172800   # 48h
```
⚠️ **Kein `--collect`**: das würde die Einheit sofort nach Lauf-Ende entfernen
— genau bevor sich ihr Exit-Code auslesen lässt, und der Exit-Code ist
hier die eigentliche Aussage (0/1/2, siehe unten). Status/Ausgabe danach
pruefen:
```bash
systemctl status autarkie-check          # zeigt den Exit-Code direkt
# oder gezielt nur den Code:
systemctl show -p ExecMainStatus autarkie-check
journalctl -u autarkie-check
```
Danach aufraeumen (die Einheit bleibt sonst als „failed"/„exited" stehen):
```bash
sudo systemctl reset-failed autarkie-check
```

## Ergebnis lesen

Es gibt **drei** Exit-Codes, nicht zwei:

- **Exit 0**: Aufnahme lief tatsaechlich (tcpdump hat Pakete erfasst) UND
  alle beobachteten Verbindungen passen zur Positivliste.
- **Exit 1**: Aufnahme lief tatsaechlich, aber mindestens eine Verbindung
  passt zu keinem Eintrag — im Bericht als `UNERWARTET` markiert, mit
  Begruendung (Port/Protokoll nicht erlaubt, oder Hostname passt zu
  keinem Eintrag).
- **Exit 2**: Die Pruefung selbst konnte nicht sauber laufen (Aufnahme
  fehlgeschlagen — falsches Interface, fehlende Root-Rechte, tcpdump
  abgestuerzt, oder 0 Pakete waehrend des Fensters erfasst). **Das ist
  KEIN bestandener Nachweis** — sofort untersuchen, nicht als "sauber"
  werten.
  - Hintergrund: eine leere/gescheiterte Aufnahme erzeugt ohne diese
    Pruefung "0 erlaubt, 0 unerwartet" (Exit 0) — von einem echten,
    vollstaendig beobachteten sauberen Lauf nicht zu unterscheiden. Genau
    dafuer existiert Exit 2: "0 erlaubt, 0 unerwartet" aus einer Aufnahme,
    die nie wirklich lief, ist KEIN Beleg fuer irgendetwas.

Der Bericht liegt zusaetzlich als Datei unter `/var/log/autarkie-check/`
(Beobachtung + Bewertung getrennt, beide mit Zeitstempel) — das ist das
vorzeigbare Artefakt, nicht nur die Bildschirmausgabe. Der Bericht beginnt
mit einem Herkunftsnachweis-Kopf (Geraet, Interface, Dauer, Zeitstempel,
Hash der verwendeten Positivliste), damit eine spaetere/externe
Datenschutz-Pruefung nachvollziehen kann, was der Lauf tatsaechlich
abgedeckt hat.

## Bekannte Einschraenkung: Reverse-DNS bei CDN-Zielen

`github.com` (Release-Feed) wird ueber ein CDN ausgeliefert; die
Reverse-DNS-Antwort der jeweiligen IP muss nicht woertlich "github.com"
enthalten (z.B. `lb-140-82-121-3.github.com` passt, eine IP ohne PTR-Eintrag
nicht automatisch). Wird github.com-Verkehr faelschlich als `UNERWARTET`
markiert: die Ziel-IP gegen die von GitHub veroeffentlichten IP-Bereiche
pruefen (`https://api.github.com/meta`) als zweite Kontrolle, bevor ein
echter Verstoss angenommen wird.

## Bekannte Einschraenkung: UDP-Antwortverkehr (Talk/WebRTC-Medien)

Die Erfassung kann ausgehenden UDP-Verkehr nicht zuverlaessig danach
unterscheiden, ob die Appliance die Verbindung selbst begonnen hat oder
nur auf eingehenden Verkehr antwortet (dafuer waere Conntrack-Integration
noetig, die diese Version nicht hat). UDP-Antwortverkehr (z. B.
WebRTC/Talk-Medien) kann in der Beobachtung auftauchen, auch wenn er nicht
vom Geraet selbst initiiert wurde. Bei UDP-Zielen mit hohen, wechselnden
Portnummern im Bericht: das ist wahrscheinlich Antwortverkehr, keine neue
ausgehende Verbindung — gegen die tatsaechlichen Talk-Nutzer-IPs im
fraglichen Zeitraum pruefen, bevor es als echter Verstoss gewertet wird.

## Bekannte Einschraenkung: IPv6-TCP wird grober erfasst als IPv4

Fuer IPv4 erfasst der Filter nur neue Verbindungen (SYN ohne ACK). Fuer
IPv6 muessen alle TCP-Pakete erfasst werden (siehe Kommentar in
`capture-outbound.sh`), da BPF die TCP-Flags bei IPv6 nicht immer
zuverlaessig ueber Extension Header hinweg lesen kann. Die anschliessende
Deduplizierung (`sort -u`) dampft das wieder auf eindeutige Ziele ein —
grobkoerniger als die IPv4-Seite, aber bewusst besser als IPv6-TCP
komplett zu uebersehen.

## Bekannte Einschraenkung: 443 ist fuer JEDES Ziel offen

`setup-firewall.sh` oeffnet ausgehend Port 443 fuer **jedes** Ziel — die
Firewall selbst schraenkt nicht nach Hostname ein, nur nach Port. Der
Hostname-Abgleich in `classify-connections.sh` ist eine
**Erkennungskontrolle** (er meldet unerwartete 443-Ziele im Nachhinein),
**keine Verhinderungskontrolle** (er kann eine Verbindung nicht
verhindern, waehrend sie passiert). Wer eine echte Verhinderung braucht,
muss das Format der Positivliste um IP/CIDR-Eintraege erweitern
(nicht Teil dieser Version, siehe Folgearbeiten).

## Bekannte Einschraenkung: DNS/NTP ohne Ziel-Einschraenkung, kein LOKAL-Urteil

- DNS (Port 53) und NTP (Port 123) sind in der aktuellen Positivliste an
  **jedes** Ziel erlaubt, ohne IP-Einschraenkung. DNS-Tunneling zu einem
  angreiferkontrollierten Resolver wuerde dadurch NICHT erkannt.
- Die Pruefung unterscheidet aktuell nicht zwischen lokalem Netzwerkverkehr
  (RFC1918) und echtem externem Verkehr. Ein Bericht kann darum
  `UNERWARTET`-Eintraege fuer ganz gewoehnliche lokale Aktivitaet zeigen
  (Monitoring-Scrapes, andere LAN-Dienste) neben echten externen
  Verstoessen. Wer den Bericht prueft, muss jeden `UNERWARTET`-Eintrag
  einzeln nach Zieladresse bewerten — nicht nur zaehlen.

Beide Punkte sind als Folgearbeit vorgemerkt, nicht in dieser Version
behoben (siehe Format-Erweiterung der Positivliste um IP/CIDR + eigenes
`LOKAL`-Urteil).

## Positivliste aendern

Nur `allowlist.conf` anfassen, dann die Firewall neu anwenden:

> **Achtung:** `setup-firewall.sh` fuehrt `ufw --force reset` aus — das
> loescht ALLE bestehenden Firewall-Regeln, auch eingehende Regeln, die
> ein echtes Deployment fuer andere Dienste gesetzt hat (z. B. die
> tatsaechlichen Nextcloud-Talk-/Vali-Anwendungsports, die diese Appliance
> im LAN bedient). Dieses Skript kennt bisher nur SSH (eingehend) und die
> ausgehende Positivliste. Wer zusaetzliche eingehende Regeln auf dieser
> Appliance braucht, muss sie nach JEDEM Lauf von `setup-firewall.sh`
> erneut anwenden — oder den eingehenden Teil des Skripts zuerst
> erweitern. Zur Einordnung: die von `setup-firewall.sh` gesetzte
> SSH-Regel oeffnet Port 22 eingehend fuer JEDE Quelle (keine
> IP-Einschraenkung) — das ist bei einem sicherheitsbewussten Betrieb
> eine bewusste Erwaehnung wert.

```bash
sudo /opt/vali-appliance/autarkie/setup-firewall.sh
```
Firewall-Regeln und Pruefskript lesen dieselbe Datei — keine zweite Stelle
pflegen.
