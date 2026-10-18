local SceneManager = require("src.core.scene_manager")
local PixelScreen = require("src.core.pixel_screen")
local GameScene = require("src.core.game_scene")
local GameState = require("src.core.game_state")
local Effects = require("src.core.effects")
local I18n = require("src.core.i18n")
local AudioManager = require("src.core.audio_manager")

local font_msg = nil
local function getMsgFont()
    if not font_msg then
        font_msg = I18n.getFont({
            path = "assets/fnt/tahoma.ttf",
            size = 9,
            hinting = "mono",
            filter = "nearest"
        })
    end
    return font_msg
end

local gameover_img = nil
local function getGameOverImg()
    if not gameover_img then
        local ok, img = pcall(love.graphics.newImage, "assets/gameover.png")
        if ok and img then
            img:setFilter("nearest", "nearest")
            gameover_img = img
        end
    end
    return gameover_img
end

local gameover_content = {}

function gameover_content:enter()
    AudioManager.musFadeTo("crt", 0.7, 0.4)
end

function gameover_content:leave()
    AudioManager.musStop(0.3)
end

function gameover_content:update(dt)
end

function gameover_content:retry()
    GameState.set("is_dead", false)
    SceneManager.crossFade("level3", 0.4)
end

function gameover_content:exitToMenu()
    GameState.set("is_dead", false)
    SceneManager.crossFade("menu", 0.4)
end

function gameover_content:keypressed(key, scancode, isrepeat)
    if key == "escape" then
        self:exitToMenu()
    else
        self:retry()
    end
end

function gameover_content:mousepressed(gx, gy, button)
    if button == 1 or button == 2 then
        self:retry()
    end
end

function gameover_content:draw()
    love.graphics.setColor(23 / 255, 50 / 255, 1.0, 1)
    love.graphics.rectangle("fill", 0, 0, 320, 240)

    local banner = getGameOverImg()
    if banner then
        love.graphics.setColor(1, 1, 1, 1)
        local bw, bh = banner:getDimensions()
        local bx = math.floor((320 - bw) / 2)
        local by = 55
        love.graphics.draw(banner, bx, by)
    else
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("fill", 74, 55, 172, 36)
        love.graphics.setColor(23 / 255, 50 / 255, 1.0, 1)
        local f = getMsgFont()
        love.graphics.setFont(f)
        local str = "GAME OVER"
        love.graphics.print(str, math.floor((320 - f:getWidth(str)) / 2), 65)
    end

    local f_msg = getMsgFont()
    love.graphics.setFont(f_msg)
    love.graphics.setColor(1, 1, 1, 1)

    local msg1 = "press any button to try again"
    local tw1 = f_msg:getWidth(msg1)
    love.graphics.print(msg1, math.floor((320 - tw1) / 2), 163)

    local msg2 = "press ESC to exit"
    local tw2 = f_msg:getWidth(msg2)
    love.graphics.print(msg2, math.floor((320 - tw2) / 2), 180)
end

local screen = PixelScreen.new({
    game = gameover_content,
    x = 320,
    y = 60,
    w = 1280,
    h = 960
})

local GameOverScene = GameScene.new({
    bg = "assets/bg/level3_bg.png",
    screen = screen,
    screen_draw_fn = function(s)
        Effects.drawCrt(s.canvas, s.x, s.y, s.scale_x, s.scale_y)
    end,
    on_bg_click = function(self, vx, vy, button)
        gameover_content:retry()
    end,
    enter = function(self)
        if gameover_content.enter then
            gameover_content:enter()
        end
    end,
    leave = function(self)
        if gameover_content.leave then
            gameover_content:leave()
        end
    end
})

return GameOverScene
