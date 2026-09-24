#!/usr/bin/env bash
# Melhoria (dentro do orcamento de 16 GB): rApp simulado (Non-RT RIC / SMO) que aplica
# uma politica de escala nao-tempo-real sobre oran-cu, com base na taxa de requisicoes
# de /metrics. Ver lab/nephio/rapp-autoscale/rapp.py para o design completo e por que
# isto e um rApp (Non-RT RIC, parte do SMO) e nao um xApp (Near-RT RIC, fora de escopo).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "== 1) RBAC (ServiceAccount + Role escopado a oran-cu) =="
kubectl --context o-cloud-1 apply -f "$ROOT/lab/nephio/rapp-autoscale/rbac.yaml"

echo "== 2) builda e carrega a imagem rapp-autoscale:v1 no o-cloud-1 =="
docker build -q -t rapp-autoscale:v1 "$ROOT/lab/nephio/rapp-autoscale"
kind load docker-image rapp-autoscale:v1 --name o-cloud-1

echo "== 3) aplica o Deployment =="
kubectl --context o-cloud-1 apply -f "$ROOT/lab/nephio/rapp-autoscale/deployment.yaml"
kubectl --context o-cloud-1 -n openran-lab rollout status deploy/rapp-autoscale --timeout=60s

echo "== 4) logs iniciais =="
sleep 5
kubectl --context o-cloud-1 -n openran-lab logs deploy/rapp-autoscale --tail=20
