ARG POSTGRES_IMAGE=postgres:18.3-alpine
FROM ${POSTGRES_IMAGE}

COPY postgresql.conf /etc/postgresql/postgresql.conf
COPY init/10-observability.sql /docker-entrypoint-initdb.d/10-observability.sql

CMD ["postgres", "-c", "config_file=/etc/postgresql/postgresql.conf"]

