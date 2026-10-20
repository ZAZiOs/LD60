local SceneManager = require("src.core.scene_manager")

local TestLevelLogic = {}

function TestLevelLogic.setup(desktop, parent_scene)
end

function TestLevelLogic.enter(desktop, parent_scene)
end

function TestLevelLogic.update(desktop, dt, parent_scene)
end

function TestLevelLogic.onKey(desktop, action, key, scancode, isrepeat)
    if action == "press" then
        if key == "escape" then
            SceneManager.goTo("menu")
        elseif key == "return" then
            SceneManager.crossFade("level1", 0.4)
        end
    end
end

function TestLevelLogic.leave(desktop, parent_scene)
end

return TestLevelLogic
