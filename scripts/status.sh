#!/usr/bin/env bash
# status.sh - visão geral do laboratório (clusters, Nephio, O2 IMS, CNFs, recursos).
set -uo pipefail
sep(){ echo; echo "==== $1 ===="; }

sep "clusters kind"
kind get clusters 2>&1

sep "management cluster (nephio-mgmt)"
if kubectl --context kind-nephio-mgmt get nodes >/dev/null 2>&1; then
  kubectl --context kind-nephio-mgmt get nodes
  n=$(kubectl --context kind-nephio-mgmt get pods -A --no-headers 2>/dev/null | wc -l)
  r=$(kubectl --context kind-nephio-mgmt get pods -A --no-headers 2>/dev/null | awk '{split($2,a,"/"); if(a[1]==a[2]&&a[2]!=0)c++} END{print c+0}')
  echo "pods: $r/$n Ready"
else
  echo "não responde (rode: bash scripts/lab-recover.sh)"
fi

sep "O2 IMS / ProvisioningRequest"
kubectl --context kind-nephio-mgmt get provisioningrequest.o2ims.provisioning.oran.org o-cloud-1 \
  -o jsonpath='{.status.provisioningStatus.provisioningState}{"\n"}' 2>/dev/null || echo "(sem ProvisioningRequest)"

sep "workload cluster / O-Cloud (o-cloud-1)"
if kubectl --context o-cloud-1 get nodes >/dev/null 2>&1; then
  kubectl --context o-cloud-1 get nodes
else
  echo "não responde (rode: bash scripts/reprovision-ocloud.sh)"
fi

sep "CNFs (openran-lab)"
kubectl --context o-cloud-1 -n openran-lab get deploy,pods,svc -o wide 2>&1 || echo "(namespace openran-lab ausente)"

sep "Repositórios Porch"
kubectl --context kind-nephio-mgmt get repository -A 2>/dev/null

sep "últimos resultados de experimentos"
tail -n 8 "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/results/experiments.csv" 2>/dev/null || echo "(sem results/experiments.csv ainda)"

sep "recursos"
free -h 2>/dev/null || echo "(rode dentro do WSL para ver RAM)"
