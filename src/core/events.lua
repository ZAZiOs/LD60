local Events = {
    listeners = {}
}

function Events.on(event_name, callback, tag)
    if not Events.listeners[event_name] then
        Events.listeners[event_name] = {}
    end
    table.insert(Events.listeners[event_name], {
        fn = callback,
        tag = tag
    })
end

function Events.clear(tag)
    if not tag then return end
    for event_name, list in pairs(Events.listeners) do
        for i = #list, 1, -1 do
            if list[i].tag == tag then
                table.remove(list, i)
            end
        end
    end
end

function Events.off(event_name, callback)
    local list = Events.listeners[event_name]
    if list then
        for i = #list, 1, -1 do
            if list[i].fn == callback then
                table.remove(list, i)
            end
        end
    end
end

function Events.emit(event_name, ...)
    local list = Events.listeners[event_name]
    if list then
        for _, item in ipairs(list) do
            item.fn(...)
        end
    end
end

return Events
