local Viewport = require("src.core.viewport")

local unpack_fn = unpack or table.unpack

local SceneManager = {
    definitions = {},
    order = {},
    scenes = {},
    current_scene = nil,
    current = nil,
    current_name = nil,
    previous_name = nil,

    transition = nil
}

local fade_canvas = nil
local function getFadeCanvas()
    local w = Viewport.getWidth()
    local h = Viewport.getHeight()
    if not fade_canvas or fade_canvas:getWidth() ~= w or fade_canvas:getHeight() ~= h then
        if fade_canvas then fade_canvas:release() end
        fade_canvas = love.graphics.newCanvas(w, h)
        fade_canvas:setFilter("nearest", "nearest")
    end
    return fade_canvas
end

function SceneManager.register(name, scene)
    assert(type(name) == "string", "Scene name must be a string")
    if not SceneManager.definitions[name] then
        table.insert(SceneManager.order, name)
    end
    SceneManager.definitions[name] = scene
    SceneManager.scenes[name] = nil
end

function SceneManager.getRegisteredScenes()
    local list = {}
    for _, name in ipairs(SceneManager.order) do
        table.insert(list, name)
    end
    return list
end

function SceneManager.has(name)
    return SceneManager.definitions[name] ~= nil
end

function SceneManager._resolveTarget(name)
    local target = SceneManager.scenes[name]
    if not target then
        local def = SceneManager.definitions[name]
        if not def then
            error(string.format("Scene '%s' is not registered in SceneManager!", tostring(name)))
        end

        if type(def) == "string" then
            local ok, loaded_module = pcall(require, def)
            if not ok then
                error(string.format("Failed to require scene module '%s' for scene '%s': %s", def, name,
                    tostring(loaded_module)))
            end
            target = loaded_module
            SceneManager.scenes[name] = target
        elseif type(def) == "function" then
            target = def()
            SceneManager.scenes[name] = target
        else
            target = def
            SceneManager.scenes[name] = target
        end
    end
    return target
end

function SceneManager.resetScene(name)
    local def = SceneManager.definitions[name]
    if def and type(def) == "string" then
        package.loaded[def] = nil
    end
    SceneManager.scenes[name] = nil
end

function SceneManager.resetGameScenes(except_name)
    local exc = except_name or "menu"
    for name, def in pairs(SceneManager.definitions) do
        if name ~= exc then
            if type(def) == "string" then
                package.loaded[def] = nil
            end
            SceneManager.scenes[name] = nil
        end
    end
end

function SceneManager.resetGame()
    local ok, GameState = pcall(require, "src.core.game_state")
    if ok and GameState and GameState.reset then
        GameState.reset()
    end
    SceneManager.resetGameScenes("menu")
end

function SceneManager._switchScene(name, ...)
    local target = SceneManager._resolveTarget(name)

    if SceneManager.current_scene and SceneManager.current_scene.leave then
        SceneManager.current_scene:leave()
    end

    if name == "menu" then
        SceneManager.resetGame()
    end

    SceneManager.previous_name = SceneManager.current_name
    SceneManager.current_name = name
    SceneManager.current_scene = target
    SceneManager.current = target

    if SceneManager.current_scene and SceneManager.current_scene.enter then
        SceneManager.current_scene:enter(...)
    end
end

function SceneManager.goTo(name, ...)
    SceneManager.transition = nil
    SceneManager._switchScene(name, ...)
end

SceneManager.switch = SceneManager.goTo

function SceneManager.crossFade(name, duration, ...)
    local dur = duration or 0.5

    local target = SceneManager._resolveTarget(name)

    local canvas = getFadeCanvas()
    love.graphics.push("all")
    love.graphics.setCanvas(canvas)
    love.graphics.origin()
    love.graphics.setScissor()
    love.graphics.clear(0, 0, 0, 0)
    if SceneManager.current_scene and SceneManager.current_scene.screen then
        SceneManager.current_scene.screen.needs_render = true
    end
    if SceneManager.current_scene and SceneManager.current_scene.draw then
        SceneManager.current_scene:draw()
    end
    love.graphics.pop()

    if SceneManager.current_scene and SceneManager.current_scene.leave then
        SceneManager.current_scene:leave()
    end

    if name == "menu" then
        SceneManager.resetGame()
    end

    SceneManager.previous_name = SceneManager.current_name
    SceneManager.current_name = name
    SceneManager.current_scene = target
    SceneManager.current = target

    if SceneManager.current_scene and SceneManager.current_scene.enter then
        SceneManager.current_scene:enter(...)
    end

    SceneManager.transition = {
        type = "crossfade",
        timer = 0,
        duration = math.max(0.01, dur),
        canvas = canvas,
        has_drawn = false
    }
end

function SceneManager._fadeColor(name, duration, color, ...)
    local dur = duration or 0.5
    local col = color or { 0, 0, 0 }

    SceneManager.transition = {
        type = "color",
        state = "fade_out",
        timer = 0,
        half_duration = math.max(0.01, dur / 2),
        color = col,
        target_name = name,
        target_args = { ... }
    }
end

function SceneManager.fadeTo(name, duration, color, ...)
    local dur = duration or 0.5
    if type(color) == "table" then
        SceneManager._fadeColor(name, dur, color, ...)
    else
        SceneManager.crossFade(name, dur, ...)
    end
end

function SceneManager.isTransitioning()
    return SceneManager.transition ~= nil
end

function SceneManager.getCurrent()
    return SceneManager.current_scene
end

function SceneManager.getCurrentName()
    return SceneManager.current_name
end

function SceneManager.getPreviousName()
    return SceneManager.previous_name
end

function SceneManager.update(dt)
    if SceneManager.current_scene and SceneManager.current_scene.update then
        SceneManager.current_scene:update(dt)
    end

    if SceneManager.transition then
        local t = SceneManager.transition
        if not t.has_drawn then
            return
        end
        local step = math.min(dt, 0.033)
        t.timer = t.timer + step

        if t.type == "crossfade" then
            if t.timer >= t.duration then
                SceneManager.transition = nil
            end
        elseif t.type == "color" then
            if t.state == "fade_out" then
                if t.timer >= t.half_duration then
                    SceneManager._switchScene(t.target_name, unpack_fn(t.target_args))
                    t.state = "fade_in"
                    t.timer = 0
                end
            elseif t.state == "fade_in" then
                if t.timer >= t.half_duration then
                    SceneManager.transition = nil
                end
            end
        end
    end
end

function SceneManager.draw()
    if SceneManager.current_scene and SceneManager.current_scene.draw then
        SceneManager.current_scene:draw()
    end

    if SceneManager.transition then
        local t = SceneManager.transition
        t.has_drawn = true

        if t.type == "crossfade" and t.canvas then
            local p = math.min(1.0, t.timer / t.duration)
            local alpha = 0.5 + 0.5 * math.cos(p * math.pi)
            if alpha > 0.001 then
                love.graphics.setColor(1, 1, 1, alpha)
                love.graphics.draw(t.canvas, 0, 0)
            end
        elseif t.type == "color" then
            local alpha = 0
            if t.state == "fade_out" then
                local p = math.min(1.0, t.timer / t.half_duration)
                alpha = 0.5 - 0.5 * math.cos(p * math.pi)
            elseif t.state == "fade_in" then
                local p = math.min(1.0, t.timer / t.half_duration)
                alpha = 0.5 + 0.5 * math.cos(p * math.pi)
            end

            if alpha > 0.001 then
                local w = Viewport.getWidth()
                local h = Viewport.getHeight()
                love.graphics.setColor(t.color[1], t.color[2], t.color[3], alpha)
                love.graphics.rectangle("fill", 0, 0, w, h)
            end
        end

        love.graphics.setColor(1, 1, 1, 1)
    end
end

function SceneManager.mousepressed(x, y, button, istouch, presses)
    if SceneManager.isTransitioning() then
        return
    end
    if SceneManager.current_scene and SceneManager.current_scene.mousepressed then
        SceneManager.current_scene:mousepressed(x, y, button, istouch, presses)
    end
end

function SceneManager.mousereleased(x, y, button, istouch, presses)
    if SceneManager.isTransitioning() then
        return
    end
    if SceneManager.current_scene and SceneManager.current_scene.mousereleased then
        SceneManager.current_scene:mousereleased(x, y, button, istouch, presses)
    end
end

function SceneManager.mousemoved(x, y, dx, dy, istouch)
    if SceneManager.current_scene and SceneManager.current_scene.mousemoved then
        SceneManager.current_scene:mousemoved(x, y, dx, dy, istouch)
    end
end

function SceneManager.wheelmoved(x, y)
    if SceneManager.current_scene and SceneManager.current_scene.wheelmoved then
        SceneManager.current_scene:wheelmoved(x, y)
    end
end

function SceneManager.keypressed(key, scancode, isrepeat)
    if SceneManager.isTransitioning() then
        return
    end
    if SceneManager.current_scene and SceneManager.current_scene.keypressed then
        SceneManager.current_scene:keypressed(key, scancode, isrepeat)
    end
end

function SceneManager.keyreleased(key, scancode)
    if SceneManager.current_scene and SceneManager.current_scene.keyreleased then
        SceneManager.current_scene:keyreleased(key, scancode)
    end
end

function SceneManager.textinput(text)
    if SceneManager.current_scene and SceneManager.current_scene.textinput then
        SceneManager.current_scene:textinput(text)
    end
end

function SceneManager.resize(w, h)
    if SceneManager.current_scene and SceneManager.current_scene.resize then
        SceneManager.current_scene:resize(w, h)
    end
end

function SceneManager.focus(focused)
    if SceneManager.current_scene and SceneManager.current_scene.focus then
        SceneManager.current_scene:focus(focused)
    end
end

function SceneManager.quit()
    if SceneManager.current_scene and SceneManager.current_scene.quit then
        return SceneManager.current_scene:quit()
    end
    return false
end

return SceneManager
