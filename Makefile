SHELL := /bin/bash
MAKEFLAGS += --no-print-directory

DOCKER_COMPOSE ?= docker compose
DOCKER_SERVICE ?= codex-dev
COMPOSE_BAKE ?= true
RUN_DIR ?= /workspace/codex/.cache/codex-playground
DOCKER_EXEC ?= $(DOCKER_COMPOSE) exec -T $(DOCKER_SERVICE)
DOCKER_EXEC_INTERACTIVE ?= $(DOCKER_COMPOSE) exec $(DOCKER_SERVICE)

.PHONY: help up down restart setup format test test_cli test_tui build run run_no_build test_and_run shell
.SILENT:

help:
	@echo "Targets:"
	@echo "  make up              Start long-lived Docker dev container"
	@echo "  make down            Stop and remove Docker dev container"
	@echo "  make restart         Restart Docker dev container"
	@echo "  make setup           Build Docker image and warm Rust deps once"
	@echo "  make format          Run Rust formatter in Docker"
	@echo "  make test_cli        Run codex-cli tests in Docker"
	@echo "  make test_tui        Run codex-tui tests in Docker"
	@echo "  make test            Run full test suite (codex-cli + codex-tui) in Docker"
	@echo "  make build           Build Codex in Docker (no host export)"
	@echo "  make run             Build (incremental), then run Codex in Docker"
	@echo "  make run_no_build    Run Codex in Docker without building"
	@echo "  make test_and_run    Test, then build and run Codex (supports RUN_DIR='...')"
	@echo "  make shell           Open interactive shell in Docker dev container"

up:
	$(DOCKER_COMPOSE) up -d $(DOCKER_SERVICE) >/dev/null 2>&1
	echo "Up: OK"

down:
	$(DOCKER_COMPOSE) down --remove-orphans

restart: down up

setup:
	start_s=$$(date +%s); \
	tmp=$$(mktemp); \
	mkdir -p .cache/codex-home; \
	if COMPOSE_BAKE=$(COMPOSE_BAKE) $(DOCKER_COMPOSE) build $(DOCKER_SERVICE) >$$tmp 2>&1 && \
		$(DOCKER_COMPOSE) up -d $(DOCKER_SERVICE) >>$$tmp 2>&1 && \
		$(DOCKER_COMPOSE) exec -T --user root $(DOCKER_SERVICE) /bin/bash -lc 'set -euo pipefail; \
			mkdir -p /home/ubuntu/.cargo /home/ubuntu/.rustup /home/ubuntu/.codex; \
			chown -R ubuntu:ubuntu /home/ubuntu/.cargo /home/ubuntu/.rustup /home/ubuntu/.codex' >>$$tmp 2>&1 && \
		$(DOCKER_EXEC) /bin/bash -lc 'set -euo pipefail; \
			cd /workspace/codex/codex-rs; \
			just install' >>$$tmp 2>&1; then \
		end_s=$$(date +%s); \
		secs=$$(awk "BEGIN { printf \"%.2f\", $$end_s-$$start_s }"); \
		echo "Setup: OK ($${secs}s)"; \
	else \
		cat $$tmp; \
		rm -f $$tmp; \
		exit 1; \
	fi; \
	rm -f $$tmp

format:
	$(DOCKER_COMPOSE) up -d $(DOCKER_SERVICE) >/dev/null 2>&1
	start_s=$$(date +%s); \
	tmp=$$(mktemp); \
	if $(DOCKER_EXEC) /bin/bash -lc 'set -euo pipefail; \
		cd /workspace/codex/codex-rs; \
		just fmt' >$$tmp 2>&1; then \
		end_s=$$(date +%s); \
		secs=$$(awk "BEGIN { printf \"%.2f\", $$end_s-$$start_s }"); \
		echo "Format: OK ($${secs}s)"; \
	else \
		cat $$tmp; \
		rm -f $$tmp; \
		exit 1; \
	fi; \
	rm -f $$tmp

test:
	$(DOCKER_COMPOSE) up -d $(DOCKER_SERVICE) >/dev/null 2>&1
	start_s=$$(date +%s); \
	tmp=$$(mktemp); \
	if $(DOCKER_EXEC) /bin/bash -lc 'set -euo pipefail; \
		cd /workspace/codex/codex-rs; \
		cargo test -p codex-cli; \
		cargo test -p codex-tui' >$$tmp 2>&1; then \
		end_s=$$(date +%s); \
		secs=$$(awk "BEGIN { printf \"%.2f\", $$end_s-$$start_s }"); \
		echo "Test: OK ($${secs}s)"; \
	else \
		cat $$tmp; \
		rm -f $$tmp; \
		exit 1; \
	fi; \
	rm -f $$tmp

test_cli:
	$(DOCKER_COMPOSE) up -d $(DOCKER_SERVICE) >/dev/null 2>&1
	start_s=$$(date +%s); \
	tmp=$$(mktemp); \
	if $(DOCKER_EXEC) /bin/bash -lc 'set -euo pipefail; \
		cd /workspace/codex/codex-rs; \
		cargo test -p codex-cli' >$$tmp 2>&1; then \
		end_s=$$(date +%s); \
		secs=$$(awk "BEGIN { printf \"%.2f\", $$end_s-$$start_s }"); \
		echo "Test CLI: OK ($${secs}s)"; \
	else \
		cat $$tmp; \
		rm -f $$tmp; \
		exit 1; \
	fi; \
	rm -f $$tmp

test_tui:
	$(DOCKER_COMPOSE) up -d $(DOCKER_SERVICE) >/dev/null 2>&1
	start_s=$$(date +%s); \
	tmp=$$(mktemp); \
	if $(DOCKER_EXEC) /bin/bash -lc 'set -euo pipefail; \
		cd /workspace/codex/codex-rs; \
		cargo test -p codex-tui' >$$tmp 2>&1; then \
		end_s=$$(date +%s); \
		secs=$$(awk "BEGIN { printf \"%.2f\", $$end_s-$$start_s }"); \
		echo "Test TUI: OK ($${secs}s)"; \
	else \
		cat $$tmp; \
		rm -f $$tmp; \
		exit 1; \
	fi; \
	rm -f $$tmp

build:
	$(DOCKER_COMPOSE) up -d $(DOCKER_SERVICE) >/dev/null 2>&1
	start_s=$$(date +%s); \
	tmp=$$(mktemp); \
	if $(DOCKER_EXEC) /bin/bash -lc 'set -euo pipefail; \
		cd /workspace/codex/codex-rs; \
		cargo build --bin codex' >$$tmp 2>&1; then :; else \
		cat $$tmp; rm -f $$tmp; exit 1; \
	fi; \
	end_s=$$(date +%s); \
	secs=$$(awk "BEGIN { printf \"%.2f\", $$end_s-$$start_s }"); \
	echo "Build: OK ($${secs}s)"; \
	echo "Ready: make run"; \
	rm -f $$tmp

run:
	$(DOCKER_COMPOSE) up -d $(DOCKER_SERVICE) >/dev/null 2>&1
	start_s=$$(date +%s); \
	tmp=$$(mktemp); \
	if $(DOCKER_EXEC) /bin/bash -lc 'set -euo pipefail; \
		cd /workspace/codex/codex-rs; \
		cargo build --bin codex' >$$tmp 2>&1; then :; else \
		cat $$tmp; rm -f $$tmp; exit 1; \
	fi; \
	end_s=$$(date +%s); \
	secs=$$(awk "BEGIN { printf \"%.2f\", $$end_s-$$start_s }"); \
	echo "Run prep: OK ($${secs}s)"; \
	rm -f $$tmp; \
	$(DOCKER_EXEC_INTERACTIVE) /bin/bash -lc "set -euo pipefail; mkdir -p '$(RUN_DIR)'; cd '$(RUN_DIR)'; /workspace/codex/codex-rs/target/debug/codex"

run_no_build:
	$(DOCKER_COMPOSE) up -d $(DOCKER_SERVICE) >/dev/null 2>&1
	$(DOCKER_EXEC_INTERACTIVE) /bin/bash -lc "set -euo pipefail; mkdir -p '$(RUN_DIR)'; cd '$(RUN_DIR)'; /workspace/codex/codex-rs/target/debug/codex"

test_and_run: test
	$(MAKE) run RUN_DIR='$(RUN_DIR)'

shell:
	$(DOCKER_COMPOSE) up -d $(DOCKER_SERVICE) >/dev/null 2>&1
	$(DOCKER_EXEC_INTERACTIVE) /bin/bash
