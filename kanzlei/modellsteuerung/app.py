"""HTTP-Schicht der Modellsteuerung: Steuer-API (8002) und zwei durchreichende Proxys.

  Whisper-Proxy (8003): jeder Auftrag (ausser /health) schaltet vorher auf "transkription".
  Ollama-Proxy  (8004): Generierungsanfragen fuer grosse Modelle schalten auf "protokoll" (agent-*) bzw.
                        "schreibhilfe"; Einbettungen und Verwaltungsaufrufe laufen ohne Umschalten durch.
So bleibt das Vali-Backend unveraendert: es spricht nur andere Adressen an.
"""
import asyncio
import json
import os
import subprocess

import httpx
from fastapi import FastAPI, HTTPException, Request, Response
from starlette.responses import StreamingResponse

GENERIERUNG = ("/api/generate", "/api/chat", "/v1/chat/completions", "/v1/completions")
HOP_HEADER = {"host", "content-length", "connection", "transfer-encoding", "keep-alive", "te", "upgrade"}


async def _durchreichen(client: httpx.AsyncClient, request: Request, body: bytes) -> Response:
    headers = {k: v for k, v in request.headers.items() if k.lower() not in HOP_HEADER}
    req = client.build_request(request.method, request.url.path, params=request.query_params, headers=headers, content=body)
    antwort = await client.send(req, stream=True)

    async def stuecke():
        try:
            async for teil in antwort.aiter_raw():
                yield teil
        finally:
            await antwort.aclose()

    ausgehend = {k: v for k, v in antwort.headers.items() if k.lower() not in HOP_HEADER | {"content-encoding"}}
    return StreamingResponse(stuecke(), status_code=antwort.status_code, headers=ausgehend)


def erstelle_apps(steuerung, whisper: httpx.AsyncClient, ollama: httpx.AsyncClient,
                  grosse=("gemma4", "agent-")):
    steuer = FastAPI(title="Modellsteuerung")

    @steuer.get("/status")
    async def status():
        return steuerung.status()

    @steuer.post("/phase/{name}")
    async def phase(name: str):
        try:
            return await steuerung.setze_phase(name)
        except ValueError as e:
            raise HTTPException(422, str(e))
        except TimeoutError as e:
            raise HTTPException(503, str(e))

    whisper_app = FastAPI(title="Whisper-Proxy")

    @whisper_app.api_route("/{pfad:path}", methods=["GET", "POST", "PUT", "DELETE", "HEAD"])
    async def whisper_durch(pfad: str, request: Request):
        if request.url.path != "/health":
            try:
                await steuerung.setze_phase("transkription")
            except TimeoutError as e:
                raise HTTPException(503, str(e))
        return await _durchreichen(whisper, request, await request.body())

    ollama_app = FastAPI(title="Ollama-Proxy")

    @ollama_app.api_route("/{pfad:path}", methods=["GET", "POST", "PUT", "DELETE", "HEAD"])
    async def ollama_durch(pfad: str, request: Request):
        body = await request.body()
        if request.method == "POST" and request.url.path in GENERIERUNG:
            try:
                modell = json.loads(body or b"{}").get("model", "")
            except ValueError:
                modell = ""
            if modell.startswith(tuple(grosse)):
                try:
                    await steuerung.setze_phase("protokoll" if modell.startswith("agent-") else "schreibhilfe")
                except TimeoutError as e:
                    raise HTTPException(503, str(e))
        return await _durchreichen(ollama, request, body)

    return steuer, whisper_app, ollama_app


def ollama_mib_aus_nvidia_smi(text: str) -> int:
    """Summe des Grafikspeichers aller Ollama-Prozesse aus der Ausgabe von
    nvidia-smi --query-compute-apps=process_name,used_memory --format=csv,noheader,nounits."""
    summe = 0
    for zeile in text.splitlines():
        name, _, mib = zeile.rpartition(",")
        if "ollama" in name or "llama-server" in name:
            summe += int(mib)
    return summe


class Systembackends:
    """Echte Anbindung: Docker-Container, Whisper-API, Ollama-API, nvidia-smi."""

    def __init__(self, whisper_url, ollama_url, container="ghost-transcriber"):
        self.whisper_url, self.ollama_url, self.container = whisper_url, ollama_url, container

    async def _docker(self, aktion):
        p = await asyncio.create_subprocess_exec("sudo", "-n", "/usr/bin/docker", aktion, self.container,
                                                 stdout=asyncio.subprocess.DEVNULL, stderr=asyncio.subprocess.PIPE)
        _, fehler = await p.communicate()
        if p.returncode != 0:
            raise RuntimeError(f"docker {aktion} {self.container}: {fehler.decode()[:200]}")

    async def whisper_gesund(self):
        try:
            async with httpx.AsyncClient(timeout=3) as c:
                return (await c.get(self.whisper_url + "/health")).status_code == 200
        except httpx.HTTPError:
            return False

    async def whisper_aktiv(self):
        try:
            async with httpx.AsyncClient(timeout=5) as c:
                q = (await c.get(self.whisper_url + "/api/queue")).json()
            return (q.get("queued_jobs", 0) + q.get("processing_jobs", 0)) > 0
        except httpx.HTTPError:
            return False

    async def whisper_stoppen(self):
        await self._docker("stop")

    async def whisper_starten(self):
        await self._docker("start")
        for _ in range(120):
            if await self.whisper_gesund():
                return
            await asyncio.sleep(1)
        raise RuntimeError("Whisper wurde nach dem Start nicht gesund")

    async def _ollama_belegt_mib(self):
        p = await asyncio.create_subprocess_exec(
            "nvidia-smi", "--query-compute-apps=process_name,used_memory", "--format=csv,noheader,nounits",
            stdout=asyncio.subprocess.PIPE)
        aus, _ = await p.communicate()
        return ollama_mib_aus_nvidia_smi(aus.decode())

    async def ollama_alle_entladen(self):
        async with httpx.AsyncClient(timeout=30) as c:
            for m in (await c.get(self.ollama_url + "/api/ps")).json().get("models", []):
                await c.post(self.ollama_url + "/api/generate", json={"model": m["name"], "keep_alive": 0})
        for _ in range(120):  # Ollama gibt die Anfrage sofort zurueck, der Speicher wird kurz danach frei
            if await self._ollama_belegt_mib() < 50:
                return
            await asyncio.sleep(0.5)
        raise RuntimeError("Ollama hat den Grafikspeicher nach dem Entladen nicht freigegeben")


def main():  # pragma: no cover - Start im Betrieb
    import uvicorn
    from steuerung import Steuerung, lade_messwerte

    whisper_url = os.environ.get("WHISPER_UPSTREAM", "http://127.0.0.1:8000")
    ollama_url = os.environ.get("OLLAMA_UPSTREAM", "http://10.77.0.3:11434")
    bind = os.environ.get("BIND", "0.0.0.0")
    st = Steuerung(Systembackends(whisper_url, ollama_url), lade_messwerte(os.environ["MESSWERTE"]))
    steuer, w, o = erstelle_apps(st, httpx.AsyncClient(base_url=whisper_url, timeout=None),
                                 httpx.AsyncClient(base_url=ollama_url, timeout=None))

    async def lauf():
        await st.initialisieren()
        server = [uvicorn.Server(uvicorn.Config(a, host=bind, port=p, log_level="info"))
                  for a, p in ((steuer, 8002), (w, 8003), (o, 8004))]
        await asyncio.gather(*(s.serve() for s in server))

    asyncio.run(lauf())


if __name__ == "__main__":  # pragma: no cover
    main()
