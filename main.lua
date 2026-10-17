local Game = require("src.game")

function love.load()
    love.window.setTitle("tech_plague")
    print("tech_plague started")
    Game.load()
end

function love.update(dt)
    Game.update(dt)
end

function love.keypressed(key)
    Game.keypressed(key)
end

function love.draw()
    Game.draw()
end