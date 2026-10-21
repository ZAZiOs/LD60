local SceneManager = require("src.core.scene_manager")
local GameState = require("src.core.game_state")
local AudioManager = require("src.core.audio_manager")
local Events = require("src.core.events")

local Level2Logic = {}

local tip_timer = 6.0

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

local function isImpoNoteOpened(sc)
    if GameState.get("level2_impo_note_opened") then
        return true
    end
    if sc then
        local win = sc:getElement("card_window")
        if win and win.visible then
            return true
        end
    end
    return false
end

function Level2Logic.setup(desktop, parent_scene)
    local clock = desktop:getElement("digital_clock")
    if clock then
        clock.draw = function(self)
            love.graphics.setColor(0, 0, 0, 1)
            love.graphics.rectangle("fill", self.x, self.y, self.w or 76, self.h or 21)

            local t = os.date("*t")
            local h = t.hour or 0
            local m = t.min or 0
            local s = t.sec or 0

            local d1 = math.floor(h / 10)
            local d2 = h % 10
            local d3 = math.floor(m / 10)
            local d4 = m % 10

            draw7SegmentDigit(d1, self.x + 9, self.y + 2)
            draw7SegmentDigit(d2, self.x + 22, self.y + 2)
            draw7SegmentDigit(d3, self.x + 43, self.y + 2)
            draw7SegmentDigit(d4, self.x + 56, self.y + 2)

            if s % 2 == 0 then
                love.graphics.setColor(1, 0, 0, 1)
            else
                love.graphics.setColor(0.18, 0, 0, 1)
            end
            love.graphics.rectangle("fill", self.x + 37, self.y + 6, 2, 2)
            love.graphics.rectangle("fill", self.x + 37, self.y + 14, 2, 2)

            love.graphics.setColor(1, 1, 1, 1)
        end
    end

    local fb = desktop:getElement("facebook")
    if fb then
        fb.canInteract = function(self)
            local win = self.scene and self.scene:getElement("facebook_window")
            return not (win and win.visible)
        end
        fb.onInteract = function(self)
            local win = self.scene:getElement("facebook_window")
            if win then win.visible = true end
            GameState.set("level2_facebook", true)
        end
    end

    local fb_win = desktop:getElement("facebook_window")
    if fb_win then
        fb_win.elements = {
            {
                id = "facebook_contents",
                visible = true,
                draw = function(self, window)
                    if not self.img_before then
                        local ok, img = pcall(love.graphics.newImage, "assets/level2/facebook_window.png")
                        if ok and img then
                            img:setFilter("nearest", "nearest")
                            self.img_before = img
                        end
                    end
                    if not self.img_after then
                        local ok, img = pcall(love.graphics.newImage, "assets/level2/facebook_window_after.png")
                        if ok and img then
                            img:setFilter("nearest", "nearest")
                            self.img_after = img
                        end
                    end

                    local img = GameState.get("level2_facebook_vandalized") and self.img_after or self.img_before
                    if img then
                        love.graphics.setColor(1, 1, 1, 1)
                        love.graphics.draw(img, 0, 0)
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
                    if not self.visible or GameState.get("level2_facebook_vandalized") then
                        return false
                    end
                    if cx >= self.x and cx < self.x + self.w and cy >= self.y and cy < self.y + self.h then
                        Events.emit("level2_kitten")
                        GameState.set("level2_facebook_vandalized", true)
                        self.visible = false
                        return true
                    end
                    return false
                end
            }
        }
    end

    local wardrobe = desktop:getElement("wardrobe")
    if wardrobe then
        wardrobe.canInteract = function(self)
            if GameState.get("level2_wardrobe_moved") then
                return false
            end
            if self.is_open and not isImpoNoteOpened(self.scene) then
                return false
            end
            return true
        end
        wardrobe.onInteract = function(self)
            if not isImpoNoteOpened(self.scene) then
                self.is_open = true
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
                self.is_open = true
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
                self.x = self.x - 24
                local card = self.scene:getElement("card")
                if card then card.visible = true end
                local doc = self.scene:getElement("doc")
                if doc then doc.visible = true end
            end
        end
    end

    local function setupPic(pid, img_path)
        local p = desktop:getElement(pid)
        if p then
            p.flipped = false
            p.canInteract = function(self)
                return not self.flipped
            end
            p.onInteract = function(self)
                self.flipped = true
                GameState.set("level2_" .. pid .. "_flipped", true)
            end
            p.draw = function(self)
                if not self.my_img then
                    local ok, img = pcall(love.graphics.newImage, img_path)
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
        end
    end

    setupPic("pic1", "assets/level2/pic_1.png")
    setupPic("pic2", "assets/level2/pic_2.png")
    setupPic("pic3", "assets/level2/pic_3.png")

    local closet = desktop:getElement("closet")
    if closet then
        closet.opened = false
        closet.canInteract = function(self)
            return not self.opened and not self.timer
        end
        closet.onInteract = function(self)
            if self.opened then return end
            self.opened = true
            GameState.set("level2_closet_opened", true)
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
        end
        closet.update = function(self, dt)
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
    end

    local sofa = desktop:getElement("sofa")
    if sofa then
        sofa.canInteract = function(self)
            return (GameState.get("level2_facebook_vandalized") or GameState.get("level2_facebook")) and not GameState.get("level2_sofa_moved")
        end
        sofa.onInteract = function(self)
            GameState.set("level2_sofa_moved", true)
            self.x = self.x - 42
            local f = self.scene:getElement("folder")
            if f then f.visible = true end
        end
    end

    local lore_note = desktop:getElement("lore_note")
    if lore_note then
        lore_note.onClick = function(self)
            self.scene:toggleElement("lore_window")
            local win = self.scene:getElement("lore_window")
            self.scene:setElementActive("lore_note", win and win.visible)
        end
        lore_note.onInteract = function(self)
            self:onClick()
        end
    end

    local lore_win = desktop:getElement("lore_window")
    if lore_win then
        lore_win.onClose = function(self)
            local tab = self.scene:getElement("lore_note")
            if tab then
                self.scene:setElementActive("lore_note", false)
            end
        end
    end

    local pdf_text = desktop:getElement("pdf_text")
    if pdf_text then
        pdf_text.onClick = function(self)
            local cn = self.scene:getElement("card_note")
            if cn then cn.visible = true end
        end
        pdf_text.onInteract = function(self)
            self:onClick()
        end
    end

    local folder = desktop:getElement("folder")
    if folder then
        folder.canInteract = function(self)
            return not GameState.get("level2_folder_collected")
        end
        folder.onInteract = function(self)
            GameState.set("level2_folder_collected", true)
            local pt = self.scene:getElement("pdf_text")
            if pt then pt.visible = true end
            self.visible = false
        end
    end

    local card_note = desktop:getElement("card_note")
    if card_note then
        card_note.onClick = function(self)
            self.scene:toggleElement("card_window")
            local win = self.scene:getElement("card_window")
            self.scene:setElementActive("card_note", win and win.visible)
            if win and win.visible then
                GameState.set("level2_impo_note_opened", true)
            end
        end
        card_note.onInteract = function(self)
            self:onClick()
        end
    end

    local card_win = desktop:getElement("card_window")
    if card_win then
        card_win.onClose = function(self)
            local tab = self.scene:getElement("card_note")
            if tab then
                self.scene:setElementActive("card_note", false)
            end
        end
    end

    local doc = desktop:getElement("doc")
    if doc then
        doc.canInteract = function(self)
            return not GameState.get("level2_doc_collected")
        end
        doc.onInteract = function(self)
            GameState.set("level2_doc_collected", true)
            local ln = self.scene:getElement("lore_note")
            if ln then ln.visible = true end
            self.visible = false
        end
    end

    local card = desktop:getElement("card")
    if card then
        card.canInteract = function(self)
            return not GameState.get("level2_card_collected")
        end
        card.onInteract = function(self)
            GameState.set("level2_card_collected", true)
            self.visible = false
        end
    end

    local door = desktop:getElement("door")
    if door then
        door.canInteract = function(self)
            return GameState.get("level2_card_collected")
        end
        door.onInteract = function(self)
            SceneManager.crossFade("level2-2", 0.4)
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

function Level2Logic.enter(desktop, parent_scene)
    tip_timer = 6.0
    GameState.set("level2_impo_note_opened", false)
    local icon = desktop and desktop:getElement("tray_exclamation")
    if icon then icon.visible = true end
    local tip = desktop and desktop:getElement("tooltip_exclamation")
    if tip then tip.visible = true end

    local closet = desktop and desktop:getElement("closet")
    if closet then
        closet.opened = GameState.get("level2_closet_opened", false)
        closet.timer = nil
        if closet.closed_img then
            closet.img_obj = closet.closed_img
            closet.image = "assets/level2/big_wd.png"
            closet.w = closet.closed_img:getWidth()
            closet.h = closet.closed_img:getHeight()
        end
    end

    local w = desktop and desktop:getElement("wardrobe")
    if w then
        w.is_open = false
    end

    for _, pid in ipairs({ "pic1", "pic2", "pic3" }) do
        local p = desktop and desktop:getElement(pid)
        if p then
            p.flipped = GameState.get("level2_" .. pid .. "_flipped", false)
        end
    end

    if GameState.get("level2_sofa_moved") then
        local sofa = desktop and desktop:getElement("sofa")
        if sofa and sofa.x > 380 then sofa.x = sofa.x - 42 end
    end
    if GameState.get("level2_folder_collected") then
        local f = desktop and desktop:getElement("folder")
        if f then f.visible = false end
        local pt = desktop and desktop:getElement("pdf_text")
        if pt then pt.visible = true end
    end
    if GameState.get("level2_wardrobe_moved") then
        local wd = desktop and desktop:getElement("wardrobe")
        if wd and wd.x > 150 then wd.x = wd.x - 24 end
    end
    if GameState.get("level2_doc_collected") then
        local d = desktop and desktop:getElement("doc")
        if d then d.visible = false end
        local ln = desktop and desktop:getElement("lore_note")
        if ln then ln.visible = true end
    end
    if GameState.get("level2_card_collected") then
        local c = desktop and desktop:getElement("card")
        if c then c.visible = false end
    end
end

function Level2Logic.update(desktop, dt, parent_scene)
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

function Level2Logic.onKey(desktop, action, key, scancode, isrepeat)
    if action == "press" and key == "escape" then
        SceneManager.goTo("menu")
    end
end

return Level2Logic
