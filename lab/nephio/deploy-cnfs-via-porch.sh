#!/usr/bin/env bash
# deploy-cnfs-via-porch.sh (Fase 12) - fluxo Nephio "de verdade" para levar as 3 CNFs
# simuladas ao workload cluster o-cloud-1, usando kpt + Porch + repositório de pacotes
# (NÃO um `kubectl apply` direto — esse foi o baseline do Passo 7 / lab/kubernetes/).
#
# Cadeia demonstrada:
#   Package (lab/nephio/openran-cnfs, kpt) --porchctl--> Repository (Porch/Gitea "openran-cnfs")
#     --porchctl rpkg pull--> cópia de trabalho vinda do repositório PUBLICADO
#     --kpt live apply--> reconciliação declarativa (ResourceGroup) no o-cloud-1
#
# Pré-requisito: o repositório Porch 'openran-cnfs' já registrado (ver docs/provisioning-flow.md
# passo 1 - reaproveita o padrão de scripts/06-porch-repos.sh mgmt/mgmt-staging).
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PKGDIR="$ROOT/lab/nephio/openran-cnfs"
REPO=openran-cnfs
PKG=openran-nfs
WS=v1
NAME="$REPO.$PKG.$WS"
MGMT=kind-nephio-mgmt
OC=o-cloud-1

echo "== 1) publica/atualiza o pacote no Porch ($NAME) =="
kubectl config use-context "$MGMT" >/dev/null
if kubectl -n default get packagerevisions.porch.kpt.dev "$NAME" >/dev/null 2>&1; then
  echo "   revisão '$NAME' já existe — puxando, mesclando o conteúdo atual e republicando"
  rm -rf /tmp/openran-nfs-work && porchctl rpkg pull "$NAME" /tmp/openran-nfs-work -n default
  cp "$PKGDIR"/*.yaml /tmp/openran-nfs-work/
  porchctl rpkg push "$NAME" /tmp/openran-nfs-work -n default
else
  porchctl rpkg init "$PKG" --repository="$REPO" --workspace="$WS" -n default
  rm -rf /tmp/openran-nfs-work && porchctl rpkg pull "$NAME" /tmp/openran-nfs-work -n default
  cp "$PKGDIR"/*.yaml /tmp/openran-nfs-work/
  porchctl rpkg push "$NAME" /tmp/openran-nfs-work -n default
  porchctl rpkg propose "$NAME" -n default
  porchctl rpkg approve "$NAME" -n default
fi
kubectl -n default get packagerevisions.porch.kpt.dev "$NAME"

echo
echo "== 2) puxa o conteúdo PUBLICADO (fonte de verdade = Porch/Gitea, não o disco local) =="
rm -rf /tmp/openran-cnfs-delivery
porchctl rpkg pull "$NAME" /tmp/openran-cnfs-delivery -n default

echo
echo "== 3) reconcilia no o-cloud-1 via kpt live apply (ResourceGroup = inventário declarativo) =="
kubectl config use-context "$OC" >/dev/null
cd /tmp/openran-cnfs-delivery
[ -f resourcegroup.yaml ] || kpt live init . --namespace=default
kpt live apply . --reconcile-timeout=2m --output=events --context="$OC" | grep -vE 'reconcile pending|in progress'

echo
echo "== 4) validação =="
kubectl --context "$OC" -n openran-lab get deploy,pods,svc -o wide
for nf in oran-cu oran-du oran-core; do
  kubectl --context "$OC" -n openran-lab exec "deploy/$nf" -- python3 -c "
import urllib.request
r = urllib.request.urlopen('http://localhost:8080/health', timeout=3)
print('$nf', '->', r.status, r.read().decode())
" 2>&1 | grep -v websocket
done
