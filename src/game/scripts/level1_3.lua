local SceneManager = require("src.core.scene_manager")

local Level1_3Logic = {}
local ROOM_HEIGHT = 480
local PLAYER_START_X, PLAYER_START_Y = 50, 340

function Level1_3Logic.setup(desktop, parent_scene)
    -- Custom draw for path lines
    local path_ids = { "path_2", "path_3", "path_4" }
    for _, pid in ipairs(path_ids) do
        local p = desktop:getElement(pid)
        if p then
            p.draw = function(self)
                love.graphics.setColor(1, 0, 1, 1)
                love.graphics.setLineWidth(5)
                love.graphics.line(self.x, self.y, self.x + self.w, self.y)
                love.graphics.setLineWidth(1)
            end
        end
    end

    local door = desktop:getElement("door")
    if door then
        door.color = {1, 0, 1, 1}
        door.hollow = false
        door.outline_width = 5
        door.onInteract = function(self)
            SceneManager.crossFade("level2", 0.4)
        end
    end
end

function Level1_3Logic.enter(desktop, parent_scene)
    if desktop and desktop.player then
        desktop.player.x = PLAYER_START_X
        desktop.player.y = PLAYER_START_Y
        desktop.player.vx = 0
        desktop.player.vy = 0
        desktop.player.is_grounded = false
    end
end

function Level1_3Logic.update(desktop, dt, parent_scene)
    if desktop and desktop.player and desktop.player.y >= ROOM_HEIGHT then
        SceneManager.goTo("level1-3")
    end
end

function Level1_3Logic.onKey(desktop, action, key, scancode, isrepeat)
    if action == "press" and key == "escape" then
        SceneManager.goTo("menu")
    end
end

return Level1_3Logic
