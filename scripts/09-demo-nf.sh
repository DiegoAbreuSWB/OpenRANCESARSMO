#!/usr/bin/env bash
# ETAPA 9 - implanta e valida o demo-nf no workload cluster o-cloud-1.
set -uo pipefail
CTX="o-cloud-1"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EVID="$ROOT/evidence/lifecycle"; mkdir -p "$EVID"
log="$EVID/$(date +%Y%m%d-%H%M%S)_etapa9_deploy.txt"
exec > >(tee "$log") 2>&1
echo "== ETAPA 9 :: deploy demo-nf :: $(date -Is) =="
echo "contexto alvo: $CTX  ($(kubectl --context $CTX config view --minify -o jsonpath='{.clusters[0].cluster.server}' 2>/dev/null))"

kubectl --context "$CTX" apply -f "$ROOT/manifests/demo-nf.yaml"
echo
kubectl --context "$CTX" rollout status deploy/demo-nf --timeout=120s

echo; echo "-- deployment --"
kubectl --context "$CTX" get deployment demo-nf -o wide
echo; echo "-- pods --"
kubectl --context "$CTX" get pods -l app=demo-nf -o wide
echo; echo "-- service --"
kubectl --context "$CTX" get svc demo-nf
echo; echo "-- describe deployment --"
kubectl --context "$CTX" describe deployment demo-nf | sed -n '1,40p'
echo; echo "-- teste HTTP interno (curl a partir de um pod efêmero) --"
kubectl --context "$CTX" run demo-nf-curl --rm -i --restart=Never --image=curlimages/curl:8.10.1 -- \
  -s -o /dev/null -w "demo-nf svc -> HTTP %{http_code}\n" http://demo-nf.default.svc.cluster.local 2>&1 || true
echo; echo "[ok] log: $log"
