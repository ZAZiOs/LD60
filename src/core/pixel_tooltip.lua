local I18n = require("src.core.i18n")

local PixelTooltip = {}
PixelTooltip.__index = PixelTooltip

function PixelTooltip.new(opts)
    opts = opts or {}
    local self = setmetatable({}, PixelTooltip)

    self.id = opts.id or "tooltip"
    self.text = opts.text or ""
    self.visible = (opts.visible ~= false)
    self.z_index = opts.z_index or 2000
    self.clickable = (opts.clickable ~= false)
    self.onClick = opts.onClick

    self.padding_x = opts.padding_x or opts.padding or 3
    self.padding_y = opts.padding_y or opts.padding or 2
    self.line_spacing = opts.line_spacing or 1

    self.bg_color = opts.bg_color or { 1, 1, 1, 1 }
    self.text_color = opts.text_color or { 0, 0, 0, 1 }

    self.target_id = opts.target_id or opts.target
    self.target_x = opts.target_x
    self.target_y = opts.target_y
    self.target_anchor_x = opts.target_anchor_x or 2
    self.target_anchor_y = opts.target_anchor_y or 0

    self.x = opts.x or 36
    self.y = opts.y or 168

    self.tail_width = opts.tail_width or 7
    self.tail_offset_x = opts.tail_offset_x or 26

    self.font = opts.font
    self:_recalculate()

    return self
end

function PixelTooltip:_getFont()
    if self.font then return self.font end
    if I18n and I18n.fonts and I18n.fonts.tahoma9 then
        return I18n.fonts.tahoma9
    end
    if I18n and I18n.getFont then
        local f = I18n.getFont("tahoma9")
        if f then return f end
    end
    if love and love.graphics and love.graphics.newFont then
        local ok, f = pcall(love.graphics.newFont, "assets/fnt/tahoma.ttf", 9, "mono")
        if ok and f then
            f:setFilter("nearest", "nearest")
            self.font = f
            return f
        end
    end
    return love.graphics.getFont()
end

function PixelTooltip:setText(text)
    self.text = text or ""
    self:_recalculate()
end

function PixelTooltip:_recalculate()
    local font = self:_getFont()
    self.lines = {}
    local max_w = 0
    if font and self.text then
        for line in string.gmatch(self.text .. "\n", "([^\n]*)\n") do
            table.insert(self.lines, line)
            local lw = font:getWidth(line)
            if lw > max_w then max_w = lw end
        end
    end
    if #self.lines == 0 then
        table.insert(self.lines, self.text or "")
        if font then
            max_w = font:getWidth(self.text or "")
        end
    end

    local font_h = font and font:getHeight() or 9
    local text_h = #self.lines * font_h + math.max(0, #self.lines - 1) * self.line_spacing

    self.box_w = math.max(max_w + self.padding_x * 2, 20)
    self.box_h = math.max(text_h + self.padding_y * 2, 10)
    self.w = self.box_w
    self.h = self.box_h
end

function PixelTooltip:draw()
    if not self.visible then return end

    local font = self:_getFont()
    if not font then return end

    if not self.box_w or not self.lines or #self.lines == 0 then
        self:_recalculate()
    end

    local tx = self.target_x
    local ty = self.target_y
    if not tx or not ty then
        if self.target_id and self.scene then
            local target = self.scene:getElement(self.target_id)
            if target and target.visible then
                tx = target.x + (self.target_anchor_x or 2)
                ty = target.y + (self.target_anchor_y or 0)
            end
        end
    end

    local bx = math.floor(self.x + 0.5)
    local by = math.floor(self.y + 0.5)
    local bw = self.box_w
    local bh = self.box_h

    if tx and ty then
        local t_left = bx + (self.tail_offset_x or 26)
        local t_right = t_left + (self.tail_width or 7)
        local b_bottom = by + bh

        love.graphics.setColor(self.bg_color)
        love.graphics.polygon("fill",
            t_left, b_bottom,
            t_left, b_bottom + 4,
            tx, ty,
            tx + 1, ty,
            t_right, b_bottom
        )
    end

    love.graphics.setColor(self.bg_color)
    love.graphics.rectangle("fill", bx, by, bw, bh)

    local prev_font = love.graphics.getFont()
    love.graphics.setFont(font)
    love.graphics.setColor(self.text_color)
    local cur_y = by + self.padding_y
    for _, line in ipairs(self.lines) do
        love.graphics.print(line, bx + self.padding_x, cur_y)
        cur_y = cur_y + font:getHeight() + self.line_spacing
    end
    if prev_font then
        love.graphics.setFont(prev_font)
    end
end

return PixelTooltip
