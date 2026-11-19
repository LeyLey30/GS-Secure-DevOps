# Imagem enxuta (alpine) e que roda SEM root (uid 101).
FROM nginxinc/nginx-unprivileged:1.27-alpine

# Aplica os patches de seguranca dos pacotes do sistema (corrige CVEs da imagem base)
USER root
RUN apk upgrade --no-cache

COPY nginx/default.conf /etc/nginx/conf.d/default.conf
COPY mvp/ /usr/share/nginx/html/

# Nenhum segredo na imagem: o painel e estatico e nao recebe credenciais.
# Volta para o usuario sem privilegios
USER 101
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD wget -qO- http://127.0.0.1:8080/healthz || exit 1
