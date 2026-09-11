# Evolução com NFs reais (Fase 21)

> Avaliação **apenas** — nada foi instalado. Objetivo: avaliar a viabilidade de substituir uma
> das 3 CNFs simuladas (`oran-cu`/`oran-du`/`oran-core`) por um componente real, **depois** que
> o ambiente mínimo (já concluído) estiver validado.

## 1. Alternativas avaliadas

| Alternativa | O que é | RAM mínima documentada | RAM recomendada |
|---|---|---|---|
| **UERANSIM** | Simulador open source de UE + gNB (RAN 5G), usado tipicamente contra o free5GC | ~2 GB / 2 CPU (junto com free5GC) | 4+ GB / 4 CPU |
| **free5GC** (core completo, todas as NFs numa máquina) | Core 5G open source (AMF, SMF, UPF, NRF, UDM…) | 4 GB | 8 GB |
| **componente leve do OpenAirInterface (OAI)** | RAN real (gNB/UE) — mais próximo de uma implementação de produção | Não documentado oficialmente como "leve"; relatos práticos apontam exigência de CPU **significativamente maior** que UERANSIM, e dificuldade de conectar mais de uma UE numa única VM | Tipicamente requer VM dedicada por componente |

Fontes: [free5gc.org/guide/Environment](https://free5gc.org/guide/Environment/) (hardware mínimo/recomendado
do free5GC), [github.com/aligungr/UERANSIM](https://github.com/aligungr/UERANSIM) e comparações
práticas publicadas sobre UERANSIM vs. OAI (UERANSIM citado como mais leve e mais simples de
configurar; OAI como mais pesado e mais complexo, com problemas relatados para múltiplas UEs
numa mesma VM).

## 2. Análise por alternativa

### 2.1 UERANSIM no lugar do `oran-du`/`oran-cu` simulados

- **Consumo esperado:** ~2 GB RAM / 2 CPU cores rodando sozinho (sem um core real por trás,
  UERANSIM ainda inicializaria mas não completaria o registro — precisaria de um AMF real).
- **Benefício:** demonstraria uma pilha RAN **real** (protocolo NAS/NGAP real, não uma API REST
  simulada), com muito mais credibilidade acadêmica que o `oran-du`/`oran-cu` atuais.
- **Risco:** UERANSIM sozinho não conversa com nada — precisaria também de um AMF real (ou seja,
  no mínimo um subconjunto do free5GC), o que empurra o consumo total para a faixa do free5GC
  (ver abaixo). Além disso, UERANSIM não é uma NF O-RAN (não implementa F1/E1); é uma simulação
  de UE+RAN "monolítica" no modelo 3GPP tradicional, não desagregado — um passo **para trás** na
  narrativa O-RAN deste trabalho (que é justamente sobre desagregação O-CU/O-DU).

### 2.2 free5GC no lugar do `oran-core` simulado

- **Consumo esperado:** 4 GB mínimo (todas as NFs numa máquina), 8 GB recomendado — **isso
  sozinho já consome a maior parte do orçamento de RAM desta máquina** (16 GB totais, ~10–12 GB
  de teto para o laboratório inteiro, dos quais o Nephio + O2 IMS + O-Cloud já usam ~4 GB).
- **Benefício:** um AMF/SMF/UPF real permitiria demonstrar registro de UE de verdade (com
  UERANSIM), sessão PDU real — a pilha 5G "de verdade" em vez de representativa.
- **Risco:** **não caberia** junto com o restante do laboratório (Nephio R6 completo + O2 IMS +
  O-Cloud + CNFs) dentro de 16 GB totais sem desligar componentes já validados. Exigiria decidir
  entre (a) rodar o free5GC num terceiro cluster/host separado (fora do escopo "100% local numa
  máquina só"), ou (b) desligar partes do Nephio para abrir espaço — o que descaracterizaria a
  Parte 1/2 deste trabalho, cujo foco é o mecanismo de SMO/orchestration, não a NF em si.

### 2.3 Componente leve do OAI (ex.: só o `oai-gnb` ou `oai-nr-ue`)

- **Consumo esperado:** não documentado oficialmente como leve; a literatura prática consultada
  aponta exigência de CPU visivelmente maior que UERANSIM e problemas de estabilidade com mais
  de uma UE por VM — sinal de que o footprint real (RAM + CPU) tende a ser maior e menos
  previsível que o do UERANSIM/free5GC.
- **Benefício:** seria o componente mais fiel a uma implementação O-RAN real (o próprio Nephio
  já tem operador para OAI no catálogo — `workloads/oai/oai-ran-operator`, visto na descoberta
  do catálogo na Fase 1).
- **Risco:** maior de todas as opções — RAM/CPU imprevisíveis, maior complexidade de
  configuração, e o próprio enunciado deste trabalho pede explicitamente para **não** instalar
  "OpenAirInterface inteiro" nesta fase.

## 3. Recomendação

**Não substituir nenhuma CNF simulada por uma NF real neste laboratório.** As três alternativas
avaliadas, mesmo a mais leve (UERANSIM), dependem de um core 5G real para fazer sentido
funcionalmente, e o conjunto (RAN real + core real) **não cabe** ao lado do Nephio R6 + O2 IMS +
O-Cloud já instalados e validados, dentro do orçamento de 16 GB.

**Caminho de evolução sugerido para um trabalho futuro** (fora do escopo desta entrega):
1. Validar primeiro se o Nephio consegue orquestrar o **onboarding do pacote** do free5GC
   (`workloads/free5gc/free5gc-operator`, já presente no catálogo oficial) **sem** de fato
   escalar as réplicas dos Pods a 1 (ou seja, demonstrar o fluxo de package/deployment do Nephio
   apontando para NFs reais, mas mantendo os Pods das NFs pesadas em `replicas: 0` até haver
   RAM dedicada) — validaria a integração Nephio↔NF real sem pagar o custo de RAM completo.
2. Só depois, com uma máquina dedicada (ou nuvem, se permitido), escalar para `replicas: 1` e
   medir o consumo real.

## 4. O que fica registrado, não instalado

Nenhum destes componentes foi baixado, construído ou executado. Esta seção documenta a
**avaliação de viabilidade**, conforme pedido pela Fase 21 — a decisão de manter as 3 CNFs
simuladas (Fase 9) é deliberada e justificada pelos números acima, não uma omissão.
