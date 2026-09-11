#!/usr/bin/env bash
# ETAPA 1 - cria e valida o Management Cluster (kind: nephio-mgmt).
# Idempotente. Rodar dentro do WSL a partir da raiz do repositório:
#   bash scripts/01-mgmt-cluster.sh
set -euo pipefail

CLUSTER="nephio-mgmt"
CTX="kind-${CLUSTER}"
CFG="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/manifests/kind-management-cluster.yaml"
EVID="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/evidence/nephio-install"
mkdir -p "$EVID"
ts="$(date +%Y%m%d-%H%M%S)"
log="$EVID/${ts}_etapa1-mgmt-cluster.txt"

exec > >(tee "$log") 2>&1
echo "== ETAPA 1 :: $(date -Is) =="
echo "kind:    $(kind --version)"
echo "kubectl: $(kubectl version --client -o yaml | awk '/gitVersion/{print $2; exit}')"

if kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; then
  echo "[skip] cluster '$CLUSTER' já existe"
else
  echo "[create] kind create cluster --config $CFG"
  kind create cluster --config "$CFG"
fi

echo; echo "== kind get clusters =="
kind get clusters

echo; echo "== kubectl cluster-info --context $CTX =="
kubectl cluster-info --context "$CTX"

echo; echo "== kubectl get nodes =="
kubectl --context "$CTX" get nodes -o wide

echo; echo "== kubectl get pods -A =="
kubectl --context "$CTX" get pods -A

echo; echo "== pods NÃO Running/!Succeeded =="
kubectl --context "$CTX" get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded || true

echo; echo "== nós Ready? =="
kubectl --context "$CTX" wait --for=condition=Ready nodes --all --timeout=120s

echo; echo "== versão do servidor =="
kubectl --context "$CTX" version -o yaml | awk '/serverVersion/,/platform/'

echo; echo "[ok] evidência salva em $log"
