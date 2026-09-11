#!/usr/bin/env bash
# render-diagrams.sh (Fase 20) - renderiza os diagramas Mermaid usados na apresentação (Parte 1)
# e no relatório (Parte 2) para PNG, via o serviço público https://mermaid.ink (sem precisar
# instalar Mermaid-CLI/Chromium localmente). Fontes reais em scripts/diagrams/*.mmd.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

render() {
  local name="$1" out="$2"
  local b64 code size
  b64=$(base64 -w0 < "scripts/diagrams/${name}.mmd")
  code=$(curl -sSL --max-time 30 -w '%{http_code}' -o "$out" "https://mermaid.ink/img/${b64}?type=png&bgColor=white")
  size=$(stat -c%s "$out" 2>/dev/null || echo 0)
  echo "$name -> $out  http=$code  bytes=$size"
}

mkdir -p presentation/assets report/assets

render oran-arch        presentation/assets/oran-arch.png
render nephio-arch       presentation/assets/nephio-arch.png
render pkgrev-states     presentation/assets/pkgrev-states.png
render intent-flow       presentation/assets/intent-flow.png
render o2ims-sequence    presentation/assets/o2ims-sequence.png

render part2-arch        report/assets/part2-arch.png
render provisioning-flow report/assets/provisioning-flow.png
render nephio-arch       report/assets/nephio-arch.png
render o2ims-sequence    report/assets/o2ims-sequence.png
