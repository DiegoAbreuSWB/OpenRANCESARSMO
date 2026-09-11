# 01 — Versão do Nephio escolhida (ETAPA 2)

> Pesquisa feita em 2026-09-09 **apenas em fontes oficiais** (nephio.org, docs.nephio.org,
> github.com/nephio-project). Nada de tutoriais de terceiros ou releases antigas.

---

## 1. Versão escolhida

| Item | Valor |
|---|---|
| Release | **Nephio R6 — `v6.0.0`** |
| Data da release | 2026-02-13 (`github.com/nephio-project/nephio`, `prerelease=false`) |
| Catálogo de pacotes | `github.com/nephio-project/catalog`, **branch `v6`** |
| test-infra (sandbox) | `github.com/nephio-project/test-infra`, **branch `R6`** |
| Porch | **v1.5.6** (R6) |
| Kubernetes suportado | **v1.26 – v1.32** (verificado pelo projeto em VMs GCE) |
| K8s usado neste lab | **v1.32.0** (mesma versão do sandbox oficial do R6) |

### Por quê R6
- É a **última release estável** (as anteriores: R5 = 2025-06, R4 = 2025-02).
- R6 é descrita como release de **manutenção/estabilidade e segurança** — bom para reprodutibilidade.
- **R6 adiciona a "O2 IMS REST Provision API"** — exatamente o tema desta atividade (SMO / O2 IMS).
- O `ProvisioningRequest` (O-RAN O2 IMS) já existe como pacote no catálogo `v6`.

---

## 2. Requisitos (oficiais) vs. nossa máquina

Fonte: `test-infra@R6 … roles/bootstrap/defaults/main.yml` + `.../tasks/prechecks.yml`.

| Perfil | vCPU | RAM | Disco | Cabe aqui? |
|---|---|---|---|---|
| **sandbox** (mínimo, o playbook faz `assert`) | **6** | **6 GB** | ~50 GB | ✅ WSL2 = 6 vCPU / 10 GB / 950 GB |
| end_to_end (com free5gc/OAI, multi-cluster) | 16 | 32 GB | 200 GB | ❌ máquina de 16 GB |
| Kernel mínimo | Linux ≥ 5.0 (para o módulo `gtp5g`) | — | — | ✅ 6.18 (mas não usaremos gtp5g) |

> O `prechecks.yml` **falha a instalação** se a RAM < 6 GB ou vCPU < 6. Por isso o `.wslconfig`
> foi fixado em `memory=10GB` / `processors=6`.

---

## 3. Método de instalação

### 3.1 O que a documentação oferece

`docs.nephio.org/docs/guides/install-guides/`:

1. **Single VM (kind)** — recomendado p/ sandbox/demo. Script Ansible `test-infra/e2e/provision/init.sh`.
2. Single VM (K8s pré-instalado).
3. GCE / VM pré-provisionada (vSphere, OpenStack, AWS, Azure).
4. **BYOC** ("bring your own cluster") — a doc **assume que não há um guia genérico**; manda usar os guias "opinativos".

### 3.2 Por que NÃO usar o instalador de sandbox completo

O `init.sh` / `install_sandbox.sh` do R6 roda um playbook Ansible que, além do management
cluster, provisiona **clusters edge + regional** e registra repositórios de **free5gc, OAI, RIC,
UERANSIM**. Componentes do bootstrap+install do sandbox:

```
distros/sandbox/cert-manager
distros/sandbox/gitea
nephio/optional/resource-backend
distros/sandbox/metallb  + metallb-sandbox-config
infra/capi/cluster-capi  + cluster-capi-infrastructure-docker  + cluster-capi-kind-docker-templates
nephio/core/porch
nephio/core/nephio-operator
nephio/core/configsync
nephio/optional/network-config
nephio/optional/fluxcd
nephio/optional/argo-cd-full
nephio/optional/webui        (opcional)
```

Isso é pesado demais (Argo CD full + Flux + WebUI + resource-backend + metallb + multi-cluster)
para 16 GB de RAM total.

### 3.3 O que faremos: instalação MÍNIMA por pacotes kpt (abordagem BYOC manual)

Instalar, **um a um e validando**, só o necessário para demonstrar SMO/O2/O-Cloud/lifecycle,
sobre o **único** cluster kind `nephio-mgmt` já criado:

| Ordem | Pacote (`catalog@v6`) | Para quê | Essencial? |
|---|---|---|---|
| 1 | `distros/sandbox/cert-manager` | webhooks do Porch/CAPI | sim |
| 2 | `nephio/core/porch` | **Package Orchestration** (o "Nephio" do diagrama) | sim |
| 3 | `distros/sandbox/gitea` | repositórios git in-cluster para o Porch | sim (ou git externo) |
| 4 | `nephio/core/nephio-operator` | controllers Nephio (PackageVariant etc.) | sim |
| 5 | `nephio/core/configsync` | GitOps p/ o workload cluster | sim |
| 6 | `infra/capi/cluster-capi` | Cluster API core | só p/ "O2 cria o cluster" (fluxo A) |
| 7 | `infra/capi/cluster-capi-infrastructure-docker` | provider **CAPD** (cria clusters em Docker) | idem |
| 8 | `infra/capi/cluster-capi-kind-docker-templates` | templates de cluster kind p/ CAPD | idem |
| 9 | `nephio/optional/focom-operator` | **FOCOM** (lado SMO do O-RAN) | sim (O2 IMS) |
| 10 | `nephio/optional/o2ims` | **operador O2 IMS + CRD `ProvisioningRequest`** | sim (O2 IMS) |

Adiado / talvez necessário conforme erros aparecerem: `nephio/optional/resource-backend`
(IPAM/VLAN — normalmente só p/ NFs tipo free5gc), `distros/sandbox/metallb` (LoadBalancer;
no kind dá p/ contornar com NodePort/port-forward), `nephio/core/workload-crds`.

> Regra: **não** adicionar pacote "por via das dúvidas". Só quando um componente essencial
> reclamar de CRD/depend. ausente (a descobrir no cluster, ETAPA 3/4).

---

## 4. O2 IMS — o que existe de fato no R6 (esquema real, do catálogo `v6`)

Fonte: `catalog@v6/nephio/optional/o2ims/**` e `.../focom-operator/**`.

### 4.1 Operador

| Item | Valor |
|---|---|
| Pacote | `nephio/optional/o2ims` |
| Deployment | `o2ims-operator` (ns **`o2ims`**), `replicas: 1`, `strategy: Recreate` |
| Imagem | `docker.io/nephio/o2ims-operator:v6.0.0` |
| Recursos | `requests = limits = 256Mi / 100m` (leve) |
| Env | `UPSTREAM_PKG_REPO=catalog-infra-capi`, `KUBERNETES_BASE_URL=https://kubernetes.default.svc` |
| Código-fonte | `github.com/nephio-project/nephio/tree/main/operators/o2ims-operator` |
| Complemento | `nephio/optional/focom-operator` (bundle do FOCOM Operator) |

O README do pacote diz textualmente: *"This operator implements O-RAN O2 IMS cluster
provisioning for K8s based cloud management. The CRD used by the operator is a work
in-progress in O-RAN standards. It is part of `O-RAN.WG6.TS.O-CLOUD-IM.0-R004-v03.00` …
provide feedback to the standardization bodies with a PoC."*
→ **É uma PoC do O2 IMS, não uma implementação O-RAN certificada.** Importante para o relatório.

### 4.2 CRD `ProvisioningRequest` (esquema exato — NÃO inventado)

```
CRD name : provisioningrequests.o2ims.provisioning.oran.org
group    : o2ims.provisioning.oran.org
kind     : ProvisioningRequest        (plural: provisioningrequests)
version  : v1alpha1  (served + storage)
scope    : Cluster                    (NÃO é namespaced)
subresources: status
```

`spec` (campos **obrigatórios**: `templateName`, `templateVersion`, `templateParameters`):

| Campo | Tipo | Obrigatório | Descrição (da CRD) |
|---|---|---|---|
| `spec.name` | string | não | nome legível, não único, descritivo |
| `spec.description` | string | não | descrição da requisição |
| `spec.templateName` | string | **sim** | template que o SMO quer usar p/ provisionar |
| `spec.templateVersion` | string | **sim** | versão do template |
| `spec.templateParameters` | object (livre, `x-kubernetes-preserve-unknown-fields`) | **sim** | parâmetros do template (schema definido pelo template) |

`status`:

| Campo | Tipo | Observação |
|---|---|---|
| `status.provisionedResourceSet.oCloudNodeClusterId` | string | id do NodeCluster do O-Cloud provisionado |
| `status.provisionedResourceSet.oCloudInfrastructureResourceIds[]` | []string | ids de recursos de infra |
| `status.provisioningStatus.provisioningState` | enum | **`progressing` \| `fulfilled` \| `failed` \| `deleting`** |
| `status.provisioningStatus.provisioningMessage` | string | detalhe do estado atual |
| `status.provisioningStatus.provisioningUpdateTime` | date-time | |
| `status.extensions` | object (livre) | |

> Este é o objeto que representa a **intenção / request** do fluxo O2 IMS. O que ele efetivamente
> dispara (CAPI/CAPD → cluster) e até onde funciona no ambiente local será verificado nas
> ETAPAS 4, 6 e 7 — **sem afirmar que "o O2 provisionou" antes de ver a mudança de estado**.

---

## 5. Ferramentas e versões (fixadas neste lab)

| Ferramenta | Versão | Observação de compatibilidade |
|---|---|---|
| kind | **v0.27.0** | par estável do node image `kindest/node:v1.32.0`. `kind v0.33.0` (o "latest") **só** suporta K8s 1.34–1.37 → foi **descartado**. |
| node image | **kindest/node:v1.32.0** | igual ao sandbox oficial do R6 |
| kubectl | **v1.32.3** | dentro do skew ±1 do apiserver 1.32 |
| kpt | **v1.0.0** (GA) | BYOC pede ≥ v1.0.0-beta.43 → OK |
| helm | **v3.19.0** | mantido na linha 3.x; Helm 4 (`v4.2.4`, "latest") evitado por compatibilidade de charts |
| porchctl | v1.6.2 | disponível se necessário |
| cluster-api / clusterctl | v1.14.2 | usado via pacote kpt, não via clusterctl |
| Docker Engine | 29.8.0 (CE, dentro do WSL2) | runtime de contêiner do kind/CAPD |

---

## 6. Incompatibilidades / riscos encontrados

| # | Item | Situação / mitigação |
|---|---|---|
| 1 | `kind` "latest" (v0.33.0) não roda K8s 1.32 | Fixado **kind v0.27.0**. |
| 2 | RAM total (16 GB) < requisito end-to-end (32 GB) | Só o perfil **mínimo** por pacotes kpt; sem free5gc/OAI/RIC/multi-cluster. |
| 3 | WSL2 derruba a VM ~60 s após fechar o último terminal → cluster kind cai e etcd reinicia sujo | `vmIdleTimeout=21600000` no `.wslconfig` + `scripts/lab-keepalive.sh` + `scripts/mgmt-cluster-recover.sh`. Confirmado estável após o ajuste. |
| 4 | O2 IMS / FOCOM **não** entram no sandbox padrão | Instalação manual dos pacotes `nephio/optional/{o2ims,focom-operator}` (ETAPA 3/4). |
| 5 | `o2ims-operator` espera um Porch repo `catalog-infra-capi` (env `UPSTREAM_PKG_REPO`) | Registrar esse repositório no Porch antes de testar o fluxo (ETAPA 7). |
| 6 | CRD `ProvisioningRequest` é **work-in-progress / PoC** O-RAN | Documentar como PoC no relatório; não apresentar como O-RAN certificado. |
| 7 | Helm 4 é o "latest" mas quebra compat. de charts | Mantido Helm 3.19. |

---

## 7. Documentação utilizada (fontes oficiais)

- `https://docs.nephio.org/docs/guides/install-guides/` — métodos de instalação, requisitos de hardware.
- `https://docs.nephio.org/docs/guides/install-guides/install-on-byoc/` — pré-requisitos (kpt/porchctl/docker), abordagem "sem guia genérico".
- `https://docs.nephio.org/docs/release-notes/r6/` — R6: "O2 IMS REST Provision API added", Porch v1.5.6, K8s v1.26–v1.32, Go ≥ 1.25.6.
- `github.com/nephio-project/nephio` — releases (`v6.0.0`, 2026-02-13), `operators/o2ims-operator`.
- `github.com/nephio-project/catalog` @ branch `v6` — árvore de pacotes; `nephio/core/*`, `nephio/optional/o2ims`, `nephio/optional/focom-operator`, `infra/capi/*`, `distros/sandbox/*`.
- `github.com/nephio-project/test-infra` @ branch `R6` — `e2e/provision/{init.sh,install_sandbox.sh}`, `playbooks/roles/{bootstrap,install}/defaults/main.yml`, `.../tasks/{create-mgmt,apply-pkgs,prechecks}.yml`.
- `github.com/kubernetes-sigs/kind` releases — matriz de suporte de node images (v0.33.0 → K8s 1.34–1.37).

---

## 8. Tag / commit de referência

| Repositório | Ref usada |
|---|---|
| nephio-project/nephio | tag `v6.0.0` |
| nephio-project/catalog | branch `v6` (não há tag `v6.0.0` de repo inteiro; pacotes versionam individualmente) |
| nephio-project/test-infra | branch `R6` |

*(os commits exatos serão registrados em `docs/02-nephio-installation.md` no momento do `kpt pkg get`.)*
