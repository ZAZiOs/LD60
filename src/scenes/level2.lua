local SceneManager = require("src.core.scene_manager")
local PixelScreen = require("src.core.pixel_screen")
local GameScene = require("src.core.game_scene")
local PixelSceneBuilder = require("src.core.pixel_scene_builder")
local AudioManager = require("src.core.audio_manager")
local Effects = require("src.core.effects")
local GameState = require("src.core.game_state")
local Events = require("src.core.events")

local ROOM_WIDTH = 540
local ROOM_HEIGHT = 240

local tip_timer = 6.0

local desktop
desktop = PixelSceneBuilder.new("desktop")
    :background("assets/level2/wp.png")
    :cursor("assets/cursor.ini")
    :setRoomBounds(ROOM_WIDTH, ROOM_HEIGHT)

    :addSolid("fg", {
        image = "assets/level2/non-interactable.png",
        x = 0,
        y = 0,
        collisions = {
            -- stairs, vertical
            {x = 143, y = 173, w = 1, h = 24},
            {x = 116, y = 149, w = 1, h = 24},
            {x = 89, y = 125, w = 1, h = 24},
            {x = 62, y = 101, w = 1, h = 24},
    
            -- stairs, horizontal
            {x = 144, y = 198, w = 24, h = 1},
            {x = 117, y = 174, w = 24, h = 1},
            {x = 90, y = 150, w = 24, h = 1},
            {x = 63, y = 126, w = 24, h = 1},
            {x = 1, y = 100, w = 63, h = 1},

            -- table
            {x = 198, y = 181, w = 80, h = 1},

            -- 2rd floor
            {x = 116, y = 100, w = 424, h = 1}
        }
    })

    :addElement({
        id = "facebook",
        image = "assets/level2/facebook.png",
        z_index = 0,
        x = 202,
        y = 173,
        onInteract = function(self)
            self.scene:getElement("facebook_window").visible = true
            GameState.set("level2_facebook", true)
        end
    })
    :addWindow("facebook_window", {
        title = "Mr. Bobinson \\ yourSpace",
        x = 0,
        y = 0,
        fixed = true,
        z_index = 49,
        sheet = "assets/window_close.ini",
        w = 320,
        h = 240,
        visible = false,
        elements = {
            {
                id = "facebook_contents",
                visible = true,
                draw = function(self, window)
                    Events.on("level2_kitten", function()
                        local ok, img = pcall(love.graphics.newImage, "assets/level2/facebook_window_after.png")
                        if ok and img then
                            img:setFilter("nearest", "nearest")
                            self.bg_img = img
                        end
                    end)

                    if not self.bg_img then
                        local ok, img = pcall(love.graphics.newImage, "assets/level2/facebook_window.png")
                        if ok and img then
                            img:setFilter("nearest", "nearest")
                            self.bg_img = img
                        end
                    end
                    if self.bg_img then
                        love.graphics.setColor(1, 1, 1, 1)
                        love.graphics.draw(self.bg_img, 0, 0)
                    end
                end
            },
            {
                id = "facebook_clickable",
                x = 108,
                y = 96,
                w = 206,
                h = 17,
                visible = true,
                
                mousepressed = function(self, cx, cy, button)
                    if cx >= self.x and cx < self.x + self.w and cy >= self.y and cy < self.y + self.h then
                        Events.emit("level2_kitten")
                        GameState.set("level2_facebook_vandalized")
                        return true 
                    end
                    return false  
                end
            },
        }
    })

    :addElement({
        id = "wardrobe",
        image = "assets/level2/wardrobe.png",
        z_index = 0,
        x = 167,
        y = 57,
        canInteract = function(self)
            return not GameState.get("level2_wardrobe_moved") 
        end,
        onInteract = function(self)
            if not GameState.get("level2_folder_collected") then
                if GameState.get("level2_doc_collected") then
                    return
                end
                self.image = "assets/level2/wardrobe_open.png"
                local ok, img = pcall(love.graphics.newImage, self.image)
                if ok and img then
                    img:setFilter("nearest", "nearest")
                    self.img_obj = img
                    self.w = img:getWidth()
                    self.h = img:getHeight()
                end
                self.scene:getElement("doc").visible = true
                self.interactable = false
            else
                GameState.set("level2_wardrobe_moved", true)
                self.x = self.x - 24
                self.scene:getElement("card").visible = true
            end
        end
    })

    :addElement({
        id = "pic1",
        z_index = 0,
        x = 100,
        y = 4,
        flipped = false,
        onInteract = function(self)
            self.flipped = true
        end,
        draw = function(self)
            if not self.my_img then
                local ok, img = pcall(love.graphics.newImage, "assets/level2/pic_1.png")
                if ok and img then
                    img:setFilter("nearest", "nearest")
                    self.my_img = img
                    self.w = img:getWidth()
                    self.h = img:getHeight()
                end
            end
        
            if self.my_img then
                love.graphics.setColor(1, 1, 1, 1)
                if self.flipped then
                    love.graphics.draw(self.my_img, self.x, self.y + self.h, 0, 1, -1, 0, 0)
                else
                    love.graphics.draw(self.my_img, self.x, self.y)
                end
            end
        end
    })
    :addElement({
        id = "pic2",
        z_index = 0,
        x = 300,
        y = 9,
        onInteract = function(self)
            self.flipped = true
        end,
        draw = function(self)
            if not self.my_img then
                local ok, img = pcall(love.graphics.newImage, "assets/level2/pic_2.png")
                if ok and img then
                    img:setFilter("nearest", "nearest")
                    self.my_img = img
                    self.w = img:getWidth()
                    self.h = img:getHeight()
                end
            end
        
            if self.my_img then
                love.graphics.setColor(1, 1, 1, 1)
                if self.flipped then
                    love.graphics.draw(self.my_img, self.x, self.y + self.h, 0, 1, -1, 0, 0)
                else
                    love.graphics.draw(self.my_img, self.x, self.y)
                end
            end
        end
    })
    :addElement({
        id = "pic3",
        z_index = 0,
        x = 319,
        y = 134,
        onInteract = function(self)
            self.flipped = true
        end,
        draw = function(self)
            if not self.my_img then
                local ok, img = pcall(love.graphics.newImage, "assets/level2/pic_3.png")
                if ok and img then
                    img:setFilter("nearest", "nearest")
                    self.my_img = img
                    self.w = img:getWidth()
                    self.h = img:getHeight()
                end
            end
        
            if self.my_img then
                love.graphics.setColor(1, 1, 1, 1)
                if self.flipped then
                    love.graphics.draw(self.my_img, self.x, self.y + self.h, 0, 1, -1, 0, 0)
                else
                    love.graphics.draw(self.my_img, self.x, self.y)
                end
            end
        end
    })

    :addElement({
        id = "closet",
        image = "assets/level2/big_wd.png",
        z_index = 0,
        x = 406,
        y = 140,
        onInteract = function(self)
            AudioManager.musFadeTo(nil, 0, 0)
            self.timer = 2.0

            self.image = "assets/level2/big_wd_o.png"
            local ok, img = pcall(love.graphics.newImage, self.image)
            if ok and img then
                img:setFilter("nearest", "nearest")
                self.img_obj = img
                self.w = img:getWidth()
                self.h = img:getHeight()
            end
        end,
        update = function(self, dt)
            if self.timer then
                self.timer = self.timer - dt
                if self.timer <= 0 then
                    AudioManager.musFadeTo(nil, 0.8, 0.8)
                    self.timer = nil
                end
            end
        end
    })

    :addElement({
        id = "sofa",
        image = "assets/level2/sofa.png",
        z_index = 2,
        x = 409,
        y = 53,
        canInteract = function(self)
            return GameState.get("level2_facebook") and not GameState.get("level2_sofa_moved")
        end,
        onInteract = function(self)
            GameState.set("level2_sofa_moved", true)
            self.x = self.x - 42
            self.scene:getElement("folder").visible = true
        end
    })

    :addTab("lore_note", {
        idle = "assets/level2/lore_idle.png",
        active = "assets/level2/lore_c.png",
        x = 62,
        y = 226,
        visible = false,
        onClick = function(self)
            self.scene:toggleElement("lore_window")
            local win = self.scene:getElement("lore_window")
            self.scene:setElementActive("lore_note", win and win.visible)
        end,
        onInteract = function(self)
            self:onClick()
        end
    })
    :addWindow("lore_window", {
        title = "cardinfo",
        x = 56,
        y = 40,
        w = 180,
        h = 120,
        visible = false,
        text = [[New text]],
        onClose = function(self)
            local tab = self.scene:getElement("lore_note")
            if tab then
                self.scene:setElementActive("lore_note", false)
            end
        end
    })

    :addTab("pdf_text", {
        idle = "assets/level2/folder_tab_idle.png",
        active = "assets/level2/folder_tab_c.png",
        x = 126,
        y = 226,
        visible = false,
        onClick = function(self)
            self.scene:getElement("card_note").visible = true
        end,
        onInteract = function(self)
            self:onClick()
        end
    })
    :addElement({
        id = "folder",
        image = "assets/level2/pdf_folder.png",
        z_index = 2,
        x = 464,
        y = 74,
        visible = false,
        canInteract = function(self)
            return not GameState.get("level2_folder_collected")
        end,
        onInteract = function(self)
            GameState.set("level2_folder_collected", true)
            self.scene:getElement("pdf_text").visible = true
            self.visible = false
        end
    })

    :addTab("card_note", {
        idle = "assets/level2/card_idle.png",
        active = "assets/level2/card_c.png",
        x = 190,
        y = 226,
        visible = false,
        onClick = function(self)
            self.scene:toggleElement("card_window")
            local win = self.scene:getElement("card_window")
            self.scene:setElementActive("card_note", win and win.visible)
        end,
        onInteract = function(self)
            self:onClick()
            self.scene:getElement("wardrobe").interactable = true
        end
    })
    :addWindow("card_window", {
        title = "cardinfo",
        x = 56,
        y = 40,
        w = 180,
        h = 120,
        visible = false,
        text = [[key card is behind the wardrobe]],
        onClose = function(self)
            local tab = self.scene:getElement("card_note")
            if tab then
                self.scene:setElementActive("card_note", false)
            end
        end
    })
    :addElement({
        id = "doc",
        image = "assets/level2/doc.file.png",
        z_index = 2,
        x = 220,
        y = 30,
        visible = false,
        canInteract = function(self)
            return not GameState.get("level2_doc_collected")
        end,
        onInteract = function(self)
            GameState.set("level2_doc_collected", true)
            self.scene:getElement("lore_note").visible = true
            self.visible = false
        end
    })

    :addElement({
        id = "card",
        image = "assets/level2/adm_card.png",
        z_index = 2,
        x = 231,
        y = 76,
        visible = false,
        canInteract = function(self)
            return not GameState.get("level2_card_collected")
        end,
        onInteract = function(self)
            GameState.set("level2_card_collected", true)
            self.visible = false
        end
    })

    :addElement({
        id = "door",
        image = "assets/level2/door.png",
        z_index = 51,
        x = 27,
        y = 162,
        canInteract = function(self)
            return GameState.get("level2_card_collected")
        end,
        onInteract = function(self)
            SceneManager.crossFade("level3", 0.4)
        end
    })

    :addSolid("taskbar", {
        image = "assets/level0/desktop/taskbar.png",
        x = 0,
        y = 224,
        w = 320,
        h = 16
    })
    :spawnPlayer({
        x = 356,
        y = 224,
        sheet = "assets/rage/rage_sh.ini"
    })
    :addElement({
        id = "tray_exclamation",
        image = "assets/exclamation_xp.png",
        x = 300,
        y = 226,
        fixed = true,
        z_index = 1005,
        clickable = true,
        onClick = function(self)
            self.visible = false
            local tip = self.scene and self.scene:getElement("tooltip_exclamation")
            if tip then tip.visible = false end
        end
    })
    :addTooltip("tooltip_exclamation", {
        text = "Find the admin\nkey card and leave\nthe room\nhint: check yourspace \non the desk",
        target = "tray_exclamation",
        target_anchor_x = 5,
        target_anchor_y = 0,
        x = 190,
        y = 156,
        tail_offset_x = 90,
        tail_width = 8,
        fixed = true,
        z_index = 2000,
        onClick = function(self)
            self.visible = false
            local icon = self.scene and self.scene:getElement("tray_exclamation")
            if icon then icon.visible = false end
        end
    })
    :onUpdate(function(sc, dt)
        local delta = dt or 0
        if tip_timer > 0 then
            tip_timer = tip_timer - delta
            if tip_timer <= 0 then
                local icon = sc and sc:getElement("tray_exclamation")
                if icon then icon.visible = false end
                local tip = sc and sc:getElement("tooltip_exclamation")
                if tip then tip.visible = false end
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
        tip_timer = 6.0
        local icon = desktop and desktop:getElement("tray_exclamation")
        if icon then icon.visible = true end
        local tip = desktop and desktop:getElement("tooltip_exclamation")
        if tip then tip.visible = true end
    end,
    leave = function(self)
        AudioManager.musStop(0.5)
    end
})

return Level1Scene
