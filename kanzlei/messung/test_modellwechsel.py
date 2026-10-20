"""Tests fuer messung/modellwechsel.py gegen einen Dummy-Server (kein Ollama, kein Docker noetig)."""
import json
import threading
import time
from http.server import BaseHTTPRequestHandler, HTTPServer

import pytest

import modellwechsel

SCHLUESSEL = {"whisper_entladen_s", "gemma_laden_s", "erstes_token_s", "tok_pro_s", "gemma_entladen_s", "whisper_starten_s"}


class _Handler(BaseHTTPRequestHandler):
    ereignisse = []

    def log_message(self, *a):
        pass

    def do_GET(self):
        self.ereignisse.append("health")
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b'{"status":"ok"}')

    def do_POST(self):
        body = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
        if body.get("keep_alive") == 0:
            self.ereignisse.append("gemma_entladen")
        else:
            self.ereignisse.append("laden" if body.get("prompt") == "" else "generate")
        self.send_response(200)
        self.end_headers()
        if body.get("prompt") == "" or body.get("keep_alive") == 0:
            self.wfile.write(json.dumps({"done": True}).encode() + b"\n")
            return
        time.sleep(0.2)  # Zeit bis zum ersten Stueck
        self.wfile.write(json.dumps({"response": "Hallo", "done": False}).encode() + b"\n")
        self.wfile.flush()
        self.wfile.write(json.dumps({"done": True, "eval_count": 100, "eval_duration": 4_000_000_000}).encode() + b"\n")


@pytest.fixture()
def server():
    _Handler.ereignisse = []
    s = HTTPServer(("127.0.0.1", 0), _Handler)
    threading.Thread(target=s.serve_forever, daemon=True).start()
    yield f"http://127.0.0.1:{s.server_port}", _Handler.ereignisse
    s.shutdown()


def _messen(url, ereignisse):
    return modellwechsel.messe_wechsel(
        ollama_url=url, whisper_url=url,
        whisper_stoppen=lambda: ereignisse.append("stopp"),
        whisper_starten=lambda: ereignisse.append("start"),
    )


def test_liefert_alle_schluessel_als_nichtnegative_zahlen(server):
    url, ereignisse = server
    ergebnis = _messen(url, ereignisse)
    assert set(ergebnis) == SCHLUESSEL
    assert all(isinstance(v, float) and v >= 0 for v in ergebnis.values())


def test_whisper_wird_vor_dem_laden_von_gemma_gestoppt(server):
    url, ereignisse = server
    _messen(url, ereignisse)
    assert ereignisse.index("stopp") < ereignisse.index("laden") < ereignisse.index("generate")
    assert ereignisse.index("start") > ereignisse.index("generate")


def test_gemma_wird_entladen_bevor_whisper_wieder_startet(server):
    # beide zusammen passen nicht in 24 GB: Whisper darf erst starten, wenn Gemma entladen ist
    url, ereignisse = server
    _messen(url, ereignisse)
    assert ereignisse.index("generate") < ereignisse.index("gemma_entladen") < ereignisse.index("start")


def test_tok_pro_s_kommt_aus_eval_werten(server):
    url, ereignisse = server
    assert _messen(url, ereignisse)["tok_pro_s"] == pytest.approx(25.0)


def test_erstes_token_ist_die_zeit_bis_zum_ersten_stueck(server):
    url, ereignisse = server
    assert 0.15 <= _messen(url, ereignisse)["erstes_token_s"] < 1.0


def test_median_ueber_laeufe():
    assert modellwechsel.median_ergebnis([{"a": 1.0}, {"a": 5.0}, {"a": 3.0}]) == {"a": 3.0}
