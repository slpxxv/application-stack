# Docker Infrastructure Stack

This repository contains Docker infrastructure only: service composition,
container configuration, monitoring, backups, operator tooling, and release
automation. It is not a development environment and does not store resources
outside the infrastructure layer.

## Table of contents

- [Requirements](#requirements)
- [Quick start](#quick-start)
- [Environments](#environments)
- [Service profiles](#service-profiles)
- [Configuration](#configuration)
- [Networks](#networks)
- [Volumes](#volumes)
- [Secrets and security](#secrets-and-security)
- [Monitoring and logs](#monitoring-and-logs)
- [Backup and restore](#backup-and-restore)
- [Deployment and rollback](#deployment-and-rollback)
- [Testing and diagnostics](#testing-and-diagnostics)
- [Troubleshooting](#troubleshooting)
- [Architecture decision](#architecture-decision)
- [License](#license)

## Requirements

- Docker Engine with Docker Compose v2
- GNU Make

## Quick start

Create an ignored local configuration file:

```sh
cp .env.example .env
```

Create the secret files described in [Secrets and security](#secrets-and-security),
then validate and start the selected services:

```sh
make config ENV=local COMPOSE_PROFILES=postgres,monitoring
make up ENV=local COMPOSE_PROFILES=postgres,monitoring
make status ENV=local COMPOSE_PROFILES=postgres,monitoring
```

Run `make help` to list all operator commands.

## Environments

Every command selects an environment through `ENV`. The Makefile always merges
the base Compose file with exactly one environment override and gives the
result an isolated project name.

| `ENV` | Compose files | Project name |
| --- | --- | --- |
| `local` | `compose.yaml`, `compose.local.yaml` | `<prefix>-local` |
| `test` | `compose.yaml`, `compose.test.yaml` | `<prefix>-test` |
| `production` | `compose.yaml`, `compose.production.yaml` | `<prefix>-production` |

The environments differ as follows:

- `local` publishes operator ports on `127.0.0.1` only and uses persistent
  local volumes.
- `test` publishes no ports and uses an isolated project name and volumes that
  are removed after the infrastructure test.
- `production` publishes only the reverse proxy, applies resource limits, and
  uses the `unless-stopped` restart policy.

Environment-specific, non-secret examples are available under `examples/env/`.

## Service profiles

Optional services are enabled with the comma-separated `COMPOSE_PROFILES`
variable.

| Profile | Services |
| --- | --- |
| `proxy` | Unprivileged Nginx |
| `postgres` | PostgreSQL and its Prometheus exporter |
| `redis` | Redis and its Prometheus exporter |
| `rabbitmq` | RabbitMQ with management UI and native metrics |
| `monitoring` | Prometheus, Grafana, Loki, Alloy, and cAdvisor |

Examples:

```sh
make config ENV=local COMPOSE_PROFILES=postgres,monitoring
make up ENV=local COMPOSE_PROFILES=postgres,monitoring
make logs ENV=local COMPOSE_PROFILES=postgres,monitoring
make down ENV=local COMPOSE_PROFILES=postgres,monitoring
```

An empty `COMPOSE_PROFILES` value starts no services. Every new service must be
assigned to the required networks and profile, have a health check where
possible, and use an explicit volume when it stores data.

## Configuration

The `.env.example` file is the complete public inventory of infrastructure
variables. A local `.env` file is not tracked by Git. Important groups include:

- versioned upstream and custom runtime images;
- host ports for locally published interfaces;
- non-secret database and broker identifiers;
- external secret and backup paths;
- monitoring retention and Grafana public URL.

For production, replace image tags with OCI digests returned by the registry.
This makes deployments reproducible even if a registry tag is moved.

Port variables control host mappings only. A production port must be published
only when it is an intentional public entry point. Data services remain on an
internal network.

## Networks

- `public` carries traffic to explicitly published infrastructure interfaces.
- `data` carries internal traffic to stateful services and is inaccessible
  from the host.
- `monitoring` carries internal metrics and logs.

The `data` and `monitoring` networks use `internal: true`. Each service is
connected only to networks required for its operation.

## Volumes

The base model defines separate named volumes for PostgreSQL, Redis, RabbitMQ,
Prometheus, Grafana, and Loki. Compose project names isolate volumes between
environments.

`make clean ENV=<environment>` stops the selected project and removes only its
named volumes. Back up stateful services before using this command.

## Secrets and security

### Required secret files

Secrets live outside the repository. The default local directory is
`./secrets`; production should point `SECRETS_PATH` to a directory managed by
the deployment platform.

Required files:

- `postgres_password`
- `redis_password`
- `redis_exporter_passwords.json`
- `rabbitmq_password`
- `grafana_admin_password`

The Redis exporter file maps an address to credentials:

```json
{"redis://redis:6379":"username:password"}
```

Never commit actual values. The secret directory should use mode `0700`.
Files should be accessible only to the operator and the corresponding
container UID, using mode `0640`, a dedicated group, or ACLs. Grafana runs as
UID 472 and postgres-exporter as UID 65534. Verify permissions on the target
host because bind mounts preserve its permission model.

Rotate secrets one at a time and recreate the affected container afterward.
For services that store credentials internally, replacing the file does not
replace the administrative password. Use this order:

1. Change the credential in the service.
2. Update the external secret file.
3. Recreate the container.
4. Verify its health and connectivity.

### Container hardening

Services use `no-new-privileges`, read-only root filesystems, bounded `tmpfs`,
log rotation, and dropped Linux capabilities. Stateful containers regain only
the capabilities their upstream entrypoints need to set data ownership and
switch to an unprivileged user. Persistent data lives in separate volumes, and
the data and monitoring networks are internal.

cAdvisor and Alloy are controlled exceptions. cAdvisor needs access to host
resources and runs as privileged. Alloy reads the Docker socket, which provides
broad visibility into the host. Run both only on a dedicated, trusted host.
The socket and host paths are mounted read-only.

In production, enable GitHub environment protection, restrict access to the
deployment host, and terminate TLS at an external load balancer or enable the
provided Nginx TLS template with read-only certificate mounts. Never store a
private key in the repository or an image.

## Monitoring and logs

The `monitoring` profile starts Prometheus, Grafana, Loki, Alloy, and cAdvisor.
Prometheus collects its own metrics, container metrics, Loki and Alloy metrics,
RabbitMQ's native endpoint, and PostgreSQL and Redis metrics through dedicated
exporters. Data-service exporters start with their corresponding profiles.
Unreachable targets appear on Prometheus `/targets` but do not stop the
collector.

Alloy discovers containers through the Docker socket and sends their
stdout/stderr logs to Loki. Grafana is automatically provisioned with
Prometheus and Loki data sources and the `Infrastructure overview` dashboard.

In `local`, the interfaces are available through `GRAFANA_PORT` and
`PROMETHEUS_PORT`. With the `proxy` profile enabled, Grafana is also available
under `/grafana/`. `PROMETHEUS_RETENTION` and `LOKI_RETENTION` control storage
retention.

Verify the stack after startup:

```sh
make status ENV=local COMPOSE_PROFILES=monitoring
curl --fail http://127.0.0.1:9090/-/ready
curl --fail http://127.0.0.1:3000/api/health
```

## Backup and restore

Archives are written to `BACKUP_PATH`, include a UTC timestamp in their name,
and receive a SHA-256 checksum file. PostgreSQL, Redis, and RabbitMQ definitions
have separate commands:

```sh
make backup-postgres ENV=production COMPOSE_PROFILES=postgres
make backup-redis ENV=production COMPOSE_PROFILES=redis
make backup-rabbitmq ENV=production COMPOSE_PROFILES=rabbitmq
make retention ENV=production
```

Restore requires an existing archive, a valid checksum, and an exact target
confirmation. For the `infrastructure` database in the production project:

```sh
make restore-postgres ENV=production FILE=/backup/file.dump \
  RESTORE_CONFIRM=infrastructure-production:infrastructure
```

For Redis and RabbitMQ, the final confirmation component is `redis` or
`rabbitmq`. Redis restore stops the service while replacing its snapshot.
RabbitMQ export contains broker definitions, not queued messages.

Copy backups away from the Docker host and test restoration regularly in an
isolated project. Retention only removes recognized backup and checksum files
older than `BACKUP_RETENTION_DAYS` from the validated backup directory.

## Deployment and rollback

The `image.yaml` workflow publishes the custom Nginx, PostgreSQL, Redis, and
RabbitMQ images to GHCR when a release tag is created. Builds target AMD64 and
ARM64, include provenance and SBOMs, and are scanned before release.

The production `.env` must select active profiles, point to host-managed
secrets, and reference versioned images. Use registry digests for full
immutability.

The manually triggered `deploy.yaml` workflow requires:

- a protected GitHub environment named `production`;
- a runner labeled `self-hosted` and `production`;
- the version to deploy;
- a known-good rollback version.

The workflow pulls images, recreates services, and waits up to 180 seconds for
health checks. A failed readiness check automatically restores the specified
rollback version. Data rollback is a separate destructive procedure and is
never performed automatically.

Before deployment, back up every enabled stateful service. After deployment,
verify:

```sh
make status ENV=production
curl --fail http://your-host/healthz
```

## Testing and diagnostics

Validate any environment without starting containers:

```sh
make config ENV=production COMPOSE_PROFILES=proxy,postgres,redis,rabbitmq,monitoring
```

The smallest integration test starts an ephemeral stack and always removes its
containers and volumes:

```sh
make test-infrastructure ENV=test \
  COMPOSE_PROFILES=proxy,postgres,redis,rabbitmq
```

Display container and health status with:

```sh
make status ENV=local COMPOSE_PROFILES=proxy,postgres,redis,rabbitmq,monitoring
```

## Troubleshooting

### The Compose model does not validate

Run `make config ENV=<environment>` and inspect missing variables. `.env` must
exist, and `SECRETS_PATH` must point to a directory accessible to the Docker
daemon.

### A container is unhealthy

Run `make status`, followed by `make logs`. Check volume permissions, access to
the relevant secret file, and free space on the host. Do not remove a stateful
volume before creating a backup.

### Monitoring cannot discover containers

Verify that Alloy can read `/var/run/docker.sock` and that cAdvisor can access
the required host paths. Docker Desktop may expose only a subset of host
metrics; this is a platform limitation rather than a Prometheus configuration
error.

### The proxy returns 502

The target service and the proxy profile must be running at the same time and
share the `monitoring` network. `/healthz` checks only the proxy process and
should continue to return HTTP 200.

## Architecture decision

### ADR 0001: Independent services through Compose profiles

- Status: accepted
- Date: 2026-08-11

One base composition defines services, networks, and volumes. Environments are
implemented as overrides, while optional groups are activated through the
`proxy`, `postgres`, `redis`, `rabbitmq`, and `monitoring` profiles.

This keeps the configuration in a single source of truth, while the Compose
project name isolates environment resources. Operators must explicitly select
profiles and must not assume that an operational dependency starts unless it
is declared in Compose.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE).
