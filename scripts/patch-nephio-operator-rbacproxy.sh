#!/usr/bin/env bash
# Correção de bug upstream do Nephio R6:
#   o pacote nephio/core/nephio-operator@v6 referencia
#   gcr.io/kubebuilder/kube-rbac-proxy:v0.8.0, que o Google REMOVEU (HTTP 404).
#   A mesma imagem/versão continua publicada em quay.io/brancz/kube-rbac-proxy:v0.8.0.
# Este script troca o registry no pacote kpt já baixado e re-aplica.
set -euo pipefail
CTX="kind-nephio-mgmt"
PKG="$HOME/nephio-install/nephio-operator"
OLD="gcr.io/kubebuilder/kube-rbac-proxy:v0.8.0"
NEW="quay.io/brancz/kube-rbac-proxy:v0.8.0"

cd "$PKG"
grep -rIl "$OLD" . | while read -r f; do
  sed -i "s#${OLD}#${NEW}#g" "$f"
  echo "[patch] $f"
done
echo "--- confirmação ---"
grep -rIn 'kube-rbac-proxy' app/controller/*.yaml

kubectl config use-context "$CTX" >/dev/null
echo "--- kpt live apply (re-aplica com a imagem corrigida) ---"
kpt live apply --reconcile-timeout=5m --output=events 2>&1 | grep -vE 'reconcile pending|in progress'

echo "--- estado final ---"
kubectl --context "$CTX" -n nephio-system get pods -o wide
