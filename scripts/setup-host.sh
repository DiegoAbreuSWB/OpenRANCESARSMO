#!/usr/bin/env bash
# setup-host.sh - prepara o host WSL2 Ubuntu para o laboratório SMO/Nephio.
# Idempotente. Rodar como root dentro do WSL:
#   sudo bash scripts/setup-host.sh <alvo>
# Alvos: base | docker | tools | all
#
# NÃO cria clusters. NÃO instala Nephio. Só o host (Docker Engine + CLIs).

set -euo pipefail

LAB_USER="${LAB_USER:-diegoabreu}"

# Versões fixadas - conferidas contra upstream em 2026-09-09 (ver docs/01-nephio-version.md).
# kind e kubectl são fixados para casar com o Nephio R6 (node image kindest/node:v1.32.0):
#   - kind v0.27.0 é o par estável dessa imagem (v0.33.0 só suporta K8s 1.34-1.37).
#   - kubectl v1.32.x fica dentro do skew +/-1 do apiserver 1.32.
KIND_VERSION="${KIND_VERSION:-v0.27.0}"
KUBECTL_VERSION="${KUBECTL_VERSION:-v1.32.3}"  # casa com o cluster K8s 1.32 do Nephio R6
HELM_VERSION="${HELM_VERSION:-v3.19.0}"        # linha 3.x por compat. de charts; ver nota no doc
KPT_VERSION="${KPT_VERSION:-v1.0.0}"
PORCHCTL_VERSION="${PORCHCTL_VERSION:-v1.5.6}"  # casa com o Porch v1.5.6 do Nephio R6 (Fase 12)

log() { printf '\n\033[1;36m== %s\033[0m\n' "$*"; }

need_root() { [ "$(id -u)" -eq 0 ] || { echo "rode como root (sudo)"; exit 1; }; }

do_base() {
  log "base: pacotes de apoio"
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y --no-install-recommends \
    ca-certificates curl gnupg jq git make apt-transport-https lsb-release
  echo "base OK"
}

do_docker() {
  log "docker: repositório oficial Docker CE"
  if command -v docker >/dev/null 2>&1 && docker --version >/dev/null 2>&1; then
    echo "docker já presente: $(docker --version)"
  else
    export DEBIAN_FRONTEND=noninteractive
    install -m 0755 -d /etc/apt/keyrings
    if [ ! -f /etc/apt/keyrings/docker.asc ]; then
      curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
      chmod a+r /etc/apt/keyrings/docker.asc
    fi
    . /etc/os-release
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable" \
      > /etc/apt/sources.list.d/docker.list
    apt-get update -qq
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  fi

  log "docker: daemon.json (limita logs, poupa disco/RAM)"
  install -d /etc/docker
  cat > /etc/docker/daemon.json <<'JSON'
{
  "log-driver": "json-file",
  "log-opts": { "max-size": "10m", "max-file": "3" }
}
JSON

  log "docker: habilitar via systemd + grupo do usuário"
  systemctl enable --now docker
  usermod -aG docker "$LAB_USER" || true
  systemctl restart docker
  sleep 2
  docker version
  echo "docker OK (o usuário '$LAB_USER' precisa de um novo shell / 'wsl --shutdown' para o grupo valer sem sudo)"
}

do_tools() {
  log "tools: kubectl"
  if ! command -v kubectl >/dev/null 2>&1; then
    ver="${KUBECTL_VERSION:-$(curl -fsSL https://dl.k8s.io/release/stable.txt)}"
    curl -fsSLo /usr/local/bin/kubectl "https://dl.k8s.io/release/${ver}/bin/linux/amd64/kubectl"
    chmod +x /usr/local/bin/kubectl
  fi
  kubectl version --client=true

  log "tools: kind ${KIND_VERSION}"
  if ! command -v kind >/dev/null 2>&1; then
    curl -fsSLo /usr/local/bin/kind "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-amd64"
    chmod +x /usr/local/bin/kind
  fi
  kind --version

  log "tools: helm (linha 3.x, via instalador oficial get-helm-3)"
  if ! command -v helm >/dev/null 2>&1; then
    tmp="$(mktemp -d)"
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 -o "$tmp/get-helm-3"
    # DESIRED_VERSION força a linha 3.x mesmo após o lançamento do Helm 4
    HELM_INSTALL_DIR=/usr/local/bin DESIRED_VERSION="${HELM_VERSION}" USE_SUDO=false bash "$tmp/get-helm-3" \
      || HELM_INSTALL_DIR=/usr/local/bin USE_SUDO=false bash "$tmp/get-helm-3"
    rm -rf "$tmp"
  fi
  helm version --short

  log "tools: kpt ${KPT_VERSION}"
  if ! command -v kpt >/dev/null 2>&1; then
    curl -fsSLo /usr/local/bin/kpt "https://github.com/kptdev/kpt/releases/download/${KPT_VERSION}/kpt_linux_amd64"
    chmod +x /usr/local/bin/kpt
  fi
  kpt version

  log "tools: porchctl ${PORCHCTL_VERSION}"
  if ! command -v porchctl >/dev/null 2>&1; then
    tmp="$(mktemp -d)"
    curl -fsSL "https://github.com/kptdev/porch/releases/download/${PORCHCTL_VERSION}/porchctl_${PORCHCTL_VERSION#v}_linux_amd64.tar.gz" \
      | tar -xz -C "$tmp"
    install -m 0755 "$tmp/porchctl" /usr/local/bin/porchctl
    rm -rf "$tmp"
  fi
  porchctl version

  echo "tools OK"
}

need_root
case "${1:-}" in
  base)   do_base ;;
  docker) do_docker ;;
  tools)  do_tools ;;
  all)    do_base; do_docker; do_tools ;;
  *) echo "uso: sudo bash scripts/setup-host.sh {base|docker|tools|all}"; exit 2 ;;
esac
