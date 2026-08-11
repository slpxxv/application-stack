ARG RABBITMQ_IMAGE=rabbitmq:4.3.4-management-alpine
FROM ${RABBITMQ_IMAGE}

COPY docker-entrypoint-wrapper.sh /usr/local/bin/docker-entrypoint-wrapper
RUN chmod 0555 /usr/local/bin/docker-entrypoint-wrapper

ENTRYPOINT ["/usr/local/bin/docker-entrypoint-wrapper"]
CMD ["rabbitmq-server"]

