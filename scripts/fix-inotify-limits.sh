#!/usr/bin/env bash
# Correção: pods do kind falhando com "too many open files".
# Causa: limites de inotify do kernel (compartilhado com a VM do WSL2) baixos demais
# para vários controllers num único nó kind. É o item "Pod errors due to too many
# open files" do known-issues oficial do kind.
# Ação: eleva fs.inotify.* e fs.file-max no host WSL2 e persiste em /etc/sysctl.d/.
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "rode como root (sudo)"; exit 1; }

CONF=/etc/sysctl.d/99-nephio-lab.conf
cat > "$CONF" <<'EOF'
# laboratório SMO/Nephio - limites para muitos controllers em 1 nó kind
fs.inotify.max_user_watches = 1048576
fs.inotify.max_user_instances = 8192
fs.file-max = 1048576
EOF
echo "[escrito] $CONF"
sysctl -p "$CONF"

echo "--- valores efetivos ---"
sysctl fs.inotify.max_user_watches fs.inotify.max_user_instances fs.file-max
