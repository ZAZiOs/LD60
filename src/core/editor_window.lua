local Viewport = require("src.core.viewport")

local EditorWindow = {}
EditorWindow.__index = EditorWindow

local font_title = nil
local font_ui = nil
local font_small = nil

local function initFonts()
    if not font_title and love and love.graphics and love.graphics.newFont then
        local font_path = "assets/fnt/tahomabd.ttf"
        local ok, f = pcall(love.graphics.newFont, font_path, 15)
        if ok and f then
            font_title = f
            font_ui = love.graphics.newFont(font_path, 13)
            font_small = love.graphics.newFont(font_path, 11)
        else
            font_title = love.graphics.newFont(15)
            font_ui = love.graphics.newFont(13)
            font_small = love.graphics.newFont(11)
        end
    end
end

function EditorWindow.new(opts)
    opts = opts or {}
    local self = setmetatable({}, EditorWindow)

    self.id = opts.id or ("win_" .. tostring(math.random(1000, 9999)))
    self.title = opts.title or "Window"
    self.x = opts.x or 100
    self.y = opts.y or 100
    self.w = opts.w or 320
    self.h = opts.h or 400
    self.min_w = opts.min_w or 200
    self.min_h = opts.min_h or 150
    self.visible = (opts.visible ~= false)
    self.collapsed = (opts.collapsed == true)
    self.closable = (opts.closable ~= false)
    self.minimizable = (opts.minimizable ~= false)
    self.resizable = (opts.resizable == true)
    self.scroll_y = 0
    self.content_height = 0

    self.title_h = 30
    self.dragging = false
    self.drag_ox = 0
    self.drag_oy = 0
    self.resizing = false

    self.draw_content = opts.draw_content
    self.on_mousepressed = opts.on_mousepressed
    self.on_keypressed = opts.on_keypressed

    return self
end

function EditorWindow:toggle()
    self.visible = not self.visible
end

function EditorWindow:open()
    self.visible = true
end

function EditorWindow:close()
    self.visible = false
end

function EditorWindow:toggleCollapse()
    self.collapsed = not self.collapsed
end

-- Layout state helpers
function EditorWindow:beginLayout(ix, iy, iw, ih, mx, my)
    self.cur_x = ix
    self.cur_y = iy - self.scroll_y
    self.layout_ix = ix
    self.layout_iy = iy
    self.layout_iw = iw
    self.layout_ih = ih
    self.mx = mx
    self.my = my
    self.total_content_h = 0
end

function EditorWindow:endLayout()
    self.content_height = self.total_content_h + 20
end

function EditorWindow:label(text, color, h)
    h = h or 22
    if self.cur_y + h >= self.layout_iy and self.cur_y <= self.layout_iy + self.layout_ih then
        love.graphics.setColor(color or { 0.85, 0.88, 0.92, 1 })
        if font_ui then love.graphics.setFont(font_ui) end
        love.graphics.print(text, self.cur_x, self.cur_y + 2)
    end
    self.cur_y = self.cur_y + h
    self.total_content_h = self.total_content_h + h
end

function EditorWindow:separator(h)
    h = h or 10
    local line_y = self.cur_y + math.floor(h / 2)
    if line_y >= self.layout_iy and line_y <= self.layout_iy + self.layout_ih then
        love.graphics.setColor(0.25, 0.28, 0.35, 1)
        love.graphics.line(self.cur_x, line_y, self.cur_x + self.layout_iw, line_y)
    end
    self.cur_y = self.cur_y + h
    self.total_content_h = self.total_content_h + h
end

function EditorWindow:button(text, w, h, onClick)
    w = w or self.layout_iw
    h = h or 26

    local is_hover = (self.mx >= self.cur_x and self.mx <= self.cur_x + w and self.my >= self.cur_y and self.my <= self.cur_y + h)
    local is_visible = (self.cur_y + h >= self.layout_iy and self.cur_y <= self.layout_iy + self.layout_ih)

    if is_visible then
        if is_hover then
            love.graphics.setColor(0.25, 0.45, 0.8, 1)
        else
            love.graphics.setColor(0.18, 0.22, 0.3, 0.95)
        end
        love.graphics.rectangle("fill", self.cur_x, self.cur_y, w, h, 3, 3)
        love.graphics.setColor(0.4, 0.48, 0.6, 1)
        love.graphics.rectangle("line", self.cur_x, self.cur_y, w, h, 3, 3)

        love.graphics.setColor(1, 1, 1, 1)
        if font_ui then love.graphics.setFont(font_ui) end
        local tw = font_ui and font_ui:getWidth(text) or 50
        local th = font_ui and font_ui:getHeight() or 14
        love.graphics.print(text, self.cur_x + (w - tw) / 2, self.cur_y + (h - th) / 2)
    end

    local clicked = false
    if is_hover and self.clicked_now then
        clicked = true
        if onClick then onClick() end
    end

    self.cur_y = self.cur_y + h + 6
    self.total_content_h = self.total_content_h + h + 6
    return clicked
end

function EditorWindow:checkbox(label, checked, onToggle)
    local h = 24
    local box_size = 16
    local is_hover = (self.mx >= self.cur_x and self.mx <= self.cur_x + self.layout_iw and self.my >= self.cur_y and self.my <= self.cur_y + h)
    local is_visible = (self.cur_y + h >= self.layout_iy and self.cur_y <= self.layout_iy + self.layout_ih)

    if is_visible then
        love.graphics.setColor(0.14, 0.16, 0.22, 1)
        love.graphics.rectangle("fill", self.cur_x, self.cur_y + 4, box_size, box_size, 2, 2)
        love.graphics.setColor(0.4, 0.45, 0.55, 1)
        love.graphics.rectangle("line", self.cur_x, self.cur_y + 4, box_size, box_size, 2, 2)

        if checked then
            love.graphics.setColor(0.3, 0.85, 0.4, 1)
            love.graphics.rectangle("fill", self.cur_x + 3, self.cur_y + 7, box_size - 6, box_size - 6)
        end

        love.graphics.setColor(is_hover and { 1, 1, 1, 1 } or { 0.85, 0.88, 0.92, 1 })
        if font_ui then love.graphics.setFont(font_ui) end
        love.graphics.print(label, self.cur_x + box_size + 8, self.cur_y + 3)
    end

    if is_hover and self.clicked_now then
        checked = not checked
        if onToggle then onToggle(checked) end
    end

    self.cur_y = self.cur_y + h + 4
    self.total_content_h = self.total_content_h + h + 4
    return checked
end

function EditorWindow:numberStepper(label, val, step, onValChange, min_val, max_val)
    local h = 26
    val = tonumber(val) or 0
    step = step or 1

    local is_visible = (self.cur_y + h >= self.layout_iy and self.cur_y <= self.layout_iy + self.layout_ih)

    if is_visible then
        love.graphics.setColor(0.8, 0.85, 0.9, 1)
        if font_ui then love.graphics.setFont(font_ui) end
        love.graphics.print(label, self.cur_x, self.cur_y + 4)

        local btn_w = 26
        local val_w = 80
        local start_x = self.cur_x + self.layout_iw - (btn_w * 2 + val_w + 4)

        -- Minus button
        local hover_minus = (self.mx >= start_x and self.mx <= start_x + btn_w and self.my >= self.cur_y and self.my <= self.cur_y + h)
        love.graphics.setColor(hover_minus and { 0.28, 0.35, 0.45, 1 } or { 0.18, 0.22, 0.3, 1 })
        love.graphics.rectangle("fill", start_x, self.cur_y, btn_w, h, 2, 2)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print("-", start_x + 9, self.cur_y + 4)

        if hover_minus and self.clicked_now then
            val = val - step
            if min_val and val < min_val then val = min_val end
            if onValChange then onValChange(val) end
        end

        -- Value display box
        local val_x = start_x + btn_w + 2
        love.graphics.setColor(0.12, 0.14, 0.18, 1)
        love.graphics.rectangle("fill", val_x, self.cur_y, val_w, h, 2, 2)
        love.graphics.setColor(0.35, 0.4, 0.5, 1)
        love.graphics.rectangle("line", val_x, self.cur_y, val_w, h, 2, 2)
        love.graphics.setColor(1, 1, 0.6, 1)
        local val_str = tostring(val)
        local vw = font_ui and font_ui:getWidth(val_str) or 30
        love.graphics.print(val_str, val_x + (val_w - vw) / 2, self.cur_y + 4)

        -- Plus button
        local plus_x = val_x + val_w + 2
        local hover_plus = (self.mx >= plus_x and self.mx <= plus_x + btn_w and self.my >= self.cur_y and self.my <= self.cur_y + h)
        love.graphics.setColor(hover_plus and { 0.28, 0.35, 0.45, 1 } or { 0.18, 0.22, 0.3, 1 })
        love.graphics.rectangle("fill", plus_x, self.cur_y, btn_w, h, 2, 2)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print("+", plus_x + 8, self.cur_y + 4)

        if hover_plus and self.clicked_now then
            val = val + step
            if max_val and val > max_val then val = max_val end
            if onValChange then onValChange(val) end
        end
    end

    self.cur_y = self.cur_y + h + 6
    self.total_content_h = self.total_content_h + h + 6
    return val
end

-- ==============================================================================
-- EditorWindowManager
-- ==============================================================================
local EditorWindowManager = {
    windows = {},
    active_window = nil,
    focused_input = nil
}

function EditorWindowManager.add(win)
    table.insert(EditorWindowManager.windows, win)
    return win
end

function EditorWindowManager.get(id)
    for _, w in ipairs(EditorWindowManager.windows) do
        if w.id == id then return w end
    end
    return nil
end

function EditorWindowManager.bringToFront(win)
    for i, w in ipairs(EditorWindowManager.windows) do
        if w == win then
            table.remove(EditorWindowManager.windows, i)
            table.insert(EditorWindowManager.windows, win)
            EditorWindowManager.active_window = win
            break
        end
    end
end

function EditorWindowManager.isMouseOverAnyWindow(mx, my)
    for i = #EditorWindowManager.windows, 1, -1 do
        local w = EditorWindowManager.windows[i]
        if w.visible then
            local check_h = w.collapsed and w.title_h or w.h
            if mx >= w.x and mx <= w.x + w.w and my >= w.y and my <= w.y + check_h then
                return true
            end
        end
    end
    return false
end

function EditorWindowManager.mousepressed(mx, my, button)
    for i = #EditorWindowManager.windows, 1, -1 do
        local w = EditorWindowManager.windows[i]
        if w.visible then
            local check_h = w.collapsed and w.title_h or w.h
            if mx >= w.x and mx <= w.x + w.w and my >= w.y and my <= w.y + check_h then
                EditorWindowManager.bringToFront(w)

                -- Check title bar controls
                if my <= w.y + w.title_h then
                    -- Close button [X]
                    local close_x = w.x + w.w - 24
                    if w.closable and mx >= close_x and mx <= close_x + 18 and my >= w.y + 6 and my <= w.y + 24 then
                        w:close()
                        return true
                    end

                    -- Collapse button [_]
                    local min_x = close_x - 22
                    if w.minimizable and mx >= min_x and mx <= min_x + 18 and my >= w.y + 6 and my <= w.y + 24 then
                        w:toggleCollapse()
                        return true
                    end

                    -- Start drag
                    if button == 1 then
                        w.dragging = true
                        w.drag_ox = mx - w.x
                        w.drag_oy = my - w.y
                        return true
                    end
                else
                    -- Inside window content
                    w.clicked_now = true
                    if w.on_mousepressed then
                        w:on_mousepressed(mx, my, button)
                    end
                    return true
                end
                return true
            end
        end
    end
    return false
end

function EditorWindowManager.mousemoved(mx, my, dx, dy)
    for _, w in ipairs(EditorWindowManager.windows) do
        if w.dragging then
            w.x = math.max(0, math.min(1920 - w.w, mx - w.drag_ox))
            w.y = math.max(32, math.min(1080 - w.title_h, my - w.drag_oy))
            return true
        end
    end
    return false
end

function EditorWindowManager.mousereleased(mx, my, button)
    local consumed = false
    for _, w in ipairs(EditorWindowManager.windows) do
        if w.dragging then
            w.dragging = false
            consumed = true
        end
        w.clicked_now = nil
    end
    return consumed
end

function EditorWindowManager.wheelmoved(x, y)
    local mx, my = Viewport.getMousePosition()
    for i = #EditorWindowManager.windows, 1, -1 do
        local w = EditorWindowManager.windows[i]
        if w.visible and not w.collapsed then
            if mx >= w.x and mx <= w.x + w.w and my >= w.y + w.title_h and my <= w.y + w.h then
                local step = 32
                w.scroll_y = w.scroll_y - y * step
                local max_scroll = math.max(0, (w.content_height or 0) - (w.h - w.title_h - 16))
                w.scroll_y = math.max(0, math.min(w.scroll_y, max_scroll))
                if w.on_wheelmoved then w:on_wheelmoved(x, y) end
                return true
            end
        end
    end
    return false
end

function EditorWindowManager.draw()
    initFonts()
    local mx, my = Viewport.getMousePosition()

    for _, w in ipairs(EditorWindowManager.windows) do
        if w.visible then
            local win_h = w.collapsed and w.title_h or w.h

            -- Drop Shadow
            love.graphics.setColor(0, 0, 0, 0.4)
            love.graphics.rectangle("fill", w.x + 4, w.y + 4, w.w, win_h, 4, 4)

            -- Window Frame Body
            love.graphics.setColor(0.1, 0.11, 0.15, 0.96)
            love.graphics.rectangle("fill", w.x, w.y, w.w, win_h, 4, 4)

            -- Border
            local is_active = (EditorWindowManager.active_window == w)
            if is_active then
                love.graphics.setColor(0.35, 0.45, 0.65, 1)
            else
                love.graphics.setColor(0.22, 0.25, 0.32, 1)
            end
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", w.x, w.y, w.w, win_h, 4, 4)

            -- Title Bar
            if is_active then
                love.graphics.setColor(0.18, 0.24, 0.36, 1)
            else
                love.graphics.setColor(0.14, 0.17, 0.23, 1)
            end
            love.graphics.rectangle("fill", w.x, w.y, w.w, w.title_h, 4, 4)
            love.graphics.setColor(0.28, 0.32, 0.42, 1)
            love.graphics.line(w.x, w.y + w.title_h, w.x + w.w, w.y + w.title_h)

            -- Title Text
            love.graphics.setColor(1, 1, 1, 1)
            if font_title then love.graphics.setFont(font_title) end
            love.graphics.print(w.title, w.x + 10, w.y + 6)

            -- Close Button [X]
            local close_x = w.x + w.w - 24
            local hover_close = (mx >= close_x and mx <= close_x + 18 and my >= w.y + 6 and my <= w.y + 24)
            if w.closable then
                love.graphics.setColor(hover_close and { 0.85, 0.25, 0.25, 1 } or { 0.25, 0.28, 0.35, 1 })
                love.graphics.rectangle("fill", close_x, w.y + 6, 18, 18, 2, 2)
                love.graphics.setColor(1, 1, 1, 1)
                if font_small then love.graphics.setFont(font_small) end
                love.graphics.print("X", close_x + 4, w.y + 7)
            end

            -- Minimize Button [_]
            if w.minimizable then
                local min_x = close_x - 22
                local hover_min = (mx >= min_x and mx <= min_x + 18 and my >= w.y + 6 and my <= w.y + 24)
                love.graphics.setColor(hover_min and { 0.35, 0.45, 0.6, 1 } or { 0.25, 0.28, 0.35, 1 })
                love.graphics.rectangle("fill", min_x, w.y + 6, 18, 18, 2, 2)
                love.graphics.setColor(1, 1, 1, 1)
                if font_small then love.graphics.setFont(font_small) end
                love.graphics.print(w.collapsed and "+" or "_", min_x + 4, w.y + 7)
            end

            -- Content Area (only if not collapsed)
            if not w.collapsed and w.draw_content then
                local ix = w.x + 12
                local iy = w.y + w.title_h + 8
                local iw = w.w - 24
                local ih = w.h - w.title_h - 16

                -- Scissor clip for scrolling content
                local sx, sy = Viewport.toScreen(ix, iy)
                local sw = iw * Viewport.scale
                local sh = ih * Viewport.scale

                love.graphics.push("all")
                love.graphics.setScissor(sx, sy, sw, sh)

                w:beginLayout(ix, iy, iw, ih, mx, my)
                w:draw_content(ix, iy, iw, ih, mx, my)
                w:endLayout()

                love.graphics.pop() -- restores scissor

                -- Draw scrollbar if needed
                if w.content_height and w.content_height > ih then
                    local bar_w = 4
                    local bar_x = w.x + w.w - bar_w - 4
                    love.graphics.setColor(0.18, 0.2, 0.25, 0.6)
                    love.graphics.rectangle("fill", bar_x, iy, bar_w, ih, 2, 2)

                    local max_scroll = w.content_height - ih
                    local thumb_h = math.max(20, (ih / w.content_height) * ih)
                    local thumb_y = iy + (w.scroll_y / max_scroll) * (ih - thumb_h)
                    love.graphics.setColor(0.45, 0.55, 0.75, 0.9)
                    love.graphics.rectangle("fill", bar_x, thumb_y, bar_w, thumb_h, 2, 2)
                end
            end
        end
    end
end

return {
    Window = EditorWindow,
    Manager = EditorWindowManager
}
