local SceneManager = require("src.core.scene_manager")
local Settings = require("src.core.settings")

local Level0Logic = {}

function Level0Logic.setup(desktop, parent_scene)
    local tab_readme = desktop:getElement("tab_readme")
    if tab_readme then
        tab_readme.onClick = function(self)
            self.scene:toggleElement("window_readme")
            local win = self.scene:getElement("window_readme")
            self.scene:setElementActive("tab_readme", win and win.visible)
            local tip = self.scene:getElement("tooltip_readme")
            if tip then
                tip.visible = false
            end
        end
        tab_readme.onInteract = function(self)
            self:onClick()
        end
    end

    local tab_settings = desktop:getElement("tab_settings")
    if tab_settings then
        tab_settings.onClick = function(self)
            self.scene:toggleElement("window_settings")
            local win = self.scene:getElement("window_settings")
            self.scene:setElementActive("tab_settings", win and win.visible)
        end
        tab_settings.onInteract = function(self)
            self:onClick()
        end
    end

    local win_readme = desktop:getElement("window_readme")
    if win_readme then
        win_readme.onClose = function(self)
            local tab = self.scene:getElement("tab_readme")
            if tab then
                self.scene:setElementActive("tab_readme", false)
            end
        end
    end

    local win_settings = desktop:getElement("window_settings")
    if win_settings then
        win_settings.onClose = function(self)
            local tab = self.scene:getElement("tab_settings")
            if tab then
                self.scene:setElementActive("tab_settings", false)
            end
        end

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
end

function Level0Logic.onKey(desktop, action, key, scancode, isrepeat)
    if action == "press" then
        if key == "escape" then
            SceneManager.goTo("menu")
        elseif key == "return" then
            SceneManager.crossFade("level1", 0.4)
        end
    end
end

return Level0Logic
