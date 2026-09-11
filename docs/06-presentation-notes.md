# 06 — Notas para a apresentação (demo de 5–8 min)

> Antes de começar: `wsl -d Ubuntu`, e garanta que o lab está de pé:
> `bash scripts/lab-recover.sh` (recupera o mgmt) e, se o `o-cloud-1` não responder,
> `bash scripts/reprovision-ocloud.sh` (leva ~4 min — faça **antes** da apresentação).
> Verificação rápida: `bash scripts/validate-lab.sh` deve dar `PASS=10`.
> Deixe dois terminais abertos: um no `kind-nephio-mgmt`, outro pronto p/ `--context o-cloud-1`.

Tempo-alvo por bloco entre colchetes.

---

## 1. Arquitetura  [45 s]

**Mostrar:** `docs/04-architecture.md` (o diagrama Mermaid).

**Falar:** "O laboratório reproduz a cadeia SMO do O-RAN numa máquina de 16 GB. Um
*Management Cluster* roda o Nephio — Porch, Config Sync, Cluster API — e os operadores
**O2 IMS** e **FOCOM**. A partir de uma *intenção declarativa*, o O2 IMS provisiona um
segundo cluster Kubernetes que, no experimento, **representa o O-Cloud**. Nele rodo um
workload representativo de uma Network Function e demonstro o ciclo de vida."

---

## 2. Management Cluster  [30 s]

**Comando:**
```bash
kubectl config use-context kind-nephio-mgmt
kubectl get nodes
kind get clusters
```
**Saída esperada:** nó `nephio-mgmt-control-plane` `Ready`, `v1.32.0`; `kind get clusters`
lista `nephio-mgmt` e `o-cloud-1`.

**Falar:** "Um cluster kind single-node, dentro do WSL2, é o nosso Management Cluster — o
'cérebro' SMO. Ele não roda nenhuma função de rede."

---

## 3. Componentes do Nephio  [45 s]

**Comando:**
```bash
kubectl get pods -n porch-system -n nephio-system -n config-management-system
kubectl api-resources | grep -E 'porch.kpt.dev|config.porch'
```
**Saída esperada:** `porch-server`, `porch-controllers`, `function-runner`,
`nephio-controller` (2/2), `token-controller`, `config-management-operator`,
`reconciler-manager`, `root-reconciler-mgmt` — todos `Running`. `api-resources` mostra
`packagerevisions`, `packagevariants`, `repositories`.

**Falar:** "O Porch é o servidor de orquestração de pacotes — versiona blueprints KRM. O
`nephio-controller` reconcilia `PackageVariant`s. O Config Sync aplica no cluster o que o
Porch publica no Git."

---

## 4. CRDs do O2 IMS  [45 s]

**Comando:**
```bash
kubectl get crd | grep -E 'o2ims|focom|provisioning.oran'
kubectl get pods -n o2ims -n focom-operator-system
kubectl explain provisioningrequests.spec
kubectl get repository
```
**Saída esperada:** CRDs `provisioningrequests.o2ims.provisioning.oran.org`,
`focomprovisioningrequests`, `oclouds`, `templateinfoes`; pods `o2ims-operator` e
`focom-operator-controller-manager` `Running`; `explain` mostra `templateName`,
`templateVersion`, `templateParameters` (obrigatórios); `get repository` mostra
`catalog-infra-capi`, `mgmt`, `mgmt-staging` `READY=True`.

**Falar:** "Estas são as CRDs da interface O2 IMS no Nephio R6 — ainda PoC do O-RAN WG6.
O `ProvisioningRequest` é o que um SMO externo enviaria para pedir infraestrutura. Ele
precisa de um *template* (um pacote kpt) e de parâmetros. Os três repositórios Porch são o
pré-requisito: um catálogo read-only e dois de deployment no Gitea."

---

## 5. A intenção / request  [60 s]

**Comando:**
```bash
cat manifests/o2-provisioning-request.yaml
kubectl get provisioningrequest o-cloud-1 -o jsonpath='{.status.provisioningStatus}' | jq .
kubectl get provisioningrequest o-cloud-1 -o jsonpath='{.status.provisionedResourceSet}' | jq .
```
**Saída esperada:** o YAML (templateName `nephio-workload-cluster`, clusterName `o-cloud-1`,
clusterProvisioner `capi`); status `provisioningState: fulfilled`,
`provisioningMessage: "Cluster resource created"`; `oCloudNodeClusterId` = um UUID.

**Falar:** "Apliquei este objeto. O `o2ims-operator` validou, criou um `PackageVariant`, o
Porch renderizou e publicou no repositório `mgmt`, o Config Sync trouxe de volta e o
Cluster API materializou um cluster. O status foi de `progressing` para **`fulfilled`** —
essa é a mudança de estado concreta: request → controller → infraestrutura."

**(opcional) mostrar a cadeia:**
```bash
kubectl get packagevariant o-cloud-1
kubectl get packagerevisions | grep o-cloud-1-cloud-1-cluster
kubectl get cluster,machinedeployment -n default
```

---

## 6. O workload cluster (O-Cloud)  [45 s]

**Comando:**
```bash
kubectl get cluster o-cloud-1 -n default          # PHASE Provisioned
docker ps --filter name=o-cloud-1 --format '{{.Names}}\t{{.Image}}\t{{.Status}}'
kubectl --context o-cloud-1 get nodes
```
**Saída esperada:** `Cluster o-cloud-1 ... Provisioned ... v1.31.0`; 3 containers
(`o-cloud-1-<hash>` control-plane, `o-cloud-1-md-0-*` worker, `o-cloud-1-lb`); 2 nós `Ready`.

**Falar:** "Aqui está o O-Cloud: dois nós Kubernetes v1.31, rodando como containers Docker
via o provider CAPD. **Não** foi um `kind create cluster` — foi o `ProvisioningRequest` que
disparou tudo. No experimento ele *representa* um O-Cloud: mesma forma, sem o hardware e o
inventário O2 de um O-Cloud real."

---

## 7. demo-nf  [30 s]

**Comando:**
```bash
kubectl --context o-cloud-1 get deploy,pods,svc -l app=demo-nf
```
**Saída esperada:** `demo-nf 1/1`, 1 pod `Running`, Service ClusterIP.

**Falar:** "Um nginx — **workload representativo de uma Network Function**, não uma NF O-RAN
real. Serve só para exercitar o ciclo de vida."

---

## 8. Escalar 1 → 3  [40 s]

**Comando:**
```bash
kubectl --context o-cloud-1 scale deploy/demo-nf --replicas=3
kubectl --context o-cloud-1 rollout status deploy/demo-nf
kubectl --context o-cloud-1 get pods -l app=demo-nf
```
**Saída esperada:** "successfully rolled out"; 3 pods `Running`.

**Falar:** "Mudo o número desejado de réplicas; o ReplicaSet reconcilia para o estado
desejado. Isto é *Kubernetes lifecycle*."

---

## 9. Deletar um pod  [20 s]

**Comando:**
```bash
POD=$(kubectl --context o-cloud-1 get pods -l app=demo-nf -o jsonpath='{.items[0].metadata.name}')
echo "vou deletar: $POD"
kubectl --context o-cloud-1 delete pod $POD
```
**Saída esperada:** `pod "<nome>" deleted`.

**Falar:** "Simulo uma falha deletando um pod à força."

---

## 10. Recuperação automática  [30 s]

**Comando:**
```bash
kubectl --context o-cloud-1 get pods -l app=demo-nf
kubectl --context o-cloud-1 get events --field-selector reason=SuccessfulCreate --sort-by=.lastTimestamp | tail -3
```
**Saída esperada:** de novo 3 pods `Running` (um com poucos segundos de idade, nome novo);
evento `SuccessfulCreate` recente.

**Falar:** "O Deployment já recriou o pod — voltou a 3/3. Isto é **reconciliação declarativa**
do Kubernetes: o controlador compara desejado × real e corrige. **Não** confundir com
*healing* de uma NF telecom, que envolveria estado de sessão e re-registro em interfaces
O-RAN — isso não está no escopo."

---

## 11. Conclusão  [40 s]

**Falar:** "Demonstrei três camadas distintas e reais: **(1)** o lifecycle do Kubernetes,
**(2)** a orquestração do Nephio via Porch/GitOps e **(3)** a integração O2 IMS — um
`ProvisioningRequest` que se transformou em um cluster O-Cloud, com `status: fulfilled`. O
que é abstração do laboratório: o O-Cloud é um cluster kind com provider Docker, o FOCOM
roda no mesmo cluster, o `demo-nf` é um nginx, e não há inventário O2 nem KPIs O-RAN. O
código e as evidências estão no repositório, e `scripts/validate-lab.sh` reexecuta as
verificações — 10/10 PASS."

---

### Se algo falhar ao vivo
- `o-cloud-1` sem resposta → `bash scripts/reprovision-ocloud.sh` (não dá tempo em 8 min;
  tenha rodado antes). Enquanto isso, mostre `evidence/o2ims/` e `evidence/lifecycle/`.
- mgmt sem resposta → `bash scripts/lab-recover.sh`.
- Fallback total: conduza a apresentação pelos arquivos de `evidence/` (todos timestamped).
