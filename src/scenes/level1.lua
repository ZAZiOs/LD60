local SceneManager = require("src.core.scene_manager")
local PixelScreen = require("src.core.pixel_screen")
local GameScene = require("src.core.game_scene")

local inner_game = {
    mouse_x = 0,
    mouse_y = 0,
    clicks = 0
}

function inner_game:enter()
    print("Entered Level 1 Inner Game")
end

function inner_game:update(dt)
end

function inner_game:draw()
    love.graphics.setColor(0.1, 0.15, 0.22, 1)
    love.graphics.rectangle("fill", 0, 0, 320, 240)

    love.graphics.setColor(0.2, 0.3, 0.45, 1)
    for x = 0, 320, 16 do
        love.graphics.line(x, 0, x, 240)
    end
    for y = 0, 240, 16 do
        love.graphics.line(0, y, 320, y)
    end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("GAME CANVAS: 320x240", 12, 12)
    love.graphics.print("Mouse: " .. self.mouse_x .. ", " .. self.mouse_y, 12, 32)
    love.graphics.print("Clicks: " .. self.clicks, 12, 52)

    love.graphics.setColor(0.2, 0.8, 0.4, 1)
    love.graphics.rectangle("fill", self.mouse_x - 3, self.mouse_y - 3, 6, 6)

    love.graphics.setColor(1, 0.8, 0.2, 1)
    love.graphics.print("[ENTER] -> Level 2", 12, 190)
    love.graphics.print("[BACKSPACE] -> Menu", 12, 210)
end

function inner_game:mousepressed(gx, gy, button)
    self.mouse_x = gx
    self.mouse_y = gy
    self.clicks = self.clicks + 1
end

function inner_game:mousemoved(gx, gy, gdx, gdy, istouch, inside)
    if inside then
        self.mouse_x = gx
        self.mouse_y = gy
    end
end

function inner_game:keypressed(key)
    if key == "return" then
        SceneManager.fadeTo("level2", 0.5)
    elseif key == "backspace" then
        SceneManager.fadeTo("menu", 0.5)
    end
end

local screen = PixelScreen.new({
    game = inner_game,
    x = 320,
    y = 60,
    w = 1280,
    h = 960
})

local Level1Scene = GameScene.new({
    bg = "assets/bg/intro_bg.png",
    screen = screen
})

return Level1Scene
