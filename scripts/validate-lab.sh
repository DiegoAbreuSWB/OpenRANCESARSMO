#!/usr/bin/env bash
# ETAPA 12 - validação automática do laboratório SMO/Nephio.
# Roda dentro do WSL:  bash scripts/validate-lab.sh
# Imprime PASS / FAIL / SKIP para cada item. NÃO esconde falhas.
# Itens 6-10 mexem no demo-nf; ao final o demo-nf é RESTAURADO (replicas=1) para
# deixar o lab em estado demonstrável.
set -uo pipefail

MGMT="kind-nephio-mgmt"
OC="o-cloud-1"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
M="$ROOT/manifests/demo-nf.yaml"
EVID="$ROOT/evidence"; mkdir -p "$EVID"
LOG="$EVID/$(date +%Y%m%d-%H%M%S)_validate-lab.txt"
exec > >(tee "$LOG") 2>&1

PASS=0; FAIL=0; SKIP=0
res(){ printf '  [%-4s] %s\n' "$1" "$2"; case "$1" in PASS) PASS=$((PASS+1));; FAIL) FAIL=$((FAIL+1));; SKIP) SKIP=$((SKIP+1));; esac; }
km(){ kubectl --context "$MGMT" "$@"; }
ko(){ kubectl --context "$OC" "$@"; }

echo "================ VALIDATE LAB :: $(date -Is) ================"

# 1 -----------------------------------------------------------------
echo "1) Management Cluster existe"
if kind get clusters 2>/dev/null | grep -qx "nephio-mgmt" && km get nodes >/dev/null 2>&1; then
  n=$(km get nodes --no-headers | grep -c ' Ready ' || true)
  res PASS "kind 'nephio-mgmt' presente, $n nó(s) Ready, contexto $MGMT responde"
else
  res FAIL "cluster nephio-mgmt ausente ou apiserver não responde"
fi

# 2 -----------------------------------------------------------------
echo "2) Nephio está saudável (Porch + nephio-controller + Gitea + ConfigSync)"
need_ns="porch-system nephio-system gitea config-management-system"
bad=""
for ns in $need_ns; do
  tot=$(km -n "$ns" get pods --no-headers 2>/dev/null | wc -l)
  rdy=$(km -n "$ns" get pods --no-headers 2>/dev/null | awk '{split($2,a,"/"); if(a[1]==a[2]&&a[2]!=0)r++} END{print r+0}')
  [ "$tot" -gt 0 ] && [ "$rdy" -eq "$tot" ] || bad="$bad $ns($rdy/$tot)"
done
porch_api=$(km api-resources 2>/dev/null | grep -c 'porch.kpt.dev' || true)
if [ -z "$bad" ] && [ "$porch_api" -ge 1 ]; then
  res PASS "pods de$([ -n "$need_ns" ] && echo " $need_ns") todos Ready; API Porch registrada"
else
  res FAIL "componentes Nephio com problema:$bad ; porch api-resources=$porch_api"
fi

# 3 -----------------------------------------------------------------
echo "3) Componentes O2 IMS necessários existem"
crd_pr=$(km get crd provisioningrequests.o2ims.provisioning.oran.org -o name 2>/dev/null || true)
o2_pod=$(km -n o2ims get pods --no-headers 2>/dev/null | grep -c 'Running' || true)
focom_pod=$(km -n focom-operator-system get pods --no-headers 2>/dev/null | grep -c 'Running' || true)
repo_ok=$(km get repository catalog-infra-capi -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)
if [ -n "$crd_pr" ] && [ "$o2_pod" -ge 1 ] && [ "$focom_pod" -ge 1 ] && [ "$repo_ok" = "True" ]; then
  res PASS "CRD ProvisioningRequest + o2ims-operator + focom-operator Running + repo Porch catalog-infra-capi Ready"
else
  res FAIL "o2ims: crd='$crd_pr' o2ims_pods=$o2_pod focom_pods=$focom_pod catalog-infra-capi.Ready=$repo_ok"
fi

# 4 -----------------------------------------------------------------
echo "4) Workload cluster (O-Cloud) existe"
pr_state=$(km get provisioningrequest.o2ims.provisioning.oran.org o-cloud-1 -o jsonpath='{.status.provisioningStatus.provisioningState}' 2>/dev/null || true)
capi_phase=$(km get cluster.cluster.x-k8s.io o-cloud-1 -n default -o jsonpath='{.status.phase}' 2>/dev/null || true)
if kind get clusters 2>/dev/null | grep -qx "o-cloud-1"; then
  res PASS "kind 'o-cloud-1' presente | ProvisioningRequest=$pr_state | CAPI Cluster phase=$capi_phase"
else
  res FAIL "cluster o-cloud-1 ausente (ProvisioningRequest=$pr_state, CAPI phase=$capi_phase)"
fi

# 5 -----------------------------------------------------------------
echo "5) Workload cluster responde"
if ko get --raw=/readyz >/dev/null 2>&1; then
  nn=$(ko get nodes --no-headers 2>/dev/null | grep -c ' Ready ' || true)
  res PASS "contexto $OC /readyz OK, $nn nó(s) Ready"
else
  res FAIL "contexto $OC não responde (rode scripts/ocloud-kubeconfig.sh)"
fi

# 6 -----------------------------------------------------------------
echo "6) demo-nf pode ser implantada"
if [ "$(ko get --raw=/readyz 2>/dev/null)" != "ok" ]; then
  res SKIP "o-cloud-1 não responde — pulando 6..10"
else
  ko delete -f "$M" --ignore-not-found >/dev/null 2>&1
  if ko apply -f "$M" >/dev/null 2>&1; then
    res PASS "kubectl apply -f manifests/demo-nf.yaml aceito"
  else
    res FAIL "apply do demo-nf rejeitado"
  fi

  # 7 ---------------------------------------------------------------
  echo "7) demo-nf fica Ready"
  if ko rollout status deploy/demo-nf --timeout=120s >/dev/null 2>&1; then
    res PASS "deployment demo-nf rollout concluído ($(ko get deploy demo-nf -o jsonpath='{.status.readyReplicas}')/$(ko get deploy demo-nf -o jsonpath='{.spec.replicas}'))"
  else
    res FAIL "demo-nf não ficou Ready em 120s"
  fi

  # 8 ---------------------------------------------------------------
  echo "8) scale funciona (1 -> 3)"
  ko scale deploy/demo-nf --replicas=3 >/dev/null 2>&1
  if ko rollout status deploy/demo-nf --timeout=120s >/dev/null 2>&1 && [ "$(ko get deploy demo-nf -o jsonpath='{.status.readyReplicas}')" = "3" ]; then
    res PASS "3/3 réplicas prontas"
  else
    res FAIL "scale para 3 não convergiu ($(ko get deploy demo-nf -o jsonpath='{.status.readyReplicas}')/3)"
  fi

  # 9 ---------------------------------------------------------------
  echo "9) delete de pod gera reconciliação"
  v=$(ko get pods -l app=demo-nf -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  ko delete pod "$v" >/dev/null 2>&1
  ok=false
  for i in $(seq 1 24); do
    cnt=$(ko get pods -l app=demo-nf --no-headers 2>/dev/null | grep -c ' Running ' || true)
    still=$(ko get pod "$v" --ignore-not-found -o name 2>/dev/null)
    [ "$cnt" = "3" ] && [ -z "$still" ] && { ok=true; break; }
    sleep 5
  done
  $ok && res PASS "pod '$v' deletado -> ReplicaSet recriou -> 3/3 Running de novo" \
       || res FAIL "reconciliação não restaurou 3/3 após deletar '$v'"

  # 10 --------------------------------------------------------------
  echo "10) cleanup funciona (delete -f remove tudo do demo-nf)"
  ko delete -f "$M" --ignore-not-found >/dev/null 2>&1
  sleep 5
  left=$(ko get deploy,svc,pods -l app=demo-nf --no-headers 2>/dev/null | wc -l)
  if [ "$left" -eq 0 ]; then
    res PASS "nenhum recurso demo-nf remanescente após delete -f"
  else
    res FAIL "$left recurso(s) demo-nf ainda presente(s) após cleanup"
  fi

  echo "   (restaurando demo-nf replicas=1 para deixar o lab demonstrável)"
  ko apply -f "$M" >/dev/null 2>&1 && ko rollout status deploy/demo-nf --timeout=90s >/dev/null 2>&1 || true
fi

echo
echo "================ RESUMO: PASS=$PASS  FAIL=$FAIL  SKIP=$SKIP ================"
echo "log: $LOG"
[ "$FAIL" -eq 0 ]
