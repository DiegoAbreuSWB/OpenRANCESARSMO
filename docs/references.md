# References (Fase 1 — Pesquisa Teórica)

> Data de acesso de todas as fontes: **2026-09-11**, salvo indicação em contrário (fontes já
> usadas no laboratório prático de 09–10/09/2026 estão marcadas *"acesso 2026-09-09/10"*).
> Prioridade: documentação oficial (Nephio, Linux Foundation, O-RAN Alliance, O-RAN Software
> Community, Kubernetes, kpt/CNCF). Fontes secundárias (blogs técnicos) usadas **apenas**
> quando não havia página oficial pública equivalente, e marcadas explicitamente como tal.

Cada entrada: **URL · Título · Seção usada · Do que trata / trecho-chave**

---

## 1. Nephio — projeto, governança, releases

1. **URL:** https://nephio.org/
   **Título:** "Nephio – Linux Foundation Project"
   **Seção:** página inicial / sobre o projeto
   **Uso:** Nephio como projeto graduado da **Linux Foundation Networking**; missão de
   "carrier-grade, simple, open, Kubernetes-based cloud native intent automation".

2. **URL:** https://www.linuxfoundation.org/press/project-nephio-joins-lf-networking-to-accelerate-cloud-native-automation-on-kubernetes
   **Título:** "Project Nephio Joins LF Networking to Accelerate Cloud Native Automation on Kubernetes"
   **Seção:** release/comunicado
   **Uso:** Nephio nasceu como colaboração Linux Foundation + Google Cloud (2022) e depois
   ingressou na LF Networking; contexto de governança.

3. **URL:** https://docs.nephio.org/docs/release-notes/r6/
   **Título:** "Nephio R6 Release Notes"
   **Seção:** release notes R6
   **Uso:** release usada no laboratório (`v6.0.0`, 2026-02-13); Porch v1.5.6; K8s v1.26–v1.32
   suportado; **"O2 IMS REST Provision API added"**. *(acesso 2026-09-09)*

4. **URL:** https://github.com/nephio-project/nephio (releases)
   **Título:** repositório oficial `nephio-project/nephio`
   **Seção:** tags/releases
   **Uso:** confirmação da tag `v6.0.0` como última release estável. *(acesso 2026-09-09)*

5. **URL:** https://github.com/nephio-project/catalog (branch `v6`)
   **Título:** "Nephio Package Catalog"
   **Seção:** árvore de diretórios `nephio/core`, `nephio/optional`, `infra/capi`, `distros/sandbox`
   **Uso:** estrutura real dos pacotes kpt instaláveis (Porch, nephio-operator, Config Sync,
   Cluster API/CAPD, O2 IMS, FOCOM, resource-backend, MetalLB). *(acesso 2026-09-10)*

---

## 2. Nephio — arquitetura, Porch, kpt, GitOps

6. **URL:** https://docs.nephio.org/docs/architecture/
   **Título:** "Architecture" (Nephio Documentation)
   **Seção:** visão C4 (System Context / System Landscape / Component views)
   **Uso:** "Nephio Core: a collection of operators and functions that perform the fundamental
   aspects of Nephio use cases"; Porch como componente arquitetural central.

7. **URL:** https://docs.nephio.org/docs/porch/
   **Título:** "Porch" (Nephio Documentation)
   **Seção:** definição e histórico
   **Uso:** Porch = **"kpt-as-a-service"**, entrega *"opinionated package management,
   manipulation, and lifecycle operations in a Kubernetes-based API"*. Nasceu dentro do
   projeto kpt; quando o kpt foi doado à CNCF, o código do Porch foi doado ao Nephio.

8. **URL:** https://kpt.dev/
   **Título:** "kpt" (site oficial)
   **Seção:** página inicial
   **Uso:** kpt = *"a package-centric toolchain that enables a WYSIWYG configuration authoring,
   automation, and delivery experience"*; simplifica *"managing Kubernetes platforms and
   KRM-driven infrastructure at scale by manipulating declarative Configuration as Data"*.
   Projeto CNCF Sandbox.

9. **URL:** https://docs.nephio.org/docs/guides/install-guides/common-components/
   **Título:** "Installing base Nephio components" (Nephio Documentation)
   **Seção:** "Management Cluster GitOps Tool"
   **Uso:** Config Sync é *"installed to allow GitOps-based application of packages on the
   management cluster itself"*; *"not needed if you only want to provision network functions,
   but it is used extensively in the cluster provisioning workflows"*. Repositórios "stock"
   (read-only, apontando para o GitHub) usados nos exercícios oficiais.

10. **URL:** (busca agregada sobre exercícios oficiais de GitOps/ArgoCD do Nephio,
    `docs.nephio.org/docs/guides/user-guides/usecase-user-guides/exercise-5-argocd-wl/` e páginas
    correlatas)
    **Título:** Nephio user guides — GitOps / Config Sync
    **Seção:** conceito de repositório *blueprint* vs. *deployment*
    **Uso:** *"Config Sync is a GitOps-based deployment mechanism that distributes and deploys
    configuration, and provides observability of the status of deployed resources"*;
    repositórios de *deployment* são "fully hydrated" e observados pelo Config Sync no
    workload cluster.

11. **URL:** https://kubernetes.io/docs/concepts/architecture/controller/
    **Título:** "Controllers" (Kubernetes Documentation)
    **Seção:** "Controller pattern", "Desired versus current state"
    **Uso:** definição oficial do padrão *controller/control loop* que fundamenta GitOps e a
    reconciliação usada pelo Nephio/Config Sync/Porch: *"controllers are control loops that
    watch the state of your cluster, then make or request changes where needed. Each
    controller tries to move the current cluster state closer to the desired state."*

---

## 3. Nephio × O-RAN / O2 / FOCOM / O-Cloud

12. **URL:** https://docs.nephio.org/docs/network-architecture/o-ran-integration/
    **Título:** "O-RAN Integration" (Nephio Documentation)
    **Seção:** relação com FOCOM, NFO, IMS, DMS
    **Uso:** Nephio *"provide[s] a reference implementation of the [O-RAN] Alliance's
    cloud-centric specifications"*, com foco em **FOCOM** (Federated O-Cloud Orchestration and
    Management), **NFO** (Network Function Orchestration), **IMS** (Infrastructure Management)
    e **DMS** (Deployment Management). Explicita que a implementação é **parcial**: *"In R4 the
    Nephio implementation supports the O-Cloud Node Cluster creation as part of the O-Cloud
    Cluster Lifecycle Management service"* — ou seja, um subconjunto do FOCOM/IMS completo.
    FOCOM pode interagir com O-Clouds "that use other non-Nephio capabilities" — reforça que
    Nephio é **uma** implementação possível, não *o* SMO. *(acesso 2026-09-10)*

13. **URL:** https://docs.nephio.org/docs/guides/user-guides/usecase-user-guides/exercise-4-o2ims/
    **Título:** "O-RAN O2 IMS Operator Deployment" (Nephio Documentation)
    **Seção:** exercício oficial de provisionamento via `ProvisioningRequest`
    **Uso:** procedimento oficial (repositórios `catalog-infra-capi`, `mgmt`, `mgmt-staging`,
    manifesto `ProvisioningRequest`) reproduzido no laboratório prático. *(acesso 2026-09-10)*

14. **URL:** https://docs.nephio.org/docs/guides/user-guides/usecase-user-guides/exercise-4-ocloud-cluster-prov/
    **Título:** "O-RAN O-Cloud K8s Cluster deployment" (Nephio Documentation)
    **Seção:** fluxo FOCOM (`OCloud`, `Secret`, `FocomProvisioningRequest`) com cluster SMO
    separado
    **Uso:** topologia canônica de dois clusters (SMO + O-Cloud) para o padrão FOCOM completo —
    não replicada integralmente no laboratório (RAM), documentado como limitação.
    *(acesso 2026-09-10)*

15. **URL:** `github.com/nephio-project/catalog` (branch `v6`) — pacote `nephio/optional/o2ims`,
    arquivo `crd/o2ims.provisioning.oran.org_provisioningrequests.yaml`
    **Título:** CRD `ProvisioningRequest`
    **Seção:** schema completo (`spec.templateName/templateVersion/templateParameters`,
    `status.provisioningStatus.provisioningState`)
    **Uso:** schema real, extraído do cluster + do repositório (não inventado). README do
    pacote: *"The CRD used by the operator is a work in-progress in O-RAN standards... a
    PoC"*, base **O-RAN.WG6.TS.O-CLOUD-IM.0-R004-v03.00**. *(acesso 2026-09-10, cluster local)*

16. **URL:** `github.com/nephio-project/nephio/tree/main/operators/o2ims-operator`
    **Título:** código-fonte do `o2ims-operator`
    **Seção:** `controllers/provisioning_request_controller.py`, `controllers/utils.py`
    **Uso:** comportamento real do operador (cria `PackageVariant`, observa `Cluster` do
    Cluster API) — base para a Fase 4/12 (fluxo de provisionamento). *(acesso 2026-09-10)*

---

## 4. O-RAN Alliance / O-RAN Software Community — SMO, O1, O2, O-Cloud (definições oficiais/semi-oficiais)

17. **URL:** https://www.o-ran.org/technical-groups/wg6
    **Título:** "O-RAN ALLIANCE e.V. — Technical Groups: WG6 (Cloudification and Orchestration)"
    **Seção:** escopo do WG6
    **Uso:** WG6 define requisitos e *reference designs* para a plataforma de nuvem do O-Cloud
    (NFVI, VIM, Accelerator Abstraction Layer) e o **O2** entre SMO e O-Cloud; O-Cloud = onde
    reside a funcionalidade de provedor de nuvem, conectado ao SMO via O2.

18. **URL:** https://lf-o-ran-sc.atlassian.net/wiki/display/OAM/SMO+-+Service+Management+and+Orchestration
    (O-RAN Software Community, projeto OAM)
    **Título:** "SMO - Service Management and Orchestration" (O-RAN-SC wiki)
    **Seção:** responsabilidades e componentes do SMO
    **Uso:** *"the SMO terminates O1, O2 interfaces, and the A1 interface (in the
    Non-RealTime RIC)"*; O1 usa NETCONF/YANG (configuração) + REST/VES (notificações
    assíncronas); A1 usa REST. Reforça o **SMO como plataforma multi-componente**
    (dashboards, bases persistentes, logging), não uma ferramenta única.
    *(nota: a própria página se declara desatualizada e aponta para o espaço de projeto SMO
    atual do O-RAN-SC — usada aqui apenas como definição estrutural estável de O1/A1/O2)*

19. **Síntese de especificação pública O-RAN.WG1 (Use Cases and Overall Architecture) e
    O-RAN.WG6 (Cloud Architecture and Deployment Scenarios)**, via páginas descritivas
    públicas do o-ran.org e cobertura técnica agregada (não foi possível acessar o PDF completo
    das especificações, que requer o portal de membros/clearinghouse do O-RAN Alliance)
    **Uso:** definição textual de O1 — *"operates between orchestration/management entities and
    O-RAN managed elements... by which FCAPS (fault, configuration, accounting, performance and
    security) management, software management, file management and other similar functions
    shall be achieved"* — e de O2 — *"supports orchestration of O-Cloud infrastructure resource
    management (e.g., inventory, monitoring, provisioning, software management and lifecycle
    management) and deployment of the Open RAN network functions"*.
    **Ressalva metodológica:** as especificações O-RAN.WG1/WG6 completas (PDF) ficam atrás do
    *O-RAN Specifications Clearinghouse*; usamos aqui a formulação textual tal como replicada
    nas páginas públicas de projeto (O-RAN-SC) e nos comunicados técnicos do próprio
    O-RAN ALLIANCE, não uma fonte comercial terceira.

---

## 5. Kubernetes / CNCF (fundamentação técnica)

20. **URL:** https://kubernetes.io/docs/concepts/architecture/controller/ — ver item 11.

21. **URL:** https://kind.sigs.k8s.io/ (kind — Kubernetes IN Docker)
    **Título:** documentação oficial do projeto `kind` (Kubernetes SIGs)
    **Uso:** runtime de cluster local usado no laboratório; escolhido pela leveza single-node.
    *(acesso 2026-09-09)*

22. **URL:** https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/
    **Título:** "Custom Resources" (Kubernetes Documentation)
    **Uso:** base conceitual para as CRDs O2 IMS/FOCOM/Nephio (extensão declarativa da API do
    Kubernetes) usadas na Fase 3/4.

---

## 6. Comparações (Fase 5) — fontes de projeto para cada ferramenta

23. **URL:** https://www.onap.org/ · **Título:** "ONAP" (site oficial, projeto LF Networking)
    **Uso:** escopo do ONAP (orquestração de serviço de ponta a ponta, VNF/CNF, muito mais
    amplo e pesado que o escopo deste laboratório).

24. **URL:** https://osm.etsi.org/ · **Título:** "ETSI OSM — Open Source MANO" (site oficial ETSI)
    **Uso:** OSM como implementação de referência do ETSI NFV MANO; ponto de comparação de
    modelo de orquestração (MANO vs. GitOps/KRM do Nephio).

25. **URL:** https://lf-o-ran-sc.atlassian.net/wiki/ (O-RAN-SC, projeto SMO)
    **Título:** "O-RAN Software Community — SMO project"
    **Uso:** implementação de referência do próprio O-RAN Alliance (via O-RAN-SC), ponto de
    comparação mais próximo conceitualmente de "SMO de referência".

26. **URL:** https://docs.openstack.org/tacker/latest/ · **Título:** "OpenStack Tacker" (docs oficiais)
    **Uso:** NFV MANO/VNF Manager de referência do ecossistema OpenStack; comparação de modelo
    de infraestrutura (VM/OpenStack vs. Kubernetes/CNF do Nephio).

---

## 7. Fontes do próprio laboratório prático (rastreabilidade)

As descobertas técnicas obtidas **diretamente do cluster real** (não de documentação) estão
registradas com evidência em:
- `docs/01-nephio-version.md` — decisão de versão e requisitos (fontes 1, 3, 4, 5 acima).
- `docs/02-nephio-installation.md` — instalação mínima e bugs de upstream corrigidos.
- `docs/03-o2ims-discovery.md` — schema real das CRDs O2 IMS/FOCOM via `kubectl explain` +
  `kubectl get crd -o yaml` + RBAC + logs (fontes 15, 16 acima).
- `docs/04-architecture.md` e `docs/05-experiment-report.md` — síntese arquitetural e resultado
  do fluxo `ProvisioningRequest → PackageVariant → Cluster → O-Cloud`.

## 8. Nota metodológica

Buscas web foram feitas em 2026-09-11 com a ferramenta de busca disponível; várias páginas
oficiais (`docs.nephio.org`, `kpt.dev`, `kubernetes.io`, `linuxfoundation.org`, `o-ran.org`,
O-RAN-SC wiki) foram acessadas diretamente. As especificações completas do O-RAN ALLIANCE
(PDFs O-RAN.WG1/WG6) estão atrás de um portal que não permite acesso automatizado direto; onde
isso ocorreu, a citação foi marcada explicitamente como **síntese de páginas públicas**, nunca
apresentada como texto literal da especificação. Nenhuma funcionalidade do Nephio foi inferida
sem confirmação em pelo menos uma fonte oficial ou no comportamento observado do cluster real.
