local SceneManager = require("src.core.scene_manager")
local PixelScreen = require("src.core.pixel_screen")
local GameScene = require("src.core.game_scene")
local Effects = require("src.core.effects")
local I18n = require("src.core.i18n")
local SpritesheetManager = require("src.core.spritesheet_manager")

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
    mouse_inside = false
}

function menu_content:refreshOptions()
    local start_text = "Start Game"

    local quit_text = "Quit"

    self.options = {
        { id = "start", text = start_text },
        { id = "quit",  text = quit_text }
    }
end

function menu_content:enter()
    print("Entered Menu")
    self.selected = 1
    self.blink_timer = 0
    self.cursor_frame = "cursor"
    self.mouse_inside = false
    self:refreshOptions()
    if not self.cursor_sheet then
        self.cursor_sheet = SpritesheetManager.getSheet("assets/cursor.ini")
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
        SceneManager.crossFade("level1", 0.2)
    elseif opt.id == "quit" then
        love.event.quit()
    end
end

function menu_content:keypressed(key)
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
    local title = "tech_plague"
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
    local start_y = 96
    local gap = 10

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

            local prefix = "  "
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
        Effects.drawCrt(s.canvas, s.x, s.y, s.scale_x, s.scale_y)
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

