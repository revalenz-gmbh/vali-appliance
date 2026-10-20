# Adressplan Kanzlei-Arbeitsplatz

| Teilnehmer | Büronetz (`vmbr0`) | intern (`vmbr1`, `10.77.0.0/24`) |
|---|---|---|
| Proxmox-Host | `<PVE_HOST>` | `10.77.0.1` |
| `buero` (VM 101) | DHCP (Eingang, Namen `*.buero.intern`) | `10.77.0.2` |
| `vali-gpu` (VM 100) | DHCP (nur SSH) | `10.77.0.3` |

`vmbr1` hat keinen physischen Anschluss. Ollama (11434), Vali (8001), Whisper (8000) und die
Modellsteuerung lauschen nur auf `10.77.0.3` und sind per Firewall nur von `10.77.0.2` erreichbar.
