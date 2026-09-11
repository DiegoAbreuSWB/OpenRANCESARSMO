#!/usr/bin/env bash
# ETAPA 3 - instalação MÍNIMA do Nephio R6, um pacote kpt por vez.
# Uso (dentro do WSL, a partir de qualquer lugar):
#   bash scripts/03-nephio-min.sh <passo>
# Passos: cert-manager | porch | gitea | nephio-operator | configsync
#         | capi | focom | o2ims | status
#
# Não instala nada "por via das dúvidas". Cada passo faz get + init + apply + dump.
set -uo pipefail

CTX="kind-nephio-mgmt"
CAT="https://github.com/nephio-project/catalog.git"
VER="v6"                       # branch do catálogo p/ Nephio R6
WORK="$HOME/nephio-install"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EVID="$REPO_ROOT/evidence/nephio-install"
mkdir -p "$WORK" "$EVID"

kubectl config use-context "$CTX" >/dev/null

step="${1:-status}"
ts="$(date +%Y%m%d-%H%M%S)"
log="$EVID/${ts}_etapa3_${step}.txt"
exec > >(tee "$log") 2>&1
echo "== ETAPA 3 :: passo=$step :: $(date -Is) =="
echo "kpt $(kpt version 2>/dev/null | head -n1)  |  VM uptime: $(uptime -p)"

# get_pkg <catalog-subpath> <localdir>
get_pkg() {
  local sub="$1" dir="$2"
  if [ -d "$WORK/$dir" ]; then
    echo "[skip get] $WORK/$dir já existe"
  else
    echo "[kpt pkg get] $CAT/$sub@$VER -> $dir"
    ( cd "$WORK" && kpt pkg get "$CAT/$sub@$VER" "$dir" )
  fi
  # registra o commit de origem p/ rastreabilidade
  grep -E 'upstream|commit|ref:' "$WORK/$dir/Kptfile" 2>/dev/null | sed 's/^/    /' || true
}

apply_pkg() {
  local dir="$1" timeout="${2:-5m}"
  cd "$WORK/$dir"
  if ! grep -q 'ResourceGroup' Kptfile 2>/dev/null && [ ! -f resourcegroup.yaml ]; then
    kpt live init 2>&1 | sed 's/^/    /' || true
  fi
  echo "[kpt live apply] $dir (reconcile-timeout=$timeout)"
  # --output=events é linha-a-linha; filtra ruído de polling p/ manter o log legível
  kpt live apply --reconcile-timeout="$timeout" --output=events 2>&1 \
    | grep -vE 'reconcile pending|in progress|watch (started|update)' || return 1
}

dump_ns() {
  for ns in "$@"; do
    echo "--- ns/$ns ---"
    kubectl -n "$ns" get pods -o wide 2>/dev/null || echo "  (sem ns $ns)"
  done
}

case "$step" in
  metallb)
    # necessário: o pacote gitea/nephio-operator do sandbox espera um IP de
    # LoadBalancer fixo (172.18.0.200) atribuído pelo MetalLB na rede docker do kind.
    get_pkg "distros/sandbox/metallb" "metallb"
    apply_pkg "metallb" "5m"
    get_pkg "distros/sandbox/metallb-sandbox-config" "metallb-sandbox-config"
    apply_pkg "metallb-sandbox-config" "3m"
    dump_ns metallb-system
    kubectl get ipaddresspools.metallb.io -A 2>/dev/null || true
    ;;
  resource-backend)
    # necessário: o nephio-controller (NetworkController, ENABLE_NETWORKS=true) faz
    # cache-sync de Endpoint/VLANIndex/NetworkInstance e CRASHA o manager inteiro
    # se esses CRDs (grupo *.resource.nephio.org / inv.nephio.org) não existirem.
    get_pkg "nephio/optional/resource-backend" "resource-backend"
    apply_pkg "resource-backend" "5m"
    dump_ns backend-system
    kubectl get crd | grep -Ei 'resource.nephio.org|inv.nephio.org' || true
    ;;
  cert-manager)
    get_pkg "distros/sandbox/cert-manager" "cert-manager"
    apply_pkg "cert-manager" "5m"
    dump_ns cert-manager
    echo "--- CRDs cert-manager ---"; kubectl get crd | grep cert-manager || true
    ;;
  porch)
    get_pkg "nephio/core/porch" "porch"
    apply_pkg "porch" "8m"
    dump_ns porch-system porch-fn-system
    echo "--- CRDs/APIs porch ---"
    kubectl get crd | grep -Ei 'porch|config.porch' || true
    kubectl api-resources | grep -Ei 'porch' || true
    ;;
  gitea)
    get_pkg "distros/sandbox/gitea" "gitea"
    apply_pkg "gitea" "8m"
    dump_ns gitea
    kubectl -n gitea get svc
    ;;
  nephio-operator)
    get_pkg "nephio/core/nephio-operator" "nephio-operator"
    apply_pkg "nephio-operator" "8m"
    dump_ns nephio-system
    kubectl get crd | grep -Ei 'nephio' || true
    ;;
  configsync)
    get_pkg "nephio/core/configsync" "configsync"
    apply_pkg "configsync" "5m"
    dump_ns config-management-system config-management-monitoring resource-group-system
    ;;
  capi)
    get_pkg "infra/capi/cluster-capi" "cluster-capi"
    apply_pkg "cluster-capi" "8m"
    get_pkg "infra/capi/cluster-capi-infrastructure-docker" "cluster-capi-infrastructure-docker"
    apply_pkg "cluster-capi-infrastructure-docker" "8m"
    get_pkg "infra/capi/cluster-capi-kind-docker-templates" "cluster-capi-kind-docker-templates"
    apply_pkg "cluster-capi-kind-docker-templates" "5m"
    dump_ns capi-system capi-kubeadm-bootstrap-system capi-kubeadm-control-plane-system capd-system
    kubectl get crd | grep -Ei 'cluster.x-k8s.io|infrastructure.cluster.x-k8s.io' || true
    ;;
  focom)
    get_pkg "nephio/optional/focom-operator" "focom-operator"
    apply_pkg "focom-operator" "5m"
    kubectl get ns | grep -Ei 'focom' || true
    kubectl get crd | grep -Ei 'focom|oran' || true
    ;;
  o2ims)
    get_pkg "nephio/optional/o2ims" "o2ims"
    apply_pkg "o2ims" "5m"
    dump_ns o2ims
    echo "--- CRD ProvisioningRequest ---"
    kubectl get crd provisioningrequests.o2ims.provisioning.oran.org -o wide || true
    kubectl api-resources | grep -Ei 'o2ims|provisioningrequest' || true
    ;;
  status)
    echo "--- todos os pods ---"
    kubectl get pods -A
    echo "--- pods problemáticos ---"
    kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded || true
    echo "--- CRDs ---"
    kubectl get crd --no-headers | wc -l
    echo "--- pacotes kpt baixados ---"
    ls -1 "$WORK" 2>/dev/null || true
    ;;
  *)
    echo "passo inválido: $step"; exit 2 ;;
esac

echo; echo "[ok] log: $log"
