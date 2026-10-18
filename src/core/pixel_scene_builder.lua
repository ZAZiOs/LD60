local PixelScene = require("src.core.pixel_scene")

local PixelSceneBuilder = {}
PixelSceneBuilder.__index = PixelSceneBuilder

function PixelSceneBuilder.new(id)
    local self = setmetatable({}, PixelSceneBuilder)
    self.scene = PixelScene.new(id)
    return self
end

function PixelSceneBuilder:setRoomBounds(w, h)
    self.scene.room_width = w or 320
    self.scene.room_height = h or 240
    return self
end

function PixelSceneBuilder:background(path_or_color)
    self.scene:setBackground(path_or_color)
    return self
end

function PixelSceneBuilder:cursor(ini_path_or_sheet, frame)
    self.scene:setCursor(ini_path_or_sheet)
    if frame then
        self.scene.cursor_frame = frame
    end
    return self
end

function PixelSceneBuilder:addSolid(id, opts)
    opts = opts or {}
    opts.id = id
    opts.is_solid = true
    if opts.is_taskbar or id == "taskbar" or (type(id) == "string" and id:match("^taskbar")) then
        opts.is_taskbar = true
        opts.z_index = opts.z_index or 1000
        if opts.clickable == nil then
            opts.clickable = true
        end
        if opts.onClick == nil then
            opts.onClick = function() return true end
        end
    else
        opts.z_index = opts.z_index or 50
    end
    self.scene:addElement(opts)
    return self
end

function PixelSceneBuilder:addTaskbar(id, opts)
    opts = opts or {}
    opts.id = id or "taskbar"
    opts.is_solid = (opts.is_solid ~= false)
    opts.is_taskbar = true
    opts.z_index = opts.z_index or 1000
    if opts.clickable == nil then
        opts.clickable = true
    end
    if opts.onClick == nil then
        opts.onClick = function() return true end
    end
    self.scene:addElement(opts)
    return self
end

function PixelSceneBuilder:addOneWay(id, opts)
    opts = opts or {}
    opts.id = id
    opts.is_solid = true
    opts.one_way = true
    opts.z_index = opts.z_index or 50
    self.scene:addElement(opts)
    return self
end

function PixelSceneBuilder:addTab(id, opts)
    opts = opts or {}
    opts.id = id
    opts.is_tab = true
    opts.image = opts.idle or opts.image
    opts.active_image = opts.active or opts.active_image
    opts.clickable = (opts.clickable ~= false)
    if opts.require_key == nil and opts.hold_key == nil and opts.require_collision == nil and opts.requires_down == nil then
        opts.require_key = "down"
    end
    opts.z_index = opts.z_index or 1010
    self.scene:addElement(opts)
    return self
end

function PixelSceneBuilder:addWindow(id, opts)
    local PixelWindow = require("src.core.pixel_window")
    opts = opts or {}
    opts.id = id
    opts.is_window = true
    opts.z_index = opts.z_index or 100
    if opts.image then
        opts.visible = (opts.visible == true)
        opts.clickable = (opts.clickable ~= false)
        self.scene:addElement(opts)
    else
        local win = PixelWindow.new(opts)
        self.scene:addElement(win)
    end
    return self
end

function PixelSceneBuilder:addTooltip(id, opts)
    local PixelTooltip = require("src.core.pixel_tooltip")
    opts = opts or {}
    opts.id = id
    opts.z_index = opts.z_index or 2000
    local tip = PixelTooltip.new(opts)
    self.scene:addElement(tip)
    return self
end

function PixelSceneBuilder:addElement(opts)
    opts = opts or {}
    opts.z_index = opts.z_index or 0
    self.scene:addElement(opts)
    return self
end


function PixelSceneBuilder:camera(x, y)
    self.scene.camera.x = x or 0
    self.scene.camera.y = y or 0
    return self
end

function PixelSceneBuilder:spawnPlayer(opts)
    local Player = require("src.game.player")
    if opts and opts.__index == Player then
        self.scene:setPlayer(opts)
    else
        self.scene:setPlayer(Player.new(opts))
    end
    return self
end


function PixelSceneBuilder:onUpdate(fn)
    self.scene.on_update_fn = fn
    return self
end

function PixelSceneBuilder:onDraw(fn)
    self.scene.on_draw_fn = fn
    return self
end

function PixelSceneBuilder:onKey(fn)
    self.scene.on_key_fn = fn
    return self
end

function PixelSceneBuilder:onMouse(fn)
    self.scene.on_mouse_fn = fn
    return self
end

function PixelSceneBuilder:onEnter(fn)
    self.scene.on_enter_fn = fn
    return self
end

function PixelSceneBuilder:onLeave(fn)
    self.scene.on_leave_fn = fn
    return self
end

function PixelSceneBuilder:build()
    return self.scene
end

return PixelSceneBuilder
