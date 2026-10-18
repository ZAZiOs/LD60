local SceneManager = require("src.core.scene_manager")
local PixelScreen = require("src.core.pixel_screen")
local GameScene = require("src.core.game_scene")
local PixelSceneBuilder = require("src.core.pixel_scene_builder")
local AudioManager = require("src.core.audio_manager")
local Effects = require("src.core.effects")

local desktop = PixelSceneBuilder.new("desktop_level1")
    :background("assets/level1/wp.png")
    :cursor("assets/cursor.ini")
    :addSolid("taskbar", {
        image = "assets/level1/taskbar.png",
        x = 0,
        y = 224,
        w = 320,
        h = 16
    })
    :addTab("tab_text", {
        idle = "assets/level1/tab_text_idle.png",
        active = "assets/level1/tab_text_a.png",
        x = 40,
        y = 226,
        onClick = function(self)
            self.scene:toggleElement("window_text")
            local win = self.scene:getElement("window_text")
            self.scene:setElementActive("tab_text", win and win.visible)
        end,
        onInteract = function(self)
            self:onClick()
        end
    })
    :addWindow("window_text", {
        title = "17oct.txt",
        x = 56,
        y = 40,
        w = 180,
        h = 120,
        visible = false,
        is_solid = true,
        text = [[October 17

Meow meow :3
meow meow mew meow
meow meow mew meow
meow meow mew meow
meow meow mew meow
]],
        onClose = function(self)
            local tab = self.scene:getElement("tab_text")
            if tab then
                self.scene:setElementActive("tab_text", false)
            end
        end
    })
    :spawnPlayer({
        x = 100,
        y = 224,
        sheet = "assets/rage/rage_sh.ini"
    })
    :onKey(function(self, action, key)
        if action == "press" then
            if key == "escape" then
                SceneManager.goTo("menu")
            elseif key == "backspace" then
                SceneManager.crossFade("level0", 0.4)
            elseif key == "return" then
                SceneManager.goTo("level2")
            end
        end
    end)
    :build()

local screen = PixelScreen.new({
    game = desktop,
    x = 320,
    y = 60,
    w = 1282,
    h = 962
})

local Level1Scene = GameScene.new({
    bg = "assets/bg/girls_room.png",
    screen = screen,
    screen_draw_fn = function(s)
        Effects.drawCrt(s.canvas, s.x, s.y, s.scale_x, s.scale_y)
    end,
    enter = function(self)
        AudioManager.musFadeTo("cat", 0.8, 0.5)
    end,
    leave = function(self)
        AudioManager.musStop(0.5)
    end
})

return Level1Scene
