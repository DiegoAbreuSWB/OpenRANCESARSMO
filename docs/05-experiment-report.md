# 05 — Relatório do experimento (SMO / O2 IMS / O-Cloud / lifecycle com Nephio)

> Atividade acadêmica — Curso CESAR / SMO.
> Ambiente: máquina local Windows 11 + WSL2, 16 GB RAM.
> Execução: 2026-09-09 a 2026-09-10.
> Todas as saídas de comando citadas estão em [`evidence/`](../evidence/).

---

## 1. Objetivo

Montar, numa única máquina de 16 GB, um laboratório **funcional e reproduzível** que
demonstre a cadeia:

```
Usuário/SMO ──intent──► Management Cluster (Nephio) ──O2 IMS──► Workload Cluster ("O-Cloud") ──► workload representativo (demo-nf) ──► lifecycle
```

com **evidências reais** de clusters, controllers, CRDs, eventos, pods, scaling,
reconciliação e remoção — sem Free5GC/OAI, sem múltiplos clusters edge, sem VMs pesadas.

---

## 2. Ambiente

| Item | Valor |
|---|---|
| Host | Windows 11 Enterprise 24H2 (build 26100), i7-1255U (10c/12t), 16 GB RAM |
| Linux | **WSL2 + Ubuntu 26.04 LTS** (kernel 6.18), systemd on |
| `.wslconfig` | `memory=10GB`, `processors=6`, `swap=4GB`, `autoMemoryReclaim=gradual`, `vmIdleTimeout=21600000` |
| Runtime | **Docker Engine 29.8.0 (CE)** nativo dentro do WSL2 (sem Docker Desktop) |
| CLIs | kubectl v1.32.3 · **kind v0.27.0** · helm v3.19.0 · kpt v1.0.0 |
| Ajustes de host | `fs.inotify.max_user_{watches,instances}` elevados; delegação de `cpuset` no cgroup v2 |

Detalhes: [`docs/00-environment-audit.md`](00-environment-audit.md), [`docs/00b-host-setup.md`](00b-host-setup.md).
Premissas do enunciado que **não** se confirmaram: Docker **não** estava instalado; WSL2 **não** estava instalado; a conta de domínio **não** era admin local (resolvido com elevação pontual).

---

## 3. Arquitetura

Diagrama e explicação completos em [`docs/04-architecture.md`](04-architecture.md). Resumo:

- **Management Cluster** `nephio-mgmt` — kind single-node, K8s **v1.32.0**. Hospeda toda a
  automação: Porch, nephio-controller, Gitea, Config Sync, Cluster API + provider Docker (CAPD),
  operadores **O2 IMS** e **FOCOM**, resource-backend, MetalLB, cert-manager.
- **Workload Cluster** `o-cloud-1` — kind 2 nós (control-plane + worker), K8s **v1.31.0**,
  criado pelo Cluster API + CAPD a partir de um `ProvisioningRequest`.
- **O-Cloud** — abstração acadêmica: `o-cloud-1` *representa* o O-Cloud (mesma forma — cluster
  provisionado sob demanda e registrado no SMO — sem HW, rede de transporte, inventário O2 nem
  certificação O-RAN).
- **demo-nf** — nginx; *workload representativo de uma Network Function*, não uma NF O-RAN real.

---

## 4. Instalação do Nephio

**Release: Nephio R6 (`v6.0.0`)** — catálogo `github.com/nephio-project/catalog@v6`
(commit `3b548f1c`). Justificativa e requisitos em [`docs/01-nephio-version.md`](01-nephio-version.md).

Método: **pacotes `kpt` aplicados um a um** (script [`scripts/03-nephio-min.sh`](../scripts/03-nephio-min.sh)),
**não** o instalador Ansible do sandbox (que traz Argo CD full + Flux + WebUI + multi-cluster,
inviável em 16 GB). Pacotes: cert-manager → **Porch** → Gitea → **nephio-operator** → Config Sync
→ **Cluster API + CAPD + ClusterClass docker** → **FOCOM** → **O2 IMS** → MetalLB → resource-backend.

**Resultado:** 34/34 pods `Running` no `nephio-mgmt`, 76 CRDs. Log final:
[`evidence/nephio-install/20260910-093127_etapa3-final-state.txt`](../evidence/nephio-install/).

### Bugs do upstream corrigidos durante a instalação

| # | Problema | Correção | Script |
|---|---|---|---|
| 1 | `gcr.io/kubebuilder/kube-rbac-proxy:v0.8.0` → **HTTP 404** (Google desativou o registry). Afeta nephio-controller, token-controller, resource-backend. | Trocar para `quay.io/brancz/kube-rbac-proxy:v0.8.0` (mesma versão, registry vivo). | [`patch-nephio-operator-rbacproxy.sh`](../scripts/patch-nephio-operator-rbacproxy.sh) |
| 2 | CAPD em `CrashLoopBackOff`: *"too many open files"* | Elevar `fs.inotify.max_user_{watches=1048576,instances=8192}` (known-issue do kind) | [`fix-inotify-limits.sh`](../scripts/fix-inotify-limits.sh) |
| 3 | `nephio-controller` em `CrashLoopBackOff` (cache-sync de `Endpoint`/`VLANIndex`; Gitea inacessível) | Instalar `resource-backend` (dá os CRDs) + `metallb` (dá o IP fixo `172.18.0.200` do Gitea) — ambos fazem parte do bootstrap oficial | (itens 11–12 de `03-nephio-min.sh`) |

Detalhes: [`docs/02-nephio-installation.md`](02-nephio-installation.md).

---

## 5. O2 IMS

Descoberta completa (schema real via `kubectl explain` + CRD + RBAC + código-fonte) em
[`docs/03-o2ims-discovery.md`](03-o2ims-discovery.md). Pontos:

- **CRDs instalados:** `provisioningrequests.o2ims.provisioning.oran.org` (cluster-scoped),
  `focomprovisioningrequests` / `oclouds` / `templateinfoes` (`focom.nephio.org` / `provisioning.oran.org`).
- **`o2ims-operator`** (kopf/Python, `docker.io/nephio/o2ims-operator:v6.0.0`) — observa
  `ProvisioningRequest`, cria um **`PackageVariant`** (`catalog-infra-capi/<templateName>` →
  `mgmt/<clusterName>`) e observa o `Cluster` CAPI resultante; grava
  `status.provisioningState`.
- **`focom-operator`** (Go) — lado SMO: traduz `FocomProvisioningRequest` + `OCloud` + `Secret`
  em um `ProvisioningRequest` no cluster alvo.
- **Cadeia:** `ProvisioningRequest → PackageVariant → PackageRevision (git "mgmt") → RootSync →
  CAPI Cluster (class=docker) → CAPD → containers`.
- **Pré-requisito que faltava** e foi criado na ETAPA 6: repositórios Porch
  `catalog-infra-capi` (read-only) + `mgmt` + `mgmt-staging` (deployment, no Gitea) + `RootSync mgmt`.
  Logs: [`evidence/o2ims/20260910-1307*`](../evidence/o2ims/), [`…1312_etapa6_rootsync.txt`](../evidence/o2ims/).

> **Ressalva (obrigatória):** o README do pacote diz que a CRD `ProvisioningRequest` é
> *"work-in-progress in O-RAN standards … a PoC"* (base `O-RAN.WG6.TS.O-CLOUD-IM.0-R004-v03.00`).
> O `status…oCloudNodeClusterId` é um **UUID aleatório** gerado pelo operador, não um id de
> inventário O2 real.

---

## 6. Provisionamento do O-Cloud

**Objeto aplicado** ([`manifests/o2-provisioning-request.yaml`](../manifests/o2-provisioning-request.yaml)):

```yaml
apiVersion: o2ims.provisioning.oran.org/v1alpha1
kind: ProvisioningRequest
metadata: { name: o-cloud-1 }
spec:
  templateName: nephio-workload-cluster
  templateVersion: main          # (v3.0.0 quebra: referencia gcr.io/kpt-fn/* desativado)
  templateParameters:
    clusterName: o-cloud-1
    clusterProvisioner: capi
    # labels OMITIDO: o operador injetaria gcr.io/kpt-fn/set-labels:v0.2.0 (registry morto)
```

**Cadeia observada** (evidência: [`evidence/o2ims/`](../evidence/o2ims/), [`evidence/workload-cluster/`](../evidence/workload-cluster/)):

| Elo | Evidência |
|---|---|
| `ProvisioningRequest` aplicado | `kubectl apply` OK |
| `o2ims-operator` reage | kopf: `Handler 'create_fn' succeeded. 1 succeeded; 0 failed` |
| cria `PackageVariant o-cloud-1` | `Ready=True :: successfully ensured downstream package variant` |
| Porch publica `PackageRevision`s | `mgmt.o-cloud-1-cloud-1-cluster.packagevariant-1` + kindnet/multus/vlanindex/local-path (`LIFECYCLE: Published`) |
| RootSync aplica no cluster | nasce `Cluster o-cloud-1` (`CLUSTERCLASS: docker`) |
| CAPI + CAPD provisionam | `Cluster PHASE: Provisioned` · KCP `INITIALIZED=true, API SERVER AVAILABLE=true, READY=1` · MachineDeployment `Running 1/1` · 2 Machines `Running` (`docker:////…`) |
| containers Docker reais | `o-cloud-1-<hash>` (control-plane, `kindest/node:v1.31.0`), `o-cloud-1-md-0-*` (worker), `o-cloud-1-lb` (haproxy) |
| **`ProvisioningRequest.status`** | **`provisioningState: fulfilled`**, `oCloudNodeClusterId`, `oCloudInfrastructureResourceIds` |
| O-Cloud operacional | **2 nós `Ready`** (v1.31.0); etcd/apiserver/CM/scheduler + kindnet + multus + kube-proxy + coredns + local-path `Running` |
| visão Nephio | `WorkloadCluster o-cloud-1` (`infra.nephio.org`) |

> **Este é o "resultado ideal"** do enunciado (§23): o O-Cloud foi **criado pelo fluxo O2 IMS**,
> não por um `kind create cluster` manual. O provider é Docker (CAPD) — provisionamento
> declarativo de infra via Cluster API, sem IaaS pesado.

### Correções necessárias no O-Cloud (pós-criação)

| Problema | Causa | Correção | Script |
|---|---|---|---|
| Pods do o-cloud-1 presos em `ContainerCreating` (`plugin "loopback" not found`) | `kindest/node:v1.31.0` (CAPD) não traz os CNI "standard" em `/opt/cni/bin` | copiar `containernetworking/plugins` para os nós | [`fix-ocloud-cni-plugins.sh`](../scripts/fix-ocloud-cni-plugins.sh) |
| o-cloud-1 **não volta** após restart da VM do WSL2 (kubelet: *missing controllers: cpuset*; IPs dos containers embaralham; apiserver não sobe) | cgroup v2 do WSL2 não delega `cpuset`; certificados presos ao IP antigo | (a) serviço systemd que delega `cpuset` a cada boot; (b) **re-provisionar** o o-cloud-1 | [`fix-wsl-cgroup-cpuset.sh`](../scripts/fix-wsl-cgroup-cpuset.sh), [`reprovision-ocloud.sh`](../scripts/reprovision-ocloud.sh) |

---

## 7. Deployment da função representativa

[`manifests/demo-nf.yaml`](../manifests/demo-nf.yaml) — `Deployment` + `Service`, `nginx:1.27-alpine`,
`requests 32Mi/25m`, `limits 128Mi/200m`, env `VERSION=v1`. Aplicado com
`kubectl --context o-cloud-1 apply -f`. Resultado: `demo-nf 1/1 Running`, Service ClusterIP,
**teste HTTP interno = 200** ([`evidence/lifecycle/20260910-133054_etapa9_deploy.txt`](../evidence/lifecycle/)).

> **`demo-nf` NÃO representa uma função O-RAN real.** É um nginx usado apenas para demonstrar
> mecanismos de lifecycle e orchestration. Sem planos de controle/usuário, interfaces O-RAN
> (E1/F1/E2/N2/N3), dependências de kernel (SCTP/GTP-U/DPDK) nem operador dedicado.

Observação: o `o-cloud-1` aplica **Pod Security Admission** (`enforce: baseline`, `warn: restricted`)
— daí o *Warning* de `restricted` no apply; o pod é admitido e roda normalmente.

---

## 8. Lifecycle management

Script [`scripts/10-lifecycle.sh`](../scripts/10-lifecycle.sh). Evidências em [`evidence/lifecycle/`](../evidence/lifecycle/) (timestamped).

| Fase | Ação | Resultado observado |
|---|---|---|
| **A · Instantiate** | `apply -f demo-nf.yaml` | `demo-nf 1/1`, `spec.replicas=1` |
| **B · Scale** | `scale --replicas=3` | rollout → `3/3`, `desejadas=3 prontas=3` |
| **C · Update** | `set env VERSION=v2` | **revision 1 → 2**; rolling update: RS `766b7dd5cb`→0, `7cbff6c797`→3; `rollout history` mostra rev 1 e 2 |
| **D · Recover** | `kubectl delete pod <x>` | ReplicaSet recria em ~5 s → volta a `3/3`; pod antigo **ausente**; evento `SuccessfulCreate` |
| **E · Terminate** | `kubectl delete -f demo-nf.yaml` | `deployment/service/pods` → `No resources found` |

`scripts/validate-lab.sh` reexecuta A/B/D/E automaticamente: **PASS=10 FAIL=0 SKIP=0**
([`evidence/20260910-150942_validate-lab.txt`](../evidence/)).

---

## 9. Monitoramento

- **Recursos** ([`scripts/resource-usage.sh`](../scripts/resource-usage.sh) → [`evidence/resources/`](../evidence/resources/)):
  ao final, no WSL: `nephio-mgmt` ≈ 3,7 GiB · `o-cloud-1` CP ≈ 1,0 GiB / worker ≈ 0,4 GiB / lb ≈ 22 MiB;
  `free -h` → ~3,7 GiB usados, ~6 GiB *available* (cache recuperável), swap ~0.
  No Windows: `vmmemWSL` ≈ 3,2 GiB; RAM livre chegou a ~2,9 GiB (ponto de atenção).
- **Eventos / status:** `kubectl get events`, `kubectl describe`, `kubectl rollout status/history`,
  logs de `o2ims-operator` / `nephio-controller` / `capd-controller-manager` — capturados nas
  evidências de cada etapa.
- **CRDs / API:** `kubectl get crd` (76), `kubectl api-resources | grep -Ei 'porch|nephio|o2ims|focom'`.
- **Clusters:** `kind get clusters` → `nephio-mgmt`, `o-cloud-1`; `kubectl config get-contexts`.

---

## 10. Resultados

| Objetivo do enunciado | Status |
|---|---|
| 1. Kubernetes local leve | ✅ kind em WSL2, single-node mgmt |
| 2. Nephio no Management Cluster | ✅ R6 mínimo, 34/34 pods |
| 3. Componentes O2 IMS | ✅ `o2ims-operator` + `focom-operator` + CRDs + repos Porch |
| 4. Solicitação declarativa de provisionamento | ✅ `ProvisioningRequest` (`o2ims.provisioning.oran.org`) |
| 5. Criar/gerenciar workload cluster | ✅ **criado pelo O2 IMS** via CAPI/CAPD (não `kind create` manual) |
| 6. Tratar como O-Cloud (acadêmico) | ✅ documentado como representação |
| 7. Implantar workload simples | ✅ `demo-nf`, HTTP 200 |
| 8. Lifecycle (instantiate/scale/update/recover/terminate) | ✅ os 5, com evidência |
| 9. Eventos, status, reconciliação | ✅ capturados |
| 10. Evidências para apresentação | ✅ `evidence/` + `docs/06-presentation-notes.md` |

**Resultado mínimo aceitável (§22): atingido.** **Resultado ideal (§23): atingido**
(Intent → O2 IMS → Nephio → Workload Cluster "O-Cloud" → demo-nf → lifecycle, com
`provisioningState: fulfilled`).

---

## 11. Limitações

1. **PoC, não O-RAN certificado.** A CRD `ProvisioningRequest` é rascunho O-RAN WG6; o
   `oCloudNodeClusterId` é um UUID gerado localmente.
2. **O-Cloud = cluster kind.** Sem hardware, rede de transporte, particionamento de recursos,
   inventário O2 (IMS/DMS) nem interfaces O1/O2 reais. Provider de infra = **Docker (CAPD)**,
   não OpenStack/metal/cloud.
3. **FOCOM no mesmo cluster.** O fluxo canônico usa um cluster SMO separado com `OCloud` +
   `Secret` (kubeconfig do O-Cloud) + `FocomProvisioningRequest`. Aqui foi usado o caminho
   **direto** (`ProvisioningRequest` no próprio management cluster) por limite de RAM.
4. **`demo-nf` não é NF.** É nginx; exercita só o *Kubernetes lifecycle*.
5. **Fragilidade a restart da VM do WSL2.** O `nephio-mgmt` recupera sozinho
   ([`lab-recover.sh`](../scripts/lab-recover.sh)); o `o-cloud-1` (CAPD) **não** — precisa ser
   **re-provisionado** ([`reprovision-ocloud.sh`](../scripts/reprovision-ocloud.sh)). Causas:
   cgroup v2 sem `cpuset` delegado e embaralhamento de IPs dos containers.
6. **3 bugs do upstream R6** exigiram patch (registry `gcr.io/kpt-fn` e `gcr.io/kubebuilder`
   desativados; `templateVersion: v3.0.0` quebrado; `labels` no `ProvisioningRequest` quebrado).
7. **Sem métricas.** `metrics-server` não instalado (fora do escopo); monitoramento via
   `events`/`describe`/`docker stats`.
8. **Escala.** Um único management cluster e um único O-Cloud; sem edge/regional/core, sem RIC,
   sem Free5GC/OAI.

---

## 12. Conclusão

**O Nephio conseguiu atuar como plataforma de automação/orchestration?**
Sim. Porch versionou e renderizou pacotes KRM; o `nephio-controller` (PackageVariant/Approval/
Repository) e o Config Sync propagaram, via Git, a configuração até o cluster; o Cluster API +
CAPD materializaram a infraestrutura. Foi orquestração declarativa de ponta a ponta, observável
por CRDs e eventos.

**Foi possível demonstrar integração O2 IMS?**
Sim, no nível de PoC do R6. Um `ProvisioningRequest` (`o2ims.provisioning.oran.org`) foi
reconciliado pelo `o2ims-operator`, que produziu uma **mudança de estado concreta**
(`PackageVariant` → `PackageRevision` → `Cluster`), e o `status.provisioningState` evoluiu
`progressing → fulfilled`. Não é uma implementação O-RAN certificada, e a federação FOCOM
(cluster SMO separado + `OCloud`/`Secret`) não foi exercitada.

**Foi possível provisionar ou gerenciar o O-Cloud?**
Sim — **provisionar**: o `o-cloud-1` (2 nós, K8s v1.31) foi **criado pelo fluxo O2 IMS**, não
manualmente. **Gerenciar**: o Management Cluster o enxerga via `Cluster`/`Machine` (CAPI),
`DockerMachine` (CAPD) e `WorkloadCluster` (Nephio). Limitação: o O-Cloud não sobrevive a
restart da VM e precisa ser re-provisionado.

**Foi possível demonstrar lifecycle?**
Sim, os cinco (instantiate, scale, update, recover, terminate), com evidência timestamped e
validação automática (`validate-lab.sh`: 10/10 PASS).

**Quais partes são O-RAN reais?**
- A **semântica** das CRDs O2 IMS/FOCOM (`ProvisioningRequest`, `FocomProvisioningRequest`,
  `OCloud`, `TemplateInfo`) e o modelo de fluxo SMO → O2 → O-Cloud, tal como propostos pelo
  Nephio R6 / O-RAN WG6 (em rascunho).
- O uso de **Cluster API** como mecanismo de provisionamento de "NodeCluster" do O-Cloud.

**Quais partes são abstrações do laboratório?**
- O **O-Cloud** = cluster kind; provider = **Docker/CAPD** (não IaaS real).
- **FOCOM** rodando no mesmo cluster (sem federação real).
- `oCloudNodeClusterId` = UUID local.
- **`demo-nf`** = nginx (workload representativo, não NF).
- GitOps = 1 repo Gitea local com auto-approve; sem multirregião, sem políticas.
- Observabilidade = `kubectl`/`docker stats` (sem coleta de KPI O1/O2, sem rApps/xApps).

**Distinção final entre os quatro "ciclos de vida"** (detalhe em `docs/04-architecture.md` §4):
o laboratório demonstrou de fato **(1) Kubernetes lifecycle**, **(2) Nephio orchestration** e
**(3) O2 IMS** (provisionamento de O-Cloud). **(4) O-RAN NF lifecycle** (onboarding/healing/
scaling de funções O-RAN guiado por KPIs e interfaces O-RAN) **não** foi implementado — apenas
nomeado, para deixar claro o limite do escopo.
