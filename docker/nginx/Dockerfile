ARG NGINX_IMAGE=nginxinc/nginx-unprivileged:1.29.4-alpine
FROM ${NGINX_IMAGE}

USER root
RUN apk add --no-cache curl
USER 101:101
