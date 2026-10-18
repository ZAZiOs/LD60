local SceneManager = require("src.core.scene_manager")
local PixelScreen = require("src.core.pixel_screen")
local GameScene = require("src.core.game_scene")
local PixelSceneBuilder = require("src.core.pixel_scene_builder")
local AudioManager = require("src.core.audio_manager")
local Effects = require("src.core.effects")

local ROOM_WIDTH = 540
local ROOM_HEIGHT = 240

local desktop = PixelSceneBuilder.new("desktop")
    :background("assets/level2/wp.png")
    :cursor("assets/cursor.ini")
    :setRoomBounds(ROOM_WIDTH, ROOM_HEIGHT)
    :addElement({
        id = "tutorial",
        image = "assets/level0/desktop/tutorial.png",
        x = 0,
        y = 0,
        z_index = 1
    })
    :addSolid("taskbar", {
        image = "assets/level0/desktop/taskbar.png",
        x = 0,
        y = 224,
        w = 320,
        h = 16
    })
    :addElement({
        id = "door",
        image = "assets/level0/desktop/door.png",
        x = 460,
        y = 112,
        z_index = 2,
        onInteract = function(self)
            SceneManager.crossFade("level3", 0.4)
        end
    })
    :spawnPlayer({
        x = 30,
        y = 224,
        sheet = "assets/rage/rage_sh.ini"
    })
    :onKey(function(self, action, key)
        if action == "press" then
            if key == "escape" then
                SceneManager.goTo("menu")
            elseif key == "return" then
                SceneManager.crossFade("level3", 0.4)
            end
        end
    end)
    :build()

local screen = PixelScreen.new({
    game = desktop,
    x = 320,
    y = 60,
    w = 1280,
    h = 960
})

local Level1Scene = GameScene.new({
    bg = "assets/bg/intro_bg.png",
    screen = screen,
    screen_draw_fn = function(s)
        Effects.drawCrt(s.canvas, s.x, s.y, s.scale_x, s.scale_y)
    end,
    enter = function(self)
        AudioManager.musFadeTo("mr_boss", 0.8, 0.5)
    end,
    leave = function(self)
        AudioManager.musStop(0.5)
    end
})

return Level1Scene
