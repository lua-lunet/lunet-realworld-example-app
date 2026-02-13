-- Vendor Library Installer
-- Downloads JavaScript libraries, computes SHA256 hashes, and renames files with hash prefix
--
-- Usage: luajit scripts/install-vendor.lua --preact 10.19.3 --htm 3.1.1 --dest assets/vendor/dist --manifest assets/vendor/manifest.txt

-- Pure-Lua SHA256 using LuaJIT's bit library (works on all platforms)
local bit = require("bit")
local band, bor, bxor = bit.band, bit.bor, bit.bxor
local rshift, lshift, rotr = bit.rshift, bit.lshift, bit.ror

local function bnot(x)
    return bit.bnot(x)
end

local function add(...)
    local sum = 0
    for i = 1, select("#", ...) do
        sum = sum + select(i, ...)
    end
    return bit.tobit(sum)
end

local K = {
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
}

local function sha256_bytes(msg)
    local H0, H1, H2, H3 = 0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a
    local H4, H5, H6, H7 = 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19

    local len = #msg
    msg = msg .. string.char(0x80)
    local pad = (56 - ((len + 1) % 64)) % 64
    msg = msg .. string.rep("\0", pad)

    local bit_len = len * 8
    local hi = math.floor(bit_len / 2^32)
    local lo = bit_len % 2^32
    msg = msg .. string.char(
        band(rshift(hi, 24), 0xFF), band(rshift(hi, 16), 0xFF), band(rshift(hi, 8), 0xFF), band(hi, 0xFF),
        band(rshift(lo, 24), 0xFF), band(rshift(lo, 16), 0xFF), band(rshift(lo, 8), 0xFF), band(lo, 0xFF)
    )

    local w = {}
    for chunk = 1, #msg, 64 do
        for i = 0, 15 do
            local a, b, c, d = msg:byte(chunk + i * 4, chunk + i * 4 + 3)
            w[i] = bor(lshift(a, 24), bor(lshift(b, 16), bor(lshift(c, 8), d)))
        end
        for i = 16, 63 do
            local s0 = bxor(bxor(rotr(w[i - 15], 7), rotr(w[i - 15], 18)), rshift(w[i - 15], 3))
            local s1 = bxor(bxor(rotr(w[i - 2], 17), rotr(w[i - 2], 19)), rshift(w[i - 2], 10))
            w[i] = add(w[i - 16], s0, w[i - 7], s1)
        end

        local a, b, c, d = H0, H1, H2, H3
        local e, f, g, h = H4, H5, H6, H7

        for i = 0, 63 do
            local S1 = bxor(bxor(rotr(e, 6), rotr(e, 11)), rotr(e, 25))
            local ch = bxor(band(e, f), band(bnot(e), g))
            local temp1 = add(h, S1, ch, K[i + 1], w[i])
            local S0 = bxor(bxor(rotr(a, 2), rotr(a, 13)), rotr(a, 22))
            local maj = bxor(bxor(band(a, b), band(a, c)), band(b, c))
            local temp2 = add(S0, maj)

            h = g
            g = f
            f = e
            e = add(d, temp1)
            d = c
            c = b
            b = a
            a = add(temp1, temp2)
        end

        H0 = add(H0, a)
        H1 = add(H1, b)
        H2 = add(H2, c)
        H3 = add(H3, d)
        H4 = add(H4, e)
        H5 = add(H5, f)
        H6 = add(H6, g)
        H7 = add(H7, h)
    end

    local function to_hex(x)
        return bit.tohex(x, 8)
    end

    return (to_hex(H0) .. to_hex(H1) .. to_hex(H2) .. to_hex(H3) .. to_hex(H4) .. to_hex(H5) .. to_hex(H6) .. to_hex(H7))
end

local function sha256_file(filepath)
    local f = io.open(filepath, "rb")
    if not f then
        return nil, "Cannot open file: " .. filepath
    end
    local content = f:read("*a")
    f:close()
    local hex = sha256_bytes(content)
    return hex:sub(1, 8)
end

local function is_windows()
    return package.config:sub(1, 1) == "\\"
end

local function ensure_dir(path)
    if is_windows() then
        os.execute(string.format('mkdir "%s" >NUL 2>NUL', path))
    else
        os.execute(string.format("mkdir -p '%s'", path))
    end
end

local function download_file(url, dest_path, timeout_seconds)
    local quote = is_windows() and '"' or "'"
    local cmd = string.format("curl -fsSL --max-time %d -o %s%s%s %s%s%s", timeout_seconds or 30, quote, dest_path, quote, quote, url, quote)
    local handle = io.popen(cmd .. " 2>&1")
    local output = handle:read("*a")
    local success = handle:close()

    if not success then
        return nil, "Failed to download: " .. output
    end

    local f = io.open(dest_path, "rb")
    if not f then
        return nil, "Failed to open downloaded file"
    end
    local content = f:read("*a")
    f:close()

    if #content < 100 then
        return nil, "Downloaded file too small (error response?)"
    end

    return true
end

local function install_vendor(args)
    local dest_dir = args.dest or "assets/vendor/dist"
    local manifest_file = args.manifest or "assets/vendor/manifest.txt"
    local preact_version = args.preact or "10.19.3"
    local htm_version = args.htm or "3.1.1"
    local tmp_dir = args.tmp or ".tmp/vendor-downloads"

    -- Ensure destination directory exists
    ensure_dir(dest_dir)
    ensure_dir(tmp_dir)

    -- Define libraries to download
    local libraries = {
        {
            name = "preact",
            file_key = "PREACT_FILE",
            url = string.format("https://unpkg.com/preact@%s/dist/preact.min.js", preact_version),
            dest_base = "preact",
            ext = ".min.js"
        },
        {
            name = "preact-hooks",
            file_key = "HOOKS_FILE",
            url = string.format("https://unpkg.com/preact@%s/hooks/dist/hooks.umd.js", preact_version),
            dest_base = "preact-hooks",
            ext = ".umd.js"
        },
        {
            name = "htm",
            file_key = "HTM_FILE",
            url = string.format("https://unpkg.com/htm@%s/dist/htm.umd.js", htm_version),
            dest_base = "htm",
            ext = ".umd.js"
        }
    }

    local manifest_lines = {"# Vendor library manifest"}
    manifest_lines[#manifest_lines + 1] = "# Auto-generated by scripts/install-vendor.lua"
    manifest_lines[#manifest_lines + 1] = "# Do not edit manually"
    manifest_lines[#manifest_lines + 1] = ""

    print("Installing vendor libraries...")

    for _, lib in ipairs(libraries) do
        print(string.format("Downloading %s from %s", lib.name, lib.url))

        -- Download to temporary file first
        local sep = is_windows() and "\\" or "/"
        local temp_file = tmp_dir .. sep .. lib.dest_base .. ".tmp"
        local ok, err = download_file(lib.url, temp_file, 60)

        if not ok then
            print(string.format("ERROR: Failed to download %s: %s", lib.name, err))
            os.exit(1)
        end

        -- Compute SHA256 hash
        local hash = sha256_file(temp_file)
        if not hash then
            print(string.format("ERROR: Failed to compute SHA256 for %s", lib.name))
            os.exit(1)
        end

        -- Move to final location with hash in filename
        local final_name = string.format("%s-%s%s", lib.dest_base, hash, lib.ext)
        local final_path = dest_dir .. (is_windows() and "\\" or "/") .. final_name

        os.rename(temp_file, final_path)

        -- Add to manifest
        manifest_lines[#manifest_lines + 1] = string.format("%s=%s", lib.file_key, final_name)

        print(string.format("  Installed %s (hash: %s)", lib.name, hash))
    end

    -- Write manifest file
    local manifest = io.open(manifest_file, "w")
    if not manifest then
        print(string.format("ERROR: Failed to write manifest file %s", manifest_file))
        os.exit(1)
    end

    manifest:write(table.concat(manifest_lines, "\n"))
    manifest:close()

    print(string.format("Vendor libraries installed to %s", dest_dir))
    print(string.format("Manifest written to %s", manifest_file))

    return true
end

-- Parse command line arguments
local args = {}
for i = 1, #arg do
    if arg[i]:sub(1, 2) == "--" then
        local key, value = arg[i]:sub(3):match("^([^=]+)=(.*)$")
        if not key or not value then
            key = arg[i]:sub(3)
            value = arg[i + 1] or ""
            if value:sub(1, 2) == "--" then
                value = ""
            end
        end
        args[key] = value
    end
end

-- Run installation
local success, err = pcall(install_vendor, args)
if not success then
    print("ERROR: " .. (err or "Unknown error"))
    os.exit(1)
end
