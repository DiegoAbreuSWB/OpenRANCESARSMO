# SMO em Open RAN com Nephio — trabalho acadêmico (Parte 1 + Parte 2)

Trabalho de duas etapas sobre **Service Management and Orchestration (SMO)** em redes Open
RAN, usando o **Nephio** como plataforma de automação cloud-native — analisado teoricamente na
Parte 1 e exercitado na prática na Parte 2, com um laboratório **100% local** (Windows + WSL2 +
kind), sem OpenStack, sem cloud paga, dentro de 16 GB de RAM.

> **Tese central (sustentada em ambas as partes, com evidência):**
> *"Nephio is a cloud-native automation and orchestration platform that can implement or
> support functions associated with the SMO and O-Cloud management architecture."*
> Nephio **não** é tratado como "o SMO oficial" da O-RAN Alliance.

## Resultado alcançado

- **Parte 1:** relatório + apresentação sobre arquitetura, funções de SMO, O1/O2, O-Cloud,
  lifecycle, monitoramento e comparação com ONAP/OSM/O-RAN-SC/Tacker — sem superestimar o que o
  Nephio cobre.
- **Parte 2:** um `ProvisioningRequest` (O2 IMS) provisiona um workload cluster real
  (`o-cloud-1`) via Cluster API; três CNFs simuladas (`oran-cu`, `oran-du`, `oran-core`) são
  publicadas como pacote kpt no Porch e entregues nesse cluster via reconciliação declarativa
  (não `kubectl apply` direto); os 6 experimentos formais (provisioning, config, scaling,
  upgrade, recovery, termination) rodaram com **6/6 `success`**
  ([`results/experiments.csv`](results/experiments.csv)).

---

## Estrutura do trabalho

| | Arquivo |
|---|---|
| **Parte 1 — relatório** | [`report/part1-report.md`](report/part1-report.md) |
| **Parte 1 — apresentação (fonte)** | [`presentation/part1-slides.md`](presentation/part1-slides.md) |
| **Parte 1 — apresentação (.pptx, 15 slides + notas)** | [`presentation/Parte1-Apresentacao-SMO-Nephio.pptx`](presentation/Parte1-Apresentacao-SMO-Nephio.pptx) |
| **Parte 2 — relatório** | [`report/part2-report.md`](report/part2-report.md) |
| **Parte 2 — relatório (.pdf, com evidências/diagramas/prints)** | [`report/Parte2-Relatorio-SMO-Nephio.pdf`](report/Parte2-Relatorio-SMO-Nephio.pdf) |
| **Parte 2 — apresentação** | [`presentation/part2-slides.md`](presentation/part2-slides.md) |
| **Roteiro de demo (8–10 min)** | [`demo/demo-script.md`](demo/demo-script.md) |
| Diagnóstico de ambiente | [`docs/environment-assessment.md`](docs/environment-assessment.md) |
| Pesquisa teórica (fontes oficiais) | [`docs/references.md`](docs/references.md) |
| Arquitetura do Nephio | [`docs/nephio-architecture.md`](docs/nephio-architecture.md) |
| Nephio × SMO (tabela função-a-função) | [`docs/nephio-vs-smo.md`](docs/nephio-vs-smo.md) |
| Interfaces O1 e O2 | [`docs/o1-o2-analysis.md`](docs/o1-o2-analysis.md) |
| Comparação com outras ferramentas | [`docs/tool-comparison.md`](docs/tool-comparison.md) |
| Fluxo de provisionamento (Intent→Package→...→CNF) | [`docs/provisioning-flow.md`](docs/provisioning-flow.md) |
| Monitoramento | [`docs/monitoring.md`](docs/monitoring.md) |
| Evolução com NFs reais (avaliação) | [`docs/real-nf-extension.md`](docs/real-nf-extension.md) |
| Relatório técnico do laboratório Nephio/O2IMS (base) | [`docs/05-experiment-report.md`](docs/05-experiment-report.md) |

---

## 1. Ambiente e pré-requisitos

| Requisito | Observação |
|---|---|
| Windows 10/11 x64 | testado em Windows 11 Enterprise 24H2 |
| **Administrador local** (pontual) | para instalar WSL2 + Docker + ajustar sysctl/cgroup |
| ~10 GB de RAM livres p/ o WSL | máquina de 16 GB: **feche Chrome/IDE** durante o lab |
| ~30 GB de disco | imagens + 2 clusters kind |
| Internet | GitHub, ghcr.io, quay.io, registry.k8s.io, docker.io |

Versões fixadas: Ubuntu 26.04 (WSL2) · Docker CE 29.8 · kind v0.27.0 · kubectl v1.32.3 ·
helm v3.19.0 · kpt v1.0.0 · **porchctl v1.5.6** · **Nephio R6 / catálogo `v6`** ·
K8s v1.32 (mgmt) / v1.31 (o-cloud). Medido em uso: **~3,9 GiB de RAM** com os 2 clusters + 3 CNFs
de pé (teto configurado: 9,7 GiB).

## 2. Arquitetura

```
Usuário ──intent──► Management Cluster (Nephio R6) ──O2 IMS──► Workload Cluster "o-cloud-1" (O-Cloud)
                                                                        │
                                                    Porch/kpt (repo 'openran-cnfs') ──► oran-cu / oran-du / oran-core
```

Diagramas completos: [`docs/04-architecture.md`](docs/04-architecture.md) (infra/O2 IMS) e
[`docs/provisioning-flow.md`](docs/provisioning-flow.md) (entrega das CNFs).

## 3. Reprodução rápida (Makefile)

```bash
wsl -d Ubuntu
cd "/mnt/c/Users/<voce>/.../SMO/X"
make help
make up          # management cluster + Nephio + O-Cloud (idempotente)
make deploy      # idem + publica/atualiza as 3 CNFs via Porch
make status      # visão geral
make experiment  # os 6 experimentos formais -> results/experiments.csv
make validate    # scripts/validate-lab.sh (10 checagens)
make down        # scripts/cleanup.sh (pergunta antes de remover)

# Deliverables finais (.pptx / .pdf) — não precisam do laboratório de pé, só de rede:
make deliverables   # instala pandoc+weasyprint sem sudo, renderiza diagramas, gera os 2 arquivos
# ou individualmente:
make slides         # -> presentation/Parte1-Apresentacao-SMO-Nephio.pptx
make report-pdf     # -> report/Parte2-Relatorio-SMO-Nephio.pdf
```

`make deliverables` não usa `sudo` (nesse WSL, `sudo` não-interativo trava pedindo autenticação
do Windows — ver [`scripts/install-docgen-tools.sh`](scripts/install-docgen-tools.sh)): pandoc é
um binário standalone baixado para `~/.local/bin`, e o WeasyPrint vai para um venv
(`~/.venvs/docgen`) via `pip install --user` (desde a v53 ele não depende mais de Pango/GTK).
Os diagramas (`scripts/diagrams/*.mmd`) são renderizados via o serviço público
[mermaid.ink](https://mermaid.ink) — sem precisar instalar Mermaid-CLI/Chromium localmente.

## 4. Reprodução do zero (passo a passo, sem Makefile)

```bash
# ---- 0. Host: WSL2 + Docker + CLIs -------------------------------------------
# [Windows / PowerShell como administrador]
wsl --install                       # instala WSL2 + Ubuntu; REINICIE o Windows
# crie C:\Users\<voce>\.wslconfig com:
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
sudo bash scripts/setup-host.sh all           # Docker CE + kubectl/kind/helm/kpt/porchctl
sudo bash scripts/fix-inotify-limits.sh       # fs.inotify.* (senão CAPD faz CrashLoop)
sudo bash scripts/fix-wsl-cgroup-cpuset.sh    # delega cpuset no cgroup v2 (resiliência)
sudo systemctl restart docker
# feche e reabra o shell WSL (para o grupo 'docker' valer sem sudo)

# ---- 1. Management Cluster + Nephio R6 mínimo -------------------------------
bash scripts/check-requirements.sh
bash scripts/install-nephio.sh                # idempotente; cria nephio-mgmt + 34/35 pods

# ---- 2. O-Cloud via O2 IMS ---------------------------------------------------
bash scripts/06-porch-repos.sh catalog
bash scripts/06-porch-repos.sh mgmt
bash scripts/06-porch-repos.sh rootsync
bash scripts/07-provisioning-request.sh apply
bash scripts/07-provisioning-request.sh watch          # até provisioningState=fulfilled
bash scripts/ocloud-kubeconfig.sh o-cloud-1
bash scripts/fix-ocloud-cni-plugins.sh

# ---- 3. As 3 CNFs via kpt + Porch (Fase 12) ---------------------------------
bash scripts/06-porch-repos.sh openran
bash lab/nephio/deploy-cnfs-via-porch.sh

# ---- 4. Experimentos formais -------------------------------------------------
bash scripts/run-experiments.sh all             # -> results/experiments.csv
```

> Atalhos: `scripts/deploy.sh` encadeia os passos 1–3 inteiros, idempotente.
> `scripts/reprovision-ocloud.sh` recria só o `o-cloud-1` (útil após restart da VM do WSL2).

## 5. Demonstração ao vivo

Roteiro cronometrado (comando/resultado esperado/fala): [`demo/demo-script.md`](demo/demo-script.md).
Para a Parte 1 (só SMO/O2 IMS, sem as CNFs): [`docs/06-presentation-notes.md`](docs/06-presentation-notes.md).

## 6. Validação

```bash
bash scripts/validate-lab.sh              # 10 checagens PASS/FAIL/SKIP -> evidence/
bash scripts/status.sh                    # snapshot do lab inteiro
bash scripts/resource-usage.sh <rótulo>   # RAM / docker stats / pods -> evidence/resources/
```

## 7. Recuperação após restart da VM do WSL2

```bash
bash scripts/lab-recover.sh          # religa o nephio-mgmt (recupera sozinho)
bash scripts/reprovision-ocloud.sh   # RECRIA o o-cloud-1 (o CAPD NÃO sobrevive ao restart)
bash lab/nephio/deploy-cnfs-via-porch.sh   # reenvia as CNFs depois de recriar o o-cloud-1
```

## 8. Cleanup

```bash
bash scripts/cleanup.sh              # pergunta antes de cada remoção
bash scripts/cleanup.sh --yes        # sem perguntar
```
Remove **apenas**: clusters `nephio-mgmt`/`o-cloud-1`, containers do lab, namespace
`openran-lab`, repositório Porch `openran-cnfs`, `~/nephio-install`, kubeconfigs/contextos do
lab. **Não** toca em outros clusters, imagens, volumes, `.wslconfig`, Docker/WSL nem nos
arquivos deste repositório.

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
| `porchctl rpkg push`: `".KptRevisionMetadata" not found` | faltou `porchctl rpkg pull` antes de editar — o `push` exige a cópia de trabalho baixada, não um dir criado do zero |
| `kpt live apply`: `apply skipped: inventory policy ... MustMatch` (`Empty` ou `NoMatch`) | o recurso já existe fora do inventário do kpt (criado manualmente, ou um `resourcegroup.yaml` novo foi gerado). Apague o recurso "órfão" (ex.: `kubectl delete ns openran-lab`) e deixe o kpt recriar/assumir a posse; **não apague `resourcegroup.yaml` entre chamadas de `deploy-cnfs-via-porch.sh`** — ele precisa ser persistente |
| Rollout não dispara ao mudar só o `ConfigMap` | Kubernetes não recria pods por mudança de `ConfigMap` referenciado via `envFrom` — mude também algo em `spec.template` (ex.: uma anotação) para forçar um novo `ReplicaSet` |
| Windows sem RAM | feche Chrome/IDE; `autoMemoryReclaim=gradual` devolve cache; baixe `memory=` no `.wslconfig` |

## 10. Resultados

- **O2 IMS / O-Cloud (Parte 1):** `validate-lab.sh` → `PASS=10 FAIL=0`. Cadeia
  `ProvisioningRequest → o2ims-operator → PackageVariant → PackageRevision → RootSync →
  Cluster CAPI (Provisioned) → CAPD → o-cloud-1 (2 nós Ready)` — `provisioningState: fulfilled`.
- **CNFs / lifecycle (Parte 2):** 6/6 experimentos `success`
  ([`results/experiments.csv`](results/experiments.csv)): provisioning 20,4s · config 0,7s ·
  scaling 5,7s · recovery 3,9s · upgrade 15,0s · termination 10,8s. 2 bugs de engenharia reais
  encontrados e corrigidos durante os experimentos (ver `docs/provisioning-flow.md` §2 e
  `report/part2-report.md` §7/§9).

Evidências timestamped em [`evidence/`](evidence/) (`environment/`, `resources/`,
`nephio-install/`, `o2ims/`, `workload-cluster/`, `lifecycle/`, `experiments/`).

## 11. Limitações

PoC de O2 IMS (não certificada O-RAN) · O-Cloud = cluster kind com provider Docker · sem O1 ·
sem Non-RT RIC/política A1 · sem GitOps contínuo (Config Sync) no workload cluster para as CNFs
(usa `kpt live apply` sob demanda) · CNFs simuladas, não NFs reais (avaliação de substituição em
`docs/real-nf-extension.md`, não realizada por RAM) · O-Cloud não sobrevive a restart da VM do
WSL2 (re-provisionar) · sem `metrics-server`/Prometheus · escala única (1 management + 1
workload cluster, sem edge/regional/core, RIC, Free5GC/OAI). Lista completa:
`report/part2-report.md` §14 e `docs/05-experiment-report.md` §11.

## 12. Estrutura do repositório

```
docs/          00-06 (auditoria/instalação/arquitetura/O2IMS/relatório do lab base) +
               environment-assessment, references, nephio-architecture, nephio-vs-smo,
               o1-o2-analysis, tool-comparison, provisioning-flow, monitoring, real-nf-extension
report/        part1-report.md, part2-report.md, part2-report-print.html (fonte do PDF),
               Parte2-Relatorio-SMO-Nephio.pdf, assets/ (diagramas .png renderizados)
presentation/  part1-slides.md, part2-slides.md, part1-slides-deck.md (fonte do pptx),
               Parte1-Apresentacao-SMO-Nephio.pptx, assets/ (diagramas .png renderizados)
demo/          demo-script.md
lab/
  cnfs/        oran-cu, oran-du, oran-core (FastAPI) + smoke-test.sh
  kubernetes/  manifests puros (Deployment/Service/ConfigMap) - baseline sem Nephio
  nephio/      pacote kpt (openran-cnfs) + deploy-cnfs-via-porch.sh - fluxo via Porch
manifests/     kind-management-cluster, o2-provisioning-request, demo-nf, porch-repo-*, rootsync-mgmt
scripts/       setup-host, check-requirements, install-nephio, 01/03/06/07/09/10-*, deploy,
               status, run-experiments, validate-lab, resource-usage, cleanup, fix-*, lab-recover,
               reprovision-ocloud, ocloud-kubeconfig, lab-keepalive, patch-*, diagrams/*.mmd,
               render-diagrams, install-docgen-tools, build-pptx, build-report-pdf
evidence/      saídas timestamped (environment/ resources/ nephio-install/ o2ims/
               workload-cluster/ lifecycle/ experiments/)
results/       experiments.csv
Makefile       make up | deploy | status | experiment | validate | slides | report-pdf |
               deliverables | down | cleanup
```
