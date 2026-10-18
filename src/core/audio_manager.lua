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
        local m = AudioManager.current_music
        local eff_vol = AudioManager._getEffectiveMusicVolume(m.current_volume)
        if m.fx_fade then
            local progress = math.min(1.0, m.fx_fade.timer / m.fx_fade.duration)
            if m.fx_fade.from_src and m.fx_fade.from_src:isPlaying() then
                m.fx_fade.from_src:setVolume((1.0 - progress) * eff_vol)
            end
            if m.fx_fade.to_src and m.fx_fade.to_src:isPlaying() then
                m.fx_fade.to_src:setVolume(progress * eff_vol)
            end
        else
            if m.source and m.source:isPlaying() then
                m.source:setVolume(eff_vol)
            end
            if m.stage == "preloop" and m.preloop_source and m.preloop_source:isPlaying() then
                m.preloop_source:setVolume(eff_vol)
            elseif m.stage == "loop" and m.loop_source and m.loop_source:isPlaying() then
                m.loop_source:setVolume(eff_vol)
            end
        end
    end

    if AudioManager.fade_out_music then
        local f = AudioManager.fade_out_music
        local eff_vol = AudioManager._getEffectiveMusicVolume(f.current_volume)
        if f.sources then
            for _, s in ipairs(f.sources) do
                if s and s:isPlaying() then
                    s:setVolume(eff_vol)
                end
            end
        else
            if f.preloop_source and f.preloop_source:isPlaying() then f.preloop_source:setVolume(eff_vol) end
            if f.loop_source and f.loop_source:isPlaying() then f.loop_source:setVolume(eff_vol) end
            if f.source and f.source:isPlaying() then f.source:setVolume(eff_vol) end
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
            volume = entry.volume or 1.0,
            fx = entry.fx
        }
    end

    return {
        id = bgm_id,
        loop = bgm_id,
        volume = 1.0
    }
end

local function get_variant_source(variant, stage)
    if not variant then return nil end
    if stage == "preloop" then
        return variant.preloop_source or variant.loop_source
    else
        return variant.loop_source or variant.preloop_source
    end
end

local function stop_music_instance(inst)
    if not inst then return end
    if inst.variants then
        for _, v in pairs(inst.variants) do
            if v.preloop_source and v.preloop_source:isPlaying() then
                v.preloop_source:stop()
            end
            if v.loop_source and v.loop_source:isPlaying() then
                v.loop_source:stop()
            end
        end
    end
    if inst.preloop_source and inst.preloop_source:isPlaying() then
        inst.preloop_source:stop()
    end
    if inst.loop_source and inst.loop_source:isPlaying() then
        inst.loop_source:stop()
    end
    if inst.source and inst.source:isPlaying() then
        inst.source:stop()
    end
end

local function create_music_instance(entry, target_vol, target_fx)
    local variants = {}

    -- 1. Base variant
    local base_pre_src = nil
    local base_pre_dur = 0
    if entry.preloop then
        base_pre_src = safe_new_source(entry.preloop, "static")
        if base_pre_src then
            base_pre_src:setLooping(false)
            base_pre_dur = base_pre_src:getDuration("seconds") or 0
        end
    end

    local base_loop_src = nil
    local base_loop_dur = 0
    local loop_path = (type(entry.loop) == "string" and entry.loop) or entry.path
    if loop_path then
        base_loop_src = safe_new_source(loop_path, "static")
        if base_loop_src then
            base_loop_src:setLooping(true)
            base_loop_dur = base_loop_src:getDuration("seconds") or 0
        end
    end

    if not base_pre_src and not base_loop_src then
        return nil
    end

    variants["base"] = {
        name = "base",
        preloop_source = base_pre_src,
        preloop_duration = base_pre_dur,
        loop_source = base_loop_src,
        loop_duration = base_loop_dur
    }

    -- 2. FX variants
    if entry.fx and type(entry.fx) == "table" then
        for fx_name, fx_entry in pairs(entry.fx) do
            if type(fx_entry) == "table" then
                local fx_pre_src = nil
                local fx_pre_dur = 0
                local fx_pre_path = fx_entry.preloop or fx_entry.intro or fx_entry.pre_loop
                if fx_pre_path then
                    fx_pre_src = safe_new_source(fx_pre_path, "static")
                    if fx_pre_src then
                        fx_pre_src:setLooping(false)
                        fx_pre_dur = fx_pre_src:getDuration("seconds") or 0
                    end
                end

                local fx_loop_src = nil
                local fx_loop_dur = 0
                local fx_loop_path = (type(fx_entry.loop) == "string" and fx_entry.loop) or fx_entry.path
                if fx_loop_path then
                    fx_loop_src = safe_new_source(fx_loop_path, "static")
                    if fx_loop_src then
                        fx_loop_src:setLooping(true)
                        fx_loop_dur = fx_loop_src:getDuration("seconds") or 0
                    end
                end

                if fx_pre_src or fx_loop_src then
                    variants[fx_name] = {
                        name = fx_name,
                        preloop_source = fx_pre_src,
                        preloop_duration = fx_pre_dur,
                        loop_source = fx_loop_src,
                        loop_duration = fx_loop_dur
                    }
                end
            end
        end
    end

    local active_fx = (target_fx and variants[target_fx]) and target_fx or "base"
    local cur_variant = variants[active_fx] or variants["base"]
    local initial_stage = cur_variant.preloop_source and "preloop" or "loop"
    local initial_src = (initial_stage == "preloop" and cur_variant.preloop_source) or cur_variant.loop_source

    if not initial_src then
        cur_variant = variants["base"]
        initial_stage = cur_variant.preloop_source and "preloop" or "loop"
        initial_src = cur_variant.preloop_source or cur_variant.loop_source
        active_fx = "base"
    end

    if not initial_src then
        return nil
    end

    return {
        id = entry.id,
        stage = initial_stage,
        active_fx = active_fx,
        variants = variants,
        source = initial_src,
        preloop_source = cur_variant.preloop_source,
        preloop_duration = cur_variant.preloop_duration,
        loop_source = cur_variant.loop_source,
        loop_duration = cur_variant.loop_duration,
        base_volume = target_vol,
        current_volume = target_vol,
        target_volume = target_vol,
        fx_fade = nil
    }
end

function AudioManager.setMusicFx(fx_name, fadedur)
    if not AudioManager.current_music then return end
    local m = AudioManager.current_music
    local target_fx = (not fx_name or fx_name == "base" or fx_name == "none" or fx_name == false or fx_name == "") and "base" or fx_name

    -- Check if we are already at this FX or currently fading towards it
    local current_target = (m.fx_fade and m.fx_fade.to_fx) or m.active_fx
    if current_target == target_fx then
        return
    end

    if not m.variants then return end
    local next_variant = m.variants[target_fx]
    if not next_variant then
        return
    end

    local dur = fadedur or (AudioManager.db and AudioManager.db.default_fade_duration) or 0.5
    dur = math.max(0.01, dur)

    -- Determine what source is currently audible
    local cur_variant = nil
    local cur_src = nil
    if m.fx_fade then
        cur_variant = m.fx_fade.to_variant
        cur_src = m.fx_fade.to_src
    else
        cur_variant = m.variants[m.active_fx] or m.variants["base"]
        cur_src = get_variant_source(cur_variant, m.stage)
    end

    local next_src = get_variant_source(next_variant, m.stage)
    if not next_src then
        m.active_fx = target_fx
        m.fx_fade = nil
        return
    end

    local pos = 0
    if cur_src and cur_src:isPlaying() then
        pos = cur_src:tell("seconds") or 0
    elseif m.source and m.source:isPlaying() then
        pos = m.source:tell("seconds") or 0
    end

    local max_dur = next_src:getDuration("seconds") or 0
    if max_dur > 0 and pos >= max_dur then
        pos = pos % max_dur
    end
    pcall(next_src.seek, next_src, pos, "seconds")

    local eff_vol = AudioManager._getEffectiveMusicVolume(m.current_volume)

    if dur <= 0.02 then
        if cur_src and cur_src:isPlaying() then
            cur_src:stop()
        end
        next_src:setVolume(eff_vol)
        next_src:play()

        m.active_fx = target_fx
        m.source = next_src
        m.preloop_source = next_variant.preloop_source
        m.loop_source = next_variant.loop_source
        m.fx_fade = nil
    else
        next_src:setVolume(0)
        next_src:play()

        if m.fx_fade and m.fx_fade.from_src and m.fx_fade.from_src ~= next_src and m.fx_fade.from_src ~= cur_src then
            m.fx_fade.from_src:stop()
        end

        m.fx_fade = {
            from_variant = cur_variant,
            to_variant = next_variant,
            from_src = cur_src,
            to_src = next_src,
            from_fx = cur_variant and cur_variant.name or m.active_fx,
            to_fx = target_fx,
            duration = dur,
            timer = 0
        }
        m.active_fx = target_fx
    end
end

function AudioManager.getMusicFx()
    if AudioManager.current_music then
        return (AudioManager.current_music.fx_fade and AudioManager.current_music.fx_fade.to_fx) or AudioManager.current_music.active_fx
    end
    return nil
end

function AudioManager.musPlay(BGM, vol, fx_name)
    if not BGM then return end

    local entry = resolve_music_entry(BGM)
    local target_vol = vol or entry.volume or 1.0
    local target_fx = (fx_name == "none" or fx_name == false or fx_name == "") and "base" or (fx_name or "base")

    if AudioManager.current_music and AudioManager.current_music.id == entry.id then
        AudioManager.current_music.target_volume = target_vol
        AudioManager.current_music.current_volume = target_vol
        AudioManager.music_fade = nil
        if fx_name ~= nil and AudioManager.current_music.active_fx ~= target_fx then
            AudioManager.setMusicFx(target_fx, 0)
        end
        if AudioManager.current_music.source and not AudioManager.current_music.source:isPlaying() then
            AudioManager.current_music.source:play()
        end
        AudioManager._updateActiveMusicVolume()
        return
    end

    if AudioManager.fade_out_music then
        stop_music_instance(AudioManager.fade_out_music)
        AudioManager.fade_out_music = nil
    end

    if AudioManager.current_music then
        stop_music_instance(AudioManager.current_music)
        AudioManager.current_music = nil
    end

    AudioManager.music_fade = nil

    local inst = create_music_instance(entry, target_vol, target_fx)
    if not inst then return end

    AudioManager.current_music = inst
    local eff_vol = AudioManager._getEffectiveMusicVolume(target_vol)
    inst.source:setVolume(eff_vol)
    inst.source:play()
end

function AudioManager.musFadeTo(BGM, vol, fadedur, fx_name)
    local dur = fadedur or (AudioManager.db and AudioManager.db.default_fade_duration) or 1.0
    dur = math.max(0.01, dur)

    local target_fx = nil
    if fx_name ~= nil then
        target_fx = (fx_name == "none" or fx_name == false or fx_name == "") and "base" or fx_name
    end

    if not BGM or (AudioManager.current_music and AudioManager.current_music.id == BGM) then
        if not AudioManager.current_music then return end
        local target_vol = vol or AudioManager.current_music.base_volume or 1.0

        if target_fx and AudioManager.current_music.active_fx ~= target_fx then
            AudioManager.setMusicFx(target_fx, dur)
        end

        AudioManager.music_fade = {
            type = "fade_volume",
            start_vol = AudioManager.current_music.current_volume,
            target_vol = target_vol,
            duration = dur,
            timer = 0
        }
        AudioManager.current_music.target_volume = target_vol
        return
    end

    local entry = resolve_music_entry(BGM)
    local target_vol = vol or entry.volume or 1.0

    if AudioManager.current_music and AudioManager.current_music.source and AudioManager.current_music.source:isPlaying() then
        if AudioManager.fade_out_music then
            stop_music_instance(AudioManager.fade_out_music)
            AudioManager.fade_out_music = nil
        end

        local playing_sources = {}
        if AudioManager.current_music.variants then
            for _, v in pairs(AudioManager.current_music.variants) do
                if v.preloop_source and v.preloop_source:isPlaying() then
                    table.insert(playing_sources, v.preloop_source)
                end
                if v.loop_source and v.loop_source:isPlaying() then
                    table.insert(playing_sources, v.loop_source)
                end
            end
        end
        if #playing_sources == 0 and AudioManager.current_music.source and AudioManager.current_music.source:isPlaying() then
            table.insert(playing_sources, AudioManager.current_music.source)
        end

        AudioManager.fade_out_music = {
            id = AudioManager.current_music.id,
            sources = playing_sources,
            variants = AudioManager.current_music.variants,
            start_volume = AudioManager.current_music.current_volume,
            current_volume = AudioManager.current_music.current_volume,
            duration = dur,
            timer = 0
        }
    end

    local inst = create_music_instance(entry, target_vol, target_fx or "base")
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
        stop_music_instance(AudioManager.current_music)
        AudioManager.current_music = nil

        if AudioManager.fade_out_music then
            stop_music_instance(AudioManager.fade_out_music)
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
        if m.stage == "preloop" then
            local cur_variant = m.variants and (m.variants[m.active_fx] or m.variants["base"])
            local pre_src = cur_variant and cur_variant.preloop_source or m.preloop_source
            local is_playing = pre_src and pre_src:isPlaying()
            local cur_pos = is_playing and pre_src:tell("seconds") or (pre_src and pre_src:getDuration("seconds")) or 0
            local dur = pre_src and pre_src:getDuration("seconds") or 0

            if not is_playing or (dur > 0 and cur_pos >= (dur - 0.02)) then
                m.stage = "loop"
                local loop_src = cur_variant and cur_variant.loop_source or m.loop_source
                if loop_src then
                    local eff_vol = AudioManager._getEffectiveMusicVolume(m.current_volume)
                    if m.fx_fade and m.fx_fade.to_src == loop_src then
                        local progress = math.min(1.0, m.fx_fade.timer / m.fx_fade.duration)
                        loop_src:setVolume(progress * eff_vol)
                    else
                        loop_src:setVolume(eff_vol)
                    end
                    loop_src:play()
                    m.source = loop_src
                end

                if pre_src and pre_src:isPlaying() then
                    pre_src:stop()
                end

                if m.fx_fade and m.fx_fade.from_variant then
                    local from_loop = m.fx_fade.from_variant.loop_source
                    if from_loop and not from_loop:isPlaying() then
                        local progress = math.min(1.0, m.fx_fade.timer / m.fx_fade.duration)
                        local eff_vol = AudioManager._getEffectiveMusicVolume(m.current_volume)
                        from_loop:setVolume((1.0 - progress) * eff_vol)
                        from_loop:play()
                        m.fx_fade.from_src = from_loop
                    end
                    if m.fx_fade.to_variant and m.fx_fade.to_variant.loop_source then
                        m.fx_fade.to_src = m.fx_fade.to_variant.loop_source
                    end
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

        if f.sources then
            for _, s in ipairs(f.sources) do
                if s and s:isPlaying() then
                    s:setVolume(eff_vol)
                end
            end
        else
            if f.preloop_source and f.preloop_source:isPlaying() then f.preloop_source:setVolume(eff_vol) end
            if f.loop_source and f.loop_source:isPlaying() then f.loop_source:setVolume(eff_vol) end
            if f.source and f.source:isPlaying() then f.source:setVolume(eff_vol) end
        end

        if progress >= 1.0 then
            stop_music_instance(f)
            AudioManager.fade_out_music = nil
        end
    end

    if AudioManager.music_fade and AudioManager.current_music then
        local fade = AudioManager.music_fade
        fade.timer = fade.timer + dt
        local progress = math.min(1.0, fade.timer / fade.duration)

        AudioManager.current_music.current_volume = fade.start_vol + (fade.target_vol - fade.start_vol) * progress
        local eff_vol = AudioManager._getEffectiveMusicVolume(AudioManager.current_music.current_volume)

        if AudioManager.current_music.fx_fade then
            local ff = AudioManager.current_music.fx_fade
            local fx_progress = math.min(1.0, ff.timer / ff.duration)
            if ff.from_src and ff.from_src:isPlaying() then
                ff.from_src:setVolume((1.0 - fx_progress) * eff_vol)
            end
            if ff.to_src and ff.to_src:isPlaying() then
                ff.to_src:setVolume(fx_progress * eff_vol)
            end
        else
            if AudioManager.current_music.source and AudioManager.current_music.source:isPlaying() then
                AudioManager.current_music.source:setVolume(eff_vol)
            end
        end

        if progress >= 1.0 then
            if fade.type == "fade_stop" then
                stop_music_instance(AudioManager.current_music)
                AudioManager.current_music = nil
            end
            AudioManager.music_fade = nil
        end
    end

    if AudioManager.current_music and AudioManager.current_music.fx_fade then
        local m = AudioManager.current_music
        local ff = m.fx_fade
        ff.timer = ff.timer + dt
        local progress = math.min(1.0, ff.timer / ff.duration)
        local eff_vol = AudioManager._getEffectiveMusicVolume(m.current_volume)

        if ff.from_src and ff.from_src:isPlaying() then
            ff.from_src:setVolume((1.0 - progress) * eff_vol)
        end
        if ff.to_src and ff.to_src:isPlaying() then
            ff.to_src:setVolume(progress * eff_vol)
        end

        if progress >= 1.0 then
            if ff.from_src and ff.from_src ~= ff.to_src then
                ff.from_src:stop()
            end
            m.active_fx = ff.to_fx
            local active_var = m.variants and (m.variants[m.active_fx] or m.variants["base"])
            m.source = ff.to_src
            m.preloop_source = active_var and active_var.preloop_source
            m.loop_source = active_var and active_var.loop_source
            m.fx_fade = nil
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

    Events.on("musPlay", function(bgm, vol, fx)
        AudioManager.musPlay(bgm, vol, fx)
    end, "audio_manager")
    Events.on("mus:play", function(bgm, vol, fx)
        AudioManager.musPlay(bgm, vol, fx)
    end, "audio_manager")
    Events.on("audio:mus_play", function(bgm, vol, fx)
        AudioManager.musPlay(bgm, vol, fx)
    end, "audio_manager")
    Events.on("audio:play_music", function(bgm, vol, fx)
        AudioManager.musPlay(bgm, vol, fx)
    end, "audio_manager")

    Events.on("musFadeTo", function(bgm, vol, fadedur, fx)
        AudioManager.musFadeTo(bgm, vol, fadedur, fx)
    end, "audio_manager")
    Events.on("mus:fade_to", function(bgm, vol, fadedur, fx)
        AudioManager.musFadeTo(bgm, vol, fadedur, fx)
    end, "audio_manager")
    Events.on("audio:mus_fade_to", function(bgm, vol, fadedur, fx)
        AudioManager.musFadeTo(bgm, vol, fadedur, fx)
    end, "audio_manager")
    Events.on("audio:fade_music", function(bgm, vol, fadedur, fx)
        AudioManager.musFadeTo(bgm, vol, fadedur, fx)
    end, "audio_manager")

    Events.on("setMusicFx", function(fx_name, fadedur)
        AudioManager.setMusicFx(fx_name, fadedur)
    end, "audio_manager")
    Events.on("mus:set_fx", function(fx_name, fadedur)
        AudioManager.setMusicFx(fx_name, fadedur)
    end, "audio_manager")
    Events.on("audio:set_fx", function(fx_name, fadedur)
        AudioManager.setMusicFx(fx_name, fadedur)
    end, "audio_manager")
    Events.on("audio:set_music_fx", function(fx_name, fadedur)
        AudioManager.setMusicFx(fx_name, fadedur)
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
