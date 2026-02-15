-- Prints the on-disk path of this script as executed by lunet-run.
-- Used by `make test-dist` to verify embedded-script extraction.

local info = debug.getinfo(1, "S")
local src = info and info.source or ""
print(src)
