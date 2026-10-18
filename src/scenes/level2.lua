local SceneManager = require("src.core.scene_manager")
local PixelScreen = require("src.core.pixel_screen")
local GameScene = require("src.core.game_scene")
local PixelSceneBuilder = require("src.core.pixel_scene_builder")
local AudioManager = require("src.core.audio_manager")
local Effects = require("src.core.effects")

local desktop = PixelSceneBuilder.new("desktop")
    :background("assets/level0/desktop/wp.png")
    :cursor("assets/cursor.ini")
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
        x = 240,
        y = 112,
        z_index = 2,
        onInteract = function(self)
            SceneManager.crossFade("level1", 0.4)
        end
    })
    :addTooltip("tooltip_readme", {
        text = "read this\nbefore playing\n(press \226\134\147 + E)",
        target = "tab_readme",
        target_anchor_x = 2,
        x = 36,
        y = 168,
        tail_offset_x = 26,
        tail_width = 7
    })
    :addTab("tab_readme", {
        idle = "assets/level0/desktop/tab_readme.png",
        active = "assets/level0/desktop/tab_readme_a.png",
        x = 62,
        y = 226,
        onClick = function(self)
            self.scene:toggleElement("window_readme")
            local win = self.scene:getElement("window_readme")
            self.scene:setElementActive("tab_readme", win and win.visible)
            local tip = self.scene:getElement("tooltip_readme")
            if tip then
                tip.visible = false
            end
        end,
        onInteract = function(self)
            self:onClick()
        end
    })
    :addTab("tab_settings", {
        idle = "assets/level0/desktop/tab_settings.png",
        active = "assets/level0/desktop/tab_settings_a.png",
        x = 115,
        y = 226,
        require_key = "down",
        onClick = function(self)
            self.scene:toggleElement("window_settings")
            local win = self.scene:getElement("window_settings")
            self.scene:setElementActive("tab_settings", win and win.visible)
        end,
        onInteract = function(self)
            self:onClick()
        end
    })
    :addWindow("window_readme", {
        title = "README.TXT",
        x = 48,
        y = 38,
        w = 192,
        h = 132,
        visible = false,
        is_solid = true,
        text = [[Hey, buddy!

I created you so you could help me with a little project. 

You see, there are some things that are better off not existing. One of those things is the data stored in ViewTech’s data centers. 

You’ll have to run between computers to get to the data center. Of course, you’ll come across other people’s computers along the way. Please don’t touch anything there. We need to go unnoticed.

In return for all your efforts, I’ll give you the chance to wreak havoc all over the internet. Good luck.]],
        onClose = function(self)
            local tab = self.scene:getElement("tab_readme")
            if tab then
                self.scene:setElementActive("tab_readme", false)
            end
        end
    })
    :addWindow("window_settings", {
        title = "SETTINGS.EXE",
        x = 76,
        y = 48,
        w = 168,
        h = 126,
        visible = false,
        is_solid = true,
        onClose = function(self)
            local tab = self.scene:getElement("tab_settings")
            if tab then
                self.scene:setElementActive("tab_settings", false)
            end
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
                SceneManager.crossFade("level1", 0.4)
            end
        end
    end)
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
