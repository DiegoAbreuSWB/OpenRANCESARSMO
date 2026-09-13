#!/usr/bin/env bash
# Reconstroi e recarrega as 3 imagens Docker das CNFs simuladas nos nos do kind
# "o-cloud-1". Necessario sempre que o o-cloud-1 e recriado do zero
# (scripts/reprovision-ocloud.sh) - os nos novos nao tem as imagens locais em cache,
# e como oran-cu/oran-du/oran-core nao vem de um registry, o kubelet nao consegue
# fazer pull sozinho (ImagePullBackOff) ate isto rodar.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
for nf in oran-cu oran-du oran-core; do
  echo "== $nf =="
  docker build -q -t "${nf}:v1" "$ROOT/lab/cnfs/${nf}"
  kind load docker-image "${nf}:v1" --name o-cloud-1
done
echo "done"
