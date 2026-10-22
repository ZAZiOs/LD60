local Controls = {}

local DEFAULT_KEYBOARD = {
    left     = { "left" },
    right    = { "right" },
    up       = { "up" },
    down     = { "down" },

    climb    = { "lshift" },
    dash     = { "x" },
    jump     = { "z", "space" },
    interact = { "c" }
}

local DEFAULT_GAMEPAD = {
    jump     = { "a" },
    dash     = { "x", "b" },
    climb    = { "rightshoulder", "leftshoulder", "triggerright", "triggerleft" },
    interact = { "y" },
    deadzone = 0.25
}

Controls.keyboard = {}
Controls.gamepad = {}
Controls.touch_enabled = false

Controls._prev_actions = {}
Controls._curr_actions = {}

Controls.touch_state = {
    dpad_x = 0,
    dpad_y = 0,
    jump = false,
    dash = false,
    climb = false,
    interact = false
}

Controls.touch_layout = {
    dpad = { x = 200, y = 880, radius = 130 },
    jump = { x = 1720, y = 880, radius = 65, label = "JUMP" },
    dash = { x = 1570, y = 800, radius = 60, label = "DASH" },
    climb = { x = 1720, y = 730, radius = 60, label = "GRAB" },
    interact = { x = 1570, y = 950, radius = 55, label = "ACT" }
}
Controls.active_touches = {}

local function deepCopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepCopy(orig_key)] = deepCopy(orig_value)
        end
    else
        copy = orig
    end
    return copy
end

function Controls.init(config)
    config = config or {}
    
    -- Check if Settings has controls saved
    local saved_controls = nil
    local pcall_ok, Settings = pcall(require, "src.core.settings")
    if pcall_ok and Settings and Settings.get then
        saved_controls = Settings.get("controls")
    end

    local kb = (saved_controls and saved_controls.keyboard) or config.keyboard or DEFAULT_KEYBOARD
    local gp = (saved_controls and saved_controls.gamepad) or config.gamepad or DEFAULT_GAMEPAD

    Controls.keyboard = deepCopy(kb)
    Controls.gamepad = deepCopy(gp)

    local os_str = love.system and love.system.getOS and love.system.getOS() or ""
    if config.touch_enabled ~= nil then
        Controls.touch_enabled = config.touch_enabled
    elseif saved_controls and saved_controls.touch_enabled ~= nil then
        Controls.touch_enabled = saved_controls.touch_enabled
    else
        Controls.touch_enabled = (os_str == "Android" or os_str == "iOS")
    end

    Controls._prev_actions = {}
    Controls._curr_actions = {}
end

function Controls.saveToSettings()
    local pcall_ok, Settings = pcall(require, "src.core.settings")
    if pcall_ok and Settings and Settings.set and Settings.save then
        Settings.set("controls", {
            keyboard = Controls.keyboard,
            gamepad = Controls.gamepad,
            touch_enabled = Controls.touch_enabled
        })
        Settings.save()
    end
end

function Controls.setTouchEnabled(enabled)
    Controls.touch_enabled = enabled
end

function Controls.isTouchEnabled()
    return Controls.touch_enabled
end

function Controls.bindKey(action, key)
    if not Controls.keyboard[action] then
        Controls.keyboard[action] = {}
    end
    table.insert(Controls.keyboard[action], key)
end

function Controls.setKeyBindings(action, key_list)
    Controls.keyboard[action] = type(key_list) == "table" and key_list or { key_list }
end

function Controls.getKeyBindings(action)
    return Controls.keyboard[action] or {}
end

function Controls.setGamepadBindings(action, btn_list)
    Controls.gamepad[action] = type(btn_list) == "table" and btn_list or { btn_list }
end

function Controls.getGamepadBindings(action)
    return Controls.gamepad[action] or {}
end

function Controls.getPrimaryGamepad()
    if love.joystick then
        local joysticks = love.joystick.getJoysticks()
        for _, joy in ipairs(joysticks) do
            if joy:isGamepad() then
                return joy
            end
        end
    end
    return nil
end

local function isKeyActive(action)
    local keys = Controls.keyboard[action]
    if not keys or not love.keyboard then return false end
    for _, k in ipairs(keys) do
        if love.keyboard.isDown(k) then
            return true
        end
    end
    return false
end

local function isGamepadActive(action)
    local pad = Controls.getPrimaryGamepad()
    if not pad then return false end

    local deadzone = Controls.gamepad.deadzone or 0.25

    if action == "left" then
        if pad:isGamepadDown("dpleft") then return true end
        local lx = pad:getGamepadAxis("leftx")
        if lx < -deadzone then return true end
    elseif action == "right" then
        if pad:isGamepadDown("dpright") then return true end
        local lx = pad:getGamepadAxis("leftx")
        if lx > deadzone then return true end
    elseif action == "up" then
        if pad:isGamepadDown("dpup") then return true end
        local ly = pad:getGamepadAxis("lefty")
        if ly < -deadzone then return true end
    elseif action == "down" then
        if pad:isGamepadDown("dpdown") then return true end
        local ly = pad:getGamepadAxis("lefty")
        if ly > deadzone then return true end
    else
        local btns = Controls.gamepad[action]
        if btns then
            for _, b in ipairs(btns) do
                if b == "triggerleft" then
                    if pad:getGamepadAxis("triggerleft") > 0.4 then return true end
                elseif b == "triggerright" then
                    if pad:getGamepadAxis("triggerright") > 0.4 then return true end
                else
                    if pad:isGamepadDown(b) then return true end
                end
            end
        end
    end

    return false
end

local function isTouchActive(action)
    if not Controls.touch_enabled then return false end

    if action == "left" then
        return Controls.touch_state.dpad_x < -0.3
    elseif action == "right" then
        return Controls.touch_state.dpad_x > 0.3
    elseif action == "up" then
        return Controls.touch_state.dpad_y < -0.3
    elseif action == "down" then
        return Controls.touch_state.dpad_y > 0.3
    elseif Controls.touch_state[action] ~= nil then
        return Controls.touch_state[action] == true
    end

    return false
end

-- Check continuous button/action state
function Controls.isDown(action)
    return isKeyActive(action) or isGamepadActive(action) or isTouchActive(action)
end

-- Query raw continuous axes (-1 to 1)
function Controls.getAxis()
    local x = 0
    local y = 0

    if Controls.isDown("left") then x = x - 1 end
    if Controls.isDown("right") then x = x + 1 end
    if Controls.isDown("up") then y = y - 1 end
    if Controls.isDown("down") then y = y + 1 end

    local pad = Controls.getPrimaryGamepad()
    if pad then
        local deadzone = Controls.gamepad.deadzone or 0.25
        local lx = pad:getGamepadAxis("leftx")
        local ly = pad:getGamepadAxis("lefty")
        if math.abs(lx) > deadzone and math.abs(lx) > math.abs(x) then
            x = lx
        end
        if math.abs(ly) > deadzone and math.abs(ly) > math.abs(y) then
            y = ly
        end
    end

    if Controls.touch_enabled then
        if math.abs(Controls.touch_state.dpad_x) > math.abs(x) then
            x = Controls.touch_state.dpad_x
        end
        if math.abs(Controls.touch_state.dpad_y) > math.abs(y) then
            y = Controls.touch_state.dpad_y
        end
    end

    return x, y
end

-- Check discrete 8-directional inputs (-1, 0, or 1)
function Controls.getDirection()
    local x, y = Controls.getAxis()
    local dx = (x > 0.35) and 1 or ((x < -0.35) and -1 or 0)
    local dy = (y > 0.35) and 1 or ((y < -0.35) and -1 or 0)
    return dx, dy
end

-- Check if an action was pressed this frame
function Controls.isJustPressed(action)
    return (Controls._curr_actions[action] == true) and (not Controls._prev_actions[action])
end

-- Check if an action was released this frame
function Controls.isJustReleased(action)
    return (not Controls._curr_actions[action]) and (Controls._prev_actions[action] == true)
end

function Controls.update(dt)
    for k, v in pairs(Controls._curr_actions) do
        Controls._prev_actions[k] = v
    end

    local actions = { "left", "right", "up", "down", "jump", "dash", "climb", "interact" }
    for _, act in ipairs(actions) do
        Controls._curr_actions[act] = Controls.isDown(act)
    end
end

-- Mobile Virtual Touch Input Handling
local function dist(x1, y1, x2, y2)
    local dx = x1 - x2
    local dy = y1 - y2
    return math.sqrt(dx * dx + dy * dy)
end

local function updateTouchDpad()
    Controls.touch_state.dpad_x = 0
    Controls.touch_state.dpad_y = 0

    local layout = Controls.touch_layout.dpad
    for id, touch in pairs(Controls.active_touches) do
        if touch.type == "dpad" then
            local dx = touch.curr_vx - layout.x
            local dy = touch.curr_vy - layout.y
            local d = math.sqrt(dx * dx + dy * dy)
            if d > 0 then
                local norm_d = math.min(1.0, d / layout.radius)
                Controls.touch_state.dpad_x = (dx / d) * norm_d
                Controls.touch_state.dpad_y = (dy / d) * norm_d
            end
            return
        end
    end
end

local function updateTouchButtons()
    local buttons = { "jump", "dash", "climb", "interact" }
    for _, btn in ipairs(buttons) do
        Controls.touch_state[btn] = false
    end

    for id, touch in pairs(Controls.active_touches) do
        for _, btn in ipairs(buttons) do
            local layout = Controls.touch_layout[btn]
            if layout and dist(touch.curr_vx, touch.curr_vy, layout.x, layout.y) <= layout.radius then
                Controls.touch_state[btn] = true
            end
        end
    end
end

function Controls.touchpressed(id, x, y, dx, dy, pressure)
    if not Controls.touch_enabled then return end
    local Viewport = require("src.core.viewport")
    local vx, vy = Viewport.toVirtual(x, y)

    local touch_info = {
        id = id,
        start_vx = vx,
        start_vy = vy,
        curr_vx = vx,
        curr_vy = vy,
        type = "unknown"
    }

    if dist(vx, vy, Controls.touch_layout.dpad.x, Controls.touch_layout.dpad.y) <= Controls.touch_layout.dpad.radius * 1.35 then
        touch_info.type = "dpad"
    else
        touch_info.type = "button"
    end

    Controls.active_touches[id] = touch_info
    updateTouchDpad()
    updateTouchButtons()
end

function Controls.touchmoved(id, x, y, dx, dy, pressure)
    if not Controls.touch_enabled then return end
    local Viewport = require("src.core.viewport")
    local vx, vy = Viewport.toVirtual(x, y)

    local t = Controls.active_touches[id]
    if t then
        t.curr_vx = vx
        t.curr_vy = vy
        updateTouchDpad()
        updateTouchButtons()
    end
end

function Controls.touchreleased(id, x, y, dx, dy, pressure)
    if not Controls.touch_enabled then return end
    Controls.active_touches[id] = nil
    updateTouchDpad()
    updateTouchButtons()
end

-- Render on-screen virtual controls for mobile/touch
function Controls.drawTouchOverlay()
    if not Controls.touch_enabled then return end

    love.graphics.push("all")

    -- D-Pad
    local dpad = Controls.touch_layout.dpad
    love.graphics.setColor(1, 1, 1, 0.15)
    love.graphics.circle("fill", dpad.x, dpad.y, dpad.radius)
    love.graphics.setColor(1, 1, 1, 0.40)
    love.graphics.setLineWidth(3)
    love.graphics.circle("line", dpad.x, dpad.y, dpad.radius)

    -- D-Pad thumb knob
    local knob_x = dpad.x + Controls.touch_state.dpad_x * (dpad.radius * 0.65)
    local knob_y = dpad.y + Controls.touch_state.dpad_y * (dpad.radius * 0.65)
    love.graphics.setColor(0.4, 0.75, 1.0, 0.55)
    love.graphics.circle("fill", knob_x, knob_y, 40)
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.circle("line", knob_x, knob_y, 40)

    -- Action Buttons
    local buttons = {
        { name = "jump", col = { 0.3, 0.85, 0.3 } },
        { name = "dash", col = { 0.3, 0.75, 1.0 } },
        { name = "climb", col = { 0.95, 0.7, 0.2 } },
        { name = "interact", col = { 0.9, 0.4, 0.9 } }
    }

    local font = love.graphics.getFont()
    for _, btn_info in ipairs(buttons) do
        local btn_name = btn_info.name
        local layout = Controls.touch_layout[btn_name]
        if layout then
            local is_pressed = Controls.touch_state[btn_name]
            local c = btn_info.col
            local alpha = is_pressed and 0.65 or 0.25
            love.graphics.setColor(c[1], c[2], c[3], alpha)
            love.graphics.circle("fill", layout.x, layout.y, layout.radius)

            love.graphics.setColor(1, 1, 1, is_pressed and 0.9 or 0.5)
            love.graphics.setLineWidth(2)
            love.graphics.circle("line", layout.x, layout.y, layout.radius)

            if layout.label and font then
                local tw = font:getWidth(layout.label)
                local th = font:getHeight()
                love.graphics.setColor(1, 1, 1, is_pressed and 1.0 or 0.75)
                love.graphics.print(layout.label, layout.x - tw / 2, layout.y - th / 2)
            end
        end
    end

    love.graphics.pop()
end

return Controls
