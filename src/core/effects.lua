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
    
    -- Convert virtual coords to real screen coords
    local realX, realY = Viewport.toScreen(x, y)
    local realScaleX = scale_x * Viewport.getScale()
    local realScaleY = scale_y * Viewport.getScale()
    
    local zoneW = canvasW * realScaleX
    local zoneH = canvasH * realScaleY
    
    crtShader:send("texSize", { canvasW, canvasH })
    crtShader:send("zone", { realX, realY, zoneW, zoneH })
    crtShader:send("time", time)
    
    love.graphics.setShader(crtShader)
    love.graphics.setColor(1, 1, 1)
    -- Draw using original virtual coords (Viewport will transform them)
    love.graphics.draw(canvas, x, y, 0, scale_x, scale_y)
    love.graphics.setShader()
end

return Effects