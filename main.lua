local SceneManager = require("src.core.scene_manager")
local Viewport = require("src.core.viewport")
local AudioManager = require("src.core.audio_manager")
local Settings = require("src.core.settings")
local I18n = require("src.core.i18n")
local Effects = require("src.core.effects")
local GameState = require("src.core.game_state")

DEBUG = false

function love.load(args)
    love.window.setTitle("mr_havoc")

    if args then
        for _, v in ipairs(args) do
            if v == "debug" then
                DEBUG = true
                break
            end
        end
    end

    Viewport.init()

    Settings.init()
    I18n.init()
    GameState.init({
        level1_vent_opened = false,
        level1_crowbar_collected = false,
        level1_chest_opened = false,
        level1_key_collected = false,
        level1_wardrobe_opened = false,
        level1_note_collected = false,
        level1_2_door_opened = false,
        level2_2_door_opened = false,
        level2_3_coin_collected = false,
        level2_pic1_flipped = false,
        level2_pic2_flipped = false,
        level2_pic3_flipped = false,
        level2_closet_opened = false,
        level2_facebook_vandalized = false,
        wrong_bookshelves_exploded = 0,
        correct_bookshelves_exploded = 0,
        eye_killed = false,
        is_dead = false,
        level3_cleared = false
    })

    AudioManager.init()
    Effects.load()

    SceneManager.register("menu", "src.scenes.menu")
    SceneManager.register("level0", "src.scenes.level0")
    SceneManager.register("level1", "src.scenes.level1")
    SceneManager.register("level1-2", "src.scenes.level1-2")
    SceneManager.register("level1-3", "src.scenes.level1-3")
    SceneManager.register("level2", "src.scenes.level2")
    SceneManager.register("level2-2", "src.scenes.level2-2")
    SceneManager.register("level2-3", "src.scenes.level2-3")
    SceneManager.register("level3", "src.scenes.level3")
    SceneManager.register("the_end", "src.scenes.the_end_scene")
    SceneManager.register("gameover", "src.scenes.gameover")

    if DEBUG then
        SceneManager.register("test_camera", "src.scenes.test_camera")
    end

    SceneManager.goTo("menu")
end

function love.update(dt)
    AudioManager.update(dt)
    Effects.update(dt)
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
    if key == "f11" or (key == "return" and (love.keyboard.isDown("lalt") or love.keyboard.isDown("ralt"))) then
        local cur = Settings.get("fullscreen") or false
        Settings.set("fullscreen", not cur)
        return
    end
    if key == "escape" and SceneManager.getCurrentName() == "menu" then
        love.event.quit()
        return
    end

    -- DEBUG: Room switching with [ and ]
    if DEBUG then
        local current = SceneManager.getCurrentName()
        -- Rooms for debug
        local debug_rooms = { 
            "menu", 
            "level0", 
            "level1", 
            "level1-2", 
            "level1-3", 
            "level2", 
            "level2-2",
            "level2-3", 
            "level3", 
            "the_end" 
        }
        
        -- Current index
        local current_index = 1
        for i, name in ipairs(debug_rooms) do
            if name == current then
                current_index = i
                break
            end
        end

        if key == "]" then
            -- Next room
            local next_index = current_index + 1
            if next_index > #debug_rooms then next_index = 1 end
            SceneManager.goTo(debug_rooms[next_index])
            return
        elseif key == "[" then
            -- Previous room
            local prev_index = current_index - 1
            if prev_index < 1 then prev_index = #debug_rooms end
            SceneManager.goTo(debug_rooms[prev_index])
            return
        end
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
