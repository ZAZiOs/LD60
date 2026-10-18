local SpritesheetManager = require("src.core.spritesheet_manager")

local outline_shader = nil
local function getOutlineShader()
    if not outline_shader and love and love.graphics and love.graphics.newShader then
        local ok, s = pcall(love.graphics.newShader, [[
            vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
                vec4 pixel = Texel(tex, tc);
                if (pixel.a < 0.1) {
                    discard;
                }
                return vec4(1.0, 1.0, 1.0, 1.0);
            }
        ]])
        if ok then
            outline_shader = s
        end
    end
    return outline_shader
end

local OUTLINE_OFFSETS = {
    {-1, -1}, {0, -1}, {1, -1},
    {-1,  0},          {1,  0},
    {-1,  1}, {0,  1}, {1,  1}
}

local PixelScene = {}
PixelScene.__index = PixelScene

function PixelScene.new(id)
    local self = setmetatable({}, PixelScene)

    self.id = id or "pixel_scene"
    self.bg_image = nil
    self.bg_color = nil

    self.elements = {}
    self.elements_by_id = {}

    self.cursor_sheet = nil
    self.cursor_frame = "cursor"
    self.show_cursor = true

    self.mouse_gx = 0
    self.mouse_gy = 0
    self.mouse_inside = false

    self.camera = { x = 0, y = 0 }
    self.player = nil

    self.current_interactable = nil
    self.current_hovered = nil

    self.on_update_fn = nil
    self.on_draw_fn = nil
    self.on_key_fn = nil
    self.on_mouse_fn = nil

    self.room_width = 320
    self.room_height = 240

    return self
end

function PixelScene:setPlayer(player)
    self.player = player
    return self
end


function PixelScene:setBackground(path_or_color)
    if type(path_or_color) == "string" then
        if love and love.filesystem and love.filesystem.getInfo(path_or_color) then
            local ok, img = pcall(love.graphics.newImage, path_or_color)
            if ok and img then
                img:setFilter("nearest", "nearest")
                self.bg_image = img
            end
        end
    elseif type(path_or_color) == "table" then
        self.bg_color = path_or_color
    elseif type(path_or_color) == "userdata" then
        path_or_color:setFilter("nearest", "nearest")
        self.bg_image = path_or_color
    end
    return self
end

function PixelScene:setCursor(ini_path_or_sheet)
    if type(ini_path_or_sheet) == "string" then
        self.cursor_sheet = SpritesheetManager.getSheet(ini_path_or_sheet)
    elseif type(ini_path_or_sheet) == "table" then
        self.cursor_sheet = ini_path_or_sheet
    end
    return self
end

function PixelScene:addElement(elem)
    if not elem or not elem.id then return self end

    if type(elem.image) == "string" and love and love.filesystem and love.filesystem.getInfo(elem.image) then
        local ok, img = pcall(love.graphics.newImage, elem.image)
        if ok and img then
            img:setFilter("nearest", "nearest")
            elem.img_obj = img
        end
    end

    if type(elem.active_image) == "string" and love and love.filesystem and love.filesystem.getInfo(elem.active_image) then
        local ok, img = pcall(love.graphics.newImage, elem.active_image)
        if ok and img then
            img:setFilter("nearest", "nearest")
            elem.active_img_obj = img
        end
    end


    elem.visible = (elem.visible ~= false)
    elem.x = elem.x or 0
    elem.y = elem.y or 0
    elem.w = elem.w or (elem.img_obj and elem.img_obj:getWidth()) or 0
    elem.h = elem.h or (elem.img_obj and elem.img_obj:getHeight()) or 0
    elem.scene = self

    if not elem.getCollisionBoxes then
        elem.getCollisionBoxes = function(self)
            if self.is_taskbar or self.id == "taskbar" then
                local rw = (self.scene and self.scene.room_width) or 320
                local rh = (self.scene and self.scene.room_height) or 240
                return { {
                    x = 0,
                    y = self.y or (rh - 16),
                    w = rw,
                    h = self.h or 16,
                    one_way = false,
                    is_one_way = false,
                    top_only = false
                } }
            elseif self.collisions and #self.collisions > 0 then
                local cam_x = (self.scene and self.scene.camera and self.scene.camera.x) or 0
                local cam_y = (self.scene and self.scene.camera and self.scene.camera.y) or 0
                local base_x = self.fixed and (self.x + cam_x) or self.x
                local base_y = self.fixed and (self.y + cam_y) or self.y
                local boxes = {}
                for _, c in ipairs(self.collisions) do
                    local is_rel = (c.relative ~= false and c.is_relative ~= false and not c.absolute)
                    local cx = c.x or c[1] or 0
                    local cy = c.y or c[2] or 0
                    local cw = c.w or c[3] or self.w
                    local ch = c.h or c[4] or self.h
                    local bx = is_rel and (base_x + cx) or cx
                    local by = is_rel and (base_y + cy) or cy
                    local one_way = (c.one_way == true or c.top_only == true or c.is_one_way == true or self.is_one_way == true or self.one_way == true or self.top_only == true)
                    table.insert(boxes, {
                        x = bx,
                        y = by,
                        w = cw,
                        h = ch,
                        one_way = one_way,
                        is_one_way = one_way,
                        top_only = one_way
                    })
                end
                return boxes
            else
                local cam_x = (self.scene and self.scene.camera and self.scene.camera.x) or 0
                local cam_y = (self.scene and self.scene.camera and self.scene.camera.y) or 0
                local base_x = self.fixed and (self.x + cam_x) or self.x
                local base_y = self.fixed and (self.y + cam_y) or self.y
                local one_way = (self.is_one_way == true or self.one_way == true or self.top_only == true)
                return { {
                    x = base_x,
                    y = base_y,
                    w = self.w,
                    h = self.h,
                    one_way = one_way,
                    is_one_way = one_way,
                    top_only = one_way
                } }
            end
        end
    end

    if elem.is_window then
        elem.z_index = elem.z_index or 100
    elseif elem.is_taskbar or elem.id == "taskbar" then
        elem.is_taskbar = true
        elem.fixed = true
        elem.z_index = elem.z_index or 1000
        if elem.clickable == nil then elem.clickable = true end
        if elem.onClick == nil then elem.onClick = function() return true end end
    elseif elem.is_tab then
        elem.is_tab = true
        elem.fixed = true
        elem.z_index = elem.z_index or 1010
    end

    elem.z_index = elem.z_index or 0
    table.insert(self.elements, elem)
    self.elements_by_id[elem.id] = elem
    self:_sortElements()

    return self
end

function PixelScene:_sortElements()
    table.sort(self.elements, function(a, b)
        return (a.z_index or 0) < (b.z_index or 0)
    end)
end

local WINDOW_Z_MIN = 100
local WINDOW_Z_MAX = 899

function PixelScene:bringToFront(id)
    local el = self.elements_by_id[id]
    if not el then return end
    self.window_z = math.max(self.window_z or WINDOW_Z_MIN, (el.z_index or WINDOW_Z_MIN)) + 1
    if self.window_z >= WINDOW_Z_MAX then
        local windows = {}
        for _, e in ipairs(self.elements) do
            if e.is_window then
                table.insert(windows, e)
            end
        end
        table.sort(windows, function(a, b) return (a.z_index or 0) < (b.z_index or 0) end)
        for idx, win in ipairs(windows) do
            win.z_index = WINDOW_Z_MIN + idx
        end
        self.window_z = WINDOW_Z_MIN + #windows + 1
    end
    el.z_index = self.window_z
    self:_sortElements()
end

function PixelScene:getElement(id)
    return self.elements_by_id[id]
end

function PixelScene:setElementVisible(id, visible)
    local el = self.elements_by_id[id]
    if el then
        el.visible = visible
        if visible and el.is_window then
            self:bringToFront(id)
        end
    end
end

function PixelScene:toggleElement(id)
    local el = self.elements_by_id[id]
    if el then
        el.visible = not el.visible
        if el.visible and el.is_window then
            self:bringToFront(id)
        end
    end
end

function PixelScene:setElementActive(id, active)
    local el = self.elements_by_id[id]
    if el then
        el.is_active = active
    end
end

PixelScene.setVisible = PixelScene.setElementVisible
PixelScene.setActive = PixelScene.setElementActive


function PixelScene:enter(...)
    if self.on_enter_fn then
        self:on_enter_fn(...)
    end
end

function PixelScene:leave()
    if self.on_leave_fn then
        self:on_leave_fn()
    end
    if love and love.mouse then
        love.mouse.setVisible(true)
    end
end

local function elementCanInteract(el, player)
    if not el or not el.visible then return false end
    if el.interactable == false then return false end
    if el.canInteract ~= nil then
        if type(el.canInteract) == "function" then
            local ok, can = pcall(el.canInteract, el, player)
            if not ok or not can then
                return false
            end
        elseif not el.canInteract then
            return false
        end
    end
    return true
end

function PixelScene:getHoveredElement()
    if not self.mouse_inside then return nil end
    local cam_x = (self.camera and self.camera.x) or 0
    local cam_y = (self.camera and self.camera.y) or 0

    for i = #self.elements, 1, -1 do
        local el = self.elements[i]
        if el.visible and el.clickable then
            local mx = el.fixed and self.mouse_gx or (self.mouse_gx + cam_x)
            local my = el.fixed and self.mouse_gy or (self.mouse_gy + cam_y)
            if mx >= el.x and mx < el.x + el.w and my >= el.y and my < el.y + el.h then
                if el.is_taskbar or el.is_window or not elementCanInteract(el, self.player) then
                    return nil
                end
                return el
            end
        end
    end
    return nil
end

function PixelScene:getInteractableElement()
    if not self.player then return nil end
    local cam_x = (self.camera and self.camera.x) or 0
    local cam_y = (self.camera and self.camera.y) or 0
    local best_el = nil
    local best_dist = math.huge
    for _, el in ipairs(self.elements) do
        if el.visible and not el.is_window and not el.is_taskbar and elementCanInteract(el, self.player) and (el.onInteract or el.interactable or (el.clickable and el.onClick)) then
            if self.player:canInteractWith(el) then
                local el_world_x = el.fixed and (el.x + cam_x) or el.x
                local el_world_y = el.fixed and (el.y + cam_y) or el.y
                local ecx = el_world_x + el.w / 2
                local ecy = el_world_y + el.h / 2
                local pcx = self.player.x
                local pcy = self.player.y - (self.player.box_h or 24) / 2
                local dist = (ecx - pcx) * (ecx - pcx) + (ecy - pcy) * (ecy - pcy)
                if dist < best_dist then
                    best_dist = dist
                    best_el = el
                end
            end
        end
    end
    return best_el
end

function PixelScene:canInteractWith(el)
    if not elementCanInteract(el, self.player) then return false end
    return self:getInteractableElement() == el
end

function PixelScene:updateCamera(dt)
    if not self.player or not self.camera then return end

    local cam_w = 320
    local cam_h = 240
    
    -- Deadzone settings
    local deadzone_w = self.camera_deadzone_w or 100
    local deadzone_h = self.camera_deadzone_h or 60
    local deadzone_x = self.camera.x + (cam_w - deadzone_w) / 2
    local deadzone_y = self.camera.y + (cam_h - deadzone_h) / 2
    
    local targetX = self.camera.x
    local targetY = self.camera.y
    
    if self.player.x < deadzone_x then
        targetX = self.player.x - (cam_w - deadzone_w) / 2
    elseif self.player.x > deadzone_x + deadzone_w then
        targetX = self.player.x - (cam_w + deadzone_w) / 2
    end
    
    if self.player.y < deadzone_y then
        targetY = self.player.y - (cam_h - deadzone_h) / 2
    elseif self.player.y > deadzone_y + deadzone_h then
        targetY = self.player.y - (cam_h + deadzone_h) / 2
    end
    
    local max_cam_x = math.max(0, self.room_width - cam_w)
    local max_cam_y = math.max(0, self.room_height - cam_h)
    
    targetX = math.max(0, math.min(targetX, max_cam_x))
    targetY = math.max(0, math.min(targetY, max_cam_y))
    
    -- Smooth exponential follow
    local speed = self.camera_speed or 12
    local t = 1 - math.exp(-speed * dt)
    
    self.camera.x = self.camera.x + (targetX - self.camera.x) * t
    self.camera.y = self.camera.y + (targetY - self.camera.y) * t
    
    self.camera.x = math.floor(self.camera.x + 0.5)
    self.camera.y = math.floor(self.camera.y + 0.5)

    if self.cam_shake_timer and self.cam_shake_timer > 0 then
        self.cam_shake_timer = math.max(0, self.cam_shake_timer - dt)
        local mag = self.cam_shake_mag or 2
        local shake_x = math.floor((math.random() * 2 - 1) * mag + 0.5)
        local shake_y = math.floor((math.random() * 2 - 1) * mag + 0.5)
        self.camera.x = self.camera.x + shake_x
        self.camera.y = self.camera.y + shake_y
    end
end

function PixelScene:shakeCamera(duration, magnitude)
    self.cam_shake_timer = duration or 0.3
    self.cam_shake_mag = magnitude or 3
end

function PixelScene:update(dt)
    if self.on_update_fn then
        self:on_update_fn(dt)
    end

    self:updateCamera(dt)

    for _, el in ipairs(self.elements) do
        if el.update then
            el:update(dt)
        end
    end

    if self.player then
        self.player:update(dt, self)
    end

    self.current_hovered = self:getHoveredElement()
    self.current_interactable = self:getInteractableElement()
end

function PixelScene:drawElement(el, shader)
    local current_img = (el.is_active and el.active_img_obj) or el.img_obj
    if self:canInteractWith(el) then
        if current_img and shader then
            love.graphics.setShader(shader)
            love.graphics.setColor(1, 1, 1, 1)
            for i = 1, 8 do
                local off = OUTLINE_OFFSETS[i]
                love.graphics.draw(current_img, el.x + off[1], el.y + off[2])
            end
            love.graphics.setShader()
        elseif el.w and el.h and el.w > 0 and el.h > 0 then
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.rectangle("fill", el.x - 1, el.y - 1, el.w + 2, 1)
            love.graphics.rectangle("fill", el.x - 1, el.y + el.h, el.w + 2, 1)
            love.graphics.rectangle("fill", el.x - 1, el.y, 1, el.h)
            love.graphics.rectangle("fill", el.x + el.w, el.y, 1, el.h)
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
    if current_img then
        love.graphics.draw(current_img, el.x, el.y)
    end
    if el.color then
        love.graphics.setColor(el.color[1], el.color[2], el.color[3], el.color[4] or 1)
        if el.hollow then
            local line_width = 5
            love.graphics.rectangle("fill", el.x, el.y, el.w, line_width) -- top
            love.graphics.rectangle("fill", el.x, el.y + el.h - line_width, el.w, line_width) -- bottom
            love.graphics.rectangle("fill", el.x, el.y, line_width, el.h) -- left
            love.graphics.rectangle("fill", el.x + el.w - line_width, el.y, line_width, el.h) -- right
        else
            love.graphics.rectangle("fill", el.x, el.y, el.w, el.h)
        end
        love.graphics.setColor(1, 1, 1, 1)
    end
    if el.draw then
        el:draw()
    end
end

function PixelScene:draw()
    local cam_x = (self.camera and self.camera.x) or 0
    local cam_y = (self.camera and self.camera.y) or 0

    if self.camera and (cam_x ~= 0 or cam_y ~= 0) then
        love.graphics.push()
        love.graphics.translate(-cam_x, -cam_y)
    end

    if self.bg_color then
        love.graphics.setColor(self.bg_color[1], self.bg_color[2], self.bg_color[3], self.bg_color[4] or 1)
        love.graphics.rectangle("fill", 0, 0, self.room_width or 320, self.room_height or 240)
    end

    if self.bg_image then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(self.bg_image, 0, 0)
    end

    local shader = getOutlineShader()
    for _, el in ipairs(self.elements) do
        if el.visible and not el.fixed then
            self:drawElement(el, shader)
        end
    end

    if self.on_draw_fn then
        self:on_draw_fn()
    end

    if self.player then
        self.player:draw()
    end

    if DEBUG then
        for _, el in ipairs(self.elements) do
            if el.visible and el.is_solid and not el.fixed then
                local boxes = el.getCollisionBoxes and el:getCollisionBoxes() or { { x = el.x, y = el.y, w = el.w, h = el.h } }
                for _, b in ipairs(boxes) do
                    if b.one_way then
                        love.graphics.setColor(0.2, 0.8, 1.0, 0.5)
                        love.graphics.rectangle("line", b.x + 0.5, b.y + 0.5, b.w - 1, b.h - 1)
                        love.graphics.setColor(1, 1, 0, 0.9)
                        love.graphics.line(b.x, b.y + 0.5, b.x + b.w, b.y + 0.5)
                    else
                        love.graphics.setColor(0.1, 1, 0.2, 0.75)
                        love.graphics.rectangle("line", b.x + 0.5, b.y + 0.5, b.w - 1, b.h - 1)
                    end
                end
            end
        end
        if self.player then
            love.graphics.setColor(1, 0.2, 0.2, 0.75)
            local pw = self.player.box_w or 10
            local ph = self.player.box_h or 24
            love.graphics.rectangle("line", math.floor(self.player.x - pw / 2) + 0.5, math.floor(self.player.y - ph) + 0.5, pw - 1, ph - 1)
        end
        love.graphics.setColor(1, 1, 1, 1)
    end

    if self.camera and (cam_x ~= 0 or cam_y ~= 0) then
        love.graphics.pop()
    end

    -- Fixed elements (HUD, taskbar at fixed bottom: 0, tabs)
    for _, el in ipairs(self.elements) do
        if el.visible and el.fixed then
            self:drawElement(el, shader)
        end
    end

    if self.show_cursor and self.mouse_inside and self.cursor_sheet then
        love.graphics.setColor(1, 1, 1, 1)
        self.cursor_sheet:drawFrame(self.cursor_frame or "cursor", self.mouse_gx, self.mouse_gy, 0, 1, 1, 0, 0)
    end
end

function PixelScene:mousepressed(gx, gy, button, istouch, presses)
    local cam_x = (self.camera and self.camera.x) or 0
    local cam_y = (self.camera and self.camera.y) or 0

    for i = #self.elements, 1, -1 do
        local el = self.elements[i]
        if el.visible and el.clickable then
            local mx = el.fixed and gx or (gx + cam_x)
            local my = el.fixed and gy or (gy + cam_y)
            if mx >= el.x and mx < el.x + el.w and my >= el.y and my < el.y + el.h then
                if el.is_window then
                    self:bringToFront(el.id)
                end
                if el.mousepressed then
                    local handled = el:mousepressed(mx, my, button)
                    if handled ~= false then
                        return true
                    end
                elseif el.onClick then
                    el:onClick(button)
                    return true
                end
            end
        end
    end

    if self.on_mouse_fn then
        self:on_mouse_fn("press", gx, gy, button)
    end
end

function PixelScene:mousereleased(gx, gy, button, istouch, presses)
    local cam_x = (self.camera and self.camera.x) or 0
    local cam_y = (self.camera and self.camera.y) or 0

    for i = #self.elements, 1, -1 do
        local el = self.elements[i]
        if el.visible and el.mousereleased then
            local mx = el.fixed and gx or (gx + cam_x)
            local my = el.fixed and gy or (gy + cam_y)
            el:mousereleased(mx, my, button)
        end
    end

    if self.on_mouse_fn then
        self:on_mouse_fn("release", gx, gy, button)
    end
end

function PixelScene:mousemoved(gx, gy, gdx, gdy, istouch, inside)
    self.mouse_gx = gx
    self.mouse_gy = gy
    self.mouse_inside = inside

    if love and love.mouse then
        love.mouse.setVisible(not inside)
    end

    local cam_x = (self.camera and self.camera.x) or 0
    local cam_y = (self.camera and self.camera.y) or 0

    for i = #self.elements, 1, -1 do
        local el = self.elements[i]
        if el.visible and el.mousemoved then
            local mx = el.fixed and gx or (gx + cam_x)
            local my = el.fixed and gy or (gy + cam_y)
            el:mousemoved(mx, my, gdx, gdy)
        end
    end

    if self.on_mouse_fn then
        self:on_mouse_fn("move", gx, gy, nil, gdx, gdy)
    end
end

function PixelScene:wheelmoved(x, y)
    local cam_x = (self.camera and self.camera.x) or 0
    local cam_y = (self.camera and self.camera.y) or 0

    if self.mouse_inside then
        for i = #self.elements, 1, -1 do
            local el = self.elements[i]
            if el.visible and el.wheelmoved then
                local mx = el.fixed and self.mouse_gx or (self.mouse_gx + cam_x)
                local my = el.fixed and self.mouse_gy or (self.mouse_gy + cam_y)
                if mx >= el.x and mx < el.x + el.w and my >= el.y and my < el.y + el.h then
                    local handled = el:wheelmoved(x, y)
                    if handled ~= false then
                        return
                    end
                end
            end
        end
    end

    if self.on_mouse_fn then
        self:on_mouse_fn("wheel", self.mouse_gx, self.mouse_gy, nil, x, y)
    end
end

function PixelScene:keypressed(key, scancode, isrepeat)
    if self.player then
        self.player:keypressed(key, self)
    end
    if self.on_key_fn then
        self:on_key_fn("press", key, scancode, isrepeat)
    end
end


function PixelScene:keyreleased(key, scancode)
    if self.on_key_fn then
        self:on_key_fn("release", key, scancode)
    end
end

return PixelScene
