#!/usr/bin/env bash
# Recria o o-cloud-1 do ZERO via o fluxo O2 IMS.
# Use quando o o-cloud-1 (CAPD) não recuperar após um restart da VM do WSL2:
# os IPs dos containers embaralham, o kube-apiserver do workload não volta e o
# GitOps (PackageRevisions no repo mgmt) fica inconsistente.
# O management cluster + Nephio NÃO são tocados.
#
# Pré-req: o mgmt precisa estar de pé (rode antes: scripts/lab-recover.sh).
set -uo pipefail
C=kind-nephio-mgmt
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
kubectl config use-context "$C" >/dev/null

echo "==== 1) apaga ProvisioningRequest + PackageVariant ===="
kubectl delete provisioningrequest.o2ims.provisioning.oran.org o-cloud-1 --ignore-not-found --wait=false
kubectl -n default delete packagevariant o-cloud-1 --ignore-not-found --wait=false
kubectl -n default delete cluster.cluster.x-k8s.io o-cloud-1 --ignore-not-found --wait=false || true
kubectl -n default delete workloadcluster.infra.nephio.org o-cloud-1 --ignore-not-found
sleep 5

echo "==== 2) RESET do GitOps: força saída de todas as PackageRevisions o-cloud-1* ===="
for pass in 1 2 3 4; do
  prs=$(kubectl -n default get packagerevisions -o name 2>/dev/null | grep -E 'o-cloud-1' || true)
  [ -z "$prs" ] && { echo "  limpo (pass $pass)"; break; }
  for pr in $prs; do
    kubectl -n default patch "$pr" --type=merge -p '{"spec":{"lifecycle":"DeletionProposed"}}' >/dev/null 2>&1 || true
    kubectl -n default delete "$pr" --ignore-not-found --wait=false >/dev/null 2>&1 || true
  done
  sleep 10
done
kubectl -n default get packagerevisions 2>/dev/null | grep -E 'o-cloud-1' && echo "  [!] ainda há PackageRevisions" || echo "  nenhuma PackageRevision o-cloud-1"

echo "==== 3) espera RootSync(mgmt) sincronizar o estado vazio (~90s) ===="
for i in $(seq 1 16); do
  se=$(kubectl -n config-management-system get rootsync mgmt -o jsonpath='{.status.sync.errorSummary.totalCount}' 2>/dev/null)
  echo "  $(date +%T) rootsync syncErrors=${se:-0}"; sleep 6
done
docker ps -a --format '{{.Names}}' | grep -E '^o-cloud-1' | xargs -r docker rm -f 2>/dev/null || true

echo "==== 4) re-aplica o ProvisioningRequest ===="
kubectl apply -f "$ROOT/manifests/o2-provisioning-request.yaml"
st=""
for i in $(seq 1 72); do
  st=$(kubectl get provisioningrequest.o2ims.provisioning.oran.org o-cloud-1 -o jsonpath='{.status.provisioningStatus.provisioningState}' 2>/dev/null || true)
  ph=$(kubectl -n default get cluster.cluster.x-k8s.io o-cloud-1 -o jsonpath='{.status.phase}' 2>/dev/null || true)
  echo "  $(date +%T) provisioningState=$st clusterPhase=$ph"
  [ "$st" = fulfilled ] && break
  [ "$st" = failed ] && { kubectl -n o2ims logs deploy/o2ims-operator --tail=20; break; }
  sleep 5
done

echo "==== 5) kubeconfig + CNI plugins + nós ===="
bash "$ROOT/scripts/ocloud-kubeconfig.sh" o-cloud-1 2>&1 | tail -n 6
bash "$ROOT/scripts/fix-ocloud-cni-plugins.sh" 2>&1 | tail -n 12
KC=/tmp/o-cloud-1.kubeconfig
for i in $(seq 1 40); do
  r=$(kubectl --kubeconfig "$KC" get nodes --no-headers 2>/dev/null | grep -cw Ready || true)
  echo "  $(date +%T) nós Ready=$r/2"; [ "${r:-0}" -ge 2 ] && break; sleep 10
done
kubectl --kubeconfig "$KC" get nodes -o wide

echo "==== 6) re-deploy demo-nf ===="
kubectl --context o-cloud-1 apply -f "$ROOT/manifests/demo-nf.yaml"
kubectl --context o-cloud-1 rollout status deploy/demo-nf --timeout=120s || true
kubectl --context o-cloud-1 get deploy,pods,svc -l app=demo-nf
echo
echo "[fim] provisioningState=$st"
