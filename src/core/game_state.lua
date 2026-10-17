local GameState = {
    data = {},
    initial_defaults = {}
}

function GameState.init(defaults)
    GameState.initial_defaults = {}
    if type(defaults) == "table" then
        for k, v in pairs(defaults) do
            GameState.initial_defaults[k] = v
        end
    end
    GameState.reset()
end

function GameState.get(key, default)
    if key == nil then return GameState.data end
    if GameState.data[key] ~= nil then
        return GameState.data[key]
    end
    return default
end

function GameState.set(key, val)
    GameState.data[key] = val
    return val
end

function GameState.has(key)
    return GameState.data[key] ~= nil
end

function GameState.delete(key)
    GameState.data[key] = nil
end

function GameState.reset(custom_data)
    GameState.data = {}
    local source = custom_data or GameState.initial_defaults
    for k, v in pairs(source) do
        GameState.data[k] = v
    end
    return GameState.data
end

function GameState.clear()
    GameState.data = {}
    return GameState.data
end

return GameState
