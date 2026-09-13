"""
config-bridge - fecha a lacuna "cell_id nao propaga de volta ao pacote"
(report/part2-report.md Sec.14 item 5 / docs/05-experiment-report.md Sec.11).

O QUE FAZ: a cada intervalo, le a config AO VIVO de cada NF (GET /config, a mesma API
usada no Experimento 2 - PUT /config para mudar cell_id) e compara com o "estado
publicado no pacote" (o ConfigMap tal como esta comitado no repo Gitea/Porch
"openran-cnfs"). Quando um operador muda a config via API (contornando o GitOps), este
controller detecta o drift e comita a correcao direto no branch "main" do repo via API
REST do Gitea - o RootSync continuo ja instalado (scripts/11-ocloud-configsync.sh)
detecta esse commit sozinho e reconcilia o ConfigMap no cluster.

SIMPLIFICACAO DELIBERADA E DOCUMENTADA: o commit vai direto pro branch "main" via API
de conteudo do Gitea, SEM passar pelo ciclo Draft->Proposed->Published do Porch
(porchctl rpkg ...). Fazer isso via Porch exigiria dar a este controller acesso de rede
ao apiserver agregado do Porch no management cluster (cross-cluster) e reimplementar em
Python o mesmo fluxo rpkg copy/push/propose/approve ja existente em
lab/nephio/deploy-cnfs-via-porch.sh. Para o proposito de fechar ESTA lacuna especifica
(propagacao de config, nao o ciclo de vida do pacote em si) o commit direto no Gitea e
suficiente e mais simples - e o mesmo backend Git que o Porch usa como fonte de verdade.

NAO E um operador Kubernetes no sentido kopf/controller-runtime (nao reage a eventos do
apiserver do Kubernetes) - e um poller HTTP simples, porque o estado que ele observa
(o /config em memoria de cada NF) NAO e um recurso do Kubernetes, entao nao ha evento
do apiserver para reagir. Documentado aqui em vez de forcar uma dependencia (kopf) que
nao se encaixa no problema real.
"""
import os
import time
import base64
import logging

import requests
import yaml

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("config-bridge")

GITEA_URL = os.environ.get("GITEA_URL", "http://172.18.0.200:3000")
GITEA_USER = os.environ.get("GITEA_USER", "nephio")
GITEA_TOKEN = os.environ["GITEA_TOKEN"]
REPO = os.environ.get("GITEA_REPO", "nephio/openran-cnfs")
BRANCH = os.environ.get("GITEA_BRANCH", "main")
POLL_SECONDS = int(os.environ.get("POLL_SECONDS", "15"))

# NF -> (url do /config, arquivo do ConfigMap no repo, prefixo das chaves de config de dominio)
WATCHED = {
    "oran-du": {
        "config_url": "http://oran-du.openran-lab.svc.cluster.local:8080/config",
        "cm_path": "openran-nfs/oran-du-configmap.yaml",
        # (chave no ConfigMap, tipo Python do valor ao vivo em /config) - plmn_id e
        # string (zero a esquerda importa: "00101" != 101), os demais sao int. Um
        # bug real apareceu aqui na primeira versao: coercao "adivinhada" (isdigit())
        # convertia "00101" -> 101 e gerava um drift falso a cada ciclo.
        "field_to_key": {
            "plmn_id": ("CFG_PLMN_ID", str),
            "cell_id": ("CFG_CELL_ID", int),
            "tx_power_dbm": ("CFG_TX_POWER_DBM", int),
            "du_id": ("CFG_DU_ID", int),
        },
    },
}

AUTH = (GITEA_USER, GITEA_TOKEN)


def get_live_config(nf: str) -> dict:
    r = requests.get(WATCHED[nf]["config_url"], timeout=5)
    r.raise_for_status()
    return r.json()["config"]


def get_package_file(nf: str):
    """Retorna (conteudo_yaml_dict, sha, conteudo_bruto) do ConfigMap tal como esta
    publicado no branch main do repo - a fonte de verdade do GitOps."""
    path = WATCHED[nf]["cm_path"]
    url = f"{GITEA_URL}/api/v1/repos/{REPO}/contents/{path}"
    r = requests.get(url, params={"ref": BRANCH}, auth=AUTH, timeout=10)
    r.raise_for_status()
    body = r.json()
    raw = base64.b64decode(body["content"]).decode()
    return yaml.safe_load(raw), body["sha"], raw


def package_config(nf: str, cm_doc: dict) -> dict:
    data = cm_doc.get("data", {})
    out = {}
    for field, (key, cast) in WATCHED[nf]["field_to_key"].items():
        v = data.get(key)
        out[field] = cast(v) if v is not None else None
    return out


def commit_updated_configmap(nf: str, cm_doc: dict, sha: str, live_cfg: dict):
    path = WATCHED[nf]["cm_path"]
    for field, (key, _cast) in WATCHED[nf]["field_to_key"].items():
        cm_doc["data"][key] = str(live_cfg[field])
    # default_style="'" forca aspas em TODO escalar, mesmo os que "parecem" numero
    # (ex.: "00101"). Sem isto, o PyYAML pode emitir CFG_PLMN_ID: 00101 sem aspas -
    # um padrao que o resolver de int do YAML 1.1 (octal-like) reconhece e, na
    # proxima leitura, vira o inteiro 101 (perde o zero a esquerda). Isso causava um
    # loop: le 101, compara com "00101" ao vivo, acha drift, comita de novo, repete.
    new_raw = yaml.dump(cm_doc, sort_keys=False, default_flow_style=False, default_style="'")
    url = f"{GITEA_URL}/api/v1/repos/{REPO}/contents/{path}"
    payload = {
        "message": f"config-bridge: sincroniza {nf} com /config ao vivo "
        f"(drift detectado, config_version mudou via API)",
        "content": base64.b64encode(new_raw.encode()).decode(),
        "sha": sha,
        "branch": BRANCH,
    }
    r = requests.put(url, json=payload, auth=AUTH, timeout=10)
    r.raise_for_status()
    return r.json()["commit"]["sha"]


def reconcile_once():
    for nf in WATCHED:
        try:
            live = get_live_config(nf)
        except Exception as e:
            log.warning("%s: /config indisponivel (%s) - pulando", nf, e)
            continue
        try:
            cm_doc, sha, _raw = get_package_file(nf)
        except Exception as e:
            log.warning("%s: nao consegui ler o ConfigMap no Gitea (%s) - pulando", nf, e)
            continue
        pkg = package_config(nf, cm_doc)
        drift = {k: (pkg.get(k), v) for k, v in live.items() if pkg.get(k) != v}
        if not drift:
            log.info("%s: sem drift (pacote == /config ao vivo)", nf)
            continue
        log.info("%s: DRIFT detectado %s -> comitando correcao no pacote", nf, drift)
        new_sha = commit_updated_configmap(nf, cm_doc, sha, live)
        log.info("%s: commit publicado %s (RootSync vai reconciliar sozinho)", nf, new_sha[:12])


def main():
    log.info(
        "config-bridge iniciado | repo=%s branch=%s poll=%ss nfs=%s",
        REPO, BRANCH, POLL_SECONDS, list(WATCHED),
    )
    while True:
        reconcile_once()
        time.sleep(POLL_SECONDS)


if __name__ == "__main__":
    main()
