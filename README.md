# Lunet RealWorld Example App

A full-featured implementation of the [RealWorld "Conduit" API specification](https://realworld.io) using the [Lunet](https://github.com/lua-lunet/lunet) async I/O framework.

This is a canonical example of how to build a production-quality web application with Lunet.

## Features

- Complete RealWorld API implementation
- User authentication with JWT
- Articles, comments, favorites, tags
- User profiles and following
- SQLite by default, MySQL/PostgreSQL optional
- Static file serving with SPA fallback
- Unix socket and TCP support

## Prerequisites

- [Lunet](https://github.com/lua-lunet/lunet) (built with database support)
- [libsodium](https://libsodium.org) for cryptography (`brew install libsodium` on macOS)
- SQLite3 (or MySQL/PostgreSQL if preferred)

## Quick Start

```bash
# 1. Clone this repository
git clone https://github.com/lua-lunet/lunet-realworld-example-app.git
cd lunet-realworld-example-app

# 2. Initialize SQLite database
sqlite3 .tmp/conduit.sqlite3 < app/schema_sqlite.sql

# 3. Start the server
lunet app/main.lua

# 4. Open http://127.0.0.1:8080 in your browser
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
mkdir -p .tmp
sqlite3 .tmp/conduit.sqlite3 < app/schema_sqlite.sql
```

### MySQL/MariaDB

```bash
mysql -u root -p conduit < app/schema.sql
DB_DRIVER=mysql DB_HOST=127.0.0.1 lunet app/main.lua
```

### PostgreSQL

```bash
psql -U postgres -d conduit -f app/schema.sql
DB_DRIVER=postgres DB_HOST=127.0.0.1 lunet app/main.lua
```

## Project Structure

```
lunet-realworld-example-app/
├── app/
│   ├── main.lua           # Entry point, routing, server
│   ├── config.lua         # Configuration
│   ├── db_config.lua      # Database configuration
│   ├── schema.sql         # MySQL/PostgreSQL schema
│   ├── schema_sqlite.sql  # SQLite schema
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
├── Makefile               # Development commands
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
# Run with default settings
make run

# Run with MySQL
make run-mysql

# Run API tests
make test

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
