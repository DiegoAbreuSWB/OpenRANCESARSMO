#!/usr/bin/env bash
# Melhoria (dentro do orcamento de 16 GB): fecha a lacuna "cell_id nao propaga de volta
# ao pacote" (report/part2-report.md Sec.14 item 5). Builda e implanta o config-bridge
# (lab/nephio/config-bridge) no o-cloud-1, reaproveitando o token do Gitea que o Porch
# ja usa para o repo openran-cnfs (nao cria credencial nova, nao comita segredo no git).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "== 1) le o token do Gitea ja usado pelo Porch para o repo openran-cnfs =="
USER=$(kubectl --context kind-nephio-mgmt -n default get secret openran-cnfs-access-token-porch -o jsonpath='{.data.username}' | base64 -d)
TOKEN=$(kubectl --context kind-nephio-mgmt -n default get secret openran-cnfs-access-token-porch -o jsonpath='{.data.token}' | base64 -d)
echo "   usuario: $USER"

echo "== 2) builda e carrega a imagem config-bridge:v1 no o-cloud-1 =="
docker build -q -t config-bridge:v1 "$ROOT/lab/nephio/config-bridge"
kind load docker-image config-bridge:v1 --name o-cloud-1

echo "== 3) cria/atualiza o Secret com o token reaproveitado (nao commitado) =="
kubectl --context o-cloud-1 -n openran-lab create secret generic config-bridge-gitea \
  --from-literal=username="$USER" \
  --from-literal=token="$TOKEN" \
  --dry-run=client -o yaml | kubectl --context o-cloud-1 apply -f -

echo "== 4) aplica o Deployment =="
kubectl --context o-cloud-1 apply -f "$ROOT/lab/nephio/config-bridge/deployment.yaml"
kubectl --context o-cloud-1 -n openran-lab rollout status deploy/config-bridge --timeout=60s

echo "== 5) logs iniciais =="
sleep 5
kubectl --context o-cloud-1 -n openran-lab logs deploy/config-bridge --tail=20
