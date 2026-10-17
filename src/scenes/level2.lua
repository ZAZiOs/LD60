local SceneManager = require("src.scene_manager")
local Level2 = {}

function Level2.enter()
    print("Entered Level 2")
end

function Level2.leave()
    print("Leaving Level 2")
end

function Level2.update(dt)
end

function Level2.keypressed(key)
    if key == "return" then
        SceneManager.switch("level1")
    elseif key == "backspace" then
        SceneManager.switch("menu")
    end
end

function Level2.draw()
    love.graphics.setColor(0, 0, 0)
    love.graphics.print("Level 2: Office worker", 20, 20)
    love.graphics.print("[ENTER] — previous level", 20, 40)
    love.graphics.print("[BACKSPACE] — menu", 20, 60)
    love.graphics.print("[ESC] — quit", 20, 80)
end

return Level2