# ⚡ Core Cheat Sheet (LD60)

> Быстрая шпаргалка по движку для джема. Копируй, вставляй и делай игру.  
> Виртуальное разрешение экрана: **1920×1080** (все координаты считаем под него).

---

## 🚀 Готовый шаблон сцены (`src/scenes/level_sample.lua`)

```lua
local SceneManager       = require("src.core.scene_manager")
local Viewport           = require("src.core.viewport")
local AudioManager       = require("src.core.audio_manager")
local I18n               = require("src.core.i18n")
local GameState          = require("src.core.game_state")
local Events             = require("src.core.events")
local SpritesheetManager = require("src.core.spritesheet_manager")

local Scene = {}

function Scene:enter(custom_arg)
    -- Запуск музыки при входе
    AudioManager.musFadeTo("theme", 0.8, 0.5)

    -- Подписка на событие с тегом сцены (для авто-очистки)
    Events.on("take_damage", function(dmg)
        AudioManager.sfxPlay("hit")
    end, "my_scene")
end

function Scene:leave()
    -- ОБЯЗАТЕЛЬНО: очистить слушатели этой сцены
    Events.clear("my_scene")
end

function Scene:update(dt)
end

function Scene:draw()
    -- Экран 1920x1080. Viewport уже подключен в main.lua!
    love.graphics.setFont(I18n.fonts.title)
    love.graphics.print("Score: " .. GameState.get("score", 0), 50, 50)
end

function Scene:mousepressed(x, y, button)
    -- (x, y) уже приведены к координатам 1920x1080!
    if button == 1 then
        Events.emit("take_damage", 10)
    end
end

function Scene:keypressed(key)
    if key == "escape" then
        SceneManager.fadeTo("menu", 0.3) -- Плавный уход в меню
    end
end

return Scene
```

---

## 🎬 1. Сцены (`SceneManager`)

```lua
local SceneManager = require("src.core.scene_manager")

-- Регистрация в main.lua:
SceneManager.register("menu", "src.scenes.menu")
SceneManager.register("level1", "src.scenes.level1")

-- Переходы между сценами:
SceneManager.goTo("level1")                   -- Мгновенно (с передачей аргументов)
SceneManager.fadeTo("level1", 0.5)            -- Плавное затемнение за 0.5 сек
SceneManager.fadeTo("level1", 1.0, {0, 0, 0}) -- Фейд в чёрный цвет
```

---

## 🖥️ 2. Игра в мониторе (`PixelScreen` + `GameScene` + `PixelSceneBuilder`)

Канвас 320×240 (пиксель-арт с фильтром `nearest`) внутри монитора на фоне 1920×1080.

### Сборка через Fluent Builder:
```lua
local PixelSceneBuilder = require("src.core.pixel_scene_builder")
local PixelScreen        = require("src.core.pixel_screen")
local GameScene          = require("src.core.game_scene")

-- 1. Декларативно собираем внутреннюю сцену 320x240:
local desktop = PixelSceneBuilder.new("desktop")
    :background("assets/level1/desktop/wp.png")
    :cursor("assets/cursor.ini")
    :addSolid("taskbar", { image = "assets/level1/desktop/taskbar.png", x = 0, y = 224, w = 320, h = 16 })
    :addTab("tab_settings", {
        idle = "assets/level1/desktop/tab_settings.png",
        active = "assets/level1/desktop/tab_settings_a.png",
        x = 115, y = 226,
        require_key = "down", -- требует зажать кнопку ("down", "up", "left", "right" или имя клавиши)
        onClick = function(self) self.scene:toggleElement("window_settings") end,
        onInteract = function(self) self:onClick() end
    })
    :addElement({
        id = "terminal_wall",
        image = "assets/terminal.png",
        x = 200, y = 180,
        is_solid = true,
        require_collision = "right", -- требует упереться коллизией вправо + зажать направо
        onInteract = function(self) print("Hacked terminal!") end
    })
    :addTooltip("tooltip_readme", {
        text = "read this\nbefore playing\n(press ↓ + E)",
        target = "tab_readme",
        x = 36, y = 168
    })
    :addWindow("window_settings", { image = "assets/level1/desktop/window_settings.png", x = 120, y = 120, visible = false, is_solid = true })
    :spawnPlayer({ x = 30, y = 224, sheet = "assets/rage/rage_sh.ini" })
    :build()

-- Индикатор взаимодействия: 1px белая обводка генерируется ТОЛЬКО когда выполнены все требования
-- (дистанция + зажатая клавиша `require_key` или упирание в коллизию `require_collision`).
-- При появлении обводки нажатие E гарантированно взаимодействует с элементом.

-- Генеративный тултип (:addTooltip): динамически считает размер блока под текст (Tahoma 9px без сглаживания)
-- и рисует пиксельный белый бабл с хвостиком, указывающим на целевой элемент.

-- 2. Помещаем в экран монитора:
local screen = PixelScreen.new({ game = desktop, x = 320, y = 60, w = 1280, h = 960 })

return GameScene.new({ bg = "assets/bg/intro_bg.png", screen = screen })
```

---

## 📺 3. Экран и мышь (`Viewport`)

В `main.lua` уже всё настроено (1920×1080 с черными полосами на нестандартных мониторах).

```lua
local Viewport = require("src.core.viewport")

-- Размеры виртуального холста:
local w = Viewport.getWidth()  -- 1920
local h = Viewport.getHeight() -- 1080

-- Позиция мыши в виртуальных координатах:
local mx, my = Viewport.getMousePosition()

-- Внутри ли экрана точка:
local ok = Viewport.isInside(mx, my)
```

---

## 🎵 4. Музыка и звуки (`AudioManager`)

```lua
local AudioManager = require("src.core.audio_manager")

-- МУЗЫКА:
AudioManager.musPlay("main_theme", 0.8)     -- Запустить сразу (id из audio_db или путь к .ogg)
AudioManager.musFadeTo("ambient", 0.7, 1.5) -- Кроссфейд на новый трек за 1.5 сек
AudioManager.musFadeTo(nil, 0.2, 1.0)       -- Плавно приглушить текущий трек
AudioManager.musStop(1.0)                   -- Остановить с фейдом 1 сек (или без аргументов — сразу)

-- ЗВУКИ (полифонические — можно спамить кликами):
AudioManager.sfxPlay("click")
AudioManager.sfxPlay("explosion", 1.0, 1.2) -- громкость 1.0, pitch 1.2

-- ИЛИ ЧЕРЕЗ СОБЫТИЯ (не требует require AudioManager):
local Events = require("src.core.events")
Events.emit("musFadeTo", "boss", 0.8, 1.0)
Events.emit("sfxPlay", "laser")
```

---

## 🎞️ 5. Спрайты и Анимация (`SpritesheetManager`)

### 1) Создай `.ini` рядом с картинкой (`assets/sprites/hero.ini`):
```ini
[meta]
image = hero.png
frame_width = 64
frame_height = 64
fps = 12

[anim:idle]
frames = 0-3
loop = true

[anim:attack]
frames = 4-7
loop = false
on_finish = idle
```

### 2) Используй в коде:
```lua
local SpritesheetManager = require("src.core.spritesheet_manager")

-- Создание анимации:
local anim = SpritesheetManager.createAnimation("assets/sprites/hero.ini", "idle")

function love.update(dt)
    anim:update(dt)
end

function love.draw()
    -- Рисует отцентрированным в точке (x, y):
    anim:draw(400, 300)
end

-- Переключение анимации:
anim:play("attack")
anim:waitEndAndGo("idle") -- Доиграет текущий цикл до конца и включит idle

-- Отрисовка статичного кадра по номеру или имени:
local sheet = SpritesheetManager.getSheet("assets/sprites/hero.ini")
sheet:drawFrame(0, 100, 100)
```

---

## 🌍 6. Текст и Шрифты (`I18n`)

### Тексты (из `src/locales/ru.json` и `en.json`):
```lua
local I18n = require("src.core.i18n")

-- Простой перевод:
local str = I18n.t("menu.start")

-- С параметрами (в json: "Привет, %{name}!"):
local str2 = I18n.t("greeting", { name = "Игрок" })

-- Смена языка:
I18n.setLocale("en")
I18n.toggleLocale() -- переключает ru <-> en
```

### Шрифты:
```lua
-- Быстрые шорткаты:
love.graphics.setFont(I18n.fonts.small)  -- 20px
love.graphics.setFont(I18n.fonts.medium) -- 26px
love.graphics.setFont(I18n.fonts.dialog) -- 32px
love.graphics.setFont(I18n.fonts.large)  -- 36px
love.graphics.setFont(I18n.fonts.title)  -- 56px
love.graphics.setFont(I18n.fonts.tahoma9) -- 9px Tahoma без антиалисинга (hinting = mono, filter = nearest, как в Aseprite)

-- Жирный / кастомный размер:
love.graphics.setFont(I18n.getFont("medium", "bold"))
love.graphics.setFont(I18n.getFont(40, "black"))
love.graphics.setFont(I18n.getFont(9, "regular", "tahoma"))
love.graphics.setFont(I18n.getFont("title", "regular", "cairopixel")) -- пиксельный шрифт
```

---

## 💾 7. Состояние игры (`GameState`)

Глобальное хранилище данных (сессия, флаги, прогресс) между сценами.

```lua
local GameState = require("src.core.game_state")

-- Установка и получение значений (2-й аргумент - значение по умолчанию):
GameState.set("score", 100)
local score = GameState.get("score", 0)

-- Проверка и удаление:
if GameState.has("quest_complete") then ... end
GameState.delete("temp_flag")

-- Инициализация / сброс к дефолтным значениям:
GameState.init({ score = 0, level = 1 })
GameState.reset() -- сброс к значениям из init
GameState.clear() -- полная очистка таблицы
```


---

## ⚙️ 8. Настройки (`Settings`)

Автоматически сохраняются в `settings.json` при изменении:

```lua
local Settings = require("src.core.settings")

Settings.set("music_volume", 0.5) -- 0.0 .. 1.0 (сразу меняет громкость)
Settings.set("locale", "en")       -- меняет язык
Settings.set("fullscreen", true)   -- меняет режим экрана

local vol = Settings.get("music_volume")
```

---

## 📢 9. Шина Событий (`Events`)

Общение между модулями без лишних `require`:

```lua
local Events = require("src.core.events")

-- 1. Слушать (3-й аргумент - тег для удобной очистки):
Events.on("quest_done", function(reward)
    print("Получено:", reward)
end, "level1")

-- 2. Отправить:
Events.emit("quest_done", 500)

-- 3. Очистить в scene:leave():
Events.clear("level1")
```

---

## 🪟 10. Генеративные Окна (`PixelWindow`) и Пиксельные Сцены (`PixelSceneBuilder`)

Сборка 9-slice окон любого размера с заголовком, кнопкой закрытия, перетаскиванием, скроллом и твердой коллизией:

```lua
local PixelSceneBuilder = require("src.core.pixel_scene_builder")

local desktop = PixelSceneBuilder.new("desktop")
    :background("assets/level1/desktop/wp.png")
    :cursor("assets/cursor.ini")
    
    -- Кнопка/вкладка в таскбаре:
    :addTab("tab_readme", {
        idle = "assets/level1/desktop/tab_readme.png",
        active = "assets/level1/desktop/tab_readme_a.png",
        x = 62,
        y = 226,
        onClick = function(self)
            self.scene:toggleElement("window_readme")
            local win = self.scene:getElement("window_readme")
            self.scene:setElementActive("tab_readme", win and win.visible)
        end
    })

    -- Генеративное окно (собирается из assets/window.ini и window.png):
    :addWindow("window_readme", {
        title = "README.TXT",
        x = 48,
        y = 38,
        w = 192,
        h = 132,
        visible = false,
        is_solid = true,     -- персонаж может прыгать на окно как на платформу
        draggable = true,    -- можно таскать за заголовок мышкой
        closeable = true,    -- кнопка [X] в правом верхнем углу
        text = "Многострочный текст\nКоторый скроллится колесиком мышки!",
        onClose = function(self)
            self.scene:setElementActive("tab_readme", false)
        end
    })

    -- Окно с интерактивным содержимым на собственном Canvas:
    :addWindow("window_settings", {
        title = "SETTINGS.EXE",
        x = 76,
        y = 48,
        w = 168,
        h = 126,
        visible = false,
        is_solid = true
    })

local win = desktop:getElement("window_settings")

-- Добавление интерактивных виджетов в локальных координатах окна (от 0, 0):
win:addSlider({
    id = "slider_music",
    x = 8,
    y = 6,
    w = 136,
    label = "Music Volume",
    value = 0.8,
    onChange = function(self, val)
        Settings.set("music_volume", val)
    end
})

win:addCheckbox({
    id = "chk_mute",
    x = 8,
    y = 52,
    text = "Mute Audio",
    checked = false,
    onChange = function(self, val)
        Settings.set("muted", val)
    end
})

win:addButton({
    id = "btn_ok",
    x = 100,
    y = 90,
    w = 44,
    h = 13,
    text = "OK",
    onClick = function()
        win:close()
    end
})

-- Прямой доступ к Canvas окна:
local canvas = win:getCanvas()
-- Или произвольный рендер:
-- win.draw_content = function(self, canvas, inner_w, inner_h) ... end
```


