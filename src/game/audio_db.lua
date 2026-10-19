return {
    default_fade_duration = 1.0,

    -- ========================================================================
    -- MUSIC & AMBIENCE
    -- ========================================================================
    -- Fields:
    --   preloop: string (path to intro segment, played once before loop)
    --   loop: string (path to looping segment, looped indefinitely via native hardware loop)
    --   path: string (fallback for simple tracks without intro)
    --   volume: number (default 1.0)
    -- ========================================================================
    music = {
        ["crt"] = {
            preloop = "assets/mus/crt_preloop.ogg",
            loop = "assets/mus/crt_loop.ogg",
            volume = 0.8,
        },
        ["cat"] = {
            preloop = "assets/mus/cat_intro.ogg",
            loop = "assets/mus/cat_loop.ogg",
            volume = 0.8,
            fx = {
                reverb = {
                    preloop = "assets/mus/cat_intro_reverb.ogg",
                    loop = "assets/mus/cat_loop_reverb.ogg",
                }
            }
        },
        ["mr_boss"] = {
            preloop = "assets/mus/mr_boss_preloop.ogg",
            loop = "assets/mus/mr_boss_loop.ogg",
            volume = 0.8
        },
        ["data"] = {
            preloop = "assets/mus/data_calm_preloop.ogg",
            loop = "assets/mus/data_calm_loop.ogg",
            volume = 0.8,
        },
        ["data_fail"] = {
            preloop = "assets/mus/data_fail.ogg",
            volume = 0.8,
        },
        ["data_run"] = {
            loop = "assets/mus/data_run_loop.ogg",
            volume = 0.8,
        },
        ["web_havoc"] = {
            preloop = "assets/mus/web_havoc_preloop.ogg",
            loop = "assets/mus/web_havoc_loop.ogg",
            volume = 0.8,
        },
        ["good_end"] = {
            preloop = "assets/mus/good_end.ogg",
            volume = 0.8,
        },
        ["bad_end"] = {
            preloop = "assets/mus/bad_end.ogg",
            volume = 0.8,
        }
    },

    -- ========================================================================
    -- SOUND EFFECTS (Static: preloaded into RAM for zero latency)
    -- ========================================================================
    -- Fields:
    --   path: string (relative to project root)
    --   volume: number (default 1.0)
    --   pitch: number (default 1.0)
    --   pitch_variance: number (random variance +/- applied per play)
    -- ========================================================================
    sfx = {
        ["shutdown"] = {
            path = "assets/sfx/shutdown.ogg",
            volume = 0.8,
            pitch = 1.0,
            pitch_variance = 0,
        },
        ["turnon"] = {
            path = "assets/sfx/turnon_sfx.ogg",
            volume = 0.8,
            pitch = 1.0,
            pitch_variance = 0,
        },
        ["coin"] = {
            path = "assets/sfx/coin_obtained.ogg",
            volume = 0.8,
            pitch = 1.0,
            pitch_variance = 0,
        }
    }
}
