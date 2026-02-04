#!/bin/bash
# Lunet RealWorld Example App Launcher
# =====================================
#
# This script runs the Conduit API server with proper environment setup.
# It handles finding the lunet binary and setting up library paths.

set -e

cd "$(dirname "$0")"

# Load .env file if present
if [ -f ".env" ]; then
	set -a
	source .env
	set +a
fi

# Configuration with defaults
PORT=${PORT:-8080}
HOST=${HOST:-127.0.0.1}
DB_PATH=${DB_PATH:-.tmp/conduit.sqlite3}

export PORT HOST DB_PATH

echo "Starting Lunet RealWorld API Server..."
echo "Listen: $HOST:$PORT"
echo "Database: $DB_PATH"

# Initialize database if needed
if [ ! -f "$DB_PATH" ]; then
	echo "Initializing database..."
	mkdir -p "$(dirname "$DB_PATH")"
	if command -v sqlite3 &>/dev/null; then
		sqlite3 "$DB_PATH" <app/schema_sqlite.sql
		echo "Database initialized."
	else
		echo "Warning: sqlite3 not found, database will be created on first run"
	fi
fi

# Find lunet binary
LUNET_BIN=""
if [ -f "./bin/lunet" ]; then
	LUNET_BIN="./bin/lunet"
elif command -v lunet &>/dev/null; then
	LUNET_BIN="lunet"
elif [ -f "../lunet/build/lunet" ]; then
	LUNET_BIN="../lunet/build/lunet"
else
	# Search in common locations
	for path in /usr/local/bin/lunet /opt/lunet/bin/lunet; do
		if [ -f "$path" ]; then
			LUNET_BIN="$path"
			break
		fi
	done
fi

if [ -z "$LUNET_BIN" ]; then
	echo "ERROR: lunet binary not found"
	echo "Please ensure lunet is installed or built"
	echo "See: https://github.com/lua-lunet/lunet"
	exit 1
fi

echo "Using lunet: $LUNET_BIN"

# Set up library path for SQLite driver
if [ -d "./lib" ]; then
	export LUA_CPATH="./lib/?.so;./lib/?.dll;$LUA_CPATH"
fi

# Also check sibling lunet build
if [ -d "../lunet/build" ]; then
	SQLITE_SO=$(find ../lunet/build -name 'sqlite3.so' -type f 2>/dev/null | head -1)
	if [ -n "$SQLITE_SO" ]; then
		export LUA_CPATH="$(dirname $SQLITE_SO)/?.so;$LUA_CPATH"
	fi
fi

echo ""

# Run the server
exec "$LUNET_BIN" app/main.lua "$@"
