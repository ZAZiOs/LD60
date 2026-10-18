local PixelScreen = {}
PixelScreen.__index = PixelScreen

function PixelScreen.new(opts)
    opts = opts or {}
    local self = setmetatable({}, PixelScreen)

    self.game_width = opts.game_width or 320
    self.game_height = opts.game_height or 240

    self.x = opts.x or 320
    self.y = opts.y or 60
    self.w = opts.w or 1280
    self.h = opts.h or 960

    self.scale_x = self.w / self.game_width
    self.scale_y = self.h / self.game_height

    self.game = opts.game or {}

    self.fps = (opts.fps ~= false) and (opts.fps or 30) or nil
    self.frame_time = self.fps and (1.0 / self.fps) or 0
    self.accum_time = 0
    self.needs_render = true

    self.canvas = nil
    self:_initCanvas()

    return self
end

function PixelScreen:setFps(fps)
    self.fps = fps and (fps > 0 and fps or nil) or nil
    self.frame_time = self.fps and (1.0 / self.fps) or 0
    self.accum_time = 0
    self.needs_render = true
end


function PixelScreen:_initCanvas()
    if love and love.graphics and love.graphics.newCanvas then
        self.canvas = love.graphics.newCanvas(self.game_width, self.game_height)
        self.canvas:setFilter("nearest", "nearest")
    end
end

function PixelScreen:setRect(x, y, w, h)
    self.x = x or self.x
    self.y = y or self.y
    self.w = w or self.w
    self.h = h or self.h
    self.scale_x = self.w / self.game_width
    self.scale_y = self.h / self.game_height
end

function PixelScreen:setScene(new_scene, ...)
    if self.game and self.game.leave then
        self.game:leave()
    end
    self.game = new_scene or {}
    if self.game and self.game.enter then
        self.game:enter(...)
    end
    return self
end

function PixelScreen:getScene()
    return self.game
end


function PixelScreen:attach()
    if not self.canvas then return end
    love.graphics.push("all")
    love.graphics.setCanvas(self.canvas)
    love.graphics.origin()
    love.graphics.setScissor()
    love.graphics.clear(0, 0, 0, 1)
end

function PixelScreen:detach()
    if not self.canvas then return end
    love.graphics.pop()
end

function PixelScreen:render(draw_fn, force)
    if not self.canvas then return end
    if not force and not self.needs_render and not draw_fn then
        return
    end

    self:attach()
    if draw_fn then
        draw_fn()
    elseif self.game and self.game.draw then
        self.game:draw()
    end
    self:detach()
    self.needs_render = false
end

function PixelScreen:draw()
    if not self.canvas then return end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self.canvas, self.x, self.y, 0, self.scale_x, self.scale_y)
end

function PixelScreen:isInside(vx, vy)
    return vx >= self.x and vx < (self.x + self.w) and
           vy >= self.y and vy < (self.y + self.h)
end

function PixelScreen:toGame(vx, vy)
    local gx = math.floor((vx - self.x) / self.scale_x)
    local gy = math.floor((vy - self.y) / self.scale_y)
    return math.max(0, math.min(self.game_width - 1, gx)),
           math.max(0, math.min(self.game_height - 1, gy))
end

function PixelScreen:toVirtual(gx, gy)
    local vx = self.x + gx * self.scale_x
    local vy = self.y + gy * self.scale_y
    return vx, vy
end

function PixelScreen:enter(...)
    self.needs_render = true
    if self.game and self.game.enter then
        self.game:enter(...)
    end
end

function PixelScreen:leave()
    if self.game and self.game.leave then
        self.game:leave()
    end
end

function PixelScreen:update(dt)
    if not self.game then return end

    if self.fps and self.fps > 0 then
        self.accum_time = self.accum_time + dt
        local max_ticks = 4
        local ticks = 0
        while self.accum_time >= self.frame_time and ticks < max_ticks do
            self.accum_time = self.accum_time - self.frame_time
            ticks = ticks + 1
            if self.game.update then
                self.game:update(self.frame_time)
            end
            self.needs_render = true
        end
        if ticks >= max_ticks then
            self.accum_time = 0
        end
    else
        if self.game.update then
            self.game:update(dt)
        end
        self.needs_render = true
    end
end


function PixelScreen:mousepressed(vx, vy, button, istouch, presses)
    if self:isInside(vx, vy) then
        self.needs_render = true
        local gx, gy = self:toGame(vx, vy)
        if self.game and self.game.mousepressed then
            self.game:mousepressed(gx, gy, button, istouch, presses)
        end
        return true
    end
    return false
end

function PixelScreen:mousereleased(vx, vy, button, istouch, presses)
    if self:isInside(vx, vy) then
        self.needs_render = true
        local gx, gy = self:toGame(vx, vy)
        if self.game and self.game.mousereleased then
            self.game:mousereleased(gx, gy, button, istouch, presses)
        end
        return true
    end
    return false
end

function PixelScreen:mousemoved(vx, vy, vdx, vdy, istouch)
    local inside = self:isInside(vx, vy)
    local gx, gy = self:toGame(vx, vy)
    local gdx = vdx / self.scale_x
    local gdy = vdy / self.scale_y
    if inside or self._was_inside then
        self.needs_render = true
    end
    self._was_inside = inside
    if self.game and self.game.mousemoved then
        self.game:mousemoved(gx, gy, gdx, gdy, istouch, inside)
    end
    return inside
end

function PixelScreen:wheelmoved(x, y)
    self.needs_render = true
    if self.game and self.game.wheelmoved then
        self.game:wheelmoved(x, y)
    end
end

function PixelScreen:keypressed(key, scancode, isrepeat)
    self.needs_render = true
    if self.game and self.game.keypressed then
        self.game:keypressed(key, scancode, isrepeat)
    end
end

function PixelScreen:keyreleased(key, scancode)
    self.needs_render = true
    if self.game and self.game.keyreleased then
        self.game:keyreleased(key, scancode)
    end
end

function PixelScreen:textinput(text)
    self.needs_render = true
    if self.game and self.game.textinput then
        self.game:textinput(text)
    end
end

return PixelScreen

