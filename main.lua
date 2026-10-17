local SceneManager = require("src.core.scene_manager")
local Viewport = require("src.core.viewport")
local AudioManager = require("src.core.audio_manager")
local Settings = require("src.core.settings")
local I18n = require("src.core.i18n")

function love.load()
    love.window.setTitle("tech_plague")

    Viewport.init()

    Settings.init()
    I18n.init()

    AudioManager.init()

    SceneManager.register("menu", "src.scenes.menu")
    SceneManager.register("level1", "src.scenes.level1")
    SceneManager.register("level2", "src.scenes.level2")

    SceneManager.goTo("menu")
end

function love.update(dt)
    AudioManager.update(dt)
    SceneManager.update(dt)
end

function love.draw()
    Viewport.attach()
    SceneManager.draw()
    Viewport.detach()
end

function love.resize(w, h)
    Viewport.resize(w, h)
    SceneManager.resize(w, h)
end

function love.keypressed(key, scancode, isrepeat)
    if key == "escape" and SceneManager.getCurrentName() == "menu" then
        love.event.quit()
        return
    end
    SceneManager.keypressed(key, scancode, isrepeat)
end

function love.keyreleased(key, scancode)
    SceneManager.keyreleased(key, scancode)
end

function love.textinput(text)
    SceneManager.textinput(text)
end

function love.mousepressed(x, y, button, istouch, presses)
    local vx, vy = Viewport.toVirtual(x, y)
    SceneManager.mousepressed(vx, vy, button, istouch, presses)
end

function love.mousereleased(x, y, button, istouch, presses)
    local vx, vy = Viewport.toVirtual(x, y)
    SceneManager.mousereleased(vx, vy, button, istouch, presses)
end

function love.mousemoved(x, y, dx, dy, istouch)
    local vx, vy = Viewport.toVirtual(x, y)
    local vdx = dx / Viewport.getScale()
    local vdy = dy / Viewport.getScale()
    SceneManager.mousemoved(vx, vy, vdx, vdy, istouch)
end

function love.wheelmoved(x, y)
    SceneManager.wheelmoved(x, y)
end

function love.focus(focused)
    SceneManager.focus(focused)
end

function love.quit()
    return SceneManager.quit()
end
