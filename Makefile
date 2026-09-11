# Makefile (Fase 16) - roda DENTRO do WSL2 Ubuntu, a partir da raiz do repositório.
#   wsl -d Ubuntu
#   cd "/mnt/c/Users/.../SMO/X"
#   make up | make status | make experiment | make down
.PHONY: up status experiment down deploy cnfs cleanup report validate help

help:
	@echo "Alvos disponíveis:"
	@echo "  make up          - management cluster + Nephio + O-Cloud (o-cloud-1), idempotente"
	@echo "  make deploy      - idem 'up' + publica/atualiza as 3 CNFs via Porch"
	@echo "  make status      - visão geral do laboratório (clusters, O2 IMS, CNFs, recursos)"
	@echo "  make experiment  - roda os 6 experimentos formais e grava results/experiments.csv"
	@echo "  make validate    - scripts/validate-lab.sh (10 checagens PASS/FAIL/SKIP)"
	@echo "  make report      - snapshot de recursos (evidence/resources/)"
	@echo "  make down        - scripts/cleanup.sh (pergunta antes de cada remoção)"
	@echo "  make cleanup     - idem 'down', sem perguntar (--yes)"

up:
	bash scripts/check-requirements.sh
	bash scripts/install-nephio.sh

deploy: up
	bash scripts/06-porch-repos.sh openran
	bash lab/nephio/deploy-cnfs-via-porch.sh

cnfs:
	bash lab/nephio/deploy-cnfs-via-porch.sh

status:
	bash scripts/status.sh

experiment:
	bash scripts/run-experiments.sh all

validate:
	bash scripts/validate-lab.sh

report:
	bash scripts/resource-usage.sh makefile-report

down:
	bash scripts/cleanup.sh

cleanup:
	bash scripts/cleanup.sh --yes
