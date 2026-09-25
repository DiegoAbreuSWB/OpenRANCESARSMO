#!/usr/bin/env python3
"""Renderiza capturas de terminal estilizadas a partir de SAIDA REAL de comandos
(copiada literalmente de evidence/ e dos logs desta sessao) - nao e uma tela do SO,
mas o CONTEUDO e 100% real, nao inventado. Estilo "janela de terminal" para ficar
legivel em slide/PDF.
"""
from PIL import Image, ImageDraw, ImageFont

ROOT = "/mnt/c/Users/diego.abreu/Documents/Desenvolvimento/Curso CESAR/SMO/X"
MONO = "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"
MONO_B = "/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf"
SANS_B = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"

BG = (13, 21, 27)
BAR = (22, 33, 42)
BORDER = (34, 48, 60)
INK = (215, 230, 227)
DIM = (120, 138, 148)
GREEN = (111, 217, 154)
CYAN = (91, 224, 207)
AMBER = (240, 185, 98)
ROSE = (239, 127, 154)
PROMPT = (91, 224, 207)

FS = 21
LH = 30
PAD_X = 28
PAD_TOP = 60
PAD_BOT = 26
SCALE = 2  # supersample for crispness


def color_for(line: str):
    l = line.lower()
    if line.startswith("$"):
        return PROMPT
    if any(k in l for k in ["fulfilled", "successful", "success", "running", "ready", "ok", "created", "published", "sincroniza", "acao aplicada", "decisao"]):
        return GREEN
    if any(k in l for k in ["drift", "warning", "pending", "not yet present", "reverificação", "reverificacao"]):
        return AMBER
    if any(k in l for k in ["error", "failed", "not found", "refused"]):
        return ROSE
    if line.startswith("--") or line.startswith("=="):
        return CYAN
    return INK


def render(title: str, lines: list[str], out_path: str, width: int = 1180):
    W = width * SCALE
    font = ImageFont.truetype(MONO, FS * SCALE)
    font_b = ImageFont.truetype(SANS_B, 19 * SCALE)
    n = len(lines)
    H = (PAD_TOP + n * LH + PAD_BOT) * SCALE

    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)

    # barra de titulo
    d.rectangle([0, 0, W, PAD_TOP * SCALE], fill=BAR)
    for i, (cx, c) in enumerate([(24, (239, 116, 107)), (48, (240, 185, 98)), (72, (111, 217, 154))]):
        d.ellipse([(cx - 6) * SCALE, (PAD_TOP // 2 - 6) * SCALE, (cx + 6) * SCALE, (PAD_TOP // 2 + 6) * SCALE], fill=c)
    d.text((W / 2, PAD_TOP * SCALE / 2), title, font=font_b, fill=(196, 208, 214), anchor="mm")
    d.line([(0, PAD_TOP * SCALE), (W, PAD_TOP * SCALE)], fill=BORDER, width=2 * SCALE)

    y = PAD_TOP * SCALE
    for line in lines:
        col = color_for(line)
        d.text((PAD_X * SCALE, y + 4 * SCALE), line, font=font, fill=col)
        y += LH * SCALE

    d.rectangle([0, 0, W - SCALE, H - SCALE], outline=BORDER, width=2 * SCALE)
    img = img.resize((W // SCALE, H // SCALE), Image.LANCZOS)
    img.save(out_path)
    print("wrote", out_path)


shots = {
    "term-o2ims-fulfilled": (
        "kubectl get provisioningrequest o-cloud-1 -o yaml",
        [
            "$ kubectl get provisioningrequest.o2ims.provisioning.oran.org o-cloud-1 -o yaml",
            "",
            "status:",
            "  provisionedResourceSet:",
            "    oCloudInfrastructureResourceIds:",
            "    - 57bc09d8-d8a6-401c-b987-32702eebda4a",
            "    oCloudNodeClusterId: b98f3882-3b4e-4372-99cd-48be7843aba7",
            "  provisioningStatus:",
            "    provisioningMessage: Cluster resource created",
            "    provisioningState: fulfilled",
            "    provisioningUpdateTime: \"2026-09-10T16:22:18Z\"",
            "",
            "-- cadeia real: ProvisioningRequest -> o2ims-operator -> PackageVariant",
            "-- -> PackageRevision (Porch) -> Cluster API + CAPD -> containers Docker",
        ],
    ),
    "term-exp1-apply": (
        "lab/nephio/deploy-cnfs-via-porch.sh — Experimento 1",
        [
            "$ bash lab/nephio/deploy-cnfs-via-porch.sh",
            "== 1) publica/atualiza o pacote no Porch (repo=openran-cnfs) ==",
            "openran-cnfs.openran-nfs.v1789101326 created / pushed / proposed / approved",
            "",
            "== 3) reconcilia no o-cloud-1 via kpt live apply ==",
            "namespace/openran-lab apply successful",
            "configmap/oran-core-identity apply successful",
            "configmap/oran-cu-identity apply successful",
            "configmap/oran-du-identity apply successful",
            "deployment.apps/oran-core apply successful",
            "deployment.apps/oran-cu apply successful",
            "deployment.apps/oran-du apply successful",
            "apply result: 10 attempted, 10 successful, 0 skipped, 0 failed",
            "",
            "oran-cu    -> 200 {\"status\":\"ok\",\"nf_type\":\"O-CU\",...}",
            "oran-du    -> 200 {\"status\":\"ok\",\"nf_type\":\"O-DU\",...}",
            "oran-core  -> 200 {\"status\":\"ok\",\"nf_type\":\"5GC-AMF-sim\",...}",
        ],
    ),
    "term-configbridge-drift": (
        "config-bridge — fechando o loop /config → pacote",
        [
            "$ curl -X PUT oran-du:8080/config -d '{\"cell_id\": 7}'   # contorna o GitOps",
            "{\"status\":\"updated\",\"config\":{\"cell_id\":7,...},\"config_version\":2}",
            "",
            "-- logs do config-bridge --",
            "DRIFT detectado {'cell_id': (1, 7)} -> comitando correcao no pacote",
            "commit publicado c75b1eaaa540 (RootSync vai reconciliar sozinho)",
            "",
            "-- ConfigMap real no cluster, 29s depois --",
            "$ kubectl get cm oran-du-identity -o jsonpath='{.data.CFG_CELL_ID}'",
            "CFG_CELL_ID=7",
            "",
            "-- RootSync sincronizou exatamente esse commit --",
            "{\"commit\":\"c75b1eaaa540b9f55f1bafdc7230f4d3d90df947\",\"errorSummary\":{}}",
        ],
    ),
    "term-rapp-decision": (
        "rapp-autoscale — decisão de escala não-tempo-real",
        [
            "$ kubectl logs deploy/rapp-autoscale --tail=4",
            "rapp-autoscale iniciado | alvo=openran-lab/oran-cu | poll=30s (nao-tempo-real)",
            "politica: rate>1.00 req/s -> scale up | rate<0.10 req/s -> scale down",
            "",
            "sem acao: rate=0.00 req/s replicas=1 (dentro da faixa)",
            "",
            "-- apos 300 requisicoes de carga (5.99s) --",
            "DECISAO rApp: rate=10.27 req/s replicas=1 -> 2 (politica nao-tempo-real)",
            "acao aplicada via Kubernetes API (patch Deployment/oran-cu scale)",
            "",
            "-- achado real: RootSync revertia p/ 1 (pacote ainda tinha replicas:1) --",
            "-- corrigido: 'replicas' removido do pacote (rApp passa a ser o dono) --",
        ],
    ),
    "term-metrics-top": (
        "metrics-server — monitoramento real no o-cloud-1",
        [
            "$ kubectl --context o-cloud-1 top nodes",
            "NAME                     CPU(cores)  CPU%   MEMORY(bytes)  MEMORY%",
            "o-cloud-1-...-cbjjq      333m        5%     971Mi          9%",
            "o-cloud-1-md-0-...       148m        2%     576Mi          5%",
            "",
            "$ kubectl --context o-cloud-1 top pods -A | head -6",
            "kube-apiserver-...       113m        255Mi",
            "etcd-...                 67m         39Mi",
            "metrics-server-...       7m          14Mi",
            "oran-cu-...              1m          5Mi",
        ],
    ),
    "term-validate-lab": (
        "scripts/validate-lab.sh — 10/10 PASS",
        [
            "================ VALIDATE LAB ================",
            "1) Management Cluster existe                [PASS]",
            "2) Nephio esta saudavel (Porch/Gitea/ConfigSync) [PASS]",
            "3) Componentes O2 IMS necessarios existem    [PASS]",
            "4) Workload cluster (O-Cloud) existe          [PASS]",
            "5) Workload cluster responde                  [PASS]",
            "6) demo-nf pode ser implantada                 [PASS]",
            "7) demo-nf fica Ready                          [PASS]",
            "8) scale funciona (1 -> 3)                     [PASS]",
            "9) delete de pod gera reconciliacao            [PASS]",
            "10) cleanup funciona                            [PASS]",
            "",
            "================ RESUMO: PASS=10  FAIL=0  SKIP=0 ================",
        ],
    ),
}

for name, (title, lines) in shots.items():
    for outdir in ["report/assets", "presentation/assets"]:
        render(title, lines, f"{ROOT}/{outdir}/{name}.png")
