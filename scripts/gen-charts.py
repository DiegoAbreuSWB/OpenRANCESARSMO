#!/usr/bin/env python3
"""Gera graficos reais (matplotlib) a partir de dados ja capturados no laboratorio.
Nenhum numero aqui e inventado - todos vem de results/experiments.csv e das evidencias
em evidence/improvements/ e evidence/o2ims/ (ver docs/improvements-16gb.md).
"""
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.font_manager as fm

ROOT = "/mnt/c/Users/diego.abreu/Documents/Desenvolvimento/Curso CESAR/SMO/X"

# paleta consistente com o dashboard (Console SMO Nephio)
TEAL = "#0d8a83"
AMBER = "#b5720b"
GREEN = "#1f7a4d"
ROSE = "#a83354"
SLATE = "#54606c"
INK = "#131b26"
BG = "#ffffff"
GRID = "#e3e9ee"

plt.rcParams.update({
    "font.family": "DejaVu Sans",
    "text.color": INK,
    "axes.edgecolor": GRID,
    "axes.labelcolor": INK,
    "xtick.color": SLATE,
    "ytick.color": SLATE,
    "figure.facecolor": BG,
    "axes.facecolor": BG,
    "savefig.facecolor": BG,
})

CAT_COLOR = {
    "Provisioning": TEAL,
    "Configuration": AMBER,
    "Lifecycle": SLATE,
    "Orchestration": GREEN,
    "Monitoring": "#6a4fb5",
    "Non-RT RIC": ROSE,
}

# ---------- Grafico 1: duracao dos experimentos (dados reais) ----------
experiments = [
    ("Instantiate\n(3 CNFs via Porch)", 20.4, "Provisioning"),
    ("Update/Upgrade\n(v1→v2, rollout)", 15.0, "Lifecycle"),
    ("Terminate\n(prune oran-core)", 10.8, "Lifecycle"),
    ("Scale\n(oran-cu 1→2)", 5.7, "Lifecycle"),
    ("Recover\n(pod deletado)", 3.9, "Lifecycle"),
    ("RootSync contínuo\n(commit→apply sem\ncomando manual)", 19.0, "Orchestration"),
    ("config-bridge\n(commit→reconciliação)", 29.0, "Configuration"),
    ("rApp\n(ciclo de decisão)", 30.0, "Non-RT RIC"),
    ("Config. operacional\n(PUT /config cell_id)", 0.713, "Configuration"),
]
experiments.sort(key=lambda x: x[1])
labels = [e[0] for e in experiments]
durations = [e[1] for e in experiments]
colors = [CAT_COLOR[e[2]] for e in experiments]

fig, ax = plt.subplots(figsize=(10, 6.2), dpi=200)
bars = ax.barh(labels, durations, color=colors, height=0.62, zorder=3)
ax.set_xlabel("Duração medida (segundos)", fontsize=11)
ax.set_title("Duração real dos experimentos e melhorias — laboratório Nephio/O-Cloud",
             fontsize=13, fontweight="bold", pad=14, color=INK)
ax.grid(axis="x", color=GRID, linewidth=1, zorder=0)
ax.set_axisbelow(True)
for spine in ["top", "right", "left"]:
    ax.spines[spine].set_visible(False)
ax.spines["bottom"].set_color(GRID)
for bar, val in zip(bars, durations):
    ax.text(bar.get_width() + 0.35, bar.get_y() + bar.get_height() / 2,
             f"{val:g}s", va="center", fontsize=9.5, color=INK, fontweight="bold")
ax.set_xlim(0, max(durations) * 1.18)

# legenda de categorias
import matplotlib.patches as mpatches
present_cats = sorted({e[2] for e in experiments}, key=lambda c: list(CAT_COLOR).index(c))
handles = [mpatches.Patch(color=CAT_COLOR[c], label=c) for c in present_cats]
ax.legend(handles=handles, loc="lower right", frameon=False, fontsize=9.5)

fig.text(0.01, 0.005,
          "Fonte: results/experiments.csv + evidence/improvements/ (dados reais capturados no laboratório)",
          fontsize=7.5, color=SLATE)
plt.tight_layout(rect=[0, 0.02, 1, 1])
plt.savefig(f"{ROOT}/report/assets/experiments-duration.png", bbox_inches="tight")
plt.savefig(f"{ROOT}/presentation/assets/experiments-duration.png", bbox_inches="tight")
plt.close()

# ---------- Grafico 2: uso de RAM medido vs orcamento ----------
fig, ax = plt.subplots(figsize=(9, 4.6), dpi=200)
components = [
    ("nephio-mgmt\n(Nephio R6 completo)", 3.8, TEAL),
    ("o-cloud-1\n(2 nós K8s)", 2.3, SLATE),
    ("3 CNFs simuladas\n(oran-cu/du/core)", 0.19, AMBER),
    ("metrics-server +\nconfig-bridge + rApp", 0.1, GREEN),
]
labels2 = [c[0] for c in components]
vals2 = [c[1] for c in components]
colors2 = [c[2] for c in components]
used = sum(vals2)
budget_wsl = 9.7
budget_host = 16.0

left = 0
bar_h = 0.55
for lab, val, col in zip(labels2, vals2, colors2):
    ax.barh(0, val, left=left, color=col, height=bar_h, zorder=3,
            edgecolor="white", linewidth=1.5)
    if val > 0.3:
        ax.text(left + val / 2, 0, f"{val:g} GiB", ha="center", va="center",
                 fontsize=9, color="white", fontweight="bold")
    left += val

ax.barh(0, budget_wsl - used, left=used, color=GRID, height=bar_h, zorder=2,
        label=f"disponível no WSL2 ({budget_wsl - used:.1f} GiB)")
ax.axvline(budget_wsl, color=ROSE, linestyle="--", linewidth=1.6, zorder=4)
ax.text(budget_wsl, 0.42, f"orçamento WSL2: {budget_wsl:g} GiB", color=ROSE,
        fontsize=9.5, ha="right", fontweight="bold")
ax.axvline(budget_host, color=INK, linestyle=":", linewidth=1.2, zorder=1)
ax.text(budget_host, -0.42, f"limite da máquina: {budget_host:g} GiB", color=SLATE,
        fontsize=9, ha="right")

ax.set_xlim(0, budget_host + 0.6)
ax.set_ylim(-0.6, 0.6)
ax.set_yticks([])
ax.set_xlabel("GiB de RAM", fontsize=11)
ax.set_title(f"Uso real de RAM — {used:.2f} GiB usados de {budget_wsl:g} GiB alocados ao WSL2 (máquina de {budget_host:g} GiB)",
             fontsize=12.5, fontweight="bold", pad=14, color=INK)
for spine in ax.spines.values():
    spine.set_visible(False)

handles2 = [mpatches.Patch(color=c, label=l.replace("\n", " ")) for l, v, c in components]
ax.legend(handles=handles2, loc="upper center", bbox_to_anchor=(0.5, -0.18),
          ncol=2, frameon=False, fontsize=9)

fig.text(0.01, 0.01, "Fonte: docker stats + kubectl top (metrics-server) — evidence/resources/, evidence/improvements/",
          fontsize=7.5, color=SLATE)
plt.tight_layout(rect=[0, 0.06, 1, 1])
plt.savefig(f"{ROOT}/report/assets/ram-usage.png", bbox_inches="tight")
plt.savefig(f"{ROOT}/presentation/assets/ram-usage.png", bbox_inches="tight")
plt.close()

print("charts ok")
