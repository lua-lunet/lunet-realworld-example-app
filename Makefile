# Lunet RealWorld Example App - Makefile
# =======================================

# Configuration
LUNET ?= lunet
DB_PATH ?= .tmp/conduit.sqlite3
PID_FILE ?= .tmp/server.pid

.PHONY: help init run run-mysql run-postgres stop test clean

help:
	@echo "Lunet RealWorld Example App"
	@echo ""
	@echo "Usage:"
	@echo "  make init         Initialize SQLite database"
	@echo "  make run          Start server (SQLite, port 8080)"
	@echo "  make run-mysql    Start server with MySQL"
	@echo "  make run-postgres Start server with PostgreSQL"
	@echo "  make stop         Stop server"
	@echo "  make test         Run API tests"
	@echo "  make clean        Remove temporary files"
	@echo ""
	@echo "Environment variables:"
	@echo "  LUNET_LISTEN    Listen address (default: tcp://127.0.0.1:8080)"
	@echo "  DB_DRIVER       Database: sqlite, mysql, postgres"
	@echo "  DB_PATH         SQLite database path"
	@echo "  DB_HOST         Database host"
	@echo "  DB_PORT         Database port"
	@echo "  DB_USER         Database user"
	@echo "  DB_PASSWORD     Database password"
	@echo "  DB_NAME         Database name"

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

# Run server with SQLite (default)
run: init
	@echo "Starting Conduit API server..."
	@$(LUNET) app/main.lua & echo $$! > $(PID_FILE)
	@echo "Server started (PID: $$(cat $(PID_FILE)))"
	@echo "API: http://127.0.0.1:8080/api"
	@echo "UI:  http://127.0.0.1:8080/"

# Run server with MySQL
run-mysql:
	@echo "Starting Conduit API server with MySQL..."
	@DB_DRIVER=mysql $(LUNET) app/main.lua & echo $$! > $(PID_FILE)
	@echo "Server started (PID: $$(cat $(PID_FILE)))"

# Run server with PostgreSQL
run-postgres:
	@echo "Starting Conduit API server with PostgreSQL..."
	@DB_DRIVER=postgres $(LUNET) app/main.lua & echo $$! > $(PID_FILE)
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

# Run API tests
test:
	@if [ -f bin/test_api.sh ]; then \
		./bin/test_api.sh; \
	else \
		echo "Test script not found. Running basic health check..."; \
		curl -s http://127.0.0.1:8080/api/tags | head -c 100; \
		echo ""; \
	fi

# Clean temporary files
clean:
	@echo "Cleaning temporary files..."
	@rm -rf .tmp
	@echo "Done."

# Development: run in foreground (no backgrounding)
dev: init
	@echo "Starting Conduit API server in foreground..."
	@$(LUNET) app/main.lua
