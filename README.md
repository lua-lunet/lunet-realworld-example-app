# Lunet RealWorld Example App

[![CI](https://github.com/lua-lunet/lunet-realworld-example-app/actions/workflows/ci.yml/badge.svg)](https://github.com/lua-lunet/lunet-realworld-example-app/actions/workflows/ci.yml)

A full-featured implementation of the [RealWorld "Conduit" API specification](https://realworld.io) using the [Lunet](https://github.com/lua-lunet/lunet) async I/O framework.

This is a canonical example of how to build a production-quality web application with Lunet, demonstrating significant resource savings compared to Node.js or Python alternatives.

## Why Lunet?

| Metric | Lunet | Node.js | Python/Django |
|--------|-------|---------|---------------|
| Docker Image | ~180 MB | ~450 MB | ~400 MB |
| Runtime Memory | ~8 MB | ~50 MB | ~80 MB |
| Cold Start | <100ms | ~500ms | ~1s |

Lunet provides the async I/O capabilities of Node.js with the resource efficiency of native code.

## Features

- Complete RealWorld API implementation
- User authentication with JWT (Argon2 password hashing)
- Articles, comments, favorites, tags
- User profiles and following
- SQLite by default, MySQL/PostgreSQL optional
- Static file serving with SPA fallback
- Unix socket and TCP support

## Quick Start

### Option 1: Download Pre-built Binary

```bash
# Download the latest release for your platform
curl -LO https://github.com/lua-lunet/lunet-realworld-example-app/releases/download/nightly/lunet-realworld-linux-amd64.tar.gz

# Extract
tar -xzf lunet-realworld-linux-amd64.tar.gz
cd lunet-realworld-linux-amd64

# Run (auto-initializes SQLite database)
./run.sh

# Open http://localhost:8080
```

### Option 2: Build from Source

```bash
# 1. Clone repositories
git clone https://github.com/lua-lunet/lunet.git
git clone https://github.com/lua-lunet/lunet-realworld-example-app.git
cd lunet-realworld-example-app

# 2. Build lunet and SQLite driver
make build

# 3. Start the server
make run

# 4. Open http://127.0.0.1:8080 in your browser
```

## Prerequisites

For building from source:

- [xmake](https://xmake.io/) build system
- [libuv](https://libuv.org/) async I/O library
- [LuaJIT](https://luajit.org/) (required for FFI)
- [libsodium](https://libsodium.org/) for cryptography
- SQLite3 (or MySQL/PostgreSQL)

### macOS

```bash
brew install xmake pkg-config libuv luajit libsodium sqlite
```

### Ubuntu/Debian

```bash
sudo apt-get install pkg-config libuv1-dev luajit libluajit-5.1-dev libsodium-dev sqlite3
# Install xmake: https://xmake.io/#/getting_started?id=installation
```

## Configuration

Configuration is via environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `LUNET_LISTEN` | `tcp://127.0.0.1:8080` | Server listen address |
| `DB_DRIVER` | `sqlite` | Database driver: `sqlite`, `mysql`, `postgres` |
| `DB_PATH` | `.tmp/conduit.sqlite3` | SQLite database path |
| `DB_HOST` | `127.0.0.1` | Database host (MySQL/PostgreSQL) |
| `DB_PORT` | `3306` | Database port |
| `DB_USER` | `root` | Database user |
| `DB_PASSWORD` | `root` | Database password |
| `DB_NAME` | `conduit` | Database name |
| `JWT_SECRET` | (default) | JWT signing secret (change in production!) |
| `JWT_EXPIRY` | `604800` | JWT expiry in seconds (7 days) |

### Listen Address Formats

```bash
# TCP (default)
LUNET_LISTEN=tcp://127.0.0.1:8080

# TCP on all interfaces (use with caution)
LUNET_LISTEN=tcp://0.0.0.0:8080

# Unix socket (for reverse proxy setups)
LUNET_LISTEN=unix:///tmp/conduit.sock
```

## Database Setup

### SQLite (Default)

```bash
make init
# Or manually:
mkdir -p .tmp
sqlite3 .tmp/conduit.sqlite3 < app/schema_sqlite.sql
```

### MySQL/MariaDB

```bash
mysql -u root -p conduit < app/schema_mysql.sql
DB_DRIVER=mysql DB_HOST=127.0.0.1 make dev
```

### PostgreSQL

```bash
psql -U postgres -d conduit -f app/schema.sql
DB_DRIVER=postgres DB_HOST=127.0.0.1 make dev
```

## Project Structure

```
lunet-realworld-example-app/
├── app/
│   ├── main.lua           # Entry point, routing, server
│   ├── config.lua         # Configuration
│   ├── db_config.lua      # Database configuration
│   ├── schema*.sql        # Database schemas
│   ├── handlers/          # Route handlers
│   │   ├── users.lua      # Authentication endpoints
│   │   ├── articles.lua   # Article CRUD
│   │   ├── comments.lua   # Comment management
│   │   ├── profiles.lua   # User profiles
│   │   └── tags.lua       # Tag listing
│   └── lib/               # Utilities
│       ├── auth.lua       # JWT authentication
│       ├── crypto.lua     # libsodium FFI bindings
│       ├── db.lua         # Database abstraction
│       ├── http.lua       # HTTP request/response
│       └── json.lua       # Pure Lua JSON
├── www/
│   └── index.html         # SPA frontend
├── bin/
│   └── test_api.sh        # API integration tests
├── test/
│   └── bench.sh           # Memory benchmark
├── .github/workflows/
│   └── ci.yml             # Matrix build CI
├── Makefile               # Development commands
├── run.sh                 # Launcher script
├── compare.sh             # Size comparison vs Node.js
└── lunet-realworld-example-app-scm-1.rockspec
```

## API Endpoints

All endpoints follow the [RealWorld API spec](https://realworld-docs.netlify.app/specifications/backend/endpoints/).

### Authentication

- `POST /api/users` - Register
- `POST /api/users/login` - Login
- `GET /api/user` - Get current user
- `PUT /api/user` - Update user

### Profiles

- `GET /api/profiles/:username` - Get profile
- `POST /api/profiles/:username/follow` - Follow user
- `DELETE /api/profiles/:username/follow` - Unfollow user

### Articles

- `GET /api/articles` - List articles
- `GET /api/articles/feed` - Feed (followed users)
- `GET /api/articles/:slug` - Get article
- `POST /api/articles` - Create article
- `PUT /api/articles/:slug` - Update article
- `DELETE /api/articles/:slug` - Delete article
- `POST /api/articles/:slug/favorite` - Favorite
- `DELETE /api/articles/:slug/favorite` - Unfavorite

### Comments

- `GET /api/articles/:slug/comments` - List comments
- `POST /api/articles/:slug/comments` - Add comment
- `DELETE /api/articles/:slug/comments/:id` - Delete comment

### Tags

- `GET /api/tags` - List tags

## Development

```bash
# Build lunet from sibling directory
make build

# Initialize database and start server (background)
make run

# Start server in foreground (development)
make dev

# Run with MySQL
make run-mysql

# Run API tests (server must be running)
make test

# Run memory benchmark
make bench

# Quick smoke test
make smoke

# Stop server
make stop
```

## Testing

Run the API integration tests:

```bash
./bin/test_api.sh
```

Or use curl directly:

```bash
# Register a user
curl -X POST http://127.0.0.1:8080/api/users \
  -H "Content-Type: application/json" \
  -d '{"user":{"username":"testuser","email":"test@example.com","password":"password"}}'

# Login
curl -X POST http://127.0.0.1:8080/api/users/login \
  -H "Content-Type: application/json" \
  -d '{"user":{"email":"test@example.com","password":"password"}}'
```

## Benchmarking

Compare resource usage against Node.js and Python implementations:

```bash
# Run size comparison (requires Docker)
./compare.sh

# Run memory benchmark
./test/bench.sh
```

## Releases

Pre-built binaries are available for:

| Platform | Architecture | Download |
|----------|--------------|----------|
| Linux | amd64 | [lunet-realworld-linux-amd64.tar.gz](https://github.com/lua-lunet/lunet-realworld-example-app/releases/download/nightly/lunet-realworld-linux-amd64.tar.gz) |
| Linux | arm64 | [lunet-realworld-linux-arm64.tar.gz](https://github.com/lua-lunet/lunet-realworld-example-app/releases/download/nightly/lunet-realworld-linux-arm64.tar.gz) |
| macOS | arm64 | [lunet-realworld-macos.tar.gz](https://github.com/lua-lunet/lunet-realworld-example-app/releases/download/nightly/lunet-realworld-macos.tar.gz) |
| Windows | amd64 | [lunet-realworld-windows-amd64.zip](https://github.com/lua-lunet/lunet-realworld-example-app/releases/download/nightly/lunet-realworld-windows-amd64.zip) |

## Installation via LuaRocks

```bash
# Default install (with SQLite)
luarocks install lunet-realworld-example-app

# For MySQL/MariaDB support
luarocks install lunet-mysql

# For PostgreSQL support  
luarocks install lunet-postgres
```

Note: You must have Lunet installed first. See the [Lunet installation guide](https://github.com/lua-lunet/lunet#build).

## License

MIT
