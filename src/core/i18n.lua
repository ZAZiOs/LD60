local json = require("src.lib.json")

local I18n = {
    current_locale = "ru",
    default_locale = "en",
    dictionaries = {},

    active_family = "tahoma",
    registered_families = {},
    family_aliases = {},
    registered_fonts = {},
    locale_families = {},
    font_cache = {},

    default_sizes = {
        tiny     = 16,
        small    = 20,
        medium   = 26,
        dialog   = 32,
        dialogue = 32,
        large    = 36,
        subtitle = 44,
        title    = 56,
        header   = 56,
        huge     = 68
    },

    fonts = {}
}

setmetatable(I18n.fonts, {
    __index = function(_, key)
        return I18n.getFont(key)
    end
})

local function file_exists(path)
    if not path or path == "" then return false end
    if love and love.filesystem and love.filesystem.getInfo then
        local info = love.filesystem.getInfo(path)
        if info then return true end
    end
    local f = io.open(path, "rb")
    if f then
        f:close()
        return true
    end
    return false
end

local function normalize_variant_name(variant)
    if not variant or variant == "" then return "regular" end
    local v = string.lower(tostring(variant)):gsub("[_%-%s]+", "")

    if v == "r" or v == "reg" or v == "regular" or v == "normal" or v == "default" then
        return "regular"
    elseif v == "b" or v == "bold" then
        return "bold"
    elseif v == "i" or v == "italic" or v == "oblique" then
        return "italic"
    elseif v == "bi" or v == "bolditalic" or v == "boldi" or v == "ib" then
        return "bold_italic"
    elseif v == "t" or v == "thin" then
        return "thin"
    elseif v == "ti" or v == "thinitalic" or v == "thini" then
        return "thin_italic"
    elseif v == "el" or v == "extralight" or v == "ultralight" then
        return "extralight"
    elseif v == "eli" or v == "extralightitalic" or v == "ultralightitalic" then
        return "extralight_italic"
    elseif v == "l" or v == "light" then
        return "light"
    elseif v == "li" or v == "lightitalic" or v == "lighti" then
        return "light_italic"
    elseif v == "m" or v == "med" or v == "medium" then
        return "medium"
    elseif v == "mi" or v == "mediumitalic" or v == "meditalic" or v == "mediumi" then
        return "medium_italic"
    elseif v == "sb" or v == "semibold" or v == "demibold" then
        return "semibold"
    elseif v == "sbi" or v == "semibolditalic" or v == "demibolditalic" or v == "semiboldi" then
        return "semibold_italic"
    elseif v == "eb" or v == "extrabold" or v == "ultrabold" then
        return "extrabold"
    elseif v == "ebi" or v == "extrabolditalic" or v == "ultrabolditalic" then
        return "extrabold_italic"
    elseif v == "blk" or v == "black" or v == "heavy" then
        return "black"
    elseif v == "blki" or v == "blackitalic" or v == "heavyitalic" then
        return "black_italic"
    end

    return variant
end

local function normalize_family_id(family_id)
    if not family_id then return I18n.active_family end
    local clean = string.lower(tostring(family_id)):gsub("[_%-%s]+", "_")
    if I18n.family_aliases[clean] then
        return I18n.family_aliases[clean]
    end
    if I18n.registered_families[clean] then
        return clean
    end
    return family_id
end

local function load_json_file(path)
    local contents = nil
    if love and love.filesystem and love.filesystem.read then
        contents = love.filesystem.read(path)
    end

    if not contents then
        local file = io.open(path, "r")
        if file then
            contents = file:read("*a")
            file:close()
        end
    end

    if contents then
        local data, err = json.decode(contents)
        if data then
            return data
        else
            print(string.format("[I18n] Error decoding JSON from %s: %s", path, tostring(err)))
        end
    else

    end
    return {}
end

function I18n.registerSizePreset(name, size)
    if type(name) == "string" and type(size) == "number" then
        I18n.default_sizes[name] = size
    end
end

function I18n.registerSizePresets(presets_table)
    if type(presets_table) == "table" then
        for k, v in pairs(presets_table) do
            I18n.registerSizePreset(k, v)
        end
    end
end

function I18n.registerFamily(family_id, config)
    if not family_id or type(config) ~= "table" then return end

    local clean_id = string.lower(tostring(family_id)):gsub("[_%-%s]+", "_")
    local family_data = {
        id = clean_id,
        name = config.name or config.displayName or family_id,
        default_variant = config.default_variant or "regular",
        filter = config.filter or "linear",
        hinting = config.hinting or "normal",
        dpiscale = config.dpiscale,
        line_height = config.line_height or config.lineHeight or 1.0,
        size_multiplier = config.size_multiplier or config.scale or 1.0,
        sizes = config.sizes or config.presets or {},
        fallbacks = config.fallbacks or {},
        fallback_family = config.fallback_family,
        locales = config.locales,
        variants = {}
    }

    if type(config.variants) == "table" then
        for v_name, v_cfg in pairs(config.variants) do
            local norm_v = normalize_variant_name(v_name)
            if type(v_cfg) == "string" then
                family_data.variants[norm_v] = {
                    path = v_cfg,
                    filter = family_data.filter,
                    hinting = family_data.hinting,
                    dpiscale = family_data.dpiscale,
                    line_height = family_data.line_height,
                    fallbacks = family_data.fallbacks
                }
            elseif type(v_cfg) == "table" then
                family_data.variants[norm_v] = {
                    path = v_cfg.path or v_cfg.file or v_cfg[1],
                    filter = v_cfg.filter or family_data.filter,
                    hinting = v_cfg.hinting or family_data.hinting,
                    dpiscale = v_cfg.dpiscale or family_data.dpiscale,
                    line_height = v_cfg.line_height or v_cfg.lineHeight or family_data.line_height,
                    fallbacks = v_cfg.fallbacks or family_data.fallbacks
                }
            end
        end
    end

    I18n.registered_families[clean_id] = family_data

    if config.aliases and type(config.aliases) == "table" then
        for _, alias in ipairs(config.aliases) do
            local clean_alias = string.lower(tostring(alias)):gsub("[_%-%s]+", "_")
            I18n.family_aliases[clean_alias] = clean_id
        end
    end
    I18n.family_aliases[string.lower(family_id)] = clean_id

    if config.locales then
        if type(config.locales) == "table" then
            for _, loc in ipairs(config.locales) do
                I18n.locale_families[loc] = clean_id
            end
        elseif type(config.locales) == "string" then
            I18n.locale_families[config.locales] = clean_id
        end
    end

    if config.is_default then
        I18n.setFontFamily(clean_id)
    end

    return family_data
end

I18n.registerFontFamily = I18n.registerFamily

function I18n.registerFont(font_name, options)
    if not font_name then return end
    if type(options) == "string" then
        I18n.registered_fonts[font_name] = { path = options }
    elseif type(options) == "table" then
        I18n.registered_fonts[font_name] = options
    end
end

function I18n.setFontFamily(family_id)
    local target_id = normalize_family_id(family_id)
    if I18n.registered_families[target_id] then
        I18n.active_family = target_id
    else
        print(string.format("[I18n] Font family '%s' not registered, falling back to '%s'", tostring(family_id), I18n.active_family))
    end
    I18n.refreshDefaultFonts()
end

function I18n.setFontScale(scale, family_id)
    local fam_id = normalize_family_id(family_id or I18n.active_family)
    if I18n.registered_families[fam_id] and type(scale) == "number" then
        I18n.registered_families[fam_id].size_multiplier = scale
        I18n.clearFontCache()
        I18n.refreshDefaultFonts()
    end
end

function I18n.getFontFamily()
    return I18n.active_family
end

function I18n.getRegisteredFamilies()
    return I18n.registered_families
end

function I18n.setFamilyForLocale(locale_code, family_id)
    if locale_code and family_id then
        I18n.locale_families[locale_code] = normalize_family_id(family_id)
    end
end

function I18n.clearFontCache()
    I18n.font_cache = {}
end

local function apply_font_settings(font_obj, filter, line_height, fallbacks)
    if not font_obj then return end

    if font_obj.setFilter and filter then
        if type(filter) == "string" then
            font_obj:setFilter(filter, filter)
        elseif type(filter) == "table" then
            local min = filter.min or "linear"
            local mag = filter.mag or "linear"
            local aniso = filter.anisotropy or 1
            font_obj:setFilter(min, mag, aniso)
        end
    end

    if font_obj.setLineHeight and line_height and type(line_height) == "number" then
        font_obj:setLineHeight(line_height)
    end

    if font_obj.setFallbacks and fallbacks and type(fallbacks) == "table" and #fallbacks > 0 then
        local resolved_fallbacks = {}
        for _, fb in ipairs(fallbacks) do
            if type(fb) == "string" then
                if file_exists(fb) and love and love.graphics and love.graphics.newFont then
                    local ok, fb_font = pcall(love.graphics.newFont, fb, font_obj:getHeight())
                    if ok and fb_font then
                        table.insert(resolved_fallbacks, fb_font)
                    end
                end
            elseif type(fb) == "userdata" or type(fb) == "table" then
                table.insert(resolved_fallbacks, fb)
            end
        end
        if #resolved_fallbacks > 0 then
            pcall(function()
                if table.unpack then
                    font_obj:setFallbacks(table.unpack(resolved_fallbacks))
                else
                    font_obj:setFallbacks(unpack(resolved_fallbacks))
                end
            end)
        end
    end
end

local function create_mock_font(size)
    local s = size or 24
    return {
        getWidth = function(_, str) return (utf8 and utf8.len(tostring(str)) or #tostring(str)) * (s * 0.55) end,
        getHeight = function(_) return s end,
        getLineHeight = function(_) return 1.0 end,
        setFilter = function(_) end,
        setLineHeight = function(_) end,
        setFallbacks = function(_) end
    }
end

local function instantiate_font(path, size, hinting, dpiscale, filter, line_height, fallbacks)
    if not (love and love.graphics and love.graphics.newFont) then
        return create_mock_font(size)
    end

    local font_obj = nil
    local target_size = math.max(1, math.floor(size + 0.5))

    if path and file_exists(path) then
        local ok, result = nil, nil
        if dpiscale and hinting then
            ok, result = pcall(love.graphics.newFont, path, target_size, hinting, dpiscale)
        elseif hinting then
            ok, result = pcall(love.graphics.newFont, path, target_size, hinting)
        else
            ok, result = pcall(love.graphics.newFont, path, target_size)
        end

        if ok and result then
            font_obj = result
        else
            print(string.format("[I18n] Error loading font from %s: %s", tostring(path), tostring(result)))
        end
    end

    if not font_obj then
        local ok, def_font = pcall(love.graphics.newFont, target_size)
        if ok and def_font then
            font_obj = def_font
        else
            font_obj = create_mock_font(target_size)
        end
    end

    apply_font_settings(font_obj, filter, line_height, fallbacks)
    return font_obj
end

function I18n.getFont(arg1, arg2, arg3, arg4)
    local family_id = nil
    local variant_name = nil
    local size = nil
    local custom_filter = nil
    local custom_hinting = nil
    local custom_dpiscale = nil
    local custom_line_height = nil
    local custom_fallbacks = nil
    local explicit_path = nil

    if type(arg1) == "table" then
        local opts = arg1
        family_id = opts.family or opts.family_id or I18n.active_family
        variant_name = opts.variant or opts.style or opts.weight or "regular"
        size = opts.size or opts.preset
        custom_filter = opts.filter
        custom_hinting = opts.hinting
        custom_dpiscale = opts.dpiscale
        custom_line_height = opts.line_height or opts.lineHeight
        custom_fallbacks = opts.fallbacks
        explicit_path = opts.path or opts.file
    elseif type(arg1) == "string" and I18n.registered_fonts[arg1] then
        local reg = I18n.registered_fonts[arg1]
        explicit_path = reg.path or reg.file
        family_id = reg.family or I18n.active_family
        variant_name = reg.variant or "regular"
        size = reg.size
        custom_filter = reg.filter
        custom_hinting = reg.hinting
        custom_dpiscale = reg.dpiscale
        custom_line_height = reg.line_height or reg.lineHeight
        custom_fallbacks = reg.fallbacks
    elseif type(arg1) == "string" and I18n.default_sizes[arg1] then
        size = arg1
        variant_name = arg2
        family_id = arg3
    elseif type(arg1) == "number" then
        size = arg1
        variant_name = arg2
        family_id = arg3
    elseif type(arg1) == "string" then
        size = arg1
        variant_name = arg2
        family_id = arg3
    end

    family_id = normalize_family_id(family_id or I18n.active_family)
    variant_name = normalize_variant_name(variant_name or "regular")

    local fam_data = I18n.registered_families[family_id] or {}

    local final_size = 24
    if type(size) == "number" then
        final_size = size
    elseif type(size) == "string" then
        if fam_data.sizes and fam_data.sizes[size] then
            final_size = fam_data.sizes[size]
        elseif I18n.default_sizes[size] then
            final_size = I18n.default_sizes[size]
        else
            local parsed_num = tonumber(size)
            if parsed_num then
                final_size = parsed_num
            end
        end
    end

    local multiplier = fam_data.size_multiplier or 1.0
    final_size = final_size * multiplier

    local font_path = explicit_path
    local v_cfg = nil
    if not font_path and fam_data.variants then
        v_cfg = fam_data.variants[variant_name] or fam_data.variants[fam_data.default_variant or "regular"] or fam_data.variants["regular"]
        if v_cfg then
            font_path = v_cfg.path
        end

        if (not font_path or not file_exists(font_path)) and fam_data.fallback_family then
            local fb_fam = I18n.registered_families[fam_data.fallback_family]
            if fb_fam and fb_fam.variants then
                local fb_v = fb_fam.variants[variant_name] or fb_fam.variants["regular"]
                if fb_v and fb_v.path and file_exists(fb_v.path) then
                    font_path = fb_v.path
                    v_cfg = fb_v
                end
            end
        end
    end

    local filter = custom_filter or (v_cfg and v_cfg.filter) or fam_data.filter or "linear"
    local hinting = custom_hinting or (v_cfg and v_cfg.hinting) or fam_data.hinting or "normal"
    local dpiscale = custom_dpiscale or (v_cfg and v_cfg.dpiscale) or fam_data.dpiscale
    local line_height = custom_line_height or (v_cfg and v_cfg.line_height) or fam_data.line_height or 1.0
    local fallbacks = custom_fallbacks or (v_cfg and v_cfg.fallbacks) or fam_data.fallbacks

    local filter_key = (type(filter) == "table") and string.format("%s_%s_%s", tostring(filter.min), tostring(filter.mag), tostring(filter.anisotropy)) or tostring(filter)
    local cache_key = string.format("%s:%s:%d:%s:%s:%s:%s:%s",
        tostring(font_path or "default"),
        tostring(variant_name),
        math.floor(final_size + 0.5),
        tostring(hinting),
        filter_key,
        tostring(dpiscale or "nil"),
        tostring(line_height),
        tostring(explicit_path or "nil")
    )

    if I18n.font_cache[cache_key] then
        return I18n.font_cache[cache_key]
    end

    local new_font = instantiate_font(font_path, final_size, hinting, dpiscale, filter, line_height, fallbacks)
    I18n.font_cache[cache_key] = new_font
    return new_font
end

function I18n.refreshDefaultFonts()
    I18n.fonts.small    = I18n.getFont("small")
    I18n.fonts.medium   = I18n.getFont("medium")
    I18n.fonts.dialog   = I18n.getFont("dialog")
    I18n.fonts.dialogue = I18n.fonts.dialog
    I18n.fonts.large    = I18n.getFont("large")
    I18n.fonts.title    = I18n.getFont("title")
end

function I18n.init()
    I18n.dictionaries["en"] = load_json_file("src/locales/en.json")
    I18n.dictionaries["ru"] = load_json_file("src/locales/ru.json")

    I18n.registerFamily("cairopixel", {
        name = "Cairopixel",
        filter = "nearest",
        hinting = "mono",
        aliases = { "cairo", "pixel", "cairo_pixel" },
        variants = {
            regular = "assets/fonts/Cairopixel.ttf"
        },
        sizes = {
            small    = 24,
            medium   = 36,
            dialog   = 48,
            dialogue = 48,
            large    = 48,
            title    = 72
        }
    })

    I18n.registerFamily("tahoma", {
        name = "Tahoma",
        hinting = "mono",
        line_height = 1.0,
        aliases = { "tahoma", "Tahoma" },
        variants = {
            regular = "assets/fnt/tahoma.ttf",
            bold    = "assets/fnt/tahomabd.ttf"
        },
        sizes = {
            tiny    = 9,
            small   = 9,
            pixel   = 9,
            default = 9
        }
    })

    I18n.registerFont("tahoma9", {
        path = "assets/fnt/tahoma.ttf",
        size = 9,
        hinting = "mono",
        filter = "nearest"
    })

    I18n.refreshDefaultFonts()

    if love and love.graphics and love.graphics.setFont and I18n.fonts.dialog then
        love.graphics.setFont(I18n.fonts.dialog)
    end
end

function I18n.setLocale(locale_code)
    if I18n.dictionaries[locale_code] then
        I18n.current_locale = locale_code
    end

    if I18n.locale_families[locale_code] then
        I18n.setFontFamily(I18n.locale_families[locale_code])
    end
end

function I18n.getLocale()
    return I18n.current_locale
end

function I18n.toggleLocale()
    if I18n.current_locale == "ru" then
        I18n.setLocale("en")
    else
        I18n.setLocale("ru")
    end
    return I18n.current_locale
end

local function lookup(dict, path)
    if not dict or not path then return nil end
    local current = dict
    for key in string.gmatch(path, "[^%.]+") do
        if type(current) == "table" then
            current = current[key]
        else
            return nil
        end
    end
    return current
end

function I18n.t(key, params)
    if not key then return "" end

    local text = lookup(I18n.dictionaries[I18n.current_locale], key)
    if not text then
        text = lookup(I18n.dictionaries[I18n.default_locale], key)
    end

    if not text then
        return key
    end

    if type(text) == "string" and params then
        for k, v in pairs(params) do
            text = string.gsub(text, "%%{" .. k .. "}", tostring(v))
        end
    end

    return text
end

return I18n
