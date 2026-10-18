local Viewport = require("src.core.viewport")

local Effects = {}

local crtShader
local asciiShader
local asciiAtlas
local asciiCanvas
local time = 0

local CELL_W, CELL_H = 20, 20
local CHARS = " +#"
local N_CHARS = #CHARS

function Effects.load()
    crtShader = love.graphics.newShader("assets/shaders/crt.glsl")
    asciiShader = love.graphics.newShader("assets/shaders/ascii.glsl")
    
    local font = love.graphics.newFont(CELL_H, "mono")
    local atlasCanvas = love.graphics.newCanvas(CELL_W * N_CHARS, CELL_H)
    atlasCanvas:setFilter("nearest", "nearest")
    
    love.graphics.push("all")
    love.graphics.setCanvas(atlasCanvas)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setFont(font)
    love.graphics.setColor(1, 1, 1, 1)
    for i = 1, N_CHARS do
        local ch = CHARS:sub(i, i)
        local fw = font:getWidth(ch)
        love.graphics.print(ch, (i - 1) * CELL_W + math.floor((CELL_W - fw) / 2), 0)
    end
    love.graphics.pop()
    
    asciiAtlas = atlasCanvas
    
    asciiShader:send("cellW", CELL_W)
    asciiShader:send("cellH", CELL_H)
    asciiShader:send("nChars", N_CHARS)
    asciiShader:send("atlasCells", { N_CHARS, 1 })
    asciiShader:send("atlasTex", asciiAtlas)
    
    asciiCanvas = love.graphics.newCanvas(1280, 960)
    asciiCanvas:setFilter("nearest", "nearest")
end

function Effects.update(dt)
    time = time + dt
end

function Effects.drawAsciiCrt(canvas, x, y, scale_x, scale_y)
    local canvasW, canvasH = canvas:getDimensions()
    local realX, realY = Viewport.toScreen(x, y)
    local viewportScale = Viewport.getScale()
    local zoneW = 1280 * viewportScale
    local zoneH = 960 * viewportScale

    -- 1. Render the game into asciiCanvas with a clean state
    love.graphics.push("all")          -- saves canvas, transform, scissor, shader, color
    love.graphics.setCanvas(asciiCanvas)
    love.graphics.origin()             -- drop Viewport translate/scale
    love.graphics.setScissor()         -- drop Viewport scissor
    love.graphics.clear(0, 0, 0, 1)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(canvas, 0, 0, 0, 1280 / canvasW, 960 / canvasH)
    love.graphics.pop()                -- restores previous canvas + Viewport transform/scissor

    -- 2. Draw to the screen through the ASCII shader
    asciiShader:send("texSize", { 1280, 960 })
    asciiShader:send("zone", { realX, realY, zoneW, zoneH })

    love.graphics.setShader(asciiShader)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(asciiCanvas, x, y, 0, 1, 1)
    love.graphics.setShader()
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
