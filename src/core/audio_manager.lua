local Events = require("src.core.events")
local Settings = require("src.core.settings")

local AudioManager = {
    db = {
        default_fade_duration = 1.0,
        music = {},
        sfx = {}
    },

    master_volume = 1.0,
    music_volume = 0.8,
    sfx_volume = 1.0,
    is_muted = false,

    current_music = nil,

    fade_out_music = nil,

    music_fade = nil,

    sfx_cache = {},

    active_sfx = {},

    initialized = false
}

local function safe_new_source(path, source_type)
    if not love.audio or not love.filesystem then return nil end
    if not path or path == "" then return nil end

    if not love.filesystem.getInfo(path) then

        if not path:match("%.%w+$") then
            local try_ogg = path .. ".ogg"
            local try_mp3 = path .. ".mp3"
            local try_wav = path .. ".wav"
            if love.filesystem.getInfo(try_ogg) then
                path = try_ogg
            elseif love.filesystem.getInfo(try_mp3) then
                path = try_mp3
            elseif love.filesystem.getInfo(try_wav) then
                path = try_wav
            else
                print(string.format("[AudioManager] Warning: Audio file not found: %s", path))
                return nil
            end
        else
            print(string.format("[AudioManager] Warning: Audio file not found: %s", path))
            return nil
        end
    end

    local ok, source = pcall(love.audio.newSource, path, source_type or "static")
    if not ok then
        print(string.format("[AudioManager] Error loading audio '%s': %s", path, tostring(source)))
        return nil
    end
    return source
end

function AudioManager.init(db_override)
    if db_override then
        AudioManager.db = db_override
    else
        local ok, loaded_db = pcall(require, "src.game.audio_db")
        if ok and type(loaded_db) == "table" then
            AudioManager.db = loaded_db
        else
            AudioManager.db = { default_fade_duration = 1.0, music = {}, sfx = {} }
        end
    end

    AudioManager.applySettings()
    AudioManager._registerEvents()
    AudioManager.initialized = true
end

function AudioManager.setDatabase(db)
    AudioManager.db = db or { default_fade_duration = 1.0, music = {}, sfx = {} }
end

function AudioManager.applySettings()
    if Settings and Settings.get then
        AudioManager.master_volume = Settings.get("master_volume") or 1.0
        AudioManager.music_volume = Settings.get("music_volume") or 0.8
        AudioManager.sfx_volume = Settings.get("sfx_volume") or 1.0
        AudioManager.is_muted = Settings.get("muted") or false
    end

    AudioManager._updateActiveMusicVolume()
end

function AudioManager._getEffectiveMusicVolume(base_vol)
    if AudioManager.is_muted then return 0 end
    return (base_vol or 1.0) * AudioManager.music_volume * AudioManager.master_volume
end

function AudioManager._getEffectiveSFXVolume(base_vol)
    if AudioManager.is_muted then return 0 end
    return (base_vol or 1.0) * AudioManager.sfx_volume * AudioManager.master_volume
end

function AudioManager._updateActiveMusicVolume()
    if AudioManager.current_music then
        local eff_vol = AudioManager._getEffectiveMusicVolume(AudioManager.current_music.current_volume)
        if AudioManager.current_music.preloop_source then
            AudioManager.current_music.preloop_source:setVolume(eff_vol)
        end
        if AudioManager.current_music.loop_source then
            AudioManager.current_music.loop_source:setVolume(eff_vol)
        end
    end

    if AudioManager.fade_out_music then
        local eff_vol = AudioManager._getEffectiveMusicVolume(AudioManager.fade_out_music.current_volume)
        if AudioManager.fade_out_music.preloop_source then
            AudioManager.fade_out_music.preloop_source:setVolume(eff_vol)
        end
        if AudioManager.fade_out_music.loop_source then
            AudioManager.fade_out_music.loop_source:setVolume(eff_vol)
        end
        if AudioManager.fade_out_music.source then
            AudioManager.fade_out_music.source:setVolume(eff_vol)
        end
    end
end

local function resolve_music_entry(bgm_id)
    if type(bgm_id) == "table" then
        return bgm_id
    end

    if AudioManager.db and AudioManager.db.music and AudioManager.db.music[bgm_id] then
        local entry = AudioManager.db.music[bgm_id]
        return {
            id = bgm_id,
            preloop = entry.preloop or entry.intro or entry.pre_loop,
            loop = entry.loop or entry.path,
            volume = entry.volume or 1.0
        }
    end

    return {
        id = bgm_id,
        loop = bgm_id,
        volume = 1.0
    }
end

local function create_music_instance(entry, target_vol)
    local preloop_path = entry.preloop
    local loop_path = (type(entry.loop) == "string" and entry.loop) or entry.path

    local preloop_src = nil
    local preloop_dur = 0
    if preloop_path then
        preloop_src = safe_new_source(preloop_path, "static")
        if preloop_src then
            preloop_src:setLooping(false)
            preloop_dur = preloop_src:getDuration("seconds") or 0
        end
    end

    local loop_src = nil
    local loop_dur = 0
    if loop_path then
        loop_src = safe_new_source(loop_path, "static")
        if loop_src then
            loop_src:setLooping(true)
            loop_dur = loop_src:getDuration("seconds") or 0
        end
    end

    local initial_stage = preloop_src and "preloop" or "loop"
    local initial_src = preloop_src or loop_src

    if not initial_src then
        return nil
    end

    return {
        id = entry.id,
        stage = initial_stage,
        preloop_source = preloop_src,
        preloop_duration = preloop_dur,
        loop_source = loop_src,
        loop_duration = loop_dur,
        source = initial_src,
        base_volume = target_vol,
        current_volume = target_vol,
        target_volume = target_vol
    }
end

function AudioManager.musPlay(BGM, vol)
    if not BGM then return end

    local entry = resolve_music_entry(BGM)
    local target_vol = vol or entry.volume or 1.0

    if AudioManager.current_music and AudioManager.current_music.id == entry.id then
        AudioManager.current_music.target_volume = target_vol
        AudioManager.current_music.current_volume = target_vol
        AudioManager.music_fade = nil
        if AudioManager.current_music.source and not AudioManager.current_music.source:isPlaying() then
            AudioManager.current_music.source:play()
        end
        AudioManager._updateActiveMusicVolume()
        return
    end

    if AudioManager.fade_out_music then
        if AudioManager.fade_out_music.preloop_source then
            AudioManager.fade_out_music.preloop_source:stop()
        end
        if AudioManager.fade_out_music.loop_source then
            AudioManager.fade_out_music.loop_source:stop()
        end
        if AudioManager.fade_out_music.source then
            AudioManager.fade_out_music.source:stop()
        end
        AudioManager.fade_out_music = nil
    end

    if AudioManager.current_music then
        if AudioManager.current_music.preloop_source then
            AudioManager.current_music.preloop_source:stop()
        end
        if AudioManager.current_music.loop_source then
            AudioManager.current_music.loop_source:stop()
        end
        AudioManager.current_music = nil
    end

    AudioManager.music_fade = nil

    local inst = create_music_instance(entry, target_vol)
    if not inst then return end

    AudioManager.current_music = inst
    local eff_vol = AudioManager._getEffectiveMusicVolume(target_vol)
    inst.source:setVolume(eff_vol)
    inst.source:play()
end

function AudioManager.musFadeTo(BGM, vol, fadedur)
    local dur = fadedur or (AudioManager.db and AudioManager.db.default_fade_duration) or 1.0
    dur = math.max(0.01, dur)

    if not BGM or (AudioManager.current_music and AudioManager.current_music.id == BGM) then
        if not AudioManager.current_music then return end
        local target_vol = vol or AudioManager.current_music.base_volume or 1.0

        AudioManager.music_fade = {
            type = "fade_volume",
            start_vol = AudioManager.current_music.current_volume,
            target_vol = target_vol,
            duration = dur,
            timer = 0
        }
        return
    end

    local entry = resolve_music_entry(BGM)
    local target_vol = vol or entry.volume or 1.0

    if AudioManager.current_music and AudioManager.current_music.source and AudioManager.current_music.source:isPlaying() then
        if AudioManager.fade_out_music then
            if AudioManager.fade_out_music.preloop_source then
                AudioManager.fade_out_music.preloop_source:stop()
            end
            if AudioManager.fade_out_music.loop_source then
                AudioManager.fade_out_music.loop_source:stop()
            end
            if AudioManager.fade_out_music.source then
                AudioManager.fade_out_music.source:stop()
            end
        end

        AudioManager.fade_out_music = {
            id = AudioManager.current_music.id,
            source = AudioManager.current_music.source,
            preloop_source = AudioManager.current_music.preloop_source,
            loop_source = AudioManager.current_music.loop_source,
            start_volume = AudioManager.current_music.current_volume,
            current_volume = AudioManager.current_music.current_volume,
            duration = dur,
            timer = 0
        }
    end

    local inst = create_music_instance(entry, target_vol)
    if not inst then
        AudioManager.current_music = nil
        return
    end

    inst.current_volume = 0.0
    inst.source:setVolume(0)
    inst.source:play()
    AudioManager.current_music = inst

    AudioManager.music_fade = {
        type = "crossfade",
        start_vol = 0.0,
        target_vol = target_vol,
        duration = dur,
        timer = 0
    }
end

function AudioManager.musStop(fadedur)
    if not AudioManager.current_music then return end

    if fadedur and fadedur > 0 then
        local dur = math.max(0.01, fadedur)
        AudioManager.music_fade = {
            type = "fade_stop",
            start_vol = AudioManager.current_music.current_volume,
            target_vol = 0.0,
            duration = dur,
            timer = 0
        }
    else
        if AudioManager.current_music.preloop_source then
            AudioManager.current_music.preloop_source:stop()
        end
        if AudioManager.current_music.loop_source then
            AudioManager.current_music.loop_source:stop()
        end
        AudioManager.current_music = nil

        if AudioManager.fade_out_music then
            if AudioManager.fade_out_music.preloop_source then
                AudioManager.fade_out_music.preloop_source:stop()
            end
            if AudioManager.fade_out_music.loop_source then
                AudioManager.fade_out_music.loop_source:stop()
            end
            if AudioManager.fade_out_music.source then
                AudioManager.fade_out_music.source:stop()
            end
            AudioManager.fade_out_music = nil
        end
        AudioManager.music_fade = nil
    end
end

local function resolve_sfx_entry(snd_id)
    if type(snd_id) == "table" then
        return snd_id
    end

    if AudioManager.db and AudioManager.db.sfx and AudioManager.db.sfx[snd_id] then
        local entry = AudioManager.db.sfx[snd_id]
        return {
            id = snd_id,
            path = entry.path,
            volume = entry.volume or 1.0,
            pitch = entry.pitch or 1.0,
            pitch_variance = entry.pitch_variance or 0
        }
    end

    return {
        id = snd_id,
        path = snd_id,
        volume = 1.0,
        pitch = 1.0,
        pitch_variance = 0
    }
end

function AudioManager.sfxPlay(SND, vol, pitch)
    if not SND then return nil end

    local entry = resolve_sfx_entry(SND)

    if not AudioManager.sfx_cache[entry.path] then
        local src = safe_new_source(entry.path, "static")
        if src then
            AudioManager.sfx_cache[entry.path] = src
        else
            return nil
        end
    end

    local proto = AudioManager.sfx_cache[entry.path]
    if not proto then return nil end

    local ok, voice = pcall(proto.clone, proto)
    if not ok or not voice then
        voice = proto
    end

    local final_pitch = pitch or entry.pitch or 1.0
    if not pitch and entry.pitch_variance and entry.pitch_variance > 0 then
        local variance = (love.math.random() * 2 - 1) * entry.pitch_variance
        final_pitch = math.max(0.1, final_pitch + variance)
    end

    local target_vol = vol or entry.volume or 1.0
    local eff_vol = AudioManager._getEffectiveSFXVolume(target_vol)

    voice:setVolume(eff_vol)
    voice:setPitch(final_pitch)
    voice:play()

    table.insert(AudioManager.active_sfx, {
        source = voice,
        base_vol = target_vol
    })

    return voice
end

function AudioManager.update(dt)

    if AudioManager.current_music then
        local m = AudioManager.current_music
        if m.stage == "preloop" and m.preloop_source then
            local is_playing = m.preloop_source:isPlaying()
            local cur_pos = is_playing and m.preloop_source:tell("seconds") or m.preloop_duration
            local dur = m.preloop_duration or (m.preloop_source:getDuration("seconds")) or 0

            if not is_playing or (dur > 0 and cur_pos >= (dur - 0.02)) then
                m.stage = "loop"
                if m.loop_source then
                    local eff_vol = AudioManager._getEffectiveMusicVolume(m.current_volume)
                    m.loop_source:setVolume(eff_vol)
                    m.loop_source:play()
                    m.source = m.loop_source
                end
                if m.preloop_source:isPlaying() then
                    m.preloop_source:stop()
                end
            end
        end
    end

    if AudioManager.fade_out_music then
        local f = AudioManager.fade_out_music
        f.timer = f.timer + dt
        local progress = math.min(1.0, f.timer / f.duration)
        f.current_volume = (1.0 - progress) * f.start_volume
        local eff_vol = AudioManager._getEffectiveMusicVolume(f.current_volume)

        if f.preloop_source then f.preloop_source:setVolume(eff_vol) end
        if f.loop_source then f.loop_source:setVolume(eff_vol) end
        if f.source then f.source:setVolume(eff_vol) end

        if progress >= 1.0 then
            if f.preloop_source then f.preloop_source:stop() end
            if f.loop_source then f.loop_source:stop() end
            if f.source then f.source:stop() end
            AudioManager.fade_out_music = nil
        end
    end

    if AudioManager.music_fade and AudioManager.current_music then
        local fade = AudioManager.music_fade
        fade.timer = fade.timer + dt
        local progress = math.min(1.0, fade.timer / fade.duration)

        AudioManager.current_music.current_volume = fade.start_vol + (fade.target_vol - fade.start_vol) * progress
        local eff_vol = AudioManager._getEffectiveMusicVolume(AudioManager.current_music.current_volume)

        if AudioManager.current_music.preloop_source then
            AudioManager.current_music.preloop_source:setVolume(eff_vol)
        end
        if AudioManager.current_music.loop_source then
            AudioManager.current_music.loop_source:setVolume(eff_vol)
        end

        if progress >= 1.0 then
            if fade.type == "fade_stop" then
                if AudioManager.current_music.preloop_source then
                    AudioManager.current_music.preloop_source:stop()
                end
                if AudioManager.current_music.loop_source then
                    AudioManager.current_music.loop_source:stop()
                end
                AudioManager.current_music = nil
            end
            AudioManager.music_fade = nil
        end
    end

    for i = #AudioManager.active_sfx, 1, -1 do
        local item = AudioManager.active_sfx[i]
        if not item.source or not item.source:isPlaying() then
            table.remove(AudioManager.active_sfx, i)
        end
    end
end

function AudioManager._registerEvents()

    Events.on("musPlay", function(bgm, vol)
        AudioManager.musPlay(bgm, vol)
    end, "audio_manager")
    Events.on("mus:play", function(bgm, vol)
        AudioManager.musPlay(bgm, vol)
    end, "audio_manager")
    Events.on("audio:mus_play", function(bgm, vol)
        AudioManager.musPlay(bgm, vol)
    end, "audio_manager")
    Events.on("audio:play_music", function(bgm, vol)
        AudioManager.musPlay(bgm, vol)
    end, "audio_manager")

    Events.on("musFadeTo", function(bgm, vol, fadedur)
        AudioManager.musFadeTo(bgm, vol, fadedur)
    end, "audio_manager")
    Events.on("mus:fade_to", function(bgm, vol, fadedur)
        AudioManager.musFadeTo(bgm, vol, fadedur)
    end, "audio_manager")
    Events.on("audio:mus_fade_to", function(bgm, vol, fadedur)
        AudioManager.musFadeTo(bgm, vol, fadedur)
    end, "audio_manager")
    Events.on("audio:fade_music", function(bgm, vol, fadedur)
        AudioManager.musFadeTo(bgm, vol, fadedur)
    end, "audio_manager")

    Events.on("musStop", function(fadedur)
        AudioManager.musStop(fadedur)
    end, "audio_manager")
    Events.on("mus:stop", function(fadedur)
        AudioManager.musStop(fadedur)
    end, "audio_manager")
    Events.on("audio:mus_stop", function(fadedur)
        AudioManager.musStop(fadedur)
    end, "audio_manager")
    Events.on("audio:stop_music", function(fadedur)
        AudioManager.musStop(fadedur)
    end, "audio_manager")

    Events.on("sfxPlay", function(snd, vol, pitch)
        AudioManager.sfxPlay(snd, vol, pitch)
    end, "audio_manager")
    Events.on("sfx:play", function(snd, vol, pitch)
        AudioManager.sfxPlay(snd, vol, pitch)
    end, "audio_manager")
    Events.on("audio:sfx_play", function(snd, vol, pitch)
        AudioManager.sfxPlay(snd, vol, pitch)
    end, "audio_manager")
    Events.on("audio:play_sfx", function(snd, vol, pitch)
        AudioManager.sfxPlay(snd, vol, pitch)
    end, "audio_manager")
end

function AudioManager.getCurrentMusic()
    return AudioManager.current_music
end

function AudioManager.isPlayingMusic()
    return AudioManager.current_music ~= nil and AudioManager.current_music.source ~= nil and AudioManager.current_music.source:isPlaying()
end

return AudioManager
