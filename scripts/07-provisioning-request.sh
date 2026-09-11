#!/usr/bin/env bash
# ETAPA 7 - aplica o ProvisioningRequest e ACOMPANHA a cadeia O2 IMS.
# Uso: bash scripts/07-provisioning-request.sh <passo>
#   apply   -> kubectl apply do manifesto
#   watch   -> 1 varredura do estado (PR, PackageVariant, PackageRevision, Cluster, containers)
#   logs    -> logs recentes do o2ims-operator
#   delete  -> remove o ProvisioningRequest (para o ciclo terminate, mais tarde)
set -uo pipefail
CTX="kind-nephio-mgmt"
kubectl config use-context "$CTX" >/dev/null
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EVID="$ROOT/evidence/o2ims"; mkdir -p "$EVID"
PR="o-cloud-1"
step="${1:-watch}"
log="$EVID/$(date +%Y%m%d-%H%M%S)_etapa7_${step}.txt"
exec > >(tee "$log") 2>&1
echo "== ETAPA 7 :: $step :: $(date -Is) :: VM $(uptime -p) =="

case "$step" in
  apply)
    kubectl apply -f "$ROOT/manifests/o2-provisioning-request.yaml"
    echo; echo "aplicado. use 'watch' para acompanhar."
    ;;
  watch)
    echo "#### 1. ProvisioningRequest ####"
    kubectl get provisioningrequests.o2ims.provisioning.oran.org "$PR" -o wide 2>&1 || true
    echo "-- status --"
    kubectl get provisioningrequests.o2ims.provisioning.oran.org "$PR" \
      -o jsonpath='{.status}' 2>/dev/null | (command -v jq >/dev/null && jq . || cat); echo

    echo; echo "#### 2. PackageVariant (criado pelo o2ims-operator) ####"
    kubectl get packagevariant -A 2>&1
    kubectl get packagevariant "$PR" -n default -o jsonpath='{.status.conditions}' 2>/dev/null | (command -v jq >/dev/null && jq . || cat); echo

    echo; echo "#### 3. PackageRevisions no repo mgmt ####"
    kubectl get packagerevisions -n default 2>/dev/null | grep -E "NAME|mgmt\.|$PR" || echo "  nenhuma"

    echo; echo "#### 4. CAPI Cluster / DockerCluster / MachineDeployment ####"
    kubectl get clusters.cluster.x-k8s.io -A 2>&1
    kubectl get dockerclusters,machinedeployments,machines -A 2>&1

    echo; echo "#### 5. Containers Docker do workload cluster ####"
    docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}' | grep -E "NAMES|$PR|o-cloud" || echo "  (nenhum container o-cloud-1 ainda)"

    echo; echo "#### 6. kind clusters ####"
    kind get clusters 2>&1

    echo; echo "#### 7. eventos recentes (type!=Normal) ####"
    kubectl get events -A --field-selector type!=Normal --sort-by=.lastTimestamp 2>/dev/null | tail -n 12
    ;;
  logs)
    kubectl -n o2ims logs deploy/o2ims-operator --tail=80 2>&1
    ;;
  delete)
    kubectl delete -f "$ROOT/manifests/o2-provisioning-request.yaml" --ignore-not-found
    ;;
  *) echo "passo inválido"; exit 2 ;;
esac
echo; echo "[ok] log: $log"
