SHELL := /bin/sh
.DEFAULT_GOAL := help

-include .env

ENV ?= local
COMPOSE_PROJECT_NAME ?= infrastructure
COMPOSE_PROFILES ?=
ENVIRONMENTS := local test production

COMPOSE := docker compose
COMPOSE_FILES := -f compose.yaml -f compose.$(ENV).yaml
PROJECT := $(COMPOSE_PROJECT_NAME)-$(ENV)
COMPOSE_RUN := COMPOSE_PROFILES="$(COMPOSE_PROFILES)" $(COMPOSE) --env-file .env --project-name $(PROJECT) $(COMPOSE_FILES)

.PHONY: help check-env config up down restart ps logs build pull clean status \
	backup-postgres backup-redis backup-rabbitmq restore-postgres restore-redis \
	restore-rabbitmq retention test-infrastructure

help: ## Show targets and configuration syntax
	@awk 'BEGIN {FS = ":.*## "; print "Usage: make <target> ENV=<local|test|production> COMPOSE_PROFILES=<profile,...>"} /^[a-zA-Z_-]+:.*## / {printf "  %-12s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

check-env:
	@case " $(ENVIRONMENTS) " in *" $(ENV) "*) ;; *) echo "Unsupported ENV='$(ENV)'; expected: $(ENVIRONMENTS)" >&2; exit 2;; esac
	@test -f .env || { echo "Missing .env; copy .env.example to .env" >&2; exit 2; }
	@test -f compose.yaml || { echo "Missing compose.yaml" >&2; exit 2; }
	@test -f compose.$(ENV).yaml || { echo "Missing compose.$(ENV).yaml" >&2; exit 2; }

config: check-env ## Render and validate the selected Compose model
	$(COMPOSE_RUN) config

up: check-env ## Start selected infrastructure services
	$(COMPOSE_RUN) up --detach --remove-orphans

down: check-env ## Stop the selected environment
	$(COMPOSE_RUN) down --remove-orphans

restart: down up ## Recreate selected infrastructure services

ps: check-env ## Show services in the selected environment
	$(COMPOSE_RUN) ps

logs: check-env ## Follow infrastructure service logs
	$(COMPOSE_RUN) logs --follow --tail=200

build: check-env ## Build infrastructure images
	$(COMPOSE_RUN) build

pull: check-env ## Pull infrastructure images
	$(COMPOSE_RUN) pull

clean: check-env ## Stop the environment and remove its named volumes
	$(COMPOSE_RUN) down --remove-orphans --volumes

status: check-env ## Report container and health status
	ENV=$(ENV) COMPOSE_PROFILES="$(COMPOSE_PROFILES)" ./infrastructure/scripts/status.sh

backup-postgres: check-env ## Create a checksummed PostgreSQL backup
	ENV=$(ENV) COMPOSE_PROFILES="$(COMPOSE_PROFILES)" ./infrastructure/backup/postgres-backup.sh

backup-redis: check-env ## Create a checksummed Redis snapshot
	ENV=$(ENV) COMPOSE_PROFILES="$(COMPOSE_PROFILES)" ./infrastructure/backup/redis-backup.sh

backup-rabbitmq: check-env ## Export checksummed RabbitMQ definitions
	ENV=$(ENV) COMPOSE_PROFILES="$(COMPOSE_PROFILES)" ./infrastructure/backup/rabbitmq-backup.sh

restore-postgres: check-env ## Restore FILE after explicit confirmation
	@test -n "$(FILE)" || { echo "FILE is required" >&2; exit 2; }
	ENV=$(ENV) COMPOSE_PROFILES="$(COMPOSE_PROFILES)" RESTORE_CONFIRM="$(RESTORE_CONFIRM)" ./infrastructure/backup/postgres-restore.sh "$(FILE)"

restore-redis: check-env ## Restore FILE after explicit confirmation
	@test -n "$(FILE)" || { echo "FILE is required" >&2; exit 2; }
	ENV=$(ENV) COMPOSE_PROFILES="$(COMPOSE_PROFILES)" RESTORE_CONFIRM="$(RESTORE_CONFIRM)" ./infrastructure/backup/redis-restore.sh "$(FILE)"

restore-rabbitmq: check-env ## Restore FILE after explicit confirmation
	@test -n "$(FILE)" || { echo "FILE is required" >&2; exit 2; }
	ENV=$(ENV) COMPOSE_PROFILES="$(COMPOSE_PROFILES)" RESTORE_CONFIRM="$(RESTORE_CONFIRM)" ./infrastructure/backup/rabbitmq-restore.sh "$(FILE)"

retention: check-env ## Delete backup files older than configured retention
	ENV=$(ENV) ./infrastructure/backup/retention.sh

test-infrastructure: check-env ## Start, verify and remove an ephemeral test stack
	ENV=test COMPOSE_PROFILES="$(COMPOSE_PROFILES)" ./infrastructure/scripts/test-stack.sh
