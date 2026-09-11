# Kubernetes local (Fase 10)

## Decisão: kind (não k3d, não single-node "puro")

Avaliação pedida entre `kind`, `k3d` e single-node Kubernetes:

| Opção | Decisão |
|---|---|
| **kind** | ✅ **Escolhido.** Já validado neste ambiente (WSL2/Docker) para o laboratório Nephio/O2IMS: `nephio-mgmt` (management) e `o-cloud-1` (workload) rodam com kind há dias, de forma estável, dentro do orçamento de RAM. Reaproveitar evita reintroduzir risco. |
| k3d | ❌ Não instalado nem necessário — resolveria o mesmo problema que o kind já resolve aqui, sem ganho. |
| single-node "puro" (kubeadm direto) | ❌ Mais trabalho operacional (bootstrap manual) sem benefício sobre o kind para este escopo. |

**Separação management/workload:** o Nephio já opera, neste projeto, com dois clusters kind —
`nephio-mgmt` (management) e `o-cloud-1` (workload, provisionado pelo próprio Nephio via O2
IMS — ver `docs/05-experiment-report.md`). **Reaproveitamos essa topologia** em vez de criar um
terceiro cluster: as CNFs deste laboratório (Fase 9) rodam no **mesmo `o-cloud-1`**, que já
representa o O-Cloud/workload cluster do experimento. Isso está dentro do orçamento de RAM (o
`o-cloud-1` mede ~1,4 GiB com 14 pods; 3 CNFs de ~64–128Mi cada somam no máximo ~384Mi a mais).

> Só documentaríamos uma "versão simplificada" (Level B/C, ver `docs/real-nf-extension.md` /
> Fase 20) se o `o-cloud-1` não estivesse disponível — não é o caso.

## Manifests

```
lab/kubernetes/
├── namespace.yaml          # cria o namespace 'openran-lab'
├── oran-cu/  {configmap,deployment,service}.yaml
├── oran-du/  {configmap,deployment,service}.yaml
└── oran-core/{configmap,deployment,service}.yaml
```

Cada `Deployment`:
- `securityContext` compatível com PodSecurity **restricted** (o `o-cloud-1` já aplica
  `enforce: baseline` / `warn: restricted` por padrão — ver `docs/05` §7), evitando os avisos
  que o `demo-nf` anterior gerava;
- `readinessProbe`/`livenessProbe` em `/health`;
- `envFrom` um `ConfigMap` de identidade (`NF_NAME`/`NF_TYPE`/`NF_VERSION`) — a configuração
  **operacional** (ex.: `cell_id`) continua sendo feita via a API `/config` da própria NF em
  runtime (Experimento 2), não via ConfigMap;
- limites de recurso:

```yaml
requests: { memory: 64Mi, cpu: 50m }
limits:   { memory: 128Mi, cpu: 200m }
```

**Orçamento somado das 3 CNFs:** requests 192Mi/150m · limits 384Mi/600m — marginal frente aos
~6 GiB "available" medidos no WSL com os dois clusters kind já de pé.

## Aplicação manual (Fase 10/11 — sem Nephio; Passo 7)

Como estes manifests usam imagens **construídas localmente** (`oran-cu:v1`, `oran-du:v1`,
`oran-core:v1` — ver `lab/cnfs/`), elas precisam ser carregadas no cluster kind antes do
`kubectl apply` (o kind não enxerga a imagem só por ela existir no Docker do host):

```bash
for nf in oran-cu oran-du oran-core; do
  docker build -t "$nf:v1" "lab/cnfs/$nf"
  kind load docker-image "$nf:v1" --name o-cloud-1
done

kubectl --context o-cloud-1 apply -f lab/kubernetes/namespace.yaml
kubectl --context o-cloud-1 apply -f lab/kubernetes/oran-cu/
kubectl --context o-cloud-1 apply -f lab/kubernetes/oran-du/
kubectl --context o-cloud-1 apply -f lab/kubernetes/oran-core/

kubectl --context o-cloud-1 -n openran-lab get deploy,pods,svc
```

Isto é o **Experimento 1** (provisionamento) feito com `kubectl apply` puro — o baseline "sem
Nephio" pedido no Passo 7, antes de integrar ao fluxo de pacotes do Nephio no Passo 9
(`docs/provisioning-flow.md`).
