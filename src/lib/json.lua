local json = {}

local function escape_str(s)
    local in_char  = {'\\', '"', '/', '\b', '\f', '\n', '\r', '\t'}
    local out_char = {'\\', '"', '/',  'b',  'f',  'n',  'r',  't'}
    for i, c in ipairs(in_char) do
        s = s:gsub(c, '\\' .. out_char[i])
    end
    return s
end

local function skip_delim(str, pos, delim, err_if_missing)
    pos = pos + #str:match('^%s*', pos)
    if str:sub(pos, pos) ~= delim then
        if err_if_missing then
            error('Expected ' .. delim .. ' near position ' .. pos)
        end
        return pos, false
    end
    return pos + 1, true
end

local function parse_str_val(str, pos)
    pos = pos + #str:match('^%s*', pos)
    if str:sub(pos, pos) ~= '"' then
        error('Expected " near position ' .. pos)
    end
    pos = pos + 1
    local val = ''
    while pos <= #str do
        local c = str:sub(pos, pos)
        if c == '"' then
            return val, pos + 1
        elseif c == '\\' then
            pos = pos + 1
            local next_c = str:sub(pos, pos)
            if next_c == '"' or next_c == '\\' or next_c == '/' then
                val = val .. next_c
            elseif next_c == 'b' then val = val .. '\b'
            elseif next_c == 'f' then val = val .. '\f'
            elseif next_c == 'n' then val = val .. '\n'
            elseif next_c == 'r' then val = val .. '\r'
            elseif next_c == 't' then val = val .. '\t'
            elseif next_c == 'u' then
                local hex = str:sub(pos + 1, pos + 4)
                if #hex == 4 and hex:match('^%x+$') then
                    local code = tonumber(hex, 16)

                    if code < 0x80 then
                        val = val .. string.char(code)
                    elseif code < 0x800 then
                        val = val .. string.char(0xC0 + math.floor(code / 0x40), 0x80 + (code % 0x40))
                    elseif code < 0x10000 then
                        val = val .. string.char(0xE0 + math.floor(code / 0x1000), 0x80 + (math.floor(code / 0x40) % 0x40), 0x80 + (code % 0x40))
                    end
                    pos = pos + 4
                else
                    error('Invalid unicode escape near position ' .. pos)
                end
            else
                val = val .. '\\' .. next_c
            end
        else
            val = val .. c
        end
        pos = pos + 1
    end
    error('Unterminated string near position ' .. pos)
end

local function parse_num_val(str, pos)
    pos = pos + #str:match('^%s*', pos)
    local num_str = str:match('^-?%d+%.?%d*[eE]?[+-]?%d*', pos)
    if not num_str or num_str == '' then
        error('Expected number near position ' .. pos)
    end
    return tonumber(num_str), pos + #num_str
end

local parse_val

local function parse_arr_val(str, pos)
    local arr = {}
    pos = pos + 1
    pos = pos + #str:match('^%s*', pos)
    if str:sub(pos, pos) == ']' then
        return arr, pos + 1
    end
    while true do
        local val
        val, pos = parse_val(str, pos)
        table.insert(arr, val)
        local delim_found
        pos, delim_found = skip_delim(str, pos, ',')
        if not delim_found then
            break
        end
    end
    pos = skip_delim(str, pos, ']', true)
    return arr, pos
end

local function parse_obj_val(str, pos)
    local obj = {}
    pos = pos + 1
    pos = pos + #str:match('^%s*', pos)
    if str:sub(pos, pos) == '}' then
        return obj, pos + 1
    end
    while true do
        local key, val
        key, pos = parse_str_val(str, pos)
        pos = skip_delim(str, pos, ':', true)
        val, pos = parse_val(str, pos)
        obj[key] = val
        local delim_found
        pos, delim_found = skip_delim(str, pos, ',')
        if not delim_found then
            break
        end
    end
    pos = skip_delim(str, pos, '}', true)
    return obj, pos
end

parse_val = function(str, pos)
    pos = pos + #str:match('^%s*', pos)
    local c = str:sub(pos, pos)
    if c == '"' then
        return parse_str_val(str, pos)
    elseif c == '{' then
        return parse_obj_val(str, pos)
    elseif c == '[' then
        return parse_arr_val(str, pos)
    elseif str:sub(pos, pos + 3) == 'true' then
        return true, pos + 4
    elseif str:sub(pos, pos + 4) == 'false' then
        return false, pos + 5
    elseif str:sub(pos, pos + 3) == 'null' then
        return nil, pos + 4
    else
        return parse_num_val(str, pos)
    end
end

function json.decode(str)
    if type(str) ~= 'string' then
        return nil, 'Expected string argument'
    end
    local ok, val = pcall(parse_val, str, 1)
    if ok then
        return val
    else
        return nil, val
    end
end

local function encode_val(val)
    local t = type(val)
    if t == 'nil' then
        return 'null'
    elseif t == 'boolean' then
        return tostring(val)
    elseif t == 'number' then
        return tostring(val)
    elseif t == 'string' then
        return '"' .. escape_str(val) .. '"'
    elseif t == 'table' then
        local is_array = true
        local n = 0
        for k, _ in pairs(val) do
            if type(k) ~= 'number' or k <= 0 or math.floor(k) ~= k then
                is_array = false
                break
            end
            n = math.max(n, k)
        end
        if n == 0 and next(val) == nil then
            return '{}'
        end
        if is_array then
            local parts = {}
            for i = 1, n do
                table.insert(parts, encode_val(val[i]))
            end
            return '[' .. table.concat(parts, ',') .. ']'
        else
            local parts = {}
            for k, v in pairs(val) do
                table.insert(parts, '"' .. escape_str(tostring(k)) .. '":' .. encode_val(v))
            end
            return '{' .. table.concat(parts, ',') .. '}'
        end
    else
        error('Cannot serialize type ' .. t)
    end
end

function json.encode(val)
    return encode_val(val)
end

return json
