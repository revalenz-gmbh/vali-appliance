"""Tests fuer die HTTP-Schicht: Steuer-API und die zwei durchreichenden Proxys (app.py)."""
import httpx
import pytest

from app import erstelle_apps


class FakeSteuerung:
    def __init__(self):
        self.aufrufe = []

    async def setze_phase(self, name):
        self.aufrufe.append(("phase", name))
        if name not in ("transkription", "protokoll", "schreibhilfe"):
            raise ValueError(name)
        return {"phase": name, "bereit": True, "geschaetzte_dauer_s": 6.9}

    def status(self):
        return {"phase": "schreibhilfe", "bereit": True}


class _Strom(httpx.AsyncByteStream):
    """Antwort als echter Strom (wie von einem Server), nicht schon eingelesen."""

    async def __aiter__(self):
        yield b'{"ok":true}\n'
        yield b'{"done":true}\n'


def _upstream(name, aufrufe):
    def handler(req: httpx.Request) -> httpx.Response:
        aufrufe.append((name, req.method, req.url.path, req.content))
        return httpx.Response(200, stream=_Strom(), headers={"content-type": "application/x-ndjson"})
    return httpx.AsyncClient(transport=httpx.MockTransport(handler), base_url="http://upstream")


@pytest.fixture()
def apps():
    fake, aufrufe = FakeSteuerung(), []
    steuer, whisper, ollama = erstelle_apps(fake, _upstream("whisper", aufrufe), _upstream("ollama", aufrufe))
    cl = lambda a: httpx.AsyncClient(transport=httpx.ASGITransport(app=a), base_url="http://test")
    return fake, aufrufe, cl(steuer), cl(whisper), cl(ollama)


async def test_status_und_phase(apps):
    fake, _, steuer, _, _ = apps
    assert (await steuer.get("/status")).json() == {"phase": "schreibhilfe", "bereit": True}
    r = await steuer.post("/phase/protokoll")
    assert r.status_code == 200 and r.json()["geschaetzte_dauer_s"] == 6.9


async def test_unbekannte_phase_ist_422(apps):
    _, _, steuer, _, _ = apps
    assert (await steuer.post("/phase/kaffeepause")).status_code == 422


async def test_whisper_auftrag_schaltet_vorher_auf_transkription(apps):
    fake, aufrufe, _, whisper, _ = apps
    r = await whisper.post("/upload", content=b"audio")
    assert r.status_code == 200 and b"done" in r.content
    assert fake.aufrufe == [("phase", "transkription")]
    assert aufrufe == [("whisper", "POST", "/upload", b"audio")]


async def test_whisper_health_schaltet_nicht(apps):
    fake, aufrufe, _, whisper, _ = apps
    assert (await whisper.get("/health")).status_code == 200
    assert fake.aufrufe == []


@pytest.mark.parametrize("modell,phase", [("agent-sekretaer:latest", "protokoll"), ("gemma4:31b", "schreibhilfe")])
async def test_grosses_modell_schaltet_auf_llm(apps, modell, phase):
    fake, _, _, _, ollama = apps
    r = await ollama.post("/api/generate", json={"model": modell, "prompt": "x"})
    assert r.status_code == 200
    assert fake.aufrufe == [("phase", phase)]


async def test_kleines_modell_und_verwaltungsaufrufe_schalten_nicht(apps):
    fake, aufrufe, _, _, ollama = apps
    await ollama.post("/api/embed", json={"model": "embeddinggemma", "input": "x"})
    await ollama.get("/api/tags")
    assert fake.aufrufe == []
    assert [a[2] for a in aufrufe] == ["/api/embed", "/api/tags"]


async def test_chat_endpunkt_der_openai_schnittstelle_wird_erkannt(apps):
    fake, _, _, _, ollama = apps
    await ollama.post("/v1/chat/completions", json={"model": "gemma4:31b", "messages": []})
    assert fake.aufrufe == [("phase", "schreibhilfe")]


def test_ollama_speicher_wird_aus_nvidia_smi_nur_fuer_ollama_prozesse_summiert():
    from app import ollama_mib_aus_nvidia_smi
    text = "python3.12, 3976\n/usr/local/lib/ollama/llama-server, 19822\n/usr/local/lib/ollama/llama-server, 100\n"
    assert ollama_mib_aus_nvidia_smi(text) == 19922
    assert ollama_mib_aus_nvidia_smi("python3.12, 3976\n") == 0
    assert ollama_mib_aus_nvidia_smi("") == 0
