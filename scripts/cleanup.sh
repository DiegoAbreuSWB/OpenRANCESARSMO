#!/usr/bin/env bash
# ETAPA 20 - remove APENAS o que este laboratório criou.
# NUNCA apaga: outros clusters kind, containers/imagens/volumes não relacionados,
# arquivos pessoais, a instalação de Docker/WSL.
# Roda dentro do WSL:  bash scripts/cleanup.sh [--yes] [--keep-images]
set -uo pipefail

ASSUME_YES=0; KEEP_IMAGES=1
for a in "$@"; do
  case "$a" in
    --yes) ASSUME_YES=1;;
    --purge-images) KEEP_IMAGES=0;;
  esac
done
confirm(){ # pergunta antes de cada bloco
  [ "$ASSUME_YES" = 1 ] && return 0
  read -r -p ">> $1  [y/N] " a </dev/tty || a=n
  [ "$a" = y ] || [ "$a" = Y ]
}

echo "================================================================"
echo " CLEANUP do laboratório SMO/Nephio"
echo " Serão considerados para remoção SOMENTE:"
echo "   - clusters kind:  nephio-mgmt  e  o-cloud-1"
echo "   - containers docker cujo nome começa com 'o-cloud-1' ou 'nephio-mgmt'"
echo "   - pasta ~/nephio-install (pacotes kpt baixados)"
echo "   - /tmp/o-cloud-1.kubeconfig"
echo "   - contextos kube: kind-nephio-mgmt, o-cloud-1"
echo " NÃO serão tocados: outros clusters kind, imagens, volumes, .wslconfig,"
echo "   Docker/WSL, nem os arquivos deste repositório (docs/evidence/scripts)."
echo "================================================================"
echo

echo "### O que existe hoje ###"
echo "-- kind clusters --"; kind get clusters 2>/dev/null | sed 's/^/   /'
echo "-- containers do lab --"
docker ps -a --format '{{.Names}}\t{{.Status}}' 2>/dev/null | grep -E '^(o-cloud-1|nephio-mgmt)' | sed 's/^/   /' || echo "   (nenhum)"
echo

# 1) demo-nf (best effort, o cluster pode já não existir)
if confirm "Remover o Deployment/Service demo-nf do o-cloud-1?"; then
  kubectl --context o-cloud-1 delete -f "$(dirname "$0")/../manifests/demo-nf.yaml" --ignore-not-found 2>/dev/null || true
fi

# 2) ProvisioningRequest + objetos Nephio do o-cloud-1
if confirm "Remover o ProvisioningRequest / PackageVariant / Cluster CAPI do o-cloud-1?"; then
  kubectl --context kind-nephio-mgmt delete provisioningrequest.o2ims.provisioning.oran.org o-cloud-1 --ignore-not-found 2>/dev/null || true
  kubectl --context kind-nephio-mgmt -n default delete packagevariant o-cloud-1 --ignore-not-found 2>/dev/null || true
  kubectl --context kind-nephio-mgmt -n default delete cluster.cluster.x-k8s.io o-cloud-1 --ignore-not-found --timeout=60s 2>/dev/null || true
fi

# 3) cluster kind o-cloud-1 (containers CAPD)
if confirm "Deletar o cluster kind 'o-cloud-1' (e seus containers Docker)?"; then
  kind delete cluster --name o-cloud-1 2>/dev/null || true
  docker ps -a --format '{{.Names}}' | grep -E '^o-cloud-1' | while read -r c; do
    echo "   docker rm -f $c"; docker rm -f "$c" >/dev/null 2>&1 || true
  done
fi

# 4) cluster kind nephio-mgmt
if confirm "Deletar o cluster kind 'nephio-mgmt' (Management Cluster + Nephio)?"; then
  kind delete cluster --name nephio-mgmt 2>/dev/null || true
fi

# 5) artefatos locais
if confirm "Remover ~/nephio-install e /tmp/o-cloud-1.kubeconfig ?"; then
  rm -rf "$HOME/nephio-install" /tmp/o-cloud-1.kubeconfig /tmp/cni-plugins-* 2>/dev/null || true
fi

# 6) contextos kube órfãos
if confirm "Limpar contextos kube 'kind-nephio-mgmt' e 'o-cloud-1' do ~/.kube/config ?"; then
  kubectl config delete-context kind-nephio-mgmt 2>/dev/null || true
  kubectl config delete-context o-cloud-1 2>/dev/null || true
  kubectl config delete-cluster kind-nephio-mgmt 2>/dev/null || true
  kubectl config delete-cluster o-cloud-1 2>/dev/null || true
  kubectl config delete-user o-cloud-1-admin 2>/dev/null || true
fi

# 7) imagens (opcional, desligado por padrão)
if [ "$KEEP_IMAGES" = 0 ] && confirm "APAGAR imagens Docker do lab (kindest/node, kindest/haproxy, nephio/*, cni-plugins)? Isto afeta SÓ estas tags."; then
  docker images --format '{{.Repository}}:{{.Tag}}' | grep -E 'kindest/(node|haproxy)|^nephio/|kube-rbac-proxy' | while read -r img; do
    echo "   docker rmi $img"; docker rmi "$img" >/dev/null 2>&1 || true
  done
fi

echo
echo "### Estado final ###"
kind get clusters 2>/dev/null | sed 's/^/   /' || echo "   (nenhum cluster kind)"
docker ps -a --format '{{.Names}}' 2>/dev/null | grep -E '^(o-cloud-1|nephio-mgmt)' | sed 's/^/   ainda existe: /' || echo "   (nenhum container do lab restante)"
echo
echo "Preservados: .wslconfig, /etc/sysctl.d/99-nephio-lab.conf, /etc/systemd/system/wsl-cgroup-cpuset.service,"
echo "            Docker/WSL, e todo o conteúdo deste repositório (docs/ evidence/ scripts/ manifests/)."
echo "Para reinstalar do zero: siga o README.md."
