local SceneManager = require("src.core.scene_manager")
local GameState = require("src.core.game_state")

local Level2_2Logic = {}

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
local active_desktop = nil
local active_screen = nil

local function advanceTerminal()
    if #queue_lines > 0 then
        while #queue_lines > 0 do
            table.insert(terminal_lines, table.remove(queue_lines, 1))
        end
        if hack_step == 4 and active_desktop then
            local door = active_desktop:getElement("door")
            if door then door.visible = true end
            GameState.set("level2_2_door_opened", true)
        end
        if active_screen then active_screen.needs_render = true end
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

    if active_screen then active_screen.needs_render = true end
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

function Level2_2Logic.setup(desktop, parent_scene)
    active_desktop = desktop
    active_screen = parent_scene and parent_scene.pixel_screen

    local vent = desktop:getElement("vent")
    if vent then
        vent.onClick = function(self)
            SceneManager.crossFade("level2", 0.4)
        end
        vent.onInteract = function(self)
            SceneManager.crossFade("level2", 0.4)
        end
    end

    local term_content = desktop:getElement("terminal_content")
    if term_content then
        term_content.update = function(self, dt)
            if #queue_lines > 0 then
                line_timer = line_timer + dt
                while line_timer >= LINE_INTERVAL and #queue_lines > 0 do
                    line_timer = line_timer - LINE_INTERVAL
                    local l = table.remove(queue_lines, 1)
                    table.insert(terminal_lines, l)
                    if active_screen then active_screen.needs_render = true end
                end

                if #queue_lines == 0 and hack_step == 4 and active_desktop then
                    local door = active_desktop:getElement("door")
                    if door then door.visible = true end
                    GameState.set("level2_2_door_opened", true)
                    if active_screen then active_screen.needs_render = true end
                end
            end
        end

        term_content.draw = function(self)
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
    end

    local term_input = desktop:getElement("terminal_input")
    if term_input then
        term_input.onClick = function(self)
            advanceTerminal()
        end
        term_input.onInteract = function(self)
            advanceTerminal()
        end
        term_input.canInteract = function(self)
            return not GameState.get("level2_2_door_opened")
        end
    end

    local door = desktop:getElement("door")
    if door then
        door.onClick = function(self)
            SceneManager.crossFade("level2-3", 0.4)
        end
        door.onInteract = function(self)
            SceneManager.crossFade("level2-3", 0.4)
        end
    end
end

function Level2_2Logic.enter(desktop, parent_scene)
    active_desktop = desktop
    active_screen = parent_scene and parent_scene.pixel_screen

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
end

function Level2_2Logic.onKey(desktop, action, key, scancode, isrepeat)
    if action == "press" then
        if key == "escape" then
            SceneManager.goTo("menu")
        elseif key == "return" or key == "kpenter" then
            advanceTerminal()
        end
    end
end

return Level2_2Logic
