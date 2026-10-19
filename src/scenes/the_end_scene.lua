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

local dev_credits = {
    { title = "Game Design",            name = "Sasik" },
    { title = "Character Designs",      name = "Lazarus517" },
    { title = "Vector Graphics",        name = "Sasik" },
    { title = "Pixel Graphics",         name = "Lazarus517, Sasik" },
    { title = "Music",                  name = "Zakuro (тёмыч)" },
    { title = "Core lib and main code", name = "ZAZiOs" },
    { title = "Shaders and platformer", name = "comprock15" },
    { title = "Levels building",        name = "imRy0, creepy0964" },
}

local FADE_STEPS = { 0.20, 0.40, 0.60, 0.80, 1.00 }
local STEP_DURATION = 0.12

local credits_content = {
    state = "scroll", -- "scroll", "stepped_fade", "jingle", "shutdown", "done"
    scroll_y = -240,
    SPEED = 35,
    max_scroll_y = 810,
    is_good_end = false,
    items = {},

    stepped_timer = 0,
    fade_alpha = 0,

    fade_wait_timer = 0,
    fade_wait_duration = 2.0,

    jingle_timer = 0,
    bad_jingle_duration = 15.0,
    good_jingle_duration = 10.0,

    disconnect_timer = 0,
    disconnect_duration = 0.65,

    black_timer = 0,
    black_duration = 0.4
}

function credits_content:initConditions()
    local correct = GameState.get("correct_bookshelves_exploded", 0)
    local wrong = GameState.get("wrong_bookshelves_exploded", 0)
    local eye_killed = GameState.get("eye_killed", false)
    local total_shelves = correct + wrong

    -- Good Ending: Killed the eye OR destroyed all 13 bookshelves
    self.is_good_end = eye_killed or (total_shelves >= 13)

    local p1 = GameState.get("level2_pic1_flipped", false)
    local p2 = GameState.get("level2_pic2_flipped", false)
    local p3 = GameState.get("level2_pic3_flipped", false)
    local all_pics_flipped = p1 and p2 and p3

    local closet_opened = GameState.get("level2_closet_opened", false)
    local facebook_vandalized = GameState.get("level2_facebook_vandalized", false)
    local coin_collected = GameState.get("level2_3_coin_collected", false)

    self.items = {
        {
            title = all_pics_flipped and "GALLERY INVERTED" or "GALLERY UNTOUCHED",
            desc = all_pics_flipped and "You turned every single painting upside down in the director's office."
                                    or "You left the director's paintings hanging straight on the walls.",
            image = "assets/level2/pic_1.png",
            flipped_y = all_pics_flipped
        },
        {
            title = closet_opened and "WARDROBE SECRET" or "SEALED WARDROBE",
            desc = closet_opened and "You opened the tall wardrobe and uncovered the horrifying secret inside."
                                 or "You walked past the tall wardrobe without ever discovering its dark secret.",
            image = closet_opened and "assets/level2/big_wd_o.png" or "assets/level2/big_wd.png"
        },
        {
            title = facebook_vandalized and "YOURSPACE SLANDER" or "CIVIL BROWSING",
            desc = facebook_vandalized and "You hijacked the terminal and posted a nasty comment on yourSpace."
                                       or "You refrained from posting toxic insults on the director's profile.",
            image = "assets/level2/facebook.png"
        },
        {
            title = coin_collected and "COIN COLLECTED" or "COIN IGNORED",
            desc = coin_collected and "You picked up the coin-looking thing in the transmission section."
                                  or "You left the coin-looking thing in the transmission section.",
            image = "assets/coin_credits.png"
        },
        {
            title = eye_killed and "ADMINISTRATOR PURGED" or "ADMINISTRATOR SPARED",
            desc = eye_killed and "You detonated high explosives and permanently eliminated the Administrator Eye."
                              or "You followed instructions carefully and left the Administrator Eye unharmed.",
            image = "assets/level3/eye.png",
            is_eye = true
        }
    }
    self.max_scroll_y = #self.items * 100 + 310
end

function credits_content:enter()
    --Settings.set("soundcheck_enabled", true)
    Settings.set("soundcheck_enabled", false)
    self:initConditions()
    self.state = "scroll"
    self.scroll_y = -240
    self.stepped_timer = 0
    self.fade_alpha = 0
    self.fade_wait_timer = 0
    self.jingle_timer = 0
    self.disconnect_timer = 0
    self.black_timer = 0

    local soundtrack = "_end_credits"
    if self.is_good_end then soundtrack = "good" .. soundtrack else soundtrack = "bad" .. soundtrack end

    AudioManager.musFadeTo(soundtrack, 0.75, 0.5)
end

function credits_content:leave()
    AudioManager.musStop(0.3)
end

function credits_content:startEnding()
    if self.state ~= "scroll" then return end
    AudioManager.musStop(2.0)
    self.state = "fade_wait"
    self.fade_wait_timer = 0
end

function credits_content:startJingle()
    if self.state ~= "stepped_fade" then return end
    self.state = "jingle"
    self.fade_alpha = 1.0
    self.jingle_timer = 0
    local jingle_id = self.is_good_end and "good_end" or "bad_end"
    AudioManager.musPlay(jingle_id, 0.85)
end

function credits_content:startShutdown()
    if self.state == "shutdown" or self.state == "black" or self.state == "done" then return end
    AudioManager.musStop(0)
    if AudioManager and AudioManager.sfxPlay then
        pcall(AudioManager.sfxPlay, "shutdown")
    end
    self.state = "shutdown"
    self.disconnect_timer = 0
end

function credits_content:update(dt)
    if self.state == "scroll" then
        local fast = love.keyboard.isDown("space") or love.keyboard.isDown("return") or love.mouse.isDown(1)
        local cur_speed = fast and (self.SPEED * 4) or self.SPEED
        self.scroll_y = self.scroll_y + cur_speed * dt
        if self.scroll_y >= self.max_scroll_y then
            self:startEnding()
        end

    elseif self.state == "fade_wait" then
        self.fade_wait_timer = self.fade_wait_timer + dt
        if self.fade_wait_timer >= self.fade_wait_duration then
            self.state = "stepped_fade"
            self.stepped_timer = 0
            self.fade_alpha = FADE_STEPS[1]
        end

    elseif self.state == "stepped_fade" then
        self.stepped_timer = self.stepped_timer + dt
        local step_idx = math.floor(self.stepped_timer / STEP_DURATION) + 1
        if step_idx > #FADE_STEPS then
            self.fade_alpha = 1.0
            self:startJingle()
        else
            self.fade_alpha = FADE_STEPS[step_idx]
        end

    elseif self.state == "jingle" then
        self.jingle_timer = self.jingle_timer + dt
        local target_duration = self.is_good_end and self.good_jingle_duration or self.bad_jingle_duration
        if self.jingle_timer >= target_duration then
            self:startShutdown()
        end

    elseif self.state == "shutdown" then
        self.disconnect_timer = self.disconnect_timer + dt
        if self.disconnect_timer >= self.disconnect_duration then
            self.state = "black"
            self.black_timer = 0
        end

    elseif self.state == "black" then
        self.black_timer = self.black_timer + dt
        if self.black_timer >= self.black_duration then
            self.state = "done"
            SceneManager.fadeTo("menu", 0.8)
        end
    end
end

function credits_content:drawConditionItem(item, y)
    if y + 80 < 0 or y > 240 then return end

    local f_title = getTitleFont()
    local f_reg = getRegularFont()
    local f_tag = getTagFont()

    local img = getImage(item.image)
    if img then
        local img_cx = 42
        local img_cy = y + 36
        local max_w, max_h = 44, 48
        local scale = 1
        local sw, sh
        if item.is_eye then
            sw, sh = 48, 48
            scale = 1.0
            local dw, dh = sw * scale, sh * scale
            local dx = math.floor(img_cx - dw / 2)
            local dy = math.floor(img_cy - dh / 2)
            love.graphics.setColor(1, 1, 1, 1)
            local q = getEyeQuad()
            love.graphics.draw(img, q, dx, dy, 0, scale, scale)
        else
            sw, sh = img:getDimensions()
            if sw <= 32 and sh <= 32 then
                scale = 1.5
            elseif sw > max_w or sh > max_h then
                scale = math.min(max_w / sw, max_h / sh)
            end
            local dw = math.floor(sw * scale)
            local dh = math.floor(sh * scale)
            local dx = math.floor(img_cx - dw / 2)
            local dy = math.floor(img_cy - dh / 2)
            love.graphics.setColor(1, 1, 1, 1)
            if item.flipped_y then
                love.graphics.draw(img, dx, dy + dh, 0, scale, -scale)
            else
                love.graphics.draw(img, dx, dy, 0, scale, scale)
            end
        end
    end

    local tx = 74
    local tw = 230

    love.graphics.setFont(f_title)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(item.title or "", tx, y + 15)

    love.graphics.setColor(0.35, 0.35, 0.35, 0.8)
    love.graphics.line(tx, y + 29, tx + 40, y + 29)

    love.graphics.setFont(f_reg)
    love.graphics.setColor(0.88, 0.88, 0.88, 1)
    love.graphics.printf(item.desc or "", tx, y + 33, tw, "left")
end

function credits_content:drawDevCredits(start_y)
    local f_title = getTitleFont()
    local f_reg = getRegularFont()

    local header_y = start_y
    if header_y >= -20 and header_y <= 240 then
        love.graphics.setFont(f_title)
        love.graphics.setColor(1, 1, 1, 1)
        local header = "THE END"
        local hw = f_title:getWidth(header)
        love.graphics.print(header, math.floor((320 - hw) / 2), header_y)
    end

    local cx = 150
    local list_start_y = start_y + 24
    local line_h = 16

    love.graphics.setFont(f_reg)
    for i, item in ipairs(dev_credits) do
        local y = list_start_y + (i - 1) * line_h
        if y >= -16 and y <= 240 then
            love.graphics.setColor(0.65, 0.65, 0.65, 1)
            local rw = f_reg:getWidth(item.title)
            love.graphics.print(item.title, cx - 8 - rw, y)

            love.graphics.setColor(0.3, 0.3, 0.3, 0.8)
            love.graphics.print("|", cx - 2, y)

            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.print(item.name, cx + 8, y)
        end
    end
end

function credits_content:draw()
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("fill", 0, 0, 320, 240)

    if self.state == "scroll" or self.state == "fade_wait" then
        for i, item in ipairs(self.items) do
            local item_y = (i - 1) * 100 - self.scroll_y
            self:drawConditionItem(item, item_y)
        end

        local credits_start_y = (#self.items * 100 + 30) - self.scroll_y
        self:drawDevCredits(credits_start_y)

    elseif self.state == "stepped_fade" or self.state == "jingle" or self.state == "shutdown" then
        local img_path = self.is_good_end and "assets/good_end.png" or "assets/bad_end.png"
        local img = getImage(img_path)
        if img then
            local alpha = (self.state == "stepped_fade") and self.fade_alpha or 1.0
            love.graphics.setColor(1, 1, 1, alpha)
            love.graphics.draw(img, 0, 0)
        end
    end
end

function credits_content:keypressed(key)
    if key == "escape" then
        if self.state == "scroll" then
            self:startEnding()
        elseif self.state == "fade_wait" then
            AudioManager.musStop(0)
            self.state = "stepped_fade"
            self.stepped_timer = 0
            self.fade_alpha = FADE_STEPS[1]
        elseif self.state == "stepped_fade" or self.state == "jingle" then
            self:startShutdown()
        elseif self.state == "shutdown" or self.state == "black" then
            self.state = "done"
            SceneManager.fadeTo("menu", 0.5)
        end
    elseif key == "space" or key == "return" then
        if self.state == "jingle" then
            self:startShutdown()
        end
    end
end

function credits_content:mousepressed(gx, gy, button)
    if button == 1 or button == 2 then
        if self.state == "jingle" then
            self:startShutdown()
        end
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
    bg = "assets/bg/the_end_bg.png",
    screen = screen,
    screen_draw_fn = function(s)
        if credits_content.state == "shutdown" then
            local dur = credits_content.disconnect_duration or 0.65
            local t_collapse = 0.38
            local t = credits_content.disconnect_timer or 0

            if t < t_collapse then
                local p = t / t_collapse
                p = math.min(1.0, p)
                local p_eased = p * p * p

                local cur_h = math.max(4, s.h * (1 - p_eased))
                local cur_y = (s.y + s.h / 2) - cur_h / 2
                local cur_scale_y = (cur_h / s.h) * s.scale_y

                love.graphics.setColor(0.02, 0.03, 0.04, 1)
                love.graphics.rectangle("fill", s.x, s.y, s.w, s.h)

                Effects.drawCrt(s.canvas, s.x, cur_y, s.scale_x, cur_scale_y)

                local flash_alpha = p_eased * 0.95
                if flash_alpha > 0.01 then
                    love.graphics.setBlendMode("add")
                    love.graphics.setColor(0.75, 0.9, 1.0, flash_alpha)
                    love.graphics.rectangle("fill", s.x, cur_y, s.w, cur_h)

                    love.graphics.setColor(1, 1, 1, flash_alpha * 0.9)
                    love.graphics.rectangle("fill", s.x, s.y + s.h / 2 - 1, s.w, 2)
                    love.graphics.setBlendMode("alpha")
                end
            else
                local p = (t - t_collapse) / (dur - t_collapse)
                p = math.min(1.0, math.max(0, p))
                local p_inv = 1 - p
                local p_eased = p_inv * p_inv

                local cx = s.x + s.w / 2
                local cy = s.y + s.h / 2
                local beam_w = math.max(4, s.w * p_eased)

                love.graphics.setColor(0.02, 0.03, 0.04, 1)
                love.graphics.rectangle("fill", s.x, s.y, s.w, s.h)

                love.graphics.setColor(0.3, 0.75, 1.0, 0.7 * p_inv)
                love.graphics.rectangle("fill", cx - beam_w / 2, cy - 4, beam_w, 8)

                love.graphics.setColor(1, 1, 1, p_inv)
                love.graphics.rectangle("fill", cx - beam_w / 2, cy - 1, beam_w, 2)

                local spot_r = math.max(1, 6 * p_eased)
                love.graphics.circle("fill", cx, cy, spot_r)
            end
        elseif credits_content.state == "black" or credits_content.state == "done" then
            love.graphics.setColor(0, 0, 0, 1)
            love.graphics.rectangle("fill", s.x, s.y, s.w, s.h)
        else
            Effects.drawCrt(s.canvas, s.x, s.y, s.scale_x, s.scale_y)
        end
    end,
    on_bg_click = function(self, vx, vy, button)
        if credits_content.state == "jingle" then
            credits_content:startShutdown()
        end
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
