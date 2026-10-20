"""Umschaltlogik der GPU zwischen Whisper und den Sprachmodellen.

Gemma 31B (21,6 GB) und Whisper (~4 GB) passen nicht gemeinsam in 24 GB. Es ist deshalb immer genau
eine der beiden Seiten im Grafikspeicher:
  "whisper" -> Container ghost-transcriber laeuft, kein Ollama-Modell geladen
  "llm"     -> Container gestoppt, Ollama laedt Modelle nach Bedarf
Phasennamen nach aussen: transkription (whisper), protokoll und schreibhilfe (beide llm).
"""
import asyncio
import json
import time
from typing import Optional, Protocol

PHASEN = {"transkription": "whisper", "protokoll": "llm", "schreibhilfe": "llm"}


class Backends(Protocol):
    async def whisper_stoppen(self) -> None: ...
    async def whisper_starten(self) -> None: ...      # kehrt zurueck, wenn Whisper gesund ist
    async def whisper_gesund(self) -> bool: ...
    async def whisper_aktiv(self) -> bool: ...        # laufende oder wartende Auftraege
    async def ollama_alle_entladen(self) -> None: ...  # kehrt zurueck, wenn der Speicher frei ist


class Steuerung:
    def __init__(self, backends: Backends, messwerte: dict, warte_s: float = 2.0, frist_s: float = 900.0):
        self.b = backends
        self.messwerte = messwerte
        self.warte_s = warte_s
        self.frist_s = frist_s
        self.physisch: Optional[str] = None
        self.phase: Optional[str] = None
        self._wechsel: Optional[dict] = None   # laufender Wechsel: {"wechselt_zu": name, "geschaetzte_dauer_s": s}
        self._sperre = asyncio.Lock()

    async def initialisieren(self) -> None:
        """Ermittelt den tatsaechlichen Zustand und stellt sicher, dass nie beide Seiten geladen sind."""
        if await self.b.whisper_gesund():
            await self.b.ollama_alle_entladen()
            self.physisch, self.phase = "whisper", "transkription"
        else:
            self.physisch, self.phase = "llm", "schreibhilfe"

    def geschaetzte_dauer_s(self, ziel: str) -> float:
        m = self.messwerte
        if self.physisch == ziel:
            return 0.0
        if ziel == "llm":
            return float(m["whisper_entladen_s"] + m["gemma_laden_s"])
        return float(m["gemma_entladen_s"] + m["whisper_starten_s"])

    async def _warte_bis_whisper_leer(self) -> None:
        ende = time.monotonic() + self.frist_s
        while await self.b.whisper_aktiv():
            if time.monotonic() >= ende:
                raise TimeoutError("Whisper hat noch Auftraege, Umschalten abgebrochen")
            await asyncio.sleep(self.warte_s)

    async def setze_phase(self, name: str) -> dict:
        if name not in PHASEN:
            raise ValueError(f"unbekannte Phase '{name}'")
        ziel = PHASEN[name]
        async with self._sperre:
            dauer = self.geschaetzte_dauer_s(ziel)
            if self.physisch != ziel:
                if ziel == "llm":
                    await self._warte_bis_whisper_leer()  # nie mitten im Auftrag stoppen
                self._wechsel = {"wechselt_zu": name, "geschaetzte_dauer_s": dauer}
                try:
                    if ziel == "llm":
                        await self.b.whisper_stoppen()
                    else:
                        await self.b.ollama_alle_entladen()
                        await self.b.whisper_starten()
                finally:
                    self._wechsel = None
                self.physisch = ziel
            self.phase = name
        return {"phase": name, "bereit": True, "geschaetzte_dauer_s": dauer}

    def status(self) -> dict:
        w = self._wechsel
        return {"phase": self.phase, "bereit": self.physisch is not None,
                "wechselt_zu": w["wechselt_zu"] if w else None,
                "geschaetzte_dauer_s": w["geschaetzte_dauer_s"] if w else 0.0}


def lade_messwerte(pfad: str) -> dict:
    """Liest die Mediane aus der Ausgabe von messung/modellwechsel.py (letzte Zeile mit "median")."""
    with open(pfad) as f:
        for zeile in reversed(f.read().splitlines()):
            if '"median"' in zeile:
                return json.loads(zeile)["median"]
    raise ValueError(f"keine Messwerte in {pfad}")
