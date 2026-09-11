# 00 — Auditoria da Máquina (ETAPA 0)

> Data da auditoria: 2026-09-09
> Executor: laboratório SMO/Nephio — atividade acadêmica
> Máquina: notebook Windows corporativo (domínio `RNP`)
> Nenhum software foi instalado nesta etapa. Apenas coleta somente-leitura.

---

## 1. Configuração encontrada

### 1.1 Sistema operacional

| Item | Valor |
|---|---|
| SO | Microsoft Windows 11 Enterprise |
| Versão / build | 10.0.26100 (24H2) |
| Arquitetura | 64 bits (x86-64 / AMD64) |
| Domínio / usuário | `RNP\diego.abreu` (conta de domínio) |

### 1.2 CPU

| Item | Valor |
|---|---|
| Modelo | 12th Gen Intel(R) Core(TM) i7-1255U |
| Núcleos físicos | 10 (2 performance + 8 efficiency) |
| Threads lógicas | 12 |
| Clock base | 1.7 GHz (série U de baixo consumo; turbo até ~4.7 GHz apenas nos P-cores) |
| Arquitetura | x86-64 |

### 1.3 Memória RAM

| Item | Valor |
|---|---|
| RAM física total | 15,66 GiB (16 GB) |
| RAM livre no momento da auditoria | ~5,6 – 6,2 GiB |
| RAM em uso (uso "normal" de trabalho) | ~9,5 GiB |
| Maiores consumidores no momento | Memory Compression, SentinelAgent (EDR), Chrome (várias abas), VS Code (várias janelas), Claude, explorer |
| Commit limit | 18,03 GiB |
| Commit livre | ~5,2 GiB |

### 1.4 Swap / arquivo de paginação

| Item | Valor |
|---|---|
| Arquivo | `C:\pagefile.sys` |
| Gerenciamento | Automático pelo Windows (`AutomaticManagedPagefile = True`) |
| Tamanho alocado | ~2,4 GB (2432 MB) — **pequeno** |
| Uso atual / pico | ~96 MB / ~123 MB |

### 1.5 Disco

| Volume | Tamanho | Livre |
|---|---|---|
| C: | 476,8 GB | 321,6 GB |

Disco **não é restrição**.

### 1.6 Virtualização / segurança da plataforma

| Item | Valor |
|---|---|
| Hipervisor presente | **Sim** (`CsHypervisorPresent = True`) |
| VBS (Virtualization-Based Security) | **Em execução** |
| Credential Guard | Ativo |
| HVCI (Integridade de Código imposta por Hypervisor) | **Imposto** |
| App Control for Business (WDAC) | **Imposto** (modo kernel) |
| Requisitos de Hyper-V (systeminfo) | "Hipervisor detectado" — recursos já em uso pelo VBS |

Interpretação: a plataforma **suporta virtualização aninhada** (WSL2 e Docker Desktop convivem com VBS via Windows Hypervisor Platform), porém o endpoint é **gerenciado e endurecido**: WDAC + HVCI + EDR podem bloquear binários não assinados, drivers e a instalação do kernel WSL.

### 1.7 WSL2

| Item | Valor |
|---|---|
| WSL instalado | **NÃO** |
| `wsl --version` / `--status` / `--list` | Retornam: *"O Subsistema do Windows para Linux não está instalado. Você pode instalar executando 'wsl.exe --install'."* |
| `%USERPROFILE%\.wslconfig` | Ausente |
| Distribuição Linux | Nenhuma |
| Launcher `wsl.exe` | Presente em `C:\Windows\System32\wsl.exe` (apenas o stub do Windows) |

### 1.8 Docker / runtime de contêiner

| Item | Valor |
|---|---|
| `docker` no PATH | **NÃO** (`CommandNotFoundException`) |
| Docker Desktop instalado | **NÃO** (`C:\Program Files\Docker`, `%LOCALAPPDATA%\Docker` inexistentes) |
| Processos `docker` / `dockerd` / `com.docker` / `vpnkit` | Nenhum em execução |
| Docker Compose | Ausente (consequência) |
| containerd | Ausente |
| Docker Desktop usando WSL2 | N/A — Docker Desktop não está instalado |

> ⚠️ A premissa do enunciado *"Docker já instalado"* **não se confirmou**. Não há nenhum runtime de contêiner na máquina.

### 1.9 Runtimes / hypervisors alternativos

Todos **ausentes**: `podman`, `nerdctl`, `minikube`, `rancher` (Rancher Desktop), `multipass`, `vagrant`, `VBoxManage` (VirtualBox).

### 1.10 Ferramentas de linha de comando

| Ferramenta | Status | Detalhe |
|---|---|---|
| git | ✅ Presente | `git version 2.55.0.windows.5` (`C:\Program Files\Git`) |
| curl | ✅ Presente | `curl.exe` nativo do Windows |
| winget | ✅ Presente | `v1.29.290` (escopo de usuário, `...\WindowsApps\winget.exe`) |
| kubectl | ❌ Ausente | |
| kind | ❌ Ausente | |
| helm | ❌ Ausente | |
| kpt | ❌ Ausente | |
| kustomize | ❌ Ausente | |
| cosign | ❌ Ausente | |
| jq | ❌ Ausente | |
| gcloud | ❌ Ausente | |

### 1.11 Rede / Internet

| Alvo | Resultado |
|---|---|
| https://github.com | HTTP 200 ✅ |
| https://docs.nephio.org | HTTP 200 ✅ |

Acesso à Internet **OK** (sem proxy aparente bloqueando).

### 1.12 Portas em escuta (host)

| Porta | Processo | Observação |
|---|---|---|
| 135 | RPC (PID 1572) | padrão Windows |
| 139 | NetBIOS (System) | padrão Windows |
| 445 | SMB (System) | padrão Windows |

Portas relevantes para `kind` / API server / ingress — **6443, 80, 443, 8080, 8443** — estão **livres**. Sem conflito.

### 1.13 Privilégios (equivalente a `sudo`)

| Item | Valor |
|---|---|
| Usuário | `RNP\diego.abreu` (conta de **domínio**) |
| Administrador local | **NÃO** (`IsInRole(Administrator) = False`) |
| `Get-WindowsOptionalFeature -Online` | Falhou: *"A operação solicitada requer elevação."* |
| Enumerar grupo Administradores | Negado |
| EDR | SentinelOne (`SentinelAgent`) em execução — endpoint corporativo gerenciado |

---

## 2. Estimativa de memória disponível

| Cenário | RAM utilizável estimada para o lab |
|---|---|
| Agora, como está (Chrome + VS Code + EDR + Claude abertos) | ~6 GiB livres |
| Fechando Chrome e janelas extras do VS Code | ~8 – 9 GiB utilizáveis |
| Piso fixo não removível (SO + serviços gerenciados + SentinelOne EDR) | ~4 – 5 GiB sempre ocupados |
| **Orçamento realista para WSL2 + Docker + kind + Nephio (melhor caso)** | **~7 – 9 GiB** |

Referência de comparação: o **sandbox oficial do Nephio** (instalação em VM única) pede tipicamente **8 vCPU / 16 GB RAM / ~200 GB disco** *só para a VM*, já provisionando management + clusters edge/regional. Isso equivale ao **total** desta máquina → a instalação **completa não cabe**.

---

## 3. Riscos (ordenados por severidade)

| # | Severidade | Risco |
|---|---|---|
| 1 | 🔴 **BLOQUEANTE** | **Sem administrador local.** Instalar WSL2 (`wsl --install`), habilitar "Plataforma de Máquina Virtual", instalar Docker/Rancher/Podman — **tudo exige elevação**. Sem isso não há runtime de contêiner, logo não há `kind` nem Nephio. |
| 2 | 🔴 **BLOQUEANTE** | **Nenhum runtime de contêiner** (Docker, Podman, containerd — todos ausentes). Premissa "Docker instalado" não confirmada. |
| 3 | 🔴 **BLOQUEANTE** | **WSL2 não instalado** e sem distribuição Linux. |
| 4 | 🟠 ALTO | **WDAC + HVCI impostos + SentinelOne EDR.** Podem bloquear binários não assinados (`kind`, `kpt`, plugins), drivers e o kernel WSL. Política corporativa pode **proibir** a instalação mesmo com admin concedido. |
| 5 | 🟠 ALTO | **Orçamento de RAM apertado.** Instalação completa do Nephio inviável. Só o perfil **mínimo** (apenas management cluster) é possível, e ainda assim com navegador/IDE fechados. |
| 6 | 🟡 MÉDIO | **Pagefile pequeno** (~2,4 GB) e commit livre ~5 GiB. Picos durante `kind create` / `docker pull` podem causar OOM ou travamento. Aumentar o pagefile também exige admin. |
| 7 | 🟡 MÉDIO | **CPU série U de baixo consumo** (base 1.7 GHz, maioria E-cores). Reconciliações, builds e pulls serão **lentos** — não impeditivo. |
| 8 | 🟢 BAIXO | Disco: 321 GB livres — sem risco. |
| 9 | 🟢 BAIXO | Rede OK, sem conflito de portas. |

---

## 4. Recomendação — arquitetura mais leve

### 4.1 Não é possível avançar para a ETAPA 1 no estado atual

Faltam **runtime de contêiner**, **WSL2** e **privilégios**. É preciso resolver 3 pré-requisitos antes de criar o Management Cluster.

### 4.2 Pré-requisitos (exigem apoio da TI / admin RNP)

1. **WSL2 + Ubuntu 22.04 ou 24.04 LTS** instalados (`wsl --install`), com a feature *Plataforma de Máquina Virtual* habilitada.
2. **Pagefile** ajustado para gerenciado pelo sistema, mínimo ~8 GB.
3. **Runtime de contêiner** (escolher 1 — todos exigem admin só na 1ª instalação):
   - ✅ **Recomendado:** **Docker Engine nativo DENTRO do WSL2 Ubuntu** (`get.docker.com`). Sem Docker Desktop, sem licença comercial, sem GUI, menor overhead de RAM.
   - Alternativa: **Rancher Desktop** (containerd + `kind` embutido) — mais pesado (GUI + VM própria).
   - Alternativa: **Podman + kind** — funciona, mas `kind` sobre Podman ainda tem arestas.
4. **CLIs no WSL (sem admin):** `kubectl`, `kind`, `helm`, `kpt`, `jq`, `gh` — via `curl`/`apt`.

### 4.3 Arquitetura de laboratório recomendada (mínima e demonstrável)

- **Host:** WSL2 Ubuntu com `.wslconfig`: `memory=10GB`, `processors=6`, `swap=4GB`.
- **Management Cluster:** 1 cluster `kind` **single-node** `nephio-mgmt`.
- **Nephio — perfil MÍNIMO:** Porch + Nephio controllers + Config Sync/Gitea + operador **O2 IMS**.
  - ❌ SEM clusters edge/regional auto-provisionados
  - ❌ SEM pacotes free5gc / OAI
  - ❌ SEM RIC, SEM Prometheus/Grafana pesados
- **Workload Cluster (O-Cloud acadêmico):** 1 cluster `kind` **single-node** `o-cloud-1`.
  - Prioridade A: provisionado pelo fluxo O2 IMS/Nephio, **se** a versão instalada conseguir sem providers de infra pesados (verificar na ETAPA 6).
  - Fallback B: criado externamente via `kind` e **registrado** no Nephio (abordagem já prevista no enunciado).
- **Workload representativo:** `demo-nf` (nginx, `requests: 32Mi / 25m`, `limits: 128Mi / 200m`) no `o-cloud-1`, para demonstrar o ciclo de vida.

### 4.4 Orçamento estimado do cenário recomendado

| Componente | RAM estimada |
|---|---|
| `kind` mgmt + Nephio mínimo | ~3,5 – 5,0 GiB |
| `kind` o-cloud-1 + demo-nf | ~0,8 – 1,2 GiB |
| Overhead Docker/WSL | ~1,0 – 1,5 GiB |
| **Total** | **~5,5 – 7,5 GiB** |

Cabe **se** Chrome e janelas extras de IDE estiverem fechados. Fica **no limite** — monitorar a cada etapa (`scripts/resource-usage.sh`) e ter plano de corte.

### 4.5 Plano C (se o Nephio mínimo estourar a RAM)

Um único cluster `kind`; instalar apenas **Porch + operador O2 IMS + 1–2 controllers** via `kpt`/`kubectl`; segundo cluster `kind` registrado manualmente; demonstrar `request → controller → mudança concreta de estado` no que estiver instalado; **documentar a limitação abertamente**.

---

## 5. A máquina aguenta o experimento?

| Situação | Veredito |
|---|---|
| **Estado atual** | ❌ **NÃO** — faltam runtime de contêiner, WSL2 e privilégios de administrador. |
| **Após resolver os 3 pré-requisitos, rodando apenas o perfil MÍNIMO do Nephio, com navegador/IDE fechados** | ⚠️ **SIM, no limite** — versão reduzida viável (Management Cluster + Nephio mínimo + O2 IMS + 1 workload cluster + `demo-nf` + lifecycle). |
| **Instalação COMPLETA do sandbox Nephio (multi-cluster, free5gc, OAI)** | ❌ **NÃO é viável** nesta máquina. |

---

## 6. Próximo passo

**Bloqueado aguardando decisão do usuário:**

1. Consegue obter administrador local (ou apoio da TI RNP) para instalar WSL2 + runtime de contêiner?
2. Se não: um VM Linux institucional/nuvem (4 vCPU / 16 GB) como host do lab é aceitável?
3. Preferência de runtime: Docker Engine no WSL2 (recomendado) / Rancher Desktop / Podman / Docker Desktop?

Somente após isso a ETAPA 1 (criação do `nephio-mgmt`) pode começar.
