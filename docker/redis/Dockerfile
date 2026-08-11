ARG REDIS_IMAGE=redis:8.8.1-alpine
FROM ${REDIS_IMAGE}

COPY redis.conf /etc/redis/redis.conf
COPY redis-entrypoint-wrapper.sh redis-healthcheck /usr/local/bin/
RUN chmod 0555 /usr/local/bin/redis-entrypoint-wrapper.sh /usr/local/bin/redis-healthcheck

ENTRYPOINT ["/usr/local/bin/redis-entrypoint-wrapper.sh"]
CMD ["redis-server", "/etc/redis/redis.conf"]
