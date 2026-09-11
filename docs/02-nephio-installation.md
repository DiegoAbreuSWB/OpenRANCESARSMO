# 02 — Instalação mínima do Nephio R6 (ETAPA 3)

> Executado em 2026-09-10, sobre o cluster `nephio-mgmt` (kind, K8s v1.32.0).
> Método: **pacotes `kpt` do catálogo oficial, aplicados um a um, validando cada um.**
> NÃO foi usado o instalador Ansible do sandbox (traz Argo CD full + Flux + WebUI +
> clusters edge/regional + free5gc/OAI — inviável em 16 GB).
> Script: [`scripts/03-nephio-min.sh`](../scripts/03-nephio-min.sh)

- Catálogo: `https://github.com/nephio-project/catalog.git`, branch **`v6`**
- Commit fixado (upstreamLock de todos os pacotes): **`3b548f1cdd239101f79e3e49797bd59a39dad161`**
- Fluxo por pacote: `kpt pkg get …@v6` → `kpt live init` → `kpt live apply --reconcile-timeout=…`

---

## 1. Pacotes instalados (na ordem)

| # | Pacote (`catalog/…@v6`) | Namespace(s) | O que entrega | Resultado |
|---|---|---|---|---|
| 1 | `distros/sandbox/cert-manager` | `cert-manager` | cert-manager 3 pods; CRDs `*.cert-manager.io` | ✅ 3/3 |
| 2 | `nephio/core/porch` | `porch-system`, `porch-fn-system` | **Porch**: `porch-server` (apiserver agregado), `porch-controllers`, `function-runner` (x2) + **19 pods de KRM functions** (cache); CRDs `repositories/packagevariants/packagevariantsets/packagerevs.config.porch.kpt.dev` + API agregada `packagerevisions/packagerevisionresources/packages.porch.kpt.dev` | ✅ 23/23 apply, 19/19 fn pods |
| 3 | `distros/sandbox/gitea` | `gitea` | Gitea + PostgreSQL + memcached (repos git para o Porch). Service `LoadBalancer` (IP via MetalLB) | ✅ 3/3 |
| 4 | `nephio/core/nephio-operator` | `nephio-system` | `nephio-controller` + `token-controller`; CRDs `workloadclusters/clustercontexts/repositories/tokens/networkconfigs.infra.nephio.org`, `capacities/interfaces/datanetworks.req.nephio.org`, `networks.config.nephio.org`, `amf/smf/upfdeployments.workload.nephio.org` | ⚠️→✅ (ver §2.1 e §2.3) |
| 5 | `nephio/core/configsync` | `config-management-system`, `config-management-monitoring`, `resource-group-system` | Config Sync: `config-management-operator`, `reconciler-manager`, `otel-collector`, `resource-group-controller-manager`; CRDs `rootsyncs/reposyncs.configsync.gke.io` | ✅ |
| 6 | `infra/capi/cluster-capi` | `capi-system`, `capi-kubeadm-bootstrap-system`, `capi-kubeadm-control-plane-system` | **Cluster API** core + kubeadm bootstrap/control-plane; CRDs `clusters/machines/machinesets/machinedeployments/clusterclasses.cluster.x-k8s.io` etc. | ✅ 54/54 |
| 7 | `infra/capi/cluster-capi-infrastructure-docker` | `capd-system` | **CAPD** (provider Docker do Cluster API); CRDs `docker{clusters,machines,*templates}.infrastructure.cluster.x-k8s.io` | ⚠️→✅ (ver §2.2) |
| 8 | `infra/capi/cluster-capi-kind-docker-templates` | `default` | ClusterClass **`docker`** + `DockerClusterTemplate` + `DockerMachineTemplate`(control-plane/worker) + `KubeadmControlPlaneTemplate` + `KubeadmConfigTemplate` — o "molde" de um workload cluster kind | ⚠️→✅ (ver §2.2) |
| 9 | `nephio/optional/focom-operator` | `focom-operator-system` | **FOCOM operator**; CRDs `focomprovisioningrequests/oclouds.focom.nephio.org`, `templateinfoes.provisioning.oran.org` | ✅ 20/20 |
| 10 | `nephio/optional/o2ims` | `o2ims` | **operador O2 IMS** (`o2ims-operator`, img `docker.io/nephio/o2ims-operator:v6.0.0`); CRD **`provisioningrequests.o2ims.provisioning.oran.org`** (`ProvisioningRequest`, cluster-scoped) | ✅ 7/7 |
| 11 | `distros/sandbox/metallb` + `distros/sandbox/metallb-sandbox-config` | `metallb-system` | MetalLB (`controller` + `speaker`) + `IPAddressPool nephio` = `172.18.0.0/20` + `L2Advertisement` — dá à Service do Gitea o IP fixo **`172.18.0.200`** | ✅ (adicionado — ver §2.3) |
| 12 | `nephio/optional/resource-backend` | `backend-system` | `resource-backend-controller` (IPAM/VLAN); CRDs `endpoints/links/nodes/targets.inv.nephio.org`, `ipclaims/ipprefixes/networkinstances.ipam.resource.nephio.org`, `vlan*.vlan.resource.nephio.org` | ✅ (adicionado — ver §2.3) |

**Estado final: 34/34 pods `Running` em 16 namespaces. 76 CRDs.**
Evidência: [`evidence/nephio-install/20260910-093127_etapa3-final-state.txt`](../evidence/nephio-install/).

---

## 2. Problemas encontrados e correções (todos são bugs/limitações reais do upstream)

### 2.1 `kube-rbac-proxy` — imagem removida pelo Google (HTTP 404)

- **Sintoma:** `nephio-controller`, `token-controller` e `resource-backend-controller` em `ImagePullBackOff` no container sidecar.
- **Causa:** os pacotes `v6` referenciam `gcr.io/kubebuilder/kube-rbac-proxy:v0.8.0`. O Google **desativou o registry `gcr.io/kubebuilder`** — `NotFound`.
- **Correção:** trocar o registry (mesma imagem/versão continua publicada):
  `gcr.io/kubebuilder/kube-rbac-proxy:v0.8.0` → **`quay.io/brancz/kube-rbac-proxy:v0.8.0`**
  nos arquivos `app/controller/deployment-*.yaml` do pacote baixado + `kpt live apply` de novo.
- **Script:** [`scripts/patch-nephio-operator-rbacproxy.sh`](../scripts/patch-nephio-operator-rbacproxy.sh) (nephio-operator);
  mesma troca aplicada manualmente em `resource-backend`.

### 2.2 CAPD em `CrashLoopBackOff` — "too many open files"

- **Sintoma:** `capd-controller-manager` reinicia em loop; log: `E … "Problem running manager" err="too many open files"`.
  Consequência: a Service do webhook do CAPD fica fora do ar e o `apply` de
  `cluster-capi-kind-docker-templates` falha 3/6 recursos (`connection refused` no webhook).
- **Causa:** limites de **inotify** do kernel (compartilhado com a VM do WSL2) baixos demais
  para ~30 controllers num único nó kind. É o item *"Pod errors due to too many open files"*
  do *known-issues* oficial do kind.
- **Correção:** elevar sysctls no host WSL2 e persistir:
  ```
  fs.inotify.max_user_watches  = 1048576
  fs.inotify.max_user_instances = 8192
  fs.file-max                   = 1048576
  ```
  Script: [`scripts/fix-inotify-limits.sh`](../scripts/fix-inotify-limits.sh)
  (grava `/etc/sysctl.d/99-nephio-lab.conf`). Depois: `rollout restart` do CAPD e
  **re-`apply`** de `cluster-capi-kind-docker-templates` (→ 6/6 ok).

### 2.3 `nephio-controller` em `CrashLoopBackOff` — dependências que eu tinha adiado

- **Sintoma:** `nephio-controller` 1/2, log:
  - `failed to wait for NetworkController caches to sync … *v1alpha1.Endpoint: timed out`
  - `no matches for kind "Endpoint" in version "inv.nephio.org/v1alpha1"` (idem `VLANIndex`, `NetworkInstance`)
  - `cannot authenticate to gitea … http://172.18.0.200:3000 … no route to host`
- **Causa:** dois pacotes que o sandbox oficial instala no bootstrap e que eu tinha
  deixado de fora para "economizar":
  1. `resource-backend` — fornece os CRDs `*.inv.nephio.org` / `*.resource.nephio.org`.
     O `NetworkController` do `nephio-controller` (`ENABLE_NETWORKS=true`) faz *cache-sync*
     desses tipos e **derruba o manager inteiro** se não existirem.
  2. `metallb` + `metallb-sandbox-config` — o pacote do `nephio-operator` tem
     `GIT_URL=http://172.18.0.200:3000` **fixo**; sem MetalLB a Service `LoadBalancer`
     do Gitea nunca recebe esse IP.
- **Correção:** instalar os dois pacotes (itens 11 e 12 da tabela). Depois disso o
  `nephio-controller` sobe **2/2** e loga `gitea init done` + inicia
  `RepositoryController`, `ApprovalController`, `GenericSpecializer`, `BootstrapPackage/SecretController`, `NetworkController`.
- **Lição:** o "mínimo" real do Nephio R6 inclui cert-manager + Porch + Gitea +
  nephio-operator + configsync + **resource-backend + metallb**. CAPI/CAPD + FOCOM + O2 IMS
  são adicionais para o fluxo de O-Cloud.

---

## 3. O que NÃO foi instalado (de propósito)

`nephio/optional/webui`, `nephio/optional/fluxcd`, `nephio/optional/argo-cd-*`,
`nephio/optional/network-config`, e todo `workloads/*` (free5gc, OAI, RIC, UERANSIM).
Motivo: fora do escopo (SMO/O2/lifecycle) e/ou peso de RAM.

> **Bugs análogos no fluxo O2 IMS (ETAPA 7):** o pacote `nephio-workload-cluster@v3.0.0` e o
> mutator que o `o2ims-operator` injeta (`set-labels`) também referenciam registries mortos
> (`gcr.io/kpt-fn/*`). Contornado usando `templateVersion: main` e **sem** `labels` no
> `ProvisioningRequest`. E os nós CAPD (`kindest/node:v1.31.0`) precisam de correção de CNI
> (`fix-ocloud-cni-plugins.sh`) e de delegação de `cpuset` no cgroup v2
> (`fix-wsl-cgroup-cpuset.sh`). Detalhes em `docs/05-experiment-report.md` §6.

## 4. O que ainda falta para o fluxo O2 IMS (ETAPA 4/7)

- **Registrar repositórios no Porch** (`Repository` em `config.porch.kpt.dev`), em especial
  um repo `catalog-infra-capi` — o `o2ims-operator` usa `UPSTREAM_PKG_REPO=catalog-infra-capi`
  (env) para achar o pacote de cluster que ele vai instanciar.
  Hoje: `kubectl get repositories.config.porch.kpt.dev -A` → **vazio**.
- Descobrir, via `kubectl explain` + CRD, o schema real de `ProvisioningRequest`,
  `FocomProvisioningRequest`, `OCloud`, `TemplateInfo` (ETAPA 4).

---

## 5. Recursos (pós-ETAPA 3)

| Onde | Métrica |
|---|---|
| Container do kind (`docker stats`) | **2,58 GiB** RAM, CPU variando 40–250% durante applies |
| WSL (`free -h`) | **2,6 GiB usados** / 9,7 · **7,1 GiB "available"** (6,1 GiB é cache recuperável) · swap 0 |
| Windows | **2,9 GiB livres** / 16 · `vmmemWSL` ≈ 3,25 GiB |

⚠️ Windows com folga curta. `autoMemoryReclaim=gradual` devolve cache com o tempo.
Recomenda-se manter Chrome/IDE fechados durante as próximas etapas.

Snapshots: [`evidence/resources/20260910-093101_etapa3-complete.txt`](../evidence/resources/) e `windows-host-ram.log`.

---

## 6. Comandos de verificação (reprodutíveis)

```bash
kubectl --context kind-nephio-mgmt get pods -A
kubectl --context kind-nephio-mgmt get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded
kubectl --context kind-nephio-mgmt get crd | wc -l          # 76
kubectl --context kind-nephio-mgmt get deploy,sts -A
kubectl --context kind-nephio-mgmt api-resources | grep -Ei 'porch|nephio|o2ims|focom|oran'
bash scripts/03-nephio-min.sh status
```
