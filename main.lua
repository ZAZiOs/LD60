local SceneManager = require("src.core.scene_manager")
local Viewport = require("src.core.viewport")
local AudioManager = require("src.core.audio_manager")
local Settings = require("src.core.settings")
local I18n = require("src.core.i18n")
local Effects = require("src.core.effects")
local GameState = require("src.core.game_state")
local LevelLoader = require("src.core.level_loader")
local LevelSelector = require("src.core.level_selector")

local Controls = require("src.core.controls")

DEBUG = false
local START_SCENE = "menu"
local target_arg = nil

function love.load(args)
    io.stdout:setvbuf("no")
    love.window.setTitle("mr_havoc")

    if args then
        for _, v in ipairs(args) do
            if v == "debug" then
                DEBUG = true
            elseif v == "test_loader" then
                print("--- RUNNING LEVEL LOADER TEST ---")
                local scene = LevelLoader.loadFromFile("levels/ld60/test_level.ini")
                assert(scene and scene.desktop, "LevelLoader failed to build scene!")
                print("TEST_LOADER_SUCCESS: Desktop built with " .. tostring(#scene.desktop.elements) .. " elements")
                os.exit(0)
            elseif v == "test_dash" then
                print("--- RUNNING DASH TEST ---")
                local Player = require("src.game.player")
                local p = Player.new({ x = 100, y = 200, max_dashes = 2, dash_speed = 300, dash_duration = 0.15 })
                assert(p.max_dashes == 2, "max_dashes should be 2")
                assert(p.dashes == 2, "initial dashes should be 2")
                p.facing = 1
                assert(p:dash() == true, "First dash should succeed")
                assert(p.dashes == 1, "Remaining dashes should be 1")
                assert(p.vx == 300 and p.vy == 0, "Horizontal dash velocities mismatch")
                p:update(0.05)
                assert(p.dash_timer > 0, "Dash timer should still be positive")
                assert(#p.dash_trail > 0, "Ghost afterimages should be created")
                p:update(0.12)
                assert(p.dash_timer == 0, "Dash timer should be completed")
                p.dash_cooldown = 0
                p.facing = -1
                assert(p:dash() == true, "Second dash should succeed")
                assert(p.dashes == 0, "Remaining dashes should be 0")
                assert(p.vx == -300, "Facing negative dash should have vx -300")
                p.dash_cooldown = 0
                assert(p:dash() == false, "Third dash should fail when out of dashes")
                p.y = 240
                p:update(0.01, { room_height = 240, room_width = 320 })
                assert(p.is_grounded == true, "Player should be grounded at bottom of room")
                assert(p.dashes == 2, "Dashes should replenish on ground")
                print("--- DASH TEST PASSED SUCCESSFULLY ---")
                os.exit(0)
            elseif v == "test_climb" then
                print("--- RUNNING CLIMB TEST ---")
                local Player = require("src.game.player")
                local p = Player.new({ x = 100, y = 100, max_stamina = 100 })
                assert(p.stamina == 100, "Initial stamina should be 100")
                assert(p.is_wall_holding == false, "Initially not holding wall")

                -- Test 1: climbJump drains stamina
                p:climbJump(1)
                assert(p.vy < 0, "climbJump should impart upward velocity")
                assert(p.vx == 0, "climbJump should have 0 horizontal velocity")
                assert(p.stamina == 73, "climbJump should consume 27 stamina (100 - 27 = 73), got: " .. tostring(p.stamina))

                -- Test 2: Replenish stamina on ground
                p.y = 239
                p.vy = 50
                p:update(0.05, { room_height = 240, room_width = 320 })
                assert(p.is_grounded == true, "Player should be grounded")
                assert(p.stamina == 100, "Stamina should replenish to max on ground")
                print("--- CLIMB TEST PASSED SUCCESSFULLY ---")
                os.exit(0)
            elseif v == "test_controls" then
                print("--- RUNNING CONTROLS TEST ---")
                Controls.init({ touch_enabled = true })
                assert(Controls.isTouchEnabled() == true, "Touch should be enabled")
                
                -- Test key binding customization
                Controls.setKeyBindings("jump", { "space", "k" })
                local jump_keys = Controls.getKeyBindings("jump")
                assert(#jump_keys == 2 and jump_keys[1] == "space" and jump_keys[2] == "k", "Key bindings should be updated")

                -- Test touch dpad & buttons simulation
                Controls.touchpressed(1, 200, 880, 0, 0, 1) -- DPad center
                Controls.touchpressed(2, 1720, 880, 0, 0, 1) -- Jump button
                assert(Controls.isDown("jump") == true, "Jump should be down from touch")
                
                Controls.update(0.016)
                assert(Controls.isJustPressed("jump") == true, "isJustPressed should be true on first frame")

                Controls.touchreleased(2, 1720, 880, 0, 0, 1)
                Controls.update(0.016)
                assert(Controls.isDown("jump") == false, "Jump should be released")
                assert(Controls.isJustReleased("jump") == true, "isJustReleased should be true on release frame")

                -- Test Player integration
                local Player = require("src.game.player")
                local p = Player.new({ x = 100, y = 100 })
                p.facing = 1
                assert(p:dash() == true, "Player dash via Controls should work")
                
                print("--- CONTROLS TEST PASSED SUCCESSFULLY ---")
                os.exit(0)
            else
                target_arg = v
            end
        end
    end

    Viewport.init()

    Settings.init()
    Controls.init()
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
    SceneManager.register("editor", "src.scenes.editor")

    LevelLoader.registerAll("levels")

    if target_arg then
        if SceneManager.definitions[target_arg] then
            START_SCENE = target_arg
        elseif SceneManager.definitions["ld60." .. target_arg] then
            START_SCENE = "ld60." .. target_arg
        end
    end

    SceneManager.goTo(START_SCENE)
end

function love.update(dt)
    Controls.update(dt)
    AudioManager.update(dt)
    Effects.update(dt)
    SceneManager.update(dt)
end

function love.draw()
    Viewport.attach()
    SceneManager.draw()
    if DEBUG and LevelSelector.isOpen() then
        LevelSelector.draw()
    end
    if Controls.isTouchEnabled() then
        Controls.drawTouchOverlay()
    end
    Viewport.detach()
end

function love.resize(w, h)
    Viewport.resize(w, h)
    SceneManager.resize(w, h)
end

function love.gamepadpressed(joystick, button)
    local cur_scene = SceneManager.getCurrent()
    if cur_scene and cur_scene.player and cur_scene.player.triggerAction then
        local gp = Controls.gamepad or {}
        local act = nil
        for action_name, btns in pairs(gp) do
            if type(btns) == "table" then
                for _, b in ipairs(btns) do
                    if b == button then
                        act = action_name
                        break
                    end
                end
            end
            if act then break end
        end
        if act then
            cur_scene.player:triggerAction(act, cur_scene)
        end
    end
end

function love.touchpressed(id, x, y, dx, dy, pressure)
    Controls.touchpressed(id, x, y, dx, dy, pressure)
    local cur_scene = SceneManager.getCurrent()
    if cur_scene and cur_scene.player and cur_scene.player.triggerAction then
        if Controls.isJustPressed("jump") then
            cur_scene.player:triggerAction("jump", cur_scene)
        end
        if Controls.isJustPressed("dash") then
            cur_scene.player:triggerAction("dash", cur_scene)
        end
        if Controls.isJustPressed("interact") then
            cur_scene.player:triggerAction("interact", cur_scene)
        end
    end
end

function love.touchmoved(id, x, y, dx, dy, pressure)
    Controls.touchmoved(id, x, y, dx, dy, pressure)
end

function love.touchreleased(id, x, y, dx, dy, pressure)
    Controls.touchreleased(id, x, y, dx, dy, pressure)
end

function love.keypressed(key, scancode, isrepeat)
    if DEBUG and key == "f1" then
        LevelSelector.toggle()
        return
    end

    if DEBUG and key == "f2" then
        if SceneManager.getCurrentName() == "editor" then
            SceneManager.goTo(SceneManager.getPreviousName() or "menu")
        else
            SceneManager.goTo("editor")
        end
        return
    end

    if DEBUG and LevelSelector.isOpen() then
        if LevelSelector.keypressed(key) then
            return
        end
    end

    if key == "f11" or (key == "return" and (love.keyboard.isDown("lalt") or love.keyboard.isDown("ralt"))) then
        local cur = Settings.get("fullscreen") or false
        Settings.set("fullscreen", not cur)
        return
    end
    if key == "escape" and SceneManager.getCurrentName() == "menu" then
        love.event.quit()
        return
    end

    if DEBUG then
        local current = SceneManager.getCurrentName()
        local debug_rooms = SceneManager.getRegisteredScenes()
        
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
    if DEBUG and LevelSelector.isOpen() then
        if LevelSelector.mousepressed(vx, vy, button) then
            return
        end
    end
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
    if DEBUG and LevelSelector.isOpen() then
        if LevelSelector.wheelmoved(x, y) then
            return
        end
    end
    SceneManager.wheelmoved(x, y)
end

function love.focus(focused)
    SceneManager.focus(focused)
end

function love.quit()
    return SceneManager.quit()
end
