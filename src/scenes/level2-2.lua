local SceneManager = require("src.core.scene_manager")
local PixelScreen = require("src.core.pixel_screen")
local GameScene = require("src.core.game_scene")
local PixelSceneBuilder = require("src.core.pixel_scene_builder")
local AudioManager = require("src.core.audio_manager")
local Effects = require("src.core.effects")
local GameState = require("src.core.game_state")

local HACK_STAGES = {
    [1] = {
        "> CARD INSERTED",
        "> CHIP: GOLD VIP",
        "> BAL: $999999",
        "# "
    },
    [2] = {
        "# pay --bypass",
        "[*] Check PIN...",
        "[+] PIN: 0000",
        "[!] Fee: $30.00",
        "[+] APPROVED",
        "# "
    },
    [3] = {
        "# unlock -f",
        "[*] Auth master...",
        "[*] Overriding...",
        "[+] Maglock: OFF",
        "# "
    },
    [4] = {
        "# open_gate",
        "[+] PROTOCOL OK",
        "==================",
        " > ACCESS GRANTED <",
        " > DOOR UNLOCKED <",
        "=================="
    }
}

local hack_step = 0
local terminal_lines = {}
local queue_lines = {}
local line_timer = 0
local LINE_INTERVAL = 0.06

local desktop = nil
local screen = nil

local function advanceTerminal()
    if #queue_lines > 0 then
        while #queue_lines > 0 do
            table.insert(terminal_lines, table.remove(queue_lines, 1))
        end
        if hack_step == 4 and desktop then
            local door = desktop:getElement("door")
            if door then door.visible = true end
            GameState.set("level2_2_door_opened", true)
        end
        if screen then screen.needs_render = true end
        return
    end

    if hack_step >= 4 then return end
    hack_step = hack_step + 1

    local new_lines = HACK_STAGES[hack_step]
    if new_lines then
        for _, line in ipairs(new_lines) do
            table.insert(queue_lines, line)
        end
    end

    if screen then screen.needs_render = true end
end

local term_font = nil
local function getTermFont()
    if not term_font and love and love.graphics and love.graphics.newFont then
        if love.filesystem and love.filesystem.getInfo and love.filesystem.getInfo("assets/fnt/tahoma.ttf") then
            local ok, f = pcall(love.graphics.newFont, "assets/fnt/tahoma.ttf", 9, "mono")
            if ok and f then term_font = f end
        end
        if not term_font then
            local ok, f = pcall(love.graphics.newFont, 8)
            if ok and f then term_font = f end
        end
    end
    return term_font
end

local term_canvas = nil
local function getTermCanvas(w, h)
    if not term_canvas or term_canvas:getWidth() ~= w or term_canvas:getHeight() ~= h then
        if term_canvas then term_canvas:release() end
        term_canvas = love.graphics.newCanvas(w, h)
        term_canvas:setFilter("nearest", "nearest")
    end
    return term_canvas
end

desktop = PixelSceneBuilder.new("desktop")
    :background("assets/level1/sublv2/wp.png")
    :cursor("assets/cursor.ini")
    :addElement({
        id = "vent",
        image = "assets/level1/vent_o.png",
        x = 16,
        y = 16,
        z_index = -1,
        clickable = true,
        onInteract = function(self)
            SceneManager.crossFade("level2", 0.4)
        end,
        onClick = function(self)
            SceneManager.crossFade("level2", 0.4)
        end
    })
    :addSolid("taskbar", {
        image = "assets/level1/sublv2/taskbar.png",
        x = 0,
        y = 224,
        w = 320,
        h = 16,
        z_index = 1
    })
    :addElement({
        id = "terminal",
        image = "assets/level1/sublv2/terminal_bg.png",
        x = 14,
        y = 77,
        z_index = 10
    })
    :addElement({
        id = "terminal_content",
        x = 16,
        y = 79,
        w = 160,
        h = 129,
        z_index = 11,
        update = function(self, dt)
            if #queue_lines > 0 then
                line_timer = line_timer + dt
                while line_timer >= LINE_INTERVAL and #queue_lines > 0 do
                    line_timer = line_timer - LINE_INTERVAL
                    local l = table.remove(queue_lines, 1)
                    table.insert(terminal_lines, l)
                    if screen then screen.needs_render = true end
                end

                if #queue_lines == 0 and hack_step == 4 and desktop then
                    local door = desktop:getElement("door")
                    if door then door.visible = true end
                    GameState.set("level2_2_door_opened", true)
                    if screen then screen.needs_render = true end
                end
            end
        end,
        draw = function(self)
            local cw, ch = self.w, self.h
            local cv = getTermCanvas(cw, ch)
            local f = getTermFont()
            if not cv then return end

            love.graphics.push("all")
            love.graphics.setCanvas(cv)
            love.graphics.origin()
            love.graphics.setScissor()

            love.graphics.clear(0.02, 0.04, 0.03, 0.96)

            if f then
                love.graphics.setFont(f)
                local lh = f:getHeight() + 1
                local max_visible = math.floor((ch - 6) / lh)

                if hack_step == 0 and #terminal_lines == 0 then
                    love.graphics.setColor(0.2, 0.55, 0.3, 0.8)
                    love.graphics.print("PAYMENT TERMINAL", 4, 4)
                    local blink = (math.floor(love.timer.getTime() * 2) % 2 == 0)
                    if blink then
                        love.graphics.setColor(0.3, 0.9, 0.45, 0.95)
                        love.graphics.print("[PRESS ENTER]", 4, 4 + lh * 2)
                    end
                else
                    local total = #terminal_lines
                    local start_idx = math.max(1, total - max_visible + 1)
                    local dy = 4
                    local cursor_char = (math.floor(love.timer.getTime() * 2.5) % 2 == 0 and #queue_lines == 0 and hack_step < 4) and "_" or ""

                    for i = start_idx, total do
                        local line_text = terminal_lines[i]
                        if i == total and cursor_char ~= "" then
                            line_text = line_text .. cursor_char
                        end

                        if line_text:sub(1, 1) == ">" or line_text:sub(1, 1) == "#" or line_text:sub(1, 4) == "root" then
                            love.graphics.setColor(0.4, 1.0, 0.5, 1.0)
                        elseif line_text:sub(1, 3) == "[+]" or line_text:sub(1, 4) == "[OK]" then
                            love.graphics.setColor(0.3, 0.95, 0.4, 1.0)
                        elseif line_text:sub(1, 3) == "[!]" then
                            love.graphics.setColor(1.0, 0.85, 0.25, 1.0)
                        elseif line_text:sub(1, 3) == "[*]" then
                            love.graphics.setColor(0.35, 0.85, 1.0, 1.0)
                        elseif line_text:find("ACCESS GRANTED") or line_text:find("UNLOCKED") then
                            love.graphics.setColor(0.45, 1.0, 0.65, 1.0)
                        else
                            love.graphics.setColor(0.25, 0.75, 0.35, 0.9)
                        end

                        love.graphics.print(line_text, 4, dy)
                        dy = dy + lh
                    end
                end
            end

            love.graphics.setColor(0, 0, 0, 0.16)
            for sy = 0, ch, 2 do
                love.graphics.rectangle("fill", 0, sy, cw, 1)
            end

            love.graphics.pop()

            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(cv, self.x, self.y)
        end
    })
    :addElement({
        id = "terminal_input",
        image = "assets/level1/sublv2/terminal_enter.png",
        x = 122,
        y = 201,
        z_index = 12,
        clickable = true,
        onInteract = function(self)
            advanceTerminal()
        end,
        onClick = function(self)
            advanceTerminal()
        end,
        canInteract = function(self)
            return not GameState.get("level2_2_door_opened")
        end
    })
    :addElement({
        id = "door",
        image = "assets/level0/desktop/door.png",
        x = 234,
        y = 112,
        z_index = 5,
        visible = false,
        clickable = true,
        onInteract = function(self)
            SceneManager.crossFade("level2-3", 0.4)
        end,
        onClick = function(self)
            SceneManager.crossFade("level2-3", 0.4)
        end
    })
    :spawnPlayer({
        x = 32,
        y = 32,
        sheet = "assets/rage/rage_sh.ini"
    })
    :onKey(function(self, action, key)
        if action == "press" then
            if key == "escape" then
                SceneManager.goTo("menu")
            elseif key == "return" or key == "kpenter" then
                advanceTerminal()
            end
        end
    end)
    :build()

screen = PixelScreen.new({
    game = desktop,
    x = 320,
    y = 60,
    w = 1280,
    h = 960
})

local Level1Scene = GameScene.new({
    bg = "assets/bg/bossbg_back.png",
    screen = screen,
    screen_draw_fn = function(s)
        Effects.drawCrt(s.canvas, s.x, s.y, s.scale_x, s.scale_y)
    end,
    enter = function(self)
        AudioManager.musFadeTo("mr_boss", 0.3, 0.5, "reverb")

        -- If already completed, restore state
        if GameState.get("level2_2_door_opened") then
            local door = desktop:getElement("door")
            if door then door.visible = true end
            hack_step = 4
            terminal_lines = {}
            for s = 1, 4 do
                for _, l in ipairs(HACK_STAGES[s]) do
                    table.insert(terminal_lines, l)
                end
            end
        end
    end,
    leave = function(self)
        AudioManager.musStop(0.5)
    end
})

return Level1Scene
