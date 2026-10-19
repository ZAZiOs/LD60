local SceneManager = require("src.core.scene_manager")
local PixelScreen = require("src.core.pixel_screen")
local GameScene = require("src.core.game_scene")
local PixelSceneBuilder = require("src.core.pixel_scene_builder")
local AudioManager = require("src.core.audio_manager")
local Effects = require("src.core.effects")

local ROOM_WIDTH = 950
local ROOM_HEIGHT = 480
local PLAYER_START_X, PLAYER_START_Y = 50, 340

local desktop = PixelSceneBuilder.new("desktop_level1")
    :addSolid("platform_1", {
        x = 25,
        y = 400,
        w = 50,
        h = 20,
        color = {1, 1, 1, 1},
        hollow = true
    })
    :addSolid("platform_2", {
        spawn_x = 100,
        spawn_y = 400,
        w = 50,
        h = 20,
        speed = 30,
        direction = 1,
        max_delta_x = 120,
        color = {1, 1, 1, 1},
        hollow = true
    })
    :addSolid("platform_3", {
        spawn_x = 300,
        spawn_y = 400,
        w = 50,
        h = 20,
        speed = 30,
        direction = -1,
        max_delta_x = 120,
        color = {1, 1, 1, 1},
        hollow = true
    })
    :addSolid("platform_4", {
        spawn_x = 500,
        spawn_y = 400,
        w = 50,
        h = 20,
        speed = 30,
        direction = 1,
        max_delta_x = 120,
        color = {1, 1, 1, 1},
        hollow = true
    })
    :addSolid("platform_5", {
        x = 700,
        y = 400,
        w = 160,
        h = 20,
        color = {1, 1, 1, 1},
        hollow = true
    })
    :addOneWay("platform_6", {
        x = 770,
        y = 360,
        w = 20,
        h = 20,
        color = {1, 1, 1, 1},
        hollow = true
    })
    :addSolid("platform_7", {
        x = 840,
        y = 300,
        w = 20,
        h = 60,
        color = {1, 1, 1, 1},
        hollow = true
    })
    :addSolid("platform_8", {
        x = 770,
        y = 240,
        w = 20,
        h = 80,
        color = {1, 1, 1, 1},
        hollow = true
    })
    :addSolid("platform_9", {
        x = 840,
        y = 260,
        w = 20,
        h = 20,
        color = {1, 1, 1, 1},
        hollow = true
    })
    :addSolid("platform_10", {
        x = 650,
        y = 210,
        w = 80,
        h = 20,
        color = {1, 1, 1, 1},
        hollow = true
    })
    :addElement({
        id = "door",
        x = 675,
        y = 170,
        w = 30,
        h = 40,
        color = {1, 0, 1, 1},
        hollow = false,
        outline_width = 5,
        onInteract = function(self)
            SceneManager.crossFade("level2", 0.4)
        end
    })
    :spawnPlayer({
        x = PLAYER_START_X,
        y = PLAYER_START_Y,
        sheet = "assets/rage/rage_sh.ini"
    })
    :setRoomBounds(ROOM_WIDTH, ROOM_HEIGHT)
    :onEnter(function(scene)
        if scene.player then
            scene.player.x = PLAYER_START_X
            scene.player.y = PLAYER_START_Y
            scene.player.vx = 0
            scene.player.vy = 0
            scene.player.is_grounded = false
        end
    end)
    :onUpdate(function(scene)
        if scene.player and scene.player.y >= ROOM_HEIGHT then
            SceneManager.goTo("level1-3")
        end
    end)
    :onKey(function(self, action, key)
        if action == "press" then
            if key == "escape" then
                SceneManager.goTo("menu")
            end
        end
    end)
    :build()

local screen = PixelScreen.new({
    game = desktop,
    fps = 30,
    x = 320,
    y = 60,
    w = 1280,
    h = 960
})

local Level1Scene = GameScene.new({
    bg = "assets/bg/platforming_section.png",
    screen = screen,
    screen_draw_fn = function(s)
        Effects.drawAsciiCrt(s.canvas, s.x, s.y, s.scale_x, s.scale_y)
    end,
    enter = function(self)
        AudioManager.musFadeTo("web_havoc", 0.8, 0.2, "reverb")
    end,
    leave = function(self)
        AudioManager.musStop(0.5)
    end
})

return Level1Scene
