local SceneManager = require("src.core.scene_manager")
local PixelScreen = require("src.core.pixel_screen")
local GameScene = require("src.core.game_scene")
local PixelSceneBuilder = require("src.core.pixel_scene_builder")
local AudioManager = require("src.core.audio_manager")
local Effects = require("src.core.effects")

local desktop = PixelSceneBuilder.new("desktop")
    :background("assets/level0/desktop/wp.png")
    :cursor("assets/cursor.ini")
    :addSolid("taskbar", {
        image = "assets/level0/desktop/taskbar.png",
        x = 0,
        y = 224,
        w = 320,
        h = 16
    })
    :spawnPlayer({
        x = 30,
        y = 224,
        sheet = "assets/rage/rage_sh.ini"
    })
    :build()

local Settings = require("src.core.settings")
local win_settings = desktop:getElement("window_settings")
if win_settings then
    win_settings:addSlider({
        id = "slider_music",
        x = 8,
        y = 6,
        w = 136,
        label = "Music Volume",
        value = Settings.get("music_volume") or 0.8,
        onChange = function(self, val)
            Settings.set("music_volume", val)
        end
    })
    win_settings:addSlider({
        id = "slider_sfx",
        x = 8,
        y = 28,
        w = 136,
        label = "SFX Volume",
        value = Settings.get("sfx_volume") or 1.0,
        onChange = function(self, val)
            Settings.set("sfx_volume", val)
        end
    })
    win_settings:addCheckbox({
        id = "chk_mute",
        x = 8,
        y = 52,
        text = "Mute Audio",
        checked = Settings.get("muted") or false,
        onChange = function(self, val)
            Settings.set("muted", val)
        end
    })
    win_settings:addCheckbox({
        id = "chk_fullscreen",
        x = 8,
        y = 68,
        text = "Fullscreen Mode",
        checked = Settings.get("fullscreen") or false,
        onChange = function(self, val)
            Settings.set("fullscreen", val)
        end
    })
    win_settings:addButton({
        id = "btn_ok",
        x = 100,
        y = 90,
        w = 44,
        h = 13,
        text = "OK",
        onClick = function()
            win_settings:close()
        end
    })
end

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
        AudioManager.musFadeTo("crt", 0.8, 0.5)
    end,
    leave = function(self)
        AudioManager.musStop(0.5)
    end
})

return Level1Scene
