#!/usr/bin/env python3
"""
Servidor local do Console SMO Nephio - roda em localhost, sem nenhuma dependencia
externa (so biblioteca padrao do Python), na mesma filosofia minimalista que a outra
equipe usou no portal deles (backend com poucas dependencias, sem build step).

Por que isto existe: o dashboard publicado como Claude Artifact (dashboard/index.html)
depende do visualizador da Claude para renderizar o Mermaid nativamente e nao tem como
consultar o cluster ao vivo. Para demonstracao em sala/apresentacao, "localhost, nao um
link do claude" e o que se espera de um portal de operacao de verdade - entao este
servidor roda dashboard/local.html (HTML completo e independente, com Mermaid.js via
CDN) e expoe /api/status consultando o cluster real via kubectl, com fallback honesto
para o ultimo snapshot conhecido quando o cluster nao esta acessivel.

Uso:
    python3 dashboard/server.py [porta]   # padrao: 8090
Depois abra: http://localhost:8090/
"""
import http.server
import json
import subprocess
import sys
import datetime
import os

ROOT = os.path.dirname(os.path.abspath(__file__))
PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8090

# Ultimo snapshot real conhecido (usado quando o cluster nao responde) - os mesmos
# numeros que ja estao documentados em evidence/ e no proprio dashboard estatico.
SNAPSHOT = {
    "nodes_ready": 2, "nodes_total": 2,
    "cnfs_running": 3, "cnfs_total": 3,
    "source": "snapshot",
}


def _kubectl(args, timeout=4):
    try:
        r = subprocess.run(
            ["kubectl"] + args,
            capture_output=True, text=True, timeout=timeout,
        )
        if r.returncode != 0:
            return None
        return r.stdout.strip()
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return None


def get_live_status():
    """Consulta o cluster real via kubectl. Retorna None por campo quando indisponivel
    (nunca inventa um numero - se nao conseguir ler, o campo fica None e o frontend
    mantem o snapshot estatico)."""
    out = {"nodes_ready": None, "nodes_total": None, "cnfs_running": None, "cnfs_total": None}

    nodes = _kubectl(["--context", "o-cloud-1", "get", "nodes", "--no-headers"])
    if nodes is not None:
        lines = [l for l in nodes.splitlines() if l.strip()]
        out["nodes_total"] = len(lines)
        out["nodes_ready"] = sum(1 for l in lines if " Ready" in l or "\tReady" in l)

    pods = _kubectl(["--context", "o-cloud-1", "-n", "openran-lab", "get", "deploy", "--no-headers"])
    if pods is not None:
        lines = [l for l in pods.splitlines() if l.strip()]
        out["cnfs_total"] = len(lines)
        ready = 0
        for l in lines:
            cols = l.split()
            # coluna READY tem formato "N/M"
            if len(cols) >= 2 and "/" in cols[1]:
                a, b = cols[1].split("/")
                if a == b and a != "0":
                    ready += 1
        out["cnfs_running"] = ready

    return out


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=ROOT, **kwargs)

    def log_message(self, fmt, *args):
        sys.stderr.write("[dashboard] " + (fmt % args) + "\n")

    def do_GET(self):
        if self.path == "/" or self.path == "":
            self.path = "/local.html"
            return super().do_GET()
        if self.path.startswith("/api/status"):
            return self._api_status()
        return super().do_GET()

    def _api_status(self):
        live = get_live_status()
        now = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        body = {
            "checked_at": now,
            "nodes_ready": live["nodes_ready"] if live["nodes_ready"] is not None else SNAPSHOT["nodes_ready"],
            "nodes_total": live["nodes_total"] if live["nodes_total"] is not None else SNAPSHOT["nodes_total"],
            "cnfs_running": live["cnfs_running"] if live["cnfs_running"] is not None else SNAPSHOT["cnfs_running"],
            "cnfs_total": live["cnfs_total"] if live["cnfs_total"] is not None else SNAPSHOT["cnfs_total"],
            "live": live["nodes_ready"] is not None,
        }
        payload = json.dumps(body).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(payload)


def main():
    server = http.server.ThreadingHTTPServer(("127.0.0.1", PORT), Handler)
    print(f"Console SMO Nephio (local) rodando em http://localhost:{PORT}/")
    print("Ctrl+C para parar.")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nencerrado.")


if __name__ == "__main__":
    main()
