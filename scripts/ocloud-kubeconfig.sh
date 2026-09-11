#!/usr/bin/env bash
# Extrai o kubeconfig do workload cluster o-cloud-1 (Secret gerado pelo Cluster API)
# e o MESCLA no ~/.kube/config como contexto "o-cloud-1".
# O o-cloud-1 NÃO foi criado por 'kind create cluster' — foi criado pelo Cluster API +
# provider Docker (CAPD), disparado pelo ProvisioningRequest do O2 IMS. Por isso o
# contexto não é "kind-o-cloud-1"; nós o registramos manualmente como "o-cloud-1".
set -euo pipefail
MGMT_CTX="kind-nephio-mgmt"
NAME="${1:-o-cloud-1}"
OUT="/tmp/${NAME}.kubeconfig"

kubectl --context "$MGMT_CTX" -n default get secret "${NAME}-kubeconfig" -o jsonpath='{.data.value}' | base64 -d > "$OUT"
echo "[ok] kubeconfig isolado: $OUT"

# PURGA entradas antigas com esse nome (senão o merge mantém o CA/servidor obsoletos
# de um o-cloud-1 recriado) e então mescla o novo.
for c in $(kubectl config get-contexts -o name 2>/dev/null | grep -E "^${NAME}(-admin@${NAME})?$"); do
  kubectl config delete-context "$c" >/dev/null 2>&1 || true
done
kubectl config delete-cluster "$NAME" >/dev/null 2>&1 || true
kubectl config delete-user "${NAME}-admin" >/dev/null 2>&1 || true
KUBECONFIG="$HOME/.kube/config:$OUT" kubectl config view --flatten > "$HOME/.kube/config.new"
mv "$HOME/.kube/config.new" "$HOME/.kube/config"
# o contexto vindo do secret costuma se chamar '<NAME>-admin@<NAME>'; renomeia p/ '<NAME>'
src_ctx="$(KUBECONFIG=$OUT kubectl config current-context)"
kubectl config delete-context "$NAME" >/dev/null 2>&1 || true
kubectl config rename-context "$src_ctx" "$NAME" >/dev/null 2>&1 || true
kubectl config use-context "$MGMT_CTX" >/dev/null

echo "[ok] contexto '$NAME' disponível. Contextos:"
kubectl config get-contexts
echo
echo "[teste] kubectl --context $NAME get nodes"
kubectl --context "$NAME" get nodes -o wide
