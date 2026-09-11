# Apresentação — Parte 1
## Plataformas de SMO para Open RAN: uma análise do Nephio

> 15 slides · alvo de 15–20 minutos (~1–1,5 min/slide). Fonte: [`report/part1-report.md`](../report/part1-report.md).

---

### Slide 1 — Título

**Título:** Plataformas de Service Management and Orchestration (SMO) para Open RAN: o caso Nephio

**Bullets:**
- Disciplina: redes Open RAN — Parte 1 (30%)
- Ferramenta analisada: **Nephio** (Linux Foundation Networking)
- Foco: arquitetura, funções de SMO, interfaces O1/O2, O-Cloud, NF lifecycle
- Autor / data

**Figura sugerida:** logo do Nephio + logo O-RAN Alliance lado a lado, sem sobrepor (evitar
sugerir afiliação oficial).

**Fala do apresentador:**
"Bom dia/tarde. Meu trabalho analisa o Nephio como plataforma de automação para Open RAN. Já
adianto a tese central: vou mostrar o que o Nephio **realmente** faz — com evidência prática —
e onde ele **não** cobre o escopo completo do SMO definido pela O-RAN Alliance."

---

### Slide 2 — Open RAN e o papel do SMO

**Bullets:**
- Open RAN desagrega o RAN: O-RU, O-DU, O-CU (CP/UP), conectados por interfaces abertas
- Introduz dois controladores de inteligência: Near-RT RIC e Non-RT RIC
- **SMO** = framework de gerência de topo da arquitetura O-RAN
- Termina as interfaces **O1**, **O2** e **A1** (via Non-RT RIC)

**Figura sugerida:** diagrama oficial simplificado da arquitetura O-RAN (SMO no topo, O1 para
O-CU/O-DU/Near-RT RIC, O2 para O-Cloud, A1 para Near-RT RIC).

**Fala do apresentador:**
"O Open RAN só funciona na prática se existir uma camada central de gerência. É isso que o SMO
faz: ele fala com os elementos de rede via O1, com a infraestrutura de nuvem via O2, e distribui
políticas para o Near-RT RIC via A1."

---

### Slide 3 — Por que o SMO é necessário

**Bullets:**
- Multi-fornecedor só funciona com orquestração central e interfaces padronizadas
- Sem SMO: integração manual, sem escala, sem automação de ciclo de vida
- Responsabilidades: FCAPS, gerenciamento de O-Cloud, inventário, políticas, orquestração
  ponta a ponta
- É uma **arquitetura de responsabilidades**, não um produto único

**Figura sugerida:** tabela simples com as 5 responsabilidades do SMO.

**Fala do apresentador:**
"Sem essa camada, a promessa de 'abertura' do Open RAN não se sustenta operacionalmente —
seria preciso integrar manualmente dezenas de componentes de fornecedores diferentes."

---

### Slide 4 — O que é Nephio

**Bullets:**
- Projeto **graduado da Linux Foundation Networking** (2022, LF + Google Cloud)
- *"Carrier-grade, simple, open, Kubernetes-based cloud native intent automation"*
- Núcleo **agnóstico de telecom**: Kubernetes + Configuration as Data (kpt) + GitOps
- Conecta-se ao O-RAN via operadores específicos (O2 IMS, FOCOM) — não é o SMO em si

**Figura sugerida:** citação em destaque: *"Nephio is a cloud-native automation and
orchestration platform that can implement or support functions associated with the SMO and
O-Cloud management architecture."*

**Fala do apresentador:**
"Esta frase é a tese do meu trabalho. Nephio **pode implementar ou apoiar** funções do SMO —
não é, ele próprio, o SMO oficial da especificação O-RAN."

---

### Slide 5 — Arquitetura

**Bullets:**
- **Management Cluster**: Nephio Core, Porch, repositório de pacotes, Config Sync
- **Workload Cluster(s)**: onde as CNFs rodam, reconciliadas via GitOps
- Porch = *"kpt-as-a-service"* — API Kubernetes para gerenciar pacotes
- kpt = toolchain *"package-centric"* sobre *Configuration as Data*

**Figura sugerida:** diagrama Mermaid do `docs/nephio-architecture.md` §3 (Management → Nephio →
Porch/kpt/Package Repository → Workload Cluster → CNFs).

**Fala do apresentador:**
"Dois tipos de cluster: um de gestão, que decide o quê e como configurar, e um ou mais de
carga, onde as funções de rede realmente rodam."

---

### Slide 6 — Componentes

**Bullets:**
- `Repository` — repositório Git/OCI registrado no Porch (read-only ou deployment)
- `PackageRevision` — uma revisão de pacote (Draft → Proposed → Published)
- `PackageVariant` / `PackageVariantSet` — gera variações de um pacote para um ou mais destinos
- Controllers Kubernetes reconciliam cada uma dessas CRDs continuamente

**Figura sugerida:** diagrama de estados do `PackageRevision` (Draft → Proposed → Published).

**Fala do apresentador:**
"Esses não são conceitos abstratos — são CRDs reais que instalei e observei rodando no meu
cluster de laboratório."

---

### Slide 7 — GitOps e automação orientada a intenção

**Bullets:**
- **GitOps**: o Git é a fonte de verdade; um agente reconcilia o cluster a partir dele
- Config Sync = a ferramenta GitOps usada pelo Nephio
- Mesmo padrão do *control loop* oficial do Kubernetes: *"move o estado atual em direção ao
  estado desejado"*
- **Intent** = uma declaração de alto nível (CR) que a cadeia de controllers traduz em recursos
  concretos

**Figura sugerida:** diagrama de fluxo Intent → Package → Repository → Reconciliation →
Kubernetes → CNF.

**Fala do apresentador:**
"O operador nunca escreve manifesto de baixo nível — declara a intenção, e a cadeia de
controllers cuida do resto."

---

### Slide 8 — Provisionamento

**Bullets:**
- Fluxo: `ProvisioningRequest` (intent) → `PackageVariant` (Porch) → `PackageRevision`
  (publicada no Git) → reconciliação (Config Sync) → `Cluster` real
- Dois níveis de orquestração: de **pacotes** (Porch) e de **infraestrutura** (Cluster API)
- **Demonstrado no laboratório**: um único objeto declarativo gerou um cluster Kubernetes real
  de 2 nós

**Figura sugerida:** o mesmo diagrama de sequência do `docs/04-architecture.md` §2.

**Fala do apresentador:**
"Isso não é teoria — apliquei um `ProvisioningRequest` e, minutos depois, tinha um segundo
cluster Kubernetes rodando, criado inteiramente por essa cadeia."

---

### Slide 9 — Interface O1

**Bullets:**
- O1 = gerência **FCAPS** entre SMO e elementos RAN (O-CU, O-DU, Near-RT RIC)
- Configuração via NETCONF/YANG; notificações via REST/VES
- **Nephio não implementa O1** — confirmado por descoberta completa do cluster (76 CRDs, nenhuma
  relacionada a O1)
- Essa função pertence, no ecossistema O-RAN, ao projeto O-RAN-SC OAM

**Figura sugerida:** ícone de "❌" sobre o bloco O1 no diagrama de arquitetura O-RAN.

**Fala do apresentador:**
"Sou direto aqui: não encontrei, no cluster real, nenhum componente de O1. É uma lacuna real,
não um detalhe."

---

### Slide 10 — Interface O2

**Bullets:**
- O2 = interface SMO ↔ O-Cloud; dividida em **O2 IMS** (infraestrutura) e **O2 DMS** (deployment)
- Nephio R6 implementa uma **PoC funcional de O2 IMS**: CRD `ProvisioningRequest`
  (`o2ims.provisioning.oran.org`)
- Fluxo **executado e validado**: `provisioningState: fulfilled`
- O próprio pacote se declara *"work-in-progress in O-RAN standards... a PoC"*

**Figura sugerida:** print/trecho do `status` real do `ProvisioningRequest` (evidência).

**Fala do apresentador:**
"Aqui o Nephio entrega de verdade — vou mostrar na Parte 2 o `status: fulfilled` saindo do
cluster real, não de um slide."

---

### Slide 11 — O-Cloud

**Bullets:**
- O-Cloud = plataforma de nuvem (NFVI + VIM + aceleradores) que hospeda as NFs O-RAN
- Nephio provisiona **O-Cloud Node Cluster** via O2 IMS + Cluster API — capacidade parcial,
  reconhecida pela própria documentação oficial
- Sem inventário de hardware/aceleradores, sem NFVI/VIM completos
- No laboratório: um cluster kind representa academicamente o O-Cloud

**Figura sugerida:** diagrama "O-Cloud real" vs. "representação acadêmica" lado a lado.

**Fala do apresentador:**
"É importante ser honesto: o que chamo de O-Cloud aqui é um cluster Kubernetes local, sem
hardware nem rede de transporte reais — mas provisionado pelo mecanismo certo."

---

### Slide 12 — Ciclo de vida de Network Functions

**Bullets:**
- Demonstrado: **instantiate → scale → update → recover → terminate**
- Mecanismo: Deployment/ReplicaSet do Kubernetes, não um ciclo de vida *NF-aware* O-RAN
- Sem KPIs de rede, sem re-registro em interfaces O-RAN, sem healing orientado a causa-raiz
- Base para os experimentos práticos da Parte 2

**Figura sugerida:** linha do tempo com os 5 estágios.

**Fala do apresentador:**
"O que demonstro é lifecycle de **Kubernetes**. Não confundo isso com lifecycle de uma NF de
telecom real — a diferença é central para o meu trabalho."

---

### Slide 13 — Monitoramento e falhas

**Bullets:**
- Nephio **não inclui** stack de monitoramento/telemetria nativo
- Sem coleta de KPI O1/PM, sem VES
- Fault management observável = *self-healing* padrão do Kubernetes (não FCAPS-F O-RAN)
- No laboratório: `kubectl`/`docker stats`/logs — opção leve, compatível com 16 GB de RAM

**Figura sugerida:** comparação "o que existe" (kubectl/eventos) vs. "o que seria FM O-RAN"
(alarmes O1, VES, correlação).

**Fala do apresentador:**
"Decidi não instalar Prometheus/Grafana para manter o laboratório leve — e isso também ilustra
bem os limites reais do que o Nephio entrega de fábrica."

---

### Slide 14 — Comparação com outras soluções

**Bullets:**
- ONAP / ETSI OSM / O-RAN-SC SMO: dezenas de GB de RAM, inviáveis no orçamento deste trabalho
- OpenStack Tacker: dependente de OpenStack, indisponível no ambiente
- Nephio: **nativamente Kubernetes**, laboratório completo em ~3,6 GiB medidos
- Contrapartida: nenhuma cobertura de O1/Non-RT RIC, diferente das alternativas "pesadas"

**Figura sugerida:** tabela resumida de `docs/tool-comparison.md` (Foco / O1 / O2 / recursos).

**Fala do apresentador:**
"A escolha do Nephio não foi só teórica — foi a única viável dentro da restrição real de
hardware que eu tinha disponível."

---

### Slide 15 — Conclusão

**Bullets:**
- Nephio é uma **plataforma de automação cloud-native efetiva**, com evidência real de
  provisioning (O2 IMS) e lifecycle Kubernetes
- **Não é** uma implementação completa/certificada do SMO — faltam O1, Non-RT RIC, telemetria,
  política A1
- Essa caracterização precisa é a base da Parte 2: provisionamento e gerenciamento prático de
  uma pilha Open RAN simulada
- Próximo passo: demonstração ao vivo (Parte 2)

**Figura sugerida:** a mesma citação-tese do Slide 4, repetida para fechar o argumento.

**Fala do apresentador:**
"Fico com uma conclusão equilibrada: o Nephio entrega automação real e demonstrável para uma
fatia bem definida do escopo do SMO — e eu mostrei, com evidência, exatamente onde essa fatia
termina. Obrigado — perguntas?"
