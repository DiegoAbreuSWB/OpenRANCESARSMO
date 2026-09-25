#!/usr/bin/env python3
"""
Servidor local do Console SMO Nephio - backend leve (biblioteca padrao do Python,
zero dependencias) que expoe o painel de operacao em http://localhost:PORT/ e
consulta o cluster real via kubectl para os widgets ao vivo (status, metricas,
logs de decisao do rApp e do config-bridge).

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

# Ultimo estado de referencia (usado quando o cluster nao esta acessivel no momento).
SNAPSHOT = {
    "nodes_ready": 2, "nodes_total": 2,
    "cnfs_running": 3, "cnfs_total": 3,
}

LOG_COMPONENTS = {"rapp-autoscale", "config-bridge"}


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
    out = {"nodes_ready": None, "nodes_total": None, "cnfs_running": None, "cnfs_total": None}

    nodes = _kubectl(["--context", "o-cloud-1", "get", "nodes", "--no-headers"])
    if nodes is not None:
        lines = [l for l in nodes.splitlines() if l.strip()]
        out["nodes_total"] = len(lines)
        out["nodes_ready"] = sum(1 for l in lines if " Ready" in l or "\tReady" in l)

    # Só as 3 CNFs entregues via pacote Porch (config-bridge/rapp-autoscale/metrics-server
    # também vivem no namespace openran-lab, mas não entram nessa contagem).
    pods = _kubectl(["--context", "o-cloud-1", "-n", "openran-lab", "get", "deploy",
                      "oran-cu", "oran-du", "oran-core", "--no-headers"])
    if pods is not None:
        lines = [l for l in pods.splitlines() if l.strip()]
        out["cnfs_total"] = len(lines)
        ready = 0
        for l in lines:
            cols = l.split()
            if len(cols) >= 2 and "/" in cols[1]:
                a, b = cols[1].split("/")
                if a == b and a != "0":
                    ready += 1
        out["cnfs_running"] = ready

    return out


def get_top():
    """kubectl top nodes/pods reais - usado pelo widget de metricas ao vivo."""
    nodes_raw = _kubectl(["--context", "o-cloud-1", "top", "nodes", "--no-headers"])
    pods_raw = _kubectl(["--context", "o-cloud-1", "-n", "openran-lab", "top", "pods", "--no-headers"])
    nodes, pods = [], []
    if nodes_raw:
        for l in nodes_raw.splitlines():
            c = l.split()
            if len(c) >= 5:
                nodes.append({"name": c[0], "cpu": c[1], "cpu_pct": c[2], "mem": c[3], "mem_pct": c[4]})
    if pods_raw:
        for l in pods_raw.splitlines():
            c = l.split()
            if len(c) >= 3:
                pods.append({"name": c[0], "cpu": c[1], "mem": c[2]})
    return {"nodes": nodes, "pods": pods, "live": bool(nodes)}


def get_logs(component):
    raw = _kubectl(["--context", "o-cloud-1", "-n", "openran-lab", "logs",
                     f"deploy/{component}", "--tail=12"])
    if raw is None:
        return {"lines": [], "live": False}
    return {"lines": raw.splitlines(), "live": True}


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
            return self._json(self._status_body())
        if self.path.startswith("/api/top"):
            return self._json(get_top())
        if self.path.startswith("/api/logs"):
            comp = "rapp-autoscale"
            if "component=" in self.path:
                comp = self.path.split("component=", 1)[1].split("&")[0]
            if comp not in LOG_COMPONENTS:
                comp = "rapp-autoscale"
            return self._json(get_logs(comp))
        return super().do_GET()

    def _status_body(self):
        live = get_live_status()
        now = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        return {
            "checked_at": now,
            "nodes_ready": live["nodes_ready"] if live["nodes_ready"] is not None else SNAPSHOT["nodes_ready"],
            "nodes_total": live["nodes_total"] if live["nodes_total"] is not None else SNAPSHOT["nodes_total"],
            "cnfs_running": live["cnfs_running"] if live["cnfs_running"] is not None else SNAPSHOT["cnfs_running"],
            "cnfs_total": live["cnfs_total"] if live["cnfs_total"] is not None else SNAPSHOT["cnfs_total"],
            "live": live["nodes_ready"] is not None,
        }

    def _json(self, body):
        payload = json.dumps(body).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(payload)


def main():
    server = http.server.ThreadingHTTPServer(("127.0.0.1", PORT), Handler)
    print(f"Console SMO Nephio rodando em http://localhost:{PORT}/")
    print("Ctrl+C para parar.")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nencerrado.")


if __name__ == "__main__":
    main()
