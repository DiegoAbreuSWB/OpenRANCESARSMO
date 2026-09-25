#!/usr/bin/env bash
# Sobe o Console SMO Nephio em localhost (sem depender de nenhum link do claude.ai).
# Rode isto DENTRO do WSL (onde o kubectl do laboratorio esta configurado) - o WSL2
# encaminha automaticamente a porta para o Windows, entao "http://localhost:8090"
# funciona igual no navegador do host.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT="${1:-8090}"
echo "Iniciando em http://localhost:${PORT}/ (Ctrl+C para parar)"
exec python3 "$ROOT/dashboard/server.py" "$PORT"
