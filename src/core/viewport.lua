local Config = require("src.core.config")

local Viewport = {
    virtual_width = Config.virtual_width or 1920,
    virtual_height = Config.virtual_height or 1080,
    
    scale = 1,
    offset_x = 0,
    offset_y = 0,
    window_width = 0,
    window_height = 0
}

function Viewport.init(v_width, v_height)
    if v_width and v_height then
        Viewport.virtual_width = v_width
        Viewport.virtual_height = v_height
    end
    Viewport.resize(love.graphics.getWidth(), love.graphics.getHeight())
end

function Viewport.resize(w, h)
    Viewport.window_width = w
    Viewport.window_height = h

    local scale_x = w / Viewport.virtual_width
    local scale_y = h / Viewport.virtual_height

    Viewport.scale = math.min(scale_x, scale_y)

    local rendered_w = Viewport.virtual_width * Viewport.scale
    local rendered_h = Viewport.virtual_height * Viewport.scale

    Viewport.offset_x = math.floor((w - rendered_w) / 2)
    Viewport.offset_y = math.floor((h - rendered_h) / 2)
end

function Viewport.toVirtual(screen_x, screen_y)
    local vx = (screen_x - Viewport.offset_x) / Viewport.scale
    local vy = (screen_y - Viewport.offset_y) / Viewport.scale
    return vx, vy
end

function Viewport.toScreen(virtual_x, virtual_y)
    local sx = virtual_x * Viewport.scale + Viewport.offset_x
    local sy = virtual_y * Viewport.scale + Viewport.offset_y
    return sx, sy
end

function Viewport.getMousePosition()
    local mx, my = love.mouse.getPosition()
    return Viewport.toVirtual(mx, my)
end

function Viewport.isInside(virtual_x, virtual_y)
    return virtual_x >= 0 and virtual_x <= Viewport.virtual_width and
           virtual_y >= 0 and virtual_y <= Viewport.virtual_height
end

function Viewport.getWidth()
    return Viewport.virtual_width
end

function Viewport.getHeight()
    return Viewport.virtual_height
end

function Viewport.getScale()
    return Viewport.scale
end

function Viewport.attach()
    love.graphics.push()
    love.graphics.translate(Viewport.offset_x, Viewport.offset_y)
    love.graphics.scale(Viewport.scale, Viewport.scale)

    love.graphics.setScissor(
        Viewport.offset_x,
        Viewport.offset_y,
        Viewport.virtual_width * Viewport.scale,
        Viewport.virtual_height * Viewport.scale
    )
end

function Viewport.detach()
    love.graphics.setScissor()
    love.graphics.pop()

    love.graphics.setColor(0, 0, 0, 1)
    local w, h = Viewport.window_width, Viewport.window_height
    local rendered_w = Viewport.virtual_width * Viewport.scale
    local rendered_h = Viewport.virtual_height * Viewport.scale

    if Viewport.offset_x > 0 then
        love.graphics.rectangle("fill", 0, 0, Viewport.offset_x, h)
        love.graphics.rectangle("fill", Viewport.offset_x + rendered_w, 0, w - (Viewport.offset_x + rendered_w), h)
    end

    if Viewport.offset_y > 0 then
        love.graphics.rectangle("fill", 0, 0, w, Viewport.offset_y)
        love.graphics.rectangle("fill", 0, Viewport.offset_y + rendered_h, w, h - (Viewport.offset_y + rendered_h))
    end
end

function Viewport.render(draw_func)
    Viewport.attach()
    draw_func()
    Viewport.detach()
end

return Viewport
