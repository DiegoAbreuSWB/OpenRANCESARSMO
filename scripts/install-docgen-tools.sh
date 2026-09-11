#!/usr/bin/env bash
# install-docgen-tools.sh (Fase 20) - instala pandoc (gera o .pptx da Parte 1) e weasyprint
# (gera o .pdf da Parte 2) SEM sudo: `sudo` neste WSL exige autenticação interativa do
# Windows (não funciona em chamada não-interativa/background - ver docs/environment-assessment.md).
#   - pandoc: binário standalone oficial (GitHub releases) em ~/.local/bin
#   - weasyprint: pip install --user dentro de um venv (~/.venvs/docgen) - desde a v53 o
#     WeasyPrint não depende mais de Pango/GTK/cffi, então instala de wheels puros, sem apt.
# Idempotente: pode rodar de novo sem quebrar nada já instalado.
set -euo pipefail

echo "=== venv (~/.venvs/docgen) ==="
mkdir -p "$HOME/.venvs"
python3 -m venv "$HOME/.venvs/docgen"
source "$HOME/.venvs/docgen/bin/activate"
pip install --upgrade pip wheel -q

echo "=== weasyprint ==="
pip install weasyprint -q
weasyprint --version

echo "=== pandoc (binário standalone, ~/.local/bin) ==="
mkdir -p "$HOME/.local/bin"
PANDOC_VER="3.7.0.2"
URL="https://github.com/jgm/pandoc/releases/download/${PANDOC_VER}/pandoc-${PANDOC_VER}-linux-amd64.tar.gz"
if [ ! -x "$HOME/.local/bin/pandoc" ]; then
  cd /tmp
  HTTP_CODE=$(curl -sSL --max-time 60 -w '%{http_code}' -o pandoc.tar.gz "$URL" || echo "CURLFAIL")
  [ "$HTTP_CODE" = "200" ] || { echo "FAILED to download pandoc (http=$HTTP_CODE)"; exit 1; }
  tar xzf pandoc.tar.gz
  cp "pandoc-${PANDOC_VER}/bin/pandoc" "$HOME/.local/bin/pandoc"
  chmod +x "$HOME/.local/bin/pandoc"
  rm -rf pandoc.tar.gz "pandoc-${PANDOC_VER}"
fi
"$HOME/.local/bin/pandoc" --version | head -1

echo "OK - weasyprint: $("$HOME/.venvs/docgen/bin/weasyprint" --version), $("$HOME/.local/bin/pandoc" --version | head -1)"
