# Apresentação — Parte 2
## Provisionamento e gerenciamento prático de uma pilha Open RAN com Nephio

> 15 slides · alvo de 20–30 minutos. Fonte: [`report/part2-report.md`](../report/part2-report.md).
> Complementa a Parte 1 (`presentation/part1-slides.md`) — aqui o foco é a **prática**.

---

### Slide 1 — Objetivo

**Bullets:**
- Usar o Nephio, na prática, para provisionar e gerenciar uma pilha Open RAN **simulada**
- 3 Network Functions representativas: `oran-cu`, `oran-du`, `oran-core`
- Demonstrar: provisioning, configuration management, orchestration, lifecycle management
- Tudo com **evidência mensurável** — tempo, RAM, CPU — não só "funcionou"

**Figura sugerida:** o diagrama do fluxo completo (Intent → Package → Repository → Reconciliation → CNF).

**Fala do apresentador:**
"Na Parte 1 caracterizei o que o Nephio faz e não faz. Agora vou provar isso na prática, com
números reais de um laboratório que rodou nesta máquina."

---

### Slide 2 — Arquitetura

**Bullets:**
- Management Cluster (`nephio-mgmt`) + Workload Cluster/O-Cloud (`o-cloud-1`) — kind, 2 clusters
- `o-cloud-1` foi **provisionado pelo próprio Nephio** via O2 IMS (Parte 1)
- As 3 CNFs chegam ao `o-cloud-1` via um pacote kpt publicado no Porch — não `kubectl apply`
- Repositório Porch dedicado: `openran-cnfs`

**Figura sugerida:** diagrama Mermaid do `report/part2-report.md` §3.

**Fala do apresentador:**
"Dois clusters, dois papéis. O de baixo — o O-Cloud — foi criado pelo próprio Nephio. Agora vou
mostrar como as funções de rede chegam nele."

---

### Slide 3 — Ambiente

**Bullets:**
- Windows 11 + WSL2 Ubuntu 26.04, Docker Engine nativo, 16 GB de RAM totais
- Nephio R6 (`v6.0.0`), Porch v1.5.6, kpt v1.0.0
- `.wslconfig`: teto de 10 GB para todo o laboratório
- 100% local — sem cloud paga, sem OpenStack

**Figura sugerida:** tabela de especificações (`report/part2-report.md` §2).

**Fala do apresentador:**
"Nada disso rodou em nuvem. É o notebook, com WSL2, dentro de um orçamento de RAM apertado."

---

### Slide 4 — Nephio (recapitulando)

**Bullets:**
- Porch = orquestração de pacotes ("kpt-as-a-service")
- kpt = pacotes como *Configuration as Data*
- Ciclo de um pacote: Draft → Proposed → Published
- GitOps: o repositório é a fonte de verdade

**Figura sugerida:** o diagrama de ciclo de vida do PackageRevision.

**Fala do apresentador:**
"Relembrando rápido os conceitos da Parte 1, porque vou usá-los ao vivo agora."

---

### Slide 5 — As Network Functions

**Bullets:**
- `oran-cu`, `oran-du`, `oran-core` — FastAPI, ~30–50 MiB de RAM cada
- `/health`, `/config` (GET/PUT), `/metrics` (Prometheus)
- **Workloads representativos — não NFs O-RAN reais** (sem F1/E1/E2, sem plano de usuário)
- Avaliei substituir por free5GC/UERANSIM/OAI — não coube no orçamento (docs/real-nf-extension.md)

**Figura sugerida:** tabela das 3 NFs com suas rotas e config de exemplo.

**Fala do apresentador:**
"Deixo bem claro: isso é um simulador leve para exercitar mecanismos, não uma pilha 5G real. Já
avaliei o caminho para NFs reais e documentei por que não coube aqui."

---

### Slide 6 — Fluxo de provisionamento

**Bullets:**
- Pacote kpt autoral (`lab/nephio/openran-cnfs`) → Porch (`porchctl rpkg init/push/propose/approve`)
- `PackageRevision` Published no repositório `openran-cnfs`
- `kpt live apply` no `o-cloud-1` — reconciliação declarativa com `ResourceGroup` (inventário)
- **Experimento 1: 20,4 s do zero até 3/3 NFs Running**

**Figura sugerida:** sequência do `docs/provisioning-flow.md` §1.

**Fala do apresentador:**
"Esse não é um `kubectl apply`. É um pacote publicado, versionado, com histórico — o mesmo
mecanismo que o Nephio usa para qualquer coisa em produção."

---

### Slide 7 — Demonstração ao vivo (início)

**Bullets:**
- `kubectl --context o-cloud-1 -n openran-lab get deploy,pods,svc`
- Mostrar as 3 NFs `Running`
- `curl`/`exec` no `/health` de uma delas

**Figura sugerida:** (ao vivo, sem figura).

**Fala do apresentador:**
"Vamos ver isso rodando de verdade agora." *(ver roteiro completo em `demo/demo-script.md`)*

---

### Slide 8 — Config update

**Bullets:**
- `oran-du`: `cell_id` `1 → 2` via `PUT /config` — **0,7 s**
- Camada operacional da NF (análoga a O1/NETCONF numa NF real) — API REST própria, não O1
- Distinto da config de **implantação** (pacote/Porch) — usada no upgrade (slide 10)

**Figura sugerida:** JSON antes/depois do `/config`.

**Fala do apresentador:**
"Duas camadas de configuração, de propósito diferente — mostro as duas ao longo da apresentação
sem misturar uma com a outra."

---

### Slide 9 — Scaling

**Bullets:**
- `oran-cu`: 1 → 2 réplicas — **5,7 s**
- `kubectl scale` + `rollout status`
- Mesmo mecanismo de reconciliação do Kubernetes usado na Parte 1

**Figura sugerida:** `kubectl get pods` antes/depois.

**Fala do apresentador:**
"Rápido e direto — o controller do Deployment faz o trabalho."

---

### Slide 10 — Upgrade (achado real incluso)

**Bullets:**
- `oran-cu`: `NF_VERSION` v1 → v2, via **atualização do pacote no Porch** — **15,0 s**
- `revision` do Deployment: 1 → 2 (rollout real, `rollout history`)
- **Achado real:** só mudar o `ConfigMap` não disparou rollout — corrigido com uma anotação de
  versão no template do Pod

**Figura sugerida:** print do log do bug + da correção (`docs/provisioning-flow.md`).

**Fala do apresentador:**
"Esse foi o experimento mais instrutivo: bati de frente com um comportamento real do
Kubernetes, descobri a causa e corrigi — vou mostrar exatamente onde."

---

### Slide 11 — Fault / recovery

**Bullets:**
- `oran-du`: `kubectl delete pod` → novo pod em **3,9 s**
- *Self-healing* do Kubernetes (desired state vs. actual state) — **não** healing de NF telecom
- Sem estado de sessão, sem re-registro em interfaces O-RAN

**Figura sugerida:** pod antigo → deletado → pod novo (nomes diferentes).

**Fala do apresentador:**
"Reconciliação declarativa clássica. Deixo claro que isto não é 'cura' de uma função de rede —
é o Kubernetes mantendo o número de réplicas desejado."

---

### Slide 12 — Monitoring

**Bullets:**
- `/metrics` de cada NF em formato Prometheus (`nf_up`, `nf_requests_total`, `nf_config_version`, `nf_restart_count`)
- Sem Prometheus/Grafana instalados — opção leve por decisão de orçamento de RAM
- `docker stats`/`free -h` para custo real de host

**Figura sugerida:** saída real de `/metrics`.

**Fala do apresentador:**
"Não é telemetria O-RAN — é o suficiente para monitorar o laboratório sem pesar o ambiente."

---

### Slide 13 — Lifecycle (visão consolidada)

**Bullets:**
- Instantiate (20,4s) → Scale (5,7s) → Update (15,0s) → Recover (3,9s) → **Terminate (10,8s)**
- Terminate: `oran-core` removido via **prune** do `kpt live apply` (via pacote, não `kubectl delete` manual)
- 6/6 experimentos formais: `success`

**Figura sugerida:** tabela do `results/experiments.csv`.

**Fala do apresentador:**
"Da instanciação até a remoção — cada etapa, medida e registrada, não só narrada."

---

### Slide 14 — Resultados e limitações

**Bullets:**
- ~3,9 GiB de RAM total (Nephio + O-Cloud + CNFs) dentro de um teto de 9,7 GiB
- 2 bugs de engenharia reais encontrados **e corrigidos** (não escondidos)
- Limitações: sem GitOps contínuo no `o-cloud-1`, sem O1, sem NF real, sem telemetria O-RAN

**Figura sugerida:** tabela de RAM por componente (`report/part2-report.md` §13).

**Fala do apresentador:**
"Prefiro mostrar os dois bugs reais que encontrei a esconder que existiram — isso é mais
valioso academicamente do que fingir que tudo saiu perfeito na primeira tentativa."

---

### Slide 15 — Conclusão

**Bullets:**
- O Nephio orquestrou o ciclo de vida completo de CNFs usando seus mecanismos nativos — não `kubectl apply`
- Provisioning, config, scaling, upgrade, recovery e termination, todos demonstrados e medidos
- O que é abstração: as NFs, o O-Cloud, a ausência de GitOps contínuo na carga
- O que é real: o mecanismo Porch/kpt/reconciliação, e o provisionamento do O-Cloud via O2 IMS

**Figura sugerida:** repetir o diagrama de arquitetura do Slide 2, agora "completo".

**Fala do apresentador:**
"Entre teoria (Parte 1) e prática (Parte 2), a mesma conclusão se sustenta: o Nephio é uma
plataforma de automação cloud-native real, que implementa um subconjunto bem definido — e
demonstrado — das funções associadas ao SMO. Obrigado."
