#!/usr/bin/env bash
# build-report-pdf.sh (Fase 20) - gera report/Parte2-Relatorio-SMO-Nephio.pdf a partir de
# report/part2-report-print.html (HTML/CSS autoral com evidências reais embutidas) via
# WeasyPrint. Requer scripts/install-docgen-tools.sh já executado.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WEASY="$HOME/.venvs/docgen/bin/weasyprint"
[ -x "$WEASY" ] || { echo "weasyprint não encontrado - rode scripts/install-docgen-tools.sh primeiro"; exit 1; }
cd "$ROOT/report"
"$WEASY" part2-report-print.html "Parte2-Relatorio-SMO-Nephio.pdf"
ls -la "Parte2-Relatorio-SMO-Nephio.pdf"
file "Parte2-Relatorio-SMO-Nephio.pdf"
