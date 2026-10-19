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

    self.wall_slide_speed = opts.wall_slide_speed or 45
    self.wall_jump_force = opts.wall_jump_force or -230
    self.wall_jump_speed = opts.wall_jump_speed or 185
    self.wall_jump_lock_time = opts.wall_jump_lock_time or 0.22
    self.wall_coyote_time = opts.wall_coyote_time or 0.1

    self.wall_coyote_timer = 0
    self.wall_jump_lock = 0
    self.wall_kick_timer = 0
    self.wall_dir = 0
    self.last_wall_dir = 0
    self.is_wall_sliding = false
    self.last_jumped_wall_dir = 0
    self.same_wall_cooldown = 0
    self.wall_safe_floor_dist = opts.wall_safe_floor_dist or 10

    self.slide_particles = {}
    self.particle_timer = 0

    self.coyote_timer = 0
    self.coyote_time = 0.08
    self.jump_buffer_timer = 0
    self.jump_buffer_time = 0.08

    self.box_w = 14
    self.box_h = 24

    self.facing = 1
    self.is_grounded = false
    self.ground_platform = nil

    self.scale_x = 1
    self.scale_y = 1
    self.was_crouching = false

    self.tail_length = opts.tail_length or 8
    self.tail_root_x = self.x - self.facing * 3 * self.scale_x
    self.tail_root_y = self.y - 10 * self.scale_y
    self.tail_tip_x = self.tail_root_x - self.facing * self.tail_length
    self.tail_tip_y = self.tail_root_y + 2
    self.tail_vx = 0
    self.tail_vy = 0
    self.tail_time = 0

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

function Player:wallJump(dir)
    local kick_dir = dir or (self.wall_dir ~= 0 and self.wall_dir) or (self.last_wall_dir ~= 0 and self.last_wall_dir) or self.facing
    self.vy = self.wall_jump_force
    self.vx = -kick_dir * self.wall_jump_speed
    self.facing = -kick_dir
    self.wall_jump_lock = self.wall_jump_lock_time
    self.last_jumped_wall_dir = kick_dir
    self.same_wall_cooldown = 0.30
    self.wall_kick_timer = 0.22
    self.wall_coyote_timer = 0
    self.jump_buffer_timer = 0
    self.is_wall_sliding = false
    self.is_grounded = false
    self.coyote_timer = 0
    self.scale_x = 0.74
    self.scale_y = 1.32
end

function Player:getHitbox()
    return {
        x = self.x - self.box_w / 2,
        y = self.y - self.box_h,
        w = self.box_w,
        h = self.box_h
    }
end

function Player:getDistanceToFloor(scene)
    if self.is_grounded then
        return 0
    end

    local sc = scene or self.scene
    local half_w = self.box_w / 2
    local room_h = (sc and sc.room_height) or 240
    local min_dist = math.max(0, room_h - self.y)

    if sc and sc.elements then
        for _, el in ipairs(sc.elements) do
            if el.visible and el.is_solid then
                local boxes = getElementBoxes(el)
                for _, box in ipairs(boxes) do
                    local ex, ey, ew, eh = box.x, box.y, box.w, box.h
                    -- Overlaps horizontally with player collision box
                    if (self.x + half_w) > ex and (self.x - half_w) < (ex + ew) then
                        if ey >= self.y - 2 then
                            local d = math.max(0, ey - self.y)
                            if d < min_dist then
                                min_dist = d
                            end
                        end
                    end
                end
            end
        end
    end

    return min_dist
end

function Player:canWallJump(scene)
    return self:getDistanceToFloor(scene) >= self.wall_safe_floor_dist
end

function Player:update(dt, scene)
    self.scene = scene

    if self.is_dead then
        self.vx = 0
        self.vy = 0
        return
    end

    if self.hide_cooldown and self.hide_cooldown > 0 then
        self.hide_cooldown = self.hide_cooldown - dt
    end

    if self.is_hidden then
        if (self.hide_cooldown or 0) <= 0 then
            local move_pressed = love.keyboard.isDown("left") or love.keyboard.isDown("a") or
                                 love.keyboard.isDown("right") or love.keyboard.isDown("d") or
                                 love.keyboard.isDown("space") or love.keyboard.isDown("up") or
                                 love.keyboard.isDown("w")
            if move_pressed then
                self.is_hidden = false
            else
                self.vx = 0
                self.vy = 0
                return
            end
        else
            self.vx = 0
            self.vy = 0
            return
        end
    end

    local carried_x = 0
    if self.ground_platform and self.is_grounded then
        carried_x = self.ground_platform.x - (self.ground_platform.previous_x or self.ground_platform.x)
    end
    self.ground_platform = nil

    local move = 0
    local down_held = love.keyboard.isDown("down") or love.keyboard.isDown("s")

    if love.keyboard.isDown("left") or love.keyboard.isDown("a") then
        move = move - 1
    end
    if love.keyboard.isDown("right") or love.keyboard.isDown("d") then
        move = move + 1
    end

    if self.same_wall_cooldown > 0 then
        self.same_wall_cooldown = math.max(0, self.same_wall_cooldown - dt)
    end

    if self.wall_jump_lock > 0 then
        self.wall_jump_lock = math.max(0, self.wall_jump_lock - dt)
        local flight_dir = -self.last_jumped_wall_dir
        if flight_dir ~= 0 and move == flight_dir then
            self.vx = flight_dir * math.max(self.speed, math.abs(self.vx))
        end
    else
        self.vx = move * self.speed
        if move ~= 0 and not self.is_wall_sliding then
            self.facing = move
        end
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
        elseif (self.is_wall_sliding or self.wall_coyote_timer > 0) and self:canWallJump(scene) then
            self:wallJump()
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
    self.x = self.x + carried_x + self.vx * dt

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

    local on_left_wall = (self.x - half_w <= 0.5) or (self.touching_left_solid ~= nil)
    local on_right_wall = (self.x + half_w >= room_w - 0.5) or (self.touching_right_solid ~= nil)

    if scene and scene.elements then
        for _, el in ipairs(scene.elements) do
            if el.visible and el.is_solid and not (el.is_one_way or el.one_way or el.top_only) then
                local boxes = getElementBoxes(el)
                for _, box in ipairs(boxes) do
                    if not (box.one_way or box.top_only or box.is_one_way) then
                        local ex, ey, ew, eh = box.x, box.y, box.w, box.h
                        if (self.y > ey + 2) and (self.y - self.box_h < ey + eh - 2) then
                            if math.abs((self.x + half_w) - ex) <= 1.5 then
                                on_right_wall = true
                            end
                            if math.abs((self.x - half_w) - (ex + ew)) <= 1.5 then
                                on_left_wall = true
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
    local landed_platform = nil
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
                                landed_platform = el
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
        self.ground_platform = landed_platform
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

    if self.is_grounded then
        self.is_wall_sliding = false
        self.wall_dir = 0
        self.wall_coyote_timer = 0
        self.wall_kick_timer = 0
        self.wall_jump_lock = 0
        self.same_wall_cooldown = 0
        self.last_jumped_wall_dir = 0
    else
        local wall_contact_dir = 0
        if on_left_wall then
            wall_contact_dir = -1
        elseif on_right_wall then
            wall_contact_dir = 1
        end

        if wall_contact_dir ~= 0 and wall_contact_dir ~= self.last_jumped_wall_dir then
            self.same_wall_cooldown = 0
            self.last_jumped_wall_dir = 0
        end

        local pressing_into_wall = (wall_contact_dir == -1 and (love.keyboard.isDown("left") or love.keyboard.isDown("a")))
                                or (wall_contact_dir == 1 and (love.keyboard.isDown("right") or love.keyboard.isDown("d")))

        local can_slide_on_this_wall = (wall_contact_dir ~= 0)
                                    and not (wall_contact_dir == self.last_jumped_wall_dir and self.same_wall_cooldown > 0)
                                    and self:canWallJump(scene)

        if can_slide_on_this_wall and self.vy > 0 and pressing_into_wall then
            self.is_wall_sliding = true
            self.wall_dir = wall_contact_dir
            self.last_wall_dir = wall_contact_dir
            self.wall_coyote_timer = self.wall_coyote_time
            self.facing = wall_contact_dir

            if self.vy > self.wall_slide_speed then
                self.vy = self.wall_slide_speed
            end
        else
            self.is_wall_sliding = false
            self.wall_dir = 0
            if can_slide_on_this_wall then
                self.last_wall_dir = wall_contact_dir
                self.wall_coyote_timer = self.wall_coyote_time
            else
                self.wall_coyote_timer = math.max(0, self.wall_coyote_timer - dt)
            end
        end
    end

    if self.wall_kick_timer > 0 then
        self.wall_kick_timer = math.max(0, self.wall_kick_timer - dt)
    end

    if self.is_wall_sliding and self.vy > 5 then
        self.particle_timer = self.particle_timer + dt
        while self.particle_timer >= 0.022 do
            self.particle_timer = self.particle_timer - 0.022
            local wall_edge_x = (self.facing == 1) and (self.x + half_w) or (self.x - half_w)
            local py = self.y - math.random(2, math.max(4, self.box_h - 2))
            local p_vx = -self.facing * math.random(8, 24)
            local p_vy = -math.random(10, 34)
            local lifetime = 0.28 + math.random() * 0.25
            local gray = 0.78 + math.random() * 0.20
            local alpha = 0.65 + math.random() * 0.30

            table.insert(self.slide_particles, {
                x = wall_edge_x,
                y = py,
                vx = p_vx,
                vy = p_vy,
                life = lifetime,
                max_life = lifetime,
                size = 2,
                r = gray,
                g = gray,
                b = gray,
                alpha = alpha
            })
        end
    else
        self.particle_timer = 0
    end

    for i = #self.slide_particles, 1, -1 do
        local p = self.slide_particles[i]
        p.life = p.life - dt
        if p.life <= 0 then
            table.remove(self.slide_particles, i)
        else
            p.x = p.x + p.vx * dt
            p.y = p.y + p.vy * dt
            p.vx = p.vx * math.max(0, 1 - 3 * dt)
            p.vy = p.vy * math.max(0, 1 - 2 * dt)
        end
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

    self.tail_time = self.tail_time + dt

    local target_root_x = self.x - self.facing * 3 * self.scale_x
    local target_root_y = self.y - 10 * self.scale_y

    if not self.tail_root_x then
        self.tail_root_x = target_root_x
        self.tail_root_y = target_root_y
    end

    local root_follow_speed = 26
    self.tail_root_x = self.tail_root_x + (target_root_x - self.tail_root_x) * math.min(1, dt * root_follow_speed)
    self.tail_root_y = self.tail_root_y + (target_root_y - self.tail_root_y) * math.min(1, dt * root_follow_speed)
    local root_x = self.tail_root_x
    local root_y = self.tail_root_y

    local rest_x = root_x - self.facing * (self.tail_length * 0.75)
    local rest_y = root_y + 2.5

    if self.is_grounded and math.abs(self.vx) < 5 then
        rest_y = rest_y + math.sin(self.tail_time * 4.5) * 1.5
        rest_x = rest_x + math.cos(self.tail_time * 2.5) * 0.8
    end

    local air_push_x = -self.vx * 0.022
    local air_push_y = -self.vy * 0.016
    rest_x = rest_x + air_push_x
    rest_y = rest_y + air_push_y

    local sim_dt = math.min(dt, 0.04)
    local sub_steps = 2
    local sdt = sim_dt / sub_steps
    local spring_k = 46
    local damping = 8.5
    local gravity = 35

    for _ = 1, sub_steps do
        local fx = (rest_x - self.tail_tip_x) * spring_k - self.tail_vx * damping
        local fy = (rest_y - self.tail_tip_y) * spring_k - self.tail_vy * damping + gravity

        self.tail_vx = self.tail_vx + fx * sdt
        self.tail_vy = self.tail_vy + fy * sdt

        self.tail_tip_x = self.tail_tip_x + self.tail_vx * sdt
        self.tail_tip_y = self.tail_tip_y + self.tail_vy * sdt

        -- Distance constraint (rod/rope length)
        local t_dx = self.tail_tip_x - root_x
        local t_dy = self.tail_tip_y - root_y
        local dist = math.sqrt(t_dx * t_dx + t_dy * t_dy)
        if dist > self.tail_length then
            local nx = t_dx / dist
            local ny = t_dy / dist
            self.tail_tip_x = root_x + nx * self.tail_length
            self.tail_tip_y = root_y + ny * self.tail_length

            -- Dissipate velocity along normal to keep simulation stable
            local vn = self.tail_vx * nx + self.tail_vy * ny
            if vn > 0 then
                self.tail_vx = self.tail_vx - vn * nx
                self.tail_vy = self.tail_vy - vn * ny
            end
        end
    end

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
            if self.is_wall_sliding then
                self.anim:play("wallslide")
            elseif self.wall_kick_timer > 0 then
                self.anim:play("wallkick")
            else
                if self.vy < 0 then
                    self.anim:play("jump")
                else
                    self.anim:play("fall")
                end
            end
        end
        self.anim:update(dt)
    end
end

local function drawPixel(x, y)
    love.graphics.rectangle("fill", math.floor(x), math.floor(y), 1, 1)
end

local function drawPixelLine(x0, y0, x1, y1)
    local dx = math.abs(x1 - x0)
    local dy = -math.abs(y1 - y0)
    local sx = x0 < x1 and 1 or -1
    local sy = y0 < y1 and 1 or -1
    local err = dx + dy
    while true do
        drawPixel(x0, y0)
        if x0 == x1 and y0 == y1 then break end
        local e2 = 2 * err
        if e2 >= dy then
            err = err + dy
            x0 = x0 + sx
        end
        if e2 <= dx then
            err = err + dx
            y0 = y0 + sy
        end
    end
end

local function drawPixelArrowTip(tx, ty, rx, ry, facing)
    local dx = tx - rx
    local dy = ty - ry
    if dx == 0 and dy == 0 then
        dx = -facing
        dy = 0
    end

    local adx = math.abs(dx)
    local ady = math.abs(dy)
    local sx = dx >= 0 and 1 or -1
    local sy = dy >= 0 and 1 or -1

    if adx > 1.8 * ady then
        -- Horizontal (pointing along sx)
        drawPixel(tx, ty)
        drawPixel(tx - sx, ty - 1)
        drawPixel(tx - sx, ty)
        drawPixel(tx - sx, ty + 1)
        drawPixel(tx - 2 * sx, ty - 1)
        drawPixel(tx - 2 * sx, ty + 1)
    elseif ady > 1.8 * adx then
        -- Vertical (pointing along sy)
        drawPixel(tx, ty)
        drawPixel(tx - 1, ty - sy)
        drawPixel(tx, ty - sy)
        drawPixel(tx + 1, ty - sy)
        drawPixel(tx - 1, ty - 2 * sy)
        drawPixel(tx + 1, ty - 2 * sy)
    else
        -- Diagonal (pointing along sx, sy)
        drawPixel(tx, ty)
        drawPixel(tx - sx, ty)
        drawPixel(tx, ty - sy)
        drawPixel(tx - sx, ty - sy)
        drawPixel(tx - 2 * sx, ty)
        drawPixel(tx, ty - 2 * sy)
    end
end

function Player:draw()
    if self.is_hidden or self.is_dead then
        return
    end

    if #self.slide_particles > 0 then
        for _, p in ipairs(self.slide_particles) do
            local current_alpha = (p.life / p.max_life) * p.alpha
            love.graphics.setColor(p.r, p.g, p.b, current_alpha)
            local sz = p.size or 2
            love.graphics.rectangle("fill", math.floor(p.x + 0.5), math.floor(p.y + 0.5), sz, sz)
        end
    end

    -- Draw vector tail (1px pixel-perfect line + 3x3 pixel arrowhead ->)
    if self.tail_tip_x and self.tail_tip_y then
        local root_x = math.floor((self.tail_root_x or (self.x - self.facing * 3 * self.scale_x)) + 0.5)
        local root_y = math.floor((self.tail_root_y or (self.y - 10 * self.scale_y)) + 0.5)
        local tip_x = math.floor(self.tail_tip_x + 0.5)
        local tip_y = math.floor(self.tail_tip_y + 0.5)

        love.graphics.setColor(0.933, 0.176, 0.157) -- dark: 0.286, 0.035, 0.027; light: 0.933, 0.176, 0.157
        drawPixelLine(root_x, root_y, tip_x, tip_y)
        drawPixelArrowTip(tip_x, tip_y, root_x, root_y, self.facing)
    end

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
    if self.is_dead then
        return
    end

    if self.is_hidden then
        if (self.hide_cooldown or 0) > 0 then
            return
        end
        if key == "e" or key == "space" or key == "up" or key == "w" or
           key == "left" or key == "a" or key == "right" or key == "d" then
            self.is_hidden = false
            return
        end
    end

    if key == "space" or key == "up" or key == "w" then
        self.jump_buffer_timer = self.jump_buffer_time
        if self.coyote_timer > 0 then
            self:jump()
        elseif (self.is_wall_sliding or self.wall_coyote_timer > 0) and self:canWallJump(scene) then
            self:wallJump()
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

