local Game = {}

function Game.load()
    print("Game loaded")
end

function Game.update(dt)
    -- TODO: game logic
end

function Game.keypressed(key)
    if key == "escape" then
        love.event.quit()
    end
end

function Game.draw()
    love.graphics.print("tech_plague — template", 20, 20)
    love.graphics.print("[ESC] — quit", 20, 40)
end

return Game