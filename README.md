# Laboratório SMO / O2 IMS / O-Cloud com Nephio (kind + WSL2)

Laboratório local, pequeno e reproduzível que demonstra a cadeia **SMO → O2 IMS → O-Cloud →
lifecycle** do O-RAN usando **Nephio R6**, numa máquina Windows de 16 GB (WSL2 + kind, sem VMs
pesadas, sem Free5GC/OAI).

- **Resultado atingido:** um `ProvisioningRequest` (O2 IMS) provisiona um segundo cluster
  Kubernetes ("O-Cloud") via Cluster API/CAPD → `provisioningState: fulfilled`; um workload
  representativo (`demo-nf`) roda nele e demonstra instantiate/scale/update/recover/terminate.
- **Validação automática:** [`scripts/validate-lab.sh`](scripts/validate-lab.sh) → `PASS=10 FAIL=0`.

> Leia também: [`docs/05-experiment-report.md`](docs/05-experiment-report.md) (relatório completo) e
> [`docs/06-presentation-notes.md`](docs/06-presentation-notes.md) (roteiro de demo).

---

## 1. Objetivo

```
Usuário/SMO ──intent──► Management Cluster (Nephio) ──O2 IMS──► Workload Cluster ("O-Cloud") ──► demo-nf ──► lifecycle
```

Demonstrar, com **evidências reais**, orquestração declarativa (Nephio/Porch/GitOps),
provisionamento de infraestrutura via a interface O2 IMS, e o ciclo de vida de um workload.
**Não** é uma implementação O-RAN certificada — ver [Limitações](#10-limitações).

## 2. Pré-requisitos

| Requisito | Observação |
|---|---|
| Windows 10/11 x64 | testado em Windows 11 Enterprise 24H2 |
| **Administrador local** (pontual) | para instalar WSL2 + Docker + ajustar sysctl/cgroup |
| ~10 GB de RAM livres p/ o WSL | máquina de 16 GB: **feche Chrome/IDE** durante o lab |
| ~30 GB de disco | imagens + 2 clusters kind |
| Internet | GitHub, ghcr.io, quay.io, registry.k8s.io, docker.io |

Versões fixadas: Ubuntu 26.04 (WSL2) · Docker CE 29.8 · **kind v0.27.0** · kubectl v1.32.3 ·
helm v3.19.0 · kpt v1.0.0 · **Nephio R6 / catálogo `v6`** · K8s v1.32 (mgmt) / v1.31 (o-cloud).

## 3. Arquitetura

Diagrama e explicação: [`docs/04-architecture.md`](docs/04-architecture.md).
Resumo: 1 Management Cluster kind (`nephio-mgmt`) com Nephio + O2 IMS/FOCOM + Cluster API/CAPD;
1 Workload Cluster kind (`o-cloud-1`, 2 nós) criado pelo fluxo O2 IMS = "O-Cloud" acadêmico;
`demo-nf` (nginx) = workload representativo de NF.

## 4. Instalação (reprodução do zero)

Todos os comandos rodam **dentro do WSL** (`wsl -d Ubuntu`), a partir da raiz deste repositório,
salvo onde indicado **[Windows/admin]**.

```bash
# ---- 0. Host: WSL2 + Docker + CLIs -------------------------------------------
# [Windows / PowerShell como administrador]
wsl --install                       # instala WSL2 + Ubuntu; REINICIE o Windows
# copie manifests/.wslconfig-exemplo? não: crie C:\Users\<voce>\.wslconfig com:
#   [wsl2]
#   memory=10GB
#   processors=6
#   swap=4GB
#   vmIdleTimeout=21600000
#   [experimental]
#   autoMemoryReclaim=gradual
#   sparseVhd=true
# depois:  wsl --shutdown   (aplica o .wslconfig)

# [dentro do WSL, como root]
sudo bash scripts/setup-host.sh all           # Docker CE + kubectl/kind/helm/kpt
sudo bash scripts/fix-inotify-limits.sh       # fs.inotify.* (senão CAPD faz CrashLoop)
sudo bash scripts/fix-wsl-cgroup-cpuset.sh    # delega cpuset no cgroup v2 (resiliência)
sudo systemctl restart docker
# feche e reabra o shell WSL (para o grupo 'docker' valer sem sudo)

# ---- 1. Management Cluster --------------------------------------------------
bash scripts/01-mgmt-cluster.sh               # kind 'nephio-mgmt' (K8s v1.32)

# ---- 3. Nephio R6 mínimo (um pacote kpt por vez) --------------------------
for step in cert-manager porch gitea nephio-operator configsync capi metallb resource-backend focom o2ims; do
  bash scripts/03-nephio-min.sh "$step"
done
bash scripts/patch-nephio-operator-rbacproxy.sh   # corrige gcr.io/kubebuilder morto
# (se resource-backend ficar 1/2, aplique a mesma troca de imagem manualmente e
#  kubectl -n backend-system rollout restart deploy/resource-backend-controller)
bash scripts/03-nephio-min.sh status              # espera 34/34 pods Running

# ---- 6. Repositórios Porch para o fluxo O2 IMS ---------------------------
bash scripts/06-porch-repos.sh catalog        # catalog-infra-capi (Ready)
bash scripts/06-porch-repos.sh mgmt           # repos deployment mgmt + mgmt-staging
bash scripts/06-porch-repos.sh rootsync       # RootSync do repo mgmt

# ---- 7. Provisionar o O-Cloud via ProvisioningRequest --------------------
bash scripts/07-provisioning-request.sh apply
bash scripts/07-provisioning-request.sh watch          # até provisioningState=fulfilled
bash scripts/ocloud-kubeconfig.sh o-cloud-1            # cria o contexto 'o-cloud-1'
bash scripts/fix-ocloud-cni-plugins.sh                 # CNI 'loopback' etc. nos nós novos

# ---- 9. Workload representativo -----------------------------------------
bash scripts/09-demo-nf.sh                     # demo-nf no o-cloud-1 (HTTP 200)
```

> Atalho: `scripts/reprovision-ocloud.sh` executa as ETAPAS 6→9 relativas ao O-Cloud (útil
> para recriar só o `o-cloud-1`).

## 5. Execução da demonstração (lifecycle)

```bash
bash scripts/10-lifecycle.sh instantiate   # A
bash scripts/10-lifecycle.sh scale         # B  (1 -> 3)
bash scripts/10-lifecycle.sh update        # C  (env VERSION v1 -> v2, rollout)
bash scripts/10-lifecycle.sh recover       # D  (delete pod -> ReplicaSet recria)
bash scripts/10-lifecycle.sh terminate     # E  (delete -f -> tudo removido)
bash scripts/10-lifecycle.sh instantiate   # restaura demo-nf p/ a apresentação
```
Roteiro narrado: [`docs/06-presentation-notes.md`](docs/06-presentation-notes.md).

## 6. Validação

```bash
bash scripts/validate-lab.sh        # 10 checagens PASS/FAIL/SKIP -> evidence/
bash scripts/resource-usage.sh <rótulo>   # RAM / docker stats / pods (evidence/resources/)
```

## 7. Recuperação após restart da VM do WSL2

```bash
bash scripts/lab-recover.sh          # religa o nephio-mgmt (recupera sozinho)
bash scripts/reprovision-ocloud.sh   # RECRIA o o-cloud-1 (o CAPD NÃO sobrevive ao restart)
```

## 8. Cleanup

```bash
bash scripts/cleanup.sh              # pergunta antes de cada remoção
bash scripts/cleanup.sh --yes       # sem perguntar
```
Remove **apenas** os clusters `nephio-mgmt` e `o-cloud-1`, seus containers, `~/nephio-install`,
`/tmp/o-cloud-1.kubeconfig` e os contextos kube do lab. **Não** toca em outros clusters,
imagens, volumes, `.wslconfig`, Docker/WSL nem nos arquivos deste repositório.

## 9. Troubleshooting

| Sintoma | Causa / correção |
|---|---|
| `wsl --install` falha (WDAC/EDR/Store) | endpoint corporativo; peça à TI, ou MSIX do `github.com/microsoft/WSL/releases` + `wsl --update` |
| Cluster kind cai ~60 s após fechar o terminal | `.wslconfig` → `vmIdleTimeout=21600000`; mantenha 1 shell WSL aberto ou rode `scripts/lab-keepalive.sh` |
| Pod em `ImagePullBackOff` de `gcr.io/kubebuilder/...` ou `gcr.io/kpt-fn/...` | registries desativados pelo Google. `kube-rbac-proxy` → `quay.io/brancz/...`; templates → use `templateVersion: main` e **sem** `labels` |
| `capd-controller-manager` CrashLoop "too many open files" | `sudo bash scripts/fix-inotify-limits.sh` |
| `nephio-controller` CrashLoop (`Endpoint`/`VLANIndex` / gitea `no route to host`) | falta `resource-backend` e/ou `metallb` — `scripts/03-nephio-min.sh resource-backend` e `... metallb` |
| Pods do `o-cloud-1` presos em `ContainerCreating` (`plugin "loopback" not found`) | `bash scripts/fix-ocloud-cni-plugins.sh` |
| `o-cloud-1` não responde após reboot; kubelet `missing controllers: cpuset` | `sudo bash scripts/fix-wsl-cgroup-cpuset.sh` + `bash scripts/reprovision-ocloud.sh` |
| `kubectl --context o-cloud-1` → `x509: certificate signed by unknown authority` | contexto com CA obsoleto (o-cloud recriado). `bash scripts/ocloud-kubeconfig.sh o-cloud-1` (purga e re-mescla) |
| `PackageVariant` `Stalled` / nenhum `Cluster` nasce | GitOps inconsistente. `bash scripts/reprovision-ocloud.sh` (faz o reset das PackageRevisions) |
| Windows sem RAM | feche Chrome/IDE; `autoMemoryReclaim=gradual` devolve cache; baixe `memory=` no `.wslconfig` |

## 10. Resultados

`validate-lab.sh` → **PASS=10 FAIL=0 SKIP=0**. Cadeia demonstrada ponta a ponta:
`ProvisioningRequest` → `o2ims-operator` → `PackageVariant` → `PackageRevision` (Gitea) →
`RootSync` → `Cluster` CAPI (`Provisioned`) → CAPD → `o-cloud-1` (2 nós Ready) →
`provisioningState: fulfilled` → `demo-nf` (HTTP 200) → lifecycle A–E.
Evidências timestamped em [`evidence/`](evidence/) (`environment/`, `resources/`,
`nephio-install/`, `o2ims/`, `workload-cluster/`, `lifecycle/`).

## 11. Limitações

Resumo (completo em [`docs/05-experiment-report.md`](docs/05-experiment-report.md) §11):
PoC O-RAN (não certificada) · O-Cloud = cluster kind com provider Docker · FOCOM no mesmo
cluster (sem federação) · `demo-nf` = nginx (não NF) · O-Cloud não sobrevive a restart da VM
(re-provisionar) · 3 bugs do upstream R6 exigiram patch · sem `metrics-server` · escala única
(sem edge/regional/core, RIC, Free5GC/OAI).

## 12. Estrutura do repositório

```
docs/    00 audit · 00b host-setup · 01 versão Nephio · 02 instalação · 03 O2 IMS discovery
         04 arquitetura · 05 relatório · 06 apresentação
manifests/  kind-management-cluster.yaml · o2-provisioning-request.yaml · demo-nf.yaml
            porch-repo-catalog-infra-capi.yaml · rootsync-mgmt.yaml
scripts/  setup-host · 01-mgmt-cluster · 03-nephio-min · 04-o2ims-discovery · 06-porch-repos
          07-provisioning-request · 09-demo-nf · 10-lifecycle · validate-lab · resource-usage
          fix-* · lab-recover · reprovision-ocloud · ocloud-kubeconfig · cleanup · lab-keepalive
evidence/ saídas timestamped de cada etapa
```
