local LevelSerializer = {}

local function format_coords(nums)
    local parts = {}
    for _, n in ipairs(nums) do
        table.insert(parts, tostring(n))
    end
    return table.concat(parts, ", ")
end

local function format_boxes(boxes)
    if not boxes or #boxes == 0 then return nil end
    local parts = {}
    for _, b in ipairs(boxes) do
        if type(b) == "table" then
            local x = b.x or b[1] or 0
            local y = b.y or b[2] or 0
            local w = b.w or b[3] or 0
            local h = b.h or b[4] or 0
            local is_ow = (b.one_way == true or b.is_one_way == true or b.top_only == true or b[5] == "oneway" or b[5] == 1)
            if is_ow then
                table.insert(parts, string.format("%d,%d,%d,%d,oneway", x, y, w, h))
            else
                table.insert(parts, string.format("%d,%d,%d,%d", x, y, w, h))
            end
        end
    end
    return table.concat(parts, "; ")
end

function LevelSerializer.serialize(data)
    local lines = {}
    local function out(s) table.insert(lines, s or "") end

    -- 1. [parent]
    local p = data.parent or {}
    out("[parent]")
    if p.fullscreen then
        out("fullscreen = true")
    end
    if p.bg and p.bg ~= "" then
        out("bg = " .. p.bg)
    end
    if p.screen and not p.fullscreen then
        out(string.format("screen = %d, %d, %d, %d", p.screen.x or 320, p.screen.y or 60, p.screen.w or 1280, p.screen.h or 960))
    end
    if p.shaders and #p.shaders > 0 then
        out("shaders = " .. table.concat(p.shaders, ", "))
    end
    if p.music and p.music.track and p.music.track ~= "" then
        local m = p.music
        out(string.format("music = %s, %.2f, %.2f%s", m.track, m.volume or 0.8, m.fade or 0.5, m.layer and (", " .. m.layer) or ""))
    end
    out()

    -- 2. [room]
    local r = data.room or {}
    out("[room]")
    out("id = " .. (r.id or "level"))
    if r.w and r.h then
        out(string.format("room_size = %d, %d", r.w, r.h))
    end
    if r.camera_w and r.camera_h then
        out(string.format("camera_size = %d, %d", r.camera_w, r.camera_h))
    end
    if r.bg and r.bg ~= "" then
        out("bg = " .. r.bg)
    end
    if r.bg_repeat and r.bg_repeat ~= "" and r.bg_repeat ~= false then
        out("bg_repeat = " .. tostring(r.bg_repeat))
    end
    if r.cursor and r.cursor ~= "" then
        out("cursor = " .. r.cursor)
    end
    if r.spawn then
        out(string.format("spawn = %d, %d, %s", r.spawn.x or 0, r.spawn.y or 0, r.spawn.sheet or "assets/rage/rage_sh.ini"))
    end
    if r.script and r.script ~= "" then
        out("script = " .. r.script)
    end
    out()

    -- 3. [template:*]
    local tpls = data.templates or {}
    local tpl_keys = {}
    for k, _ in pairs(tpls) do table.insert(tpl_keys, k) end
    table.sort(tpl_keys)

    if #tpl_keys > 0 then
        out("; --- TEMPLATES (PREFABS) ---")
        for _, name in ipairs(tpl_keys) do
            local tpl = tpls[name]
            out(string.format("[template:%s]", name))
            if tpl.type then out("type = " .. tpl.type) end
            if tpl.image then out("image = " .. tpl.image) end
            if tpl.w and tpl.h and not tpl.image then out(string.format("size = %d, %d", tpl.w, tpl.h)) end
            if tpl.visible ~= nil then out("visible = " .. tostring(tpl.visible)) end
            if tpl.is_solid ~= nil then out("is_solid = " .. tostring(tpl.is_solid)) end
            if tpl.one_way ~= nil then out("one_way = " .. tostring(tpl.one_way)) end
            if tpl.collisions and #tpl.collisions > 0 then
                local b_str = format_boxes(tpl.collisions)
                if b_str then out("boxes = " .. b_str) end
            end
            if tpl.script then out("script = " .. tpl.script) end
            out()
        end
    end

    -- 4. Elements
    out("; --- ELEMENTS ---")
    local standard_keys = {
        id = true, type = true, template = true, x = true, y = true, w = true, h = true,
        image = true, collisions = true, on_interact = true, script = true, z_index = true,
        max_delta_x = true, max_delta_y = true, speed = true, visible = true, is_solid = true,
        one_way = true, is_one_way = true, custom_size = true,
        title = true, text = true, idle = true, active = true, target = true, fade = true,
        sheet = true, frame = true
    }

    for _, el in ipairs(data.elements or {}) do
        local section_type = el.template or el.type or "element"
        out(string.format("[%s:%s]", section_type, el.id))

        if el.template and el.template ~= section_type then
            out("template = " .. el.template)
        end
        if el.x ~= nil and el.y ~= nil then
            out(string.format("pos = %d, %d", el.x, el.y))
        end
        local has_img = (el.image and el.image ~= "") or (el.idle and el.idle ~= "") or (el.sheet and el.sheet ~= "")
        if (el.custom_size or not has_img) and el.w ~= nil and el.h ~= nil and el.w > 0 and el.h > 0 then
            out(string.format("size = %d, %d", el.w, el.h))
        end
        local img_path = (el.image and el.image ~= "" and el.image) or (el.texture and el.texture ~= "" and el.texture)
        if img_path then
            out("image = " .. img_path)
        end
        if el.sheet and el.sheet ~= "" then
            out("sheet = " .. el.sheet)
        end
        if el.frame and el.frame ~= "" then
            out("frame = " .. el.frame)
        end
        if el.idle and el.idle ~= "" then
            out("idle = " .. el.idle)
        end
        if el.active and el.active ~= "" then
            out("active = " .. el.active)
        end
        if el.title and el.title ~= "" then
            out("title = " .. el.title)
        end
        if el.text and el.text ~= "" then
            if el.text:find("\n") then
                out('text = """\n' .. el.text .. '\n"""')
            else
                out('text = "' .. el.text .. '"')
            end
        end
        if el.collisions and #el.collisions > 0 then
            local b_str = format_boxes(el.collisions)
            if b_str then out("boxes = " .. b_str) end
        end
        if el.z_index and el.z_index ~= 0 then
            out("z_index = " .. tostring(el.z_index))
        end
        if el.target and el.target ~= "" then
            out("target = " .. el.target)
        end
        if el.fade then
            out("fade = " .. tostring(el.fade))
        end
        if el.on_interact and el.on_interact ~= "" then
            out("on_interact = " .. el.on_interact)
        end
        if el.script and el.script ~= "" then
            out("script = " .. el.script)
        end
        if el.speed and (el.max_delta_x or el.max_delta_y) then
            out(string.format("delta = %d, %d", el.max_delta_x or 0, el.max_delta_y or 0))
            out("speed = " .. tostring(el.speed))
        end
        if el.visible == false then
            out("visible = false")
        end
        if el.is_solid == false then
            out("is_solid = false")
        end

        -- Extra custom fields
        for k, v in pairs(el) do
            if not standard_keys[k] and type(v) ~= "function" and type(v) ~= "table" then
                out(string.format("%s = %s", tostring(k), tostring(v)))
            end
        end
        out()
    end

    return table.concat(lines, "\n")
end

function LevelSerializer.saveToFile(file_path, data)
    local text = LevelSerializer.serialize(data)
    if love and love.filesystem then
        local ok, err = love.filesystem.write(file_path, text)
        if not ok then
            -- Fallback to standard io
            local f = io.open(file_path, "w")
            if f then
                f:write(text)
                f:close()
                return true
            else
                return false, err
            end
        end
        return true
    else
        local f = io.open(file_path, "w")
        if f then
            f:write(text)
            f:close()
            return true
        end
        return false, "Failed to open file"
    end
end

return LevelSerializer
