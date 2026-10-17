local SceneManager = require("src.scene_manager")

-- Settings
local GAME_WIDTH, GAME_HEIGHT = 320, 240  -- Internal pixel art resolution
local virtualCanvas                       -- Game renders here
local bgImage                             -- Background image (1920x1080)

function love.load(args)
    DEBUG = false
    if args then
        for _, v in ipairs(args) do
            if v == "debug" then
                DEBUG = true
                break
            end
        end
    end

    love.window.setTitle("tech_plague")
    
    -- 1. Disable smoothing for all textures (crisp pixels)
    love.graphics.setDefaultFilter("nearest", "nearest")
    
    -- 2. Create the game canvas (320x240)
    virtualCanvas = love.graphics.newCanvas(GAME_WIDTH, GAME_HEIGHT)
    virtualCanvas:setFilter("nearest", "nearest")
    
    -- 3. Load the background image
    bgImage = love.graphics.newImage("assets/bg/game_menu.png")
    
    -- 4. Register scenes
    SceneManager.register("menu", require("src.scenes.menu"))
    SceneManager.register("level1", require("src.scenes.level1"))
    SceneManager.register("level2", require("src.scenes.level2"))
    
    SceneManager.switch("menu")
end

function love.draw()
    local windowW, windowH = love.graphics.getDimensions()

    -- 1. Draw BACKGROUND scaled to fit the window (1920x1080 -> 1280x960)
    -- Calculate scale to cover the window
    local bgW, bgH = bgImage:getDimensions()
    local bgScale = math.max(windowW / bgW, windowH / bgH)
    local bgOffsetX = (windowW - bgW * bgScale) / 2
    local bgOffsetY = (windowH - bgH * bgScale) / 2

    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(bgImage, bgOffsetX, bgOffsetY, 0, bgScale, bgScale)

    -- 2. Draw GAME into the small canvas
    love.graphics.setCanvas(virtualCanvas)
    love.graphics.clear(0, 0, 0, 0)
    SceneManager.draw()
    love.graphics.setCanvas()

    -- 3. Draw the small canvas OVER the background, upscaled (4x)
    local scale = 3.2 -- TODO: check scaling
    local offsetX = math.floor((windowW - GAME_WIDTH * scale) / 2)
    local offsetY = math.floor((windowH - GAME_HEIGHT * scale) / 2)

    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(virtualCanvas, offsetX, offsetY, 0, scale, scale)

    -- 4. Draw a border around the virtual canvas (debug helper)
    if DEBUG then
        love.graphics.setColor(1, 0, 0, 0.8) -- Red, 80% opaque
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", offsetX, offsetY, GAME_WIDTH * scale, GAME_HEIGHT * scale)
        love.graphics.setLineWidth(1) -- Reset line width to default
    end
end

function love.update(dt)
    SceneManager.update(dt)
end

function love.keypressed(key)
    if key == "escape" then 
        love.event.quit() 
    end
    SceneManager.keypressed(key)
end