# Environment Assessment (PASSO 1)

> Data: 2026-09-11. Diagnóstico somente-leitura — **nada foi instalado nesta etapa.**
> Este trabalho reaproveita um laboratório Nephio já construído nos dias 09–10/09/2026
> nesta mesma máquina/pasta. Ver seção 6.

---

## 1. Comandos solicitados (saída real)

```text
$ docker --version
Docker version 29.8.0, build 88096ef

$ docker info (resumo)
ServerVersion=29.8.0  OS=Ubuntu 26.04 LTS  CPUs=6  MemTotal=9.7 GiB (limite do WSL)
Containers=4 (4 rodando)

$ wsl --version   [Windows]
Versão do WSL: 2.7.13.0

$ kubectl version --client
Client Version: v1.32.3

$ kind version
kind v0.27.0 go1.23.6 linux/amd64

$ k3d version
command not found   ->  NÃO instalado (não é necessário: kind já é o runtime escolhido e validado)

$ helm version --short
v3.19.0+g3d8990f

$ kpt version
Version: 1.0.0

$ git --version   [WSL]
git version 2.53.0
$ git --version   [Windows]
git version 2.55.0.windows.5
```

## 2. Recursos da máquina (agora)

| Métrica | Valor |
|---|---|
| RAM total (Windows) | 15,66 GB |
| **RAM livre (Windows) agora** | **1,73 GB ⚠️** (Chrome/IDE abertos — ver risco §4) |
| RAM do WSL2 (cgroup, `.wslconfig`) | 9,7 GiB (`memory=10GB`) |
| RAM usada dentro do WSL agora | 3,6 GiB (o laboratório já está rodando — ver §6) |
| RAM "available" no WSL | 6,1 GiB (inclui cache reclamável) |
| `vmmemWSL` visto pelo Windows | 3,27 GB |
| CPUs alocadas ao WSL | 6 (`processors=6` no `.wslconfig`) |
| Disco (WSL, `/`) | 1007 GB total, **937 GB livres** |
| Swap do WSL | 4 GiB configurado, ~0 em uso |

## 3. O que já está instalado / o que falta

| Ferramenta | Status | Versão |
|---|---|---|
| Docker Engine (dentro do WSL2, sem Docker Desktop) | ✅ instalado | 29.8.0 |
| WSL2 + Ubuntu | ✅ instalado | WSL 2.7.13 · Ubuntu 26.04 LTS |
| kubectl | ✅ instalado | v1.32.3 |
| kind | ✅ instalado | v0.27.0 |
| k3d | ❌ ausente | **não necessário** — kind já validado e em uso |
| helm | ✅ instalado | v3.19.0 |
| kpt | ✅ instalado | v1.0.0 |
| git | ✅ instalado (Windows e WSL) | 2.55 / 2.53 |
| Nephio | ✅ **já instalado e rodando** (release R6) | ver §6 |
| Prometheus/Grafana | ❌ não instalado | por escolha (ver Fase 14, opção leve) |
| metrics-server | ❌ não instalado | por escolha (evita peso extra) |

**Nada precisa ser instalado para começar a Fase 1 (pesquisa) nem para retomar a Fase 8+ (Nephio) —
o ambiente de execução já existe e está saudável.**

## 4. Risco de consumo de memória

| Risco | Severidade | Nota |
|---|---|---|
| RAM do **Windows** apertada agora (1,73 GB livres) | 🟠 alto, imediato | Feche Chrome/outros apps antes de rodar experimentos pesados. Não é um problema do laboratório em si — é o desktop concorrendo pela mesma RAM. |
| WSL2 já usa ~3,6 GiB com o lab de pé (2 clusters kind) | 🟡 médio | Dentro do orçamento (~10–12 GB pedido). Margem: ~6 GiB *available* no WSL antes de pressionar o teto de 9,7 GiB. |
| Um 3º cluster ou CNFs pesadas | 🟡 médio | As 3 CNFs simuladas (FastAPI, Fase 9) são leves (~30–60 MiB cada) — impacto marginal. |
| VM do WSL2 reiniciando (sleep/hibernate do notebook, ou `wsl --shutdown`) | 🟡 médio, conhecido | O cluster de management se recupera sozinho; o workload cluster (CAPD) **não** — precisa ser re-provisionado. Scripts prontos: `scripts/lab-recover.sh`, `scripts/reprovision-ocloud.sh`. |
| Prometheus/Grafana completos | 🔴 alto se instalados | Por isso a Fase 14 prioriza a "Opção A" (leve: `/metrics` + `kubectl top` + logs). |

## 5. Arquitetura recomendada

Reaproveitar a que já está validada e rodando, em vez de recriar do zero:

```
Windows 11 (16 GB)
  └─ WSL2 Ubuntu 26.04  (.wslconfig: memory=10GB, processors=6, swap=4GB)
       └─ Docker Engine 29.8 (nativo, sem Docker Desktop)
            ├─ kind cluster "nephio-mgmt"   (K8s v1.32, 1 nó)  — Management Cluster
            │     Nephio R6: Porch, nephio-controller, Config Sync, Gitea,
            │     Cluster API + CAPD, operadores O2 IMS + FOCOM
            │
            └─ kind cluster "o-cloud-1"     (K8s v1.31, 2 nós) — Workload Cluster / "O-Cloud"
                  provisionado PELO Nephio via ProvisioningRequest (não kind manual)
                  → aqui entram as CNFs simuladas oran-cu / oran-du / oran-core (Fase 9)
```

Orçamento medido agora com os 2 clusters de pé e saudáveis: **~3,6 GiB dentro do WSL**
(bem abaixo do teto de 9,7 GiB / da meta de 10–12 GB do enunciado). Sobra confortável para
as 3 CNFs leves e para um monitoramento mínimo (Opção A da Fase 14).

Isso corresponde ao **Level A** da Fase 20 (Nephio completo + management + workload cluster +
CNFs) — e já está **funcionando**, não é apenas um plano.

## 6. O que já foi feito nesta mesma pasta (reaproveitável)

Nos dias 09–10/09/2026 este mesmo diretório foi usado para um laboratório Nephio R6 completo,
que **cobre integralmente a Fase 8 a 12 e parte da 13** do novo enunciado. Estado atual (verificado
agora, ao vivo): `nephio-mgmt` 35/35 pods `Ready`, `o-cloud-1` 2 nós `Ready`, ambos rodando
continuamente há 9h sem intervenção.

| Já existe | Onde | Cobre |
|---|---|---|
| Auditoria de ambiente anterior (mais detalhada, nível infra) | `docs/00-environment-audit.md`, `00b-host-setup.md` | complementa este `environment-assessment.md` |
| Decisão de versão do Nephio (R6, catálogo `v6`) + justificativa | `docs/01-nephio-version.md` | Fase 1 (pesquisa) e Passo 8 |
| Instalação mínima do Nephio, pacote a pacote via `kpt`, com bugs de upstream corrigidos e documentados | `docs/02-nephio-installation.md`, `scripts/03-nephio-min.sh`, `scripts/patch-nephio-operator-rbacproxy.sh`, `scripts/fix-inotify-limits.sh` | Fase 11 (`install-nephio.sh` já existe em espírito) |
| Descoberta real das CRDs/controllers O2 IMS + FOCOM (schema, RBAC, fluxo) | `docs/03-o2ims-discovery.md` | Fase 4 (O1/O2) — só falta O1 |
| Arquitetura com diagrama Mermaid | `docs/04-architecture.md` | Fase 2 (arquitetura Nephio) — já no formato pedido |
| **Fluxo `Intent → Package → Repository → Nephio → Reconciliation → Kubernetes → CNF` já demonstrado e evidenciado**, via `ProvisioningRequest` real (`status: fulfilled`) | `docs/05-experiment-report.md` §6, `manifests/o2-provisioning-request.yaml`, `evidence/o2ims/` | Fase 12 (provisioning flow) inteira |
| Deploy de um workload representativo + ciclo de vida completo (instantiate/scale/update/recover/terminate) já demonstrado e validado | `manifests/demo-nf.yaml`, `scripts/10-lifecycle.sh`, `scripts/validate-lab.sh` (PASS=10), `evidence/lifecycle/` | Fase 13, Experimentos 1, 3, 4, 5, 6 (falta o Experimento 2 — config management, que pede uma CNF com `/config`) |
| Roteiro de demonstração ao vivo | `docs/06-presentation-notes.md` | Fase 19 (equivalente) |
| Scripts de recuperação/reprovisionamento/limpeza | `scripts/lab-recover.sh`, `reprovision-ocloud.sh`, `cleanup.sh`, `validate-lab.sh` | Fase 11, 16, 20 |

**O que falta para fechar o novo escopo:**
- as 3 CNFs simuladas com `/health /config /metrics` (Fase 9) — o `demo-nf` atual é um nginx
  simples, sem essas rotas; precisa ser substituído/complementado por `oran-cu/du/core`;
- Experimento 2 (config management com reconciliação de `cell_id`);
- estrutura acadêmica nova: `report/`, `presentation/`, `lab/`, `demo/`, `results/`, `Makefile`,
  e os docs teóricos (`references.md`, `nephio-architecture.md`, `nephio-vs-smo.md`,
  `o1-o2-analysis.md`, `tool-comparison.md`, `provisioning-flow.md`, `monitoring.md`,
  `real-nf-extension.md`) — conteúdo novo de pesquisa (Fases 1–7), não reaproveitável do lab
  anterior, mas que pode **citar e referenciar** as descobertas técnicas já feitas (principalmente
  `03-o2ims-discovery.md` e `05-experiment-report.md`).

---

## 7. Próximos passos (aguardando autorização)

1. **Decisão de estrutura** (pergunto ao usuário a seguir): manter tudo nesta mesma pasta,
   acrescentando `report/`, `presentation/`, `lab/`, `demo/`, `results/`, `Makefile` — ou criar
   uma pasta nova `openran-nephio-lab/`? Recriar do zero jogaria fora ~9h de laboratório já
   validado e todos os caminhos absolutos usados pelos scripts.
2. Se autorizado: Passo 2 — pesquisa teórica (Fase 1) e `docs/references.md`, sem tocar no cluster.
3. Depois: relatório e apresentação da Parte 1 (Fases 6–7), só então retomar a prática (Parte 2)
   reaproveitando o laboratório já rodando.

Nenhum componente novo será instalado até nova autorização explícita.
