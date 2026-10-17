local SceneManager = require("src.scene_manager")

function love.load()
    love.window.setTitle("tech_plague")
    
    -- Register scenes
    SceneManager.register("menu", require("src.scenes.menu"))
    SceneManager.register("level1", require("src.scenes.level1"))
    SceneManager.register("level2", require("src.scenes.level2"))
    
    -- Start with menu
    SceneManager.switch("menu")
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

function love.draw()
    SceneManager.draw()
end