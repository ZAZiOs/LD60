local SpritesheetManager = require("src.core.spritesheet_manager")
local I18n = require("src.core.i18n")

local PixelWindow = {}
PixelWindow.__index = PixelWindow

local function drawPart(sheet, name, px, py, sx, sy)
    local quad = sheet:getQuad(name)
    if quad and sheet.image then
        love.graphics.draw(sheet.image, quad, px, py, 0, sx or 1, sy or 1, 0, 0)
    end
end

local function wrapText(font, text, max_w)
    local lines = {}
    if not text or text == "" then return lines end
    for paragraph in (text .. "\n"):gmatch("(.-)\r?\n") do
        if paragraph == "" then
            table.insert(lines, "")
        else
            if font and font.getWrap then
                local _, wrapped = font:getWrap(paragraph, max_w)
                if wrapped and #wrapped > 0 then
                    for _, l in ipairs(wrapped) do
                        table.insert(lines, l)
                    end
                else
                    table.insert(lines, paragraph)
                end
            else
                table.insert(lines, paragraph)
            end
        end
    end
    return lines
end

function PixelWindow.new(opts)
    opts = opts or {}
    local self = setmetatable({}, PixelWindow)

    self.id = opts.id or "window"
    self.x = opts.x or 40
    self.y = opts.y or 40
    self.w = math.max(30, opts.w or 160)
    self.h = math.max(24, opts.h or 120)

    self.inner_w = math.max(1, self.w - 8)
    self.inner_h = math.max(1, self.h - 14)

    self.sheet_path = opts.sheet or "assets/window.ini"
    self.sheet = SpritesheetManager.getSheet(self.sheet_path)

    self.title = opts.title or "Window"
    self.visible = (opts.visible == true)
    self.is_window = true
    self.clickable = (opts.clickable ~= false)
    self.is_solid = (opts.is_solid == true)
    self.fixed = (opts.fixed == true)
    self.scene = opts.scene
    self.z_index = opts.z_index or (self.fixed and 1050 or 100)

    self.closeable = (opts.closeable ~= false)
    self.draggable = (opts.draggable ~= false)
    self.onClose = opts.onClose
    self.draw_content = opts.draw_content
    self.on_content_click = opts.on_content_click

    self.text = opts.text or ""
    self.lines = {}
    self.line_height = opts.line_height or 10

    self.elements = {}
    self.elements_by_id = {}

    self.scroll_y = 0
    self.max_scroll = 0

    self.dragging = false
    self.drag_offset_x = 0
    self.drag_offset_y = 0

    self.dragging_scrollbar = false
    self.scrollbar_drag_y = 0

    self.canvas = nil
    self:_initCanvas()

    if opts.elements then
        for _, el in ipairs(opts.elements) do
            self:addElement(el)
        end
    end

    self:_reflowText()

    return self
end

function PixelWindow:_getFont()
    return (I18n and I18n.fonts and I18n.fonts.tahoma9) or (love.graphics and love.graphics.getFont and love.graphics.getFont())
end

function PixelWindow:_initCanvas()
    if love and love.graphics and love.graphics.newCanvas then
        self.canvas = love.graphics.newCanvas(self.inner_w, self.inner_h)
        self.canvas:setFilter("nearest", "nearest")
    end
end

function PixelWindow:getCanvas()
    if not self.canvas then
        self:_initCanvas()
    end
    return self.canvas
end

function PixelWindow:addElement(el)
    if not el then return self end
    table.insert(self.elements, el)
    if el.id then
        self.elements_by_id[el.id] = el
    end
    self:_updateContentHeight()
    return el
end

function PixelWindow:getElement(id)
    return self.elements_by_id[id]
end

function PixelWindow:addButton(opts)
    opts = opts or {}
    local font = self:_getFont()
    local btn = {
        id = opts.id,
        x = opts.x or 0,
        y = opts.y or 0,
        w = opts.w or (font and font:getWidth(opts.text or "Button") + 8) or 40,
        h = opts.h or 12,
        text = opts.text or "Button",
        onClick = opts.onClick,
        is_pressed = false,
        visible = (opts.visible ~= false)
    }

    function btn:draw(win)
        local bx, by, bw, bh = self.x, self.y, self.w, self.h
        love.graphics.setColor(0.8, 0.78, 0.78, 1)
        love.graphics.rectangle("fill", bx, by, bw, bh)

        if self.is_pressed then
            love.graphics.setColor(0.3, 0.3, 0.33, 1)
            love.graphics.rectangle("fill", bx, by, bw, 1)
            love.graphics.rectangle("fill", bx, by, 1, bh)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.rectangle("fill", bx + bw - 1, by, 1, bh)
            love.graphics.rectangle("fill", bx, by + bh - 1, bw, 1)
        else
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.rectangle("fill", bx, by, bw, 1)
            love.graphics.rectangle("fill", bx, by, 1, bh)
            love.graphics.setColor(0.3, 0.3, 0.33, 1)
            love.graphics.rectangle("fill", bx + bw - 1, by, 1, bh)
            love.graphics.rectangle("fill", bx, by + bh - 1, bw, 1)
        end

        local f = win:_getFont()
        if f then
            love.graphics.setFont(f)
            love.graphics.setColor(0.12, 0.12, 0.15, 1)
            local tw = f:getWidth(self.text)
            local th = f:getHeight()
            local off = self.is_pressed and 1 or 0
            local tx = bx + math.floor((bw - tw) / 2) + off
            local ty = by + math.floor((bh - th) / 2) + off
            love.graphics.print(self.text, tx, ty)
        end
    end

    function btn:mousepressed(cx, cy, button)
        if button == 1 and cx >= self.x and cx < self.x + self.w and cy >= self.y and cy < self.y + self.h then
            self.is_pressed = true
            return true
        end
        return false
    end

    function btn:mousereleased(cx, cy, button)
        if self.is_pressed then
            self.is_pressed = false
            if cx >= self.x and cx < self.x + self.w and cy >= self.y and cy < self.y + self.h then
                if self.onClick then
                    self:onClick()
                end
            end
        end
    end

    return self:addElement(btn)
end

function PixelWindow:addCheckbox(opts)
    opts = opts or {}
    local cb = {
        id = opts.id,
        x = opts.x or 0,
        y = opts.y or 0,
        text = opts.text or "",
        checked = (opts.checked == true),
        onChange = opts.onChange,
        visible = (opts.visible ~= false)
    }

    function cb:draw(win)
        local bx = self.x
        local by = self.y + 1
        local bs = 8

        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("fill", bx, by, bs, bs)

        love.graphics.setColor(0.35, 0.35, 0.38, 1)
        love.graphics.rectangle("fill", bx, by, bs, 1)
        love.graphics.rectangle("fill", bx, by, 1, bs)
        love.graphics.setColor(0.9, 0.9, 0.9, 1)
        love.graphics.rectangle("fill", bx + bs - 1, by, 1, bs)
        love.graphics.rectangle("fill", bx, by + bs - 1, bs, 1)

        if self.checked then
            love.graphics.setColor(0.12, 0.12, 0.15, 1)
            love.graphics.rectangle("fill", bx + 2, by + 2, 2, 2)
            love.graphics.rectangle("fill", bx + 3, by + 3, 2, 2)
            love.graphics.rectangle("fill", bx + 4, by + 4, 2, 2)
            love.graphics.rectangle("fill", bx + 4, by + 2, 2, 2)
            love.graphics.rectangle("fill", bx + 2, by + 4, 2, 2)
        end

        local f = win:_getFont()
        if f and self.text ~= "" then
            love.graphics.setFont(f)
            love.graphics.setColor(0.12, 0.12, 0.15, 1)
            love.graphics.print(self.text, bx + 12, self.y)
        end
    end

    function cb:mousepressed(cx, cy, button)
        if button == 1 then
            local f = love.graphics.getFont()
            local tw = f and f:getWidth(self.text) or 60
            if cx >= self.x and cx <= self.x + 14 + tw and cy >= self.y and cy <= self.y + 10 then
                self.checked = not self.checked
                if self.onChange then
                    self:onChange(self.checked)
                end
                return true
            end
        end
        return false
    end

    return self:addElement(cb)
end

function PixelWindow:addSlider(opts)
    opts = opts or {}
    local slider = {
        id = opts.id,
        x = opts.x or 0,
        y = opts.y or 0,
        w = opts.w or 100,
        label = opts.label or "Volume",
        min = opts.min or 0,
        max = opts.max or 1,
        value = opts.value or 0.5,
        onChange = opts.onChange,
        dragging = false,
        visible = (opts.visible ~= false)
    }

    function slider:draw(win)
        local f = win:_getFont()
        if f then
            love.graphics.setFont(f)
            love.graphics.setColor(0.12, 0.12, 0.15, 1)
            local range = math.max(0.0001, self.max - self.min)
            local pct = math.floor(((self.value - self.min) / range) * 100)
            local lbl = self.label .. ": " .. pct .. "%"
            love.graphics.print(lbl, self.x, self.y)
        end

        local track_y = self.y + 11
        local track_h = 3
        love.graphics.setColor(0.35, 0.35, 0.38, 1)
        love.graphics.rectangle("fill", self.x, track_y, self.w, track_h)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("fill", self.x, track_y + track_h - 1, self.w, 1)
        love.graphics.rectangle("fill", self.x + self.w - 1, track_y, 1, track_h)

        local range = math.max(0.0001, self.max - self.min)
        local ratio = math.max(0, math.min(1, (self.value - self.min) / range))
        local knob_w = 6
        local knob_h = 9
        local knob_x = self.x + math.floor((self.w - knob_w) * ratio)
        local knob_y = track_y - 3

        love.graphics.setColor(0.8, 0.78, 0.78, 1)
        love.graphics.rectangle("fill", knob_x, knob_y, knob_w, knob_h)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("fill", knob_x, knob_y, knob_w, 1)
        love.graphics.rectangle("fill", knob_x, knob_y, 1, knob_h)
        love.graphics.setColor(0.3, 0.3, 0.33, 1)
        love.graphics.rectangle("fill", knob_x + knob_w - 1, knob_y, 1, knob_h)
        love.graphics.rectangle("fill", knob_x, knob_y + knob_h - 1, knob_w, 1)
    end

    function slider:_updateFromX(cx)
        local knob_w = 6
        local ratio = math.max(0, math.min(1, (cx - self.x - knob_w / 2) / (self.w - knob_w)))
        local new_val = self.min + ratio * (self.max - self.min)
        if math.abs(new_val - self.value) > 0.001 then
            self.value = new_val
            if self.onChange then
                self:onChange(self.value)
            end
        end
    end

    function slider:mousepressed(cx, cy, button)
        if button == 1 then
            if cx >= self.x - 2 and cx <= self.x + self.w + 2 and cy >= self.y + 7 and cy <= self.y + 17 then
                self.dragging = true
                self:_updateFromX(cx)
                return true
            end
        end
        return false
    end

    function slider:mousemoved(cx, cy, gdx, gdy)
        if self.dragging then
            self:_updateFromX(cx)
        end
    end

    function slider:mousereleased(cx, cy, button)
        self.dragging = false
    end

    return self:addElement(slider)
end

function PixelWindow:addLabel(opts)
    opts = opts or {}
    local label = {
        id = opts.id,
        x = opts.x or 0,
        y = opts.y or 0,
        text = opts.text or "",
        color = opts.color or {0.12, 0.12, 0.15, 1},
        visible = (opts.visible ~= false)
    }

    function label:draw(win)
        local f = win:_getFont()
        if f and self.text ~= "" then
            love.graphics.setFont(f)
            love.graphics.setColor(self.color[1], self.color[2], self.color[3], self.color[4] or 1)
            love.graphics.print(self.text, self.x, self.y)
        end
    end

    return self:addElement(label)
end

function PixelWindow:_updateContentHeight()
    local total_h = #self.lines * self.line_height
    for _, el in ipairs(self.elements) do
        local ey = (el.y or 0) + (el.h or 14)
        if ey > total_h then
            total_h = ey
        end
    end
    self.max_scroll = math.max(0, total_h - self.inner_h)
    self.scroll_y = math.max(0, math.min(self.scroll_y, self.max_scroll))
end

function PixelWindow:_reflowText()
    local font = self:_getFont()
    local text_w = math.max(10, self.inner_w - 10)
    self.lines = wrapText(font, self.text, text_w)
    self:_updateContentHeight()
end

function PixelWindow:setText(new_text)
    self.text = new_text or ""
    self:_reflowText()
end

function PixelWindow:setScroll(val)
    self.scroll_y = math.max(0, math.min(self.max_scroll, val or 0))
end

function PixelWindow:close()
    self.visible = false
    self.dragging = false
    self.dragging_scrollbar = false
    for _, el in ipairs(self.elements) do
        if el.dragging ~= nil then el.dragging = false end
        if el.is_pressed ~= nil then el.is_pressed = false end
    end
    if self.onClose then
        self:onClose()
    end
end

function PixelWindow:_renderCanvas()
    if not self.canvas then
        self:_initCanvas()
        if not self.canvas then return end
    end

    local font = self:_getFont()

    love.graphics.push("all")
    love.graphics.setCanvas(self.canvas)
    love.graphics.origin()
    love.graphics.setScissor()
    love.graphics.clear(0, 0, 0, 0)

    love.graphics.push()
    love.graphics.translate(0, -self.scroll_y)

    if self.draw_content then
        self:draw_content(self.canvas, self.inner_w, self.inner_h)
    end

    if #self.lines > 0 and font then
        love.graphics.setFont(font)
        love.graphics.setColor(0.12, 0.12, 0.15, 1)
        local start_idx = math.max(1, math.floor(self.scroll_y / self.line_height) + 1)
        local end_idx = math.min(#self.lines, math.ceil((self.scroll_y + self.inner_h) / self.line_height) + 1)
        for i = start_idx, end_idx do
            local ly = (i - 1) * self.line_height
            love.graphics.print(self.lines[i], 0, ly)
        end
    end

    for _, el in ipairs(self.elements) do
        if el.visible ~= false and el.draw then
            love.graphics.setColor(1, 1, 1, 1)
            el:draw(self)
        end
    end

    love.graphics.pop()
    love.graphics.setCanvas()
    love.graphics.pop()
end

function PixelWindow:draw()
    if not self.visible then return end
    if not self.sheet or not self.sheet.image then
        self.sheet = SpritesheetManager.getSheet(self.sheet_path)
        if not self.sheet or not self.sheet.image then return end
    end

    if #self.lines == 0 and self.text ~= "" then
        self:_reflowText()
    end

    local x = self.x
    local y = self.y
    local w = self.w
    local h = self.h
    local sheet = self.sheet

    love.graphics.setColor(1, 1, 1, 1)

    drawPart(sheet, "bg", x + 2, y + 10, w - 4, h - 12)

    drawPart(sheet, "corner_tl", x, y, 1, 1)
    drawPart(sheet, "title_mid", x + 3, y, w - 5, 1)
    drawPart(sheet, "corner_tr", x + w - 2, y, 1, 1)

    if self.closeable then
        drawPart(sheet, "btn_close", x + w - 9, y + 1, 1, 1)
    end

    drawPart(sheet, "border_left", x, y + 10, 1, h - 12)
    drawPart(sheet, "border_right", x + w - 2, y + 10, 1, h - 12)

    drawPart(sheet, "corner_bl", x, y + h - 2, 1, 1)
    drawPart(sheet, "border_bottom", x + 2, y + h - 2, w - 4, 1)
    drawPart(sheet, "corner_br", x + w - 2, y + h - 2, 1, 1)

    self:_renderCanvas()

    if self.canvas then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(self.canvas, x + 4, y + 12)
    end

    local font = self:_getFont()
    if font and self.title and self.title ~= "" then
        love.graphics.setFont(font)
        love.graphics.setColor(1, 1, 1, 1)
        local title_limit = self.closeable and (w - 14) or (w - 6)
        local cam_x = (not self.fixed and self.scene and self.scene.camera and self.scene.camera.x) or 0
        local cam_y = (not self.fixed and self.scene and self.scene.camera and self.scene.camera.y) or 0
        local sx = math.floor(x + 4 - cam_x)
        local sy = math.floor(y - cam_y)
        local old_sx, old_sy, old_sw, old_sh = love.graphics.getScissor()
        love.graphics.setScissor(sx, sy, title_limit, 10)
        love.graphics.print(self.title, x + 4, y)
        love.graphics.setScissor(old_sx, old_sy, old_sw, old_sh)
    end

    if self.max_scroll > 0 then
        local sb_w = 5
        local sb_x = x + w - 8
        local sb_y = y + 12
        local sb_h = self.inner_h

        love.graphics.setColor(0.8, 0.78, 0.78, 1)
        love.graphics.rectangle("fill", sb_x, sb_y, sb_w, sb_h)

        local total_h = self.inner_h + self.max_scroll
        local thumb_h = math.max(8, math.floor(sb_h * (sb_h / total_h)))
        local thumb_travel = sb_h - thumb_h
        local thumb_y = sb_y + math.floor(thumb_travel * (self.scroll_y / self.max_scroll))

        love.graphics.setColor(0.72, 0.7, 0.7, 1)
        love.graphics.rectangle("fill", sb_x, thumb_y, sb_w, thumb_h)

        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("fill", sb_x, thumb_y, sb_w, 1)
        love.graphics.rectangle("fill", sb_x, thumb_y, 1, thumb_h)

        love.graphics.setColor(0.35, 0.35, 0.38, 1)
        love.graphics.rectangle("fill", sb_x + sb_w - 1, thumb_y, 1, thumb_h)
        love.graphics.rectangle("fill", sb_x, thumb_y + thumb_h - 1, sb_w, 1)
    end
end

function PixelWindow:mousepressed(gx, gy, button)
    if not self.visible or button ~= 1 then return false end

    if self.closeable then
        local btn_x = self.x + self.w - 9
        local btn_y = self.y + 1
        if gx >= btn_x and gx < btn_x + 7 and gy >= btn_y and gy < btn_y + 8 then
            self:close()
            return true
        end
    end

    if self.max_scroll > 0 then
        local sb_w = 5
        local sb_x = self.x + self.w - 8
        local sb_y = self.y + 12
        local sb_h = self.inner_h
        if gx >= sb_x - 1 and gx <= sb_x + sb_w + 1 and gy >= sb_y and gy <= sb_y + sb_h then
            self.dragging_scrollbar = true
            local ratio = math.max(0, math.min(1, (gy - sb_y) / sb_h))
            self.scroll_y = math.floor(ratio * self.max_scroll)
            return true
        end
    end

    if self.draggable and gy >= self.y and gy < self.y + 10 then
        self.dragging = true
        self.drag_offset_x = gx - self.x
        self.drag_offset_y = gy - self.y
        return true
    end

    local inner_x = self.x + 4
    local inner_y = self.y + 12
    if gx >= inner_x and gx < inner_x + self.inner_w and gy >= inner_y and gy < inner_y + self.inner_h then
        local cx = gx - inner_x
        local cy = gy - inner_y + self.scroll_y
        for i = #self.elements, 1, -1 do
            local el = self.elements[i]
            if el.visible ~= false and el.mousepressed then
                local handled = el:mousepressed(cx, cy, button)
                if handled ~= false then
                    return true
                end
            end
        end
        if self.on_content_click then
            self:on_content_click(cx, cy, button)
        end
        return true
    end

    return true
end

function PixelWindow:mousereleased(gx, gy, button)
    self.dragging = false
    self.dragging_scrollbar = false

    local inner_x = self.x + 4
    local inner_y = self.y + 12
    local cx = gx - inner_x
    local cy = gy - inner_y + self.scroll_y

    for i = #self.elements, 1, -1 do
        local el = self.elements[i]
        if el.mousereleased then
            el:mousereleased(cx, cy, button)
        end
    end
end

function PixelWindow:mousemoved(gx, gy, gdx, gdy)
    if self.dragging then
        self.x = math.floor(gx - self.drag_offset_x)
        self.y = math.floor(gy - self.drag_offset_y)
        local max_w = self.fixed and 300 or ((self.scene and self.scene.room_width and (self.scene.room_width - 20)) or 300)
        local max_h = self.fixed and 214 or ((self.scene and self.scene.room_height and (self.scene.room_height - 26)) or 214)
        self.x = math.max(-self.w + 20, math.min(max_w, self.x))
        self.y = math.max(0, math.min(max_h, self.y))
    elseif self.dragging_scrollbar and self.max_scroll > 0 then
        local sb_y = self.y + 12
        local sb_h = self.inner_h
        local ratio = math.max(0, math.min(1, (gy - sb_y) / sb_h))
        self.scroll_y = math.floor(ratio * self.max_scroll)
    end

    local inner_x = self.x + 4
    local inner_y = self.y + 12
    local cx = gx - inner_x
    local cy = gy - inner_y + self.scroll_y

    for i = #self.elements, 1, -1 do
        local el = self.elements[i]
        if el.mousemoved then
            el:mousemoved(cx, cy, gdx, gdy)
        end
    end
end

function PixelWindow:wheelmoved(x, y)
    if not self.visible or self.max_scroll <= 0 then return false end
    self.scroll_y = math.max(0, math.min(self.max_scroll, self.scroll_y - y * (self.line_height * 2)))
    return true
end

return PixelWindow
