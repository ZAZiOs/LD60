local SceneManager = require("src.core.scene_manager")
local PixelScreen = require("src.core.pixel_screen")
local GameScene = require("src.core.game_scene")
local PixelSceneBuilder = require("src.core.pixel_scene_builder")
local AudioManager = require("src.core.audio_manager")
local Effects = require("src.core.effects")

ROOM_WIDTH = 640
ROOM_HEIGHT = 240

local desktop = PixelSceneBuilder.new("desktop_level1")
    :addSolid("taskbar", {
        image = "assets/level1/taskbar.png",
        x = 0,
        y = 224,
        w = 320,
        h = 16
    })
    :spawnPlayer({
        x = 100,
        y = 224,
        sheet = "assets/rage/rage_sh.ini"
    })
    :setRoomBounds(ROOM_WIDTH, ROOM_HEIGHT)
    :build()

local screen = PixelScreen.new({
    game = desktop,
    x = 320,
    y = 60,
    w = 1280,
    h = 960
})

local Level1Scene = GameScene.new({
    bg = "assets/bg/girls_monitor.png",
    screen = screen,
    screen_draw_fn = function(s)
        Effects.drawAsciiCrt(s.canvas, s.x, s.y, s.scale_x, s.scale_y)
    end,
    enter = function(self)
        AudioManager.musFadeTo("cat", 0.8, 0.5)
    end,
    leave = function(self)
        AudioManager.musStop(0.5)
    end
})

return Level1Scene
