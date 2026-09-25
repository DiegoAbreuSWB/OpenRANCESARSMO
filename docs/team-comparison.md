# Comparação com outra equipe (Felipe Favilla et al.) — Fase pós-entrega

> Análise honesta do que a outra equipe implementou (`outraequipe/` — apresentação e
> screenshots enviados pelo usuário — e o repositório público
> [`github.com/felipefavilla/smo-openran`](https://github.com/felipefavilla/smo-openran)),
> confrontado com este trabalho. **Não é para copiar** — os dois times escolheram
> plataformas deliberadamente diferentes dentro do mesmo enunciado, e isso é uma
> característica válida do exercício, não um erro de um dos lados.

## 1. O que a outra equipe implementou

Plataforma: **O-RAN Software Community (OSC) — módulo OAM + Non-RT RIC**, não Nephio.
Stack real, via Docker Compose (não Kubernetes):

| Componente | Papel | Origem |
|---|---|---|
| SDN-R (OpenDaylight) `13.0.1` | Controlador O1 — sessões NETCONF, mountpoints | O-RAN SC |
| ODLUX `13.0.1` | UI oficial do SDN-R | O-RAN SC |
| VES Collector `1.12.5` | Ingestão de eventos O1 (PNF reg, fault, heartbeat, PM) | ONAP |
| Kafka + ZooKeeper (Strimzi) | Barramento de eventos, 1 tópico por domínio VES | ONAP/Strimzi |
| NTS-NG `1.8.1` (o-du-1, o-ru-1, o-ru-2) | Simuladores de NF com agente NETCONF real | O-RAN SC |
| A1 Policy Management Service `2.3.1` | Ciclo de vida de políticas A1 | O-RAN SC Non-RT RIC |
| Near-RT RIC simulator (a1-simulator) `2.2.0` | Alvo real das políticas A1 | O-RAN SC |
| MariaDB `11.1.2` | Persistência | — |
| **smo-portal** | Portal de operação custom (contribuição do grupo) | Node.js + Express + kafkajs |

**O que foi realmente provado, com evidência (não só "instalado"):**

1. **O1 real** — sessão NETCONF/YANG completa: descoberta de capacidades (`o-du-1`: 33
   módulos YANG; `o-ru-1`/`o-ru-2`: 84 módulos cada, 13 capacidades NETCONF por
   elemento), `get-config`/`edit-config`, e **verificação de ida e volta** (mudou
   `heartbeat period` de 30s→20s no O-RU real via RESTCONF→NETCONF, releu e confirmou o
   novo valor no elemento).
2. **Auto-descoberta de PNF (zero-touch onboarding)** — a NF sobe → registra via VES
   (`PNFREG`) → SDN-R cria o mountpoint NETCONF sozinho → SMO aplica um perfil de "Dia
   1" automaticamente. Nenhum cadastro manual de elemento.
3. **VES/Kafka real** — 4 tópicos por domínio (PNFREG/FAULT/HEARTBEAT/PERFORMANCE),
   números reais de ~1h de operação contínua (174 eventos de falha, 271 heartbeats, 31
   relatórios de medição).
4. **A1 real, ponta a ponta** — tipo de política carregado no Near-RT RIC → instância
   criada (`201`) → **confirmada no próprio RIC** (não só no SMO) → removida (`204`).
5. **Portal de operação em Node.js** rodando em `localhost:8080`, consumindo as APIs
   reais dos componentes oficiais (sem reimplementar nenhuma função de gerência) — SSE
   para o fluxo de eventos ao vivo.
6. **87 testes automatizados** (60 API via Node/npm sem mocks + 27 UI via
   Puppeteer/Chrome headless) e um roteiro reproduzível de 13 passos, 0 falhas.
7. Modelo de referência de SMO confrontado com a execução real: OAM/O1 e Non-RT
   RIC/A1 "confirmados"; TE&IV/SA/NFO "parcialmente observados"; **SO, FOCOM/O2 e rApp
   Manager explicitamente fora de escopo** — o próprio time reconhece que precisaria de
   um "perfil Kubernetes" e StarlingX para O2/FOCOM, que não montaram.
8. Custo: ~8 GB de RAM dedicados ao Docker (6 GB sem o perfil A1) — cabe em 16 GB, mas é
   um orçamento maior que o nosso (~5,6 GiB para o laboratório inteiro).

## 2. O que este trabalho (Nephio) tem que eles não têm

- **O2 IMS real** — `ProvisioningRequest` → `o2ims-operator` → Cluster API/CAPD →
  cluster Kubernetes real de 2 nós, `provisioningState: fulfilled`. Eles descartaram
  O2/FOCOM explicitamente por exigir StarlingX + hardware dedicado — nós demonstramos
  exatamente essa camada, com um provider mais leve (Docker via CAPD).
- **Orquestração de pacotes cloud-native (Porch/kpt/GitOps)** — um paradigma de SMO
  diferente e igualmente válido (Configuration as Data + GitOps) do paradigma clássico
  de telecom (NETCONF/YANG) que eles usaram. Os dois cobrem ângulos diferentes da
  mesma especificação.
- **RootSync contínuo com prova de auto-reconciliação cronometrada** (commit → aplicado
  sozinho, sem comando manual) — GitOps de verdade, não só o RootSync instalado.
- **Uma função de Non-RT RIC funcional (rApp) que decide sozinha**, a partir de
  telemetria real, e age via API — mais simples que o A1 PMS deles (que expõe CRUD de
  política manual, não uma função autônoma), mas é uma peça que eles não têm: uma
  decisão de orquestração não-tempo-real tomada por código, não por um operador humano
  criando uma policy.
- **11 bugs de engenharia reais documentados e corrigidos**, incluindo um achado de
  sistemas distribuídos genuíno (conflito de autoridade GitOps × controle imperativo) —
  comparável em rigor aos "quatro problemas de integração" que eles relatam.

## 3. O que ainda precisamos fazer para não ficar para trás

**Não vamos replicar o stack deles** (SDN-R/NETCONF/VES/Kafka/A1 PMS) — isso abandonaria
a tese deste trabalho (Nephio como automação cloud-native) e duplicaria, com pior
qualidade e menos tempo, o que eles já fizeram bem. Os itens abaixo são o que
**realisticamente** fecha a distância, dentro do escopo Nephio e do orçamento de 16 GB:

| # | Item | Prioridade | Esforço | Status |
|---|---|---|---|---|
| 1 | **Demonstração em `localhost`, não só um link do claude.ai** | Alta | Baixo | ✅ Feito — `dashboard/server.py` + `dashboard/local.html` |
| 2 | Reforçar `validate-lab.sh` com mais asserções automatizadas (inspirado nos 87 testes deles) | Média | Médio | ✅ Feito — 10→15 checagens (CNFs reais, metrics-server, RootSync, config-bridge, rapp-autoscale); rodado de verdade, 15/15 PASS |
| 3 | Deixar explícito, no relatório/apresentação, que O1/A1 foram **avaliados e conscientemente não replicados** aqui porque outra equipe já cobre esse ângulo com o stack certo para isso (OSC/OAM) — nosso ângulo é o cloud-native/O2 | Alta | Baixo | ✅ Feito — §11/§15 do relatório e slides dedicados na apresentação |
| 4 | Um pequeno endpoint de "eventos ao vivo" no `dashboard/server.py` (ex.: últimas N linhas de log do `rapp-autoscale`/`config-bridge` via SSE ou polling) — dá ao nosso portal local uma sensação "ao vivo" parecida com o SSE deles, sem precisar de Kafka/VES | Baixa | Baixo-médio | Backlog (não essencial) |
| 5 | Fechar a reverificação final do rApp | Média | Baixo | ✅ Feito — scale-up confirmado estável (`spec.replicas=2`) num ciclo completo, ambiente estabilizado; ver `docs/improvements-16gb.md` §4 |

### Por que não vale a pena replicar O1/NETCONF/A1 aqui

- **Custo de RAM real deles**: ~8 GB só para o stack O1+A1 — nosso laboratório inteiro
  (Nephio + O2 IMS + O-Cloud + 4 melhorias) usa ~5,6 GiB. Rodar os dois lados a lados
  em 16 GB é apertado, e não é o objetivo: o enunciado pede "uma pilha", não a soma das
  duas.
- **Seria redundante, não complementar.** Se replicássemos O1/A1 com pior profundidade
  do que quem já fez isso bem, isso not adiciona nada novo ao debate — só duplicaria
  trabalho. O valor deste trabalho está em cobrir o ângulo que a outra equipe
  deliberadamente deixou de fora (O2/FOCOM, orquestração de pacotes cloud-native).
- **Já está documentado, não escondido.** `docs/o1-o2-analysis.md` e
  `docs/nephio-vs-smo.md` já registram, com evidência de descoberta real do cluster
  (76 CRDs, nenhuma O1), que o Nephio não implementa O1/A1 — a outra equipe apenas
  confirma, do lado deles, que essas interfaces existem e são implementáveis por outro
  stack. As duas conclusões são consistentes, não conflitantes.

## 4. Conclusão

As duas equipes provam a mesma tese da Parte 1 por ângulos diferentes e complementares:
**SMO não é uma plataforma única** — é uma arquitetura de responsabilidades que pode ser
implementada por peças distintas (OSC/OAM+Non-RT RIC de um lado, Nephio+O2 IMS do
outro), cada uma cobrindo bem uma fatia e deixando outra de fora conscientemente. O item
que era uma lacuna real e endereçável do nosso lado — depender de um link externo do
claude.ai para a demonstração — foi corrigido nesta sessão: `dashboard/server.py` sobe
o mesmo painel em `http://localhost:8090/`, com dados ao vivo do cluster quando
disponível e um snapshot honesto quando não.
