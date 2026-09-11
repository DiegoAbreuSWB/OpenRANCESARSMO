# Nephio × SMO — o que é implementado, o que é apoiado, o que não existe (Fase 3)

> Parte crítica deste trabalho. Fontes: `docs/references.md` itens 12–19 (Nephio docs oficiais +
> O-RAN Alliance/O-RAN-SC) e evidência real do laboratório (`docs/03-o2ims-discovery.md`,
> `docs/05-experiment-report.md`).

## 1. O que é SMO segundo a O-RAN Alliance

O **Service Management and Orchestration (SMO)** é o framework de gerência da arquitetura
O-RAN responsável por orquestrar e gerenciar todos os elementos RAN e a infraestrutura de nuvem
(O-Cloud) sobre a qual eles rodam. Segundo o O-RAN Software Community (projeto OAM), o SMO
**"terminates O1, O2 interfaces, and the A1 interface (in the Non-RealTime RIC)"**. É descrito
como uma **plataforma multi-componente** — não uma ferramenta única — tipicamente incluindo:
terminação O1 (NETCONF/YANG + REST/VES), terminação O2, hospedagem do **Non-RT RIC** (que
termina A1), dashboards, bases de dados persistentes, servidor de certificados e logging
centralizado, normalmente conectados por um *message bus*.

## 2. Responsabilidades do SMO (segundo O-RAN WG1/WG6, síntese)

- **FCAPS** (Fault, Configuration, Accounting, Performance, Security) dos elementos RAN, via O1.
- **Gerenciamento do O-Cloud** (inventário, provisionamento, lifecycle da infraestrutura de
  nuvem e das NFs nela hospedadas), via O2 (O2 IMS + O2 DMS).
- **Non-RT RIC** — políticas (A1) e rApps para otimização não tempo-real do RAN.
- **Inventário e topologia** de toda a rede gerenciada.
- **Orquestração de ponta a ponta** de serviços e NFs (onboarding, instanciação, escala,
  atualização, terminação).
- **Catálogo de NFs/serviços** e políticas de deployment.

## 3. Tabela — Função × SMO × Nephio

| Função | Responsabilidade do SMO | Nephio oferece? | Como (evidência real) | Limitação |
|---|---|---|---|---|
| **Provisioning** (infra) | Provisionar recursos de O-Cloud sob demanda | ✅ **Sim, demonstrado** | `ProvisioningRequest` (O2 IMS) → `PackageVariant` (Porch) → `Cluster` (Cluster API/CAPD) → cluster real provisionado (`docs/05` §6) | Provider = Docker/CAPD; não OpenStack/bare-metal/cloud real |
| **Configuration management** | FCAPS-C de elementos RAN via O1 (NETCONF/YANG) | ⚠️ **Parcial, indireto** | Nephio versiona/propaga *configuração de pacotes Kubernetes* (KRM) via kpt/Porch/Config Sync — não configuração de elementos de rede via NETCONF | **Não** implementa O1; não configura um O-DU/O-CU físico ou um NMS externo |
| **Orchestration** | Orquestração de serviços/NFs ponta a ponta, multi-domínio | ⚠️ **Parcial** | Orquestração de **pacotes** (Porch/kpt) e de infraestrutura de cluster (Cluster API); demonstrado neste laboratório em escala de 1 workload cluster | Sem orquestração de serviço multi-domínio/multi-fornecedor no nível do ONAP; sem catálogo de serviço formal |
| **Lifecycle management** | Onboarding/instanciação/escala/update/healing/terminação de NFs | ✅ **Sim, para o ciclo de vida Kubernetes** | Demonstrado: instantiate, scale 1→3, update (rollout), recover (reconciliação), terminate — `docs/05` §8 | É o ciclo de vida do **Kubernetes** (Deployment/ReplicaSet), não um ciclo de vida *NF-aware* com KPIs O-RAN, re-registro em interfaces, ou *healing* orientado a causa-raiz |
| **O-Cloud management** | Inventário, lifecycle da infraestrutura O-Cloud (IMS+DMS) | ⚠️ **Parcial, PoC** | Operador O2 IMS cria/observa `Cluster`s (função de IMS); `WorkloadCluster`/`ClusterContext` (Nephio) dão uma visão básica de inventário | Sem inventário de hardware/acelerador, sem NFVI/VIM completos; a própria doc do Nephio admite suporte parcial ("R4... supports the O-Cloud Node Cluster creation **as part of** the O-Cloud Cluster Lifecycle Management service") |
| **Monitoring** | Coleta de estado operacional da rede | ❌ **Não incluído nativamente** | Nenhum stack de monitoramento é instalado por padrão pelo Nephio | Depende de ferramentas externas (Prometheus, etc.); neste laboratório usamos `kubectl`/`docker stats`/logs (Opção A da Fase 14) |
| **Telemetry** | Streaming de métricas/KPIs de rede (O1 PM, VES) | ❌ **Não implementado** | — | Sem suporte a VES ou PM Job O1; fora do escopo do Nephio Core |
| **Fault management** | Detecção/correlação/alarmes O1-FM | ⚠️ **Apenas no nível Kubernetes** | *Self-healing* via ReplicaSet (pod deletado → recriado), demonstrado no Experimento 4 | **Não** é FM O-RAN: sem alarmes O1, sem correlação de eventos, sem VES |
| **O1** | Interface de gerência FCAPS com elementos RAN | ❌ **Não implementado** | Nenhuma CRD, controller ou serviço O1 foi encontrado na descoberta do cluster (`docs/03-o2ims-discovery.md`) | Precisaria de um componente externo (ex.: O-RAN-SC OAM/SMO, ou um NMS dedicado) |
| **O2** | Interface SMO↔O-Cloud (IMS/DMS) | ✅ **Sim, como PoC** | CRD `provisioningrequests.o2ims.provisioning.oran.org` + `o2ims-operator`, fluxo completo demonstrado e evidenciado | O próprio pacote se declara *"work-in-progress in O-RAN standards... a PoC"`; `oCloudNodeClusterId` é um UUID local, não um id de inventário O2 real |
| **Non-RT RIC** | Hospedagem de rApps, políticas A1 | ❌ **Não implementado** | Não instalado/não faz parte do Nephio Core | É um projeto separado (O-RAN-SC Non-RT RIC / SMO); Nephio não o substitui |
| **Policy** | Distribuição de políticas A1 para o Near-RT RIC | ❌ **Não implementado** | — | Sem CRDs/controllers de política A1 no cluster |
| **Inventory** | Inventário completo de rede/infra/NF | ⚠️ **Parcial** | `WorkloadCluster`, `ClusterContext`, `Repository`, `PackageRevision` dão um inventário de *pacotes e clusters* | Sem inventário de elementos de rádio, sem topologia RAN, sem inventário de hardware O-Cloud |

## 4. Síntese

| Categoria | Funções |
|---|---|
| **Nephio implementa diretamente** (com evidência real neste laboratório) | Provisioning de infraestrutura (via O2 IMS PoC), lifecycle de deployment Kubernetes, parte de O-Cloud management (criação de cluster) |
| **Nephio apenas apoia / parcialmente** | Configuration management (config de pacotes K8s, não O1), orchestration (de pacotes, não de serviço multi-domínio), fault management (nível K8s, não O1-FM), inventory (de clusters/pacotes, não de rede) |
| **Nephio NÃO implementa** | O1, monitoring/telemetria nativos, Non-RT RIC, policy (A1) |

**Conclusão da Fase 3:** Nephio é uma plataforma de automação cloud-native cujo núcleo
(Kubernetes + GitOps + kpt/Porch) é **agnóstico de telecom**; ele se conecta ao mundo O-RAN por
meio de **operadores e pacotes específicos** (O2 IMS, FOCOM) que implementam **partes** das
funções do SMO — principalmente relacionadas a **O2/O-Cloud** e ao **ciclo de vida de
deployment de NFs cloud-native**. As funções mais próximas do "SMO clássico" de telecom
(O1/FCAPS, Non-RT RIC/A1, telemetria de rede) **não fazem parte do Nephio** e exigiriam
integração com outros componentes (ex.: O-RAN-SC OAM, um Non-RT RIC dedicado).
