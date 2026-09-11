#!/usr/bin/env bash
# check-requirements.sh (Fase 11) - verifica requisitos ANTES de instalar/usar o Nephio.
# Idempotente (só leitura). Sai com código != 0 se algum requisito CRITICO faltar.
# Uso: bash scripts/check-requirements.sh   (dentro do WSL)
set -uo pipefail

CRIT_FAIL=0
WARN=0
pass(){ printf '  [PASS] %s\n' "$1"; }
warn(){ printf '  [WARN] %s\n' "$1"; WARN=$((WARN+1)); }
crit(){ printf '  [FAIL] %s\n' "$1"; CRIT_FAIL=$((CRIT_FAIL+1)); }

echo "== check-requirements.sh :: $(date -Is) =="

# ---- SO / WSL -------------------------------------------------------------
echo; echo "-- Sistema --"
if grep -qi microsoft /proc/version 2>/dev/null; then
  pass "rodando dentro do WSL2 ($(uname -srm))"
else
  warn "não parece WSL2 ($(uname -srm)) - script assume Linux/WSL2, pode funcionar mesmo assim"
fi

# ---- Docker -----------------------------------------------------------
echo; echo "-- Docker --"
if command -v docker >/dev/null 2>&1; then
  if docker info >/dev/null 2>&1; then
    v=$(docker version --format '{{.Server.Version}}' 2>/dev/null)
    pass "Docker Engine ativo (server $v)"
  else
    crit "docker instalado mas o daemon não responde (docker info falhou)"
  fi
else
  crit "docker não encontrado no PATH"
fi

# ---- ferramentas K8s ----------------------------------------------------
echo; echo "-- CLIs Kubernetes --"
for c in kubectl kind helm kpt git; do
  if command -v "$c" >/dev/null 2>&1; then
    pass "$c presente ($($c version --client 2>/dev/null | head -n1 || $c version 2>/dev/null | head -n1 || $c --version 2>/dev/null | head -n1))"
  else
    crit "$c ausente - necessário para instalar/operar o Nephio"
  fi
done

# ---- recursos -----------------------------------------------------------
echo; echo "-- Recursos --"
mem_total_kb=$(awk '/MemTotal/{print $2}' /proc/meminfo)
mem_avail_kb=$(awk '/MemAvailable/{print $2}' /proc/meminfo)
mem_total_gb=$(awk -v k="$mem_total_kb" 'BEGIN{printf "%.1f", k/1024/1024}')
mem_avail_gb=$(awk -v k="$mem_avail_kb" 'BEGIN{printf "%.1f", k/1024/1024}')
nproc_n=$(nproc)
disk_avail_gb=$(df -BG --output=avail / 2>/dev/null | tail -n1 | tr -dc '0-9')

echo "  RAM total (WSL):     ${mem_total_gb} GiB"
echo "  RAM disponível agora: ${mem_avail_gb} GiB"
echo "  CPUs:                 ${nproc_n}"
echo "  Disco livre (/):       ${disk_avail_gb} GB"

# minimo do sandbox oficial do Nephio (docs/01-nephio-version.md): 6 vCPU / 6 GB
awk -v m="$mem_total_gb" 'BEGIN{exit !(m>=6)}'   && pass "RAM total >= 6 GiB (mínimo do sandbox Nephio)" || crit "RAM total < 6 GiB - abaixo do mínimo oficial do sandbox Nephio"
[ "$nproc_n" -ge 4 ] && pass "CPUs >= 4" || warn "menos de 4 CPUs disponíveis (recomendado >=6)"
[ "${disk_avail_gb:-0}" -ge 20 ] && pass "disco livre >= 20 GB" || warn "menos de 20 GB livres em disco"
awk -v m="$mem_avail_gb" 'BEGIN{exit !(m>=1.5)}' && pass "RAM disponível agora >= 1,5 GiB" || warn "RAM disponível agora está baixa (<1,5 GiB) - feche apps antes de instalar"

# ---- ambiente existente (não vamos destruir nada) ------------------------
echo; echo "-- Ambiente existente (informativo, nada será alterado por este script) --"
if command -v kind >/dev/null 2>&1; then
  existing=$(kind get clusters 2>/dev/null || true)
  if [ -n "$existing" ]; then
    echo "  clusters kind já presentes:"
    echo "$existing" | sed 's/^/    - /'
  else
    echo "  nenhum cluster kind presente ainda"
  fi
fi

# ---- resultado ------------------------------------------------------------
echo
echo "== RESUMO: $CRIT_FAIL crítico(s), $WARN aviso(s) =="
if [ "$CRIT_FAIL" -gt 0 ]; then
  echo "Requisitos CRÍTICOS não atendidos. Corrija antes de rodar scripts/install-nephio.sh."
  exit 1
fi
echo "Requisitos críticos OK. Pode prosseguir."
exit 0
