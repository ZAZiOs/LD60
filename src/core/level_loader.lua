local PixelSceneBuilder = require("src.core.pixel_scene_builder")
local PixelScreen = require("src.core.pixel_screen")
local GameScene = require("src.core.game_scene")
local Effects = require("src.core.effects")
local AudioManager = require("src.core.audio_manager")
local SceneManager = require("src.core.scene_manager")
local LevelParser = require("src.core.level_parser")

local LevelLoader = {}

LevelLoader.shaders = {
    crt = function(s)
        Effects.drawCrt(s.canvas, s.x, s.y, s.scale_x, s.scale_y)
    end,
    ascii_crt = function(s)
        Effects.drawAsciiCrt(s.canvas, s.x, s.y, s.scale_x, s.scale_y)
    end,
    none = function(s)
        s:draw()
    end
}

local function trim(s)
    if not s then return "" end
    return s:match("^%s*(.-)%s*$") or ""
end

local function build_action_fn(action_str, el_id)
    local action, param_str = action_str:match("^([%w_]+)%s*:%s*(.*)$")
    action = action and action:lower() or action_str:lower()
    param_str = param_str or ""

    local params = {}
    for p in param_str:gmatch("([^,]+)") do
        table.insert(params, trim(p))
    end

    if action == "goto" or action == "scene" then
        local target_scene = params[1] or "menu"
        local fade_time = tonumber(params[2]) or 0.4
        return function(self)
            SceneManager.crossFade(target_scene, fade_time)
        end
    elseif action == "toggle_window" or action == "toggle" then
        local win_id = params[1] or ""
        return function(self)
            if self.scene then
                self.scene:toggleElement(win_id)
                local win = self.scene:getElement(win_id)
                self.scene:setElementActive(self.id or el_id, win and win.visible)
            end
        end
    elseif action == "sfx" then
        local sound = params[1]
        local vol = tonumber(params[2]) or 1.0
        return function(self)
            if AudioManager and AudioManager.sfxPlay then
                pcall(AudioManager.sfxPlay, sound, vol)
            end
        end
    end

    return nil
end

function LevelLoader.loadFromFile(file_path, custom_logic)
    local level_data = LevelParser.parse(file_path)
    return LevelLoader.build(level_data, custom_logic)
end

function LevelLoader.build(data, custom_logic)
    local room = data.room or {}
    local parent = data.parent or {}
    local room_id = room.id or "level"

    local b = PixelSceneBuilder.new(room_id)
        :setRoomBounds(room.w or 320, room.h or 240)

    if room.bg then
        b:background(room.bg, room.bg_repeat)
    end

    if room.cursor then
        b:cursor(room.cursor)
    end

    if room.spawn then
        b:spawnPlayer(room.spawn)
    end

    local script_bindings = {}

    for _, el in ipairs(data.elements or {}) do
        if el.on_interact and type(el.on_interact) == "string" then
            local act_fn = build_action_fn(el.on_interact, el.id)
            if act_fn then
                el.onInteract = act_fn
                if el.type == "tab" and not el.onClick then
                    el.onClick = function(self) act_fn(self) end
                end
            end
        end

        if el.script and type(el.script) == "string" then
            table.insert(script_bindings, { id = el.id, script = el.script })
        end

        local t = el.type and el.type:lower() or "element"

        if t == "taskbar" then
            b:addTaskbar(el.id, el)
        elseif t == "solid" then
            b:addSolid(el.id, el)
        elseif t == "oneway" then
            b:addOneWay(el.id, el)
        elseif t == "window" then
            b:addWindow(el.id, el)
        elseif t == "tab" then
            b:addTab(el.id, el)
        elseif t == "tooltip" then
            b:addTooltip(el.id, el)
        elseif t == "bookshelf" then
            b:addBookshelf(el.id, el)
        elseif t == "door" then
            if not el.onInteract and el.target then
                el.onInteract = function(self)
                    SceneManager.crossFade(el.target, el.fade or 0.4)
                end
            end
            el.clickable = (el.clickable ~= false)
            el.interactable = true
            b:addElement(el)
        else
            b:addElement(el)
        end
    end

    local room_logic = custom_logic
    if not room_logic and room.script then
        local ok, mod = pcall(require, room.script)
        if ok then
            room_logic = mod
        else
            print(string.format("[LevelLoader] Warning: Failed to load room script '%s': %s", tostring(room.script), tostring(mod)))
        end
    end

    if room_logic and room_logic.onKey then
        b:onKey(function(sc, action, key, scancode, isrepeat)
            room_logic.onKey(sc, action, key, scancode, isrepeat)
        end)
    end

    if room_logic and room_logic.onDraw then
        b:onDraw(function(sc)
            room_logic.onDraw(sc)
        end)
    end

    if room_logic and room_logic.onMouse then
        b:onMouse(function(sc, action, gx, gy, button)
            room_logic.onMouse(sc, action, gx, gy, button)
        end)
    end

    local desktop = b:build()

    for _, binding in ipairs(script_bindings) do
        local ok, mod = pcall(require, binding.script)
        if ok then
            local spawned_el = desktop:getElement(binding.id)
            if spawned_el then
                if type(mod) == "function" then
                    mod(spawned_el, desktop)
                elseif type(mod) == "table" and mod.setup then
                    mod.setup(spawned_el, desktop)
                end
            end
        else
            print(string.format("[LevelLoader] Warning: Failed to load element script '%s': %s", tostring(binding.script), tostring(mod)))
        end
    end

    local is_fullscreen = (parent.fullscreen == true) or (parent.bg == nil and parent.screen == nil)
    local screen_x, screen_y, screen_w, screen_h
    if is_fullscreen then
        screen_x, screen_y, screen_w, screen_h = 0, 0, 1920, 1080
    else
        local screen_cfg = parent.screen or {}
        screen_x = screen_cfg.x or 320
        screen_y = screen_cfg.y or 60
        screen_w = screen_cfg.w or 1280
        screen_h = screen_cfg.h or 960
    end

    local cam_w = room.camera_w or room.w or 320
    local cam_h = room.camera_h or room.h or 240

    local screen = PixelScreen.new({
        game = desktop,
        game_width = cam_w,
        game_height = cam_h,
        x = screen_x,
        y = screen_y,
        w = screen_w,
        h = screen_h
    })

    local shader_name = (parent.shaders and parent.shaders[1]) or "crt"
    local default_draw_fn = LevelLoader.shaders[shader_name] or LevelLoader.shaders.crt
    local draw_fn = function(s)
        if room_logic and room_logic.screen_draw_fn then
            room_logic.screen_draw_fn(s, default_draw_fn)
        else
            default_draw_fn(s)
        end
    end

    local scene = GameScene.new({
        bg = parent.bg,
        screen = screen,
        screen_draw_fn = draw_fn,
        on_bg_click = function(self, vx, vy, button)
            if room_logic and room_logic.on_bg_click then
                room_logic.on_bg_click(desktop, self, vx, vy, button)
            end
        end,
        enter = function(self, ...)
            local mus = parent.music
            if mus and mus.track and mus.track ~= "" then
                AudioManager.musFadeTo(mus.track, mus.volume or 0.8, mus.fade or 0.5, mus.layer)
            end
            if room_logic and room_logic.enter then
                room_logic.enter(desktop, self, ...)
            end
        end,
        leave = function(self)
            if parent.music then
                AudioManager.musStop(0.5)
            end
            if room_logic and room_logic.leave then
                room_logic.leave(desktop, self)
            end
        end,
        update = function(self, dt)
            if room_logic and room_logic.update then
                room_logic.update(desktop, dt, self)
            end
        end
    })

    scene.desktop = desktop
    scene.pixel_screen = screen
    scene.level_data = data

    if room_logic and room_logic.setup then
        room_logic.setup(desktop, scene)
    end

    return scene
end

LevelLoader.registered_levels = {}

function LevelLoader.registerAll(base_dir)
    base_dir = base_dir or "levels"
    local registered = {}

    local function scan(dir, prefix)
        if not (love and love.filesystem and love.filesystem.getDirectoryItems) then return end
        local items = love.filesystem.getDirectoryItems(dir)
        table.sort(items)
        for _, item in ipairs(items) do
            local path = dir .. "/" .. item
            local info = love.filesystem.getInfo(path)
            if info then
                if info.type == "directory" then
                    local next_prefix = (prefix and prefix ~= "") and (prefix .. "." .. item) or item
                    scan(path, next_prefix)
                elseif info.type == "file" and item:match("%.ini$") then
                    local base_name = item:gsub("%.ini$", "")
                    local scene_name = (prefix and prefix ~= "") and (prefix .. "." .. base_name) or base_name

                    SceneManager.register(scene_name, function()
                        return LevelLoader.loadFromFile(path)
                    end)
                    table.insert(registered, scene_name)

                    -- Also register short name (e.g. "level0", "level1") so transitions to "level0" seamlessly use the INI
                    if base_name ~= scene_name then
                        SceneManager.register(base_name, function()
                            return LevelLoader.loadFromFile(path)
                        end)
                    end
                end
            end
        end
    end

    if love and love.filesystem and love.filesystem.getInfo(base_dir) then
        scan(base_dir, "")
    end

    LevelLoader.registered_levels = registered
    return registered
end

return LevelLoader
