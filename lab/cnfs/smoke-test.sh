#!/usr/bin/env bash
set -uo pipefail
# raiz do repo = dois níveis acima deste script (lab/cnfs/smoke-test.sh)
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ok=0; fail=0
for nf in oran-cu oran-du oran-core; do
  echo "===== $nf ====="
  d="$ROOT/lab/cnfs/$nf"
  if ! docker build -q -t "$nf:smoketest" "$d" >/tmp/build_$nf.log 2>&1; then
    echo "  [FAIL] build"; tail -n 20 /tmp/build_$nf.log; fail=$((fail+1)); continue
  fi
  echo "  [ok] build"
  cid=$(docker run -d --rm -p 0:8080 "$nf:smoketest")
  port=$(docker port "$cid" 8080/tcp | head -1 | cut -d: -f2)
  sleep 1.5
  h=$(curl -fsS "http://localhost:$port/health" 2>&1) || { echo "  [FAIL] /health: $h"; docker logs "$cid"; docker stop "$cid" >/dev/null; fail=$((fail+1)); continue; }
  echo "  /health -> $h"
  c1=$(curl -fsS "http://localhost:$port/config")
  echo "  /config (antes) -> $c1"
  if [ "$nf" = "oran-du" ]; then upd='{"cell_id": 2}'; else upd='{"probe": true}'; fi
  c2=$(curl -fsS -X PUT "http://localhost:$port/config" -H 'content-type: application/json' -d "$upd")
  echo "  /config (PUT $upd) -> $c2"
  m=$(curl -fsS "http://localhost:$port/metrics")
  echo "  /metrics ->"; echo "$m" | sed 's/^/    /'
  echo "$m" | grep -q '^nf_up{' && echo "$m" | grep -q '^nf_config_version{' && echo "  [ok] métricas presentes" || { echo "  [FAIL] métricas ausentes"; fail=$((fail+1)); docker stop "$cid" >/dev/null; continue; }
  docker stop "$cid" >/dev/null
  ok=$((ok+1))
  echo "  [PASS] $nf"
done
echo
echo "RESUMO: ok=$ok fail=$fail"
docker rmi oran-cu:smoketest oran-du:smoketest oran-core:smoketest >/dev/null 2>&1 || true
[ "$fail" -eq 0 ]
