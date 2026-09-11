# Comparação com outras ferramentas (Fase 5)

> Fontes: `docs/references.md` itens 23–26 (páginas oficiais de cada projeto) + o próprio
> laboratório (linha "Nephio" preenchida com dados reais medidos, não estimativas).

## 1. Tabela comparativa

| | **ONAP** | **ETSI OSM** | **O-RAN-SC SMO** | **OpenStack Tacker** | **Nephio** (este trabalho) |
|---|---|---|---|---|---|
| **Foco** | Orquestração de serviço de ponta a ponta (VNF/CNF), operadoras de grande porte | MANO de referência ETSI NFV (VNF/CNF onboarding e lifecycle) | Implementação de referência do SMO O-RAN (O1/O2/A1, Non-RT RIC) | VNF Manager (VNFM) + NFVO dentro do ecossistema OpenStack | Automação cloud-native genérica (Kubernetes/GitOps), com operadores para casos de uso O-RAN |
| **SMO** | Não é rotulado "SMO", mas cobre funções sobrepostas (orquestração, políticas, assurance) | Não | **Sim** — é a implementação de referência do SMO da própria O-RAN Alliance | Não | Não — implementa **partes** de funções associadas ao SMO (ver `docs/nephio-vs-smo.md`) |
| **O1** | Não nativo (foco em VNF genérico, não RAN) | Não nativo | **Sim** (projeto OAM) | Não | **Não** |
| **O2** | Não | Não (modelo NFVI próprio, pré-O-RAN) | **Sim** (projeto O-Cloud/NONRTRIC integrations) | Não (modelo VIM OpenStack, não O2) | **Sim, PoC** (O2 IMS demonstrado neste laboratório) |
| **NF lifecycle** | Sim, amplo (VNF/CNF, multi-domínio) | Sim (VNF, foco em máquina virtual + CNF mais recentemente) | Sim (via integração com outros projetos O-RAN-SC) | Sim (VNF sobre OpenStack) | Sim, para o ciclo de vida **Kubernetes** de CNFs (demonstrado: instantiate/scale/update/recover/terminate) |
| **O-Cloud** | Não (conceito não existe fora do O-RAN) | Não | Sim (integra IMS/DMS) | Não | Parcial — provisionamento de cluster via O2 IMS PoC |
| **Kubernetes** | Suporte via Multi-Cloud/K8s plugin (não é o modelo nativo) | Suporte parcial (VIM K8s) | Depende da implantação | Não (OpenStack-native) | **Nativo** — tudo é CRD/controller Kubernetes |
| **Facilidade de laboratório local (16 GB)** | 🔴 Muito difícil — arquitetura de microsserviços pesada, tipicamente >32 GB recomendado | 🟡 Moderada — mais leve que ONAP, mas ainda orientado a VMs/VNFs | 🔴 Difícil — múltiplos subprojetos, integração complexa | 🔴 Inviável sem OpenStack (que não está disponível neste ambiente) | 🟢 **Viável e demonstrado** — laboratório completo rodando em ~3,6 GiB dentro de 16 GB totais |
| **Consumo de recursos (típico)** | Dezenas de GB de RAM, múltiplos VMs/containers | Vários GB, VM-orientado | Alto — soma dos subprojetos O-RAN-SC | Depende do OpenStack completo (dezenas de GB) | **Medido**: ~3,6 GiB para management + workload cluster + CNFs leves |

## 2. Por que Nephio foi escolhido para este trabalho

1. **Restrição de ambiente é o fator decisivo.** O enunciado exige 100% local, ≤16 GB de RAM,
   sem OpenStack, sem cloud paga. ONAP, OSM e o SMO completo do O-RAN-SC são, na prática,
   **inviáveis** nesse orçamento (documentação oficial de cada projeto recomenda dezenas de GB
   e múltiplas VMs). Tacker depende de OpenStack, que **não existe** neste ambiente — eliminação
   direta.
2. **Nephio é nativamente Kubernetes/GitOps**, o que combina com `kind` local e com a proposta
   do curso de demonstrar mecanismos de SMO/provisioning/orchestration/lifecycle sem precisar
   de uma pilha de telecom completa.
3. **Tem uma implementação real e testável de O2 IMS**, o que permite demonstrar, com evidência
   (não apenas teoria), o fluxo `intent → provisioning → O-Cloud`. Isso é diferenciador: outras
   ferramentas leves para Kubernetes puro (ex.: apenas Argo CD/Flux) não têm esse componente
   O-RAN-specific pronto para uso.
4. **Projeto ativo e com governança clara** (Linux Foundation Networking), documentação oficial
   disponível, releases datadas — permite trabalho acadêmico rastreável e reprodutível.
5. **Contrapartida honesta:** por ser leve e Kubernetes-nativo, o Nephio **não cobre** O1,
   Non-RT RIC nem telemetria O-RAN — lacunas assumidas explicitamente neste trabalho
   (`docs/nephio-vs-smo.md`), em vez de escondidas.
