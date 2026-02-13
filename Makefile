# Lunet RealWorld Example App - Makefile
# =======================================
#
# A complete RealWorld "Conduit" API implementation using the Lunet framework.
# Lunet is cloned at build time per https://github.com/lua-lunet/lunet/blob/main/docs/XMAKE_INTEGRATION.md

LUNET_DIR := lunet
LUNET_VERSION := v0.1.2
LUNET_REPO := https://github.com/lua-lunet/lunet.git
LUNET_BIN := $(LUNET_DIR)/build/macosx/arm64/release/lunet-run

# Database configuration
DB_PATH ?= .tmp/conduit.sqlite3
PID_FILE ?= .tmp/server.pid

# Default timeout for commands (seconds)
TIMEOUT := 10

# Detect timeout command (GNU coreutils vs BSD)
TIMEOUT_CMD := $(shell command -v gtimeout 2>/dev/null || command -v timeout 2>/dev/null || echo "")

.PHONY: all build run run-debug run-mysql run-postgres stop test bench clean clean-all help init dev install-vendor

all: help

# Vendor lib versions (content-addressed for cache busting)
PREACT_URL := https://unpkg.com/preact@10.19.3/dist/preact.min.js
HOOKS_URL := https://unpkg.com/preact@10.19.3/hooks/dist/hooks.umd.js
HTM_URL := https://unpkg.com/htm@3.1.1/dist/htm.umd.js
TAILWIND_URL := https://cdn.tailwindcss.com

# Install vendor libs with content-addressed filenames (SHA256 first 8 chars)
# Run: make install-vendor
# Updates www/vendor/dist/ and www/vendor/manifest.txt
install-vendor:
	@mkdir -p www/vendor/dist
	@echo "Downloading vendor libraries..."
	@curl -sL -o /tmp/preact.min.js "$(PREACT_URL)" && \
		PREACT_SHA=$$(sha256sum /tmp/preact.min.js | cut -c1-8) && \
		mv /tmp/preact.min.js www/vendor/dist/preact-$$PREACT_SHA.min.js && \
		echo "PREACT_FILE=preact-$$PREACT_SHA.min.js" > www/vendor/manifest.txt
	@curl -sL -o /tmp/hooks.umd.js "$(HOOKS_URL)" && \
		HOOKS_SHA=$$(sha256sum /tmp/hooks.umd.js | cut -c1-8) && \
		mv /tmp/hooks.umd.js www/vendor/dist/preact-hooks-$$HOOKS_SHA.umd.js && \
		echo "HOOKS_FILE=preact-hooks-$$HOOKS_SHA.umd.js" >> www/vendor/manifest.txt
	@curl -sL -o /tmp/htm.umd.js "$(HTM_URL)" && \
		HTM_SHA=$$(sha256sum /tmp/htm.umd.js | cut -c1-8) && \
		mv /tmp/htm.umd.js www/vendor/dist/htm-$$HTM_SHA.umd.js && \
		echo "HTM_FILE=htm-$$HTM_SHA.umd.js" >> www/vendor/manifest.txt
	@curl -sL -o /tmp/tailwind.js "$(TAILWIND_URL)" && \
		TAILWIND_SHA=$$(sha256sum /tmp/tailwind.js | cut -c1-8) && \
		mv /tmp/tailwind.js www/vendor/dist/tailwind-$$TAILWIND_SHA.js && \
		echo "TAILWIND_FILE=tailwind-$$TAILWIND_SHA.js" >> www/vendor/manifest.txt
	@echo "Vendor libs installed. Manifest: www/vendor/manifest.txt"
	@cat www/vendor/manifest.txt

# Build lunet if needed (clones at LUNET_VERSION if not present)
$(LUNET_BIN):
	@echo "Building lunet v$(LUNET_VERSION)..."
	@if [ ! -d "$(LUNET_DIR)" ]; then \
		echo "Cloning lunet $(LUNET_VERSION)..."; \
		git clone --branch $(LUNET_VERSION) --depth 1 $(LUNET_REPO) $(LUNET_DIR); \
	fi
	@cd $(LUNET_DIR) && \
		xmake f -m release --lunet_trace=n --lunet_verbose_trace=n -y && \
		xmake build && \
		xmake build lunet-sqlite3

build: $(LUNET_BIN)
	@echo "Build complete. Lunet binary: $(LUNET_BIN)"
	@echo "SQLite driver: $$(find $(LUNET_DIR)/build -name 'sqlite3.so' -type f | head -1)"

# Initialize SQLite database
init:
	@mkdir -p .tmp
	@if [ -f "$(DB_PATH)" ]; then \
		echo "Database already exists at $(DB_PATH)"; \
	else \
		echo "Creating SQLite database at $(DB_PATH)..."; \
		sqlite3 "$(DB_PATH)" < app/schema_sqlite.sql; \
		echo "Database initialized."; \
	fi

# Set up LUA_CPATH for the SQLite driver
define setup_env
	SQLITE_SO=$$(find $(LUNET_DIR)/build -name 'sqlite3.so' -type f 2>/dev/null | head -1); \
	if [ -n "$$SQLITE_SO" ]; then \
		export LUA_CPATH="$$(dirname $$SQLITE_SO)/?.so;;"; \
	fi; \
	export LUA_PATH="$(LUNET_DIR)/src/?.lua;;"
endef

# Run the server (SQLite default, background)
run: build init
	@echo "Starting Conduit API server..."
	@$(setup_env); $(LUNET_BIN) app/main.lua & echo $$! > $(PID_FILE)
	@sleep 1
	@echo "Server started (PID: $$(cat $(PID_FILE)))"
	@echo "API: http://127.0.0.1:8080/api"
	@echo "UI:  http://127.0.0.1:8080/"

# Run in foreground (development mode)
dev: build init
	@echo "Starting Conduit API server in foreground..."
	@$(setup_env); $(LUNET_BIN) app/main.lua

# Run with debug output
run-debug: build init
	@echo "Starting Conduit API server with debug..."
	@$(setup_env); DEBUG=1 $(LUNET_BIN) app/main.lua

# Run with MySQL
run-mysql: build
	@echo "Starting Conduit API server with MySQL..."
	@$(setup_env); DB_DRIVER=mysql $(LUNET_BIN) app/main.lua & echo $$! > $(PID_FILE)
	@echo "Server started (PID: $$(cat $(PID_FILE)))"

# Run with PostgreSQL
run-postgres: build
	@echo "Starting Conduit API server with PostgreSQL..."
	@$(setup_env); DB_DRIVER=postgres $(LUNET_BIN) app/main.lua & echo $$! > $(PID_FILE)
	@echo "Server started (PID: $$(cat $(PID_FILE)))"

# Stop server
stop:
	@if [ -f $(PID_FILE) ]; then \
		PID=$$(cat $(PID_FILE)); \
		if kill -0 $$PID 2>/dev/null; then \
			echo "Stopping server (PID: $$PID)..."; \
			kill $$PID; \
			rm -f $(PID_FILE); \
			echo "Server stopped."; \
		else \
			echo "Server not running (stale PID file)."; \
			rm -f $(PID_FILE); \
		fi \
	else \
		echo "No PID file found. Server may not be running."; \
	fi

# Run API tests (server must be running)
test:
	@echo "Running API tests..."
	@if [ -f bin/test_api.sh ]; then \
		./bin/test_api.sh; \
	else \
		echo "Test script not found. Running basic health check..."; \
		curl -s --max-time 3 http://127.0.0.1:8080/api/tags || echo "ERROR: Server not responding"; \
		echo ""; \
	fi

# Quick smoke test (server must be running)
smoke:
	@echo "Testing server endpoints..."
	@curl -s --max-time 5 http://localhost:8080/api/tags || echo "ERROR: Server not responding"
	@echo ""
	@echo ""
	@echo "Testing user registration..."
	@curl -s --max-time 5 -X POST http://localhost:8080/api/users \
		-H "Content-Type: application/json" \
		-d '{"user":{"username":"smoketest'$$RANDOM'","email":"smoke'$$RANDOM'@test.com","password":"password123"}}' | head -c 200
	@echo ""

# Memory benchmark (starts its own server)
bench: build init
ifneq ($(TIMEOUT_CMD),)
	@echo "Running memory benchmark..."
	@$(setup_env); $(TIMEOUT_CMD) 30 ./test/bench.sh || echo "Benchmark timed out or failed"
else
	@echo "WARNING: No timeout command available, running without timeout"
	@$(setup_env); ./test/bench.sh
endif

# Shell-based stress test (server must be running)
stress:
	@echo "Running 50 sequential requests..."
	@for i in $$(seq 1 50); do \
		curl -s --max-time 3 http://localhost:8080/api/tags > /dev/null && echo -n "." || echo -n "X"; \
	done
	@echo ""
	@echo "Done"

# Clean temporary files (safe - moves to .tmp/trash)
clean:
	@echo "Cleaning temporary files..."
	@mkdir -p .tmp/trash
	@[ -f $(PID_FILE) ] && mv $(PID_FILE) .tmp/trash/server.pid.$$(date +%Y%m%d_%H%M%S) 2>/dev/null || true
	@[ -f .tmp/*.log ] && mv .tmp/*.log .tmp/trash/ 2>/dev/null || true
	@echo "Cleaned temporary files (moved to .tmp/trash/)"

# Deep clean (including lunet build)
clean-all: clean
	@echo "Cleaning all build artifacts..."
	cd $(LUNET_DIR) && xmake clean 2>/dev/null || true
	@echo "Removing cloned lunet directory..."
	rm -rf $(LUNET_DIR)
	@echo "Cleaned all build artifacts"

# Show help
help:
	@echo "Lunet RealWorld Example App"
	@echo "==========================="
	@echo ""
	@echo "A complete RealWorld \"Conduit\" API implementation using Lunet."
	@echo ""
	@echo "Usage:"
	@echo "  make build        - Build lunet v$(LUNET_VERSION) (clones if needed)"
	@echo "  make init         - Initialize SQLite database"
	@echo "  make run          - Start server (port 8080, background)"
	@echo "  make dev          - Start server in foreground (development)"
	@echo "  make run-debug    - Start with debug output"
	@echo "  make run-mysql    - Start with MySQL backend"
	@echo "  make run-postgres - Start with PostgreSQL backend"
	@echo "  make stop         - Stop background server"
	@echo "  make test         - Run API integration tests"
	@echo "  make smoke        - Quick smoke test"
	@echo "  make bench        - Run memory benchmark"
	@echo "  make stress       - Run stress test (50 requests)"
	@echo "  make install-vendor - Download vendor libs (preact, htm, tailwind) with content-addressed filenames"
	@echo "  make clean        - Clean temporary files"
	@echo "  make clean-all    - Clean all including lunet build"
	@echo ""
	@echo "Environment variables:"
	@echo "  LUNET_LISTEN    - Listen address (default: tcp://127.0.0.1:8080)"
	@echo "  DB_DRIVER       - Database: sqlite, mysql, postgres (default: sqlite)"
	@echo "  DB_PATH         - SQLite database path (default: .tmp/conduit.sqlite3)"
	@echo "  DB_HOST         - Database host (MySQL/PostgreSQL)"
	@echo "  DB_PORT         - Database port"
	@echo "  DB_USER         - Database user"
	@echo "  DB_PASSWORD     - Database password"
	@echo "  DB_NAME         - Database name"
	@echo "  JWT_SECRET      - JWT signing secret (change in production!)"
	@echo ""
	@echo "Quick Start:"
	@echo "  1. make build (clones lunet v$(LUNET_VERSION) automatically)"
	@echo "  2. make run"
	@echo "  3. Open http://localhost:8080/"
