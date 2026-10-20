#!/usr/bin/env python3
"""Misst, was ein Wechsel der GPU von Whisper zu einem Sprachmodell (und zurueck) dauert.

Ablauf eines Messlaufs (Whisper laeuft, das Sprachmodell ist entladen):
  1. Whisper stoppen                      -> whisper_entladen_s
  2. Sprachmodell laden (leerer Prompt)   -> gemma_laden_s
  3. kurzer Prompt, gestreamt             -> erstes_token_s (bis zum ersten Stueck), tok_pro_s
  4. Sprachmodell entladen                -> gemma_entladen_s (beide zusammen passen nicht in 24 GB)
  5. Whisper starten bis /health ok       -> whisper_starten_s

Aufruf auf vali-gpu: modellwechsel.py --laeufe 5 --ctx 16384
Nur Standardbibliothek, damit es ohne zusaetzliche Pakete auf der Appliance laeuft.
"""
import argparse
import json
import statistics
import subprocess
import time
import urllib.request

PROMPT = "Nenne drei Vorteile eines schriftlichen Protokolls nach einer Besprechung."


def _post_stream(url, body):
    req = urllib.request.Request(url, data=json.dumps(body).encode(), headers={"content-type": "application/json"})
    return urllib.request.urlopen(req, timeout=900)


def _warte_auf_health(whisper_url, frist_s=300):
    ende = time.monotonic() + frist_s
    while time.monotonic() < ende:
        try:
            with urllib.request.urlopen(whisper_url.rstrip("/") + "/health", timeout=5) as r:
                if r.status == 200:
                    return
        except OSError:
            pass
        time.sleep(1)
    raise TimeoutError("Whisper wurde nicht gesund")


def messe_wechsel(ollama_url, whisper_url, whisper_stoppen, whisper_starten,
                  modell="gemma4:31b", num_ctx=16384):
    """Ein Messlauf. whisper_stoppen/whisper_starten sind Funktionen ohne Argumente (z. B. docker stop/start)."""
    t = time.monotonic()
    whisper_stoppen()
    entladen = time.monotonic() - t

    t = time.monotonic()
    with _post_stream(ollama_url + "/api/generate",
                      {"model": modell, "prompt": "", "keep_alive": -1, "options": {"num_ctx": num_ctx}}) as r:
        r.read()
    laden = time.monotonic() - t

    t = time.monotonic()
    erstes = None
    tok_pro_s = 0.0
    with _post_stream(ollama_url + "/api/generate",
                      {"model": modell, "prompt": PROMPT, "stream": True, "think": False,
                       "keep_alive": -1, "options": {"num_ctx": num_ctx}}) as r:
        for zeile in r:
            if not zeile.strip():
                continue
            d = json.loads(zeile)
            if erstes is None and d.get("response"):
                erstes = time.monotonic() - t
            if d.get("done") and d.get("eval_duration"):
                tok_pro_s = d["eval_count"] / (d["eval_duration"] / 1e9)

    t = time.monotonic()
    _entladen(ollama_url, modell)
    gemma_entladen = time.monotonic() - t

    t = time.monotonic()
    whisper_starten()
    _warte_auf_health(whisper_url)
    starten = time.monotonic() - t

    return {
        "whisper_entladen_s": float(entladen),
        "gemma_laden_s": float(laden),
        "erstes_token_s": float(erstes if erstes is not None else 0.0),
        "tok_pro_s": float(tok_pro_s),
        "gemma_entladen_s": float(gemma_entladen),
        "whisper_starten_s": float(starten),
    }


def median_ergebnis(laeufe):
    """Median je Schluessel ueber mehrere Messlaeufe."""
    return {k: float(statistics.median(l[k] for l in laeufe)) for k in laeufe[0]}


def _docker(aktion):
    return lambda: subprocess.run(["sudo", "docker", aktion, "ghost-transcriber"], check=True,
                                  stdout=subprocess.DEVNULL)


def _entladen(ollama_url, modell):
    with _post_stream(ollama_url + "/api/generate", {"model": modell, "keep_alive": 0}) as r:
        r.read()


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--ollama", default="http://10.77.0.3:11434")
    ap.add_argument("--whisper", default="http://10.77.0.3:8000")
    ap.add_argument("--modell", default="gemma4:31b")
    ap.add_argument("--ctx", type=int, default=16384)
    ap.add_argument("--laeufe", type=int, default=5)
    a = ap.parse_args()
    laeufe = []
    for i in range(a.laeufe):
        _entladen(a.ollama, a.modell)
        # Whisper muss fuer den Lauf laufen: bei Bedarf starten
        try:
            _warte_auf_health(a.whisper, frist_s=1)
        except TimeoutError:
            _docker("start")()
            _warte_auf_health(a.whisper)
        laeufe.append(messe_wechsel(a.ollama, a.whisper, _docker("stop"), _docker("start"), a.modell, a.ctx))
        print(json.dumps({"lauf": i + 1, **laeufe[-1]}), flush=True)
    print(json.dumps({"median": median_ergebnis(laeufe), "ctx": a.ctx, "modell": a.modell}))
