#!/usr/bin/env bash
# Gera trafego para ultrapassar o limite do alerta (padrao: 30 req em 5 min).
# Uso: ./03-disparar-alerta.sh https://SEU-APP.azurecontainerapps.io
set -euo pipefail
URL="${1:?informe a URL do MVP}"
for i in $(seq 1 80); do
  curl -s -o /dev/null -w "%{http_code} " "$URL/"
  sleep 0.5
done
echo; echo "Pronto. Aguarde 2-5 min e veja Monitor > Alertas."
