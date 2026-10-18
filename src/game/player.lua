local SpritesheetManager = require("src.core.spritesheet_manager")

local function getElementBoxes(el)
    if el.getCollisionBoxes then
        return el:getCollisionBoxes()
    elseif el.collisions and #el.collisions > 0 then
        local boxes = {}
        for _, c in ipairs(el.collisions) do
            local is_rel = (c.relative ~= false and c.is_relative ~= false and not c.absolute)
            local cx = c.x or c[1] or 0
            local cy = c.y or c[2] or 0
            local cw = c.w or c[3] or el.w
            local ch = c.h or c[4] or el.h
            local bx = is_rel and (el.x + cx) or cx
            local by = is_rel and (el.y + cy) or cy
            local one_way = (c.one_way == true or c.top_only == true or c.is_one_way == true or el.is_one_way == true or el.one_way == true or el.top_only == true)
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
        local one_way = (el.is_one_way == true or el.one_way == true or el.top_only == true)
        return { {
            x = el.x,
            y = el.y,
            w = el.w,
            h = el.h,
            one_way = one_way,
            is_one_way = one_way,
            top_only = one_way
        } }
    end
end

local Player = {}
Player.__index = Player

function Player.new(opts)
    opts = opts or {}
    local self = setmetatable({}, Player)

    self.x = opts.x or 40
    self.y = opts.y or 224
    self.vx = 0
    self.vy = 0

    self.speed = opts.speed or 95
    self.jump_force = opts.jump_force or -225

    self.gravity_held = opts.gravity_held or 580
    self.gravity_fall = opts.gravity_fall or 700
    self.gravity_cut = opts.gravity_cut or 1100
    self.gravity_apex = opts.gravity_apex or 420
    self.max_fall = opts.max_fall or 320



    self.coyote_timer = 0
    self.coyote_time = 0.08
    self.jump_buffer_timer = 0
    self.jump_buffer_time = 0.08

    self.box_w = 14
    self.box_h = 24

    self.facing = 1
    self.is_grounded = false

    self.scale_x = 1
    self.scale_y = 1
    self.was_crouching = false

    local ini_path = opts.sheet or "assets/rage/rage_sh.ini"
    self.anim = SpritesheetManager.createAnimation(ini_path, "idle")

    return self
end

function Player:jump()
    self.vy = self.jump_force
    self.is_grounded = false
    self.coyote_timer = 0
    self.jump_buffer_timer = 0
    self.scale_x = 0.78
    self.scale_y = 1.3
end

function Player:getHitbox()
    return {
        x = self.x - self.box_w / 2,
        y = self.y - self.box_h,
        w = self.box_w,
        h = self.box_h
    }
end

function Player:update(dt, scene)
    local move = 0
    local down_held = love.keyboard.isDown("down") or love.keyboard.isDown("s")

    if love.keyboard.isDown("left") or love.keyboard.isDown("a") then
        move = move - 1
    end
    if love.keyboard.isDown("right") or love.keyboard.isDown("d") then
        move = move + 1
    end

    self.vx = move * self.speed
    if move ~= 0 then
        self.facing = move
    end

    if self.is_grounded then
        self.coyote_timer = self.coyote_time
    else
        self.coyote_timer = math.max(0, self.coyote_timer - dt)
    end

    if self.jump_buffer_timer > 0 then
        self.jump_buffer_timer = math.max(0, self.jump_buffer_timer - dt)
        if self.coyote_timer > 0 then
            self:jump()
        end
    end

    local jump_held = love.keyboard.isDown("space") or love.keyboard.isDown("up") or love.keyboard.isDown("w")

    if not self.is_grounded then
        local current_gravity = self.gravity_fall

        if self.vy < 0 then
            if jump_held then
                if math.abs(self.vy) < 30 then
                    current_gravity = self.gravity_apex
                else
                    current_gravity = self.gravity_held
                end

            else
                current_gravity = self.gravity_cut
            end
        else
            current_gravity = self.gravity_fall
        end

        self.vy = math.min(self.max_fall, self.vy + current_gravity * dt)
    end


    local prev_x = self.x
    self.x = self.x + self.vx * dt

    local room_w = (scene and scene.room_width) or 320
    local half_w = self.box_w / 2
    if self.x - half_w < 0 then
        self.x = half_w
    elseif self.x + half_w > room_w then
        self.x = room_w - half_w
    end

    self.touching_left_solid = nil
    self.touching_right_solid = nil

    if scene and scene.elements then
        for _, el in ipairs(scene.elements) do
            if el.visible and el.is_solid and not (el.is_one_way or el.one_way or el.top_only) then
                local boxes = getElementBoxes(el)
                for _, box in ipairs(boxes) do
                    if not (box.one_way or box.top_only or box.is_one_way) then
                        local ex, ey, ew, eh = box.x, box.y, box.w, box.h
                        if (self.y > ey + 2) and (self.y - self.box_h < ey + eh - 2) then
                            if self.vx > 0 and prev_x + half_w <= ex + 1 and (self.x + half_w) >= ex then
                                self.x = ex - half_w
                                self.vx = 0
                                self.touching_right_solid = el
                            elseif self.vx < 0 and prev_x - half_w >= ex + ew - 1 and (self.x - half_w) <= ex + ew then
                                self.x = ex + ew + half_w
                                self.vx = 0
                                self.touching_left_solid = el
                            end
                        end
                    end
                end
            end
        end
    end

    local was_grounded = self.is_grounded
    local fall_speed = self.vy

    local prev_y = self.y
    self.y = self.y + self.vy * dt
    self.is_grounded = false

    local landed_y = nil
    if scene and scene.elements then
        for _, el in ipairs(scene.elements) do
            if el.visible and el.is_solid then
                local boxes = getElementBoxes(el)
                for _, box in ipairs(boxes) do
                    local ex, ey, ew, eh = box.x, box.y, box.w, box.h
                    if (self.x + half_w) > ex and (self.x - half_w) < (ex + ew) then
                        local can_land = false

                        -- Normal landing when falling from above
                        if self.vy >= 0 and prev_y <= ey + 2 and self.y >= ey then
                            can_land = true
                        -- Smooth step-up onto small rims/bumps (<= 4px) when moving along ground
                        elseif was_grounded and prev_y >= ey and (prev_y - ey) <= 4 then
                            can_land = true
                        end

                        if can_land then
                            if not landed_y or ey < landed_y then
                                landed_y = ey
                            end
                        end
                    end
                end
            end
        end
    end
    if landed_y then
        self.y = landed_y
        self.vy = 0
        self.is_grounded = true
    end

    local room_h = (scene and scene.room_height) or 240
    if self.y >= room_h  then
        self.y = room_h 
        self.vy = 0
        self.is_grounded = true
    end

    if not was_grounded and self.is_grounded and fall_speed > 60 then
        self.scale_x = 1.2
        self.scale_y = 0.8
    end

    local is_crouching = self.is_grounded and down_held and math.abs(self.vx) < 5
    if is_crouching and not self.was_crouching then
        self.scale_x = 1.24
        self.scale_y = 0.76
    elseif not is_crouching and self.was_crouching then
        if self.is_grounded then
            self.scale_x = 0.88
            self.scale_y = 1.12
        end
    end
    self.was_crouching = is_crouching

    local target_sx = is_crouching and 1.12 or 1.0
    local target_sy = is_crouching and 0.88 or 1.0
    local recover_speed = 12
    self.scale_x = self.scale_x + (target_sx - self.scale_x) * math.min(1, dt * recover_speed)
    self.scale_y = self.scale_y + (target_sy - self.scale_y) * math.min(1, dt * recover_speed)

    if self.anim then
        if self.is_grounded then
            if down_held and math.abs(self.vx) < 5 then
                self.anim:play("sit")
            elseif math.abs(self.vx) > 5 then
                self.anim:play("run")
            else
                self.anim:play("idle")
            end
        else
            if self.vy < 0 then
                self.anim:play("jump")
            else
                self.anim:play("fall")
            end
        end
        self.anim:update(dt)
    end
end

function Player:draw()
    if self.anim then
        love.graphics.setColor(1, 1, 1, 1)
        local draw_x = math.floor(self.x + 0.5)
        local draw_y = math.floor(self.y + 0.5)
        self.anim:draw(draw_x, draw_y, 0, self.facing * self.scale_x, self.scale_y, 16, 26)
    end
end

function Player:isHoldingKey(key_name)
    if not key_name then return true end
    if type(key_name) == "table" then
        for _, k in ipairs(key_name) do
            if not self:isHoldingKey(k) then return false end
        end
        return true
    end
    if key_name == "down" then
        return love.keyboard.isDown("down") or love.keyboard.isDown("s")
    elseif key_name == "up" then
        return love.keyboard.isDown("up") or love.keyboard.isDown("w")
    elseif key_name == "left" then
        return love.keyboard.isDown("left") or love.keyboard.isDown("a")
    elseif key_name == "right" then
        return love.keyboard.isDown("right") or love.keyboard.isDown("d")
    else
        return love.keyboard.isDown(key_name)
    end
end

function Player:checkCollisionDir(el, dir)
    if not dir then return true end
    local half_w = self.box_w / 2
    local px = self.x - half_w
    local py = self.y - self.box_h
    local pw = self.box_w
    local ph = self.box_h

    local boxes = getElementBoxes(el)
    for _, box in ipairs(boxes) do
        local ex, ey, ew, eh = box.x, box.y, box.w, box.h

        if dir == "right" then
            if not self:isHoldingKey("right") then return false end
            if self.touching_right_solid == el then return true end
            local overlap_y = (py + ph > ey + 2) and (py < ey + eh - 2)
            local touching = math.abs((px + pw) - ex) <= 4
            if overlap_y and touching then return true end
        elseif dir == "left" then
            if not self:isHoldingKey("left") then return false end
            if self.touching_left_solid == el then return true end
            local overlap_y = (py + ph > ey + 2) and (py < ey + eh - 2)
            local touching = math.abs(px - (ex + ew)) <= 4
            if overlap_y and touching then return true end
        elseif dir == "down" then
            if not self:isHoldingKey("down") then return false end
            local overlap_x = (px + pw > ex + 2) and (px < ex + ew - 2)
            local touching = math.abs((py + ph) - ey) <= 4 or ((py + ph >= ey) and (py + ph <= ey + eh + 4))
            if overlap_x and touching then return true end
        elseif dir == "up" then
            if not self:isHoldingKey("up") then return false end
            local overlap_x = (px + pw > ex + 2) and (px < ex + ew - 2)
            local touching = math.abs(py - (ey + eh)) <= 4
            if overlap_x and touching then return true end
        end
    end
    return false
end

function Player:canInteractWith(el)
    if not el or not el.visible then return false end
    if not (el.onClick or el.onInteract or el.interactable) then return false end

    local req_key = el.require_key or el.required_key or el.hold_key
    if req_key == nil and el.requires_down then
        req_key = "down"
    end
    if req_key and not self:isHoldingKey(req_key) then
        return false
    end

    local req_col = el.require_collision or el.required_collision or el.collision_dir
    if req_col and not self:checkCollisionDir(el, req_col) then
        return false
    end

    if el.canInteract ~= nil then
        if type(el.canInteract) == "function" then
            local ok, can = pcall(el.canInteract, el, self)
            if not ok or not can then
                return false
            end
        elseif not el.canInteract then
            return false
        end
    end

    local boxes = getElementBoxes(el)
    local min_dist_ok = false
    local px = self.x - self.box_w / 2
    local py = self.y - self.box_h
    local pw = self.box_w
    local ph = self.box_h
    for _, box in ipairs(boxes) do
        local ex, ey, ew, eh = box.x, box.y, box.w, box.h
        local dx = math.max(0, math.max(ex - (px + pw), px - (ex + ew)))
        local dy = math.max(0, math.max(ey - (py + ph), py - (ey + eh)))
        if dx <= 10 and dy <= 12 then
            min_dist_ok = true
            break
        end
    end
    return min_dist_ok
end

function Player:keypressed(key, scene)
    if key == "space" or key == "up" or key == "w" then
        self.jump_buffer_timer = self.jump_buffer_time
        if self.coyote_timer > 0 then
            self:jump()
        end
    end

    if key == "e" then
        local target = (scene and scene.getInteractableElement and scene:getInteractableElement()) or (scene and scene.current_interactable)
        if not target and scene and scene.elements then
            for _, el in ipairs(scene.elements) do
                if self:canInteractWith(el) then
                    target = el
                    break
                end
            end
        end
        if target then
            local down_held = self:isHoldingKey("down")
            if target.onInteract then
                target:onInteract(down_held, self)
            elseif target.onClick then
                target:onClick(1)
            end
        end
    end
end

return Player

