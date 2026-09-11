# CNFs simuladas (Fase 9)

> **Estas NÃO são funções O-RAN reais.** São três aplicações Python/FastAPI extremamente leves
> (~30–50 MiB de RAM cada), usadas exclusivamente como **workloads representativos** para
> demonstrar onboarding, provisioning, deployment, configuration management, monitoring,
> update, scaling, failure e recovery — os *mecanismos* de SMO/orchestration/lifecycle, não a
> pilha 5G/O-RAN em si. Nenhuma delas implementa protocolos de rádio, planos de
> usuário/controle reais, ou interfaces O-RAN (F1/E1/E2/N2/N3).

| CNF simulada | Representa (conceitualmente) | Config de exemplo |
|---|---|---|
| `oran-cu` | O-CU (Central Unit) | `plmn_id`, `cu_id`, `connected_du_count` |
| `oran-du` | O-DU (Distributed Unit) | `plmn_id`, **`cell_id`**, `tx_power_dbm` |
| `oran-core` | Core 5G simplificado (tipo AMF) | `amf_name`, `served_plmn`, `registered_ues` |

`oran-du` é a NF usada no **Experimento 2** (mudança de `cell_id`).

## API comum (idêntica nas 3 CNFs)

| Rota | Método | Descrição |
|---|---|---|
| `/health` | GET | status, nome/tipo da NF, uptime |
| `/config` | GET | configuração atual + versão |
| `/config` | PUT (ou POST) | atualiza campos da configuração; incrementa `config_version` |
| `/metrics` | GET | métricas em formato **Prometheus text exposition** |

## Métricas expostas

```
nf_up{nf_name="..."} 1
nf_requests_total{nf_name="..."} <contador>
nf_config_version{nf_name="..."} <versão atual>
nf_restart_count{nf_name="..."} <auto-reportado pelo processo>
```

> `nf_restart_count` é um contador **auto-reportado pelo processo da aplicação** (via variável
> de ambiente `NF_RESTART_COUNT`, opcionalmente injetada no manifesto). Ele **não** é o mesmo
> que o contador de reinícios do Kubernetes — para o valor autoritativo de reinícios do Pod, use
> `kubectl get pods` (coluna `RESTARTS`) ou `kubectl get pod <nome> -o jsonpath='{.status.containerStatuses[0].restartCount}'`.
> Essa distinção é intencional e documentada em [`docs/monitoring.md`](../../docs/monitoring.md).

## Build local (sem Kubernetes, sem Nephio)

```bash
cd lab/cnfs/oran-du
docker build -t oran-du:v1 .
docker run --rm -p 8080:8080 oran-du:v1
curl localhost:8080/health
curl localhost:8080/config
curl -X PUT localhost:8080/config -H 'content-type: application/json' -d '{"cell_id": 2}'
curl localhost:8080/metrics
```
