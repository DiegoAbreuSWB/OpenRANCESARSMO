#!/usr/bin/env bash
# run-experiments.sh (Fase 13/15) - executa os 6 experimentos formais sobre as CNFs
# no o-cloud-1 e registra tempo/estado em results/experiments.csv.
# Uso: bash scripts/run-experiments.sh [1|2|3|4|5|6|all]
set -uo pipefail
export PATH="$HOME/.local/bin:$PATH"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OC=o-cloud-1
NS=openran-lab
RES="$ROOT/results/experiments.csv"
EVID="$ROOT/evidence/experiments"
mkdir -p "$ROOT/results" "$EVID"
[ -f "$RES" ] || echo "operation,duration_seconds,status,timestamp,detail" > "$RES"

log(){ local ts; ts="$(date +%Y%m%d-%H%M%S)"; echo "$1" > "$EVID/${ts}_$2.txt"; }
record(){ echo "$1,$2,$3,$(date -Is),\"$4\"" >> "$RES"; }
k(){ kubectl --context "$OC" "$@"; }
hdr(){ echo; echo "################################################################"; echo "# $1"; echo "################################################################"; }

# ---------------------------------------------------------------------------
exp1() {
  hdr "EXPERIMENTO 1 - Provisionamento (estado inicial: nenhuma NF)"
  k delete ns "$NS" --ignore-not-found --wait=true --timeout=90s
  echo "-- estado inicial (nenhuma NF) --"
  k get pods -A -l app 2>&1 | grep -E 'oran-' || echo "  (nenhuma CNF presente - confirmado)"

  t0=$(date +%s.%N)
  bash "$ROOT/lab/nephio/deploy-cnfs-via-porch.sh" > "$EVID/$(date +%Y%m%d-%H%M%S)_exp1_deploy.log" 2>&1
  for i in $(seq 1 60); do
    r=$(k -n "$NS" get pods --no-headers 2>/dev/null | grep -c ' Running ' || true)
    [ "${r:-0}" -ge 3 ] && break
    sleep 2
  done
  t1=$(date +%s.%N)
  dur=$(awk -v a="$t0" -v b="$t1" 'BEGIN{printf "%.1f", b-a}')

  echo "-- estado final --"
  k -n "$NS" get deploy,pods,svc -o wide
  ready=$(k -n "$NS" get pods --no-headers 2>/dev/null | grep -c ' Running ' || true)
  st="success"; [ "${ready:-0}" -ge 3 ] || st="fail"
  record "provision-all-cnfs" "$dur" "$st" "3 NFs (oran-cu, oran-du, oran-core) via kpt live apply"
  echo ">> duração: ${dur}s  status: $st"
}

# ---------------------------------------------------------------------------
exp2() {
  hdr "EXPERIMENTO 2 - Configuration Management (oran-du: cell_id 1 -> 2)"
  before=$(k -n "$NS" exec deploy/oran-du -- python3 -c "import urllib.request;print(urllib.request.urlopen('http://localhost:8080/config',timeout=3).read().decode())" 2>&1 | grep -v websocket)
  echo "-- config ANTES -- "; echo "$before"

  t0=$(date +%s.%N)
  after=$(k -n "$NS" exec deploy/oran-du -- python3 -c "
import urllib.request
req = urllib.request.Request('http://localhost:8080/config', data=b'{\"cell_id\": 2}', method='PUT', headers={'Content-Type':'application/json'})
print(urllib.request.urlopen(req, timeout=3).read().decode())
" 2>&1 | grep -v websocket)
  t1=$(date +%s.%N)
  dur=$(awk -v a="$t0" -v b="$t1" 'BEGIN{printf "%.3f", b-a}')

  echo "-- config DEPOIS --"; echo "$after"
  st="fail"; echo "$after" | grep -qE '"cell_id":[[:space:]]*2' && st="success"
  record "config-update-oran-du-cell_id" "$dur" "$st" "cell_id: 1 -> 2 via PUT /config"
  echo ">> duração: ${dur}s  status: $st"
  { echo "ANTES:"; echo "$before"; echo; echo "DEPOIS:"; echo "$after"; } > "$EVID/$(date +%Y%m%d-%H%M%S)_exp2_config.txt"
}

# ---------------------------------------------------------------------------
exp3() {
  hdr "EXPERIMENTO 3 - Scaling (oran-cu: 1 -> 2 réplicas)"
  before=$(k -n "$NS" get pods -l app=oran-cu --no-headers | wc -l)
  echo "-- antes: $before pod(s) --"

  t0=$(date +%s.%N)
  k -n "$NS" scale deploy/oran-cu --replicas=2
  k -n "$NS" rollout status deploy/oran-cu --timeout=90s
  t1=$(date +%s.%N)
  dur=$(awk -v a="$t0" -v b="$t1" 'BEGIN{printf "%.1f", b-a}')

  after=$(k -n "$NS" get pods -l app=oran-cu --no-headers | wc -l)
  echo "-- depois: $after pod(s) --"
  k -n "$NS" get pods -l app=oran-cu -o wide
  st="fail"; [ "$after" -eq 2 ] && st="success"
  record "scale-oran-cu-1to2" "$dur" "$st" "réplicas: $before -> $after"
  echo ">> duração: ${dur}s  status: $st"
}

# ---------------------------------------------------------------------------
exp4() {
  hdr "EXPERIMENTO 4 - Failure and Recovery (oran-du)"
  victim=$(k -n "$NS" get pods -l app=oran-du -o jsonpath='{.items[0].metadata.name}')
  echo "-- pod alvo: $victim --"

  t0=$(date +%s.%N)
  k -n "$NS" delete pod "$victim"
  for i in $(seq 1 60); do
    cur=$(k -n "$NS" get pods -l app=oran-du --no-headers 2>/dev/null | grep -c ' Running ' || true)
    still=$(k -n "$NS" get pod "$victim" --ignore-not-found -o name 2>/dev/null)
    [ "${cur:-0}" -ge 1 ] && [ -z "$still" ] && break
    sleep 1
  done
  t1=$(date +%s.%N)
  dur=$(awk -v a="$t0" -v b="$t1" 'BEGIN{printf "%.1f", b-a}')

  novo=$(k -n "$NS" get pods -l app=oran-du -o jsonpath='{.items[0].metadata.name}')
  echo "-- pod antigo: $victim | pod novo: $novo --"
  k -n "$NS" get pods -l app=oran-du -o wide
  st="fail"; [ "$novo" != "$victim" ] && [ -n "$novo" ] && st="success"
  record "recover-oran-du" "$dur" "$st" "pod antigo=$victim pod novo=$novo (reconciliacao K8s, nao healing O-RAN)"
  echo ">> duração: ${dur}s  status: $st"
}

# ---------------------------------------------------------------------------
exp5() {
  hdr "EXPERIMENTO 5 - Upgrade (oran-cu: NF_VERSION v1 -> v2, via pacote Porch)"
  rev_before=$(k -n "$NS" get deploy oran-cu -o jsonpath='{.metadata.annotations.deployment\.kubernetes\.io/revision}')
  echo "-- revisão antes: $rev_before --"

  # edita o pacote autoral e republica via Porch (mesmo mecanismo do Passo 9).
  # NOTA (achado real, ver docs/05-experiment-report.md e report/part2-report.md):
  # só mudar o ConfigMap (consumido via envFrom) NAO dispara rollout - o hash do
  # pod template não muda. Por isso também bumpamos a anotação do template.
  sed -i 's/NF_VERSION: "v1"/NF_VERSION: "v2"/' "$ROOT/lab/nephio/openran-cnfs/oran-cu-configmap.yaml"
  sed -i 's#openran-lab/nf-version: "v1"#openran-lab/nf-version: "v2"#' "$ROOT/lab/nephio/openran-cnfs/oran-cu-deployment.yaml"

  t0=$(date +%s.%N)
  bash "$ROOT/lab/nephio/deploy-cnfs-via-porch.sh" > "$EVID/$(date +%Y%m%d-%H%M%S)_exp5_upgrade.log" 2>&1
  k -n "$NS" rollout status deploy/oran-cu --timeout=90s
  t1=$(date +%s.%N)
  dur=$(awk -v a="$t0" -v b="$t1" 'BEGIN{printf "%.1f", b-a}')

  rev_after=$(k -n "$NS" get deploy oran-cu -o jsonpath='{.metadata.annotations.deployment\.kubernetes\.io/revision}')
  health=$(k -n "$NS" exec deploy/oran-cu -- python3 -c "import urllib.request;print(urllib.request.urlopen('http://localhost:8080/health',timeout=3).read().decode())" 2>&1 | grep -v websocket)
  echo "-- revisão depois: $rev_after --"
  echo "-- /health --"; echo "$health"
  k -n "$NS" rollout history deploy/oran-cu
  st="fail"; echo "$health" | grep -qE '"nf_version":[[:space:]]*"v2"' && st="success"
  record "upgrade-oran-cu-v1-v2" "$dur" "$st" "revision $rev_before -> $rev_after"
  echo ">> duração: ${dur}s  status: $st"
}

# ---------------------------------------------------------------------------
exp6() {
  hdr "EXPERIMENTO 6 - Termination (oran-core, via fluxo de gerenciamento Nephio)"
  echo "-- antes --"; k -n "$NS" get deploy,pods -l app=oran-core

  # remove oran-core do pacote autoral (fonte de verdade) e republica
  mkdir -p /tmp/openran-cnfs-noOc
  rm -f "$ROOT/lab/nephio/openran-cnfs/oran-core-"*.yaml.bak 2>/dev/null
  for f in "$ROOT/lab/nephio/openran-cnfs/oran-core-"*.yaml; do mv "$f" "$f.bak"; done

  t0=$(date +%s.%N)
  bash "$ROOT/lab/nephio/deploy-cnfs-via-porch.sh" > "$EVID/$(date +%Y%m%d-%H%M%S)_exp6_terminate.log" 2>&1
  for i in $(seq 1 30); do
    left=$(k -n "$NS" get deploy oran-core --ignore-not-found -o name 2>/dev/null)
    [ -z "$left" ] && break
    sleep 2
  done
  t1=$(date +%s.%N)
  dur=$(awk -v a="$t0" -v b="$t1" 'BEGIN{printf "%.1f", b-a}')

  echo "-- depois --"
  k -n "$NS" get deploy,pods,svc -l app=oran-core 2>&1
  left=$(k -n "$NS" get deploy oran-core --ignore-not-found -o name 2>/dev/null)
  st="fail"; [ -z "$left" ] && st="success"
  record "terminate-oran-core" "$dur" "$st" "removido do pacote Porch + kpt live apply (prune)"
  echo ">> duração: ${dur}s  status: $st (Running: $(status='RUNNING'; k get all -n $NS 2>/dev/null | grep -c oran-core || echo 0))"
  echo "NOTA: oran-core fica intencionalmente terminado - restauração manual ao final via restore-oran-core.sh"
}

case "${1:-all}" in
  1) exp1 ;; 2) exp2 ;; 3) exp3 ;; 4) exp4 ;; 5) exp5 ;; 6) exp6 ;;
  all) exp1; exp2; exp3; exp4; exp5; exp6 ;;
  *) echo "uso: $0 {1|2|3|4|5|6|all}"; exit 2 ;;
esac

echo; echo "== results/experiments.csv =="; cat "$RES"
