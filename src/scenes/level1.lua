local SceneManager = require("src.core.scene_manager")
local PixelScreen = require("src.core.pixel_screen")
local GameScene = require("src.core.game_scene")
local PixelSceneBuilder = require("src.core.pixel_scene_builder")
local AudioManager = require("src.core.audio_manager")
local Effects = require("src.core.effects")
local GameState = require("src.core.game_state")

local desktop = PixelSceneBuilder.new("desktop_level1")
    :background("assets/level1/wp.png")
    :cursor("assets/cursor.ini")
    :addSolid("taskbar", {
        image = "assets/level1/taskbar.png",
        x = 0,
        y = 224,
        w = 320,
        h = 16
    })
    
    -- bed
    :addSolid("bed_main", {
        image = "assets/level1/bed_main.png",
        x = 205,
        y = 189,
        h = 83
    })
    :addSolid("bed_back", {
        image = "assets/level1/bed_back.png",
        x = 205,
        y = 170,
        h = -3,
        z_index = -3,
    })

    -- bg-attached shelves
    :addSolid("shelf_left", {
        image = "assets/level1/shelf2.png",
        x = 45,
        y = 70,
    })
    :addSolid("shelf_right", {
        image = "assets/level1/shelf2.png",
        x = 220,
        y = 70,
    })

    -- right wall shelf
    :addSolid("shelf_wall", {
        image = "assets/level1/shelf1.png",
        x = 285,
        y = 140,
        h = 1,
    })
    :addSolid("shelf_wall_books", {
        image = "assets/level1/books.png",
        x = 303,
        y = 107,
    })

    -- chandelier
    :addSolid("chandelier", {
        image = "assets/level1/lamp.png",
        x = 133,
        y = 38,
    })
    :addElement({
        id = "cable",
        image = "assets/level1/cable.png",
        x = 161,
        y = 0,
        z_index = -2,
    })

    -- vent
    :addElement({
        id = "vent",
        image = "assets/level1/vent_c.png",
        x = 15,
        y = 15,
        z_index = -2,
        onInteract = function(self)
            if GameState.get("level1_vent_opened") then
                SceneManager.crossFade("level2", 0.4)
            end
            if GameState.get("level1_crowbar_collected") then
                self.image = "assets/level1/vent_o.png"
                local ok, img = pcall(love.graphics.newImage, self.image)
                if ok and img then
                    img:setFilter("nearest", "nearest")
                    self.img_obj = img
                end
                GameState.set("level1_vent_opened", true)
            end
        end
    })

    -- miscellaneous
    :addElement({
        id = "chest",
        image = "assets/level1/chest_closed.png",
        x = 55,
        y = 187,
        z_index = 2,
        onInteract = function(self)
            if GameState.get("level1_key_collected") then
                self.image = "assets/level1/chest_open.png"
                local ok, img = pcall(love.graphics.newImage, self.image)
                if ok and img then
                    img:setFilter("nearest", "nearest")
                    self.img_obj = img
                end
                GameState.set("level1_chest_opened", true)
                if not GameState.get("level1_crowbar_collected") then
                    self.scene:getElement("crowbar").visible = true
                end
                if not GameState.get("level1_note_collected") then
                    self.scene:getElement("note").visible = true
                end
            end
        end
    })
    :addElement({
        id = "key",
        image = "assets/level1/key.png",
        x = 300,
        y = 200,
        z_index = 2,
        onInteract = function(self)
            if not GameState.get("level1_key_collected", false) then
                GameState.set("level1_key_collected", true)
            end
            self.visible = false
        end
    })
    :addElement({
        id = "whatnot",
        image = "assets/level1/chest.png",
        x = 5,
        y = 117,
        z_index = -2,
    })
    :addElement({
        id = "note",
        image = "assets/level1/note.png",
        x = 60,
        y = 160,
        z_index = 0,
        visible = false,
        onInteract = function(self)
            if GameState.get("level1_chest_opened") then
                GameState.set("level1_note_collected", true)
                self.visible = false
                self.scene:getElement("tab_text").visible = true
            end
        end
    })
    :addElement({
        id = "crowbar",
        image = "assets/level1/fomka.png",
        x = 20,
        y = 160,
        z_index = 0,
        visible = false,
        onInteract = function(self)
            if GameState.get("level1_chest_opened") then
                GameState.set("level1_crowbar_collected", true)
                self.visible = false
            end
        end
    })

    :addTab("tab_text", {
        idle = "assets/level1/tab_text_idle.png",
        active = "assets/level1/tab_text_a.png",
        x = 40,
        y = 226,
        visible = false,
        onClick = function(self)
            self.scene:toggleElement("window_text")
            local win = self.scene:getElement("window_text")
            self.scene:setElementActive("tab_text", win and win.visible)
        end,
        onInteract = function(self)
            self:onClick()
        end
    })
    :addWindow("window_text", {
        title = "17oct.txt",
        x = 56,
        y = 40,
        w = 180,
        h = 120,
        z_index = 50,
        visible = false,
        text = [[October 17

Meow meow :3
meow meow mew meow
meow meow mew meow
meow meow mew meow
meow meow mew meow
]],
        onClose = function(self)
            local tab = self.scene:getElement("tab_text")
            if tab then
                self.scene:setElementActive("tab_text", false)
            end
        end
    })
    :spawnPlayer({
        x = 100,
        y = 224,
        sheet = "assets/rage/rage_sh.ini"
    })
    :onKey(function(self, action, key)
        if action == "press" then
            if key == "escape" then
                SceneManager.goTo("menu")
            elseif key == "backspace" then
                SceneManager.crossFade("level0", 0.4)
            elseif key == "return" then
                SceneManager.goTo("level2")
            end
        end
    end)
    :build()

local screen = PixelScreen.new({
    game = desktop,
    x = 320,
    y = 60,
    w = 1282,
    h = 962
})

local Level1Scene = GameScene.new({
    bg = "assets/bg/girls_room.png",
    screen = screen,
    screen_draw_fn = function(s)
        Effects.drawCrt(s.canvas, s.x, s.y, s.scale_x, s.scale_y)
    end,
    enter = function(self)
        AudioManager.musFadeTo("cat", 0.8, 0.5)
    end,
    leave = function(self)
        AudioManager.musStop(0.5)
    end
})

return Level1Scene
