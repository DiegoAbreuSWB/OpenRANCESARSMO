#!/usr/bin/env bash
# Correção: pods do o-cloud-1 presos em ContainerCreating.
#   Erro no describe: plugin type="loopback" failed (add): failed to find plugin
#   "loopback" in path [/opt/cni/bin]
#   -> a imagem kindest/node:v1.31.0 usada pelo CAPD não trouxe os plugins CNI
#      "standard" (loopback, portmap, host-local, ptp...) em /opt/cni/bin.
#   O multus + kindnet funcionam (atribuem IP), mas a criação do sandbox exige
#   o plugin loopback.
# Ação: baixa os containernetworking/plugins e copia para /opt/cni/bin de cada nó
#       do o-cloud-1 (via docker cp).
set -euo pipefail
CNI_VER="${CNI_VER:-v1.5.1}"
TARB="/tmp/cni-plugins-${CNI_VER}.tgz"
DIR="/tmp/cni-plugins-${CNI_VER}"

nodes=$(docker ps --filter "name=o-cloud-1-" --format '{{.Names}}' | grep -vE 'o-cloud-1-lb$' || true)
[ -z "$nodes" ] && { echo "nenhum nó o-cloud-1 encontrado"; exit 1; }
echo "nós alvo:"; echo "$nodes" | sed 's/^/  /'

echo "== estado atual (/opt/cni/bin do 1o nó) =="
docker exec "$(echo "$nodes" | head -1)" ls /opt/cni/bin 2>&1 | tr '\n' ' '; echo

if [ ! -f "$TARB" ]; then
  echo "== baixando cni-plugins ${CNI_VER} =="
  curl -fsSLo "$TARB" "https://github.com/containernetworking/plugins/releases/download/${CNI_VER}/cni-plugins-linux-amd64-${CNI_VER}.tgz"
fi
mkdir -p "$DIR"; tar -xzf "$TARB" -C "$DIR"
echo "plugins disponíveis: $(ls "$DIR" | tr '\n' ' ')"

for n in $nodes; do
  echo "== $n: copiando plugins faltantes =="
  for bin in loopback host-local portmap ptp bridge bandwidth firewall sbr static tuning vlan; do
    if ! docker exec "$n" test -f "/opt/cni/bin/$bin" 2>/dev/null; then
      docker cp "$DIR/$bin" "$n:/opt/cni/bin/$bin"
      echo "  + $bin"
    fi
  done
  docker exec "$n" chmod +x /opt/cni/bin/* 2>/dev/null || true
  echo "  agora: $(docker exec "$n" ls /opt/cni/bin | tr '\n' ' ')"
done

echo "== recriando pods presos =="
export KUBECONFIG=/tmp/o-cloud-1.kubeconfig
kubectl -n kube-system delete pod -l k8s-app=kube-dns --wait=false 2>/dev/null || true
kubectl -n local-path-storage delete pod -l app=local-path-provisioner --wait=false 2>/dev/null || true
sleep 20
kubectl get pods -A
