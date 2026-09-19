# Vali-Appliance

Ein autarkes, beim Kunden lokal laufendes Vali-System (Talk-Aufnahme +
Protokoll) fuer Steuerkanzleien, Praxen und andere Stellen, bei denen
Kundendaten das eigene Haus nicht unbemerkt verlassen duerfen (§ 203 StGB,
DSGVO Art. 9). Offen wartbare Linux-Maschine, gepflegt vom
kundeneigenen IT-Dienstleister -- kein laufender Zugriff von revalenz.

## Inhalt

- `autarkie/` -- Default-Deny-Firewall + Nachweisskript, das den
  tatsaechlichen ausgehenden Netzwerkverkehr gegen eine dokumentierte
  Positivliste prueft. Siehe `autarkie/RUNBOOK.md`.

## Updates einspielen

Siehe `UPDATE-RUNBOOK.md` im Repo-Root -- Releases sind signierte Git-Tags,
der eingebaute Atom-Feed dieses Repos
(`https://github.com/revalenz-gmbh/vali-appliance/releases.atom`) ist der
Hinweiskanal.

## Sicherheit / Signaturpruefung

Siehe `SECURITY.md`.
