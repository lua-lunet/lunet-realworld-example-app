-- Database abstraction for RealWorld API
-- Dynamically loads the appropriate driver based on config
local config = require("app.db_config")

local driver_modules = {
    sqlite = "lunet.sqlite3",
    sqlite3 = "lunet.sqlite3",
    mysql = "lunet.mysql",
    postgres = "lunet.postgres",
}

local driver_name = driver_modules[config.driver] or "lunet.sqlite3"
local native = require(driver_name)

local db = {}

-- Expose native functions
db.open = native.open
db.close = native.close
db.query_raw = native.query
db.exec_raw = native.exec
db.query_params = native.query_params
db.exec_params = native.exec_params

function db.set_config(cfg)
    if not cfg then return end
    for k, v in pairs(cfg) do
        config[k] = v
    end
end

-- Connection management
function db.connect()
    return native.open(config)
end

-- Escape function
function db.escape(value)
    if value == nil then
        return "NULL"
    elseif type(value) == "number" then
        return tostring(value)
    elseif type(value) == "boolean" then
        return value and "1" or "0"
    else
        return "'" .. native.escape(tostring(value)) .. "'"
    end
end

-- Interpolate: replace ? with escaped values
function db.interpolate(sql, ...)
    local args = {...}
    local idx = 0
    return sql:gsub("%?", function()
        idx = idx + 1
        return db.escape(args[idx])
    end)
end

-- Higher level query (handles connection and parameters)
function db.query(sql, ...)
    local conn, err = db.connect()
    if not conn then
        return nil, err
    end

    local result, query_err
    if select("#", ...) > 0 then
        result, query_err = db.query_params(conn, sql, ...)
    else
        result, query_err = db.query_raw(conn, sql)
    end
    
    db.close(conn)
    
    if not result then
        return nil, query_err or "query failed"
    end

    return result
end

function db.exec(sql, ...)
    local conn, err = db.connect()
    if not conn then
        return nil, err
    end

    local result, exec_err
    if select("#", ...) > 0 then
        result, exec_err = db.exec_params(conn, sql, ...)
    else
        result, exec_err = db.exec_raw(conn, sql)
    end
    
    db.close(conn)
    
    if not result then
        return nil, exec_err or "exec failed"
    end

    return result
end

function db.query_one(sql, ...)
    local result, err = db.query(sql, ...)
    if not result then return nil, err end
    if #result == 0 then return nil end
    return result[1]
end

-- Table helpers
function db.insert(table_name, data)
    local columns = {}
    local values = {}
    for col, val in pairs(data) do
        columns[#columns + 1] = col
        values[#values + 1] = db.escape(val)
    end
    local sql = string.format(
        "INSERT INTO %s (%s) VALUES (%s)",
        table_name,
        table.concat(columns, ", "),
        table.concat(values, ", ")
    )
    return db.exec(sql)
end

function db.update(table_name, data, where, ...)
    local sets = {}
    for col, val in pairs(data) do
        sets[#sets + 1] = col .. " = " .. db.escape(val)
    end
    local sql = string.format(
        "UPDATE %s SET %s WHERE %s",
        table_name,
        table.concat(sets, ", "),
        db.interpolate(where, ...)
    )
    return db.exec(sql)
end

function db.delete(table_name, where, ...)
    local sql = string.format(
        "DELETE FROM %s WHERE %s",
        table_name,
        db.interpolate(where, ...)
    )
    return db.exec(sql)
end

function db.init()
    if config.driver == "sqlite" or config.driver == "sqlite3" then
        -- Ensure .tmp directory exists
        os.execute("mkdir -p .tmp")
        
        local conn, err = db.connect()
        if not conn then return nil, err end
        
        -- Read schema from app directory
        local schema_paths = {
            "app/schema_sqlite.sql",
            "app/schema.sql"
        }
        
        local f
        for _, path in ipairs(schema_paths) do
            f = io.open(path, "rb")
            if f then break end
        end
        
        if f then
            local schema = f:read("*a")
            f:close()
            db.exec_raw(conn, schema)
        end
        db.close(conn)
    end
    return true
end

return db
