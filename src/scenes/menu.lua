local SceneManager = require("src.core.scene_manager")
local PixelScreen = require("src.core.pixel_screen")
local GameScene = require("src.core.game_scene")
local Effects = require("src.core.effects")
local I18n = require("src.core.i18n")
local SpritesheetManager = require("src.core.spritesheet_manager")
local AudioManager = require("src.core.audio_manager")
local Settings = require("src.core.settings")

local menu_has_booted = false

local font_title = nil
local font_bold = nil
local font_regular = nil

local function getTitleFont()
    if not font_title then
        font_title = I18n.getFont({
            path = "assets/fnt/tahomabd.ttf",
            size = 14,
            hinting = "mono",
            filter = "nearest"
        })
    end
    return font_title
end

local function getBoldFont()
    if not font_bold then
        font_bold = I18n.getFont({
            path = "assets/fnt/tahomabd.ttf",
            size = 10,
            hinting = "mono",
            filter = "nearest"
        })
    end
    return font_bold
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

local menu_content = {
    selected = 1,
    options = {},
    blink_timer = 0,
    item_bounds = {},
    cursor_sheet = nil,
    cursor_frame = "cursor",
    mouse_gx = 0,
    mouse_gy = 0,
    mouse_inside = false,

    power_state = "off",     -- "off" | "powering_on" | "on"
    power_timer = 0,
    power_duration = 0.32
}

function menu_content:refreshOptions()
    local start_text = "run"
    local soundcheck_text = "soundcheck"
    local quit_text = "exit"

    self.options = {
        { id = "start", text = start_text }
    }

    if Settings.get("soundcheck_enabled") then
        table.insert(self.options, { id = "soundcheck", text = soundcheck_text })
    end

    table.insert(self.options, { id = "quit", text = quit_text })
end

function menu_content:turnOn()
    if self.power_state ~= "off" then return end
    self.power_state = "powering_on"
    self.power_timer = 0
    menu_has_booted = true
    AudioManager.musPlay("crt")
end

function menu_content:enter()
    print("Entered Menu")
    SceneManager.resetGame()
    self.selected = 1
    self.blink_timer = 0
    self.cursor_frame = "cursor"
    self.mouse_inside = false
    self:refreshOptions()
    if not self.cursor_sheet then
        self.cursor_sheet = SpritesheetManager.getSheet("assets/cursor.ini")
    end

    if menu_has_booted then
        self.power_state = "on"
        AudioManager.musPlay("crt")
    else
        self.power_state = "off"
        self.power_timer = 0
    end

    if love and love.mouse then
        love.mouse.setVisible(true)
    end
end

function menu_content:leave()
    print("Leaving Menu")
    self.mouse_inside = false
    if love and love.mouse then
        love.mouse.setVisible(true)
    end
end

function menu_content:update(dt)
    self.blink_timer = self.blink_timer + dt

    if self.power_state == "powering_on" then
        self.power_timer = self.power_timer + dt
        if self.power_timer >= self.power_duration then
            self.power_state = "on"
        end
    end
end

function menu_content:selectNext()
    self.selected = self.selected + 1
    if self.selected > #self.options then
        self.selected = 1
    end
end

function menu_content:selectPrev()
    self.selected = self.selected - 1
    if self.selected < 1 then
        self.selected = #self.options
    end
end

function menu_content:confirm()
    local opt = self.options[self.selected]
    if not opt then return end
    if opt.id == "start" then
        SceneManager.resetGame()
        SceneManager.goTo("level0")
    elseif opt.id == "soundcheck" then
        SceneManager.crossFade("soundcheck", 0.4)
    elseif opt.id == "quit" then
        love.event.quit()
    end
end

function menu_content:keypressed(key)
    if self.power_state == "off" then
        self:turnOn()
        return
    elseif self.power_state == "powering_on" then
        return
    end

    if key == "up" or key == "w" then
        self:selectPrev()
    elseif key == "down" or key == "s" then
        self:selectNext()
    elseif key == "return" or key == "kpenter" or key == "space" then
        self:confirm()
    elseif key == "tab" then
        I18n.toggleLocale()
        self:refreshOptions()
    end
end

function menu_content:mousemoved(gx, gy, gdx, gdy, istouch, inside)
    self.mouse_gx = gx
    self.mouse_gy = gy
    self.mouse_inside = inside

    if self.power_state ~= "on" then
        if love and love.mouse then
            love.mouse.setVisible(true)
        end
        return
    end

    if love and love.mouse then
        love.mouse.setVisible(not inside)
    end

    local hovered = false
    if inside then
        for i, b in ipairs(self.item_bounds) do
            if gx >= b.x and gx <= b.x + b.w and gy >= b.y and gy <= b.y + b.h then
                self.selected = i
                hovered = true
                break
            end
        end
    end
    self.cursor_frame = hovered and "pointer" or "cursor"
end

function menu_content:mousepressed(gx, gy, button)
    if self.power_state == "off" then
        self:turnOn()
        return true
    elseif self.power_state == "powering_on" then
        return true
    end

    if button == 1 then
        for i, b in ipairs(self.item_bounds) do
            if gx >= b.x and gx <= b.x + b.w and gy >= b.y and gy <= b.y + b.h then
                self.selected = i
                self:confirm()
                return true
            end
        end
    end
end

function menu_content:draw()
    love.graphics.setColor(0.04, 0.05, 0.08, 1)
    love.graphics.rectangle("fill", 0, 0, 320, 240)

    love.graphics.setColor(0.12, 0.16, 0.22, 0.8)
    love.graphics.rectangle("line", 6, 6, 308, 228)

    local f_title = getTitleFont()
    local f_bold = getBoldFont()
    local f_reg = getRegularFont()

    love.graphics.setFont(f_title)
    local title = "mr_havoc"
    local tw = f_title:getWidth(title)
    love.graphics.setColor(0.92, 0.95, 1, 1)
    love.graphics.print(title, math.floor((320 - tw) / 2), 32)

    love.graphics.setFont(f_reg)
    local sub = "v1.0 [LD60 version]"
    local sw = f_reg:getWidth(sub)
    love.graphics.setColor(0.42, 0.58, 0.72, 1)
    love.graphics.print(sub, math.floor((320 - sw) / 2), 52)

    love.graphics.setColor(0.18, 0.24, 0.32, 0.9)
    love.graphics.line(24, 68, 296, 68)

    love.graphics.setFont(f_bold)
    local item_w = 150
    local item_h = 22
    local item_x = math.floor((320 - item_w) / 2)
    local count = #self.options
    local start_y = count > 2 and 84 or 96
    local gap = count > 2 and 8 or 10

    self.item_bounds = {}

    for i, opt in ipairs(self.options) do
        local item_y = start_y + (i - 1) * (item_h + gap)
        self.item_bounds[i] = { x = item_x, y = item_y, w = item_w, h = item_h }

        local is_sel = (i == self.selected)

        if is_sel then
            love.graphics.setColor(0.15, 0.35, 0.65, 0.9)
            love.graphics.rectangle("fill", item_x, item_y, item_w, item_h)
            love.graphics.setColor(0.4, 0.7, 1.0, 1)
            love.graphics.rectangle("line", item_x, item_y, item_w, item_h)

            local prefix = "> "
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.print(prefix .. opt.text, item_x + 10, item_y + 5)
        else
            love.graphics.setColor(0.08, 0.11, 0.16, 0.5)
            love.graphics.rectangle("fill", item_x, item_y, item_w, item_h)
            love.graphics.setColor(0.16, 0.22, 0.3, 0.6)
            love.graphics.rectangle("line", item_x, item_y, item_w, item_h)

            love.graphics.setColor(0.65, 0.7, 0.76, 1)
            love.graphics.print("  " .. opt.text, item_x + 10, item_y + 5)
        end
    end

    love.graphics.setFont(f_reg)
    love.graphics.setColor(0.42, 0.48, 0.56, 1)
    local hint = "Use [UP] / [DOWN] to select, [ENTER] to confirm"
    local hw = f_reg:getWidth(hint)
    love.graphics.print(hint, math.floor((320 - hw) / 2), 186)

    if DEBUG then
        love.graphics.setColor(0.85, 0.3, 0.3, 1)
        local dbg = "DEBUG mode is ON! Switch rooms with [ and ]"
        local dw = f_reg:getWidth(dbg)
        love.graphics.print(dbg, math.floor((320 - dw) / 2), 206)
    end

    -- Draw retro pixel cursor inside monitor
    if self.mouse_inside and self.cursor_sheet then
        love.graphics.setColor(1, 1, 1, 1)
        self.cursor_sheet:drawFrame(self.cursor_frame or "cursor", self.mouse_gx, self.mouse_gy, 0, 1, 1, 0, 0)
    end
end

local bg_path = "assets/bg/main_menu.png"

local screen = PixelScreen.new({
    game = menu_content,
    x = 320,
    y = 60,
    w = 1280,
    h = 960
})

local MenuScene = GameScene.new({
    bg = bg_path,
    screen = screen,
    screen_draw_fn = function(s)
        if menu_content.power_state == "off" then
            love.graphics.setColor(0.02, 0.03, 0.04, 1)
            love.graphics.rectangle("fill", s.x, s.y, s.w, s.h)

            local alpha = 0.35 + 0.35 * math.sin(menu_content.blink_timer * 4)
            love.graphics.setColor(0.4, 0.65, 0.85, alpha)
            local f = getBoldFont()
            love.graphics.setFont(f)
            local txt = "[ CLICK TO POWER ON ]"
            local scale = 3
            local tw = f:getWidth(txt) * scale
            local th = f:getHeight() * scale
            love.graphics.print(txt, s.x + math.floor((s.w - tw) / 2), s.y + math.floor((s.h - th) / 2), 0, scale, scale)

        elseif menu_content.power_state == "powering_on" then
            local t = menu_content.power_timer
            local dur = menu_content.power_duration

            local t_beam = 0.08
            if t < t_beam then
                -- Phase 1: Horizontal beam flaring out from center
                local p = t / t_beam
                local p_eased = 1 - (1 - p) * (1 - p)

                local cx = s.x + s.w / 2
                local cy = s.y + s.h / 2
                local beam_w = math.max(8, s.w * p_eased)

                love.graphics.setColor(0.02, 0.03, 0.04, 1)
                love.graphics.rectangle("fill", s.x, s.y, s.w, s.h)

                -- Outer cyan glow
                love.graphics.setColor(0.3, 0.75, 1.0, 0.6)
                love.graphics.rectangle("fill", cx - beam_w / 2, cy - 4, beam_w, 8)

                -- Inner bright white core
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.rectangle("fill", cx - beam_w / 2, cy - 1, beam_w, 2)

                -- Central bright spark
                local spot_r = 5 * (1 - p) + 1
                love.graphics.circle("fill", cx, cy, spot_r)

            else
                -- Phase 2: Vertical expansion of the CRT screen
                local p = (t - t_beam) / (dur - t_beam)
                p = math.min(1.0, p)
                local p_eased = 1 - (1 - p) * (1 - p) * (1 - p)

                local cur_h = math.max(6, s.h * p_eased)
                local cur_y = (s.y + s.h / 2) - cur_h / 2
                local cur_scale_y = (cur_h / s.h) * s.scale_y

                -- Dark background behind expanding screen
                love.graphics.setColor(0.02, 0.03, 0.04, 1)
                love.graphics.rectangle("fill", s.x, s.y, s.w, s.h)

                -- Draw compressed canvas through CRT shader
                Effects.drawCrt(s.canvas, s.x, cur_y, s.scale_x, cur_scale_y)

                -- Intense white/blue phosphor bloom flash
                local flash_alpha = (1.0 - p) * (1.0 - p) * 0.95
                if flash_alpha > 0.01 then
                    love.graphics.setBlendMode("add")
                    love.graphics.setColor(0.75, 0.9, 1.0, flash_alpha)
                    love.graphics.rectangle("fill", s.x, cur_y, s.w, cur_h)

                    -- Center horizontal line
                    love.graphics.setColor(1, 1, 1, flash_alpha * 0.8)
                    love.graphics.rectangle("fill", s.x, s.y + s.h / 2 - 1, s.w, 2)
                    love.graphics.setBlendMode("alpha")
                end
            end
        else
            Effects.drawCrt(s.canvas, s.x, s.y, s.scale_x, s.scale_y)
        end
    end,
    on_bg_click = function(self, vx, vy, button)
        if button == 1 and menu_content.power_state == "off" then
            menu_content:turnOn()
        end
    end,
    enter = function(self)
        if menu_content.enter then
            menu_content:enter()
        end
    end,
    leave = function(self)
        if menu_content.leave then
            menu_content:leave()
        end
    end
})

return MenuScene

