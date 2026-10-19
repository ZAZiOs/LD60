local SceneManager = require("src.core.scene_manager")
local PixelScreen = require("src.core.pixel_screen")
local GameScene = require("src.core.game_scene")
local GameState = require("src.core.game_state")
local Effects = require("src.core.effects")
local I18n = require("src.core.i18n")
local AudioManager = require("src.core.audio_manager")
local Settings = require("src.core.settings")

local font_title = nil
local font_regular = nil
local font_tag = nil

local function getTitleFont()
    if not font_title then
        font_title = I18n.getFont({
            path = "assets/fnt/tahomabd.ttf",
            size = 11,
            hinting = "mono",
            filter = "nearest"
        })
    end
    return font_title
end

local function getRegularFont()
    if not font_regular then
        font_regular = I18n.getFont({
            path = "assets/fnt/tahoma.ttf",
            size = 9,
            hinting = "mono",
            filter = "nearest"
        })
    end
    return font_regular
end

local function getTagFont()
    if not font_tag then
        font_tag = I18n.getFont({
            path = "assets/fnt/tahomabd.ttf",
            size = 9,
            hinting = "mono",
            filter = "nearest"
        })
    end
    return font_tag
end

local image_cache = {}
local function getImage(path)
    if not path then return nil end
    if not image_cache[path] then
        local ok, img = pcall(love.graphics.newImage, path)
        if ok and img then
            img:setFilter("nearest", "nearest")
            image_cache[path] = img
        end
    end
    return image_cache[path]
end

local eye_quad = nil
local function getEyeQuad()
    if not eye_quad then
        eye_quad = love.graphics.newQuad(0, 0, 48, 48, 144, 48)
    end
    return eye_quad
end

local credits_content = {
    slides = {},
    current_index = 1,
    timer = 0,
    is_transitioning = false,
    trans_timer = 0,
    DISPLAY_TIME = 4.2,
    TRANS_TIME = 0.8,
    CREDITS_TIME = 10.0
}

local dev_credits = {
    { title = "Game Design",            name = "Sasik" },
    { title = "Character Designs",      name = "Lazarus" },
    { title = "Vector Graphics",        name = "Sasik" },
    { title = "Pixel Graphics",         name = "Lazarus, Sasik" },
    { title = "Music",                  name = "Zakuro" },
    { title = "Main code",              name = "ZAZiOs" },
    { title = "Shaders and platformer", name = "Comprock15" },
    { title = "Levels building",        name = "imRy0, creepy0964" },
}

function credits_content:buildSlides()
    local crowbar = GameState.get("level1_crowbar_collected", false)
    local note = GameState.get("level1_note_collected", false)
    local door_hacked = GameState.get("level1_2_door_opened", false)
    local wrong = GameState.get("wrong_bookshelves_exploded", 0)
    local eye_killed = GameState.get("eye_killed", false)

    self.slides = {
        {
            layout = "img_left",
            tag = "CHAPTER 01 // SECTOR A",
            title = crowbar and "THE CROWBAR" or "UNTOUCHED VENT",
            desc = crowbar and "You scavenged the rusted crowbar and broke through the vent shaft."
                           or "You slipped past without ever touching the crowbar or the vent.",
            image = crowbar and "assets/level1/fomka.png" or "assets/level1/vent_c.png"
        },
        {
            layout = "img_right",
            tag = "CHAPTER 01 // SECRETS",
            title = note and "ENCRYPTED MEMO" or "SEALED CHEST",
            desc = note and "You opened the locked chest and retrieved the hacker's secret note."
                        or "The forgotten chest and its hidden message remained sealed.",
            image = note and "assets/level1/note.png" or "assets/level1/chest_closed.png"
        },
        {
            layout = "img_left",
            tag = "CHAPTER 02 // MAINFRAME",
            title = door_hacked and "ROOT OVERRIDE" or "FIREWALL BYPASS",
            desc = door_hacked and "Executed exploit CVE-8921 to override the magnetic gateway."
                               or "Infiltrated through the secondary security corridor.",
            image = door_hacked and "assets/level1/sublv2/terminal_enter.png" or "assets/level1/sublv2/terminal_bg.png"
        },
        {
            layout = "img_right",
            tag = "CHAPTER 03 // ARCHIVE",
            title = (wrong == 0) and "SURGICAL STRIKE" or "COLLATERAL DAMAGE",
            desc = (wrong == 0) and "You destroyed only the 3 designated bomb racks with zero collateral damage."
                                or string.format("You blew up %d wrong bookshelves in the heat of the mission.", wrong),
            image = (wrong == 0) and "assets/level3/bookshelf1.png" or "assets/level3/bookshelf_boom_boom.png"
        },
        {
            layout = "img_left",
            tag = "CHAPTER 03 // OBSERVER",
            title = eye_killed and "ANTIVIRUS PURGED" or "GHOST PROTOCOL",
            desc = eye_killed and "You defied all warnings and permanently eliminated the Eye Antivirus."
                              or "You respected the warnings and slipped past the Eye undetected.",
            image = "assets/level3/eye.png",
            is_eye = true
        },
        {
            is_credits = true
        }
    }
end

function credits_content:enter()
    Settings.set("soundcheck_enabled", true)
    self:buildSlides()
    self.current_index = 1
    self.timer = 0
    self.is_transitioning = false
    self.trans_timer = 0
    AudioManager.musFadeTo("crt", 0.75, 0.8)
end

function credits_content:leave()
    AudioManager.musStop(0.5)
end

function credits_content:startTransition()
    if self.current_index < #self.slides and not self.is_transitioning then
        self.is_transitioning = true
        self.trans_timer = 0
    end
end

function credits_content:nextSlide()
    local current_slide = self.slides[self.current_index]
    if current_slide and current_slide.is_credits then
        SceneManager.crossFade("menu", 0.5)
        return
    end
    if self.current_index < #self.slides then
        self.is_transitioning = false
        self.trans_timer = 0
        self.current_index = self.current_index + 1
        self.timer = 0
    end
end

function credits_content:update(dt)
    local current_slide = self.slides[self.current_index]
    if not current_slide then return end

    if current_slide.is_credits then
        self.timer = self.timer + dt
        if self.timer >= self.CREDITS_TIME then
            SceneManager.crossFade("menu", 0.8)
        end
        return
    end

    if self.is_transitioning then
        self.trans_timer = self.trans_timer + dt
        if self.trans_timer >= self.TRANS_TIME then
            self.is_transitioning = false
            self.trans_timer = 0
            self.current_index = self.current_index + 1
            self.timer = 0
        end
    else
        self.timer = self.timer + dt
        if self.timer >= self.DISPLAY_TIME then
            self:startTransition()
        end
    end
end

function credits_content:drawSlide(slide, base_y)
    if not slide then return end
    if slide.is_credits then
        self:drawDevCredits(base_y)
        return
    end

    local f_title = getTitleFont()
    local f_reg = getRegularFont()
    local f_tag = getTagFont()

    local img = getImage(slide.image)
    local is_left = (slide.layout == "img_left")

    local img_cx = is_left and 75 or 245
    local img_cy = base_y + 120

    if img then
        local max_w = 90
        local max_h = 100
        local scale = 1
        local sw, sh
        if slide.is_eye then
            sw, sh = 48, 48
            scale = 1.3
        else
            sw, sh = img:getDimensions()
            if sw <= 40 and sh <= 40 then
                scale = 2
            elseif sw > max_w or sh > max_h then
                scale = math.min(max_w / sw, max_h / sh)
            end
        end

        local dw = sw * scale
        local dh = sh * scale
        local dx = math.floor(img_cx - dw / 2)
        local dy = math.floor(img_cy - dh / 2)

        love.graphics.setColor(1, 1, 1, 1)
        if slide.is_eye then
            local q = getEyeQuad()
            love.graphics.draw(img, q, dx, dy, 0, scale, scale)
        else
            love.graphics.draw(img, dx, dy, 0, scale, scale)
        end
    end

    local text_x = is_left and 145 or 20
    local text_w = 155
    local text_y = base_y + 68

    love.graphics.setFont(f_tag)
    love.graphics.setColor(0.55, 0.55, 0.55, 1)
    love.graphics.print(slide.tag or "", text_x, text_y)

    love.graphics.setFont(f_title)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(slide.title or "", text_x, text_y + 14)

    love.graphics.setColor(0.35, 0.35, 0.35, 1)
    love.graphics.line(text_x, text_y + 29, text_x + 36, text_y + 29)

    love.graphics.setFont(f_reg)
    love.graphics.setColor(0.9, 0.9, 0.9, 1)
    love.graphics.printf(slide.desc or "", text_x, text_y + 36, text_w, "left")
end

function credits_content:drawDevCredits(base_y)
    local f_title = getTitleFont()
    local f_reg = getRegularFont()

    local cx = 152
    local start_y = base_y + 54
    local line_h = 16

    love.graphics.setFont(f_title)
    love.graphics.setColor(1, 1, 1, 1)
    local header = "THE END"
    local hw = f_title:getWidth(header)
    love.graphics.print(header, math.floor((320 - hw) / 2), base_y + 26)

    love.graphics.setFont(f_reg)
    for i, item in ipairs(dev_credits) do
        local y = start_y + (i - 1) * line_h

        love.graphics.setColor(0.68, 0.68, 0.68, 1)
        local rw = f_reg:getWidth(item.title)
        love.graphics.print(item.title, cx - 8 - rw, y)

        love.graphics.setColor(0.3, 0.3, 0.3, 0.8)
        love.graphics.print("|", cx - 2, y)

        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(item.name, cx + 8, y)
    end

    if self.timer >= 4.0 then
        local alpha = math.min(1.0, (self.timer - 4.0) / 2.0)
        love.graphics.setColor(0.45, 0.45, 0.45, alpha)
        local hint = "[ Press ESC to return to menu ]"
        local tw = f_reg:getWidth(hint)
        love.graphics.print(hint, math.floor((320 - tw) / 2), base_y + 204)
    end
end

function credits_content:draw()
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("fill", 0, 0, 320, 240)

    local cur = self.slides[self.current_index]
    if not cur then return end

    if self.is_transitioning then
        local p = math.min(1.0, self.trans_timer / self.TRANS_TIME)
        local offset_y = 0
        if p < 0.22 then
            local q = p / 0.22
            offset_y = -14 * math.sin(q * math.pi / 2)
        else
            local q = (p - 0.22) / 0.78
            local ease = q * q * (3 - 2 * q)
            offset_y = -14 * (1 - ease) + 240 * ease
        end

        local nxt = self.slides[self.current_index + 1]
        self:drawSlide(cur, -offset_y)
        if nxt then
            self:drawSlide(nxt, 240 - offset_y)
        end
    else
        self:drawSlide(cur, 0)
    end
end

function credits_content:keypressed(key)
    if key == "escape" then
        SceneManager.crossFade("menu", 0.5)
    elseif key == "space" or key == "return" or key == "right" or key == "e" then
        self:nextSlide()
    end
end

function credits_content:mousepressed(gx, gy, button)
    if button == 1 or button == 2 then
        self:nextSlide()
    end
end

local screen = PixelScreen.new({
    game = credits_content,
    x = 320,
    y = 60,
    w = 1280,
    h = 960
})

local TheEndScene = GameScene.new({
    bg = "assets/bg/intro_bg.png",
    screen = screen,
    screen_draw_fn = function(s)
        Effects.drawCrt(s.canvas, s.x, s.y, s.scale_x, s.scale_y)
    end,
    on_bg_click = function(self, vx, vy, button)
        credits_content:nextSlide()
    end,
    enter = function(self)
        if credits_content.enter then
            credits_content:enter()
        end
    end,
    leave = function(self)
        if credits_content.leave then
            credits_content:leave()
        end
    end
})

return TheEndScene
