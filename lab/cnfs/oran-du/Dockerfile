# oran-du - simulador leve de O-DU (workload representativo, NAO uma NF O-RAN real)
FROM python:3.12-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .

ENV NF_NAME=oran-du \
    NF_TYPE=O-DU \
    NF_VERSION=v1 \
    NF_RESTART_COUNT=0

EXPOSE 8080
USER 65532:65532

CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8080"]
