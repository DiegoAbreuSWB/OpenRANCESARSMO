#!/usr/bin/env bash
# ETAPA 4 - descoberta do O2 IMS realmente instalado. SÓ LEITURA. Não aplica nada.
set -uo pipefail
CTX="kind-nephio-mgmt"
kubectl config use-context "$CTX" >/dev/null
EVID="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/evidence/o2ims"
mkdir -p "$EVID"
log="$EVID/$(date +%Y%m%d-%H%M%S)_o2ims-discovery.txt"
exec > >(tee "$log") 2>&1

sep(){ printf '\n\n############ %s ############\n' "$*"; }

sep "1. CRDs candidatos (o2 / provision / ocloud / oran / focom / template / infrastructure)"
kubectl get crd | grep -Ei 'o2|provision|ocloud|oran|focom|template|infrastructure|workloadcluster|clustercontext' | sort

sep "2. api-resources candidatos"
kubectl api-resources 2>/dev/null | grep -Ei 'o2ims|provision|ocloud|oran|focom|template|workloadcluster|clustercontext'

for res in \
  provisioningrequests.o2ims.provisioning.oran.org \
  focomprovisioningrequests.focom.nephio.org \
  oclouds.focom.nephio.org \
  templateinfoes.provisioning.oran.org \
  workloadclusters.infra.nephio.org ; do
  sep "3. explain --recursive :: $res"
  kubectl explain "$res" --recursive 2>&1 | sed 's/^/  /'
done

sep "4. CRD provisioningrequests.o2ims.provisioning.oran.org (-o yaml, só spec/status)"
kubectl get crd provisioningrequests.o2ims.provisioning.oran.org -o yaml \
 | sed -n '/openAPIV3Schema/,/subresources/p' | sed 's/^/  /'

sep "5. CRD focomprovisioningrequests.focom.nephio.org (-o yaml, schema)"
kubectl get crd focomprovisioningrequests.focom.nephio.org -o yaml \
 | sed -n '/openAPIV3Schema/,/status:/p' | sed 's/^/  /'

sep "6. CRD oclouds.focom.nephio.org (-o yaml, schema)"
kubectl get crd oclouds.focom.nephio.org -o yaml \
 | sed -n '/openAPIV3Schema/,/status:/p' | sed 's/^/  /'

sep "7. CRD templateinfoes.provisioning.oran.org (-o yaml, schema)"
kubectl get crd templateinfoes.provisioning.oran.org -o yaml \
 | sed -n '/openAPIV3Schema/,/subresources/p' | sed 's/^/  /'

sep "8. o2ims-operator :: deployment (env/args/img)"
kubectl -n o2ims get deploy o2ims-operator -o jsonpath='{range .spec.template.spec.containers[*]}img={.image}{"\n"}args={.args}{"\n"}env=[{range .env[*]}{.name}={.value}; {end}]{"\n"}{end}'
sep "8b. o2ims-operator :: ClusterRole (o que observa/muta)"
kubectl get clusterrole o2ims:provisioning-role -o yaml 2>/dev/null | sed -n '/^rules:/,$p' | sed 's/^/  /'
sep "8c. o2ims-operator :: logs (tail 40)"
kubectl -n o2ims logs deploy/o2ims-operator --tail=40 2>&1 | sed 's/^/  /'

sep "9. focom-operator :: deployment (env/args/img)"
kubectl -n focom-operator-system get deploy focom-operator-controller-manager -o jsonpath='{range .spec.template.spec.containers[*]}name={.name} img={.image}{"\n"}args={.args}{"\n"}{end}'
sep "9b. focom-operator :: ClusterRole manager-role (rules)"
kubectl get clusterrole focom-operator-manager-role -o yaml 2>/dev/null | sed -n '/^rules:/,$p' | sed 's/^/  /'
sep "9c. focom-operator :: logs (tail 40)"
kubectl -n focom-operator-system logs deploy/focom-operator-controller-manager -c manager --tail=40 2>&1 | sed 's/^/  /'

sep "10. instâncias já existentes desses CRDs (esperado: nenhuma)"
for r in provisioningrequests.o2ims.provisioning.oran.org focomprovisioningrequests.focom.nephio.org oclouds.focom.nephio.org templateinfoes.provisioning.oran.org workloadclusters.infra.nephio.org clustercontexts.infra.nephio.org; do
  printf '  %-55s ' "$r"; kubectl get "$r" -A --no-headers 2>&1 | wc -l | tr -d '\n'; echo " objeto(s)"
done

sep "11. Porch: repositórios registrados"
kubectl get repositories.config.porch.kpt.dev -A 2>&1
kubectl get repositories.infra.nephio.org -A 2>&1

sep "12. CAPI: ClusterClass e templates disponíveis"
kubectl get clusterclass -A 2>&1
kubectl get dockerclustertemplate,dockermachinetemplate,kubeadmcontrolplanetemplate,kubeadmconfigtemplate -A 2>&1

echo; echo "[ok] log: $log"
