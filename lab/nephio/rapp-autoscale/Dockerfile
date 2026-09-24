# rapp-autoscale - rApp simulado (Non-RT RIC / SMO). Ver rapp.py para o design e a
# justificativa de por que isto e um rApp e nao um xApp.
FROM python:3.12-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY rapp.py .

EXPOSE 0
USER 65532:65532

CMD ["python", "rapp.py"]
