#!/usr/bin/env bash
# Prova de carga do rapp-autoscale (lab/nephio/rapp-autoscale): gera trafego real contra
# oran-cu e observa o rApp decidir e aplicar o scale-up sozinho (poll nao-tempo-real de
# 30s). Requer scripts/13-rapp-autoscale.sh ja aplicado. Ver docs/improvements-16gb.md
# Sec.4 para o design completo e o achado real sobre GitOps x controle imperativo.
set -uo pipefail
echo "== ANTES =="
kubectl --context o-cloud-1 -n openran-lab get deploy/oran-cu --no-headers

echo "== gerando trafego (300 requisicoes a /metrics) =="
kubectl --context o-cloud-1 -n openran-lab exec deploy/oran-cu -- python3 -c "
import urllib.request, time
t0 = time.time()
for i in range(300):
    urllib.request.urlopen('http://localhost:8080/metrics', timeout=3).read()
print('300 requisicoes em %.2fs' % (time.time() - t0))
"

echo "== aguardando 1 ciclo do rApp (poll=30s) =="
sleep 35
echo "== DEPOIS (scale up esperado) =="
kubectl --context o-cloud-1 -n openran-lab logs deploy/rapp-autoscale --tail=4
kubectl --context o-cloud-1 -n openran-lab get deploy/oran-cu --no-headers
kubectl --context o-cloud-1 -n openran-lab get pods -l app=oran-cu --no-headers

echo "== aguardando o trafego zerar e o rApp reduzir de volta (poll=30s) =="
sleep 35
kubectl --context o-cloud-1 -n openran-lab logs deploy/rapp-autoscale --tail=4
kubectl --context o-cloud-1 -n openran-lab get deploy/oran-cu --no-headers
