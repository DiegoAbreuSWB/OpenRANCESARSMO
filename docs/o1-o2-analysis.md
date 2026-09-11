# Análise das interfaces O1 e O2 (Fase 4)

> Fontes: `docs/references.md` itens 12–19. Parte de O2 é reaproveitada e aprofundada de
> `docs/03-o2ims-discovery.md`, que descobriu o schema **real** (não teórico) das CRDs no
> cluster do laboratório.

---

## 1. Interface O1

### 1.1 Função da interface

O1 é a interface de **gerência FCAPS** entre o SMO (mais especificamente as funções de
orquestração/NMS do SMO) e os **elementos gerenciados O-RAN** (Near-RT RIC, O-CU, O-DU,
O-RU indiretamente via O-DU). Segundo a síntese das especificações públicas O-RAN WG1:

> "The O1 Interface operates between orchestration and management entities (orchestration/NMS)
> and O-RAN managed elements for operation and management, by which FCAPS (fault, configuration,
> accounting, performance and security) management, software management, file management and
> other similar functions shall be achieved."

### 1.2 Quais elementos conecta

- **SMO ⟷ Near-RT RIC**
- **SMO ⟷ O-CU** (unidade central)
- **SMO ⟷ O-DU** (unidade distribuída)

(O-RU normalmente não termina O1 diretamente; é gerenciado via M-plane/O-DU.)

### 1.3 FCAPS via O1

| Domínio FCAPS | Mecanismo O1 | Descrição |
|---|---|---|
| **F**ault | Alarmes VES (REST/HTTP) | Notificações assíncronas de falha |
| **C**onfiguration | NETCONF/YANG (GET/SET) | Modelos de dados YANG específicos O-RAN para configurar os elementos |
| **A**ccounting | — | Uso/contabilização de recursos |
| **P**erformance | PM (Performance Measurement) Jobs, VES | Coleta periódica de KPIs |
| **S**ecurity | Certificados, TLS sobre NETCONF | Segurança do canal de gerência |

### 1.4 Nephio implementa O1?

**Não, diretamente não.** A descoberta feita no cluster real (`docs/03-o2ims-discovery.md`)
não encontrou **nenhuma** CRD, controller ou serviço relacionado a O1/NETCONF/YANG/VES entre os
76 CRDs instalados no `nephio-mgmt` (Nephio R6 mínimo + O2 IMS + FOCOM). Buscas nas
documentações oficiais do Nephio (`docs.nephio.org`) também não retornaram um componente de
terminação O1 no núcleo do projeto.

**Depende de outros componentes.** Terminação O1 é historicamente um escopo do projeto **O-RAN
Software Community (O-RAN-SC), subprojeto OAM** — que implementa um cliente NETCONF (para
configuração) e um servidor VES (para notificações). Se um trabalho quisesse demonstrar O1 de
fato, precisaria integrar (ou simular) um componente OAM/O1 separado — **fora do escopo deste
laboratório**, que prioriza O2/O-Cloud, onde o Nephio tem uma implementação real e testável.

**Como apresentar isso sem exagerar:** afirmar explicitamente, em qualquer slide/relatório, que
*"o Nephio, na configuração usada neste trabalho, não implementa a interface O1; a configuração
demonstrada é configuração de pacotes Kubernetes (KRM) via GitOps, não configuração de
elementos de rede via NETCONF/YANG"*. Ver Experimento 2 (`docs/provisioning-flow.md` e
`report/part2-report.md`) para a distinção prática entre os dois tipos de "configuration
management".

---

## 2. Interface O2

### 2.1 SMO ↔ O-Cloud

O2 é a interface entre o SMO e o **O-Cloud** — a plataforma de nuvem (NFVI + VIM + camada de
abstração de aceleradores, conforme O-RAN WG6) que hospeda as funções de rede O-RAN
"cloudificadas". Síntese das especificações públicas O-RAN WG6:

> "The O2 interface supports orchestration of O-Cloud infrastructure resource management (e.g.,
> inventory, monitoring, provisioning, software management and lifecycle management) and
> deployment of the Open RAN network functions, providing logical services for managing the
> lifecycle of deployments that use cloud resources."

O2 se divide, na arquitetura O-RAN, em dois planos de serviço:

- **O2 IMS (Infrastructure Management Services)** — gerência da infraestrutura de nuvem
  propriamente dita: inventário de recursos, **provisionamento de clusters/nodes**, monitoramento
  de capacidade.
- **O2 DMS (Deployment Management Services)** — gerência do **deployment das NFs** sobre essa
  infraestrutura: onboarding de pacotes de NF, instanciação, lifecycle.

### 2.2 O que foi confirmado no cluster real (não teórico)

| Elemento | Confirmado? | Detalhe |
|---|---|---|
| CRD `ProvisioningRequest` (`o2ims.provisioning.oran.org/v1alpha1`, cluster-scoped) | ✅ | schema real extraído via `kubectl explain` + `get crd -o yaml` |
| Operador `o2ims-operator` (kopf/Python) | ✅ | observa `ProvisioningRequest`, cria `PackageVariant`, observa `Cluster` (Cluster API) |
| CRDs `FocomProvisioningRequest`, `OCloud`, `TemplateInfo` (`focom.nephio.org` / `provisioning.oran.org`) | ✅ | lado "SMO" do fluxo (federação entre múltiplos O-Clouds) |
| Fluxo completo `ProvisioningRequest → PackageVariant → PackageRevision → Cluster → containers` | ✅ **executado e evidenciado** | `provisioningState: fulfilled`; cluster `o-cloud-1` real, 2 nós `Ready` (`docs/05-experiment-report.md` §6) |
| **"O2 IMS REST Provision API"** (nova no Nephio R6, conforme release notes) | ✅ existe no código (`controllers/northbound_restapi.py`) | não exercitada neste laboratório (usamos a via Kubernetes API/CRD diretamente, que é a forma nativa de operar o Nephio) |
| O2 DMS (deployment de NF propriamente dito, pós-provisionamento do cluster) | ⚠️ parcial | o `demo-nf` foi implantado via `kubectl apply` direto no workload cluster, não via um segundo `ProvisioningRequest`/pacote O2 DMS dedicado |

### 2.3 Qual parte do O2 está mais próxima do Nephio

**O2 IMS** é a parte com implementação mais concreta e demonstrável no Nephio R6: o
`o2ims-operator` recebe uma requisição de provisionamento e a traduz em infraestrutura real
(um `Cluster` do Cluster API, materializado como containers Docker no nosso ambiente). Isso é
literalmente a definição de IMS — "provisioning... of resources exposed by an O-Cloud".

**O2 DMS** é mais difuso no Nephio: a "deployment management" de NFs acontece através do
mecanismo genérico de pacotes (Porch/PackageVariant/Config Sync) — o mesmo mecanismo usado para
qualquer configuração Kubernetes, não uma API O2 DMS dedicada e separada. Não há, no cluster
investigado, uma CRD específica rotulada como "O2 DMS".

**Conclusão:** Nephio R6 implementa uma **PoC funcional de O2 IMS** (confirmada por execução
real, não apenas por leitura de documentação) e um mecanismo genérico e reutilizável — o próprio
Porch/GitOps — que **pode ser usado para** cumprir o papel de O2 DMS, mas sem uma API O2 DMS
formalmente exposta e rotulada como tal.

---

## 3. Resumo comparativo O1 × O2 no contexto Nephio

| | O1 | O2 |
|---|---|---|
| Implementado pelo Nephio? | ❌ Não | ✅ Parcial (IMS forte, DMS difuso) — PoC |
| Evidência neste laboratório | Nenhuma (CRD/controller ausente) | `ProvisioningRequest` → cluster real provisionado, `status: fulfilled` |
| O que seria necessário para cobrir a lacuna | Integração com O-RAN-SC OAM (cliente NETCONF + servidor VES) ou um NMS externo | Já coberto pelo O2 IMS; O2 DMS poderia ser formalizado com uma CRD/label dedicada sobre o mecanismo de pacotes existente |
| Nível de maturidade declarado pelo próprio projeto | N/A (não faz parte do escopo core) | "work-in-progress in O-RAN standards... a PoC" (README do pacote `o2ims`) |
