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
        ["cat"] = {
            preloop = "assets/mus/cat_intro.ogg",
            loop = "assets/mus/cat_loop.ogg",
            volume = 0.8,
        },
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
    }
}
