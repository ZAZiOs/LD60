local json = require("src.lib.json")
local I18n = require("src.core.i18n")

local Settings = {
    data = {
        locale = "ru",
        master_volume = 1.0,
        music_volume = 0.2,
        sfx_volume = 1.0,
        muted = false,
        fullscreen = false,
        vsync = true,
        text_speed = "normal",
        soundcheck_enabled = false
    },

    speed_values = {
        slow = 20,
        normal = 35,
        fast = 70,
        instant = 9999
    }
}

local SETTINGS_FILE = "settings.json"

function Settings.init()
    if love.filesystem.getInfo and love.filesystem.getInfo(SETTINGS_FILE) then
        local contents, _ = love.filesystem.read(SETTINGS_FILE)
        if contents then
            local decoded, err = json.decode(contents)
            if type(decoded) == "table" then
                for k, v in pairs(decoded) do
                    Settings.data[k] = v
                end
            end
        end
    end

    Settings.applyAll()
end

function Settings.applyWindow()
    if not (love.window and love.window.isOpen()) then return end
    local cur_fs = love.window.getFullscreen()
    if cur_fs ~= Settings.data.fullscreen then
        if Settings.data.fullscreen then
            love.window.setFullscreen(true, "desktop")
        else
            love.window.setFullscreen(false)
            love.window.setMode(1280, 720, {
                resizable = true,
                minwidth = 1280,
                minheight = 720,
                highdpi = true,
                usedpiscale = false
            })
        end
    end
    if love.window.setVSync then
        love.window.setVSync(Settings.data.vsync and 1 or 0)
    end
    local ok, Viewport = pcall(require, "src.core.viewport")
    if ok and Viewport then
        Viewport.resize(love.graphics.getWidth(), love.graphics.getHeight())
    end
    local ok2, SceneManager = pcall(require, "src.core.scene_manager")
    if ok2 and SceneManager then
        SceneManager.resize(love.graphics.getWidth(), love.graphics.getHeight())
    end
end

function Settings.applyAll()
    if Settings.data.locale then
        I18n.setLocale(Settings.data.locale)
    end

    Settings.applyAudio()
    Settings.applyWindow()
end

function Settings.applyAudio()
    if not love.audio then return end
    if Settings.data.muted then
        love.audio.setVolume(0)
    else
        love.audio.setVolume(Settings.data.master_volume or 1.0)
    end

    local ok, am = pcall(require, "src.core.audio_manager")
    if ok and am and am.applySettings then
        am.applySettings()
    end
end

function Settings.save()
    local encoded = json.encode(Settings.data)
    love.filesystem.write(SETTINGS_FILE, encoded)
end

function Settings.get(key)
    return Settings.data[key]
end

function Settings.set(key, value)
    Settings.data[key] = value

    if key == "locale" then
        I18n.setLocale(value)
    elseif key == "master_volume" or key == "music_volume" or key == "sfx_volume" or key == "muted" then
        Settings.applyAudio()
    elseif key == "fullscreen" then
        Settings.applyWindow()
    elseif key == "vsync" then
        if love.window and love.window.setVSync then
            love.window.setVSync(value and 1 or 0)
        end
    end

    Settings.save()
end

function Settings.getTextCharSpeed()
    local spd = Settings.data.text_speed or "normal"
    return Settings.speed_values[spd] or 35
end

return Settings
