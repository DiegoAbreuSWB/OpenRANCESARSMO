# 03 — Descoberta do O2 IMS realmente instalado (ETAPA 4)

> Tudo abaixo foi extraído do **cluster em execução** (`kubectl explain`, `kubectl get crd -o yaml`,
> `kubectl get clusterrole -o yaml`, logs dos operadores) e do **código-fonte oficial**
> (`nephio-project/nephio` @ `v6.0.0`, `nephio-project/catalog` @ `v6`).
> Evidência bruta: [`evidence/o2ims/20260910-122847_o2ims-discovery.txt`](../evidence/o2ims/),
> [`…_raw_o2ims-operator-source.txt`](../evidence/o2ims/), [`…_raw_porch-repo-packages.txt`](../evidence/o2ims/).
> **Nada foi aplicado.** Só leitura.

---

## 1. CRDs relacionados a O2 / O-Cloud / provisionamento (presentes no cluster)

| CRD | Grupo/Versão | Escopo | `status`? | Pacote de origem |
|---|---|---|---|---|
| **`provisioningrequests`** | `o2ims.provisioning.oran.org/v1alpha1` | **Cluster** | sim | `nephio/optional/o2ims` |
| **`focomprovisioningrequests`** | `focom.nephio.org/v1alpha1` | Namespaced | sim | `nephio/optional/focom-operator` |
| **`oclouds`** | `focom.nephio.org/v1alpha1` | Namespaced | sim | `nephio/optional/focom-operator` |
| **`templateinfoes`** | `provisioning.oran.org/v1alpha1` | Namespaced | sim | `nephio/optional/focom-operator` |
| `workloadclusters` | `infra.nephio.org/v1alpha1` | Namespaced | sim | `nephio/core/nephio-operator` |
| `clustercontexts` | `infra.nephio.org/v1alpha1` | Namespaced | sim | `nephio/core/nephio-operator` |
| `clusters` + `dockerclusters` + `dockermachinetemplates` … | `cluster.x-k8s.io` / `infrastructure.cluster.x-k8s.io` `/v1beta1` | Namespaced | sim | `infra/capi/*` |

Nenhuma instância de nenhum desses CRDs existe hoje (cluster limpo).

---

## 2. Schema REAL de cada CRD (campos, obrigatoriedade, enums)

### 2.1 `ProvisioningRequest` (`o2ims.provisioning.oran.org/v1alpha1`) — **cluster-scoped**

Este é o objeto da **interface O2 IMS** (o que um SMO externo instanciaria).

| Campo | Tipo | Obrigatório |
|---|---|---|
| `spec.templateName` | string | **sim** |
| `spec.templateVersion` | string | **sim** |
| `spec.templateParameters` | object (livre, `x-kubernetes-preserve-unknown-fields`) | **sim** |
| `spec.name` | string | não (nome legível) |
| `spec.description` | string | não |
| `status.provisioningStatus.provisioningState` | enum: **`progressing` / `fulfilled` / `failed` / `deleting`** | (observado) |
| `status.provisioningStatus.provisioningMessage` | string | (observado) |
| `status.provisionedResourceSet.oCloudNodeClusterId` | string | (observado) |
| `status.provisionedResourceSet.oCloudInfrastructureResourceIds[]` | []string | (observado) |
| `status.extensions` | object livre | (observado) |

`metadata.name` = *provisioningItemId* (id único que o SMO usa para referenciar tudo o que a request provisionou).

Campos que o **operador espera dentro de `spec.templateParameters`** (do código, não do CRD):
`clusterName` (**obrigatório**), `clusterProvisioner` (só `capi` é tratado), `labels` (map), `creationTimeout`.

### 2.2 `FocomProvisioningRequest` (`focom.nephio.org/v1alpha1`) — namespaced

O objeto do **lado SMO** (O-RAN FOCOM). Igual ao ProvisioningRequest **+** referência ao O-Cloud alvo:

| Campo | Tipo | Obrigatório |
|---|---|---|
| `spec.oCloudId` | string | **sim** |
| `spec.oCloudNamespace` | string | **sim** |
| `spec.templateName` / `templateVersion` / `templateParameters` | — | **sim** |
| `spec.name` / `spec.description` | string | não |
| `status.phase` / `status.message` / `status.remoteName` / `status.lastUpdated` | — | (observado) |

`status.remoteName` = "nome do recurso remoto no cluster alvo" → ou seja, o `ProvisioningRequest` que o FOCOM cria no O-Cloud.

### 2.3 `OCloud` (`focom.nephio.org/v1alpha1`) — namespaced

Registro do O-Cloud no SMO. **Só um ponteiro para um Secret** com endpoint+credenciais O2 IMS:

```
spec.o2imsSecret.secretRef.name       (obrigatório)
spec.o2imsSecret.secretRef.namespace  (obrigatório)
```
Na prática (exercício oficial), esse Secret é o **kubeconfig do cluster O-Cloud**.

### 2.4 `TemplateInfo` (`provisioning.oran.org/v1alpha1`) — namespaced

Catálogo de templates que o FOCOM usa para **validar** os `templateParameters`:

```
spec.templateName             (obrigatório)
spec.templateVersion          (obrigatório)
spec.templateParameterSchema  (obrigatório) — string com schema JSON/YAML dos parâmetros
```

### 2.5 `WorkloadCluster` (`infra.nephio.org/v1alpha1`) — namespaced

Como o **Nephio** (não o O2) enxerga um cluster gerenciado:

```
spec.clusterName        (string)
spec.cnis               ([]string, ex.: macvlan, ipvlan, sriov)
spec.masterInterface    (string, ex.: eth1)
```

---

## 3. Quais controllers observam o quê (extraído do RBAC + logs)

### 3.1 `o2ims-operator`  (ns `o2ims`, img `docker.io/nephio/o2ims-operator:v6.0.0`, framework **kopf/Python**)

- **Observa:** `provisioningrequests` (+`/status`,`/finalizers`) em `o2ims.provisioning.oran.org`.
- **Cria/muta:** `clusters` (`cluster.x-k8s.io`) — verbos `create/update/patch/delete` — e
  `packagevariants` (`config.porch.kpt.dev`) via REST (`KUBERNETES_BASE_URL`).
- **Env:** `UPSTREAM_PKG_REPO=catalog-infra-capi`, `KUBERNETES_BASE_URL=https://kubernetes.default.svc`.
- **Controllers internos:** `provisioning_request_controller.py`, `provisioning_request_validation_controller.py`,
  `northbound_restapi.py` (= a "O2 IMS REST Provision API" citada no release note do R6).

**O que ele faz, passo a passo** (de `provisioning_request_controller.py` + `utils.py`):
1. valida `templateName` / `templateVersion` / `templateParameters` (não vazios) e `clusterName`;
2. **cria um `PackageVariant`**:
   ```yaml
   apiVersion: config.porch.kpt.dev/v1alpha1
   kind: PackageVariant
   metadata: { name: <nome-do-ProvisioningRequest> }
   spec:
     upstream:   { repo: catalog-infra-capi, package: <templateName>, workspaceName: <templateVersion> }
     downstream: { repo: mgmt, package: <templateParameters.clusterName> }
     annotations: { approval.nephio.org/policy: initial }
     pipeline: { mutators: [ set-labels(<templateParameters.labels>) ] }
   ```
3. faz *poll* de `PackageVariant.status.conditions` → `provisioningState=progressing` (renderizando) ou `failed`;
4. faz *poll* do **CAPI `Cluster`** `<clusterName>` em `namespace=default` até `status.phase == "Provisioned"`
   → então grava `provisioningState=fulfilled` + `provisionedResourceSet.oCloudNodeClusterId=<uuid>`.

### 3.2 `focom-operator`  (ns `focom-operator-system`, img `docker.io/nephio/focom-operator:v6.0.0`, **controller-runtime/Go**)

- **Observa:** `focomprovisioningrequests` (+`/status`,`/finalizers`), `oclouds` (get/list/watch),
  `templateinfoes` (CRUD), `secrets` (get/list/watch).
- **Fluxo:** lê o `FocomProvisioningRequest` → resolve o `OCloud` (`spec.oCloudId`/`oCloudNamespace`)
  → lê o Secret `o2imsSecret` (kubeconfig/endpoint do O-Cloud) → **cria um `ProvisioningRequest`
  no cluster alvo** (`status.remoteName`), validando os parâmetros contra o `TemplateInfo`.

### 3.3 Cadeia completa

```
FocomProvisioningRequest  ──focom-operator──►  ProvisioningRequest (no O-Cloud)
     │(usa OCloud + Secret)                          │
     │                                    o2ims-operator
     ▼                                               ▼
                                        PackageVariant (catalog-infra-capi/<templateName> → mgmt/<clusterName>)
                                                     │  porch-controllers + nephio-controller (PackageVariant ctrl)
                                                     ▼
                                        PackageRevision publicada no repo git "mgmt" (auto-approve: policy=initial)
                                                     │  ConfigSync RootSync(mgmt) aplica de volta no cluster
                                                     ▼
                                        CAPI Cluster "<clusterName>" (topology class=docker)
                                                     │  capi-controller + capd-controller
                                                     ▼
                                        containers kind = WORKLOAD CLUSTER  → Cluster.status.phase=Provisioned
                                                     │
                                                     ▼
                                        ProvisioningRequest.status.provisioningState = fulfilled
```

---

## 4. Qual objeto corresponde a quê no fluxo O2 IMS

| Papel no O-RAN O2 | Objeto no cluster | Observação |
|---|---|---|
| **Intent / request do SMO** | `FocomProvisioningRequest` (SMO) → `ProvisioningRequest` (O-Cloud) | o `ProvisioningRequest` é o ponto de entrada da **interface O2 IMS** propriamente dita |
| **Registro do O-Cloud + credenciais** | `OCloud` + Secret | |
| **Catálogo de templates** | `TemplateInfo` | valida `templateParameters` |
| **Infraestrutura solicitada** | `PackageVariant` → `PackageRevision` (git) → **CAPI `Cluster`** (+ `DockerCluster`, `MachineDeployment`) | o `Cluster` CAPI é o "NodeCluster" do O-Cloud |
| **O-Cloud concretizado** | containers Docker/kind do workload cluster | `status.phase=Provisioned` |
| **Visão Nephio do cluster** | `WorkloadCluster` + `ClusterContext` (`infra.nephio.org`) | usados para sincronizar workloads (NF) depois |

> ⚠️ O README do próprio pacote diz que a CRD `ProvisioningRequest` é *"work in-progress in
> O-RAN standards … a PoC"* baseada em `O-RAN.WG6.TS.O-CLOUD-IM.0-R004-v03.00`. **É PoC**, não
> implementação O-RAN certificada. E o `oCloudNodeClusterId` no status é um **UUID aleatório**
> gerado pelo operador (`str(uuid.uuid4())`), não um id vindo de um inventário O2 real.

---

## 5. O que falta para acionar o fluxo (gap real deste laboratório)

`kubectl get repository` / `kubectl get repositories.config.porch.kpt.dev` → **VAZIO**.

O `o2ims-operator` assume que existem, no Porch:

| Repo Porch | Tipo | Aponta para | Como criar |
|---|---|---|---|
| **`catalog-infra-capi`** | read-only, `deployment: false` | `github.com/nephio-project/catalog` `/infra/capi` (branch `main`) | 1 `kubectl apply` de um `Repository` (shape em `nephio/optional/stock-repos/repo-infra-capi-packages.yaml`) |
| **`mgmt`** | `deployment: true` | repo git `http://172.18.0.200:3000/nephio/mgmt.git` no Gitea + Secret token | pacote `distros/sandbox/repository` com `name: mgmt` (cria repo Gitea via `Token`/`Repository` do `infra.nephio.org` + `Repository` do Porch) |
| **`mgmt-staging`** | staging (`deployment: false`, anотação `nephio.org/staging`) | idem, repo `mgmt-staging` | idem, `name: mgmt-staging` |
| `RootSync` (ConfigSync) do `mgmt` | — | aplica de volta no cluster o que o Porch publicar | `nephio/optional/rootsync` ou o pacote `repository` |

Sem isso, um `ProvisioningRequest` seria aceito e o `o2ims-operator` **criaria o `PackageVariant`**
(mudança de estado concreta observável), mas o `PackageVariant` ficaria **`Stalled`** por falta do
repo `mgmt` — e nenhum `Cluster` seria criado.

**Plano (ETAPA 6/7):** registrar `catalog-infra-capi` + criar `mgmt`/`mgmt-staging` + `RootSync`;
então criar o `ProvisioningRequest` (`templateName: nephio-workload-cluster`,
`templateParameters.clusterName: o-cloud-1`, `clusterProvisioner: capi`) e acompanhar
`ProvisioningRequest` → `PackageVariant` → `PackageRevision` → `Cluster` → containers.
**Se travar**, documentar exatamente onde e cair para o plano B (aplicar o `Cluster` CAPI
`class: docker` diretamente — CAPD ainda cria o `o-cloud-1` real — mantendo o `ProvisioningRequest`
+ `PackageVariant` como evidência do "request → controller → estado").

---

## 6. Tutoriais oficiais usados de referência

- `docs.nephio.org/docs/guides/user-guides/usecase-user-guides/exercise-4-o2ims/` — "O-RAN O2 IMS Operator Deployment" (usa a sandbox completa com repos `catalog-*`, `mgmt`, `mgmt-staging`).
- `docs.nephio.org/docs/guides/user-guides/usecase-user-guides/exercise-4-ocloud-cluster-prov/` — "O-RAN O-Cloud K8s Cluster deployment" (fluxo FOCOM com um 2º cluster kind como SMO).
- `docs.nephio.org/docs/network-architecture/o-ran-integration/`.
- `github.com/nephio-project/nephio` @ `v6.0.0` — `operators/o2ims-operator/` (código do controller + `tests/sample_provisioning_request.yaml`).
- `github.com/nephio-project/catalog` @ `v6` — `nephio/optional/stock-repos`, `distros/sandbox/repository`, `infra/capi/nephio-workload-cluster`, `infra/capi/cluster-capi-kind`.
