#!/bin/bash
# Memory benchmark for lunet-realworld
#
# Measures RSS memory after server startup and API operations.
# Usage: ./test/bench.sh [duration_seconds] [port]

set -e

DURATION=${1:-30}
PORT=${2:-8080}
PID_FILE=".tmp/bench_server.pid"

echo "=============================================="
echo "Lunet RealWorld Memory Benchmark"
echo "=============================================="
echo ""
echo "Duration: ${DURATION}s"
echo "Port: $PORT"
echo ""

# Function to get RSS in KB
get_rss() {
	local pid=$1
	if [ "$(uname)" = "Darwin" ]; then
		# macOS: use ps
		ps -o rss= -p "$pid" 2>/dev/null | tr -d ' '
	else
		# Linux: use /proc
		if [ -f "/proc/$pid/status" ]; then
			grep VmRSS /proc/$pid/status 2>/dev/null | awk '{print $2}'
		else
			ps -o rss= -p "$pid" 2>/dev/null | tr -d ' '
		fi
	fi
}

# Function to format memory
format_mem() {
	local kb=$1
	if [ "$kb" -ge 1024 ]; then
		echo "$((kb / 1024)) MB"
	else
		echo "${kb} KB"
	fi
}

# Check if server is already running
if [ -f "$PID_FILE" ]; then
	OLD_PID=$(cat "$PID_FILE")
	if kill -0 "$OLD_PID" 2>/dev/null; then
		echo "Stopping existing server (PID: $OLD_PID)..."
		kill "$OLD_PID" 2>/dev/null || true
		sleep 1
	fi
	rm -f "$PID_FILE"
fi

# Initialize database
mkdir -p .tmp
if [ ! -f ".tmp/conduit.sqlite3" ]; then
	echo "Initializing database..."
	sqlite3 .tmp/conduit.sqlite3 <app/schema_sqlite.sql
fi

# Find lunet binary
if [ -f "./bin/lunet" ]; then
	LUNET_BIN="./bin/lunet"
elif [ -f "../lunet/build/lunet" ]; then
	LUNET_BIN="../lunet/build/lunet"
elif command -v lunet &>/dev/null; then
	LUNET_BIN="lunet"
else
	echo "ERROR: lunet binary not found"
	exit 1
fi

# Set up library path
if [ -d "../lunet/build" ]; then
	SQLITE_SO=$(find ../lunet/build -name 'sqlite3.so' -type f 2>/dev/null | head -1)
	if [ -n "$SQLITE_SO" ]; then
		export LUA_CPATH="$(dirname $SQLITE_SO)/?.so;$LUA_CPATH"
	fi
fi

# Start server
echo "Starting server..."
$LUNET_BIN app/main.lua &
SERVER_PID=$!
echo $SERVER_PID >"$PID_FILE"
sleep 2

# Check if server started
if ! kill -0 $SERVER_PID 2>/dev/null; then
	echo "ERROR: Server failed to start"
	exit 1
fi

# Wait for server to be ready
echo "Waiting for server..."
for i in $(seq 1 10); do
	if curl -s --max-time 1 "http://localhost:$PORT/api/tags" >/dev/null 2>&1; then
		break
	fi
	sleep 1
done

# Initial memory
INITIAL_RSS=$(get_rss $SERVER_PID)
echo ""
echo "Initial RSS: $(format_mem $INITIAL_RSS)"
echo ""

# Run API operations
echo "Running API operations..."
echo ""

# Register users
echo -n "Registering users: "
for i in $(seq 1 10); do
	curl -s --max-time 3 -X POST "http://localhost:$PORT/api/users" \
		-H "Content-Type: application/json" \
		-d "{\"user\":{\"username\":\"bench$i$RANDOM\",\"email\":\"bench$i$RANDOM@test.com\",\"password\":\"password123\"}}" >/dev/null 2>&1 && echo -n "." || echo -n "X"
done
echo ""

# Get a token
TOKEN=$(curl -s --max-time 3 -X POST "http://localhost:$PORT/api/users/login" \
	-H "Content-Type: application/json" \
	-d '{"user":{"email":"bench1@test.com","password":"password123"}}' 2>/dev/null | grep -o '"token":"[^"]*"' | cut -d'"' -f4 || true)

if [ -n "$TOKEN" ]; then
	# Create articles
	echo -n "Creating articles: "
	for i in $(seq 1 10); do
		curl -s --max-time 3 -X POST "http://localhost:$PORT/api/articles" \
			-H "Content-Type: application/json" \
			-H "Authorization: Token $TOKEN" \
			-d "{\"article\":{\"title\":\"Bench Article $i $RANDOM\",\"description\":\"Test\",\"body\":\"Test body\",\"tagList\":[\"bench\"]}}" >/dev/null 2>&1 && echo -n "." || echo -n "X"
	done
	echo ""
fi

# List articles repeatedly
echo -n "Listing articles: "
for i in $(seq 1 20); do
	curl -s --max-time 3 "http://localhost:$PORT/api/articles?limit=10" >/dev/null 2>&1 && echo -n "." || echo -n "X"
done
echo ""

# Get tags repeatedly
echo -n "Getting tags: "
for i in $(seq 1 20); do
	curl -s --max-time 3 "http://localhost:$PORT/api/tags" >/dev/null 2>&1 && echo -n "." || echo -n "X"
done
echo ""

# Memory after operations
AFTER_OPS_RSS=$(get_rss $SERVER_PID)
echo ""
echo "RSS after operations: $(format_mem $AFTER_OPS_RSS)"

# Wait and measure final memory
echo ""
echo "Waiting ${DURATION}s for memory to stabilize..."
sleep $DURATION

FINAL_RSS=$(get_rss $SERVER_PID)
echo ""
echo "=============================================="
echo "Results"
echo "=============================================="
echo ""
echo "Initial RSS:      $(format_mem $INITIAL_RSS)"
echo "After operations: $(format_mem $AFTER_OPS_RSS)"
echo "Final RSS:        $(format_mem $FINAL_RSS)"
echo ""

# Calculate growth
GROWTH=$((FINAL_RSS - INITIAL_RSS))
if [ $INITIAL_RSS -gt 0 ]; then
	GROWTH_PCT=$((GROWTH * 100 / INITIAL_RSS))
	echo "Memory growth:    $(format_mem $GROWTH) (${GROWTH_PCT}%)"
fi
echo ""

# Stop server
echo "Stopping server..."
kill $SERVER_PID 2>/dev/null || true
rm -f "$PID_FILE"

echo ""
echo "Benchmark complete!"
