local SceneManager = require("src.core.scene_manager")
local GameState = require("src.core.game_state")

local Level1Logic = {}
local tip_timer = 6.0

function Level1Logic.setup(desktop, parent_scene)
    local vent = desktop:getElement("vent")
    if vent then
        vent.onInteract = function(self)
            if GameState.get("level1_vent_opened") then
                SceneManager.crossFade("level1-2", 0.4)
            elseif GameState.get("level1_crowbar_collected") then
                self.image = "assets/level1/vent_o.png"
                local ok, img = pcall(love.graphics.newImage, self.image)
                if ok and img then
                    img:setFilter("nearest", "nearest")
                    self.img_obj = img
                end
                GameState.set("level1_vent_opened", true)
            end
        end
    end

    local chest = desktop:getElement("chest")
    if chest then
        chest.canInteract = function(self)
            return not GameState.get("level1_chest_opened")
        end
        chest.onInteract = function(self)
            if GameState.get("level1_key_collected") then
                self.image = "assets/level1/chest_open.png"
                local ok, img = pcall(love.graphics.newImage, self.image)
                if ok and img then
                    img:setFilter("nearest", "nearest")
                    self.img_obj = img
                end
                GameState.set("level1_chest_opened", true)
                if not GameState.get("level1_note_collected") then
                    local note = self.scene and self.scene:getElement("note")
                    if note then note.visible = true end
                end
            end
        end
    end

    local key_el = desktop:getElement("key")
    if key_el then
        key_el.canInteract = function(self)
            return not GameState.get("level1_key_collected")
        end
        key_el.onInteract = function(self)
            if not GameState.get("level1_key_collected", false) then
                GameState.set("level1_key_collected", true)
            end
            self.visible = false
        end
    end

    local wardrobe_segment = desktop:getElement("wardrobe_segment")
    if wardrobe_segment then
        wardrobe_segment.canInteract = function(self)
            return GameState.get("level1_note_collected") and not GameState.get("level1_wardrobe_opened")
        end
        wardrobe_segment.onInteract = function(self)
            if GameState.get("level1_note_collected") and not GameState.get("level1_wardrobe_opened") then
                self.image = "assets/level1/wardrobe_chest_open.png"
                local ok, img = pcall(love.graphics.newImage, self.image)
                if ok and img then
                    img:setFilter("nearest", "nearest")
                    self.img_obj = img
                    self.w = img:getWidth()
                    self.h = img:getHeight()
                end
                GameState.set("level1_wardrobe_opened", true)
                local crowbar = self.scene:getElement("crowbar")
                if crowbar and not GameState.get("level1_crowbar_collected") then
                    crowbar.visible = true
                end
            end
        end
    end

    local note = desktop:getElement("note")
    if note then
        note.canInteract = function(self)
            return GameState.get("level1_chest_opened") and not GameState.get("level1_note_collected")
        end
        note.onInteract = function(self)
            if GameState.get("level1_chest_opened") then
                GameState.set("level1_note_collected", true)
                self.visible = false
                local tab = self.scene:getElement("tab_text")
                if tab then tab.visible = true end
            end
        end
    end

    local crowbar = desktop:getElement("crowbar")
    if crowbar then
        crowbar.canInteract = function(self)
            return GameState.get("level1_wardrobe_opened") and not GameState.get("level1_crowbar_collected")
        end
        crowbar.onInteract = function(self)
            if GameState.get("level1_wardrobe_opened") then
                GameState.set("level1_crowbar_collected", true)
                self.visible = false
            end
        end
    end

    local tab_text = desktop:getElement("tab_text")
    if tab_text then
        tab_text.onClick = function(self)
            self.scene:toggleElement("window_text")
            local win = self.scene:getElement("window_text")
            self.scene:setElementActive("tab_text", win and win.visible)
        end
        tab_text.onInteract = function(self)
            self:onClick()
        end
    end

    local win_text = desktop:getElement("window_text")
    if win_text then
        win_text.onClose = function(self)
            local tab = self.scene:getElement("tab_text")
            if tab then
                self.scene:setElementActive("tab_text", false)
            end
        end
    end

    local tray_ex = desktop:getElement("tray_exclamation")
    if tray_ex then
        tray_ex.onClick = function(self)
            self.visible = false
            local tip = self.scene and self.scene:getElement("tooltip_exclamation")
            if tip then tip.visible = false end
        end
    end

    local tip_ex = desktop:getElement("tooltip_exclamation")
    if tip_ex then
        tip_ex.onClick = function(self)
            self.visible = false
            local icon = self.scene and self.scene:getElement("tray_exclamation")
            if icon then icon.visible = false end
        end
    end
end

function Level1Logic.enter(desktop, parent_scene)
    tip_timer = 6.0
    local icon = desktop:getElement("tray_exclamation")
    if icon then icon.visible = true end
    local tip = desktop:getElement("tooltip_exclamation")
    if tip then tip.visible = true end

    if GameState.get("level1_vent_opened") then
        local vent = desktop:getElement("vent")
        if vent then
            vent.image = "assets/level1/vent_o.png"
            local ok, img = pcall(love.graphics.newImage, vent.image)
            if ok and img then
                img:setFilter("nearest", "nearest")
                vent.img_obj = img
            end
        end
    end
    if GameState.get("level1_chest_opened") then
        local chest = desktop:getElement("chest")
        if chest then
            chest.image = "assets/level1/chest_open.png"
            local ok, img = pcall(love.graphics.newImage, chest.image)
            if ok and img then
                img:setFilter("nearest", "nearest")
                chest.img_obj = img
            end
        end
    end
    if GameState.get("level1_key_collected") then
        local k = desktop:getElement("key")
        if k then k.visible = false end
    end
    if GameState.get("level1_wardrobe_opened") then
        local ws = desktop:getElement("wardrobe_segment")
        if ws then
            ws.image = "assets/level1/wardrobe_chest_open.png"
            local ok, img = pcall(love.graphics.newImage, ws.image)
            if ok and img then
                img:setFilter("nearest", "nearest")
                ws.img_obj = img
            end
        end
    end
    if GameState.get("level1_crowbar_collected") then
        local cb = desktop:getElement("crowbar")
        if cb then cb.visible = false end
    end
    if GameState.get("level1_note_collected") then
        local n = desktop:getElement("note")
        if n then n.visible = false end
        local t = desktop:getElement("tab_text")
        if t then t.visible = true end
    end
end

function Level1Logic.update(desktop, dt, parent_scene)
    if tip_timer > 0 then
        tip_timer = tip_timer - dt
        if tip_timer <= 0 then
            local icon = desktop and desktop:getElement("tray_exclamation")
            if icon then icon.visible = false end
            local tip = desktop and desktop:getElement("tooltip_exclamation")
            if tip then tip.visible = false end
        end
    end
end

function Level1Logic.onKey(desktop, action, key, scancode, isrepeat)
    if action == "press" and key == "escape" then
        SceneManager.goTo("menu")
    end
end

return Level1Logic
