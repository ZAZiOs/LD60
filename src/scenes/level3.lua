local SceneManager = require("src.core.scene_manager")
local PixelScreen = require("src.core.pixel_screen")
local GameScene = require("src.core.game_scene")
local PixelSceneBuilder = require("src.core.pixel_scene_builder")
local AudioManager = require("src.core.audio_manager")
local Effects = require("src.core.effects")
local GameState = require("src.core.game_state")
local SpritesheetManager = require("src.core.spritesheet_manager")
local I18n = require("src.core.i18n")

local ROOM_WIDTH = 840
local ROOM_HEIGHT = 240
local TOTAL_BOMBS = 3

local asciiShader = nil
local asciiAtlas = nil
local asciiCellW = 4
local asciiCellH = 6
local nChars = 8

local function initAsciiShader()
    if asciiShader then return end
    local ok, s = pcall(love.graphics.newShader, "assets/shaders/ascii.glsl")
    if ok and s then
        asciiShader = s
        asciiCellW = 4
        asciiCellH = 6
        nChars = 8

        asciiAtlas = love.graphics.newCanvas(nChars * asciiCellW, asciiCellH)
        asciiAtlas:setFilter("nearest", "nearest")

        love.graphics.push("all")
        love.graphics.setCanvas(asciiAtlas)
        love.graphics.clear(0, 0, 0, 0)
        love.graphics.setColor(1, 1, 1, 1)

        local function px(i, x, y)
            love.graphics.rectangle("fill", (i - 1) * asciiCellW + x, y, 1, 1)
        end
        local function rect(i, x, y, w, h)
            love.graphics.rectangle("fill", (i - 1) * asciiCellW + x, y, w, h)
        end

        px(2, 1, 4)
        px(3, 1, 1)
        px(3, 1, 4)
        rect(4, 0, 2, 3, 1)
        rect(5, 0, 2, 3, 1)
        rect(5, 1, 1, 1, 3)
        rect(6, 0, 2, 3, 1)
        rect(6, 1, 1, 1, 3)
        px(6, 0, 1)
        px(6, 2, 3)
        rect(7, 0, 1, 3, 1)
        rect(7, 0, 4, 3, 1)
        rect(7, 0, 2, 1, 2)
        rect(7, 2, 2, 1, 2)
        rect(8, 0, 0, 3, 5)

        love.graphics.pop()
    end
end

local scan_raw_canvas = nil
local desktop = nil

local countdown_active = false
local countdown_timer = 40.0
local first_explosion_done = false
local eye_alert_timer = 0
local eye_notification_timer = 0
local restart_timer = 0
local exit_unlocked = false
local last_music_is_hidden = false

local disconnect_state = "none" -- "none", "shutting_down", "disconnected", "turning_on"
local disconnect_timer = 0
local disconnect_duration = 0.55
local disconnect_blink = 0
local fail_reason = "none" -- "timeout", "destroyed", "none"
local eye_caught_state = "none" -- "none", "targeting"
local eye_caught_timer = 0
local eye_caught_exploded = false
local triggerRetry = nil

local font_retry = nil
local function getRetryFont()
    if not font_retry then
        font_retry = I18n.getFont({
            path = "assets/fnt/tahomabd.ttf",
            size = 11,
            hinting = "mono",
            filter = "nearest"
        })
    end
    return font_retry
end

local eye = {
    x = 485,
    y = 145,
    w = 48,
    h = 48,
    facing = 1,
    state = "behind_desk",
    wait_timer = 0,
    is_dead = false,
    speed = 124,
    sheet = nil
}

local explosion_img = nil
local exclamation_img = nil

local function getExplosionImg()
    if not explosion_img then
        local ok, img = pcall(love.graphics.newImage, "assets/level3/explosion.png")
        if ok and img then
            img:setFilter("nearest", "nearest")
            explosion_img = img
        end
    end
    return explosion_img
end

local function getExclamationImg()
    if not exclamation_img then
        local ok, img = pcall(love.graphics.newImage, "assets/exclamation_xp.png")
        if ok and img then
            img:setFilter("nearest", "nearest")
            exclamation_img = img
        end
    end
    return exclamation_img
end

local function checkDoorUnlock()
    local correct = GameState.get("correct_bookshelves_exploded", 0)
    if correct >= TOTAL_BOMBS then
        local d_exit = desktop and desktop:getElement("door_exit")
        if d_exit then
            d_exit.visible = true
            d_exit.unlocked = true
        end
        exit_unlocked = true
        GameState.set("level3_cleared", true)
    end
end

local function triggerFirstExplosion(is_loud)
    if not first_explosion_done then
        first_explosion_done = true
        countdown_active = true
        countdown_timer = 40.0

        if AudioManager and AudioManager.musFadeTo then
            AudioManager.musFadeTo("data_run", 0.7, 0.4)
        end

        if not eye.is_dead then
            eye.state = "waiting_delay"
            eye_alert_timer = is_loud and 5.0 or 3.0
        end
    end
end

local function canBackstabEye(player, eye_npc)
    if not player or not eye_npc or eye_npc.is_dead or eye_npc.exploding or player.is_hidden then
        return false
    end

    if eye_npc.state == "behind_desk" or eye_npc.state == "waiting_delay" then
        local eye_cx = eye_npc.x + 24
        local dx = math.abs(player.x - eye_cx)
        if dx <= 65 and player.y >= 160 and player.y <= 235 then
            return true
        end
        return false
    end

    local dy = math.abs(player.y - (eye_npc.y + 48))
    if dy > 24 then
        return false
    end

    local eye_cx = eye_npc.x + 24
    local dx = player.x - eye_cx

    if eye_npc.facing == -1 and dx > 0 and dx <= 40 then
        return true
    elseif eye_npc.facing == 1 and dx < 0 and dx >= -40 then
        return true
    elseif (eye_npc.state == "climbing_ladder" or eye_npc.state == "climbing_up" or eye_npc.state == "climbing_down") and math.abs(dx) <= 24 then
        return true
    end

    return false
end

local function detonateEye()
    if eye.is_dead or eye.exploding then return end
    eye.is_dead = true
    eye.exploding = true
    eye.explode_timer = 0.6
    GameState.set("eye_killed", true)
    if desktop and desktop.shakeCamera then
        desktop:shakeCamera(0.6, 7)
    end
    if AudioManager and AudioManager.sfxPlay then
        pcall(AudioManager.sfxPlay, "explosion")
    end
end

desktop = PixelSceneBuilder.new("desktop_level3")
    :background("assets/level3/wp.png")
    :cursor("assets/cursor.ini")
    :setRoomBounds(ROOM_WIDTH, ROOM_HEIGHT)
    
    :addSolid("taskbar", {
        image = "assets/level3/taskbar.png",
        x = 0,
        y = 224,
        w = 320,
        h = 16,
        fixed = true,
        z_index = 1000
    })

    :addTab("tab_readme", {
        idle = "assets/level3/rm_tab.png",
        active = "assets/level3/rm_tab_a.png",
        x = 62,
        y = 226,
        visible = true,
        is_active = false,
        onClick = function(self)
            self.scene:toggleElement("window_readme")
            local win = self.scene:getElement("window_readme")
            self.scene:setElementActive("tab_readme", win and win.visible)
            if win and win.visible then
                self.scene:setElementVisible("tab_scanner", true)
            end
        end,
        onInteract = function(self)
            self:onClick()
        end
    })

    :addTab("tab_scanner", {
        idle = "assets/level3/xs_tab.png",
        active = "assets/level3/xs_tab_a.png",
        x = 120,
        y = 226,
        visible = false,
        is_active = false,
        onClick = function(self)
            self.scene:toggleElement("window_scanner")
            local win = self.scene:getElement("window_scanner")
            self.scene:setElementActive("tab_scanner", win and win.visible)
        end,
        onInteract = function(self)
            self:onClick()
        end
    })

    :addSolid("beam_left", {
        x = 0,
        y = 109,
        w = 788,
        h = 15,
        is_solid = true,
        z_index = 2
    })
    :addSolid("beam_right", {
        x = 820,
        y = 109,
        w = 140,
        h = 15,
        is_solid = true,
        z_index = 2
    })

    :addBookshelf("s_f2_1", { x = 36, y = 12,  has_bomb = false})
    :addBookshelf("s_f1_1", { x = 36, y = 127, has_bomb = false})

    :addBookshelf("s_f2_2", { x = 115, y = 12,  has_bomb = true})
    :addBookshelf("s_f1_2", { x = 115, y = 127, has_bomb = false})
    
    :addBookshelf("s_f2_3", { x = 194, y = 12,  has_bomb = true})
    :addBookshelf("s_f1_3", { x = 194, y = 127, has_bomb = false})
    
    :addBookshelf("s_f2_4", { x = 273, y = 12,  has_bomb = false})
    :addBookshelf("s_f1_4", { x = 273, y = 127, has_bomb = false})
    
    :addBookshelf("s_f2_5", { x = 352, y = 12,  has_bomb = false})
    :addBookshelf("s_f1_5", { x = 352, y = 127, has_bomb = false})

    :addBookshelf("s_f2_6", { x = 589, y = 12,  has_bomb = false})
    :addBookshelf("s_f2_7", { x = 668, y = 12,  has_bomb = true})

    :addBookshelf("s_f1_7", { x = 668, y = 127,  has_bomb = false})

    :addElement({
        id = "door_hide",
        image = "assets/level3/door_hide.png",
        x = 478,
        y = 22,
        w = 64,
        h = 87,
        z_index = 3,
        interactable = true,
        clickable = true,
        onInteract = function(self, down_held, player)
            player = player or (desktop and desktop.player)
            if player and player.y < 115 and math.abs(player.x - 510) < 45 then
                player.is_hidden = not player.is_hidden
                if player.is_hidden then
                    player.hide_cooldown = 0.25
                    player.x = 510
                    player.y = 109
                    player.vx = 0
                    player.vy = 0
                end
            end
        end,
        onClick = function(self, btn)
            local player = desktop and desktop.player
            if player and player.y < 115 and math.abs(player.x - 510) < 45 then
                player.is_hidden = not player.is_hidden
                if player.is_hidden then
                    player.hide_cooldown = 0.25
                    player.x = 510
                    player.y = 109
                    player.vx = 0
                    player.vy = 0
                end
                return true
            end
        end
    })

    :addElement({
        id = "door_exit",
        image = "assets/level3/door_exit.png",
        x = 548,
        y = 126,
        z_index = 5,
        visible = false,
        interactable = true,
        clickable = true,
        unlocked = false,
        onInteract = function(self)
            if self.unlocked or exit_unlocked then
                SceneManager.crossFade("level4", 0.4)
            end
        end,
        onClick = function(self)
            self:onInteract()
        end
    })

    :addElement({
        id = "desk_counter",
        x = 445,
        y = 158,
        w = 120,
        h = 66,
        z_index = 9
    })

    :addWindow("window_readme", {
        title = "README",
        x = 60,
        y = 30,
        w = 140,
        h = 96,
        fixed = true,
        visible = false,
        closeable = true,
        draggable = true,
        text = [[Okay, you got to the point I wrote to you for. The data center. You should destroy ONLY THE 3 BOOKSHELVES I NEED!!! NO MORE!!! I really, really DON'T WANT to be noticed. REALLY, REALLY DON'T WANT.

When you open this file, you will also get a utility I coded to scan shelves and find the ones I need. Using it, check the ones I need AND NO MORE!!

DO NOT TOUCH OTHER SHELVES! AND! IN ANY CASE! DON'T TOUCH THE EYE ANTIVIRUS!
DO!!!!!!! NOT!!!!!! TOUCH!!!!! IT!!!!!!!! IN!!!! ANY!!!!! CASE!!!!!!!]],
        onClose = function(win)
            if desktop then
                desktop:setElementActive("tab_readme", false)
            end
        end
    })

    :addWindow("window_scanner", {
        title = "X-SCANNER",
        x = 90,
        y = 30,
        w = 140,
        h = 96,
        fixed = true,
        visible = false,
        closeable = true,
        draggable = true,
        onClose = function(win)
            if desktop then
                desktop:setElementActive("tab_scanner", false)
            end
        end,
        draw_content = function(win, canvas, inner_w, inner_h)
            initAsciiShader()

            if not scan_raw_canvas or scan_raw_canvas:getWidth() ~= inner_w or scan_raw_canvas:getHeight() ~= inner_h then
                scan_raw_canvas = love.graphics.newCanvas(inner_w, inner_h)
                scan_raw_canvas:setFilter("nearest", "nearest")
            end

            local cam_x = math.floor((desktop and desktop.camera and desktop.camera.x or 0) + 0.5)
            local cam_y = math.floor((desktop and desktop.camera and desktop.camera.y or 0) + 0.5)
            local world_x = math.floor(win.x + 4 + cam_x + 0.5)
            local world_y = math.floor(win.y + 12 + cam_y + 0.5)

            local bomb_in_view = false

            love.graphics.push("all")
            love.graphics.setCanvas(scan_raw_canvas)
            love.graphics.origin()
            love.graphics.clear(0, 0, 0, 1)

            if desktop and desktop.bg_image then
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.draw(desktop.bg_image, -world_x, -world_y)
            end

            if desktop and desktop.elements then
                for _, el in ipairs(desktop.elements) do
                    if el.is_bookshelf then
                        local sx = math.floor(el.x - world_x)
                        local sy = math.floor(el.y - world_y)
                        if sx + el.w > 0 and sx < inner_w and sy + el.h > 0 and sy < inner_h then
                            local img = (el.is_active and el.active_img_obj) or el.img_obj
                            if img then
                                love.graphics.setColor(1, 1, 1, 1)
                                love.graphics.draw(img, sx, sy)
                            end

                            if el.has_bomb and not el.is_exploded then
                                bomb_in_view = true
                                local bcx = math.floor(sx + el.w / 2)
                                local bcy = math.floor(sy + el.h / 2)
                                love.graphics.setColor(1, 1, 1, 1)
                                love.graphics.circle("fill", bcx, bcy, 9)
                            end
                        end
                    end
                end
            end

            love.graphics.pop()

            if asciiShader and asciiAtlas then
                local function sendUniform(name, val)
                    if asciiShader:hasUniform(name) then
                        asciiShader:send(name, val)
                    end
                end
                sendUniform("atlasTex", asciiAtlas)
                sendUniform("atlasCells", { nChars, 1 })
                sendUniform("cellW", asciiCellW)
                sendUniform("cellH", asciiCellH)
                sendUniform("nChars", nChars)
                sendUniform("texSize", { inner_w, inner_h })
                sendUniform("zone", { 0, 0, inner_w, inner_h })
                sendUniform("time", love.timer.getTime())

                love.graphics.setShader(asciiShader)
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.draw(scan_raw_canvas, 0, 0)
                love.graphics.setShader()
            end
        end
    })

    :spawnPlayer({
        x = 40,
        y = 224,
        sheet = "assets/rage/rage_sh.ini"
    })

    :onUpdate(function(self, dt)
        if disconnect_state ~= "none" or eye_caught_state ~= "none" then
            return
        end

        local player = self.player

        if countdown_active then
            countdown_timer = countdown_timer - dt
            if countdown_timer <= 0 then
                countdown_timer = 0
                countdown_active = false
                disconnect_state = "shutting_down"
                disconnect_timer = 0
                fail_reason = "timeout"
                if AudioManager and AudioManager.musStop then
                    AudioManager.musStop(0)
                end
                if AudioManager and AudioManager.sfxPlay then
                    pcall(AudioManager.sfxPlay, "shutdown")
                end
                return
            end
        end

        if player then
            if player.x >= 786 and player.x <= 822 then
                local up_held = love.keyboard.isDown("up") or love.keyboard.isDown("w")
                local down_held = love.keyboard.isDown("down") or love.keyboard.isDown("s")

                if up_held then
                    player.vy = -80
                    player.is_grounded = false
                elseif down_held then
                    player.vy = 80
                elseif player.y > 115 and player.y < 220 then
                    player.vy = 0
                end
            end
            if player.is_hidden then
                player.x = 510
                player.y = 109
                player.vx = 0
                player.vy = 0
            end
        end

        if not eye.is_dead then
            if not eye.sheet then
                eye.sheet = SpritesheetManager.getSheet("assets/level3/eye.ini")
            end

            if eye_notification_timer > 0 then
                eye_notification_timer = math.max(0, eye_notification_timer - dt)
            end

            if eye.state == "waiting_delay" then
                eye_alert_timer = eye_alert_timer - dt
                if eye_alert_timer <= 0 then
                    eye.state = "f1_to_ladder"
                    eye.y = 176
                    eye_notification_timer = 5.0
                end
            elseif eye.state == "f1_to_ladder" or eye.state == "moving_to_ladder" then
                -- Moving right on 1st floor to the ladder
                eye.facing = 1
                eye.y = 176
                eye.x = eye.x + eye.speed * dt
                if eye.x >= 800 then
                    eye.x = 800
                    eye.state = "climbing_up"
                end
            elseif eye.state == "climbing_up" or eye.state == "climbing_ladder" then
                -- Climbing up ladder to 2nd floor
                eye.x = 800
                eye.y = eye.y - 48 * dt
                if eye.y <= 61 then
                    eye.y = 61
                    eye.state = "f2_left"
                end
            elseif eye.state == "f2_left" or eye.state == "patrol_left" then
                -- Walking left on 2nd floor to the left edge
                eye.facing = -1
                eye.y = 61
                eye.x = eye.x - eye.speed * dt
                if eye.x <= 50 then
                    eye.x = 50
                    eye.state = "f2_wait_left"
                    eye.wait_timer = 1.5
                end
            elseif eye.state == "f2_wait_left" or eye.state == "patrol_wait_left" then
                -- Brief pause at left edge of 2nd floor
                eye.wait_timer = eye.wait_timer - dt
                if eye.wait_timer <= 0 then
                    eye.state = "f2_to_ladder"
                end
            elseif eye.state == "f2_to_ladder" or eye.state == "patrol_right" then
                -- Walking right on 2nd floor to the ladder
                eye.facing = 1
                eye.y = 61
                eye.x = eye.x + eye.speed * dt
                if eye.x >= 800 then
                    eye.x = 800
                    eye.state = "climbing_down"
                end
            elseif eye.state == "climbing_down" then
                -- Climbing down ladder to 1st floor
                eye.x = 800
                eye.y = eye.y + 48 * dt
                if eye.y >= 176 then
                    eye.y = 176
                    eye.state = "f1_left"
                end
            elseif eye.state == "f1_left" then
                -- Walking left on 1st floor across ground
                eye.facing = -1
                eye.y = 176
                eye.x = eye.x - eye.speed * dt
                if eye.x <= 50 then
                    eye.x = 50
                    eye.state = "f1_wait_left"
                    eye.wait_timer = 1.5
                end
            elseif eye.state == "f1_wait_left" then
                -- Brief pause at left edge of 1st floor
                eye.wait_timer = eye.wait_timer - dt
                if eye.wait_timer <= 0 then
                    eye.state = "f1_to_ladder"
                end
            end

            if player and not player.is_hidden and eye.state ~= "behind_desk" and eye.state ~= "waiting_delay" then
                local dy = math.abs(player.y - (eye.y + 48))
                if dy <= 24 then
                    local eye_cx = eye.x + 24
                    local dx = player.x - eye_cx
                    local dist = math.abs(dx)
                    local in_front = false

                    if eye.facing == -1 and dx < 0 and dist <= 120 then
                        in_front = true
                    elseif eye.facing == 1 and dx > 0 and dist <= 120 then
                        in_front = true
                    end

                    if in_front then
                        eye_caught_state = "targeting"
                        eye_caught_timer = 0
                        eye_caught_exploded = false
                        eye.facing = (player.x < eye_cx) and -1 or 1
                        GameState.set("is_dead", true)
                        if player then
                            player.vx = 0
                            player.vy = 0
                        end
                        if AudioManager and AudioManager.musFadeTo then
                            AudioManager.musFadeTo("data_fail", 0.85, 0.02)
                        end
                    end
                end
            end
        end

        if eye.exploding then
            eye.explode_timer = eye.explode_timer - dt
            if eye.explode_timer <= 0 then
                eye.exploding = false
            end
        end

        -- Dynamic music: panic track 'data_run' starts from first explosion and plays from start
        if eye_caught_state == "none" and (first_explosion_done or countdown_active or eye.state ~= "behind_desk") then
            if AudioManager and AudioManager.current_music and AudioManager.current_music.id ~= "data_run" then
                if AudioManager.musFadeTo then
                    AudioManager.musFadeTo("data_run", 0.70, 0.4)
                end
            end
        end

        -- Volume: quieter in closet (while hidden), normal outside
        local p = self.player or (desktop and desktop.player)
        local is_hidden = (p and p.is_hidden) or false
        if eye_caught_state == "none" and is_hidden ~= last_music_is_hidden then
            last_music_is_hidden = is_hidden
            if AudioManager and AudioManager.current_music then
                local target_vol = is_hidden and 0.32 or 0.70
                AudioManager.musFadeTo(nil, target_vol, 0.4)
            end
        end
    end)

    :onDraw(function(self)
        local font = (I18n and I18n.fonts and I18n.fonts.tahoma9) or love.graphics.getFont()
        if font then love.graphics.setFont(font) end

        if not eye.is_dead and eye.sheet then
            local frame_name = "idle"
            local scale_y = 1
            local oy_off = 0
            if eye.state == "climbing_down" then
                frame_name = "down"
                scale_y = -1
                oy_off = 48
            elseif eye.state == "climbing_ladder" or eye.state == "climbing_up" then
                frame_name = "down"
            elseif eye.state == "f1_to_ladder" or eye.state == "f2_left" or eye.state == "f2_to_ladder" or eye.state == "f1_left" or eye.state == "moving_to_ladder" or eye.state == "patrol_left" or eye.state == "patrol_right" then
                frame_name = "side"
            else
                frame_name = "idle"
            end

            love.graphics.setColor(1, 1, 1, 1)
            local ox = (eye.facing == -1) and 48 or 0
            eye.sheet:drawFrame(frame_name, eye.x + ox, eye.y + oy_off, 0, eye.facing, scale_y, 0, 0)
        elseif eye.exploding then
            local img = getExplosionImg()
            if img then
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.draw(img, eye.x - 16, eye.y - 10)
            end
        end

        if self.player and self.player.is_hidden then
            local text = "you're here"
            local tw = font and font:getWidth(text) or 48
            local bw = tw + 8
            local bh = 13
            local bx = 510 - math.floor(bw / 2)
            local by = 36

            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.rectangle("fill", bx, by, bw, bh)
            love.graphics.polygon("fill", bx + 16, by + bh, bx + 24, by + bh, bx + 20, by + bh + 5)

            love.graphics.setColor(0, 0, 0, 1)
            love.graphics.rectangle("line", bx, by, bw, bh)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.line(bx + 17, by + bh, bx + 23, by + bh)
            love.graphics.setColor(0, 0, 0, 1)
            love.graphics.line(bx + 16, by + bh, bx + 20, by + bh + 5)
            love.graphics.line(bx + 24, by + bh, bx + 20, by + bh + 5)

            love.graphics.print(text, bx + 4, by + 1)
        end

        -- Red laser from eye to player when caught
        if eye_caught_state == "targeting" and self.player then
            local p = self.player
            local ex = eye.x + (eye.facing == 1 and 30 or 18)
            local ey = eye.y + 24
            local px = p.x
            local py = p.y - 12

            local t = eye_caught_timer
            local beam_p = math.min(1.0, t / 0.12)
            local tx = ex + (px - ex) * beam_p
            local ty = ey + (py - ey) * beam_p

            -- Outer red glow
            love.graphics.setColor(1, 0, 0, 0.45 + 0.3 * math.sin(t * 30))
            love.graphics.setLineWidth(5)
            love.graphics.line(ex, ey, tx, ty)

            -- Mid laser beam
            love.graphics.setColor(1, 0.2, 0.2, 0.9)
            love.graphics.setLineWidth(2.5)
            love.graphics.line(ex, ey, tx, ty)

            -- Inner white core
            love.graphics.setColor(1, 0.9, 0.9, 0.95)
            love.graphics.setLineWidth(1)
            love.graphics.line(ex, ey, tx, ty)
            love.graphics.setLineWidth(1)

            -- Eye flare
            love.graphics.setColor(1, 0.2, 0.2, 0.8)
            love.graphics.circle("fill", ex, ey, 4 + math.sin(t * 20))
            love.graphics.setColor(1, 1, 1, 0.9)
            love.graphics.circle("fill", ex, ey, 2)

            -- Impact flare
            if beam_p >= 1.0 and not eye_caught_exploded then
                love.graphics.setColor(1, 0.1, 0.1, 0.85)
                love.graphics.circle("fill", px, py, 6 + 2 * math.sin(t * 25))
                love.graphics.setColor(1, 1, 1, 0.95)
                love.graphics.circle("fill", px, py, 2.5)
            end
        end

        if eye_caught_exploded and self.player then
            local img = getExplosionImg()
            if img then
                local t_exp = eye_caught_timer - 1.8
                local scale = 1.0 + math.min(0.4, t_exp * 0.25)
                love.graphics.setColor(1, 1, 1, math.max(0, 1.0 - t_exp * 0.25))
                love.graphics.draw(img, math.floor(self.player.x - 24 * scale), math.floor((self.player.y - 12) - 24 * scale), 0, scale, scale)
            end
        end
    end)

    :onKey(function(self, action, key)
        if action == "press" then
            if key == "escape" then
                SceneManager.goTo("menu")
                return
            end
            if disconnect_state == "disconnected" then
                if triggerRetry then triggerRetry() end
                return
            end
            if disconnect_state ~= "none" or eye_caught_state ~= "none" then
                return
            end
            if key == "return" then
                SceneManager.crossFade("level3", 0.4)
            elseif key == "e" then
                local p = self.player
                if p then
                    if canBackstabEye(p, eye) then
                        detonateEye()
                    elseif self.elements then
                        local down_held = (p.isHoldingKey and p:isHoldingKey("down")) or love.keyboard.isDown("down") or love.keyboard.isDown("s")
                        if not down_held then
                            for _, el in ipairs(self.elements) do
                                if el.is_bookshelf and not el.is_exploded and el.visible then
                                    local ecx = el.x + el.w / 2
                                    local ecy = el.y + el.h / 2
                                    local dx = math.abs(p.x - ecx)
                                    local dy = math.abs(p.y - (p.box_h or 24) / 2 - ecy)
                                    if dx <= (el.w / 2 + 18) and dy <= (el.h / 2 + 18) then
                                        if el.explode then
                                            el:explode()
                                            break
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end)
    :onMouse(function(self, action, gx, gy, button)
        if action == "press" and button == 1 then
            if disconnect_state == "disconnected" then
                if triggerRetry then triggerRetry() end
                return
            end
            if disconnect_state ~= "none" or eye_caught_state ~= "none" then
                return
            end

            local p = self.player
            if p and canBackstabEye(p, eye) then
                local cam_x = (self.camera and self.camera.x) or 0
                local cam_y = (self.camera and self.camera.y) or 0
                local mx = gx + cam_x
                local my = gy + cam_y
                if mx >= eye.x - 8 and mx <= eye.x + eye.w + 8 and my >= eye.y - 16 and my <= eye.y + eye.h + 10 then
                    detonateEye()
                end
            end
        end
    end)
    :build()

desktop.onBombDefused = function(self, shelf)
    triggerFirstExplosion(false)
    checkDoorUnlock()
end

desktop.onWrongBookshelfExploded = function(self, shelf, wrong_count)
    triggerFirstExplosion(true)
end

local orig_desktop_draw = desktop.draw
desktop.draw = function(self, shader)
    orig_desktop_draw(self, shader)

    local font = (I18n and I18n.fonts and I18n.fonts.tahoma9) or love.graphics.getFont()
    if font then love.graphics.setFont(font) end

    if countdown_active then
        local timer_w = 240
        local timer_h = 13
        local timer_x = 13
        local timer_y = 6

        love.graphics.setColor(0, 0, 0, 0.85)
        love.graphics.rectangle("fill", timer_x, timer_y, timer_w, timer_h)
        love.graphics.setColor(0.3, 0.3, 0.35, 1)
        love.graphics.rectangle("line", timer_x, timer_y, timer_w, timer_h)

        if countdown_timer <= 10.0 then
            love.graphics.setColor(1, 0.2, 0.2, 1)
        else
            love.graphics.setColor(1, 0.9, 0.3, 1)
        end
        local str = string.format("CONNECTION UNSTABLE, DISCONNECT IN %04.1fs", countdown_timer)
        love.graphics.print(str, timer_x + 4, timer_y + 2)
    end

    if eye_notification_timer > 0 and not eye.is_dead then
        local icon = getExclamationImg()
        local tray_x = 265
        local tray_y = 226

        if icon then
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(icon, tray_x, tray_y)
        end

        local balloon_w = 90
        local balloon_h = 20
        local balloon_x = 215
        local balloon_y = 200

        love.graphics.setColor(1, 1, 0.86, 0.95)
        love.graphics.rectangle("fill", balloon_x, balloon_y, balloon_w, balloon_h)
        love.graphics.setColor(0.2, 0.2, 0.2, 1)
        love.graphics.rectangle("line", balloon_x, balloon_y, balloon_w, balloon_h)

        love.graphics.setColor(1, 1, 0.86, 1)
        love.graphics.polygon("fill", tray_x + 2, balloon_y + balloon_h, tray_x + 8, balloon_y + balloon_h, tray_x + 5, tray_y - 1)
        love.graphics.setColor(0.2, 0.2, 0.2, 1)
        love.graphics.line(tray_x + 2, balloon_y + balloon_h, tray_x + 5, tray_y - 1)
        love.graphics.line(tray_x + 8, balloon_y + balloon_h, tray_x + 5, tray_y - 1)

        love.graphics.setColor(0.1, 0.1, 0.15, 1)
        love.graphics.print("The eye is coming", balloon_x + 5, balloon_y + 4)
    end

end

local function resetLevelState()
    AudioManager.musFadeTo("data", 0.7, 0.5)
    last_music_is_hidden = false
    GameState.set("wrong_bookshelves_exploded", 0)
    GameState.set("correct_bookshelves_exploded", 0)
    GameState.set("level3_cleared", false)
    GameState.set("is_dead", false)
    GameState.set("eye_killed", false)

    countdown_active = false
    countdown_timer = 40.0
    first_explosion_done = false
    eye_alert_timer = 0
    eye_notification_timer = 0
    eye_caught_state = "none"
    eye_caught_timer = 0
    eye_caught_exploded = false
    fail_reason = "none"
    restart_timer = 0
    exit_unlocked = false

    eye.x = 485
    eye.y = 145
    eye.facing = 1
    eye.state = "behind_desk"
    eye.wait_timer = 0
    eye.is_dead = false
    eye.exploding = false
    eye.explode_timer = 0

    if desktop then
        desktop:setElementVisible("window_readme", false)
        desktop:setElementActive("tab_readme", false)
        desktop:setElementVisible("tab_scanner", false)
        desktop:setElementActive("tab_scanner", false)
        desktop:setElementVisible("window_scanner", false)

        local d_exit = desktop:getElement("door_exit")
        if d_exit then
            d_exit.visible = false
            d_exit.unlocked = false
        end

        if desktop.elements then
            local default_variants = {
                "assets/level3/bookshelf1.png",
                "assets/level3/bookshelf2.png",
                "assets/level3/bookshelf3.png"
            }
            local shelf_idx = 0
            for _, el in ipairs(desktop.elements) do
                if el.is_bookshelf then
                    shelf_idx = shelf_idx + 1
                    if not el.orig_image or el.orig_image:find("boom") then
                        el.orig_image = default_variants[((shelf_idx - 1) % 3) + 1]
                    end
                    if el.reset then
                        el:reset()
                    else
                        el.is_exploded = false
                        el.exploding = false
                        el.explosion_timer = 0
                        el.image = el.orig_image
                        local ok, img = pcall(love.graphics.newImage, el.image)
                        if ok and img then
                            img:setFilter("nearest", "nearest")
                            el.img_obj = img
                        end
                    end
                end
            end
        end

        if desktop.camera then
            desktop.camera.x = 0
            desktop.camera.y = 0
        end
        desktop.cam_shake_timer = 0

        if desktop.player then
            desktop.player.x = 40
            desktop.player.y = 224
            desktop.player.vx = 0
            desktop.player.vy = 0
            desktop.player.is_hidden = false
            desktop.player.is_dead = false
        end
    end

    checkDoorUnlock()
end

local screen = PixelScreen.new({
    game = desktop,
    x = 320,
    y = 60,
    w = 1280,
    h = 960
})

triggerRetry = function()
    if disconnect_state ~= "disconnected" then return end
    resetLevelState()
    if screen then
        screen.needs_render = true
        screen:render(nil, true)
    end
    disconnect_state = "turning_on"
    disconnect_timer = 0
    if AudioManager and AudioManager.sfxPlay then
        pcall(AudioManager.sfxPlay, "turnon")
    end
end

local Level3Scene = GameScene.new({
    bg = "assets/bg/level3_bg.png",
    screen = screen,
    update = function(self, dt)
        if eye_caught_state == "targeting" then
            eye_caught_timer = eye_caught_timer + dt

            -- Minor charge shake
            if eye_caught_timer < 1.8 then
                if desktop and desktop.shakeCamera then
                    desktop:shakeCamera(0.1, 1.5)
                end
            end

            -- At 1.8s: Explosion!
            if eye_caught_timer >= 1.8 and not eye_caught_exploded then
                eye_caught_exploded = true
                if desktop and desktop.player then
                    desktop.player.is_dead = true
                end
                if desktop and desktop.shakeCamera then
                    desktop:shakeCamera(0.8, 10)
                end
                if AudioManager and AudioManager.sfxPlay then
                    pcall(AudioManager.sfxPlay, "explosion")
                end
            end

            -- At 4.70s: Monitor shuts down!
            if eye_caught_timer >= 4.70 then
                eye_caught_state = "none"
                disconnect_state = "shutting_down"
                disconnect_timer = 0
                fail_reason = "destroyed"
                if AudioManager and AudioManager.musStop then
                    AudioManager.musStop(0)
                end
                if AudioManager and AudioManager.sfxPlay then
                    pcall(AudioManager.sfxPlay, "shutdown")
                end
            end
            return
        end

        if disconnect_state == "shutting_down" then
            disconnect_timer = disconnect_timer + dt
            if disconnect_timer >= disconnect_duration then
                disconnect_state = "disconnected"
                disconnect_timer = disconnect_duration
            end
        elseif disconnect_state == "disconnected" then
            disconnect_blink = disconnect_blink + dt
        elseif disconnect_state == "turning_on" then
            disconnect_timer = disconnect_timer + dt
            if disconnect_timer >= disconnect_duration then
                disconnect_state = "none"
                disconnect_timer = 0
            end
        end
    end,
    on_bg_click = function(self, vx, vy, button)
        if button == 1 and disconnect_state == "disconnected" then
            if triggerRetry then triggerRetry() end
        end
    end,
    screen_draw_fn = function(s)
        if disconnect_state == "disconnected" then
            love.graphics.setColor(0.02, 0.03, 0.04, 1)
            love.graphics.rectangle("fill", s.x, s.y, s.w, s.h)

            local alpha = 0.35 + 0.35 * math.sin(disconnect_blink * 4)
            love.graphics.setColor(0.9, 0.4, 0.4, alpha)
            local f = getRetryFont()
            love.graphics.setFont(f)
            local txt = "[ Connection reset by host, click to retry ]"
            if fail_reason == "destroyed" then
                txt = "[ You've been destroyed, click to retry ]"
            end
            local scale = 2.4
            local tw = f:getWidth(txt) * scale
            if tw > s.w - 80 then
                scale = (s.w - 80) / f:getWidth(txt)
                tw = f:getWidth(txt) * scale
            end
            local th = f:getHeight() * scale
            love.graphics.print(txt, s.x + math.floor((s.w - tw) / 2), s.y + math.floor((s.h - th) / 2), 0, scale, scale)

        elseif disconnect_state == "shutting_down" or disconnect_state == "turning_on" then
            local dur = disconnect_duration
            local t_collapse = 0.38
            local t = disconnect_timer
            if disconnect_state == "turning_on" then
                t = math.max(0, dur - disconnect_timer)
            end

            if t < t_collapse then
                local p = t / t_collapse
                p = math.min(1.0, p)
                local p_eased = p * p * p

                local cur_h = math.max(4, s.h * (1 - p_eased))
                local cur_y = (s.y + s.h / 2) - cur_h / 2
                local cur_scale_y = (cur_h / s.h) * s.scale_y

                love.graphics.setColor(0.02, 0.03, 0.04, 1)
                love.graphics.rectangle("fill", s.x, s.y, s.w, s.h)

                Effects.drawCrt(s.canvas, s.x, cur_y, s.scale_x, cur_scale_y)

                local flash_alpha = p_eased * 0.95
                if flash_alpha > 0.01 then
                    love.graphics.setBlendMode("add")
                    love.graphics.setColor(0.75, 0.9, 1.0, flash_alpha)
                    love.graphics.rectangle("fill", s.x, cur_y, s.w, cur_h)

                    love.graphics.setColor(1, 1, 1, flash_alpha * 0.9)
                    love.graphics.rectangle("fill", s.x, s.y + s.h / 2 - 1, s.w, 2)
                    love.graphics.setBlendMode("alpha")
                end
            else
                local p = (t - t_collapse) / (dur - t_collapse)
                p = math.min(1.0, math.max(0, p))
                local p_inv = 1 - p
                local p_eased = p_inv * p_inv

                local cx = s.x + s.w / 2
                local cy = s.y + s.h / 2
                local beam_w = math.max(4, s.w * p_eased)

                love.graphics.setColor(0.02, 0.03, 0.04, 1)
                love.graphics.rectangle("fill", s.x, s.y, s.w, s.h)

                love.graphics.setColor(0.3, 0.75, 1.0, 0.7 * p_inv)
                love.graphics.rectangle("fill", cx - beam_w / 2, cy - 4, beam_w, 8)

                love.graphics.setColor(1, 1, 1, p_inv)
                love.graphics.rectangle("fill", cx - beam_w / 2, cy - 1, beam_w, 2)

                local spot_r = math.max(1, 6 * p_eased)
                love.graphics.circle("fill", cx, cy, spot_r)
            end
        else
            Effects.drawCrt(s.canvas, s.x, s.y, s.scale_x, s.scale_y)
        end
    end,
    enter = function(self)
        disconnect_state = "none"
        disconnect_timer = 0
        disconnect_blink = 0
        resetLevelState()
    end,
    leave = function(self)
        AudioManager.musStop(0.5)
    end
})

return Level3Scene
