#!/usr/bin/env bash
# deploy.sh - provisiona TUDO: management cluster + Nephio + repo Porch + as 3 CNFs
# no o-cloud-1, via o fluxo real (kpt + Porch), do zero ou de forma idempotente.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "###### 1) management cluster + Nephio R6 (idempotente) ######"
bash "$ROOT/scripts/install-nephio.sh"

echo
echo "###### 2) workload cluster / O-Cloud (o-cloud-1) via O2 IMS ######"
if ! kubectl --context o-cloud-1 get nodes >/dev/null 2>&1; then
  echo "   o-cloud-1 ausente — provisionando via ProvisioningRequest (O2 IMS)"
  bash "$ROOT/scripts/07-provisioning-request.sh" apply
  bash "$ROOT/scripts/07-provisioning-request.sh" watch
  bash "$ROOT/scripts/ocloud-kubeconfig.sh" o-cloud-1
  bash "$ROOT/scripts/fix-ocloud-cni-plugins.sh"
else
  echo "   o-cloud-1 já responde — pulando provisionamento"
fi

echo
echo "###### 3) repositório Porch dedicado às CNFs (idempotente) ######"
bash "$ROOT/scripts/06-porch-repos.sh" openran

echo
echo "###### 4) as 3 CNFs via kpt + Porch (Fase 12) ######"
bash "$ROOT/lab/nephio/deploy-cnfs-via-porch.sh"

echo
echo "###### deploy.sh concluído ######"
bash "$ROOT/scripts/status.sh"
