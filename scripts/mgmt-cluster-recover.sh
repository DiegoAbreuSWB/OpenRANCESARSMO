#!/usr/bin/env bash
# Recupera o cluster nephio-mgmt após um reinício da VM do WSL2 e valida a saúde.
# Idempotente. Uso: bash scripts/mgmt-cluster-recover.sh
set -uo pipefail
CTX="kind-nephio-mgmt"
NODE_CT="nephio-mgmt-control-plane"
EVID="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/evidence/nephio-install"
mkdir -p "$EVID"
log="$EVID/$(date +%Y%m%d-%H%M%S)_mgmt-recover-verify.txt"
exec > >(tee "$log") 2>&1
echo "== recover/verify nephio-mgmt :: $(date -Is) =="
echo "VM uptime: $(uptime -p)"

# 1) esperar o docker
for i in $(seq 1 30); do
  if docker info >/dev/null 2>&1; then echo "[ok] docker pronto (${i}s)"; break; fi
  sleep 1
done

# 2) garantir o container do nó de pé
state="$(docker inspect -f '{{.State.Status}}' "$NODE_CT" 2>/dev/null || echo missing)"
echo "estado do container do nó: $state"
if [ "$state" != "running" ] && [ "$state" != "missing" ]; then
  echo "[fix] docker start $NODE_CT"; docker start "$NODE_CT" || true
fi

# 3) esperar o apiserver responder
for i in $(seq 1 60); do
  if kubectl --context "$CTX" get --raw=/readyz >/dev/null 2>&1; then echo "[ok] apiserver readyz (${i}s)"; break; fi
  sleep 2
done

# 4) esperar nó Ready e componentes de sistema
kubectl --context "$CTX" wait --for=condition=Ready node --all --timeout=180s
kubectl --context "$CTX" -n kube-system rollout status deploy/coredns --timeout=120s || true

echo; echo "== nodes =="
kubectl --context "$CTX" get nodes -o wide
echo; echo "== pods -A =="
kubectl --context "$CTX" get pods -A
echo; echo "== pods problemáticos =="
kubectl --context "$CTX" get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded || true
echo; echo "== deploy/ds/sts -A =="
kubectl --context "$CTX" get deploy,ds,sts -A
echo; echo "== nº de CRDs =="
kubectl --context "$CTX" get crd --no-headers 2>/dev/null | wc -l
echo; echo "== contextos =="
kubectl config get-contexts
echo; echo "== docker ps =="
docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'
echo; echo "== free -h =="
free -h
echo; echo "[ok] log: $log"
