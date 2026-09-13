# Melhorias implementadas dentro do limite de 16 GB

> Contexto: após a entrega completa da Parte 1 + Parte 2, foi levantada uma lista de
> lacunas e melhorias possíveis (ver `report/part2-report.md` §14 e
> `docs/05-experiment-report.md` §11). Este documento registra as duas melhorias que
> **couberam dentro do orçamento de 16 GB** e foram efetivamente implementadas e
> evidenciadas — não apenas planejadas.

## 1. `metrics-server` no `o-cloud-1`

**Lacuna que fechava:** monitoramento limitado a `docker stats`/`kubectl describe`/eventos;
sem `kubectl top` real por nó ou por pod.

**Implementação:** manifesto oficial `kubernetes-sigs/metrics-server` (`components.yaml`),
aplicado no contexto `o-cloud-1`, com o único patch necessário em qualquer cluster
kind/local — `--kubelet-insecure-tls` (os nós kind usam certificados de kubelet
self-signed que o metrics-server não valida por padrão).

```
kubectl --context o-cloud-1 apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl --context o-cloud-1 -n kube-system patch deployment metrics-server --type=json \
  -p '[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
```

**Custo de RAM medido:** pod `metrics-server` ≈ 14–17 MiB (`kubectl top pods -A`, ver
evidência) — praticamente gratuito no orçamento.

**Evidência real** (`evidence/improvements/20260913-*_metrics-server.txt`):

```
NAME                               CPU(cores)   CPU(%)   MEMORY(bytes)   MEMORY(%)
o-cloud-1-45dsx-cbjjq              333m         5%       971Mi           9%
o-cloud-1-md-0-6s4dn-kbzk5-gcf5r   148m         2%       576Mi           5%
```

## 2. RootSync contínuo no `o-cloud-1` para o repositório `openran-cnfs`

**Lacuna que fechava** (limitação documentada em `report/part2-report.md` §14 item 2 e
`docs/05-experiment-report.md` §11 item 2): a entrega das 3 CNFs simuladas dependia de
rodar manualmente `lab/nephio/deploy-cnfs-via-porch.sh` (`kpt live apply` sob demanda) —
não havia reconciliação contínua observando o repositório, ao contrário do management
cluster (que já tem `RootSync mgmt` rodando desde a Parte 1).

**Implementação:** o mesmo pacote kpt oficial do catálogo Nephio já usado para instalar
Config Sync no management cluster (`nephio/core/configsync@v6`,
`scripts/03-nephio-min.sh configsync`), agora aplicado — pela primeira vez — no próprio
`o-cloud-1` (script novo: [`scripts/11-ocloud-configsync.sh`](../scripts/11-ocloud-configsync.sh)).
Em seguida, um `RootSync` (`configsync.gke.io/v1beta1`) foi criado apontando para o
repositório real já registrado no Porch/Gitea:

```yaml
apiVersion: configsync.gke.io/v1beta1
kind: RootSync
metadata:
  name: openran-cnfs
  namespace: config-management-system
spec:
  sourceType: git
  sourceFormat: unstructured
  git:
    repo: http://172.18.0.200:3000/nephio/openran-cnfs.git
    branch: main
    dir: "."
    auth: none
```

**Custo de RAM medido:** 3 pods novos no `o-cloud-1`
(`config-management-operator`, `reconciler-manager`, `root-reconciler-openran-cnfs`),
mesma ordem de grandeza dos equivalentes já rodando no management cluster (~dezenas de
MiB cada) — cabe folgado dentro dos ~4,4 GiB *available* medidos após a instalação.

### Prova de que é realmente contínuo (não apenas instalado)

Teste feito: publicar uma nova revisão do pacote `openran-nfs` no Porch/Gitea (via
`porchctl rpkg copy/push/propose/approve`, mudando
`openran-lab/nf-version: "v2" → "v3"` no `oran-cu-deployment.yaml`) **sem** rodar
`deploy-cnfs-via-porch.sh` (ou seja, sem nenhum `kpt live apply` manual no `o-cloud-1`) —
e observar se o cluster se atualizava sozinho.

**Resultado real** (`evidence/improvements/`, script `scripts/_publish-only-test.sh`):

```
== NAO rodei kpt live apply no o-cloud-1. Observando o RootSync sozinho... ==
  03:57:55 rootsync.commit=1bdae53df4d1 oran-cu.nf-version=v2
  03:58:02 rootsync.commit=1bdae53df4d1 oran-cu.nf-version=v2
  03:58:08 rootsync.commit=1bdae53df4d1 oran-cu.nf-version=v2
  03:58:14 rootsync.commit=1bdae53df4d1 oran-cu.nf-version=v3
  >>> RootSync aplicou sozinho, sem kpt live apply manual <<<

NAME                      READY   STATUS    RESTARTS   AGE
oran-cu-5b85f7d48-9vfbc   0/1     Running   0          4s
oran-cu-c44ff566c-dqd4v   1/1     Running   0          11m
```

O `RootSync` detectou o novo commit publicado no Gitea (`porchctl approve` = merge no
branch `main`) e disparou sozinho o rollout do `oran-cu` — em ~20 s, sem qualquer comando
imperativo. **Isto é GitOps de verdade fechando o gap**, não apenas o CRD instalado.

## 3. `config-bridge`: sincronização `/config` (NF) → pacote Porch/Gitea

**Lacuna que fechava** (`report/part2-report.md` §14 item 5): a configuração de domínio
mudada via `PUT /config` (API própria da NF, análoga a O1/NETCONF) e a configuração do
pacote (Porch) eram caminhos independentes — uma mudança feita por um não aparecia no
outro. Documentada como "fora do escopo" na Parte 2 original.

**Pré-requisito que faltava:** a config de domínio (`cell_id`, `plmn_id`, `tx_power_dbm`,
`du_id`) nunca existiu no ConfigMap do pacote — era *hardcoded* em
`lab/cnfs/oran-du/app.py` (`DEFAULT_CONFIG`). Sem isso não havia "valor publicado no
pacote" nenhum para comparar. Corrigido: `app.py` agora lê esses 4 campos de variáveis
de ambiente (`CFG_PLMN_ID`, `CFG_CELL_ID`, `CFG_TX_POWER_DBM`, `CFG_DU_ID`), com os
mesmos valores como *default* se a env var não existir; e
`lab/nephio/openran-cnfs/oran-du-configmap.yaml` passou a declarar essas 4 chaves.

**Implementação:** [`lab/nephio/config-bridge/bridge.py`](../lab/nephio/config-bridge/bridge.py)
— um poller Python (não um operador `kopf`/`controller-runtime`: o estado observado,
o `/config` em memória da NF, não é um recurso do Kubernetes, então não há evento do
apiserver para reagir; um poll HTTP simples é o desenho correto para este problema, não
uma dependência forçada). A cada 15 s, para `oran-du`:

1. `GET /config` na NF (config ao vivo).
2. `GET` do `ConfigMap` **tal como publicado no branch `main`** do repo Gitea via API
   de conteúdo do Gitea (a mesma fonte que o Porch usa, e que o RootSync contínuo já
   observa — ver §2).
3. Compara os dois. Sem diferença → não faz nada (log `sem drift`).
4. Com diferença → escreve o `ConfigMap` atualizado e comita direto no branch `main`
   via API do Gitea, reaproveitando **o mesmo token que o Porch já usa** para este repo
   (lido do Secret `openran-cnfs-access-token-porch` no management cluster — nenhuma
   credencial nova criada, nada de segredo comitado no git;
   [`scripts/12-config-bridge.sh`](../scripts/12-config-bridge.sh) lê e injeta em
   tempo de deploy).
5. O RootSync contínuo (§2) detecta o novo commit sozinho e reconcilia o `ConfigMap`
   no cluster — fechando o ciclo.

**Simplificação deliberada e documentada:** o commit vai direto para o branch `main`
via API de conteúdo do Gitea, **sem** passar pelo ciclo Draft→Proposed→Published do
Porch (`porchctl rpkg ...`). Fazer isso via Porch exigiria dar a este controller acesso
de rede ao apiserver agregado do Porch (cross-cluster, do `o-cloud-1` até o
`nephio-mgmt`) e reimplementar em Python o mesmo fluxo já existente em
`lab/nephio/deploy-cnfs-via-porch.sh`. Para o propósito específico desta melhoria
(fechar a lacuna de propagação de config, não o ciclo de vida do pacote), o commit
direto no Gitea é suficiente — é o mesmo backend Git que o Porch usa como fonte de
verdade, então o resultado observável (o que está publicado) é idêntico.

**Bug real encontrado e corrigido durante a implementação:** a primeira versão
serializava o YAML sem forçar aspas, e o PyYAML emitiu `CFG_PLMN_ID: 00101` (sem
aspas) — um padrão que o resolvedor de tipos do YAML 1.1 reconhece como "parece um
número" e que, na releitura, virou o inteiro `101` (perdendo o zero à esquerda de
`"00101"`). Isso causava um **loop infinito de auto-correção**: lê `101`, compara com
`"00101"` ao vivo, acha drift, comita `00101` de novo sem aspas, repete a cada 15 s.
Corrigido forçando `default_style="'"` no `yaml.dump` (aspas em todo escalar) — igual
ao que o Kubernetes já faz implicitamente (todo valor de `ConfigMap.data` é string).
Documentado aqui em vez de escondido, como os demais bugs reais desta sessão.

**Prova real de round-trip completo** (`evidence/improvements/*_config-bridge-proof.txt`):

```
-- PUT /config cell_id=7 (operador simulado, contornando o GitOps) --
{"status":"updated", ..., "config":{"cell_id":7, ...}}

-- logs do config-bridge --
DRIFT detectado {'cell_id': (1, 7)} -> comitando correcao no pacote
commit publicado c75b1eaaa540 (RootSync vai reconciliar sozinho)

-- ConfigMap real no cluster apos RootSync reconciliar --
CFG_CELL_ID=7

-- RootSync sincronizou EXATAMENTE o commit do config-bridge --
{"commit":"c75b1eaaa540b9f55f1bafdc7230f4d3d90df947", "errorSummary":{}}
```

**Custo de RAM medido:** 1 pod, `requests: 32Mi/10m` / `limits: 64Mi/100m` — o menor
componente do laboratório.

**Escopo desta implementação:** aplicado a `oran-du`/`cell_id` (o mesmo par já usado no
Experimento 2), não às 3 CNFs. O padrão é generalizável (basta adicionar entradas em
`WATCHED` no `bridge.py`), mas isso ficou fora do escopo desta melhoria pontual.

## 4. O que isso muda na caracterização do laboratório

- `report/part2-report.md` §14 item 2 ("Sem GitOps contínuo no `o-cloud-1`") deixa de ser
  uma limitação **geral** e passa a ser uma limitação **de decisão de escopo original,
  já superada** — mantida no relatório original por fidelidade histórica ao que foi
  entregue na Parte 2, com este documento registrando a evolução posterior.
- `docs/monitoring.md` ("sem `kubectl top`") também deixa de se aplicar ao `o-cloud-1`.
- `report/part2-report.md` §14 item 5 ("`cell_id` não propaga de volta ao pacote") também
  deixa de ser uma limitação geral — superada, para `oran-du`/`cell_id`, pelo
  `config-bridge` (§3). Continua válida para os demais campos/NFs não incluídos em
  `WATCHED`.
- As demais lacunas (O1, NF real, FOCOM federado, fragilidade do `o-cloud-1` a restart da
  VM) **permanecem** — nenhuma delas cabe no orçamento de 16 GB sem uma segunda máquina
  dedicada, conforme já analisado em `docs/real-nf-extension.md`.

## 5. Recuperação de infraestrutura registrada nesta sessão (contexto operacional)

Como parte deste trabalho, a VM do WSL2 havia reiniciado (uptime zerado) e tanto o
`o-cloud-1` quanto, momentaneamente, o `nephio-mgmt` precisaram de recuperação — o
`o-cloud-1` teve o `/etc/kubernetes/pki` do control-plane corrompido pelo halt abrupto
anterior (não recuperável por `docker start`; corrigido com
`scripts/reprovision-ocloud.sh`, o mesmo mecanismo O2 IMS real, não um `kind create`
manual) e o Gitea do `nephio-mgmt` ficou preso em `Unknown` (corrigido com um simples
`kubectl delete pod` para forçar recriação pelo StatefulSet). Ambos os incidentes e suas
causas-raiz são consistentes com as fragilidades já documentadas em
`docs/05-experiment-report.md` §11 itens 5 e 6, e não indicam nenhum problema novo — apenas
reafirmam, na prática, a limitação já conhecida de infraestrutura CAPD sobre WSL2.
