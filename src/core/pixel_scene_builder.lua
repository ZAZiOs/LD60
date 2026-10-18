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
    if opts.speed and opts.max_delta_x then
        local spawn_x = opts.spawn_x or opts.x or 0
        local spawn_y = opts.spawn_y or opts.y or 0
        local end_x = spawn_x + math.abs(opts.max_delta_x)
        local direction = opts.direction or 1
        opts.x, opts.y = spawn_x + opts.max_delta_x / 2, spawn_y
        opts.update = function(self, dt)
            self.x = self.x + math.abs(opts.speed) * direction * dt
            if self.x >= end_x then
                self.x = end_x
                direction = -1
            elseif self.x <= spawn_x then
                self.x = spawn_x
                direction = 1
            end
        end
    end
    if opts.is_taskbar or id == "taskbar" or (type(id) == "string" and id:match("^taskbar")) then
        opts.is_taskbar = true
        opts.fixed = (opts.fixed ~= false)
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
    opts.fixed = (opts.fixed ~= false)
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
    opts.fixed = (opts.fixed ~= false)
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
    opts.scene = self.scene
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

function PixelSceneBuilder:addBookshelf(id, opts)
    opts = opts or {}
    if type(id) == "table" and opts == nil then
        opts = id
        id = opts.id
    end
    opts.id = id or ("bookshelf_" .. tostring(math.random(1000, 9999)))
    opts.is_bookshelf = true
    opts.is_solid = false
    opts.z_index = opts.z_index or 15
    opts.clickable = false
    opts.interactable = true

    if not opts.image then
        local variants = {
            "assets/level3/bookshelf1.png",
            "assets/level3/bookshelf2.png",
            "assets/level3/bookshelf3.png"
        }
        opts.image = variants[math.random(1, #variants)]
    end
    opts.orig_image = opts.image

    opts.w = opts.w or 77
    opts.h = opts.h or 97

    opts.has_bomb = (opts.has_bomb == true)
    opts.is_exploded = false
    opts.exploding = false
    opts.explosion_timer = 0

    function opts:reset()
        self.is_exploded = false
        self.exploding = false
        self.explosion_timer = 0
        if not self.orig_image or self.orig_image:find("boom") then
            self.orig_image = "assets/level3/bookshelf1.png"
        end
        self.image = self.orig_image
        if self.orig_img_obj then
            self.img_obj = self.orig_img_obj
        else
            local ok, img = pcall(love.graphics.newImage, self.image)
            if ok and img then
                img:setFilter("nearest", "nearest")
                self.img_obj = img
                self.orig_img_obj = img
            end
        end
    end

    function opts:explode()
        if self.is_exploded then return end
        self.is_exploded = true
        self.exploding = true
        self.explosion_timer = 0.45

        self.orig_image = self.orig_image or self.image
        self.image = "assets/level3/bookshelf_boom_boom.png"
        if not self.boom_img_obj then
            local ok, img = pcall(love.graphics.newImage, self.image)
            if ok and img then
                img:setFilter("nearest", "nearest")
                self.boom_img_obj = img
            end
        end
        if self.boom_img_obj then
            self.img_obj = self.boom_img_obj
        end

        local sc = self.scene
        if sc and sc.shakeCamera then
            sc:shakeCamera(0.35, 4)
        end

        local AudioManager = require("src.core.audio_manager")
        if AudioManager and AudioManager.sfxPlay then
            AudioManager.sfxPlay("explosion", 1.0, 1.0)
        end

        local GameState = require("src.core.game_state")
        if self.has_bomb then
            local correct = GameState.get("correct_bookshelves_exploded", 0) + 1
            GameState.set("correct_bookshelves_exploded", correct)
            if sc and sc.onBombDefused then
                sc:onBombDefused(self)
            end
        else
            local wrong = GameState.get("wrong_bookshelves_exploded", 0) + 1
            GameState.set("wrong_bookshelves_exploded", wrong)
            if sc and sc.onWrongBookshelfExploded then
                sc:onWrongBookshelfExploded(self, wrong)
            end
        end
    end

    function opts:canInteract(player)
        if self.is_exploded then return false end
        local is_down = false
        if player and player.isHoldingKey then
            is_down = player:isHoldingKey("down")
        else
            is_down = love.keyboard.isDown("down") or love.keyboard.isDown("s")
        end
        if is_down then
            return false
        end
        return true
    end

    function opts:onInteract(down_held, player)
        local is_down = down_held
        if is_down == nil then
            if player and player.isHoldingKey then
                is_down = player:isHoldingKey("down")
            else
                is_down = love.keyboard.isDown("down") or love.keyboard.isDown("s")
            end
        end
        if is_down then
            return
        end
        self:explode()
    end

    function opts:update(dt)
        if self.exploding then
            self.explosion_timer = self.explosion_timer - dt
            if self.explosion_timer <= 0 then
                self.exploding = false
            end
        end
    end

    function opts:draw()
        if self.exploding then
            if not self.explosion_img then
                local ok, img = pcall(love.graphics.newImage, "assets/level3/explosion.png")
                if ok and img then
                    img:setFilter("nearest", "nearest")
                    self.explosion_img = img
                end
            end
            if self.explosion_img then
                local ew, eh = self.explosion_img:getDimensions()
                local ex = self.x + (self.w - ew) / 2
                local ey = self.y + (self.h - eh) / 2
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.draw(self.explosion_img, ex, ey)
            end
        end
    end

    self.scene:addElement(opts)
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
