"""Tests fuer die Umschaltlogik (steuerung.py) mit Attrappen statt Docker und Ollama."""
import pytest

from steuerung import Steuerung

MESSWERTE = {"whisper_entladen_s": 1.3, "gemma_laden_s": 5.6, "gemma_entladen_s": 0.5, "whisper_starten_s": 6.3}


class Attrappe:
    def __init__(self, aktiv_nacheinander=(), dauerhaft_aktiv=False):
        self.ereignisse = []
        self._aktiv = list(aktiv_nacheinander)
        self._dauerhaft = dauerhaft_aktiv

    async def whisper_stoppen(self):
        self.ereignisse.append("whisper_stopp")

    async def whisper_starten(self):
        self.ereignisse.append("whisper_start")

    async def whisper_gesund(self):
        return False

    async def whisper_aktiv(self):
        return True if self._dauerhaft else (self._aktiv.pop(0) if self._aktiv else False)

    async def ollama_alle_entladen(self):
        self.ereignisse.append("ollama_entladen")


def _st(b):
    return Steuerung(b, MESSWERTE, warte_s=0.0, frist_s=5.0)


async def test_wechsel_zu_protokoll_stoppt_whisper_und_schaetzt_die_dauer():
    b = Attrappe()
    st = _st(b)
    st.physisch = "whisper"
    ergebnis = await st.setze_phase("protokoll")
    assert b.ereignisse == ["whisper_stopp"]
    assert ergebnis == {"phase": "protokoll", "bereit": True, "geschaetzte_dauer_s": pytest.approx(6.9)}


async def test_wechsel_zu_transkription_entlaedt_ollama_vor_dem_whisper_start():
    b = Attrappe()
    st = _st(b)
    st.physisch = "llm"
    ergebnis = await st.setze_phase("transkription")
    assert b.ereignisse == ["ollama_entladen", "whisper_start"]
    assert ergebnis["geschaetzte_dauer_s"] == pytest.approx(6.8)


async def test_gleiche_phase_schaltet_nicht_noch_einmal():
    b = Attrappe()
    st = _st(b)
    st.physisch = "llm"
    await st.setze_phase("protokoll")
    ergebnis = await st.setze_phase("schreibhilfe")  # gleiche physische Phase
    assert b.ereignisse == []
    assert ergebnis["phase"] == "schreibhilfe" and ergebnis["geschaetzte_dauer_s"] == 0


async def test_unbekannte_phase_wird_abgelehnt():
    with pytest.raises(ValueError):
        await _st(Attrappe()).setze_phase("kaffeepause")


async def test_wartet_mit_dem_stoppen_bis_whisper_nichts_mehr_zu_tun_hat():
    b = Attrappe(aktiv_nacheinander=[True, True, False])
    st = _st(b)
    st.physisch = "whisper"
    await st.setze_phase("protokoll")
    assert b.ereignisse == ["whisper_stopp"] and b._aktiv == []


async def test_gibt_nach_der_frist_auf_statt_ewig_zu_warten():
    b = Attrappe(dauerhaft_aktiv=True)
    st = Steuerung(b, MESSWERTE, warte_s=0.0, frist_s=0.05)
    st.physisch = "whisper"
    with pytest.raises(TimeoutError):
        await st.setze_phase("protokoll")
    assert b.ereignisse == []  # Whisper wurde NICHT mitten im Auftrag gestoppt


async def test_initialisieren_erkennt_laufendes_whisper():
    class Laeuft(Attrappe):
        async def whisper_gesund(self):
            return True

    b = Laeuft()
    st = _st(b)
    await st.initialisieren()
    assert st.physisch == "whisper"
    assert b.ereignisse == ["ollama_entladen"]  # nie beide gleichzeitig im Speicher


async def test_initialisieren_ohne_whisper_geht_in_llm_phase():
    b = Attrappe()
    st = _st(b)
    await st.initialisieren()
    assert st.physisch == "llm"


async def test_status_zeigt_den_laufenden_wechsel_mit_geschaetzter_dauer():
    import asyncio

    class Langsam(Attrappe):
        def __init__(self):
            super().__init__()
            self.los = asyncio.Event()
            self.angefangen = asyncio.Event()

        async def whisper_stoppen(self):
            self.angefangen.set()
            await self.los.wait()

    b = Langsam()
    st = _st(b)
    st.physisch = "whisper"
    aufgabe = asyncio.create_task(st.setze_phase("protokoll"))
    await b.angefangen.wait()
    mitten = st.status()
    assert mitten["wechselt_zu"] == "protokoll"
    assert mitten["geschaetzte_dauer_s"] == pytest.approx(6.9)
    b.los.set()
    await aufgabe
    danach = st.status()
    assert danach["wechselt_zu"] is None and danach["phase"] == "protokoll"
