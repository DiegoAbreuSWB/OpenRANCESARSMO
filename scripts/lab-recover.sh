#!/usr/bin/env bash
# lab-recover.sh - recupera AMBOS os clusters (nephio-mgmt e o-cloud-1) depois que a
# VM do WSL2 reinicia. Os containers do kind/CAPD param junto com a VM; este script
# os religa na ordem certa e espera os apiservers.
set -uo pipefail

start_ct(){ # nome
  local n="$1" st
  st="$(docker inspect -f '{{.State.Status}}' "$n" 2>/dev/null || echo missing)"
  case "$st" in
    running) echo "  [$n] já running";;
    missing) echo "  [$n] AUSENTE (container removido) — pode exigir re-provisionamento";;
    *) echo "  [$n] $st -> docker start"; docker start "$n" >/dev/null 2>&1 && echo "     ok" || echo "     FALHOU";;
  esac
}

echo "== VM uptime: $(uptime -p) =="
echo "== esperando docker =="
for i in $(seq 1 30); do docker info >/dev/null 2>&1 && break; sleep 2; done
docker info >/dev/null 2>&1 || { echo "docker não subiu"; exit 1; }

echo "== 1) management cluster =="
start_ct nephio-mgmt-control-plane
echo "   aguardando apiserver (kind-nephio-mgmt)..."
ok=false
for i in $(seq 1 60); do
  kubectl --context kind-nephio-mgmt get --raw=/readyz >/dev/null 2>&1 && { ok=true; break; }
  sleep 3
done
$ok && echo "   [ok] mgmt apiserver responde" || { echo "   [!] mgmt não respondeu; docker logs:"; docker logs --tail=25 nephio-mgmt-control-plane 2>&1 | sed 's/^/     /'; }

echo "== 2) o-cloud-1 (LB -> control-plane -> worker) =="
start_ct o-cloud-1-lb
start_ct o-cloud-1-jhflr-ljvxg
start_ct o-cloud-1-md-0-xw88l-wz8cl-7xssj
echo "   aguardando apiserver (o-cloud-1)..."
# refresca o kubeconfig do secret (o IP/porta podem mudar)
kubectl --context kind-nephio-mgmt -n default get secret o-cloud-1-kubeconfig -o jsonpath='{.data.value}' 2>/dev/null | base64 -d > /tmp/o-cloud-1.kubeconfig 2>/dev/null || true
ok=false
for i in $(seq 1 60); do
  kubectl --kubeconfig /tmp/o-cloud-1.kubeconfig get --raw=/readyz >/dev/null 2>&1 && { ok=true; break; }
  sleep 3
done
$ok && echo "   [ok] o-cloud-1 apiserver responde" || echo "   [!] o-cloud-1 não respondeu ainda (pode levar +1-2 min ou exigir recriação)"

echo
echo "== estado =="
kind get clusters 2>&1
echo "-- mgmt pods problemáticos --"
kubectl --context kind-nephio-mgmt get pods -A --no-headers 2>/dev/null | grep -vE '([0-9]+)/\1 +Running|Completed' | sed 's/^/   /' || echo "   (todos ok)"
echo "-- o-cloud-1 nodes --"
kubectl --kubeconfig /tmp/o-cloud-1.kubeconfig get nodes 2>&1 | sed 's/^/   /'
echo "-- containers --"
docker ps --format '   {{.Names}}  {{.Status}}' | grep -E 'o-cloud|nephio-mgmt'
free -h | sed 's/^/   /'
