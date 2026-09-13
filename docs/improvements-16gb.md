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

## 3. O que isso muda na caracterização do laboratório

- `report/part2-report.md` §14 item 2 ("Sem GitOps contínuo no `o-cloud-1`") deixa de ser
  uma limitação **geral** e passa a ser uma limitação **de decisão de escopo original,
  já superada** — mantida no relatório original por fidelidade histórica ao que foi
  entregue na Parte 2, com este documento registrando a evolução posterior.
- `docs/monitoring.md` ("sem `kubectl top`") também deixa de se aplicar ao `o-cloud-1`.
- As demais lacunas (O1, NF real, FOCOM federado, fragilidade do `o-cloud-1` a restart da
  VM) **permanecem** — nenhuma delas cabe no orçamento de 16 GB sem uma segunda máquina
  dedicada, conforme já analisado em `docs/real-nf-extension.md`.

## 4. Recuperação de infraestrutura registrada nesta sessão (contexto operacional)

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
