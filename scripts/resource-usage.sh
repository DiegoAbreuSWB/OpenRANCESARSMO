#!/usr/bin/env bash
# resource-usage.sh - snapshot de RAM/CPU/containers/k8s do laboratório SMO/Nephio.
# Uso:
#   ./scripts/resource-usage.sh [rótulo]
# Salva uma cópia timestamped em evidence/resources/ e imprime no terminal.
# NÃO instala nada. Se metrics-server não existir, apenas pula 'kubectl top'.

set -u

label="${1:-snapshot}"
label_safe="$(printf '%s' "$label" | tr -c 'A-Za-z0-9._-' '_')"
ts="$(date +%Y%m%d-%H%M%S)"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
out_dir="$repo_root/evidence/resources"
mkdir -p "$out_dir"
out_file="$out_dir/${ts}_${label_safe}.txt"

{
  echo "==================================================================="
  echo " RESOURCE SNAPSHOT  |  label=$label  |  $(date -Is)"
  echo " host: $(uname -srm)  |  kernel WSL2"
  echo "==================================================================="

  echo
  echo "----- free -h -----"
  free -h

  echo
  echo "----- /proc/loadavg -----"
  cat /proc/loadavg

  echo
  echo "----- top 8 processos por RSS -----"
  ps -eo pid,comm,rss --sort=-rss | awk 'NR==1{print $0" (rss KiB)"} NR>1 && NR<=9 {printf "%-8s %-24s %10.1f MiB\n", $1, $2, $3/1024}'

  echo
  echo "----- docker stats --no-stream -----"
  if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    docker stats --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}'
    echo
    echo "  (containers: $(docker ps -q | wc -l) rodando / $(docker ps -aq | wc -l) total)"
  else
    echo "  docker indisponível ou daemon parado - pulado"
  fi

  echo
  echo "----- kind clusters -----"
  if command -v kind >/dev/null 2>&1; then kind get clusters 2>&1; else echo "  kind não instalado - pulado"; fi

  echo
  echo "----- kubectl top nodes -----"
  if command -v kubectl >/dev/null 2>&1; then
    kubectl top nodes 2>/dev/null || echo "  (metrics-server ausente ou sem contexto - pulado, sem instalar nada)"
  else
    echo "  kubectl não instalado - pulado"
  fi

  echo
  echo "----- kubectl top pods -A -----"
  if command -v kubectl >/dev/null 2>&1; then
    kubectl top pods -A 2>/dev/null || echo "  (metrics-server ausente ou sem contexto - pulado)"
  else
    echo "  kubectl não instalado - pulado"
  fi

  echo
  echo "----- resumo pods por contexto (se houver) -----"
  if command -v kubectl >/dev/null 2>&1; then
    for ctx in $(kubectl config get-contexts -o name 2>/dev/null); do
      n=$(kubectl --context "$ctx" get pods -A --no-headers 2>/dev/null | wc -l)
      nr=$(kubectl --context "$ctx" get pods -A --no-headers 2>/dev/null | grep -Ec 'Running|Completed' || true)
      echo "  ctx=$ctx pods=$n running/completed=$nr"
    done
  else
    echo "  kubectl não instalado - pulado"
  fi

  echo
  echo "==================================================================="
  echo " fim do snapshot"
  echo "==================================================================="
} | tee "$out_file"

echo
echo "[salvo em] $out_file"
