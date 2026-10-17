local Viewport = require("src.core.viewport")

local unpack_fn = unpack or table.unpack

local SceneManager = {
    scenes = {},
    current_scene = nil,
    current = nil,
    current_name = nil,
    previous_name = nil,

    transition = nil
}

local DEFAULT_FADE_COLOR = { 0x2D / 255, 0x37 / 255, 0x42 / 255 }

function SceneManager.register(name, scene)
    assert(type(name) == "string", "Scene name must be a string")
    SceneManager.scenes[name] = scene
end

function SceneManager._resolveTarget(name)
    local target = SceneManager.scenes[name]
    if not target then
        error(string.format("Scene '%s' is not registered in SceneManager!", tostring(name)))
    end

    if type(target) == "string" then
        local ok, loaded_module = pcall(require, target)
        if not ok then
            error(string.format("Failed to require scene module '%s' for scene '%s': %s", target, name, tostring(loaded_module)))
        end
        target = loaded_module
        SceneManager.scenes[name] = target
    end
    return target
end

function SceneManager._switchScene(name, ...)
    local target = SceneManager._resolveTarget(name)

    if SceneManager.current_scene and SceneManager.current_scene.leave then
        SceneManager.current_scene:leave()
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

function SceneManager.fadeTo(name, duration, color, ...)
    local dur = duration or 1.0
    local col = color or DEFAULT_FADE_COLOR

    SceneManager.transition = {
        state = "fade_out",
        timer = 0,
        half_duration = math.max(0.01, dur / 2),
        color = col,
        target_name = name,
        target_args = { ... }
    }
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
        t.timer = t.timer + dt

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

function SceneManager.draw()
    if SceneManager.current_scene and SceneManager.current_scene.draw then
        SceneManager.current_scene:draw()
    end

    if SceneManager.transition then
        local t = SceneManager.transition
        local alpha = 0

        if t.state == "fade_out" then
            alpha = math.min(1, t.timer / t.half_duration)
        elseif t.state == "fade_in" then
            alpha = math.max(0, 1.0 - (t.timer / t.half_duration))
        end

        if alpha > 0 then
            local w = Viewport.getWidth()
            local h = Viewport.getHeight()
            love.graphics.setColor(t.color[1], t.color[2], t.color[3], alpha)
            love.graphics.rectangle("fill", 0, 0, w, h)
        end
    end
end

function SceneManager.mousepressed(x, y, button, istouch, presses)
    if SceneManager.isTransitioning() and SceneManager.transition.state == "fade_out" then
        return
    end
    if SceneManager.current_scene and SceneManager.current_scene.mousepressed then
        SceneManager.current_scene:mousepressed(x, y, button, istouch, presses)
    end
end

function SceneManager.mousereleased(x, y, button, istouch, presses)
    if SceneManager.isTransitioning() and SceneManager.transition.state == "fade_out" then
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
    if SceneManager.isTransitioning() and SceneManager.transition.state == "fade_out" then
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
