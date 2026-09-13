# config-bridge - poller que sincroniza /config das CNFs de volta pro pacote Porch/Gitea.
# Ver bridge.py para o design e as simplificacoes deliberadas.
FROM python:3.12-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY bridge.py .

EXPOSE 0
USER 65532:65532

CMD ["python", "bridge.py"]
