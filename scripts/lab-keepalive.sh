#!/usr/bin/env bash
# lab-keepalive.sh - mantém a VM do WSL2 (e portanto o cluster kind) viva.
#
# O WSL2 desliga a VM ~60s depois que a última sessão fecha. Quando isso acontece
# o container do kind para e o cluster reinicia "sujo" a cada novo comando.
# Duas defesas:
#   1) vmIdleTimeout alto no C:\Users\<voce>\.wslconfig  (já configurado)
#   2) este processo, que segura uma sessão aberta enquanto o lab estiver em uso.
#
# Uso (deixe rodando num terminal PowerShell/Windows durante todo o laboratório):
#   wsl -d Ubuntu -- bash /mnt/c/.../scripts/lab-keepalive.sh
# ou, mais simples, apenas mantenha UM terminal WSL aberto.
echo "[keepalive] segurando a VM do WSL2 viva - PID $$  ($(date -Is))"
trap 'echo "[keepalive] encerrado"; exit 0' INT TERM
while true; do sleep 3600; done
