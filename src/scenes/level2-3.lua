local SceneManager = require("src.core.scene_manager")
local PixelScreen = require("src.core.pixel_screen")
local GameScene = require("src.core.game_scene")
local PixelSceneBuilder = require("src.core.pixel_scene_builder")
local AudioManager = require("src.core.audio_manager")
local Effects = require("src.core.effects")
local GameState = require("src.core.game_state")

ROOM_WIDTH = 1280
ROOM_HEIGHT = 560
local PLAYER_START_X, PLAYER_START_Y = 110, 460
--local PLAYER_START_X, PLAYER_START_Y = 120, 10
--local PLAYER_START_X, PLAYER_START_Y = 750, 410
--local PLAYER_START_X, PLAYER_START_Y = 605, 260

local desktop = PixelSceneBuilder.new("desktop_level2_3")
    :addSolid("platform_1", {
        x = 90,
        y = 480,
        w = 40,
        h = 20,
        color = {1, 1, 1, 1},
        hollow = true
    })
    :addSolid("platform_2", {
        x = 160,
        y = 390,
        w = 20,
        h = 60,
        color = {1, 1, 1, 1},
        hollow = true
    })
    :addSolid("platform_3", {
        x = 100,
        y = 360,
        w = 20,
        h = 60,
        color = {1, 1, 1, 1},
        hollow = true
    })
    :addSolid("platform_4", {
        x = 160,
        y = 330,
        w = 20,
        h = 20,
        color = {1, 1, 1, 1},
        hollow = true
    })  
    :addSolid("platform_5", {
        x = 120,
        y = 260,
        w = 20,
        h = 60,
        color = {1, 1, 1, 1},
        hollow = true
    })  
    :addSolid("platform_6", {
        x = 200,
        y = 220,
        w = 20,
        h = 60,
        color = {1, 1, 1, 1},
        hollow = true
    })
    :addSolid("platform_7", {
        x = 100,
        y = 220,
        w = 40,
        h = 20,
        color = {1, 1, 1, 1},
        hollow = true
    })
    :addSolid("platform_8", {
        x = 50,
        y = 180,
        w = 20,
        h = 60,
        color = {1, 1, 1, 1},
        hollow = true
    })
    :addSolid("platform_9", {
        x = 100,
        y = 150,
        w = 80,
        h = 20,
        color = {1, 1, 1, 1},
        hollow = true
    })
    :addSolid("platform_10", {
        spawn_x = 240,
        spawn_y = 150,
        w = 80,
        h = 20,
        speed = 30,
        direction = 1,
        max_delta_x = 140,
        max_delta_y= 140,
        color = {1, 1, 1, 1},
        hollow = true
    })
    :addSolid("platform_11", {
        spawn_x = 500,
        spawn_y = 290,
        w = 80,
        h = 20,
        speed = 30,
        direction = -1,
        max_delta_x = 140,
        max_delta_y= 140,
        color = {1, 1, 1, 1},
        hollow = true
    })
    :addSolid("platform_12", {
        x = 740,
        y = 430,
        w = 80,
        h = 20,
        color = {1, 1, 1, 1},
        hollow = true
    })
    :addSolid("platform_13", {
        x = 850,
        y = 390,
        w = 80,
        h = 20,
        color = {1, 1, 1, 1},
        hollow = true
    })
    :addSolid("platform_14", {
        x = 910,
        y = 390,
        w = 20,
        h = 60,
        color = {1, 1, 1, 1},
        hollow = true
    })
    :addSolid("platform_15", {
        x = 910,
        y = 430,
        w = 80,
        h = 20,
        color = {1, 1, 1, 1},
        hollow = true
    })
    :addSolid("platform_16", {
        x = 1060,
        y = 430,
        w = 80,
        h = 20,
        color = {1, 1, 1, 1},
        hollow = true
    })
    :addElement({
        id = "door",
        x = 1085,
        y = 390,
        w = 30,
        h = 40,
        color = {1, 0, 1, 1},
        hollow = false,
        outline_width = 5,
        onInteract = function(self)
            SceneManager.crossFade("level3", 0.4)
        end
    })
    :addSolid("platform_coin_1", {
        x = 610,
        y = 260,
        w = 20,
        h = 20,
        color = {1, 1, 1, 1},
        hollow = true
    })
    :addSolid("platform_coin_2", {
        x = 690,
        y = 230,
        w = 20,
        h = 20,
        color = {1, 1, 1, 1},
        hollow = true
    })
    :addSolid("platform_coin_3", {
        x = 795,
        y = 230,
        w = 20,
        h = 20,
        color = {1, 1, 1, 1},
        hollow = true
    })
    :addSolid("platform_coin_4", {
        x = 900,
        y = 250,
        w = 20,
        h = 20,
        color = {1, 1, 1, 1},
        hollow = true
    })
    :addSolid("platform_coin_5", {
        x = 900,
        y = 250,
        w = 20,
        h = 20,
        color = {1, 1, 1, 1},
        hollow = true
    })
    :addSolid("platform_coin_6", {
        x = 1000,
        y = 250,
        w = 20,
        h = 20,
        color = {1, 1, 1, 1},
        hollow = true
    })
    :addSolid("platform_coin_7", {
        x = 1080,
        y = 250,
        w = 40,
        h = 20,
        color = {1, 1, 1, 1},
        hollow = true
    })
    :addElement({
        id = "coin",
        x = 1095,
        y = 220,
        w = 10,
        h = 20,
        color = {1, 0, 1, 1},
        outline_width = 5,
        z_index = -1,
        canInteract = function(self)
            return not GameState.get("level2-3_coin_collected")
        end,
        onInteract = function(self)
            if not GameState.get("level2-3_coin_collected") then
                GameState.set("level2-3_coin_collected", true)
                self.visible = false
            end
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
            SceneManager.goTo("level2-3")
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
