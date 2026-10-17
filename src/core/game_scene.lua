local PixelScreen = require("src.core.pixel_screen")

local GameScene = {}
GameScene.__index = GameScene

function GameScene.new(opts)
    local self = setmetatable({}, GameScene)

    if opts and opts.__index == PixelScreen then
        self.screen = opts
        self.bg_path = "assets/bg/intro_bg.png"
    else
        opts = opts or {}
        self.bg_path = opts.bg or "assets/bg/intro_bg.png"
        self.screen = opts.screen or PixelScreen.new(opts)
        self.on_bg_click = opts.on_bg_click
        self.on_update = opts.update
        self.on_enter = opts.on_enter or opts.enter
        self.on_leave = opts.on_leave or opts.leave
        self.draw_overlay = opts.draw_overlay
    end

    self.bg_image = nil
    self:_loadBg()

    return self
end

function GameScene:_loadBg()
    if type(self.bg_path) == "string" and love and love.filesystem and love.filesystem.getInfo(self.bg_path) then
        local ok, img = pcall(love.graphics.newImage, self.bg_path)
        if ok and img then
            self.bg_image = img
        end
    elseif type(self.bg_path) == "userdata" then
        self.bg_image = self.bg_path
    end
end

function GameScene:enter(...)
    if not self.bg_image then
        self:_loadBg()
    end
    if self.screen then
        self.screen:enter(...)
    end
    if self.on_enter then
        self:on_enter(...)
    end
end

function GameScene:leave()
    if self.on_leave then
        self:on_leave()
    end
    if self.screen then
        self.screen:leave()
    end
end

function GameScene:update(dt)
    if self.screen then
        self.screen:update(dt)
    end
    if self.on_update then
        self:on_update(dt)
    end
end

function GameScene:draw()
    love.graphics.setColor(1, 1, 1, 1)

    if self.bg_image then
        love.graphics.draw(self.bg_image, 0, 0)
    else
        love.graphics.setColor(0.12, 0.12, 0.14, 1)
        love.graphics.rectangle("fill", 0, 0, 1920, 1080)
    end

    if self.screen then
        self.screen:render()
        self.screen:draw()
    end

    if self.draw_overlay then
        self:draw_overlay()
    end
end

function GameScene:mousepressed(vx, vy, button, istouch, presses)
    local handled = false
    if self.screen then
        handled = self.screen:mousepressed(vx, vy, button, istouch, presses)
    end
    if not handled and self.on_bg_click then
        self:on_bg_click(vx, vy, button)
    end
end

function GameScene:mousereleased(vx, vy, button, istouch, presses)
    if self.screen then
        self.screen:mousereleased(vx, vy, button, istouch, presses)
    end
end

function GameScene:mousemoved(vx, vy, vdx, vdy, istouch)
    if self.screen then
        self.screen:mousemoved(vx, vy, vdx, vdy, istouch)
    end
end

function GameScene:wheelmoved(x, y)
    if self.screen then
        self.screen:wheelmoved(x, y)
    end
end

function GameScene:keypressed(key, scancode, isrepeat)
    if self.screen then
        self.screen:keypressed(key, scancode, isrepeat)
    end
end

function GameScene:keyreleased(key, scancode)
    if self.screen then
        self.screen:keyreleased(key, scancode)
    end
end

function GameScene:textinput(text)
    if self.screen then
        self.screen:textinput(text)
    end
end

return GameScene
