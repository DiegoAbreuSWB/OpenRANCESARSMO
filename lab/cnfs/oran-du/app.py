"""
oran-du - simulador LEVE de um O-DU (Distributed Unit).

ATENCAO: isto NAO implementa F1/Open Fronthaul nem qualquer protocolo O-RAN real. E um
workload representativo (FastAPI) usado apenas para demonstrar onboarding, configuration
management, monitoring e lifecycle sobre uma NF simulada. Ver lab/cnfs/README.md.

Esta e a NF usada no Experimento 2 (mudanca de cell_id).
"""
import os
import time

from fastapi import Body, FastAPI
from fastapi.responses import PlainTextResponse

NF_NAME = os.environ.get("NF_NAME", "oran-du")
NF_TYPE = os.environ.get("NF_TYPE", "O-DU")
NF_VERSION = os.environ.get("NF_VERSION", "v1")
# auto-reportado; o valor autoritativo de reinicios vem do Kubernetes (RESTARTS em `kubectl get pods`)
RESTART_COUNT = int(os.environ.get("NF_RESTART_COUNT", "0"))

# Config de dominio lida do ConfigMap (envFrom no Deployment) quando presente - e o
# que permite ao config-bridge (lab/nephio/config-bridge) saber qual era o "ultimo
# estado publicado no pacote" ao decidir se precisa comitar uma correcao de drift.
# Antes desta mudanca estes valores eram hardcoded aqui e nao existiam no pacote kpt -
# por isso a config de dominio (cell_id etc.) nunca "propagava de volta ao pacote"
# (limitacao registrada em report/part2-report.md Sec.14 item 5).
DEFAULT_CONFIG = {
    "plmn_id": os.environ.get("CFG_PLMN_ID", "00101"),
    "cell_id": int(os.environ.get("CFG_CELL_ID", "1")),
    "tx_power_dbm": int(os.environ.get("CFG_TX_POWER_DBM", "20")),
    "du_id": int(os.environ.get("CFG_DU_ID", "1")),
}

app = FastAPI(title=f"{NF_NAME} simulator", version=NF_VERSION)

STATE = {
    "config": dict(DEFAULT_CONFIG),
    "config_version": 1,
    "requests_total": 0,
    "start_time": time.time(),
}


@app.middleware("http")
async def _count_requests(request, call_next):
    STATE["requests_total"] += 1
    return await call_next(request)


@app.get("/health")
def health():
    return {
        "status": "ok",
        "nf_name": NF_NAME,
        "nf_type": NF_TYPE,
        "nf_version": NF_VERSION,
        "uptime_seconds": round(time.time() - STATE["start_time"], 1),
    }


@app.get("/config")
def get_config():
    return {
        "nf_name": NF_NAME,
        "config_version": STATE["config_version"],
        "config": STATE["config"],
    }


def _apply_config_update(update: dict):
    if update:
        STATE["config"].update(update)
        STATE["config_version"] += 1
    return {
        "status": "updated",
        "nf_name": NF_NAME,
        "config_version": STATE["config_version"],
        "config": STATE["config"],
    }


@app.put("/config")
def put_config(update: dict = Body(default_factory=dict)):
    return _apply_config_update(update)


@app.post("/config")
def post_config(update: dict = Body(default_factory=dict)):
    return _apply_config_update(update)


@app.get("/metrics", response_class=PlainTextResponse)
def metrics():
    lines = [
        "# HELP nf_up 1 if the NF process is serving requests",
        "# TYPE nf_up gauge",
        f'nf_up{{nf_name="{NF_NAME}",nf_type="{NF_TYPE}"}} 1',
        "# HELP nf_requests_total total HTTP requests served since process start",
        "# TYPE nf_requests_total counter",
        f'nf_requests_total{{nf_name="{NF_NAME}"}} {STATE["requests_total"]}',
        "# HELP nf_config_version current configuration version (increments on each update)",
        "# TYPE nf_config_version gauge",
        f'nf_config_version{{nf_name="{NF_NAME}"}} {STATE["config_version"]}',
        "# HELP nf_restart_count self-reported restart count (see kubectl get pods for the authoritative value)",
        "# TYPE nf_restart_count counter",
        f'nf_restart_count{{nf_name="{NF_NAME}"}} {RESTART_COUNT}',
    ]
    return "\n".join(lines) + "\n"


@app.get("/")
def root():
    return {"nf_name": NF_NAME, "nf_type": NF_TYPE, "routes": ["/health", "/config", "/metrics"]}
