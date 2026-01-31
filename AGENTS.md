# Agent Notes: RealWorld Conduit Demo

## Operational Rules (STRICT)

1. **NO COMMITS:** Do not commit unless explicitly asked.
2. **NO PUSH:** Do not push unless explicitly asked.
3. **NO DATA LOSS:** Never use `rm -rf`. Move to `.tmp/` instead: `mv xxx .tmp/xxx.$(date +%Y%m%d_%H%M%S)`
4. **TIMEOUTS:** All commands interacting with the server must have a timeout (`curl --max-time 3`).
5. **SECURE BINDING:** Default is `127.0.0.1`. Never bind to `0.0.0.0` unless user explicitly requests it.

## Project Overview

This is a **demo application** showcasing the [Lunet](https://github.com/lua-lunet/lunet) async I/O framework. It implements the [RealWorld "Conduit" API](https://realworld.io) - a Medium.com clone backend.

### Key Components

| Directory | Purpose |
|-----------|---------|
| `app/` | Lua application code |
| `app/handlers/` | HTTP route handlers |
| `app/lib/` | Utility libraries (db, auth, http, json, crypto) |
| `www/` | Static frontend (SPA) |
| `bin/` | Test and utility scripts |

## Testing Protocol

### 1. Start the Server

```bash
make init  # Initialize SQLite database
make run   # Start server in background
```

### 2. Run API Tests

```bash
make test
# Or directly:
./bin/test_api.sh
```

### 3. Manual Testing

```bash
# Health check
curl --max-time 3 http://127.0.0.1:8080/api/tags

# Register user
curl --max-time 3 -X POST http://127.0.0.1:8080/api/users \
  -H "Content-Type: application/json" \
  -d '{"user":{"username":"test","email":"test@test.com","password":"password"}}'
```

### 4. Stop Server

```bash
make stop
```

## Database

Default: SQLite at `.tmp/conduit.sqlite3`

For MySQL/PostgreSQL testing:
```bash
DB_DRIVER=mysql make run
DB_DRIVER=postgres make run
```

## Configuration

Environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `LUNET_LISTEN` | `tcp://127.0.0.1:8080` | Server listen address |
| `DB_DRIVER` | `sqlite` | Database: sqlite, mysql, postgres |
| `DB_PATH` | `.tmp/conduit.sqlite3` | SQLite database path |

## Dependencies

This app requires:
- **lunet** - The async I/O runtime
- **lunet-sqlite3** (default), **lunet-mysql**, or **lunet-postgres** - Database driver
- **libsodium** - For password hashing and JWT signatures

Install database drivers via LuaRocks:
```bash
luarocks install lunet-sqlite3   # Default, installed with this app
luarocks install lunet-mysql     # Optional: MySQL/MariaDB support
luarocks install lunet-postgres  # Optional: PostgreSQL support
```

## Known Issues

1. **LuaJIT Required:** The crypto library uses LuaJIT FFI. Standard Lua 5.x will not work.

## Safe Deletion Pattern

When cleaning up files/directories, use `.tmp/` as a staging area:

```bash
# Good - preserves data
mv somedir .tmp/somedir.$(date +%Y%m%d_%H%M%S)

# Bad - data loss
rm -rf somedir
```

The `.tmp/` directory is in `.gitignore` and can be safely cleaned later with `make clean`.
