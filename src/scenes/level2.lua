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

local CLOCK_SEGMENTS = {
    a = function(dx, dy)
        love.graphics.rectangle("fill", dx + 2, dy + 0, 7, 1)
        love.graphics.rectangle("fill", dx + 3, dy + 1, 5, 1)
    end,
    b = function(dx, dy)
        love.graphics.rectangle("fill", dx + 10, dy + 1, 1, 1)
        love.graphics.rectangle("fill", dx + 9,  dy + 2, 2, 5)
        love.graphics.rectangle("fill", dx + 10, dy + 7, 1, 1)
    end,
    c = function(dx, dy)
        love.graphics.rectangle("fill", dx + 10, dy + 9,  1, 1)
        love.graphics.rectangle("fill", dx + 9,  dy + 10, 2, 5)
        love.graphics.rectangle("fill", dx + 10, dy + 15, 1, 1)
    end,
    d = function(dx, dy)
        love.graphics.rectangle("fill", dx + 3, dy + 15, 5, 1)
        love.graphics.rectangle("fill", dx + 2, dy + 16, 7, 1)
    end,
    e = function(dx, dy)
        love.graphics.rectangle("fill", dx + 0, dy + 9,  1, 1)
        love.graphics.rectangle("fill", dx + 0, dy + 10, 2, 5)
        love.graphics.rectangle("fill", dx + 0, dy + 15, 1, 1)
    end,
    f = function(dx, dy)
        love.graphics.rectangle("fill", dx + 0, dy + 1, 1, 1)
        love.graphics.rectangle("fill", dx + 0, dy + 2, 2, 5)
        love.graphics.rectangle("fill", dx + 0, dy + 7, 1, 1)
    end,
    g = function(dx, dy)
        love.graphics.rectangle("fill", dx + 2, dy + 8, 7, 1)
        love.graphics.rectangle("fill", dx + 3, dy + 9, 5, 1)
    end,
}

local CLOCK_PATTERNS = {
    [0] = { a = true, b = true, c = true, d = true, e = true, f = true },
    [1] = { b = true, c = true },
    [2] = { a = true, b = true, g = true, e = true, d = true },
    [3] = { a = true, b = true, g = true, c = true, d = true },
    [4] = { f = true, g = true, b = true, c = true },
    [5] = { a = true, f = true, g = true, c = true, d = true },
    [6] = { a = true, f = true, g = true, e = true, c = true, d = true },
    [7] = { a = true, b = true, c = true },
    [8] = { a = true, b = true, c = true, d = true, e = true, f = true, g = true },
    [9] = { a = true, b = true, c = true, d = true, f = true, g = true },
}

local SEG_NAMES = { "a", "b", "c", "d", "e", "f", "g" }

local function draw7SegmentDigit(digit, dx, dy)
    local pat = CLOCK_PATTERNS[digit] or CLOCK_PATTERNS[0]
    for _, name in ipairs(SEG_NAMES) do
        if pat[name] then
            love.graphics.setColor(1, 0, 0, 1)
        else
            love.graphics.setColor(0.18, 0, 0, 1)
        end
        CLOCK_SEGMENTS[name](dx, dy)
    end
end

local desktop = PixelSceneBuilder.new("desktop")
    :background("assets/level2/wp.png")
    :cursor("assets/cursor.ini")
    :setRoomBounds(ROOM_WIDTH, ROOM_HEIGHT)

    :addSolid("fg", {
        image = "assets/level2/non-interactable.png",
        x = 0,
        y = 0,
        collisions = {
            -- stairs (one-way)
            { x = 144, y = 198, w = 24,  h = 1, one_way = true },
            { x = 117, y = 174, w = 24,  h = 1, one_way = true },
            { x = 90,  y = 150, w = 24,  h = 1, one_way = true },
            { x = 63,  y = 126, w = 24,  h = 1, one_way = true },
            { x = 1,   y = 100, w = 63,  h = 1, one_way = true },

            -- table (one-way)
            { x = 198, y = 181, w = 80,  h = 1, one_way = true },

            -- 2rd floor
            { x = 116, y = 100, w = 424, h = 1 }
        }
    })

    :addElement({
        id = "digital_clock",
        z_index = 51,
        x = 12,
        y = 14,
        w = 76,
        h = 21,
        clickable = false,
        draw = function(self)
            love.graphics.setColor(0, 0, 0, 1)
            love.graphics.rectangle("fill", 12, 14, 76, 21)

            local t = os.date("*t")
            local h = t.hour or 0
            local m = t.min or 0
            local s = t.sec or 0

            local d1 = math.floor(h / 10)
            local d2 = h % 10
            local d3 = math.floor(m / 10)
            local d4 = m % 10

            draw7SegmentDigit(d1, 21, 16)
            draw7SegmentDigit(d2, 34, 16)
            draw7SegmentDigit(d3, 55, 16)
            draw7SegmentDigit(d4, 68, 16)

            if s % 2 == 0 then
                love.graphics.setColor(1, 0, 0, 1)
            else
                love.graphics.setColor(0.18, 0, 0, 1)
            end
            love.graphics.rectangle("fill", 49, 20, 2, 2)
            love.graphics.rectangle("fill", 49, 28, 2, 2)

            love.graphics.setColor(1, 1, 1, 1)
        end
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
        draggable = false,
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
                self.image = "assets/level2/wardrobe_open.png"
                if not self.open_img then
                    local ok, img = pcall(love.graphics.newImage, self.image)
                    if ok and img then
                        img:setFilter("nearest", "nearest")
                        self.open_img = img
                    end
                end
                if self.open_img then
                    self.img_obj = self.open_img
                    self.w = self.open_img:getWidth()
                    self.h = self.open_img:getHeight()
                end
            else
                GameState.set("level2_wardrobe_moved", true)
                self.x = self.x - 24
                self.scene:getElement("card").visible = true
                self.scene:getElement("doc").visible = true
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
        canInteract = function(self)
            return not self.timer
        end,
        onInteract = function(self)
            AudioManager.musFadeTo(nil, 0, 0)
            self.timer = 2.0

            if not self.closed_img and self.img_obj then
                self.closed_img = self.img_obj
            end

            if not self.open_img then
                local ok, img = pcall(love.graphics.newImage, "assets/level2/big_wd_o.png")
                if ok and img then
                    img:setFilter("nearest", "nearest")
                    self.open_img = img
                end
            end
            if self.open_img then
                self.img_obj = self.open_img
                self.image = "assets/level2/big_wd_o.png"
                self.w = self.open_img:getWidth()
                self.h = self.open_img:getHeight()
            end
        end,
        update = function(self, dt)
            if self.timer then
                self.timer = self.timer - dt
                if self.timer <= 0 then
                    AudioManager.musFadeTo(nil, 0.8, 0.8)
                    self.timer = nil

                    if not self.closed_img then
                        local ok, img = pcall(love.graphics.newImage, "assets/level2/big_wd.png")
                        if ok and img then
                            img:setFilter("nearest", "nearest")
                            self.closed_img = img
                        end
                    end
                    if self.closed_img then
                        self.img_obj = self.closed_img
                        self.image = "assets/level2/big_wd.png"
                        self.w = self.closed_img:getWidth()
                        self.h = self.closed_img:getHeight()
                    end
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
        idle = "assets/level2/card_idle.png",
        active = "assets/level2/card_c.png",
        x = 192,
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
        text =
        [[I used to use this card as a credit card, but then I thought the gold plastic looked really smart, so I attached a payment terminal to the entrance to the cellar. Every time I go down to the cellar now, it costs me 30 dollars!]],
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
        x = 62,
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
        idle = "assets/level2/lore_idle.png",
        active = "assets/level2/lore_c.png",
        x = 126,
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
        title = "impo_note",
        x = 56,
        y = 40,
        w = 180,
        h = 120,
        visible = false,
        text =
        [[soo i deleted all of my important notes here because dude from the security department said that it's not secure to store them here                  i will leave only the passkey to the administrator permissions behind the drawer right after the stairs

i mean it's not that seriouss!]],
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
