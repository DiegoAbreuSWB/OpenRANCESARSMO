# 00b — Preparação do host Linux (pré-requisito da ETAPA 1)

> Decisão do usuário: hospedar nesta máquina Windows · runtime = **Docker Engine nativo dentro do WSL2**.
> Elevação (admin) disponível — o usuário executa os passos marcados **[USER / elevado]**.
> Tudo o mais é executado pelo assistente via `wsl.exe -- <cmd>`.

## Plano incremental (cada fase é validada antes da seguinte)

| Fase | Objetivo | Quem executa | Validação |
|---|---|---|---|
| **A1** | Instalar WSL2 + Ubuntu | **[USER / elevado]** + reboot | `wsl -l -v` mostra distro em `VERSION 2` |
| **A2** | `.wslconfig` (limites de RAM/CPU) | assistente (já feito) | `wsl --shutdown` e reinício aplicam limites |
| **A3** | Criar usuário Linux, `apt update/upgrade`, pacotes base | assistente (após 1º login) | `uname -a`, `free -h`, `nproc`, `df -h` |
| **B**  | Docker Engine (CE) dentro do WSL + systemd | assistente | `docker run hello-world` OK |
| **C**  | `kubectl`, `kind`, `helm`, `kpt`, `jq` | assistente | versões impressas |
| **ETAPA 1** | Cluster kind `nephio-mgmt` | assistente | `kubectl get nodes` Ready |

Medição de RAM/CPU ao fim de cada fase → `evidence/resources/`.

---

## Fase A1 — Instalar WSL2 + Ubuntu  **[USER / elevado]**

### Config já aplicada pelo assistente
- `C:\Users\diego.abreu\.wslconfig` criado com `memory=10GB`, `processors=6`, `swap=4GB`, `autoMemoryReclaim=gradual`, `sparseVhd=true`.

### Comandos a executar num **PowerShell "Executar como administrador"**

```powershell
# 1. Instala WSL2 + Ubuntu (LTS atual = 24.04) e habilita as features
#    (Virtual Machine Platform + Windows-Subsystem-for-Linux)
wsl --install

# Se o comando acima só imprimir a ajuda do WSL (WSL já parcialmente presente):
#   wsl --list --online
#   wsl --install -d Ubuntu-24.04
# Se travar em 0.0% (Store bloqueada por política corporativa):
#   wsl --install --web-download -d Ubuntu-24.04

# 2. REINICIAR o Windows (obrigatório na 1ª instalação)
```

Após o reboot, o Ubuntu abre sozinho e pede:
- **UNIX username** (ex.: `nephio` ou o seu de preferência — minúsculas, sem espaço)
- **senha** (guarde; o sudo pede ela; por padrão o WSL configura sudo para este usuário)

### Verificações a rodar (PowerShell normal, não precisa admin) e **colar a saída para o assistente**:

```powershell
wsl --version
wsl --status
wsl -l -v
```

Resultado esperado: `wsl --version` mostra versão do WSL e do kernel; `wsl -l -v` lista `Ubuntu` (ou `Ubuntu-24.04`) com `STATE=Running/Stopped` e **`VERSION 2`**.

> ⚠️ Riscos conhecidos neste endpoint (ver `00-environment-audit.md`): WDAC/HVCI impostos + SentinelOne EDR podem bloquear a entrega do WSL pela Store ou o kernel. Se `wsl --install` falhar, colar a mensagem de erro exata — há caminho alternativo (MSIX do GitHub `microsoft/WSL/releases` + `wsl --update`).

---

---

## Resultado (executado 2026-09-09)

### A1 — WSL2 + Ubuntu ✅
- WSL versão **2.7.13.0**, kernel **6.18.33.2**.
- Distro registrada: **Ubuntu 26.04 LTS** (`resolute`) — o `wsl --install` default trouxe a LTS mais nova. `wsl -l -v` → `Ubuntu  Stopped  VERSION 2`.
- Usuário Linux: **`diegoabreu`** (uid 1000), **sudo sem senha** OK.
- **systemd ativo** (pid 1 = systemd) — necessário para o Docker.

### A2 — `.wslconfig` ✅
- `C:\Users\diego.abreu\.wslconfig`: `memory=10GB`, `processors=6`, `swap=4GB`, `autoMemoryReclaim=gradual`, `sparseVhd=true`.
- Confirmado dentro do WSL: `free -h` → **9.7 GiB** total, **4.0 GiB swap**; `nproc` → **6**.

### A3 — pacotes base ✅
- `ca-certificates curl gnupg jq git make apt-transport-https lsb-release`.
- `jq-1.8.1`, `git 2.53.0`.

### B — Docker Engine ✅
- Repositório **oficial Docker CE** (`download.docker.com/linux/ubuntu resolute stable`).
- **docker-ce / cli / containerd.io / buildx / compose-plugin** → Docker **29.8.0**, containerd **v2.3.5**, runc **1.5.1**.
- `/etc/docker/daemon.json`: rotação de logs (`max-size=10m`, `max-file=3`).
- `systemctl enable --now docker` → **active + enabled** (sobe sozinho no boot do WSL).
- `diegoabreu` adicionado ao grupo `docker` → `docker` sem sudo (validado após `wsl --shutdown`).
- `docker run --rm hello-world` → **"Hello from Docker!"** ✅

### C — CLIs Kubernetes ✅ (conferidas contra upstream em 2026-09-09)

| Ferramenta | Instalada | Latest upstream nessa data |
|---|---|---|
| kubectl | **v1.37.0** (kustomize v5.8.1) | v1.37.0 |
| kind | **v0.33.0** | v0.33.0 |
| helm | **v3.19.0** (linha 3.x mantida de propósito) | v4.2.4 (Helm 4 — evitado por compat. de charts) |
| kpt | **v1.0.0** (GA) | v1.0.0 |

Referência p/ ETAPA 2: última release do Nephio = **v6.0.0 (R6)**, 2026-02-13, estável.
Também disponíveis: `porchctl` v1.6.2, `cluster-api`/`clusterctl` v1.14.2.

### Medição de recursos (idle, pós-setup)
- Dentro do WSL: **585 MiB usados** / 9.7 GiB (dockerd 90 MiB, containerd 43 MiB).
- Windows: **6,3 GiB livres**; `vmmemWSL` ≈ 1,9 GiB visto pelo host.
- Snapshot: `evidence/resources/20260909-161650_post-host-setup.txt`.

### Realinhamento de versões (para casar com Nephio R6)
- `kind` **v0.33.0 → v0.27.0** (v0.33 só suporta K8s 1.34–1.37; Nephio R6 usa 1.32).
- `kubectl` **v1.37.0 → v1.32.3** (skew ±1 do apiserver 1.32).
- `helm` v3.19.0 e `kpt` v1.0.0 mantidos.

### Correção de estabilidade do WSL2 (descoberta na ETAPA 1)
- Sintoma: a VM do WSL2 desligava ~60 s após fechar o último terminal → o container do
  kind parava e `etcd`/`apiserver` reiniciavam "sujos" a cada comando (CRDs sumiam,
  "connection refused").
- Correção: `.wslconfig` → `vmIdleTimeout=21600000` (6 h) + `scripts/lab-keepalive.sh`
  (segura uma sessão aberta) + `scripts/mgmt-cluster-recover.sh` (recupera o cluster
  limpo após qualquer reboot da VM). Estável após o ajuste.

## Status

- [x] A1 — WSL2 + Ubuntu 26.04 LTS
- [x] A2 — `.wslconfig` (limites + `vmIdleTimeout`)
- [x] A3 — pacotes base
- [x] B — Docker Engine 29.8.0 (systemd, rootless p/ o usuário)
- [x] C — kubectl / kind / helm / kpt (realinhados p/ K8s 1.32)
- [x] **ETAPA 1** — cluster kind `nephio-mgmt` criado e saudável
- [x] **ETAPA 2** — versão do Nephio decidida → `docs/01-nephio-version.md`
- [x] **ETAPA 3** — Nephio R6 mínimo instalado (34/34 pods, 76 CRDs) → `docs/02-nephio-installation.md`
- [x] **ETAPA 4** — schema real do O2 IMS descoberto → `docs/03-o2ims-discovery.md`
- [x] **ETAPA 5** — `docs/04-architecture.md` (Mermaid + 4 camadas de lifecycle)
- [x] **ETAPA 6** — repos Porch registrados (`catalog-infra-capi`, `mgmt`, `mgmt-staging`) + `RootSync mgmt`
- [x] **ETAPA 7** — `ProvisioningRequest` → **O2 IMS criou o `o-cloud-1`** (`provisioningState: fulfilled`, CAPI Cluster `Provisioned`, 2 nós Ready) ✅ **resultado ideal**
- [x] **ETAPA 8** — O-Cloud validado → `evidence/workload-cluster/`
- [x] **ETAPA 9** — `demo-nf` no `o-cloud-1` (HTTP 200) → `evidence/lifecycle/`
- [x] **ETAPA 10** — lifecycle A–E demonstrado → `evidence/lifecycle/`
- [x] **ETAPA 11–15** — `evidence/` consolidado · `scripts/validate-lab.sh` (PASS=10) · `docs/05` · `docs/06` · `README.md`
- [x] **ETAPA 20** — `scripts/cleanup.sh`

### Ajuste extra de host (ETAPA 6/7, lado O-Cloud)
- `/etc/systemd/system/wsl-cgroup-cpuset.service`: delega `cpuset` no cgroup v2 a cada boot
  (senão o kubelet dos nós CAPD `kindest/node:v1.31.0` falha com *missing controllers: cpuset*
  após um restart da VM). Script: `scripts/fix-wsl-cgroup-cpuset.sh`.
- `scripts/fix-ocloud-cni-plugins.sh`: instala os CNI "standard" (`loopback`…) em `/opt/cni/bin`
  dos nós do `o-cloud-1` (a imagem `kindest/node:v1.31.0` não os traz).

### Ajuste extra de host aplicado na ETAPA 3
- `/etc/sysctl.d/99-nephio-lab.conf`: `fs.inotify.max_user_watches=1048576`,
  `fs.inotify.max_user_instances=8192`, `fs.file-max=1048576`
  (sem isso, controllers do kind falham com "too many open files").
  Script: `scripts/fix-inotify-limits.sh`.
