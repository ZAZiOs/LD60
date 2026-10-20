local SceneManager = require("src.core.scene_manager")
local Viewport = require("src.core.viewport")
local LevelParser = require("src.core.level_parser")
local LevelLoader = require("src.core.level_loader")
local LevelSerializer = require("src.core.level_serializer")
local EditorUI = require("src.core.editor_window")

local EditorScene = {}
EditorScene.__index = EditorScene

local WindowManager = EditorUI.Manager
local EditorWindow = EditorUI.Window

local image_cache = {}
local function getImage(path)
    if not path or path == "" then return nil end
    if image_cache[path] ~= nil then return image_cache[path] end
    if love and love.filesystem and love.filesystem.getInfo(path) then
        local ok, img = pcall(love.graphics.newImage, path)
        if ok and img then
            img:setFilter("nearest", "nearest")
            image_cache[path] = img
            return img
        end
    end
    image_cache[path] = false
    return nil
end

local function listDirectoryItems(dir)
    local items = {}
    if love and love.filesystem and love.filesystem.getInfo(dir) then
        local names = love.filesystem.getDirectoryItems(dir)
        table.sort(names)
        for _, name in ipairs(names) do
            local path = (dir == "" or dir == ".") and name or (dir .. "/" .. name)
            local info = love.filesystem.getInfo(path)
            if info then
                if info.type == "directory" then
                    table.insert(items, { name = name, path = path, is_dir = true })
                elseif info.type == "file" and name:match("%.ini$") then
                    table.insert(items, { name = name, path = path, is_dir = false })
                end
            end
        end
    end
    return items
end

function EditorScene.new()
    local self = setmetatable({}, EditorScene)

    -- Mode: "browser" (level column hub) or "workspace" (canvas & floating windows)
    self.view_mode = "browser"

    self.level_path = "levels/ld60/test_level.ini"
    self.level_data = nil
    self.selected_index = nil
    self.selected_element = nil

    -- Browser Miller Columns State
    self.columns_data = {}      -- list of { dir = "...", items = {...}, selected_idx = nil }
    self.selected_file_item = nil
    self.selected_file_preview = nil
    self.browser_scrolls = { 0, 0, 0 }

    -- Modal: Create Level Dialog
    self.show_new_level_dialog = false
    self.new_level_name = "new_level"
    self.new_level_folder = "levels/ld60"
    self.new_level_fullscreen = true

    -- Workspace Canvas & Pan/Zoom
    self.canvas_cx = 960
    self.canvas_cy = 540
    self.zoom = 3.0
    self.min_zoom = 1.0
    self.max_zoom = 6.0

    self.grid_size = 8
    self.grid_snap = true

    self.panning = false
    self.pan_start_x = 0
    self.pan_start_y = 0
    self.pan_orig_cx = 0
    self.pan_orig_cy = 0

    self.dragging_element = false
    self.drag_ox = 0
    self.drag_oy = 0

    self.edit_mode = "object"          -- "object" or "collision"
    self.selected_collision_idx = 1
    self.dragging_collision = false
    self.show_collisions = true
    self.show_windows = true

    self.status_text = "Level Editor Ready"
    self.status_timer = 3.0

    self.font_header = nil
    self.font_body = nil
    self.font_title = nil
    self.font_small = nil

    self:_initWindows()
    self:initBrowser()

    return self
end

function EditorScene:_initFonts()
    if not self.font_header and love and love.graphics and love.graphics.newFont then
        local font_path = "assets/fnt/tahomabd.ttf"
        local ok, f = pcall(love.graphics.newFont, font_path, 18)
        if ok and f then
            self.font_title = f
            self.font_header = love.graphics.newFont(font_path, 15)
            self.font_body = love.graphics.newFont(font_path, 13)
            self.font_small = love.graphics.newFont(font_path, 11)
        else
            self.font_title = love.graphics.newFont(18)
            self.font_header = love.graphics.newFont(15)
            self.font_body = love.graphics.newFont(13)
            self.font_small = love.graphics.newFont(11)
        end
    end
end

function EditorScene:setStatus(text)
    self.status_text = text
    self.status_timer = 4.0
end

-- ==============================================================================
-- BROWSER / MILLER COLUMNS
-- ==============================================================================
function EditorScene:initBrowser()
    self.columns_data = {}
    self.browser_scrolls = { 0, 0, 0 }
    self:openBrowserColumn(1, "levels")

    -- If ld60 folder exists, auto-open column 2
    local root_items = self.columns_data[1] and self.columns_data[1].items or {}
    for idx, item in ipairs(root_items) do
        if item.is_dir and item.name == "ld60" then
            self:selectBrowserItem(1, idx)
            break
        end
    end
end

function EditorScene:openBrowserColumn(col_idx, dir_path)
    -- Truncate deeper columns
    while #self.columns_data >= col_idx do
        table.remove(self.columns_data)
    end

    local items = listDirectoryItems(dir_path)
    table.insert(self.columns_data, {
        dir = dir_path,
        items = items,
        selected_idx = nil
    })
    self.browser_scrolls[col_idx] = 0
end

function EditorScene:selectBrowserItem(col_idx, item_idx)
    local col = self.columns_data[col_idx]
    if not col then return end

    col.selected_idx = item_idx
    local item = col.items[item_idx]
    if not item then return end

    if item.is_dir then
        -- Open next column with folder contents
        self.new_level_folder = item.path
        self:openBrowserColumn(col_idx + 1, item.path)
        self.selected_file_item = nil
        self.selected_file_preview = nil
    else
        -- File selected: truncate any next column and load preview
        while #self.columns_data > col_idx do
            table.remove(self.columns_data)
        end
        self.selected_file_item = item
        self:loadPreview(item.path)
    end
end

function EditorScene:loadPreview(path)
    local ok, data = pcall(LevelParser.parse, path)
    if ok and data then
        self.selected_file_preview = data
    else
        self.selected_file_preview = nil
    end
end

function EditorScene:createAndOpenNewLevel()
    local name = self.new_level_name:gsub("[^%w_%-]", "")
    if name == "" then name = "new_level" end
    local folder = self.new_level_folder or "levels"
    local file_path = folder .. "/" .. name .. ".ini"

    local new_data = {
        parent = {
            fullscreen = self.new_level_fullscreen,
            bg = self.new_level_fullscreen and nil or "assets/bg/intro_bg.png",
            shaders = { "crt" },
            music = { track = "crt", volume = 0.8, fade = 0.5 }
        },
        room = {
            id = name,
            w = 320,
            h = 240,
            camera_w = 320,
            camera_h = 240,
            bg = "assets/level0/desktop/wp.png",
            cursor = "assets/cursor.ini",
            spawn = { x = 30, y = 220, sheet = "assets/rage/rage_sh.ini" }
        },
        templates = {
            shelf = {
                type = "solid",
                image = "assets/level1/shelf2.png",
                w = 55,
                h = 8
            }
        },
        elements = {
            {
                id = "floor",
                type = "solid",
                x = 0,
                y = 224,
                w = 320,
                h = 16,
                image = "assets/level0/desktop/taskbar.png",
                is_solid = true
            },
            {
                id = "shelf_1",
                template = "shelf",
                type = "solid",
                x = 80,
                y = 160,
                w = 55,
                h = 8,
                image = "assets/level1/shelf2.png",
                is_solid = true
            },
            {
                id = "door_exit",
                type = "door",
                x = 240,
                y = 112,
                image = "assets/level0/desktop/door.png",
                on_interact = "goto:menu, 0.4"
            }
        }
    }

    local ok, err = LevelSerializer.saveToFile(file_path, new_data)
    if ok then
        LevelLoader.registerAll("levels")
        self.show_new_level_dialog = false
        self:loadLevel(file_path)
        self.view_mode = "workspace"
        self:setStatus("Created & opened: " .. file_path)
    else
        self:setStatus("Error creating file: " .. tostring(err))
    end
end

-- ==============================================================================
-- WORKSPACE / LEVEL OPERATIONS
-- ==============================================================================
function EditorScene:resolveVisual(el)
    if not el then return 16, 16, nil, 0, 0 end
    local img_path = el.image or el.idle
    local img = getImage(img_path)
    local iw, ih = 0, 0
    if img then
        iw, ih = img:getDimensions()
    end

    local is_win = (el.type == "window" or el.is_window or (el.template and el.template:match("window")))

    -- If window, visual size is el.w, el.h
    if is_win then
        return el.w or 192, el.h or 132, nil, 0, 0
    end

    -- If image exists, natural size is iw, ih unless custom size is explicitly set
    local vw = el.w or (img and iw) or (el.type == "taskbar" and 320) or 16
    local vh = el.h or (img and ih) or (el.type == "taskbar" and 16) or 16
    return vw, vh, img, iw, ih
end

function EditorScene:getCollisionBoxes(el)
    if not el then return nil, false end
    if el.collisions and #el.collisions > 0 then
        return el.collisions, true
    end
    local is_solid = (el.is_solid == true or el.type == "solid" or el.type == "oneway" or el.one_way == true)
    if is_solid then
        local vw, vh = self:resolveVisual(el)
        local is_ow = (el.type == "oneway" or el.one_way == true or el.is_one_way == true or el.top_only == true)
        return {
            { x = 0, y = 0, w = vw, h = vh, one_way = is_ow, is_default = true }
        }, false
    end
    return nil, false
end

function EditorScene:loadLevel(path)
    self.level_path = path or self.level_path or "levels/ld60/test_level.ini"
    local ok, res = pcall(LevelParser.parse, self.level_path)
    if ok and res then
        self.level_data = res
        self.selected_index = nil
        self.selected_element = nil
        self.selected_collision_idx = 1

        -- Sanitize elements that might have received spurious 16x16 size:
        for _, el in ipairs(self.level_data.elements or {}) do
            local img_path = el.image or el.idle
            local img = getImage(img_path)
            if img then
                local iw, ih = img:getDimensions()
                if el.w == 16 and el.h == 16 and (iw ~= 16 or ih ~= 16) then
                    el.w = nil
                    el.h = nil
                end
            end
        end

        self:setStatus("Loaded: " .. self.level_path)
    else
        self:setStatus("Error loading level: " .. tostring(res))
    end
end

function EditorScene:saveLevel()
    if not self.level_data then return end
    local ok, err = LevelSerializer.saveToFile(self.level_path, self.level_data)
    if ok then
        self:setStatus("Saved to " .. self.level_path)
    else
        self:setStatus("Error saving: " .. tostring(err))
    end
end

function EditorScene:screenToWorld(vx, vy)
    local wx = math.floor((vx - self.canvas_cx) / self.zoom)
    local wy = math.floor((vy - self.canvas_cy) / self.zoom)
    return wx, wy
end

function EditorScene:worldToScreen(wx, wy)
    local vx = self.canvas_cx + wx * self.zoom
    local vy = self.canvas_cy + wy * self.zoom
    return vx, vy
end

function EditorScene:snap(val)
    if not self.grid_snap then return val end
    return math.floor((val + self.grid_size / 2) / self.grid_size) * self.grid_size
end

function EditorScene:selectElement(idx)
    if idx and self.level_data and self.level_data.elements[idx] then
        self.selected_index = idx
        self.selected_element = self.level_data.elements[idx]
        self.selected_collision_idx = 1
        local win_insp = WindowManager.get("win_inspector")
        if win_insp then win_insp:open() WindowManager.bringToFront(win_insp) end
    else
        self.selected_index = nil
        self.selected_element = nil
        self.selected_collision_idx = 1
    end
end

function EditorScene:deleteSelected()
    if self.selected_index and self.level_data then
        local id = self.selected_element and self.selected_element.id or ""
        table.remove(self.level_data.elements, self.selected_index)
        self:selectElement(nil)
        self:setStatus("Deleted: " .. id)
    end
end

function EditorScene:duplicateSelected()
    if self.selected_element and self.level_data then
        local new_el = {}
        for k, v in pairs(self.selected_element) do
            if k == "collisions" and type(v) == "table" then
                new_el.collisions = {}
                for _, b in ipairs(v) do
                    local cb = {}
                    for bk, bv in pairs(b) do cb[bk] = bv end
                    table.insert(new_el.collisions, cb)
                end
            elseif type(v) == "table" then
                new_el[k] = {}
                for tk, tv in pairs(v) do new_el[k][tk] = tv end
            else
                new_el[k] = v
            end
        end
        new_el.id = new_el.id .. "_copy"
        new_el.x = (new_el.x or 0) + self.grid_size
        new_el.y = (new_el.y or 0) + self.grid_size
        table.insert(self.level_data.elements, new_el)
        self:selectElement(#self.level_data.elements)
        self:setStatus("Duplicated: " .. new_el.id)
    end
end

function EditorScene:addNewElement(el_type, tpl_name)
    if not self.level_data then return end
    local room = self.level_data.room or {}
    local spawn_x = math.floor((room.w or 320) / 2)
    local spawn_y = math.floor((room.h or 240) / 2)

    local new_id = (tpl_name or el_type or "el") .. "_" .. tostring(math.random(100, 999))
    local el = {
        id = new_id,
        type = el_type or "solid",
        template = tpl_name,
        x = self:snap(spawn_x - 20),
        y = self:snap(spawn_y - 10),
        z_index = 5
    }

    if tpl_name and self.level_data.templates and self.level_data.templates[tpl_name] then
        local tpl = self.level_data.templates[tpl_name]
        if tpl.image then el.image = tpl.image end
        if tpl.type then el.type = tpl.type end
        if tpl.is_solid ~= nil then el.is_solid = tpl.is_solid end
        if tpl.one_way ~= nil then el.one_way = tpl.one_way end
        if tpl.collisions then
            el.collisions = {}
            for _, b in ipairs(tpl.collisions) do
                table.insert(el.collisions, {
                    x = b.x or 0, y = b.y or 0, w = b.w, h = b.h,
                    one_way = b.one_way, is_one_way = b.one_way, top_only = b.one_way
                })
            end
        end
        if tpl.w and not tpl.image then el.w = tpl.w end
        if tpl.h and not tpl.image then el.h = tpl.h end
    elseif el_type == "solid" then
        el.w = 48
        el.h = 16
        el.is_solid = true
    elseif el_type == "oneway" then
        el.w = 48
        el.h = 10
        el.is_solid = true
        el.one_way = true
    elseif el_type == "door" then
        el.w = 32
        el.h = 48
        el.target = "level1"
    elseif el_type == "window" then
        el.title = "WINDOW"
        el.w = 192
        el.h = 132
        el.visible = false
    end

    table.insert(self.level_data.elements, el)
    self:selectElement(#self.level_data.elements)
    self:setStatus("Created new: " .. new_id)
end

function EditorScene:_initWindows()
    -- 1. Tools & Palette Window
    local win_tools = EditorWindow.new({
        id = "win_tools",
        title = "Toolbox & Prefabs",
        x = 24,
        y = 56,
        w = 260,
        h = 480,
        draw_content = function(win, ix, iy, iw, ih, mx, my)
            win:label("PRIMITIVES", { 0.4, 0.8, 1, 1 })
            win:button("+ Solid Platform", iw, 26, function() self:addNewElement("solid") end)
            win:button("+ OneWay Platform", iw, 26, function() self:addNewElement("oneway") end)
            win:button("+ Door Trigger", iw, 26, function() self:addNewElement("door") end)
            win:button("+ Window UI", iw, 26, function() self:addNewElement("window") end)

            win:separator(14)
            win:label("PREFABS / TEMPLATES", { 0.95, 0.8, 0.3, 1 })

            local tpls = (self.level_data and self.level_data.templates) or {}
            local has_tpls = false
            for tpl_name, _ in pairs(tpls) do
                has_tpls = true
                win:button("+ Spawn " .. tpl_name, iw, 26, function()
                    self:addNewElement("element", tpl_name)
                end)
            end
            if not has_tpls then
                win:label("No templates defined in INI", { 0.5, 0.55, 0.6, 1 })
            end

            win:separator(14)
            win:label("GRID SETTINGS", { 0.7, 0.75, 0.8, 1 })
            self.grid_snap = win:checkbox("Snap to Grid", self.grid_snap)
            self.grid_size = win:numberStepper("Grid Size (px)", self.grid_size, 8, function(v)
                self.grid_size = math.max(4, math.min(64, v))
            end)
        end
    })
    WindowManager.add(win_tools)

    -- 2. Inspector Window
    local win_inspector = EditorWindow.new({
        id = "win_inspector",
        title = "Inspector",
        x = 1920 - 364,
        y = 56,
        w = 340,
        h = 720,
        resizable = true,
        draw_content = function(win, ix, iy, iw, ih, mx, my)
            if self.selected_element then
                local el = self.selected_element
                local vw, vh, img, iw_spr, ih_spr = self:resolveVisual(el)

                -- 1. Identity
                win:label("SELECTED: " .. tostring(el.id), { 1, 0.9, 0.3, 1 })
                local type_label = el.template and ("Prefab: " .. el.template) or ("Type: " .. tostring(el.type or "solid"))
                win:label(type_label, { 0.6, 0.8, 1, 1 })
                win:separator(8)

                -- 2. Visual / Transform
                win:label("TRANSFORM / VISUAL", { 0.9, 0.85, 0.4, 1 })
                el.x = win:numberStepper("Pos X", el.x or 0, self.grid_size, function(v) el.x = v end)
                el.y = win:numberStepper("Pos Y", el.y or 0, self.grid_size, function(v) el.y = v end)

                if img then
                    win:label(string.format("Sprite: %dx%d px", iw_spr, ih_spr), { 0.7, 0.85, 0.7, 1 })
                    if el.custom_size then
                        win:label("Custom visual scale is ACTIVE", { 1, 0.65, 0.2, 1 })
                        el.w = win:numberStepper("Scale W", el.w or vw, self.grid_size, function(v) el.w = math.max(1, v) end, 1)
                        el.h = win:numberStepper("Scale H", el.h or vh, self.grid_size, function(v) el.h = math.max(1, v) end, 1)
                        win:button("Reset to 1:1 Sprite Size", iw, 24, function()
                            el.w = nil
                            el.h = nil
                            el.custom_size = nil
                        end)
                    else
                        win:button("Enable Custom Scale", iw, 22, function()
                            el.custom_size = true
                            el.w = el.w or iw_spr
                            el.h = el.h or ih_spr
                        end)
                    end
                else
                    el.w = win:numberStepper("Width", el.w or vw, self.grid_size, function(v) el.w = math.max(1, v) end, 1)
                    el.h = win:numberStepper("Height", el.h or vh, self.grid_size, function(v) el.h = math.max(1, v) end, 1)
                end

                el.z_index = win:numberStepper("Z-Index", el.z_index or 0, 1, function(v) el.z_index = v end)
                win:separator(10)

                -- 3. Collision Section (Separate parameter editing)
                win:label("COLLISION (КОЛЛИЗИЯ)", { 0.2, 1.0, 0.4, 1 })
                local cur_solid = (el.is_solid == true or el.type == "solid")
                local cur_ow = (el.type == "oneway" or el.one_way == true)
                local col_mode_str = cur_ow and "One-Way (Сквозная)" or (cur_solid and "Solid (Твёрдая)" or "None (Визуал)")
                win:label("Type: " .. col_mode_str, cur_ow and { 0.2, 0.85, 1, 1 } or (cur_solid and { 0.2, 1, 0.4, 1 } or { 0.6, 0.65, 0.7, 1 }))

                -- Type switch buttons
                win:button("Set: Solid Platform", iw, 24, function()
                    el.is_solid = true
                    el.one_way = nil
                    if el.type == "oneway" then el.type = "solid" end
                end)
                win:button("Set: One-Way Platform", iw, 24, function()
                    el.is_solid = true
                    el.one_way = true
                    el.type = "oneway"
                end)
                win:button("Set: No Collision (Visual Only)", iw, 24, function()
                    el.is_solid = false
                    el.one_way = false
                    el.collisions = nil
                    if el.type == "solid" or el.type == "oneway" then el.type = "element" end
                end)

                if el.is_solid or el.type == "solid" or el.type == "oneway" or el.one_way or (el.collisions and #el.collisions > 0) then
                    win:separator(6)
                    local has_custom = (el.collisions ~= nil and #el.collisions > 0)
                    local toggle_custom = win:checkbox("Collision != Object (Кастомные боксы)", has_custom)
                    if toggle_custom and not has_custom then
                        local def_h = (cur_ow and math.min(vh, 6) or vh)
                        el.collisions = {
                            { x = 0, y = 0, w = vw, h = def_h, one_way = cur_ow, is_one_way = cur_ow, top_only = cur_ow }
                        }
                        self.selected_collision_idx = 1
                    elseif not toggle_custom and has_custom then
                        el.collisions = nil
                        self.selected_collision_idx = 1
                    end

                    if el.collisions and #el.collisions > 0 then
                        win:label(string.format("Кастомные боксы (%d):", #el.collisions), { 0.3, 0.9, 1, 1 })
                        for b_idx, b in ipairs(el.collisions) do
                            local is_b_sel = (self.selected_collision_idx == b_idx)
                            local b_header = string.format("Бокс #%d: [%s]%s", b_idx, b.one_way and "One-Way" or "Solid", is_b_sel and " [АКТИВЕН]" or "")
                            win:label(b_header, is_b_sel and { 1, 0.9, 0.2, 1 } or { 0.75, 0.85, 0.95, 1 })

                            b.x = win:numberStepper("  Offset X", b.x or 0, self.grid_size, function(v) b.x = v end)
                            b.y = win:numberStepper("  Offset Y", b.y or 0, self.grid_size, function(v) b.y = v end)
                            b.w = win:numberStepper("  Width", b.w or vw, self.grid_size, function(v) b.w = math.max(1, v) end, 1)
                            b.h = win:numberStepper("  Height", b.h or vh, self.grid_size, function(v) b.h = math.max(1, v) end, 1)
                            b.one_way = win:checkbox("  One-Way (верхняя грань)", b.one_way == true)
                            b.is_one_way = b.one_way
                            b.top_only = b.one_way

                            if #el.collisions > 1 then
                                win:button("Удалить бокс #" .. b_idx, iw, 22, function()
                                    table.remove(el.collisions, b_idx)
                                    self.selected_collision_idx = 1
                                end)
                            end
                            win:separator(4)
                        end

                        win:button("+ Добавить бокс коллизии", iw, 24, function()
                            table.insert(el.collisions, {
                                x = 0, y = 0, w = vw, h = math.min(vh, 6), one_way = cur_ow, is_one_way = cur_ow, top_only = cur_ow
                            })
                            self.selected_collision_idx = #el.collisions
                        end)
                        win:button("Сбросить к размеру объекта", iw, 24, function()
                            el.collisions = {
                                { x = 0, y = 0, w = vw, h = vh, one_way = cur_ow, is_one_way = cur_ow, top_only = cur_ow }
                            }
                            self.selected_collision_idx = 1
                        end)
                    else
                        win:label(string.format("Зона коллизии: %dx%d (1:1 со спрайтом)", vw, vh), { 0.5, 0.75, 0.65, 1 })
                    end
                end

                -- 4. Other Properties & Actions
                win:separator(10)
                win:label("PROPERTIES / ACTIONS", { 0.7, 0.75, 0.8, 1 })
                if el.image then
                    win:label("Image: " .. tostring(el.image), { 0.7, 0.7, 0.7, 1 })
                end
                if el.on_interact then
                    win:label("Action: " .. tostring(el.on_interact), { 0.4, 0.9, 0.5, 1 })
                end
                if el.visible ~= nil then
                    el.visible = win:checkbox("Visible in Game", el.visible ~= false)
                end

                win:separator(12)
                win:button("Duplicate (Ctrl+D)", iw, 26, function() self:duplicateSelected() end)
                win:button("Delete Object (Del)", iw, 26, function() self:deleteSelected() end)
            else
                win:label("NO SELECTION", { 0.55, 0.6, 0.65, 1 })
                win:label("Click any object on the canvas", { 0.7, 0.7, 0.7, 1 })
                win:label("or in Hierarchy to edit.", { 0.7, 0.7, 0.7, 1 })
                win:separator(14)

                local r = self.level_data and self.level_data.room or {}
                win:label("ROOM SUMMARY", { 0.4, 0.8, 1, 1 })
                win:label(string.format("Room Size: %d x %d", r.w or 320, r.h or 240))
                win:label(string.format("Camera Size: %d x %d", r.camera_w or r.w or 320, r.camera_h or r.h or 240))
                win:label("Elements: " .. tostring(#((self.level_data and self.level_data.elements) or {})))
            end
        end
    })
    WindowManager.add(win_inspector)

    -- 3. Level Settings Window
    local win_settings = EditorWindow.new({
        id = "win_settings",
        title = "Level Settings",
        x = 1920 - 344,
        y = 650,
        w = 320,
        h = 380,
        draw_content = function(win, ix, iy, iw, ih, mx, my)
            if not self.level_data then return end
            local p = self.level_data.parent or {}
            local r = self.level_data.room or {}

            win:label("ENVIRONMENT & SCREEN", { 0.4, 0.8, 1, 1 })
            p.fullscreen = win:checkbox("Fullscreen (No Room BG)", p.fullscreen or (p.bg == nil))

            if not p.fullscreen then
                win:label("BG: " .. tostring(p.bg or "None"), { 0.7, 0.7, 0.7, 1 })
            end

            local shader_str = (p.shaders and p.shaders[1]) or "crt"
            win:label("Screen Shader: " .. shader_str, { 0.9, 0.8, 0.3, 1 })
            win:button("Cycle Shader (crt/ascii/none)", iw, 24, function()
                if shader_str == "crt" then p.shaders = { "ascii_crt" }
                elseif shader_str == "ascii_crt" then p.shaders = { "none" }
                else p.shaders = { "crt" } end
            end)

            win:separator(10)
            win:label("ROOM / CAMERA BOUNDS", { 0.4, 0.8, 1, 1 })
            r.w = win:numberStepper("Room W", r.w or 320, 20, function(v) r.w = math.max(160, v) end)
            r.h = win:numberStepper("Room H", r.h or 240, 20, function(v) r.h = math.max(120, v) end)

            r.camera_w = win:numberStepper("Camera W", r.camera_w or r.w or 320, 20, function(v) r.camera_w = math.max(160, v) end)
            r.camera_h = win:numberStepper("Camera H", r.camera_h or r.h or 240, 20, function(v) r.camera_h = math.max(120, v) end)
        end
    })
    WindowManager.add(win_settings)

    -- 4. Hierarchy Window
    local win_tree = EditorWindow.new({
        id = "win_tree",
        title = "Hierarchy",
        x = 24,
        y = 550,
        w = 260,
        h = 480,
        draw_content = function(win, ix, iy, iw, ih, mx, my)
            local els = (self.level_data and self.level_data.elements) or {}
            win:label("OBJECTS (" .. #els .. ")", { 0.4, 0.8, 1, 1 })
            win:separator(6)

            for i, el in ipairs(els) do
                local is_sel = (i == self.selected_index)
                local prefix = is_sel and "> " or "  "
                local label = prefix .. tostring(el.id) .. " (" .. tostring(el.template or el.type or "solid") .. ")"

                win:button(label, iw, 24, function()
                    self:selectElement(i)
                end)
            end
        end
    })
    WindowManager.add(win_tree)
end

function EditorScene:enter(path)
    if path and path ~= "" then
        self:loadLevel(path)
        self.view_mode = "workspace"
    else
        self:initBrowser()
        self.view_mode = "browser"
    end
end

function EditorScene:update(dt)
    if self.status_timer > 0 then
        self.status_timer = self.status_timer - dt
    end
end

function EditorScene:draw()
    self:_initFonts()

    if self.view_mode == "browser" then
        self:drawBrowser()
    else
        self:drawWorkspace()
    end

    if self.show_new_level_dialog then
        self:drawNewLevelDialog()
    end
end

-- ==============================================================================
-- DRAWING: BROWSER (MILLER COLUMNS)
-- ==============================================================================
function EditorScene:drawBrowser()
    local mx, my = Viewport.getMousePosition()

    -- Dark background
    love.graphics.setColor(0.08, 0.09, 0.12, 1)
    love.graphics.rectangle("fill", 0, 0, 1920, 1080)

    -- Top Header
    love.graphics.setColor(0.12, 0.14, 0.18, 0.98)
    love.graphics.rectangle("fill", 0, 0, 1920, 70)
    love.graphics.setColor(0.25, 0.28, 0.35, 1)
    love.graphics.line(0, 70, 1920, 70)

    love.graphics.setColor(1, 0.85, 0.2, 1)
    if self.font_title then love.graphics.setFont(self.font_title) end
    love.graphics.print("LEVEL MANAGER & BROWSER", 40, 14)

    love.graphics.setColor(0.65, 0.7, 0.78, 1)
    if self.font_body then love.graphics.setFont(self.font_body) end
    love.graphics.print("Browse folders, select a level to open, or create a new level", 40, 42)

    -- Header Right Buttons
    local function topBtn(x, y, w, h, text, bg_col, hover_col, onClick)
        local hover = (mx >= x and mx <= x + w and my >= y and my <= y + h)
        love.graphics.setColor(hover and hover_col or bg_col)
        love.graphics.rectangle("fill", x, y, w, h, 4, 4)
        love.graphics.setColor(0.4, 0.5, 0.65, 1)
        love.graphics.rectangle("line", x, y, w, h, 4, 4)
        love.graphics.setColor(1, 1, 1, 1)
        if self.font_header then love.graphics.setFont(self.font_header) end
        local tw = self.font_header and self.font_header:getWidth(text) or 60
        love.graphics.print(text, x + (w - tw) / 2, y + (h - 18) / 2)

        if hover and love.mouse.isDown(1) and not self.browser_btn_down then
            self.browser_btn_down = true
            onClick()
        end
    end

    topBtn(1680, 16, 200, 38, "+ Создать уровень", { 0.2, 0.52, 0.32, 1 }, { 0.28, 0.65, 0.4, 1 }, function()
        self.show_new_level_dialog = true
    end)

    if self.level_data then
        topBtn(1440, 16, 220, 38, "В редактор (Esc)", { 0.2, 0.26, 0.38, 1 }, { 0.3, 0.38, 0.55, 1 }, function()
            self.view_mode = "workspace"
        end)
    end

    if not love.mouse.isDown(1) then
        self.browser_btn_down = false
    end

    -- Breadcrumb Bar
    love.graphics.setColor(0.14, 0.16, 0.21, 1)
    love.graphics.rectangle("fill", 40, 84, 1840, 38, 4, 4)
    love.graphics.setColor(0.28, 0.32, 0.4, 1)
    love.graphics.rectangle("line", 40, 84, 1840, 38, 4, 4)

    local cur_path_str = "Folder: [<root>]"
    for i, col in ipairs(self.columns_data) do
        cur_path_str = cur_path_str .. " > [" .. col.dir:gsub("^levels/?", "") .. "]"
    end
    love.graphics.setColor(0.4, 0.85, 1, 1)
    if self.font_body then love.graphics.setFont(self.font_body) end
    love.graphics.print(cur_path_str, 56, 94)

    -- Miller Columns Container
    local col_y = 136
    local col_h = 880
    local col_w = 420
    local start_x = 40

    for col_idx, col in ipairs(self.columns_data) do
        local cx = start_x + (col_idx - 1) * (col_w + 16)
        if cx + col_w <= 1920 - 460 then
            -- Column box
            love.graphics.setColor(0.12, 0.14, 0.18, 0.95)
            love.graphics.rectangle("fill", cx, col_y, col_w, col_h, 4, 4)
            love.graphics.setColor(0.25, 0.28, 0.36, 1)
            love.graphics.rectangle("line", cx, col_y, col_w, col_h, 4, 4)

            -- Column Header
            love.graphics.setColor(0.16, 0.2, 0.26, 1)
            love.graphics.rectangle("fill", cx, col_y, col_w, 34, 4, 4)
            love.graphics.setColor(0.3, 0.36, 0.46, 1)
            love.graphics.line(cx, col_y + 34, cx + col_w, col_y + 34)

            love.graphics.setColor(1, 1, 1, 1)
            if self.font_header then love.graphics.setFont(self.font_header) end
            local col_title = (col.dir == "levels") and "levels (root)" or col.dir
            love.graphics.print(col_title, cx + 12, col_y + 8)

            -- Column Items
            local item_h = 36
            local list_y = col_y + 40
            local list_h = col_h - 48

            local sx, sy = Viewport.toScreen(cx + 8, list_y)
            local sw = (col_w - 16) * Viewport.scale
            local sh = list_h * Viewport.scale

            love.graphics.push("all")
            love.graphics.setScissor(sx, sy, sw, sh)

            for item_idx, item in ipairs(col.items) do
                local iy = list_y + (item_idx - 1) * item_h - (self.browser_scrolls[col_idx] or 0)
                if iy + item_h >= list_y and iy <= list_y + list_h then
                    local is_sel = (col.selected_idx == item_idx)
                    local hover = (mx >= cx + 8 and mx <= cx + col_w - 8 and my >= iy and my <= iy + item_h - 2)

                    if is_sel then
                        love.graphics.setColor(0.2, 0.45, 0.75, 1)
                    elseif hover then
                        love.graphics.setColor(0.18, 0.22, 0.32, 1)
                    else
                        love.graphics.setColor(0.14, 0.15, 0.2, 0.6)
                    end
                    love.graphics.rectangle("fill", cx + 8, iy, col_w - 16, item_h - 2, 3, 3)

                    -- Icon badge
                    if item.is_dir then
                        love.graphics.setColor(0.35, 0.8, 1, 1)
                        love.graphics.print("[DIR]", cx + 16, iy + 9)
                    else
                        love.graphics.setColor(0.4, 0.95, 0.5, 1)
                        love.graphics.print("[LVL]", cx + 16, iy + 9)
                    end

                    -- Item Name
                    love.graphics.setColor(1, 1, 1, 1)
                    if self.font_body then love.graphics.setFont(self.font_body) end
                    love.graphics.print(item.name, cx + 60, iy + 9)

                    if item.is_dir then
                        love.graphics.setColor(0.5, 0.6, 0.7, 1)
                        love.graphics.print(">", cx + col_w - 28, iy + 9)
                    end
                end
            end

            love.graphics.pop()
        end
    end

    -- Details & Action Panel (Right Side)
    local card_x = 1920 - 460
    local card_w = 420
    love.graphics.setColor(0.11, 0.13, 0.17, 0.96)
    love.graphics.rectangle("fill", card_x, col_y, card_w, col_h, 4, 4)
    love.graphics.setColor(0.25, 0.3, 0.4, 1)
    love.graphics.rectangle("line", card_x, col_y, card_w, col_h, 4, 4)

    love.graphics.setColor(0.16, 0.2, 0.28, 1)
    love.graphics.rectangle("fill", card_x, col_y, card_w, 34, 4, 4)
    love.graphics.setColor(0.3, 0.36, 0.48, 1)
    love.graphics.line(card_x, col_y + 34, card_x + card_w, col_y + 34)

    love.graphics.setColor(1, 1, 1, 1)
    if self.font_header then love.graphics.setFont(self.font_header) end
    love.graphics.print("LEVEL DETAILS", card_x + 16, col_y + 8)

    if self.selected_file_item then
        local p = self.selected_file_preview
        local r = p and p.room or {}
        local parent = p and p.parent or {}

        love.graphics.setColor(0.3, 0.9, 0.5, 1)
        if self.font_title then love.graphics.setFont(self.font_title) end
        love.graphics.print(self.selected_file_item.name, card_x + 20, col_y + 56)

        love.graphics.setColor(0.65, 0.7, 0.78, 1)
        if self.font_small then love.graphics.setFont(self.font_small) end
        love.graphics.print("Path: " .. self.selected_file_item.path, card_x + 20, col_y + 86)

        love.graphics.setColor(0.25, 0.28, 0.35, 1)
        love.graphics.line(card_x + 20, col_y + 110, card_x + card_w - 20, col_y + 110)

        if p then
            love.graphics.setColor(0.85, 0.9, 0.95, 1)
            if self.font_body then love.graphics.setFont(self.font_body) end
            local py = col_y + 126
            love.graphics.print("Room ID: " .. tostring(r.id or "level"), card_x + 20, py) py = py + 26
            love.graphics.print(string.format("Room Size: %d x %d", r.w or 320, r.h or 240), card_x + 20, py) py = py + 26
            love.graphics.print(string.format("Camera Size: %d x %d", r.camera_w or r.w or 320, r.camera_h or r.h or 240), card_x + 20, py) py = py + 26
            love.graphics.print("Fullscreen: " .. tostring(parent.fullscreen or (parent.bg == nil)), card_x + 20, py) py = py + 26
            love.graphics.print("Shader: " .. tostring((parent.shaders and parent.shaders[1]) or "crt"), card_x + 20, py) py = py + 26
            love.graphics.print("Music: " .. tostring((parent.music and parent.music.track) or "None"), card_x + 20, py) py = py + 26
            love.graphics.print("Elements Count: " .. tostring(#(p.elements or {})), card_x + 20, py) py = py + 26
        else
            love.graphics.setColor(0.8, 0.3, 0.3, 1)
            love.graphics.print("Failed to parse file preview", card_x + 20, col_y + 130)
        end

        -- Action Buttons
        topBtn(card_x + 20, col_y + col_h - 120, card_w - 40, 48, "ОТКРЫТЬ В РЕДАКТОРЕ", { 0.2, 0.55, 0.35, 1 }, { 0.28, 0.68, 0.45, 1 }, function()
            self:loadLevel(self.selected_file_item.path)
            self.view_mode = "workspace"
        end)

        topBtn(card_x + 20, col_y + col_h - 60, card_w - 40, 42, "ЗАПУСТИТЬ ПЛЕЙТЕСТ (F5)", { 0.2, 0.35, 0.6, 1 }, { 0.28, 0.48, 0.75, 1 }, function()
            local base_name = self.selected_file_item.path:gsub("^levels/", ""):gsub("%.ini$", ""):gsub("/", ".")
            SceneManager.goTo(base_name)
        end)
    else
        love.graphics.setColor(0.5, 0.55, 0.65, 1)
        if self.font_body then love.graphics.setFont(self.font_body) end
        love.graphics.print("Select a level file (.ini)\nto inspect and open it.", card_x + 20, col_y + 60)
    end
end

-- ==============================================================================
-- DRAWING: MODAL CREATE LEVEL DIALOG
-- ==============================================================================
function EditorScene:drawNewLevelDialog()
    -- Dim background
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, 1920, 1080)

    local mx, my = Viewport.getMousePosition()
    local dw, dh = 560, 360
    local dx = (1920 - dw) / 2
    local dy = (1080 - dh) / 2

    love.graphics.setColor(0.12, 0.14, 0.19, 0.98)
    love.graphics.rectangle("fill", dx, dy, dw, dh, 6, 6)
    love.graphics.setColor(0.35, 0.45, 0.65, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", dx, dy, dw, dh, 6, 6)

    -- Dialog Title
    love.graphics.setColor(0.18, 0.24, 0.35, 1)
    love.graphics.rectangle("fill", dx, dy, dw, 40, 6, 6)
    love.graphics.setColor(1, 1, 1, 1)
    if self.font_header then love.graphics.setFont(self.font_header) end
    love.graphics.print("СОЗДАТЬ НОВЫЙ УРОВЕНЬ", dx + 20, dy + 10)

    -- Form Fields
    local fy = dy + 60
    love.graphics.setColor(0.85, 0.88, 0.92, 1)
    if self.font_body then love.graphics.setFont(self.font_body) end
    love.graphics.print("Папка: " .. (self.new_level_folder or "levels"), dx + 24, fy)

    fy = fy + 36
    love.graphics.print("Имя файла уровня (.ini):", dx + 24, fy)
    fy = fy + 24

    -- Input box for name
    love.graphics.setColor(0.08, 0.09, 0.12, 1)
    love.graphics.rectangle("fill", dx + 24, fy, dw - 48, 36, 4, 4)
    love.graphics.setColor(0.4, 0.6, 0.9, 1)
    love.graphics.rectangle("line", dx + 24, fy, dw - 48, 36, 4, 4)
    love.graphics.setColor(1, 1, 0.6, 1)
    love.graphics.print(self.new_level_name .. "_", dx + 36, fy + 8)

    fy = fy + 56
    -- Fullscreen toggle checkbox
    local hover_chk = (mx >= dx + 24 and mx <= dx + 300 and my >= fy and my <= fy + 24)
    love.graphics.setColor(0.14, 0.16, 0.22, 1)
    love.graphics.rectangle("fill", dx + 24, fy, 18, 18, 2, 2)
    love.graphics.setColor(0.4, 0.45, 0.55, 1)
    love.graphics.rectangle("line", dx + 24, fy, 18, 18, 2, 2)
    if self.new_level_fullscreen then
        love.graphics.setColor(0.3, 0.85, 0.4, 1)
        love.graphics.rectangle("fill", dx + 27, fy + 3, 12, 12)
    end
    love.graphics.setColor(hover_chk and { 1, 1, 1, 1 } or { 0.85, 0.88, 0.92, 1 })
    love.graphics.print("Fullscreen (без фона комнаты / ретро-монитора)", dx + 52, fy)

    if hover_chk and love.mouse.isDown(1) and not self.dialog_chk_down then
        self.dialog_chk_down = true
        self.new_level_fullscreen = not self.new_level_fullscreen
    end
    if not love.mouse.isDown(1) then self.dialog_chk_down = false end

    -- Buttons
    local function dlgBtn(bx, by, bw, bh, text, col, hover_c, onClick)
        local hover = (mx >= bx and mx <= bx + bw and my >= by and my <= by + bh)
        love.graphics.setColor(hover and hover_c or col)
        love.graphics.rectangle("fill", bx, by, bw, bh, 4, 4)
        love.graphics.setColor(1, 1, 1, 1)
        local tw = self.font_header and self.font_header:getWidth(text) or 60
        love.graphics.print(text, bx + (bw - tw) / 2, by + (bh - 18) / 2)
        if hover and love.mouse.isDown(1) and not self.dialog_btn_down then
            self.dialog_btn_down = true
            onClick()
        end
    end

    dlgBtn(dx + 24, dy + dh - 56, 240, 40, "Создать и открыть", { 0.2, 0.55, 0.35, 1 }, { 0.28, 0.68, 0.45, 1 }, function()
        self:createAndOpenNewLevel()
    end)

    dlgBtn(dx + dw - 150, dy + dh - 56, 126, 40, "Отмена", { 0.25, 0.28, 0.35, 1 }, { 0.35, 0.38, 0.48, 1 }, function()
        self.show_new_level_dialog = false
    end)

    if not love.mouse.isDown(1) then self.dialog_btn_down = false end
end

-- ==============================================================================
-- DRAWING: WORKSPACE (CANVAS + FLOATING WINDOWS)
-- ==============================================================================
function EditorScene:drawWorkspace()
    -- 1. Dark workspace background
    love.graphics.setColor(0.08, 0.09, 0.11, 1)
    love.graphics.rectangle("fill", 0, 0, 1920, 1080)

    -- 2. Render Level Canvas
    self:drawCanvas()

    -- 3. Top Menu Bar
    self:drawTopBar()

    -- 4. Bottom Status Bar
    self:drawBottomBar()

    -- 5. Floating Windows
    WindowManager.draw()
end

function EditorScene:drawCanvas()
    if not self.level_data then return end

    local r = self.level_data.room or {}
    local rw = r.w or 320
    local rh = r.h or 240

    local sx, sy = self:worldToScreen(0, 0)
    local sw = rw * self.zoom
    local sh = rh * self.zoom

    -- Room Canvas Backing
    love.graphics.setColor(0.15, 0.17, 0.22, 1)
    love.graphics.rectangle("fill", sx, sy, sw, sh)

    -- Wallpaper if exists
    if r.bg then
        local img = getImage(r.bg)
        if img then
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(img, sx, sy, 0, self.zoom, self.zoom)
        end
    end

    -- Grid lines
    if self.grid_snap and self.zoom >= 2.0 then
        love.graphics.setColor(0.25, 0.28, 0.35, 0.45)
        love.graphics.setLineWidth(1)
        local step = self.grid_size * self.zoom
        for x = sx, sx + sw, step do
            love.graphics.line(x, sy, x, sy + sh)
        end
        for y = sy, sy + sh, step do
            love.graphics.line(sx, y, sx + sw, y)
        end
    end

    -- Camera bounds indicator
    local cw = (r.camera_w or rw) * self.zoom
    local ch = (r.camera_h or rh) * self.zoom
    if cw < sw or ch < sh then
        love.graphics.setColor(1, 0.8, 0.2, 0.4)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", sx, sy, cw, ch)
    end

    -- Draw Elements
    local els = (self.level_data and self.level_data.elements) or {}
    for i, el in ipairs(els) do
        local vw, vh, img, iw, ih = self:resolveVisual(el)
        local ex, ey = self:worldToScreen(el.x or 0, el.y or 0)
        local ew = vw * self.zoom
        local eh = vh * self.zoom
        local is_sel = (i == self.selected_index)

        -- 1. Visual rendering
        local is_win = (el.type == "window" or el.is_window or (el.template and el.template:match("window")))

        if is_win then
            -- Draw as a clean, translucent OS window preview (NEVER solid green!)
            if self.show_windows ~= false then
                love.graphics.setColor(0.12, 0.16, 0.25, 0.45)
                love.graphics.rectangle("fill", ex, ey, ew, eh, 2, 2)

                -- Titlebar
                local tbh = math.min(22 * (self.zoom >= 2 and 1.5 or 1), eh * 0.25)
                love.graphics.setColor(0.2, 0.35, 0.65, 0.8)
                love.graphics.rectangle("fill", ex, ey, ew, tbh, 2, 2)

                love.graphics.setColor(0.4, 0.6, 0.9, 0.9)
                love.graphics.rectangle("line", ex, ey, ew, eh, 2, 2)

                love.graphics.setColor(1, 1, 1, 0.95)
                if self.font_small then love.graphics.setFont(self.font_small) end
                local title_txt = (el.title or el.id or "Window") .. (el.visible == false and " [Hidden]" or "")
                love.graphics.print(title_txt, ex + 6, ey + 3)
            end
        elseif img then
            love.graphics.setColor(1, 1, 1, 1)
            if el.custom_size and iw > 0 and ih > 0 then
                love.graphics.draw(img, ex, ey, 0, (vw / iw) * self.zoom, (vh / ih) * self.zoom)
            else
                love.graphics.draw(img, ex, ey, 0, self.zoom, self.zoom)
            end
        else
            -- Element without image and not window
            if el.type == "door" then
                love.graphics.setColor(0.75, 0.45, 0.15, 0.55)
                love.graphics.rectangle("fill", ex, ey, ew, eh)
                love.graphics.setColor(1, 0.7, 0.3, 0.9)
                love.graphics.rectangle("line", ex, ey, ew, eh)
                if self.font_small then
                    love.graphics.setFont(self.font_small)
                    love.graphics.print("DOOR", ex + 4, ey + 4)
                end
            elseif el.type == "oneway" or el.one_way then
                love.graphics.setColor(0.2, 0.7, 0.8, 0.35)
                love.graphics.rectangle("fill", ex, ey, ew, eh)
            elseif el.is_solid then
                love.graphics.setColor(0.3, 0.45, 0.4, 0.4)
                love.graphics.rectangle("fill", ex, ey, ew, eh)
            else
                love.graphics.setColor(0.35, 0.4, 0.55, 0.4)
                love.graphics.rectangle("fill", ex, ey, ew, eh)
            end
            love.graphics.setColor(0.5, 0.6, 0.75, 0.8)
            love.graphics.rectangle("line", ex, ey, ew, eh)
        end

        -- 2. Collision rendering (Rendered accurately with cyan/yellow or green)
        if self.show_collisions ~= false and not is_win then
            local boxes, is_custom = self:getCollisionBoxes(el)
            if boxes and #boxes > 0 then
                for b_idx, b in ipairs(boxes) do
                    local bx = (el.x or 0) + (b.x or 0)
                    local by = (el.y or 0) + (b.y or 0)
                    local bw = b.w or vw
                    local bh = b.h or vh
                    local bsx, bsy = self:worldToScreen(bx, by)
                    local bsw = bw * self.zoom
                    local bsh = bh * self.zoom

                    local is_ow = (b.one_way or b.is_one_way or b.top_only or el.type == "oneway" or el.one_way)
                    local is_b_sel = is_sel and (is_custom and (self.selected_collision_idx == b_idx))

                    if is_ow then
                        -- One-Way platform: Cyan body + Yellow top edge (exact game match!)
                        love.graphics.setColor(0.15, 0.8, 0.95, is_sel and 0.25 or 0.12)
                        love.graphics.rectangle("fill", bsx, bsy, bsw, bsh)

                        love.graphics.setColor(0.15, 0.8, 0.95, is_sel and 1.0 or 0.75)
                        love.graphics.setLineWidth(is_b_sel and 2 or 1)
                        love.graphics.rectangle("line", bsx, bsy, bsw, bsh)

                        -- Top ledge highlight (Yellow line)
                        love.graphics.setColor(1, 1, 0.1, 0.95)
                        love.graphics.setLineWidth(2)
                        love.graphics.line(bsx, bsy, bsx + bsw, bsy)
                    else
                        -- Solid block: Bright green
                        love.graphics.setColor(0.1, 0.95, 0.3, is_sel and 0.25 or 0.12)
                        love.graphics.rectangle("fill", bsx, bsy, bsw, bsh)

                        love.graphics.setColor(0.1, 0.95, 0.3, is_sel and 1.0 or 0.75)
                        love.graphics.setLineWidth(is_b_sel and 2 or 1)
                        love.graphics.rectangle("line", bsx, bsy, bsw, bsh)
                    end

                    -- If custom box, show badge
                    if is_custom then
                        love.graphics.setColor(is_ow and { 0.1, 0.9, 1, 0.9 } or { 0.2, 1, 0.4, 0.9 })
                        if self.font_small then love.graphics.setFont(self.font_small) end
                        love.graphics.print(string.format("#%d", b_idx), bsx + 2, bsy + 2)

                        -- If this box is actively selected for editing, draw resize handles
                        if is_b_sel and self.edit_mode == "collision" then
                            love.graphics.setColor(1, 1, 0.2, 1)
                            love.graphics.rectangle("fill", bsx - 3, bsy - 3, 6, 6)
                            love.graphics.rectangle("fill", bsx + bsw - 3, bsy + bsh - 3, 6, 6)
                        end
                    end
                end
            end
        end

        -- 3. Visual Selection Highlight (Yellow boundary on the object)
        if is_sel then
            love.graphics.setColor(1, 0.85, 0.2, 1)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", ex - 2, ey - 2, ew + 4, eh + 4)

            -- Corner resize/drag handles
            love.graphics.rectangle("fill", ex - 4, ey - 4, 6, 6)
            love.graphics.rectangle("fill", ex + ew - 2, ey - 4, 6, 6)
            love.graphics.rectangle("fill", ex - 4, ey + eh - 2, 6, 6)
            love.graphics.rectangle("fill", ex + ew - 2, ey + eh - 2, 6, 6)

            -- Selection Tag above object
            local tag_str = tostring(el.id) .. " (" .. tostring(vw) .. "x" .. tostring(vh) .. ")"
            if el.collisions and #el.collisions > 0 then
                tag_str = tag_str .. string.format(" [Custom Collision: %d]", #el.collisions)
            end
            love.graphics.setColor(0.1, 0.12, 0.16, 0.85)
            local tw = self.font_small and self.font_small:getWidth(tag_str) or 80
            love.graphics.rectangle("fill", ex, ey - 18, tw + 8, 16, 2, 2)
            love.graphics.setColor(1, 0.88, 0.3, 1)
            if self.font_small then
                love.graphics.setFont(self.font_small)
                love.graphics.print(tag_str, ex + 4, ey - 17)
            end
        end
    end

    -- Player Spawn Marker
    if r.spawn then
        local px, py = self:worldToScreen(r.spawn.x or 0, r.spawn.y or 0)
        love.graphics.setColor(1, 0.25, 0.25, 0.9)
        love.graphics.circle("fill", px, py, 6 * (self.zoom / 2))
        love.graphics.setColor(1, 1, 1, 1)
        if self.font_body then love.graphics.setFont(self.font_body) end
        love.graphics.print("SPAWN", px + 8, py - 8)
    end

    -- Room Canvas Border
    love.graphics.setColor(0.4, 0.5, 0.7, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", sx, sy, sw, sh)
end

function EditorScene:drawTopBar()
    love.graphics.setColor(0.12, 0.14, 0.18, 0.98)
    love.graphics.rectangle("fill", 0, 0, 1920, 42)
    love.graphics.setColor(0.25, 0.28, 0.35, 1)
    love.graphics.line(0, 42, 1920, 42)

    love.graphics.setColor(1, 0.8, 0.2, 1)
    if self.font_header then love.graphics.setFont(self.font_header) end
    love.graphics.print("LEVEL EDITOR", 24, 12)

    love.graphics.setColor(0.7, 0.75, 0.8, 1)
    if self.font_body then love.graphics.setFont(self.font_body) end
    local fname = self.level_path and self.level_path:match("([^/\\]+%.ini)$") or self.level_path or "None"
    love.graphics.print("File: " .. fname, 160, 14)

    -- Top Menu Buttons
    local btn_x = 360
    local function menuBtn(label, w, onClick, active, custom_col)
        local mx, my = Viewport.getMousePosition()
        local hover = (mx >= btn_x and mx <= btn_x + w and my >= 8 and my <= 34)
        if custom_col then
            love.graphics.setColor(hover and custom_col[2] or custom_col[1])
        elseif active then
            love.graphics.setColor(hover and { 0.25, 0.55, 0.85, 1 } or { 0.2, 0.45, 0.75, 1 })
        else
            love.graphics.setColor(hover and { 0.25, 0.32, 0.42, 1 } or { 0.16, 0.19, 0.26, 1 })
        end
        love.graphics.rectangle("fill", btn_x, 8, w, 26, 3, 3)
        love.graphics.setColor(0.38, 0.45, 0.58, 1)
        love.graphics.rectangle("line", btn_x, 8, w, 26, 3, 3)
        love.graphics.setColor(1, 1, 1, 1)
        local tw = self.font_body and self.font_body:getWidth(label) or 40
        love.graphics.print(label, btn_x + (w - tw) / 2, 13)

        if hover and love.mouse.isDown(1) and not self.top_btn_down then
            self.top_btn_down = true
            onClick()
        end
        btn_x = btn_x + w + 8
    end

    menuBtn("Levels Browser", 120, function() self:initBrowser() self.view_mode = "browser" end)
    menuBtn("Save (Ctrl+S)", 100, function() self:saveLevel() end)
    menuBtn("Playtest (F5)", 105, function() self:startPlaytest() end, false, { { 0.2, 0.45, 0.28, 1 }, { 0.28, 0.58, 0.36, 1 } })

    -- Mode toggle button
    local is_col_mode = (self.edit_mode == "collision")
    local mode_label = is_col_mode and "Mode: Collision (C)" or "Mode: Object (V)"
    local mode_cols = is_col_mode and { { 0.18, 0.45, 0.55, 1 }, { 0.25, 0.58, 0.7, 1 } } or { { 0.55, 0.4, 0.15, 1 }, { 0.7, 0.52, 0.2, 1 } }
    menuBtn(mode_label, 150, function()
        self.edit_mode = is_col_mode and "object" or "collision"
        self:setStatus("Mode switched to: " .. self.edit_mode:upper())
    end, true, mode_cols)

    -- View toggles
    menuBtn(self.show_collisions ~= false and "Collisions: ON" or "Collisions: OFF", 115, function()
        self.show_collisions = not self.show_collisions
    end, self.show_collisions ~= false)

    menuBtn(self.show_windows ~= false and "Windows: ON" or "Windows: OFF", 105, function()
        self.show_windows = not self.show_windows
    end, self.show_windows ~= false)

    -- Window toggles
    menuBtn("Tools", 60, function() WindowManager.get("win_tools"):toggle() end)
    menuBtn("Inspector", 78, function() WindowManager.get("win_inspector"):toggle() end)
    menuBtn("Settings", 74, function() WindowManager.get("win_settings"):toggle() end)
    menuBtn("Hierarchy", 78, function() WindowManager.get("win_tree"):toggle() end)

    if not love.mouse.isDown(1) then
        self.top_btn_down = false
    end
end

function EditorScene:drawBottomBar()
    love.graphics.setColor(0.1, 0.11, 0.14, 0.98)
    love.graphics.rectangle("fill", 0, 1046, 1920, 34)
    love.graphics.setColor(0.25, 0.28, 0.35, 1)
    love.graphics.line(0, 1046, 1920, 1046)

    local mx, my = Viewport.getMousePosition()
    local wx, wy = self:screenToWorld(mx, my)

    love.graphics.setColor(0.8, 0.85, 0.9, 1)
    if self.font_body then love.graphics.setFont(self.font_body) end
    local info = string.format("Cursor: (%d, %d) | Zoom: %d%% | Grid: %dpx [%s] | Mode: [%s] (Keys: [V] Object, [C] Collision, [Del] Delete, [Space+LMB] Pan)",
        wx, wy, math.floor(self.zoom * 100), self.grid_size, self.grid_snap and "ON" or "OFF", self.edit_mode:upper())
    love.graphics.print(info, 24, 1054)

    if self.status_timer > 0 then
        love.graphics.setColor(0.4, 0.95, 0.5, 1)
        local sw = self.font_body and self.font_body:getWidth(self.status_text) or 100
        love.graphics.print(self.status_text, 1920 - sw - 24, 1054)
    end
end

function EditorScene:startPlaytest()
    self:saveLevel()
    local base_name = self.level_path:gsub("^levels/", ""):gsub("%.ini$", ""):gsub("/", ".")
    SceneManager.goTo(base_name)
end

-- ==============================================================================
-- INPUT EVENTS
-- ==============================================================================
function EditorScene:mousepressed(vx, vy, button, istouch, presses)
    if self.show_new_level_dialog then
        return
    end

    if self.view_mode == "browser" then
        -- Handle column selection clicks
        local col_y = 136
        local col_h = 880
        local col_w = 420
        local start_x = 40

        for col_idx, col in ipairs(self.columns_data) do
            local cx = start_x + (col_idx - 1) * (col_w + 16)
            if vx >= cx and vx <= cx + col_w and vy >= col_y + 40 and vy <= col_y + col_h then
                local item_h = 36
                local list_y = col_y + 40
                local rel_y = (vy - list_y) + (self.browser_scrolls[col_idx] or 0)
                local idx = math.floor(rel_y / item_h) + 1
                if idx >= 1 and idx <= #col.items then
                    self:selectBrowserItem(col_idx, idx)

                    -- Double click on file directly opens it
                    if button == 1 and presses and presses >= 2 then
                        local item = col.items[idx]
                        if not item.is_dir then
                            self:loadLevel(item.path)
                            self.view_mode = "workspace"
                        end
                    end
                    return
                end
            end
        end
        return
    end

    -- Workspace: Forward to floating windows first
    if WindowManager.mousepressed(vx, vy, button) then
        return
    end

    if vy < 42 or vy > 1046 then return end

    if button == 3 or (button == 1 and love.keyboard.isDown("space")) then
        self.panning = true
        self.pan_start_x = vx
        self.pan_start_y = vy
        self.pan_orig_cx = self.canvas_cx
        self.pan_orig_cy = self.canvas_cy
        return
    end

    if button == 1 then
        local wx, wy = self:screenToWorld(vx, vy)

        -- If in collision mode and current selection has custom collision boxes, test clicking collision boxes first!
        if self.edit_mode == "collision" and self.selected_element and self.selected_element.collisions and #self.selected_element.collisions > 0 then
            local el = self.selected_element
            local hit_box_idx = nil
            local is_corner_resize = false

            for b_idx = #el.collisions, 1, -1 do
                local b = el.collisions[b_idx]
                local bx = (el.x or 0) + (b.x or 0)
                local by = (el.y or 0) + (b.y or 0)
                local bw = b.w or 16
                local bh = b.h or 16

                -- Corner handle test (bottom-right 6px)
                if math.abs(wx - (bx + bw)) <= 4 and math.abs(wy - (by + bh)) <= 4 then
                    hit_box_idx = b_idx
                    is_corner_resize = true
                    break
                elseif wx >= bx and wx <= bx + bw and wy >= by and wy <= by + bh then
                    hit_box_idx = b_idx
                    break
                end
            end

            if hit_box_idx then
                self.selected_collision_idx = hit_box_idx
                local b = el.collisions[hit_box_idx]
                if is_corner_resize then
                    self.resizing_collision = true
                else
                    self.dragging_collision = true
                    self.drag_ox = wx - ((el.x or 0) + (b.x or 0))
                    self.drag_oy = wy - ((el.y or 0) + (b.y or 0))
                end
                return
            end
        end

        local clicked_idx = nil
        local els = (self.level_data and self.level_data.elements) or {}
        for i = #els, 1, -1 do
            local el = els[i]
            local is_win = (el.type == "window" or el.is_window or (el.template and el.template:match("window")))
            if not (is_win and self.show_windows == false) then
                local vw, vh = self:resolveVisual(el)
                local ex = el.x or 0
                local ey = el.y or 0
                local ew = vw
                local eh = vh
                if wx >= ex and wx <= ex + ew and wy >= ey and wy <= ey + eh then
                    clicked_idx = i
                    break
                end
            end
        end

        self:selectElement(clicked_idx)
        if self.selected_element then
            self.dragging_element = true
            self.drag_ox = wx - (self.selected_element.x or 0)
            self.drag_oy = wy - (self.selected_element.y or 0)
        end
    end
end

function EditorScene:mousemoved(vx, vy, dx, dy, istouch)
    if self.show_new_level_dialog then return end

    if self.view_mode == "workspace" then
        if WindowManager.mousemoved(vx, vy, dx, dy) then
            return
        end

        if self.panning then
            self.canvas_cx = self.pan_orig_cx + (vx - self.pan_start_x)
            self.canvas_cy = self.pan_orig_cy + (vy - self.pan_start_y)
            return
        end

        if self.resizing_collision and self.selected_element and self.selected_element.collisions then
            local b = self.selected_element.collisions[self.selected_collision_idx or 1]
            if b then
                local wx, wy = self:screenToWorld(vx, vy)
                local bx = (self.selected_element.x or 0) + (b.x or 0)
                local by = (self.selected_element.y or 0) + (b.y or 0)
                b.w = math.max(1, self:snap(wx - bx))
                b.h = math.max(1, self:snap(wy - by))
            end
            return
        end

        if self.dragging_collision and self.selected_element and self.selected_element.collisions then
            local b = self.selected_element.collisions[self.selected_collision_idx or 1]
            if b then
                local wx, wy = self:screenToWorld(vx, vy)
                local target_x = self:snap(wx - self.drag_ox) - (self.selected_element.x or 0)
                local target_y = self:snap(wy - self.drag_oy) - (self.selected_element.y or 0)
                b.x = target_x
                b.y = target_y
            end
            return
        end

        if self.dragging_element and self.selected_element then
            local wx, wy = self:screenToWorld(vx, vy)
            self.selected_element.x = self:snap(wx - self.drag_ox)
            self.selected_element.y = self:snap(wy - self.drag_oy)
        end
    end
end

function EditorScene:mousereleased(vx, vy, button, istouch, presses)
    WindowManager.mousereleased(vx, vy, button)
    self.panning = false
    self.dragging_element = false
    self.dragging_collision = false
    self.resizing_collision = false
end

function EditorScene:wheelmoved(x, y)
    if self.show_new_level_dialog then return end

    local vx, vy = Viewport.getMousePosition()

    if self.view_mode == "browser" then
        local col_y = 136
        local col_h = 880
        local col_w = 420
        local start_x = 40

        for col_idx, _ in ipairs(self.columns_data) do
            local cx = start_x + (col_idx - 1) * (col_w + 16)
            if vx >= cx and vx <= cx + col_w and vy >= col_y and vy <= col_y + col_h then
                self.browser_scrolls[col_idx] = math.max(0, (self.browser_scrolls[col_idx] or 0) - y * 36)
                return
            end
        end
        return
    end

    if WindowManager.wheelmoved(x, y) then
        return
    end

    -- Zoom canvas
    local old_zoom = self.zoom
    local new_zoom = math.max(self.min_zoom, math.min(self.max_zoom, self.zoom + y * 0.25))

    if old_zoom ~= new_zoom then
        local wx, wy = self:screenToWorld(vx, vy)
        self.zoom = new_zoom
        self.canvas_cx = vx - wx * self.zoom
        self.canvas_cy = vy - wy * self.zoom
    end
end

function EditorScene:textinput(text)
    if self.show_new_level_dialog then
        self.new_level_name = self.new_level_name .. text
    end
end

function EditorScene:keypressed(key, scancode, isrepeat)
    if self.show_new_level_dialog then
        if key == "escape" then
            self.show_new_level_dialog = false
        elseif key == "backspace" then
            self.new_level_name = self.new_level_name:sub(1, -2)
        elseif key == "return" then
            self:createAndOpenNewLevel()
        end
        return
    end

    local ctrl = love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")

    if self.view_mode == "browser" then
        if key == "escape" then
            if self.level_data then
                self.view_mode = "workspace"
            else
                SceneManager.goTo("menu")
            end
        elseif key == "return" then
            if self.selected_file_item then
                self:loadLevel(self.selected_file_item.path)
                self.view_mode = "workspace"
            end
        end
        return
    end

    -- Workspace Keys
    if ctrl and key == "s" then
        self:saveLevel()
        return
    elseif ctrl and key == "d" then
        self:duplicateSelected()
        return
    elseif key == "f5" then
        self:startPlaytest()
        return
    elseif key == "delete" or key == "backspace" then
        self:deleteSelected()
        return
    elseif key == "escape" then
        self:initBrowser()
        self.view_mode = "browser"
        return
    end

    -- Mode switching hotkeys
    if key == "v" and not ctrl then
        self.edit_mode = "object"
        self:setStatus("Mode: OBJECT (V)")
        return
    elseif key == "c" and not ctrl then
        self.edit_mode = "collision"
        self:setStatus("Mode: COLLISION (C)")
        return
    end

    -- Nudge selected element or collision box with arrows
    if self.selected_element then
        local step = love.keyboard.isDown("lshift") and self.grid_size or 1
        if self.edit_mode == "collision" and self.selected_element.collisions and #self.selected_element.collisions > 0 then
            local b = self.selected_element.collisions[self.selected_collision_idx or 1]
            if b then
                if key == "left" then b.x = (b.x or 0) - step
                elseif key == "right" then b.x = (b.x or 0) + step
                elseif key == "up" then b.y = (b.y or 0) - step
                elseif key == "down" then b.y = (b.y or 0) + step end
            end
        else
            if key == "left" then
                self.selected_element.x = (self.selected_element.x or 0) - step
            elseif key == "right" then
                self.selected_element.x = (self.selected_element.x or 0) + step
            elseif key == "up" then
                self.selected_element.y = (self.selected_element.y or 0) - step
            elseif key == "down" then
                self.selected_element.y = (self.selected_element.y or 0) + step
            end
        end
    end
end

return EditorScene.new()
