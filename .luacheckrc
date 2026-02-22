std = "lua51"
max_line_length = 120
codes = true

ignore = {
    "212/self",
}

globals = {}

read_globals = {
    -- Lua
    "table", "string", "math", "pairs", "ipairs", "type", "tostring",
    "select", "next", "error", "unpack", "abs",

    -- WoW API
    "CreateFrame", "GetTime", "UIParent", "geterrorhandler",

    -- Libraries
    "LibStub",
}
