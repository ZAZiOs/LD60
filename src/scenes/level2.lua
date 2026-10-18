local SceneManager = require("src.core.scene_manager")

local Level2 = {}

function Level2:enter()
    print("Entered Level 2")
end

function Level2:leave()
    print("Leaving Level 2")
end

function Level2:update(dt)

end

function Level2:keypressed(key)
    if key == "return" then
        SceneManager.goTo("level0")
    elseif key == "backspace" then
        SceneManager.goTo("menu")
    end
end

function Level2:draw()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Level 2: Office worker", 40, 40)
    love.graphics.print("[ENTER] - previous level", 40, 80)
    love.graphics.print("[BACKSPACE] - menu", 40, 110)
    love.graphics.print("[ESC] - quit", 40, 140)
end

return Level2
