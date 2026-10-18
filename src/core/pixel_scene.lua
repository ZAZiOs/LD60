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

function PixelScene:bringToFront(id)
    local el = self.elements_by_id[id]
    if not el then return end
    self.window_z = math.max(self.window_z or 10, (el.z_index or 10)) + 1
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

function PixelScene:getHoveredElement()
    if not self.mouse_inside then return nil end
    for i = #self.elements, 1, -1 do
        local el = self.elements[i]
        if el.visible and el.clickable and not el.is_window then
            if self.mouse_gx >= el.x and self.mouse_gx < el.x + el.w and self.mouse_gy >= el.y and self.mouse_gy < el.y + el.h then
                return el
            end
        end
    end
    return nil
end

function PixelScene:getInteractableElement()
    if not self.player then return nil end
    local best_el = nil
    local best_dist = math.huge
    for _, el in ipairs(self.elements) do
        if el.visible and not el.is_window and (el.onInteract or el.interactable or (el.clickable and el.onClick)) then
            if self.player:canInteractWith(el) then
                local ecx = el.x + el.w / 2
                local ecy = el.y + el.h / 2
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
    if not el or not el.visible then return false end
    return self:getInteractableElement() == el
end

function PixelScene:updateCamera(dt)
    if not self.player or not self.camera then return end

    local cam_w = 320
    local cam_h = 240
    
    -- Deadzone settings
    local deadzone_w = 120
    local deadzone_h = 60
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
    
    -- Smoothing
    local speed = 1000
    local t = 1 - math.exp(-speed * dt)
    
    self.camera.x = self.camera.x + (targetX - self.camera.x) * t
    self.camera.y = self.camera.y + (targetY - self.camera.y) * t
    
    self.camera.x = math.floor(self.camera.x)
    self.camera.y = math.floor(self.camera.y)
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

function PixelScene:draw()
    if self.camera and (self.camera.x ~= 0 or self.camera.y ~= 0) then
        love.graphics.push()
        love.graphics.translate(-self.camera.x, -self.camera.y)
    end

    if self.bg_color then
        love.graphics.setColor(self.bg_color[1], self.bg_color[2], self.bg_color[3], self.bg_color[4] or 1)
        love.graphics.rectangle("fill", 0, 0, 320, 240)
    end

    if self.bg_image then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(self.bg_image, 0, 0)
    end

    local shader = getOutlineShader()
    for _, el in ipairs(self.elements) do
        if el.visible then
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
            if el.draw then
                el:draw()
            end
        end
    end

    if self.on_draw_fn then
        self:on_draw_fn()
    end

    if self.player then
        self.player:draw()
    end

    if self.camera and (self.camera.x ~= 0 or self.camera.y ~= 0) then
        love.graphics.pop()
    end

    if self.show_cursor and self.mouse_inside and self.cursor_sheet then
        love.graphics.setColor(1, 1, 1, 1)
        self.cursor_sheet:drawFrame(self.cursor_frame or "cursor", self.mouse_gx, self.mouse_gy, 0, 1, 1, 0, 0)
    end
end

function PixelScene:mousepressed(gx, gy, button, istouch, presses)
    for i = #self.elements, 1, -1 do
        local el = self.elements[i]
        if el.visible and el.clickable then
            if gx >= el.x and gx < el.x + el.w and gy >= el.y and gy < el.y + el.h then
                if el.is_window then
                    self:bringToFront(el.id)
                end
                if el.mousepressed then
                    local handled = el:mousepressed(gx, gy, button)
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
    for i = #self.elements, 1, -1 do
        local el = self.elements[i]
        if el.visible and el.mousereleased then
            el:mousereleased(gx, gy, button)
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

    for i = #self.elements, 1, -1 do
        local el = self.elements[i]
        if el.visible and el.mousemoved then
            el:mousemoved(gx, gy, gdx, gdy)
        end
    end

    if self.on_mouse_fn then
        self:on_mouse_fn("move", gx, gy, nil, gdx, gdy)
    end
end

function PixelScene:wheelmoved(x, y)
    if self.mouse_inside then
        for i = #self.elements, 1, -1 do
            local el = self.elements[i]
            if el.visible and el.wheelmoved then
                if self.mouse_gx >= el.x and self.mouse_gx < el.x + el.w and self.mouse_gy >= el.y and self.mouse_gy < el.y + el.h then
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
