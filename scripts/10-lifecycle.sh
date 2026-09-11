#!/usr/bin/env bash
# ETAPA 10 - demonstra o ciclo de vida do demo-nf no o-cloud-1.
# Uso: bash scripts/10-lifecycle.sh <passo>
#   instantiate | scale | update | recover | terminate | status
# Cada passo salva evidência timestamped em evidence/lifecycle/.
set -uo pipefail
CTX="o-cloud-1"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
M="$ROOT/manifests/demo-nf.yaml"
EVID="$ROOT/evidence/lifecycle"; mkdir -p "$EVID"
step="${1:-status}"
log="$EVID/$(date +%Y%m%d-%H%M%S)_etapa10_${step}.txt"
exec > >(tee "$log") 2>&1
k(){ kubectl --context "$CTX" "$@"; }
echo "== ETAPA 10 :: $step :: $(date -Is) :: cluster=$CTX =="

case "$step" in
  instantiate)
    echo "[A] INSTANTIATE — aplicar demo-nf, replicas=1"
    k apply -f "$M"
    k rollout status deploy/demo-nf --timeout=120s
    k get deploy demo-nf -o wide
    k get pods -l app=demo-nf -o wide
    echo "replicas desejadas: $(k get deploy demo-nf -o jsonpath='{.spec.replicas}')"
    ;;

  scale)
    echo "[B] SCALE — alterar replicas 1 -> 3 (declarativo)"
    echo "-- antes --"; k get deploy demo-nf -o wide; k get pods -l app=demo-nf --no-headers | wc -l | xargs echo "pods:"
    k scale deploy/demo-nf --replicas=3
    k rollout status deploy/demo-nf --timeout=120s
    echo "-- depois --"
    k get deploy demo-nf -o wide
    k get pods -l app=demo-nf -o wide
    echo "replicas: desejadas=$(k get deploy demo-nf -o jsonpath='{.spec.replicas}') prontas=$(k get deploy demo-nf -o jsonpath='{.status.readyReplicas}')"
    ;;

  update)
    echo "[C] UPDATE — mudar env VERSION v1 -> v2 (dispara rollout)"
    echo "-- antes: revision / env --"
    k get deploy demo-nf -o jsonpath='{.metadata.annotations.deployment\.kubernetes\.io/revision}{"\n"}'
    k get deploy demo-nf -o jsonpath='{.spec.template.spec.containers[0].env}{"\n"}'
    k set env deploy/demo-nf VERSION=v2
    k rollout status deploy/demo-nf --timeout=120s
    echo "-- depois --"
    k get deploy demo-nf -o jsonpath='revision={.metadata.annotations.deployment\.kubernetes\.io/revision}{"\n"}'
    k get deploy demo-nf -o jsonpath='{.spec.template.spec.containers[0].env}{"\n"}'
    echo "-- rollout history --"
    k rollout history deploy/demo-nf
    echo "-- ReplicaSets (o antigo fica com 0) --"
    k get rs -l app=demo-nf -o wide
    k get pods -l app=demo-nf -o wide
    ;;

  recover)
    echo "[D] RECOVERY / RECONCILIATION — deletar 1 pod manualmente"
    victim="$(k get pods -l app=demo-nf -o jsonpath='{.items[0].metadata.name}')"
    echo "pod alvo (antigo): $victim"
    k get pods -l app=demo-nf -o wide
    echo "--> kubectl delete pod $victim"
    k delete pod "$victim"
    echo "aguardando o Deployment reconciliar..."
    k rollout status deploy/demo-nf --timeout=120s
    echo "-- depois (o pod deletado sumiu; um novo nasceu) --"
    k get pods -l app=demo-nf -o wide
    echo "pod antigo '$victim' ainda existe? -> $(k get pod "$victim" --ignore-not-found -o name || echo NAO)"
    echo "eventos recentes do Deployment/ReplicaSet:"
    k get events --field-selector reason=SuccessfulCreate --sort-by=.lastTimestamp | tail -n 5
    echo
    echo "NOTA: isto é RECONCILIAÇÃO DECLARATIVA do Kubernetes (ReplicaSet mantém replicas=desejado)."
    echo "NÃO é 'healing' de uma NF telecom (sem estado de sessão, sem re-registro em interfaces O-RAN)."
    ;;

  terminate)
    echo "[E] TERMINATE — remover o manifesto"
    k delete -f "$M" --ignore-not-found
    sleep 5
    echo "-- verificação de remoção --"
    echo "deployment: $(k get deploy demo-nf --ignore-not-found -o name || echo REMOVIDO)"
    echo "service:    $(k get svc demo-nf --ignore-not-found -o name || echo REMOVIDO)"
    echo "pods:       $(k get pods -l app=demo-nf --no-headers 2>/dev/null | wc -l) restante(s)"
    k get all -l app=demo-nf 2>&1
    ;;

  status)
    k get deploy,rs,pods,svc -l app=demo-nf -o wide 2>&1
    echo "replicas: desejadas=$(k get deploy demo-nf -o jsonpath='{.spec.replicas}' 2>/dev/null) prontas=$(k get deploy demo-nf -o jsonpath='{.status.readyReplicas}' 2>/dev/null)"
    k get deploy demo-nf -o jsonpath='revision={.metadata.annotations.deployment\.kubernetes\.io/revision} env={.spec.template.spec.containers[0].env}{"\n"}' 2>/dev/null || true
    ;;

  *) echo "passo inválido: $step"; exit 2 ;;
esac
echo; echo "[ok] log: $log"
