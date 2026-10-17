local Spritesheet = require("src.core.spritesheet")
local Animation = require("src.core.animation")

local SpritesheetManager = {
    sheet_cache = {}
}

function SpritesheetManager.getSheet(def_or_path, base_dir)
    if not def_or_path then return nil end

    if type(def_or_path) == "string" then
        local cache_key = def_or_path
        if SpritesheetManager.sheet_cache[cache_key] then
            return SpritesheetManager.sheet_cache[cache_key]
        end

        local sheet = Spritesheet.new(def_or_path, base_dir)
        SpritesheetManager.sheet_cache[cache_key] = sheet
        return sheet
    end

    return Spritesheet.new(def_or_path, base_dir)
end

function SpritesheetManager.createAnimation(def_or_path, default_anim, base_dir)
    local sheet = SpritesheetManager.getSheet(def_or_path, base_dir)
    if not sheet then return nil end
    return Animation.new(sheet, default_anim)
end

function SpritesheetManager.clearCache()
    SpritesheetManager.sheet_cache = {}
end

return SpritesheetManager
