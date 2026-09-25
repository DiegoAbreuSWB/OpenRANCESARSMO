#!/usr/bin/env bash
# build-pptx-part2.sh - gera presentation/Parte2-Apresentacao-SMO-Nephio.pptx a partir de
# presentation/part2-slides-deck.md via pandoc (--slide-level=2, notas via '::: notes').
# Requer scripts/install-docgen-tools.sh já executado.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PANDOC="$HOME/.local/bin/pandoc"
[ -x "$PANDOC" ] || { echo "pandoc não encontrado - rode scripts/install-docgen-tools.sh primeiro"; exit 1; }
cd "$ROOT/presentation"
"$PANDOC" -t pptx --slide-level=2 -o "Parte2-Apresentacao-SMO-Nephio.pptx" "part2-slides-deck.md"
ls -la "Parte2-Apresentacao-SMO-Nephio.pptx"
file "Parte2-Apresentacao-SMO-Nephio.pptx"
