# Monitoramento (Fase 14)

## Decisão: Opção A (leve) — sem Prometheus/Grafana

Dado o orçamento de RAM (16 GB totais, meta de 10–12 GB para o laboratório inteiro) e o fato de
o Nephio **não** incluir um stack de observabilidade nativo (ver
[`docs/nephio-vs-smo.md`](nephio-vs-smo.md) — monitoring/telemetria = "não implementado"), a
Opção A foi adotada integralmente. A Opção B (Prometheus) **não foi instalada**.

## Mecanismos usados

### 1. `curl`/`kubectl exec` no endpoint `/metrics` de cada CNF

Cada CNF expõe métricas em **formato Prometheus text exposition** (sem precisar de um
Prometheus rodando — o formato é só texto):

```bash
kubectl --context o-cloud-1 -n openran-lab exec deploy/oran-du -- python3 -c "
import urllib.request
print(urllib.request.urlopen('http://localhost:8080/metrics', timeout=3).read().decode())
"
```

Saída real (exemplo, `oran-du`):
```
nf_up{nf_name="oran-du",nf_type="O-DU"} 1
nf_requests_total{nf_name="oran-du"} 7
nf_config_version{nf_name="oran-du"} 2
nf_restart_count{nf_name="oran-du"} 0
```

### 2. `kubectl top` (se o `metrics-server` existir)

**Não instalamos `metrics-server`** por decisão explícita (evitar peso extra — ver
`scripts/resource-usage.sh`, que já trata isso: *"Se metrics-server não estiver instalado, NÃO
instale automaticamente só por isso"*). `kubectl top nodes/pods` portanto **não está
disponível** neste laboratório; documentado como limitação, não escondido.

### 3. `docker stats` / `free -h` (nível de host)

Usado durante todo o laboratório (`scripts/resource-usage.sh`) para medir o custo real de RAM/CPU
de cada componente — é assim que os números de `results/` e dos relatórios foram obtidos (não
são estimativas).

### 4. Logs e eventos do Kubernetes

```bash
kubectl --context o-cloud-1 -n openran-lab logs deploy/<nf>
kubectl --context o-cloud-1 -n openran-lab get events --sort-by=.lastTimestamp
kubectl --context o-cloud-1 -n openran-lab describe pod <pod>
```

## O que isso NÃO é

Esse monitoramento é **operacional/de laboratório**, não FCAPS-P (Performance Management) O-RAN:
não há coleta periódica de KPI via O1, não há agregação temporal (série histórica), não há
alertas. As métricas `nf_*` são ilustrativas — não seguem nenhum modelo de dados O-RAN
padronizado.

## Se RAM permitir no futuro (Opção B)

`kube-prometheus-stack` (Helm chart) poderia ser instalado no `o-cloud-1` para scrape automático
dos `/metrics` das 3 CNFs (`ServiceMonitor`/anotações `prometheus.io/scrape`). Custo estimado:
Prometheus + Grafana + node-exporter ≈ 1–2 GiB adicionais — viável dentro da folga atual (~5,8
GiB *available*), mas não instalado neste laboratório por escolha de manter o escopo mínimo e
por não agregar ao objetivo pedagógico principal (mecanismos de SMO/orchestration/lifecycle).
