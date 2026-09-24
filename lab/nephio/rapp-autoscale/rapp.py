"""
rapp-autoscale - um rApp simulado (analogo ao que rodaria no Non-RT RIC, que e parte
do proprio SMO na arquitetura O-RAN - ver docs/nephio-vs-smo.md Sec.1/2).

POR QUE rApp E NAO xApp: xApps rodam no Near-RT RIC e falam E2 (E2AP/ASN.1 sobre SCTP)
com os "E2 Nodes" (O-CU/O-DU) em ciclo QUASE-tempo-real (10ms-1s, por definicao O-RAN).
Nossas CNFs simuladas nao tem nenhum agente E2 real - simular isso seria inventar uma
interface que nao existe de fato no laboratorio (contra a regra deste trabalho de nunca
fingir que algo funciona). rApps rodam no Non-RT RIC em ciclo NAO-tempo-real (>1s,
tipicamente segundos a minutos) e fazem analytics/otimizacao sobre dados que ja temos de
verdade (as metricas /metrics das CNFs) - por isso o poll aqui e de 30s, deliberadamente
lento, para marcar essa distincao na pratica, nao so no texto.

O QUE FAZ: le /metrics de oran-cu (endpoint Prometheus-like ja usado no laboratorio),
calcula a taxa de requisicoes (nf_requests_total) entre dois polls, e aplica uma politica
de escala nao-tempo-real - a mesma classe de decisao que um rApp de "traffic steering /
capacity optimization" tomaria no mundo real, so que aqui a acao e executada diretamente
via API do Kubernetes (patch no Deployment), nao publicada como uma policy A1 para um
Near-RT RIC (que nao existe neste laboratorio). Essa simplificacao e deliberada e esta
documentada em docs/improvements-16gb.md - o mesmo padrao ja usado no config-bridge
(commit direto no Gitea em vez do ciclo Porch completo).
"""
import os
import time
import logging

import requests

logging.basicConfig(level=logging.INFO, format="%(asctime)s INFO %(message)s")
log = logging.getLogger("rapp-autoscale")

NS = os.environ.get("TARGET_NAMESPACE", "openran-lab")
DEPLOY = os.environ.get("TARGET_DEPLOYMENT", "oran-cu")
METRICS_URL = os.environ.get("METRICS_URL", "http://oran-cu.openran-lab.svc.cluster.local:8080/metrics")
POLL_SECONDS = int(os.environ.get("POLL_SECONDS", "30"))  # nao-tempo-real (O-RAN: rApp >1s, xApp 10ms-1s)
UP_RATE = float(os.environ.get("UP_RATE_REQ_S", "1.0"))   # req/s acima disto -> escala pra cima
DOWN_RATE = float(os.environ.get("DOWN_RATE_REQ_S", "0.1"))  # req/s abaixo disto -> escala pra baixo
MIN_REPLICAS = int(os.environ.get("MIN_REPLICAS", "1"))
MAX_REPLICAS = int(os.environ.get("MAX_REPLICAS", "3"))

K8S_API = "https://kubernetes.default.svc"
TOKEN_PATH = "/var/run/secrets/kubernetes.io/serviceaccount/token"
CA_PATH = "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"


def _k8s_headers():
    with open(TOKEN_PATH) as f:
        token = f.read().strip()
    return {"Authorization": f"Bearer {token}"}


def get_replicas() -> int:
    url = f"{K8S_API}/apis/apps/v1/namespaces/{NS}/deployments/{DEPLOY}"
    r = requests.get(url, headers=_k8s_headers(), verify=CA_PATH, timeout=5)
    r.raise_for_status()
    return r.json()["spec"]["replicas"]


def set_replicas(n: int):
    url = f"{K8S_API}/apis/apps/v1/namespaces/{NS}/deployments/{DEPLOY}/scale"
    headers = _k8s_headers()
    headers["Content-Type"] = "application/merge-patch+json"
    r = requests.patch(url, headers=headers, verify=CA_PATH, timeout=5, json={"spec": {"replicas": n}})
    r.raise_for_status()


def get_requests_total() -> float:
    r = requests.get(METRICS_URL, timeout=5)
    r.raise_for_status()
    for line in r.text.splitlines():
        if line.startswith("nf_requests_total{"):
            return float(line.rsplit(" ", 1)[1])
    return 0.0


def decide(rate: float, replicas: int) -> int:
    """Politica do rApp: analogo a uma recomendacao de 'capacity optimization' que um
    rApp real publicaria como policy A1 - aqui, executada diretamente."""
    if rate > UP_RATE and replicas < MAX_REPLICAS:
        return replicas + 1
    if rate < DOWN_RATE and replicas > MIN_REPLICAS:
        return replicas - 1
    return replicas


def main():
    log.info(
        "rapp-autoscale iniciado | alvo=%s/%s | poll=%ss (nao-tempo-real) | "
        "politica: rate>%.2f req/s -> scale up | rate<%.2f req/s -> scale down | [%d..%d] replicas",
        NS, DEPLOY, POLL_SECONDS, UP_RATE, DOWN_RATE, MIN_REPLICAS, MAX_REPLICAS,
    )
    prev_total = None
    prev_time = None
    while True:
        try:
            total = get_requests_total()
            replicas = get_replicas()
            now = time.time()
            if prev_total is None:
                rate = 0.0
            else:
                dt = max(now - prev_time, 1e-6)
                rate = max(total - prev_total, 0.0) / dt
            prev_total, prev_time = total, now

            target = decide(rate, replicas)
            if target != replicas:
                log.info(
                    "DECISAO rApp: rate=%.2f req/s replicas=%d -> %d (politica de capacidade nao-tempo-real)",
                    rate, replicas, target,
                )
                set_replicas(target)
                log.info("acao aplicada via Kubernetes API (patch Deployment/%s scale)", DEPLOY)
            else:
                log.info("sem acao: rate=%.2f req/s replicas=%d (dentro da faixa)", rate, replicas)
        except Exception as e:
            log.warning("ciclo falhou (%s) - tentando de novo no proximo poll", e)
        time.sleep(POLL_SECONDS)


if __name__ == "__main__":
    main()
