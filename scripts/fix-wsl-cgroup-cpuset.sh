#!/usr/bin/env bash
# Correção: nós do o-cloud-1 (CAPD) NÃO voltam depois de um restart da VM do WSL2.
#   kubelet: "failed to initialize top level QOS containers: ... cgroup
#   [kubelet kubepods] has some missing controllers: cpuset"
# Causa: no cgroup v2 do WSL2 o controller 'cpuset' não é delegado por padrão aos
#   cgroups filhos onde o Docker cria os containers do kind.
# Ação: habilita 'cpuset' (e demais) em cgroup.subtree_control em toda a árvore e
#   registra um serviço systemd que refaz isso a cada boot da VM.
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "rode como root"; exit 1; }

propagate() {
  local root=/sys/fs/cgroup
  # habilita no topo
  echo "+cpuset +cpu +io +memory +pids" > "$root/cgroup.subtree_control" 2>/dev/null || true
  # e em cada subárvore existente
  find "$root" -name cgroup.subtree_control 2>/dev/null | while read -r f; do
    echo "+cpuset" > "$f" 2>/dev/null || true
  done
}
propagate
echo "-- topo agora: $(cat /sys/fs/cgroup/cgroup.subtree_control)"

UNIT=/etc/systemd/system/wsl-cgroup-cpuset.service
cat > "$UNIT" <<'EOF'
[Unit]
Description=Delegar cpuset no cgroup v2 (kind/CAPD no WSL2)
DefaultDependencies=no
Before=docker.service containerd.service
After=sysinit.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/bash -c 'echo "+cpuset +cpu +io +memory +pids" > /sys/fs/cgroup/cgroup.subtree_control 2>/dev/null || true; find /sys/fs/cgroup -name cgroup.subtree_control -exec bash -c "echo +cpuset > {} 2>/dev/null || true" \;'

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now wsl-cgroup-cpuset.service
echo "-- serviço $UNIT habilitado --"
systemctl is-enabled wsl-cgroup-cpuset.service
echo "reinicie o docker para pegar a mudança: systemctl restart docker"
