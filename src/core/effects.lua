local Viewport = require("src.core.viewport")

local Effects = {}

local crtShader
local time = 0

function Effects.load()
    crtShader = love.graphics.newShader("assets/shaders/crt.glsl")
end

function Effects.update(dt)
    time = time + dt
end

function Effects.drawCrt(canvas, x, y, scale_x, scale_y)
    local canvasW, canvasH = canvas:getDimensions()

    local zoneX, zoneY, zoneW, zoneH
    if love.graphics.getCanvas() then
        -- Offscreen canvas (e.g. fade_canvas during transitions):
        -- Screen coordinates in the shader are in canvas pixels, not window pixels
        zoneX = x
        zoneY = y
        zoneW = canvasW * scale_x
        zoneH = canvasH * scale_y
    else
        -- Window screen: convert to physical window coordinates
        local realX, realY = Viewport.toScreen(x, y)
        local realScaleX = scale_x * Viewport.getScale()
        local realScaleY = scale_y * Viewport.getScale()
        zoneX = realX
        zoneY = realY
        zoneW = canvasW * realScaleX
        zoneH = canvasH * realScaleY
    end
    
    crtShader:send("texSize", { canvasW, canvasH })
    crtShader:send("zone", { zoneX, zoneY, zoneW, zoneH })
    crtShader:send("time", time)
    
    love.graphics.setShader(crtShader)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(canvas, x, y, 0, scale_x, scale_y)
    love.graphics.setShader()
end

return Effects