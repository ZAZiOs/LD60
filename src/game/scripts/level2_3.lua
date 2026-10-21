local SceneManager = require("src.core.scene_manager")
local GameState = require("src.core.game_state")
local AudioManager = require("src.core.audio_manager")

local Level2_3Logic = {}
local ROOM_HEIGHT = 560
local PLAYER_START_X, PLAYER_START_Y = 110, 460

function Level2_3Logic.setup(desktop, parent_scene)
    local path_10 = desktop:getElement("path_10")
    if path_10 then
        path_10.draw = function(self)
            love.graphics.setColor(1, 0, 1, 1)
            love.graphics.setLineWidth(4)
            love.graphics.line(self.x, self.y, self.x + self.w, self.y + self.h)
            love.graphics.setLineWidth(1)
        end
    end

    local path_11 = desktop:getElement("path_11")
    if path_11 then
        path_11.draw = function(self)
            love.graphics.setColor(1, 0, 1, 1)
            love.graphics.setLineWidth(4)
            love.graphics.line(self.x, self.y, self.x + self.w, self.y + self.h)
            love.graphics.setLineWidth(1)
        end
    end

    local door = desktop:getElement("door")
    if door then
        door.color = {1, 0, 1, 1}
        door.hollow = false
        door.outline_width = 5
        door.onInteract = function(self)
            SceneManager.crossFade("level3", 0.4)
        end
    end

    local coin = desktop:getElement("coin")
    if coin then
        coin.color = {1, 0, 1, 1}
        coin.outline_width = 5
        coin.canInteract = function(self)
            return not GameState.get("level2_3_coin_collected")
        end
        coin.onInteract = function(self)
            if not GameState.get("level2_3_coin_collected") then
                GameState.set("level2_3_coin_collected", true)
                self.visible = false
                if AudioManager and AudioManager.sfxPlay then
                    pcall(AudioManager.sfxPlay, "coin")
                end
            end
        end
    end
end

function Level2_3Logic.enter(desktop, parent_scene)
    if desktop and desktop.player then
        desktop.player.x = PLAYER_START_X
        desktop.player.y = PLAYER_START_Y
        desktop.player.vx = 0
        desktop.player.vy = 0
        desktop.player.is_grounded = false
    end

    if GameState.get("level2_3_coin_collected") then
        local coin = desktop:getElement("coin")
        if coin then coin.visible = false end
    end
end

function Level2_3Logic.update(desktop, dt, parent_scene)
    if desktop and desktop.player and desktop.player.y >= ROOM_HEIGHT then
        SceneManager.goTo("level2-3")
    end
end

function Level2_3Logic.onKey(desktop, action, key, scancode, isrepeat)
    if action == "press" and key == "escape" then
        SceneManager.goTo("menu")
    end
end

return Level2_3Logic
