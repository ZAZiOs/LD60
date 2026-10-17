local SceneManager = require("src.scene_manager")
local Level1 = {}

function Level1.enter()
    print("Entered Level 1")
end

function Level1.leave()
    print("Leaving Level 1")
end

function Level1.update(dt)
    -- Level logic (empty for now)
end

function Level1.keypressed(key)
    if key == "return" then
        SceneManager.switch("level2")
    elseif key == "backspace" then
        SceneManager.switch("menu")
    end
end

function Level1.draw()
    love.graphics.print("Level 1: Teenage girl", 20, 20)
    love.graphics.print("[ENTER] — next level", 20, 40)
    love.graphics.print("[BACKSPACE] — menu", 20, 60)
    love.graphics.print("[ESC] — quit", 20, 80)
end

return Level1