local SceneManager = require("src.core.scene_manager")
local Viewport = require("src.core.viewport")
local LevelLoader = require("src.core.level_loader")

local LevelSelector = {
    is_open = false,
    items = {},
    selected_index = 1,
    hover_index = nil,
    scroll_y = 0,
    font_title = nil,
    font_item = nil,
    font_small = nil,

    box_w = 720,
    box_h = 760,
    item_h = 44
}

function LevelSelector.init()
    if not LevelSelector.font_title and love and love.graphics and love.graphics.newFont then
        local font_path = "assets/fnt/tahomabd.ttf"
        local ok, f = pcall(love.graphics.newFont, font_path, 20)
        if ok and f then
            LevelSelector.font_title = f
            LevelSelector.font_item = love.graphics.newFont(font_path, 16)
            LevelSelector.font_small = love.graphics.newFont(font_path, 13)
        else
            LevelSelector.font_title = love.graphics.newFont(20)
            LevelSelector.font_item = love.graphics.newFont(16)
            LevelSelector.font_small = love.graphics.newFont(13)
        end
    end
end

function LevelSelector.refresh()
    LevelSelector.init()
    LevelSelector.items = {}

    local all_scenes = SceneManager.getRegisteredScenes()
    local ini_levels = {}
    for _, name in ipairs(LevelLoader.registered_levels or {}) do
        ini_levels[name] = true
    end

    for _, name in ipairs(all_scenes) do
        local cat = ini_levels[name] and "INI LEVEL" or "BUILT-IN"
        table.insert(LevelSelector.items, {
            name = name,
            category = cat
        })
    end

    local cur = SceneManager.getCurrentName()
    LevelSelector.selected_index = 1
    for i, it in ipairs(LevelSelector.items) do
        if it.name == cur then
            LevelSelector.selected_index = i
            break
        end
    end

    LevelSelector.scrollToIndex(LevelSelector.selected_index)
end

function LevelSelector.isOpen()
    return LevelSelector.is_open
end

function LevelSelector.open()
    LevelSelector.is_open = true
    LevelSelector.refresh()
end

function LevelSelector.close()
    LevelSelector.is_open = false
end

function LevelSelector.toggle()
    if LevelSelector.is_open then
        LevelSelector.close()
    else
        LevelSelector.open()
    end
end

function LevelSelector.scrollToIndex(idx)
    local list_h = LevelSelector.box_h - 100
    local target_y = (idx - 1) * LevelSelector.item_h
    if target_y < LevelSelector.scroll_y then
        LevelSelector.scroll_y = target_y
    elseif target_y + LevelSelector.item_h > LevelSelector.scroll_y + list_h then
        LevelSelector.scroll_y = target_y + LevelSelector.item_h - list_h
    end
    LevelSelector.clampScroll()
end

function LevelSelector.clampScroll()
    local list_h = LevelSelector.box_h - 100
    local total_h = #LevelSelector.items * LevelSelector.item_h
    local max_scroll = math.max(0, total_h - list_h)
    LevelSelector.scroll_y = math.max(0, math.min(LevelSelector.scroll_y, max_scroll))
end

function LevelSelector.selectAndGo(idx)
    local item = LevelSelector.items[idx]
    if item then
        LevelSelector.close()
        SceneManager.goTo(item.name)
    end
end

function LevelSelector.keypressed(key)
    if not LevelSelector.is_open then return false end

    if key == "f1" or key == "escape" then
        LevelSelector.close()
        return true
    elseif key == "up" or key == "w" then
        LevelSelector.selected_index = math.max(1, LevelSelector.selected_index - 1)
        LevelSelector.scrollToIndex(LevelSelector.selected_index)
        return true
    elseif key == "down" or key == "s" then
        LevelSelector.selected_index = math.min(#LevelSelector.items, LevelSelector.selected_index + 1)
        LevelSelector.scrollToIndex(LevelSelector.selected_index)
        return true
    elseif key == "pageup" then
        LevelSelector.selected_index = math.max(1, LevelSelector.selected_index - 10)
        LevelSelector.scrollToIndex(LevelSelector.selected_index)
        return true
    elseif key == "pagedown" then
        LevelSelector.selected_index = math.min(#LevelSelector.items, LevelSelector.selected_index + 10)
        LevelSelector.scrollToIndex(LevelSelector.selected_index)
        return true
    elseif key == "return" or key == "space" then
        LevelSelector.selectAndGo(LevelSelector.selected_index)
        return true
    end

    return true
end

function LevelSelector.wheelmoved(x, y)
    if not LevelSelector.is_open then return false end
    LevelSelector.scroll_y = LevelSelector.scroll_y - y * (LevelSelector.item_h * 2)
    LevelSelector.clampScroll()
    return true
end

function LevelSelector.mousepressed(vx, vy, button)
    if not LevelSelector.is_open then return false end

    local box_x = (1920 - LevelSelector.box_w) / 2
    local box_y = (1080 - LevelSelector.box_h) / 2
    local list_x = box_x + 16
    local list_y = box_y + 80
    local list_w = LevelSelector.box_w - 32
    local list_h = LevelSelector.box_h - 96

    -- Click outside box closes overlay
    if vx < box_x or vx > box_x + LevelSelector.box_w or vy < box_y or vy > box_y + LevelSelector.box_h then
        LevelSelector.close()
        return true
    end

    if button == 1 then
        if vx >= list_x and vx <= list_x + list_w and vy >= list_y and vy <= list_y + list_h then
            local rel_y = (vy - list_y) + LevelSelector.scroll_y
            local idx = math.floor(rel_y / LevelSelector.item_h) + 1
            if idx >= 1 and idx <= #LevelSelector.items then
                LevelSelector.selected_index = idx
                LevelSelector.selectAndGo(idx)
                return true
            end
        end
    end

    return true
end

function LevelSelector.draw()
    if not LevelSelector.is_open then return end

    LevelSelector.init()

    -- 1. Dim full screen
    love.graphics.setColor(0, 0, 0, 0.65)
    love.graphics.rectangle("fill", 0, 0, 1920, 1080)

    -- 2. Modal Window frame
    local box_x = (1920 - LevelSelector.box_w) / 2
    local box_y = (1080 - LevelSelector.box_h) / 2
    local list_x = box_x + 16
    local list_y = box_y + 80
    local list_w = LevelSelector.box_w - 32
    local list_h = LevelSelector.box_h - 96

    -- Panel background
    love.graphics.setColor(0.1, 0.11, 0.14, 0.96)
    love.graphics.rectangle("fill", box_x, box_y, LevelSelector.box_w, LevelSelector.box_h)

    -- Panel outer border
    love.graphics.setColor(0.35, 0.4, 0.5, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", box_x, box_y, LevelSelector.box_w, LevelSelector.box_h)

    -- Header bar
    love.graphics.setColor(0.16, 0.2, 0.28, 1)
    love.graphics.rectangle("fill", box_x, box_y, LevelSelector.box_w, 64)
    love.graphics.setColor(0.3, 0.35, 0.45, 1)
    love.graphics.line(box_x, box_y + 64, box_x + LevelSelector.box_w, box_y + 64)

    -- Header text
    love.graphics.setColor(1, 1, 1, 1)
    if LevelSelector.font_title then
        love.graphics.setFont(LevelSelector.font_title)
    end
    love.graphics.print("LEVEL SELECTOR [DEBUG]", box_x + 20, box_y + 12)

    love.graphics.setColor(0.7, 0.75, 0.8, 1)
    if LevelSelector.font_small then
        love.graphics.setFont(LevelSelector.font_small)
    end
    love.graphics.print("UP / DOWN / WHEEL: scroll  |  ENTER / CLICK: warp  |  F1 / ESC: return", box_x + 20, box_y + 38)

    -- 3. Items list area with scissor
    local cur_scene = SceneManager.getCurrentName()
    local mx, my = Viewport.getMousePosition()
    LevelSelector.hover_index = nil

    love.graphics.push("all")
    -- Convert scissor coordinates to physical screen coords
    local sx, sy = Viewport.toScreen(list_x, list_y)
    local sw = list_w * Viewport.scale
    local sh = list_h * Viewport.scale
    love.graphics.setScissor(sx, sy, sw, sh)

    for i, item in ipairs(LevelSelector.items) do
        local iy = list_y + (i - 1) * LevelSelector.item_h - LevelSelector.scroll_y

        -- Only draw visible items
        if iy + LevelSelector.item_h >= list_y and iy <= list_y + list_h then
            local is_selected = (i == LevelSelector.selected_index)
            local is_current = (item.name == cur_scene)

            -- Hover check
            local is_hover = (mx >= list_x and mx <= list_x + list_w and my >= iy and my < iy + LevelSelector.item_h)
            if is_hover then
                LevelSelector.hover_index = i
            end

            -- Row background
            if is_selected then
                love.graphics.setColor(0.2, 0.42, 0.75, 0.9)
                love.graphics.rectangle("fill", list_x, iy, list_w, LevelSelector.item_h - 2)
            elseif is_hover then
                love.graphics.setColor(0.18, 0.22, 0.3, 0.8)
                love.graphics.rectangle("fill", list_x, iy, list_w, LevelSelector.item_h - 2)
            else
                love.graphics.setColor(0.13, 0.14, 0.18, 0.5)
                love.graphics.rectangle("fill", list_x, iy, list_w, LevelSelector.item_h - 2)
            end

            -- Row index & Name
            if LevelSelector.font_item then
                love.graphics.setFont(LevelSelector.font_item)
            end

            if is_selected then
                love.graphics.setColor(1, 1, 1, 1)
            elseif is_current then
                love.graphics.setColor(0.4, 0.95, 0.5, 1)
            else
                love.graphics.setColor(0.85, 0.88, 0.92, 1)
            end

            local prefix = string.format("%2d. ", i)
            love.graphics.print(prefix .. item.name, list_x + 12, iy + 10)

            -- Tags on right side
            if is_current then
                love.graphics.setColor(0.3, 0.9, 0.4, 1)
                if LevelSelector.font_small then love.graphics.setFont(LevelSelector.font_small) end
                love.graphics.print("[CURRENT]", list_x + list_w - 180, iy + 13)
            end

            -- Category badge
            love.graphics.setColor(0.55, 0.6, 0.7, 1)
            if LevelSelector.font_small then love.graphics.setFont(LevelSelector.font_small) end
            local cat_w = LevelSelector.font_small and LevelSelector.font_small:getWidth(item.category) or 60
            love.graphics.print(item.category, list_x + list_w - cat_w - 16, iy + 13)
        end
    end

    love.graphics.pop() -- Restores scissor and state

    -- 4. Scrollbar
    local total_h = #LevelSelector.items * LevelSelector.item_h
    if total_h > list_h then
        local bar_w = 6
        local bar_x = list_x + list_w - bar_w - 2
        love.graphics.setColor(0.18, 0.2, 0.25, 0.8)
        love.graphics.rectangle("fill", bar_x, list_y, bar_w, list_h)

        local thumb_h = math.max(30, (list_h / total_h) * list_h)
        local max_scroll = total_h - list_h
        local thumb_y = list_y + (LevelSelector.scroll_y / max_scroll) * (list_h - thumb_h)
        love.graphics.setColor(0.4, 0.55, 0.75, 1)
        love.graphics.rectangle("fill", bar_x, thumb_y, bar_w, thumb_h)
    end
end

return LevelSelector
