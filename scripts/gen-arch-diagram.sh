#!/usr/bin/env bash
set -euo pipefail
ROOT="/mnt/c/Users/diego.abreu/Documents/Desenvolvimento/Curso CESAR/SMO/X"
cp "$ROOT/scripts/arch.mmd" /tmp/arch.mmd
B64=$(base64 -w0 /tmp/arch.mmd)
echo "b64 length: ${#B64}"
curl -sS "https://mermaid.ink/img/${B64}?type=png&bgColor=white" -o /tmp/arch.png -w "http:%{http_code}\n"
file /tmp/arch.png
if file /tmp/arch.png | grep -q PNG; then
  cp /tmp/arch.png "$ROOT/report/assets/architecture-final.png"
  cp /tmp/arch.png "$ROOT/presentation/assets/architecture-final.png"
  echo "OK - copiado para report/ e presentation/"
else
  echo "--- corpo da resposta (erro) ---"
  cat /tmp/arch.png
fi
