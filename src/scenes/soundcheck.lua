local SceneManager = require("src.core.scene_manager")
local PixelScreen = require("src.core.pixel_screen")
local GameScene = require("src.core.game_scene")
local Effects = require("src.core.effects")
local I18n = require("src.core.i18n")
local SpritesheetManager = require("src.core.spritesheet_manager")
local AudioManager = require("src.core.audio_manager")
local Settings = require("src.core.settings")

local font_title = nil
local font_bold = nil
local font_regular = nil

local function getTitleFont()
    if not font_title then
        font_title = I18n.getFont({
            path = "assets/fnt/tahomabd.ttf",
            size = 10,
            hinting = "mono",
            filter = "nearest"
        })
    end
    return font_title
end

local function getBoldFont()
    if not font_bold then
        font_bold = I18n.getFont({
            path = "assets/fnt/tahomabd.ttf",
            size = 9,
            hinting = "mono",
            filter = "nearest"
        })
    end
    return font_bold
end

local function getRegularFont()
    if not font_regular then
        font_regular = I18n.getFont({
            path = "assets/fnt/tahoma.ttf",
            size = 8,
            hinting = "mono",
            filter = "nearest"
        })
    end
    return font_regular
end

local soundcheck_content = {
    tracks = {},
    selected_track_idx = 1,
    active_fade_dur = 0.5,
    cursor_sheet = nil,
    mouse_gx = 0,
    mouse_gy = 0,
    mouse_inside = false,
    ui_buttons = {},
    eq_bars = {},
    eq_timer = 0
}

function soundcheck_content:refreshTracks()
    self.tracks = {}
    if AudioManager.db and AudioManager.db.music then
        for id, data in pairs(AudioManager.db.music) do
            local fx_variants = { "base" }
            if data.fx and type(data.fx) == "table" then
                for fx_name, _ in pairs(data.fx) do
                    table.insert(fx_variants, fx_name)
                end
            end
            table.sort(fx_variants)

            table.insert(self.tracks, {
                id = id,
                data = data,
                fx_variants = fx_variants,
                has_fx = (#fx_variants > 1)
            })
        end
    end
    table.sort(self.tracks, function(a, b) return a.id < b.id end)

    if #self.tracks > 0 and (self.selected_track_idx < 1 or self.selected_track_idx > #self.tracks) then
        self.selected_track_idx = 1
    end
end

function soundcheck_content:enter()
    self:refreshTracks()
    if not self.cursor_sheet then
        self.cursor_sheet = SpritesheetManager.getSheet("assets/cursor.ini")
    end

    -- Initialize 12 visualizer bands
    self.eq_bars = {}
    for i = 1, 12 do
        self.eq_bars[i] = { val = 0.2, target = 0.2, speed = 8 + (i % 5) * 2 }
    end

    -- If a track is already playing in AudioManager, select it in the list
    if AudioManager.current_music then
        for i, t in ipairs(self.tracks) do
            if t.id == AudioManager.current_music.id then
                self.selected_track_idx = i
                break
            end
        end
    end
end

function soundcheck_content:leave()
end

function soundcheck_content:playSelected(target_fx)
    local t = self.tracks[self.selected_track_idx]
    if not t then return end

    local fx = target_fx
    if not fx then
        if AudioManager.current_music and AudioManager.current_music.id == t.id then
            fx = AudioManager.current_music.active_fx
        else
            fx = "base"
        end
    end

    AudioManager.musFadeTo(t.id, 0.8, self.active_fade_dur, fx)
end

function soundcheck_content:toggleFx()
    if not AudioManager.current_music then
        self:playSelected("base")
        return
    end

    local cur_track_id = AudioManager.current_music.id
    local current_track_data = nil
    for _, t in ipairs(self.tracks) do
        if t.id == cur_track_id then
            current_track_data = t
            break
        end
    end

    if not current_track_data or not current_track_data.has_fx then
        return
    end

    local cur_fx = AudioManager.current_music.active_fx or "base"
    local vars = current_track_data.fx_variants
    local next_fx = vars[1]
    for i, v in ipairs(vars) do
        if v == cur_fx then
            next_fx = vars[(i % #vars) + 1]
            break
        end
    end

    AudioManager.setMusicFx(next_fx, self.active_fade_dur)
end

function soundcheck_content:update(dt)
    self.eq_timer = self.eq_timer + dt

    local is_playing = AudioManager.current_music and AudioManager.current_music.source and AudioManager.current_music.source:isPlaying()

    for i = 1, 12 do
        local b = self.eq_bars[i]
        if is_playing then
            -- Rhythmic procedural equalizer modulation
            local phase = self.eq_timer * 9 + i * 0.7
            local noise = (math.sin(phase) * 0.5 + 0.5) * (math.cos(phase * 1.6 + i) * 0.4 + 0.6)
            b.target = math.max(0.1, math.min(1.0, noise + (i % 3 == 0 and 0.25 or 0)))
        else
            b.target = 0
        end
        b.val = b.val + (b.target - b.val) * math.min(1.0, dt * 14)
    end
end

function soundcheck_content:mousemoved(gx, gy, gdx, gdy, istouch, inside)
    self.mouse_gx = gx
    self.mouse_gy = gy
    self.mouse_inside = inside
end

function soundcheck_content:mousepressed(gx, gy, button)
    if button == 1 then
        for _, btn in ipairs(self.ui_buttons) do
            if gx >= btn.x and gx < btn.x + btn.w and gy >= btn.y and gy < btn.y + btn.h then
                if btn.onClick then
                    btn.onClick()
                end
                return
            end
        end
    end
end

function soundcheck_content:keypressed(key, scancode, isrepeat)
    if key == "up" or key == "w" then
        self.selected_track_idx = math.max(1, self.selected_track_idx - 1)
    elseif key == "down" or key == "s" then
        self.selected_track_idx = math.min(#self.tracks, self.selected_track_idx + 1)
    elseif key == "return" or key == "space" then
        self:playSelected()
    elseif key == "f" or key == "tab" then
        self:toggleFx()
    elseif key == "x" then
        AudioManager.musStop(self.active_fade_dur)
    elseif key == "escape" then
        SceneManager.goTo("menu")
    elseif key == "-" or key == "[" then
        local cur = Settings.get("music_volume") or 0.8
        Settings.set("music_volume", math.max(0, cur - 0.1))
        AudioManager.applySettings()
    elseif key == "=" or key == "+" or key == "]" then
        local cur = Settings.get("music_volume") or 0.8
        Settings.set("music_volume", math.min(1.0, cur + 0.1))
        AudioManager.applySettings()
    end
end

function soundcheck_content:draw()
    self.ui_buttons = {}

    local f_title = getTitleFont()
    local f_bold = getBoldFont()
    local f_reg = getRegularFont()

    -- Dark Synth / Audio Rack Background
    love.graphics.setColor(0.04, 0.05, 0.08, 1)
    love.graphics.rectangle("fill", 0, 0, 320, 240)

    -- Top Header Panel
    love.graphics.setColor(0.09, 0.13, 0.20, 1)
    love.graphics.rectangle("fill", 8, 6, 304, 18)
    love.graphics.setColor(0.2, 0.35, 0.55, 1)
    love.graphics.rectangle("line", 8, 6, 304, 18)

    love.graphics.setFont(f_title)
    love.graphics.setColor(0.35, 0.85, 1, 1)
    love.graphics.print("SOUNDCHECK // AUDIO ROUTING & FX TEST", 14, 9)

    -- Menu Button (Top Right)
    local btn_menu = { x = 250, y = 8, w = 58, h = 14 }
    local is_menu_hov = self.mouse_gx >= btn_menu.x and self.mouse_gx < btn_menu.x + btn_menu.w and
                        self.mouse_gy >= btn_menu.y and self.mouse_gy < btn_menu.y + btn_menu.h
    love.graphics.setColor(is_menu_hov and 0.25 or 0.14, is_menu_hov and 0.35 or 0.20, is_menu_hov and 0.50 or 0.28, 1)
    love.graphics.rectangle("fill", btn_menu.x, btn_menu.y, btn_menu.w, btn_menu.h)
    love.graphics.setColor(is_menu_hov and 0.6 or 0.35, is_menu_hov and 0.85 or 0.55, 1, 1)
    love.graphics.rectangle("line", btn_menu.x, btn_menu.y, btn_menu.w, btn_menu.h)
    love.graphics.setFont(f_reg)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("ESC: MENU", btn_menu.x + 8, btn_menu.y + 2)

    table.insert(self.ui_buttons, {
        x = btn_menu.x, y = btn_menu.y, w = btn_menu.w, h = btn_menu.h,
        onClick = function() SceneManager.goTo("menu") end
    })

    -- ========================================================================
    -- Left Panel: Track List (x = 8, y = 28, w = 144, h = 126)
    -- ========================================================================
    love.graphics.setColor(0.06, 0.08, 0.12, 1)
    love.graphics.rectangle("fill", 8, 28, 144, 126)
    love.graphics.setColor(0.18, 0.24, 0.35, 1)
    love.graphics.rectangle("line", 8, 28, 144, 126)

    love.graphics.setColor(0.12, 0.17, 0.25, 1)
    love.graphics.rectangle("fill", 8, 28, 144, 14)
    love.graphics.setColor(0.3, 0.75, 0.95, 1)
    love.graphics.setFont(f_bold)
    love.graphics.print("AVAILABLE TRACKS", 12, 30)

    local active_playing_id = AudioManager.current_music and AudioManager.current_music.id

    for i, t in ipairs(self.tracks) do
        local item_y = 44 + (i - 1) * 20
        local is_selected = (i == self.selected_track_idx)
        local is_playing = (t.id == active_playing_id)

        local is_hover = self.mouse_gx >= 10 and self.mouse_gx < 150 and self.mouse_gy >= item_y and self.mouse_gy < item_y + 18

        if is_selected then
            love.graphics.setColor(0.15, 0.32, 0.55, 0.9)
            love.graphics.rectangle("fill", 10, item_y, 140, 18)
            love.graphics.setColor(0.4, 0.8, 1.0, 1)
            love.graphics.rectangle("line", 10, item_y, 140, 18)
        elseif is_hover then
            love.graphics.setColor(0.10, 0.16, 0.24, 0.7)
            love.graphics.rectangle("fill", 10, item_y, 140, 18)
            love.graphics.setColor(0.25, 0.45, 0.65, 0.8)
            love.graphics.rectangle("line", 10, item_y, 140, 18)
        end

        -- Status Indicator dot/icon
        if is_playing then
            love.graphics.setColor(0.2, 1.0, 0.4, 1)
            love.graphics.print("▶", 13, item_y + 3)
        else
            love.graphics.setColor(0.3, 0.4, 0.5, 0.7)
            love.graphics.print("•", 14, item_y + 3)
        end

        -- Track Title
        love.graphics.setFont(f_bold)
        love.graphics.setColor(is_selected and {1, 1, 1, 1} or {0.75, 0.82, 0.9, 1})
        love.graphics.print(t.id, 24, item_y + 3)

        -- FX Variant Badge
        if t.has_fx then
            love.graphics.setColor(0.85, 0.4, 0.9, 0.9)
            love.graphics.setFont(f_reg)
            love.graphics.print("[FX]", 118, item_y + 4)
        end

        table.insert(self.ui_buttons, {
            x = 10, y = item_y, w = 140, h = 18,
            onClick = function()
                self.selected_track_idx = i
                self:playSelected()
            end
        })
    end

    -- ========================================================================
    -- Right Panel: FX & DSP Controls (x = 156, y = 28, w = 156, h = 126)
    -- ========================================================================
    love.graphics.setColor(0.06, 0.08, 0.12, 1)
    love.graphics.rectangle("fill", 156, 28, 156, 126)
    love.graphics.setColor(0.18, 0.24, 0.35, 1)
    love.graphics.rectangle("line", 156, 28, 156, 126)

    love.graphics.setColor(0.12, 0.17, 0.25, 1)
    love.graphics.rectangle("fill", 156, 28, 156, 14)
    love.graphics.setColor(0.3, 0.75, 0.95, 1)
    love.graphics.setFont(f_bold)
    love.graphics.print("FX ROUTING & DSP", 160, 30)

    local current_playing_track = nil
    for _, t in ipairs(self.tracks) do
        if t.id == active_playing_id then
            current_playing_track = t
            break
        end
    end

    local current_active_fx = AudioManager.current_music and AudioManager.current_music.active_fx or "base"

    if current_playing_track and current_playing_track.has_fx then
        love.graphics.setFont(f_reg)
        love.graphics.setColor(0.7, 0.8, 0.9, 1)
        love.graphics.print("Active Variant: " .. string.upper(current_active_fx), 162, 46)

        -- Buttons for each variant
        for idx, fx_name in ipairs(current_playing_track.fx_variants) do
            local by = 60 + (idx - 1) * 22
            local is_active_fx = (fx_name == current_active_fx)
            local is_hov = self.mouse_gx >= 162 and self.mouse_gx < 304 and self.mouse_gy >= by and self.mouse_gy < by + 18

            if is_active_fx then
                love.graphics.setColor(0.12, 0.45, 0.3, 1)
                love.graphics.rectangle("fill", 162, by, 142, 18)
                love.graphics.setColor(0.3, 1.0, 0.6, 1)
                love.graphics.rectangle("line", 162, by, 142, 18)
                love.graphics.rectangle("line", 163, by + 1, 140, 16)
            elseif is_hov then
                love.graphics.setColor(0.15, 0.24, 0.35, 1)
                love.graphics.rectangle("fill", 162, by, 142, 18)
                love.graphics.setColor(0.4, 0.75, 1.0, 1)
                love.graphics.rectangle("line", 162, by, 142, 18)
            else
                love.graphics.setColor(0.09, 0.12, 0.18, 0.9)
                love.graphics.rectangle("fill", 162, by, 142, 18)
                love.graphics.setColor(0.22, 0.3, 0.42, 0.8)
                love.graphics.rectangle("line", 162, by, 142, 18)
            end

            love.graphics.setFont(f_bold)
            love.graphics.setColor(is_active_fx and {0.4, 1.0, 0.7, 1} or {0.8, 0.88, 0.95, 1})
            local label = (fx_name == "base" and "DRY: " or "WET: ") .. string.upper(fx_name)
            love.graphics.print(label, 168, by + 4)

            if is_active_fx then
                love.graphics.setFont(f_reg)
                love.graphics.setColor(0.3, 1.0, 0.5, 1)
                love.graphics.print("[ACTIVE]", 254, by + 4)
            end

            table.insert(self.ui_buttons, {
                x = 162, y = by, w = 142, h = 18,
                onClick = function()
                    AudioManager.setMusicFx(fx_name, self.active_fade_dur)
                end
            })
        end

        -- Crossfade duration presets
        love.graphics.setFont(f_reg)
        love.graphics.setColor(0.6, 0.7, 0.8, 1)
        love.graphics.print("Crossfade Duration:", 162, 114)

        local fades = {
            { dur = 0.0, label = "0s" },
            { dur = 0.3, label = "0.3s" },
            { dur = 0.8, label = "0.8s" },
            { dur = 1.5, label = "1.5s" }
        }

        for fi, fv in ipairs(fades) do
            local fbx = 162 + (fi - 1) * 36
            local fby = 126
            local is_cur = (math.abs(self.active_fade_dur - fv.dur) < 0.05)
            local is_fhov = self.mouse_gx >= fbx and self.mouse_gx < fbx + 32 and self.mouse_gy >= fby and self.mouse_gy < fby + 16

            if is_cur then
                love.graphics.setColor(0.2, 0.4, 0.65, 1)
                love.graphics.rectangle("fill", fbx, fby, 32, 16)
                love.graphics.setColor(0.4, 0.85, 1, 1)
                love.graphics.rectangle("line", fbx, fby, 32, 16)
            else
                love.graphics.setColor(0.08, 0.11, 0.16, 1)
                love.graphics.rectangle("fill", fbx, fby, 32, 16)
                love.graphics.setColor(is_fhov and 0.4 or 0.2, is_fhov and 0.6 or 0.3, is_fhov and 0.8 or 0.4, 1)
                love.graphics.rectangle("line", fbx, fby, 32, 16)
            end

            love.graphics.setColor(is_cur and {1, 1, 1, 1} or {0.7, 0.8, 0.9, 1})
            love.graphics.print(fv.label, fbx + 6, fby + 3)

            table.insert(self.ui_buttons, {
                x = fbx, y = fby, w = 32, h = 16,
                onClick = function() self.active_fade_dur = fv.dur end
            })
        end

    else
        love.graphics.setFont(f_reg)
        love.graphics.setColor(0.5, 0.6, 0.7, 0.9)
        love.graphics.print("No FX variants defined for", 162, 50)
        love.graphics.print("the currently active track.", 162, 62)
        love.graphics.setColor(0.35, 0.75, 0.95, 1)
        love.graphics.print("-> Select track 'cat' to test", 162, 82)
        love.graphics.print("   dry vs reverb FX routing!", 162, 94)
    end

    -- ========================================================================
    -- Bottom Panel: Transport & Equalizer (x = 8, y = 158, w = 304, h = 76)
    -- ========================================================================
    love.graphics.setColor(0.05, 0.07, 0.10, 1)
    love.graphics.rectangle("fill", 8, 158, 304, 76)
    love.graphics.setColor(0.18, 0.24, 0.35, 1)
    love.graphics.rectangle("line", 8, 158, 304, 76)

    -- Status string
    local status_str = "STANDBY"
    local cur_time = 0
    local max_time = 0
    local stage_str = "IDLE"

    if AudioManager.current_music then
        status_str = string.upper(AudioManager.current_music.id) .. " (" .. string.upper(AudioManager.current_music.active_fx or "base") .. ")"
        stage_str = string.upper(AudioManager.current_music.stage or "LOOP")
        if AudioManager.current_music.source then
            cur_time = AudioManager.current_music.source:tell("seconds") or 0
            max_time = AudioManager.current_music.source:getDuration("seconds") or 0
        end
    end

    love.graphics.setFont(f_bold)
    love.graphics.setColor(0.9, 0.95, 1, 1)
    love.graphics.print("NOW PLAYING: " .. status_str, 14, 163)

    love.graphics.setFont(f_reg)
    love.graphics.setColor(0.4, 0.9, 0.5, 1)
    love.graphics.print("STAGE: [" .. stage_str .. "]", 186, 163)

    -- Progress bar
    local progress = (max_time > 0) and math.min(1.0, cur_time / max_time) or 0
    love.graphics.setColor(0.08, 0.12, 0.18, 1)
    love.graphics.rectangle("fill", 14, 175, 180, 5)
    love.graphics.setColor(0.25, 0.7, 1.0, 1)
    love.graphics.rectangle("fill", 14, 175, math.floor(180 * progress), 5)
    love.graphics.setColor(0.3, 0.45, 0.6, 1)
    love.graphics.rectangle("line", 14, 175, 180, 5)

    -- Time display
    local time_text = string.format("%02d:%02d / %02d:%02d", math.floor(cur_time / 60), math.floor(cur_time % 60), math.floor(max_time / 60), math.floor(max_time % 60))
    love.graphics.setColor(0.65, 0.75, 0.85, 1)
    love.graphics.print(time_text, 14, 182)

    -- Equalizer Display (12 vertical bars)
    local eq_x = 208
    local eq_y = 175
    local eq_w = 94
    local eq_h = 32

    love.graphics.setColor(0.02, 0.03, 0.05, 1)
    love.graphics.rectangle("fill", eq_x, eq_y, eq_w, eq_h)
    love.graphics.setColor(0.15, 0.22, 0.32, 1)
    love.graphics.rectangle("line", eq_x, eq_y, eq_w, eq_h)

    for i = 1, 12 do
        local bx = eq_x + 3 + (i - 1) * 7.5
        local bar_val = self.eq_bars[i].val
        local bar_h = math.floor((eq_h - 4) * bar_val)
        local by = eq_y + eq_h - 2 - bar_h

        -- Segmented LED colors (green bottom, yellow middle, red top)
        if bar_val > 0.8 then
            love.graphics.setColor(1.0, 0.2, 0.2, 1)
        elseif bar_val > 0.5 then
            love.graphics.setColor(1.0, 0.85, 0.2, 1)
        else
            love.graphics.setColor(0.2, 0.9, 0.35, 1)
        end
        love.graphics.rectangle("fill", bx, by, 5, bar_h)
    end

    -- Control buttons row
    local controls = {
        { id = "play", label = "▶ PLAY", x = 14, w = 42, fn = function() self:playSelected() end },
        { id = "stop", label = "⏹ STOP", x = 60, w = 42, fn = function() AudioManager.musStop(self.active_fade_dur) end },
        { id = "fx",   label = "⚡ FX",   x = 106, w = 38, fn = function() self:toggleFx() end },
    }

    for _, c in ipairs(controls) do
        local is_chov = self.mouse_gx >= c.x and self.mouse_gx < c.x + c.w and self.mouse_gy >= 195 and self.mouse_gy < 195 + 16
        love.graphics.setColor(is_chov and 0.20 or 0.11, is_chov and 0.30 or 0.16, is_chov and 0.45 or 0.24, 1)
        love.graphics.rectangle("fill", c.x, 195, c.w, 16)
        love.graphics.setColor(is_chov and 0.45 or 0.28, is_chov and 0.75 or 0.45, is_chov and 1.0 or 0.65, 1)
        love.graphics.rectangle("line", c.x, 195, c.w, 16)

        love.graphics.setFont(f_bold)
        love.graphics.setColor(is_chov and {1, 1, 1, 1} or {0.8, 0.9, 1, 1})
        love.graphics.print(c.label, c.x + 4, 198)

        table.insert(self.ui_buttons, {
            x = c.x, y = 195, w = c.w, h = 16,
            onClick = c.fn
        })
    end

    -- Volume controls
    local cur_vol = Settings.get("music_volume") or 0.8
    local vol_text = string.format("VOL: %d%%", math.floor(cur_vol * 100))
    love.graphics.setFont(f_bold)
    love.graphics.setColor(0.85, 0.92, 1, 1)
    love.graphics.print(vol_text, 148, 198)

    local btn_vol_down = { x = 186, y = 196, w = 12, h = 14 }
    local is_vd_hov = self.mouse_gx >= btn_vol_down.x and self.mouse_gx < btn_vol_down.x + btn_vol_down.w and self.mouse_gy >= btn_vol_down.y and self.mouse_gy < btn_vol_down.y + btn_vol_down.h
    love.graphics.setColor(is_vd_hov and 0.25 or 0.12, is_vd_hov and 0.35 or 0.18, is_vd_hov and 0.5 or 0.25, 1)
    love.graphics.rectangle("fill", btn_vol_down.x, btn_vol_down.y, btn_vol_down.w, btn_vol_down.h)
    love.graphics.setColor(0.35, 0.6, 0.8, 1)
    love.graphics.rectangle("line", btn_vol_down.x, btn_vol_down.y, btn_vol_down.w, btn_vol_down.h)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("-", btn_vol_down.x + 3, btn_vol_down.y + 1)
    table.insert(self.ui_buttons, {
        x = btn_vol_down.x, y = btn_vol_down.y, w = btn_vol_down.w, h = btn_vol_down.h,
        onClick = function()
            Settings.set("music_volume", math.max(0, cur_vol - 0.1))
            AudioManager.applySettings()
        end
    })

    local btn_vol_up = { x = 200, y = 196, w = 12, h = 14 }
    local is_vu_hov = self.mouse_gx >= btn_vol_up.x and self.mouse_gx < btn_vol_up.x + btn_vol_up.w and self.mouse_gy >= btn_vol_up.y and self.mouse_gy < btn_vol_up.y + btn_vol_up.h
    love.graphics.setColor(is_vu_hov and 0.25 or 0.12, is_vu_hov and 0.35 or 0.18, is_vu_hov and 0.5 or 0.25, 1)
    love.graphics.rectangle("fill", btn_vol_up.x, btn_vol_up.y, btn_vol_up.w, btn_vol_up.h)
    love.graphics.setColor(0.35, 0.6, 0.8, 1)
    love.graphics.rectangle("line", btn_vol_up.x, btn_vol_up.y, btn_vol_up.w, btn_vol_up.h)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("+", btn_vol_up.x + 2, btn_vol_up.y + 1)
    table.insert(self.ui_buttons, {
        x = btn_vol_up.x, y = btn_vol_up.y, w = btn_vol_up.w, h = btn_vol_up.h,
        onClick = function()
            Settings.set("music_volume", math.min(1.0, cur_vol + 0.1))
            AudioManager.applySettings()
        end
    })

    -- Keyboard Hints Bar (Bottom)
    love.graphics.setFont(f_reg)
    love.graphics.setColor(0.4, 0.52, 0.65, 1)
    local hint_txt = "[↑/↓] Select  [SPACE] Play  [F/TAB] Toggle FX  [X] Stop  [ESC] Menu  [[]/] Switch Room"
    love.graphics.print(hint_txt, 14, 218)

    -- Retro cursor inside monitor
    if self.mouse_inside and self.cursor_sheet then
        love.graphics.setColor(1, 1, 1, 1)
        self.cursor_sheet:drawFrame("cursor", self.mouse_gx, self.mouse_gy, 0, 1, 1, 0, 0)
    end
end

local screen = PixelScreen.new({
    game = soundcheck_content,
    x = 320,
    y = 60,
    w = 1280,
    h = 960
})

local SoundCheckScene = GameScene.new({
    bg = "assets/bg/intro_bg.png",
    screen = screen,
    screen_draw_fn = function(s)
        Effects.drawCrt(s.canvas, s.x, s.y, s.scale_x, s.scale_y)
    end,
    enter = function(self)
        if soundcheck_content.enter then
            soundcheck_content:enter()
        end
    end,
    leave = function(self)
        if soundcheck_content.leave then
            soundcheck_content:leave()
        end
    end
})

return SoundCheckScene
