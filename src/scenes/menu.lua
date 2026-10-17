local SceneManager = require("src.scene_manager")
local Menu = {}

function Menu.enter()
    print("Entered Menu")
    Menu.selected = 1
    Menu.options = { "Start Game", "Quit" }
end

function Menu.leave()
    print("Leaving Menu")
end

function Menu.update(dt)
    -- Menu logic (animated background, etc.) goes here
end

function Menu.keypressed(key)
    if key == "up" then
        Menu.selected = Menu.selected - 1
        if Menu.selected < 1 then Menu.selected = #Menu.options end
    elseif key == "down" then
        Menu.selected = Menu.selected + 1
        if Menu.selected > #Menu.options then Menu.selected = 1 end
    elseif key == "return" then
        if Menu.selected == 1 then
            SceneManager.switch("level1")
        elseif Menu.selected == 2 then
            love.event.quit()
        end
    end
end

function Menu.draw()
    love.graphics.print("tech_plague", 20, 20)
    love.graphics.print("Use [UP]/[DOWN] to select, [ENTER] to confirm", 20, 40)

    for i, option in ipairs(Menu.options) do
        local prefix = (i == Menu.selected) and "> " or "  "
        love.graphics.print(prefix .. option, 20, 80 + (i - 1) * 20)
    end
end

return Menu