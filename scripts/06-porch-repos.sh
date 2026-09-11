#!/usr/bin/env bash
# ETAPA 6 - registra repositórios no Porch para habilitar o fluxo O2 IMS.
# Uso: bash scripts/06-porch-repos.sh <passo>
#   catalog   -> registra catalog-infra-capi (read-only) e valida
#   mgmt      -> cria repos deployment mgmt + mgmt-staging (Gitea) via pacote kpt
#   openran   -> cria o repo deployment 'openran-cnfs' (Fase 12 - CNFs via Porch)
#   rootsync  -> RootSync do ConfigSync apontando para o repo mgmt
#   status    -> mostra Repository / PackageRevision / RootSync
set -uo pipefail
CTX="kind-nephio-mgmt"
kubectl config use-context "$CTX" >/dev/null
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$HOME/nephio-install"
EVID="$ROOT/evidence/o2ims"; mkdir -p "$EVID"
CAT="https://github.com/nephio-project/catalog.git"; VER="v6"
step="${1:-status}"
log="$EVID/$(date +%Y%m%d-%H%M%S)_etapa6_${step}.txt"
exec > >(tee "$log") 2>&1
echo "== ETAPA 6 :: $step :: $(date -Is) :: VM $(uptime -p) =="

wait_repo_ready(){
  local n="$1"
  for i in $(seq 1 40); do
    local c
    c="$(kubectl get repository "$n" -n default -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)"
    echo "  $(date +%T) repository/$n Ready=$c"
    [ "$c" = "True" ] && return 0
    sleep 6
  done
  return 1
}

register_deployment_repo(){
  local name="$1"
  local d="$WORK/repo-$name"
  if [ ! -d "$d" ]; then
    ( cd "$WORK" && kpt pkg get "$CAT/distros/sandbox/repository@$VER" "repo-$name" )
  fi
  local pc="$d/package-context.yaml"
  sed -i "s/name: example-repo/name: $name/;  s/clusterName: example-cluster-name/clusterName: $name/" "$pc"
  echo "-- package-context de repo-$name --"; cat "$pc"
  ( cd "$d" && kpt fn render 2>&1 | tail -n 5 && (kpt live init 2>/dev/null || true) \
    && kpt live apply --reconcile-timeout=3m --output=events 2>&1 | grep -vE 'reconcile pending|in progress' | tail -n 25 )
}

case "$step" in
  catalog)
    kubectl apply -f "$ROOT/manifests/porch-repo-catalog-infra-capi.yaml"
    wait_repo_ready catalog-infra-capi || echo "[!] catalog-infra-capi não ficou Ready"
    echo; echo "-- repositories --"; kubectl get repository -A
    echo; echo "-- PackageRevisions de nephio-workload-cluster / cluster-capi-kind --"
    kubectl get packagerevisions -n default 2>/dev/null | grep -E 'nephio-workload-cluster|cluster-capi-kind' || echo "  (nenhuma ainda — pode levar ~1 min)"
    ;;
  mgmt)
    for name in mgmt mgmt-staging; do register_deployment_repo "$name"; done
    echo; echo "-- infra.nephio.org Repository + Token --"
    kubectl get repositories.infra.nephio.org,tokens.infra.nephio.org -A
    echo; echo "-- aguardando repos Porch mgmt / mgmt-staging --"
    wait_repo_ready mgmt || echo "[!] mgmt não ficou Ready"
    wait_repo_ready mgmt-staging || echo "[!] mgmt-staging não ficou Ready"
    kubectl get repository -A
    ;;
  openran)
    register_deployment_repo "openran-cnfs"
    echo; echo "-- aguardando repo Porch openran-cnfs --"
    wait_repo_ready openran-cnfs || echo "[!] openran-cnfs não ficou Ready"
    kubectl get repository -A
    ;;
  rootsync)
    kubectl apply -f "$ROOT/manifests/rootsync-mgmt.yaml"
    sleep 10
    kubectl get rootsync -A
    kubectl -n config-management-system get pods
    ;;
  status)
    echo "-- config.porch.kpt.dev/Repository --"; kubectl get repository -A -o wide
    echo; echo "-- infra.nephio.org/Repository + Token --"; kubectl get repositories.infra.nephio.org,tokens.infra.nephio.org -A
    echo; echo "-- RootSync --"; kubectl get rootsync -A 2>/dev/null || true
    echo; echo "-- PackageRevisions (nephio-workload-cluster / cluster-capi-kind) --"
    kubectl get packagerevisions -n default 2>/dev/null | grep -E 'NAME|nephio-workload-cluster|cluster-capi-kind' || echo "  nenhuma"
    ;;
  *) echo "passo inválido"; exit 2 ;;
esac
echo; echo "[ok] log: $log"
