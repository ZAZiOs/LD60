local LevelParser = {}

local function trim(s)
    if not s then return "" end
    return s:match("^%s*(.-)%s*$") or ""
end

local function parse_number_or_string(s)
    s = trim(s)
    if s == "true" or s == "yes" or s == "on" then
        return true
    elseif s == "false" or s == "no" or s == "off" then
        return false
    end
    local n = tonumber(s)
    if n ~= nil then
        return n
    end
    local q = s:match('^"(.*)"$') or s:match("^'(.*)'$")
    if q then
        q = q:gsub("\\n", "\n"):gsub("\\t", "\t")
        return q
    end
    return s:gsub("\\n", "\n")
end

local function parse_coords(val_str)
    local parts = {}
    for part in val_str:gmatch("([^,]+)") do
        local n = tonumber(trim(part))
        if n ~= nil then
            table.insert(parts, n)
        else
            table.insert(parts, trim(part))
        end
    end
    return parts
end

local function parse_boxes(val_str)
    local boxes = {}
    for box_str in val_str:gmatch("([^;]+)") do
        local parts = parse_coords(box_str)
        if #parts >= 4 then
            local is_ow = false
            if parts[5] ~= nil then
                local p5 = tostring(parts[5]):lower()
                is_ow = (p5 == "oneway" or p5 == "one_way" or p5 == "1" or p5 == "true")
            end
            table.insert(boxes, {
                x = tonumber(parts[1]) or 0,
                y = tonumber(parts[2]) or 0,
                w = tonumber(parts[3]) or 0,
                h = tonumber(parts[4]) or 0,
                one_way = is_ow,
                is_one_way = is_ow,
                top_only = is_ow
            })
        end
    end
    return boxes
end

local function parse_music(val_str)
    local parts = parse_coords(val_str)
    return {
        track = tostring(parts[1] or ""),
        volume = tonumber(parts[2]) or 0.8,
        fade = tonumber(parts[3]) or 0.5,
        layer = parts[4] and tostring(parts[4]) or nil
    }
end

local function deep_copy(orig)
    if type(orig) ~= "table" then return orig end
    local copy = {}
    for k, v in pairs(orig) do
        copy[k] = deep_copy(v)
    end
    return copy
end

function LevelParser.parse(input)
    if not input or input == "" then
        return {}
    end

    local text = input
    if not input:find("\n") then
        if love and love.filesystem and love.filesystem.getInfo(input) then
            local content = love.filesystem.read(input)
            if content then text = content end
        else
            local f = io.open(input, "r")
            if f then
                text = f:read("*all")
                f:close()
            end
        end
    end

    local result = {
        meta = {},
        parent = {
            bg = nil,
            fullscreen = false,
            screen = nil,
            shaders = { "crt" },
            music = nil
        },
        room = {
            id = "level",
            w = 320,
            h = 240,
            camera_w = nil,
            camera_h = nil,
            bg = nil,
            cursor = nil,
            spawn = nil,
            script = nil
        },
        templates = {},
        elements = {}
    }

    local current_scope = "meta"
    local current_type = nil
    local current_id = nil
    local current_target = result.meta

    local multiline_key = nil
    local multiline_buf = {}

    for line in (text .. "\n"):gmatch("(.-)\r?\n") do
        local l = trim(line)

        if multiline_key then
            if l:find('"""$') or l == '"""' then
                local end_idx = l:find('"""')
                local before = l:sub(1, end_idx - 1)
                if before ~= "" then
                    table.insert(multiline_buf, before)
                end
                current_target[multiline_key] = table.concat(multiline_buf, "\n")
                multiline_key = nil
                multiline_buf = {}
            else
                table.insert(multiline_buf, line)
            end
        elseif l ~= "" and not l:match("^[;#]") then
            local section_header = l:match("^%[([^%]]+)%]$")
            if section_header then
                section_header = trim(section_header)
                local sub_type, sub_id = section_header:match("^([%w_]+)%s*:%s*([%w_%-%.]+)$")

                if sub_type and sub_id then
                    sub_type = trim(sub_type)
                    sub_id = trim(sub_id)

                    if sub_type == "template" then
                        current_scope = "template"
                        current_type = sub_type
                        current_id = sub_id
                        result.templates[sub_id] = result.templates[sub_id] or { id = sub_id }
                        current_target = result.templates[sub_id]
                    else
                        current_scope = "element"
                        current_type = sub_type
                        current_id = sub_id
                        local el = {
                            id = sub_id,
                            type = sub_type
                        }
                        table.insert(result.elements, el)
                        current_target = el
                    end
                else
                    local s_name = section_header:lower()
                    if s_name == "parent" then
                        current_scope = "parent"
                        current_target = result.parent
                    elseif s_name == "room" or s_name == "level" or s_name == "desktop" then
                        current_scope = "room"
                        current_target = result.room
                    elseif s_name == "meta" then
                        current_scope = "meta"
                        current_target = result.meta
                    else
                        current_scope = "custom"
                        result[s_name] = result[s_name] or {}
                        current_target = result[s_name]
                    end
                    current_type = nil
                    current_id = nil
                end
            else
                local key, val = l:match("^([^=]+)=(.*)$")
                if key and val then
                    key = trim(key)
                    val = trim(val)
                    if val:match('^"""') then
                        val = val:sub(4)
                        if val:match('"""$') then
                            current_target[key] = val:sub(1, #val - 3)
                        else
                            multiline_key = key
                            multiline_buf = { val }
                        end
                    else
                        if key == "pos" then
                            local c = parse_coords(val)
                            current_target.x = c[1] or 0
                            current_target.y = c[2] or 0
                        elseif key == "size" or key == "room_size" then
                            local c = parse_coords(val)
                            current_target.w = c[1] or 0
                            current_target.h = c[2] or 0
                        elseif key == "camera_size" or key == "view_size" then
                            local c = parse_coords(val)
                            current_target.camera_w = c[1] or 0
                            current_target.camera_h = c[2] or 0
                        elseif key == "fullscreen" then
                            current_target.fullscreen = (val == "true" or val == "yes" or val == "1" or val == true)
                        elseif key == "rect" or key == "screen" then
                            local c = parse_coords(val)
                            current_target.x = c[1] or 0
                            current_target.y = c[2] or 0
                            current_target.w = c[3] or 0
                            current_target.h = c[4] or 0
                        elseif key == "boxes" or key == "collisions" then
                            current_target.collisions = parse_boxes(val)
                        elseif key == "delta" then
                            local c = parse_coords(val)
                            current_target.max_delta_x = c[1] or 0
                            current_target.max_delta_y = c[2] or 0
                        elseif key == "music" then
                            current_target.music = parse_music(val)
                        elseif key == "shaders" or key == "shader" then
                            local list = {}
                            for s in val:gmatch("([^,]+)") do
                                table.insert(list, trim(s))
                            end
                            current_target.shaders = list
                        elseif key == "spawn" then
                            local parts = parse_coords(val)
                            current_target.spawn = {
                                x = tonumber(parts[1]) or 0,
                                y = tonumber(parts[2]) or 0,
                                sheet = parts[3] and tostring(parts[3]) or "assets/rage/rage_sh.ini"
                            }
                        elseif key == "color" or key == "title_color" then
                            local parts = parse_coords(val)
                            local col = {}
                            for _, p in ipairs(parts) do
                                table.insert(col, tonumber(p) or 1)
                            end
                            current_target[key] = col
                        else
                            current_target[key] = parse_number_or_string(val)
                        end
                    end
                end
            end
        end
    end

    for _, el in ipairs(result.elements) do
        local tpl_name = el.template or el.type
        local tpl = result.templates[tpl_name]
        if tpl then
            el.template = el.template or tpl_name
            for tk, tv in pairs(tpl) do
                if tk ~= "id" and tk ~= "type" and el[tk] == nil then
                    el[tk] = deep_copy(tv)
                end
            end
            if tpl.type then
                el.type = tpl.type
            end
        end
    end

    return result
end

return LevelParser
