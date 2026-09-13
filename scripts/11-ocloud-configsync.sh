#!/usr/bin/env bash
# Melhoria (dentro do orçamento de 16 GB): instala Config Sync no PRÓPRIO o-cloud-1 e
# cria um RootSync contínuo apontando para o repositório Porch/Gitea "openran-cnfs".
#
# Lacuna que isso fecha (docs/05-experiment-report.md §11 item 2 / report/part2-report.md
# §14 item 2): até aqui a entrega das 3 CNFs simuladas dependia de rodar manualmente
# `lab/nephio/deploy-cnfs-via-porch.sh` (kpt live apply sob demanda). Com este script, o
# o-cloud-1 passa a reconciliar sozinho, de forma contínua, o que estiver publicado no
# repo "openran-cnfs" — o mesmo padrão GitOps que o management cluster já usa para o
# repo "mgmt". Usa o MESMO pacote kpt oficial do catálogo Nephio (nephio/core/configsync@v6)
# já usado em scripts/03-nephio-min.sh, só que aplicado no contexto o-cloud-1 em vez de
# kind-nephio-mgmt.
set -uo pipefail

CTX="o-cloud-1"
CAT="https://github.com/nephio-project/catalog.git"
VER="v6"
WORK="$HOME/nephio-install-ocloud"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EVID="$REPO_ROOT/evidence/improvements"
mkdir -p "$WORK" "$EVID"

kubectl config use-context "$CTX" >/dev/null

ts="$(date +%Y%m%d-%H%M%S)"
log="$EVID/${ts}_ocloud-configsync.txt"
exec > >(tee "$log") 2>&1
echo "== instala Config Sync em $CTX :: $(date -Is) =="

echo "== 1) busca o pacote kpt oficial (mesmo do mgmt) =="
if [ -d "$WORK/configsync" ]; then
  echo "[skip get] $WORK/configsync já existe"
else
  ( cd "$WORK" && kpt pkg get "$CAT/nephio/core/configsync@$VER" configsync )
fi

echo "== 2) kpt live apply no o-cloud-1 =="
cd "$WORK/configsync"
if [ ! -f resourcegroup.yaml ] && ! grep -q ResourceGroup Kptfile 2>/dev/null; then
  kpt live init 2>&1 | sed 's/^/    /'
fi
kpt live apply --reconcile-timeout=5m --output=events 2>&1 \
  | grep -vE 'reconcile pending|in progress|watch (started|update)'

echo "== 3) aguarda reconciler-manager =="
kubectl --context "$CTX" -n config-management-system rollout status deploy/reconciler-manager --timeout=120s

echo "== 4) cria o RootSync 'openran-cnfs' apontando para o repo real do Porch/Gitea =="
kubectl --context "$CTX" apply -f - <<'EOF'
apiVersion: configsync.gke.io/v1beta1
kind: RootSync
metadata:
  name: openran-cnfs
  namespace: config-management-system
spec:
  sourceType: git
  sourceFormat: unstructured
  git:
    repo: http://172.18.0.200:3000/nephio/openran-cnfs.git
    branch: main
    dir: "."
    auth: none
EOF

echo "== 5) aguarda primeira sincronização (~60-90s) =="
for i in $(seq 1 20); do
  se=$(kubectl --context "$CTX" -n config-management-system get rootsync openran-cnfs -o jsonpath='{.status.sync.errorSummary.totalCount}' 2>/dev/null)
  commit=$(kubectl --context "$CTX" -n config-management-system get rootsync openran-cnfs -o jsonpath='{.status.sync.commit}' 2>/dev/null)
  echo "  $(date +%T) syncErrors=${se:-?} commit=${commit:-<none>}"
  [ -n "${commit:-}" ] && [ "${se:-0}" = "0" ] && break
  sleep 6
done

echo
echo "== 6) validação: os recursos existem SEM eu ter rodado deploy-cnfs-via-porch.sh agora =="
kubectl --context "$CTX" -n openran-lab get deploy,pods
echo
echo "[fim] log: $log"
