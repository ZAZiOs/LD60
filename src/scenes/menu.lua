local SceneManager = require("src.core.scene_manager")
local I18n = require("src.core.i18n")

local Menu = {
    selected = 1,
    options = {}
}

function Menu:enter()
    print("Entered Menu")
    self.selected = 1
    self.options = {
        I18n.t("game.start") ~= "game.start" and I18n.t("game.start") or "Start Game",
        I18n.t("game.quit") ~= "game.quit" and I18n.t("game.quit") or "Quit"
    }
end

function Menu:leave()
    print("Leaving Menu")
end

function Menu:update(dt)

end

function Menu:keypressed(key)
    if key == "up" then
        self.selected = self.selected - 1
        if self.selected < 1 then self.selected = #self.options end
    elseif key == "down" then
        self.selected = self.selected + 1
        if self.selected > #self.options then self.selected = 1 end
    elseif key == "return" then
        if self.selected == 1 then
            SceneManager.goTo("level1")
        elseif self.selected == 2 then
            love.event.quit()
        end
    end
end

function Menu:draw()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("tech_plague", 40, 40)
    love.graphics.print("Use [UP]/[DOWN] to select, [ENTER] to confirm", 40, 70)

    for i, option in ipairs(self.options) do
        local prefix = (i == self.selected) and "> " or "  "
        love.graphics.print(prefix .. option, 40, 120 + (i - 1) * 30)
    end
end

return Menu
