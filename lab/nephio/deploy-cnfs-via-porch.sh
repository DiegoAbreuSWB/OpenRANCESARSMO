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
# Cada mudança de conteúdo vira uma NOVA revisão do pacote (Porch não permite `push`
# sobre uma revisão já Published — só Draft). Isso é o comportamento real do Porch:
# atualizações de pacote = novas PackageRevisions, com histórico completo.
#
# Pré-requisito: o repositório Porch 'openran-cnfs' já registrado
#   (bash scripts/06-porch-repos.sh openran)
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PKGDIR="$ROOT/lab/nephio/openran-cnfs"
REPO=openran-cnfs
PKG=openran-nfs
MGMT=kind-nephio-mgmt
OC=o-cloud-1

kubectl config use-context "$MGMT" >/dev/null

echo "== 1) publica/atualiza o pacote no Porch (repo=$REPO pkg=$PKG) =="
latest=$(kubectl -n default get packagerevisions.porch.kpt.dev -o json 2>/dev/null \
  | jq -r --arg repo "$REPO" --arg pkg "$PKG" \
    '.items[] | select(.spec.repository==$repo and .spec.packageName==$pkg and .metadata.labels["kpt.dev/latest-revision"]=="true") | .metadata.name' \
  | head -1)

if [ -z "$latest" ]; then
  echo "   nenhuma revisão existente — criando a primeira (workspace=v1)"
  WS="v1"
  NAME="$REPO.$PKG.$WS"
  porchctl rpkg init "$PKG" --repository="$REPO" --workspace="$WS" -n default
else
  echo "   revisão mais recente: $latest — criando uma NOVA revisão a partir dela (rpkg copy)"
  WS="v$(date +%s)"
  NAME="$REPO.$PKG.$WS"
  porchctl rpkg copy "$latest" --workspace="$WS" -n default
fi

rm -rf /tmp/openran-nfs-work && porchctl rpkg pull "$NAME" /tmp/openran-nfs-work -n default
# conteúdo do pacote = exatamente o que está em $PKGDIR agora (arquivos removidos
# de $PKGDIR não são copiados => kpt live apply os PODA na reconciliação, adiante)
find /tmp/openran-nfs-work -maxdepth 1 -name '*.yaml' ! -name 'package-context.yaml' -delete
cp "$PKGDIR"/*.yaml /tmp/openran-nfs-work/
porchctl rpkg push "$NAME" /tmp/openran-nfs-work -n default
porchctl rpkg propose "$NAME" -n default
porchctl rpkg approve "$NAME" -n default
kubectl -n default get packagerevisions.porch.kpt.dev "$NAME"

echo
echo "== 2) puxa o conteúdo PUBLICADO (fonte de verdade = Porch/Gitea, não o disco local) =="
# IMPORTANTE: o diretório de entrega é PERSISTENTE entre chamadas (não é apagado),
# porque ele guarda o resourcegroup.yaml (inventário) que o kpt usa para saber quais
# recursos já pertencem a este pacote. Apagar e recriar a cada chamada geraria um
# inventory-id novo a cada vez, e o kpt recusaria tocar nos recursos já existentes
# (policy MustMatch -> NoMatch) - foi exatamente o bug encontrado e corrigido aqui.
DELIVERY=/tmp/openran-cnfs-delivery
had_inventory=0
[ -f "$DELIVERY/resourcegroup.yaml" ] && had_inventory=1
rm -rf /tmp/openran-cnfs-pull-tmp
porchctl rpkg pull "$NAME" /tmp/openran-cnfs-pull-tmp -n default
mkdir -p "$DELIVERY"
if [ "$had_inventory" -eq 1 ]; then
  cp "$DELIVERY/resourcegroup.yaml" /tmp/openran-cnfs-pull-tmp/resourcegroup.yaml
fi
rm -rf "$DELIVERY" && mv /tmp/openran-cnfs-pull-tmp "$DELIVERY"

echo
echo "== 3) reconcilia no o-cloud-1 via kpt live apply (ResourceGroup = inventário declarativo) =="
kubectl config use-context "$OC" >/dev/null
cd "$DELIVERY"
[ -f resourcegroup.yaml ] || kpt live init . --namespace=default
kpt live apply . --reconcile-timeout=2m --output=events --context="$OC" --prune-propagation-policy=Foreground \
  | grep -vE 'reconcile pending|in progress'

echo
echo "== 4) validação =="
kubectl --context "$OC" -n openran-lab get deploy,pods,svc -o wide
for nf in oran-cu oran-du oran-core; do
  if kubectl --context "$OC" -n openran-lab get deploy "$nf" >/dev/null 2>&1; then
    kubectl --context "$OC" -n openran-lab exec "deploy/$nf" -- python3 -c "
import urllib.request
r = urllib.request.urlopen('http://localhost:8080/health', timeout=3)
print('$nf', '->', r.status, r.read().decode())
" 2>&1 | grep -v websocket
  else
    echo "$nf -> (não presente no pacote atual)"
  fi
done
