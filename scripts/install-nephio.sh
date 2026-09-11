#!/usr/bin/env bash
# install-nephio.sh (Fase 11) - instala o Nephio de forma IDEMPOTENTE.
#
# Release identificada e versionada em docs/01-nephio-version.md:
#   Nephio R6 (tag v6.0.0) | catálogo nephio-project/catalog @ branch v6
#   K8s alvo do management cluster: v1.32.0 (kind)
# Requisitos verificados em docs/01-nephio-version.md / scripts/check-requirements.sh:
#   mínimo oficial do sandbox = 6 vCPU / 6 GB RAM (ver assert do playbook oficial)
#
# Este script NÃO reinstala o que já existe e saudável, e NUNCA apaga um cluster
# existente. Ele apenas encadeia os scripts já testados deste repositório
# (scripts/01-mgmt-cluster.sh, scripts/03-nephio-min.sh, correções de bugs upstream)
# e para no primeiro erro real, mostrando a causa.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CTX="kind-nephio-mgmt"

echo "############################################################"
echo "# install-nephio.sh :: $(date -Is)"
echo "# Release-alvo: Nephio R6 (v6.0.0) - ver docs/01-nephio-version.md"
echo "############################################################"

echo; echo "== Passo A: verificar requisitos =="
if ! bash "$ROOT/scripts/check-requirements.sh"; then
  echo "ABORTANDO: requisitos críticos não atendidos (ver acima)."
  exit 1
fi

echo; echo "== Passo B: já está instalado? (idempotência) =="
if kubectl --context "$CTX" get nodes >/dev/null 2>&1; then
  tot=$(kubectl --context "$CTX" get pods -A --no-headers 2>/dev/null | wc -l)
  rdy=$(kubectl --context "$CTX" get pods -A --no-headers 2>/dev/null | awk '{split($2,a,"/"); if(a[1]==a[2]&&a[2]!=0)r++} END{print r+0}')
  porch_api=$(kubectl --context "$CTX" api-resources 2>/dev/null | grep -c 'porch.kpt.dev' || true)
  o2ims_crd=$(kubectl --context "$CTX" get crd provisioningrequests.o2ims.provisioning.oran.org -o name 2>/dev/null || true)
  echo "  cluster '$CTX' já responde. pods: $rdy/$tot Ready. Porch API: ${porch_api:-0} recursos. O2IMS CRD: ${o2ims_crd:+presente}"
  if [ "$tot" -gt 0 ] && [ "$rdy" -eq "$tot" ] && [ "$porch_api" -ge 1 ] && [ -n "$o2ims_crd" ]; then
    echo
    echo "== JÁ INSTALADO E SAUDÁVEL — nada a fazer (idempotente) =="
    echo "   Se algum cluster caiu por restart da VM do WSL2, use:"
    echo "     bash scripts/lab-recover.sh          # management cluster"
    echo "     bash scripts/reprovision-ocloud.sh   # workload cluster / O-Cloud"
    exit 0
  fi
  echo "  cluster existe mas está incompleto/não saudável — vou completar a instalação (sem apagar nada)."
else
  echo "  cluster '$CTX' ainda não existe — instalação do zero."
fi

echo; echo "== Passo C: management cluster (kind, idempotente) =="
bash "$ROOT/scripts/01-mgmt-cluster.sh" || { echo "FALHOU no Passo C — ver log acima."; exit 1; }

echo; echo "== Passo D: Nephio R6 mínimo, pacote a pacote (idempotente por pacote) =="
for step in cert-manager porch gitea nephio-operator configsync capi metallb resource-backend focom o2ims; do
  echo "--- pacote: $step ---"
  bash "$ROOT/scripts/03-nephio-min.sh" "$step" || { echo "FALHOU no pacote '$step' — ver log acima. Corrija e rode novamente (idempotente)."; exit 1; }
done

echo; echo "== Passo E: correções de bugs conhecidos do upstream R6 =="
bash "$ROOT/scripts/patch-nephio-operator-rbacproxy.sh" || echo "  [aviso] patch do rbac-proxy retornou erro — verifique manualmente (ver docs/02)."
sudo -n bash "$ROOT/scripts/fix-inotify-limits.sh" 2>/dev/null || echo "  [aviso] fix-inotify-limits precisa de sudo — rode manualmente se CAPD entrar em CrashLoop."

echo; echo "== Passo F: verificação final =="
bash "$ROOT/scripts/03-nephio-min.sh" status

echo
echo "== install-nephio.sh concluído. Use 'kubectl --context $CTX ...' para operar o cluster. =="
