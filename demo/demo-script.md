# Roteiro de demonstração (Fase 19)

> Duração alvo: **8–10 minutos**. Rodar dentro do WSL (`wsl -d Ubuntu`), a partir da raiz do
> repositório. **Antes de começar:** `make status` para confirmar que os clusters estão de pé;
> se as 3 CNFs não estiverem todas presentes, rode `bash scripts/run-experiments.sh 1` (reprovisiona
> do zero em ~20s) para começar com um estado limpo e completo.

Para cada etapa: comando → resultado esperado → o que falar.

---

## 1. Mostrar o cluster

**Comando:**
```bash
kubectl --context o-cloud-1 get nodes
```
**Resultado esperado:** 2 nós `Ready` (`o-cloud-1-...-control-plane`, `o-cloud-1-md-0-...`), `v1.31.0`.

**Falar:** "Este é o `o-cloud-1` — um workload cluster que o próprio Nephio provisionou via O2
IMS, a partir de um `ProvisioningRequest`. Vou usá-lo agora como o O-Cloud onde as funções de
rede vão rodar."

---

## 2. Mostrar que não existem NFs

**Comando:**
```bash
kubectl --context o-cloud-1 -n openran-lab get all
```
**Resultado esperado:** `No resources found` (se o namespace ainda não existir) **ou** rode
antes `kubectl --context o-cloud-1 delete ns openran-lab --ignore-not-found` para garantir o
estado zerado.

**Falar:** "Estado inicial: nenhuma Network Function rodando."

---

## 3. Provisionar

**Comando:**
```bash
time bash lab/nephio/deploy-cnfs-via-porch.sh
```
**Resultado esperado:** log mostrando `porchctl rpkg init/push/propose/approve`, depois
`kpt live apply ... apply result: 10 attempted, 10 successful`. Tempo total ≈ 15–20 s.

**Falar:** "Isso não é um `kubectl apply` direto. É um pacote kpt sendo publicado no Porch —
Draft, Proposed, Published — e só depois aplicado no cluster via reconciliação declarativa. O
mesmo mecanismo usado em produção pelo Nephio."

---

## 4. Mostrar NFs Running

**Comando:**
```bash
kubectl --context o-cloud-1 -n openran-lab get deploy,pods,svc
```
**Resultado esperado:** `oran-cu`, `oran-du`, `oran-core` — todos `1/1 Running`.

**Falar:** "Três Network Functions representativas — O-CU, O-DU e um core 5G simplificado —
todas de pé."

---

## 5. Consultar `/health`

**Comando:**
```bash
kubectl --context o-cloud-1 -n openran-lab exec deploy/oran-du -- python3 -c "
import urllib.request
print(urllib.request.urlopen('http://localhost:8080/health', timeout=3).read().decode())
"
```
**Resultado esperado:** `{"status":"ok","nf_name":"oran-du","nf_type":"O-DU",...}`.

**Falar:** "Cada NF expõe seu próprio endpoint de saúde — o tipo de verificação que um
orquestrador real faria antes de considerar a NF operacional."

---

## 6. Mostrar métricas

**Comando:**
```bash
kubectl --context o-cloud-1 -n openran-lab exec deploy/oran-du -- python3 -c "
import urllib.request
print(urllib.request.urlopen('http://localhost:8080/metrics', timeout=3).read().decode())
"
```
**Resultado esperado:** texto formato Prometheus — `nf_up`, `nf_requests_total`,
`nf_config_version`, `nf_restart_count`.

**Falar:** "Métricas no formato Prometheus — sem precisar instalar um Prometheus completo para
mostrar o mecanismo."

---

## 7. Alterar configuração

**Comando:**
```bash
kubectl --context o-cloud-1 -n openran-lab exec deploy/oran-du -- python3 -c "
import urllib.request
req = urllib.request.Request('http://localhost:8080/config', data=b'{\"cell_id\": 2}',
  method='PUT', headers={'Content-Type':'application/json'})
print(urllib.request.urlopen(req, timeout=3).read().decode())
"
```
**Resultado esperado:** `"config_version":2` e `"cell_id":2` na resposta.

**Falar:** "Mudança de configuração operacional da O-DU — `cell_id` de 1 para 2 — aplicada e
confirmada em menos de 1 segundo."

---

## 8. Escalar

**Comando:**
```bash
kubectl --context o-cloud-1 -n openran-lab scale deploy/oran-cu --replicas=2
kubectl --context o-cloud-1 -n openran-lab rollout status deploy/oran-cu
```
**Resultado esperado:** `deployment "oran-cu" successfully rolled out`; `get pods` mostra 2
pods `oran-cu-*`.

**Falar:** "De 1 para 2 réplicas do O-CU — o controller do Kubernetes cuida do resto."

---

## 9. Matar pod

**Comando:**
```bash
POD=$(kubectl --context o-cloud-1 -n openran-lab get pods -l app=oran-du -o jsonpath='{.items[0].metadata.name}')
echo "deletando: $POD"
kubectl --context o-cloud-1 -n openran-lab delete pod "$POD"
```
**Resultado esperado:** `pod "<nome>" deleted`.

**Falar:** "Vou simular uma falha, deletando à força o pod da O-DU."

---

## 10. Mostrar recuperação

**Comando:**
```bash
kubectl --context o-cloud-1 -n openran-lab get pods -l app=oran-du
```
**Resultado esperado:** um pod `oran-du-*` **novo** (nome diferente do deletado), `Running`.

**Falar:** "Em poucos segundos o ReplicaSet já recriou o pod. Isto é reconciliação declarativa
do Kubernetes — estado desejado versus estado real — não é healing de uma NF de telecom real,
que envolveria re-registro em interfaces O-RAN e recuperação de sessão."

---

## 11. Remover uma NF

**Comando:**
```bash
mv lab/nephio/openran-cnfs/oran-core-*.yaml /tmp/ 2>/dev/null  # remove do pacote
bash lab/nephio/deploy-cnfs-via-porch.sh                       # republica + kpt live apply (prune)
kubectl --context o-cloud-1 -n openran-lab get deploy,pods -l app=oran-core
```
**Resultado esperado:** `No resources found` — `oran-core` removido.

**Falar:** "Removendo o `oran-core` do pacote e republicando, o `kpt live apply` **poda**
(prune) o recurso que não faz mais parte do estado desejado — terminação via o mesmo mecanismo
declarativo usado para criar, não um `kubectl delete` avulso. Com isso fecho o ciclo completo:
instantiate, configuration, scaling, recovery e termination, todos pelo fluxo real do Nephio."

---

## Encerramento (fora do roteiro cronometrado)

Restaurar o pacote para a próxima demonstração:
```bash
mv /tmp/oran-core-*.yaml lab/nephio/openran-cnfs/
```
