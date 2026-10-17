local IniParser = require("src.core.ini_parser")

local Spritesheet = {}
Spritesheet.__index = Spritesheet

function Spritesheet.new(def_or_path, base_dir)
    local self = setmetatable({}, Spritesheet)

    local def = def_or_path
    local ini_dir = base_dir or ""
    if type(def_or_path) == "string" then
        def = IniParser.parse(def_or_path)

        ini_dir = def_or_path:match("^(.-)[^/\\]+$") or ""
    end

    def = def or {}
    self.meta = def.meta or {}
    self.anims = def.anims or {}
    self.named_frames = def.frames or {}

    self.image = nil
    self.quads = {}
    self.frame_width = self.meta.frame_width or 32
    self.frame_height = self.meta.frame_height or 32
    self.default_fps = self.meta.fps or 12
    self.columns = self.meta.columns or 0
    self.rows = self.meta.rows or 0
    self.total_frames = 0

    self:_loadImage(ini_dir)
    self:_generateQuads()

    return self
end

function Spritesheet:_loadImage(ini_dir)
    local img_path = self.meta.image or self.meta.texture or self.meta.file
    if not img_path then
        print("[Spritesheet] Warning: No image specified in meta!")
        return
    end

    local full_path = img_path
    if not (img_path:find("^assets/") or img_path:find("^src/")) and ini_dir ~= "" then
        local try_rel = ini_dir .. img_path
        if love.filesystem and love.filesystem.getInfo(try_rel) then
            full_path = try_rel
        end
    end

    if love.filesystem and love.filesystem.getInfo(full_path) then
        local ok, img = pcall(love.graphics.newImage, full_path)
        if ok and img then
            self.image = img
            local filter = self.meta.filter or "nearest"
            self.image:setFilter(filter, filter)

        else
            print(string.format("[Spritesheet] Error loading image '%s': %s", full_path, tostring(img)))
        end
    else
        print(string.format("[Spritesheet] Warning: Image file not found: %s", full_path))
    end
end

function Spritesheet:_generateQuads()
    if not self.image then return end

    local img_w = self.image:getWidth()
    local img_h = self.image:getHeight()

    local fw = self.frame_width
    local fh = self.frame_height

    local cols = (self.columns > 0) and self.columns or math.floor(img_w / fw)
    local rows = (self.rows > 0) and self.rows or math.floor(img_h / fh)
    self.columns = math.max(1, cols)
    self.rows = math.max(1, rows)

    self.total_frames = self.columns * self.rows

    for r = 0, self.rows - 1 do
        for c = 0, self.columns - 1 do
            local idx = r * self.columns + c
            local qx = c * fw
            local qy = r * fh
            self.quads[idx] = love.graphics.newQuad(qx, qy, fw, fh, img_w, img_h)
        end
    end

    for name, frame_data in pairs(self.named_frames) do
        if type(frame_data) == "table" and frame_data.x and frame_data.y and frame_data.w and frame_data.h then
            self.quads[name] = love.graphics.newQuad(
                frame_data.x, frame_data.y, frame_data.w, frame_data.h, img_w, img_h
            )
        end
    end
end

function Spritesheet:getQuad(frame_id_or_index)
    if type(frame_id_or_index) == "string" then
        if self.quads[frame_id_or_index] then
            return self.quads[frame_id_or_index]
        end
        if self.named_frames[frame_id_or_index] ~= nil then
            local named_val = self.named_frames[frame_id_or_index]
            if type(named_val) == "number" then
                return self.quads[named_val]
            elseif type(named_val) == "table" and named_val.index ~= nil then
                return self.quads[named_val.index]
            end
        end
    end

    local idx = tonumber(frame_id_or_index) or 0
    return self.quads[idx] or self.quads[0]
end

function Spritesheet:hasFrame(frame_id_or_index)
    if type(frame_id_or_index) == "string" then
        return (self.named_frames[frame_id_or_index] ~= nil) or (self.quads[frame_id_or_index] ~= nil)
    end
    local idx = tonumber(frame_id_or_index)
    return idx and (self.quads[idx] ~= nil) or false
end

Spritesheet.getFrame = Spritesheet.getQuad

function Spritesheet:getImage()
    return self.image
end

function Spritesheet:getFrameSize()
    return self.frame_width, self.frame_height
end

function Spritesheet:getAnimationDef(name)
    return self.anims[name]
end

function Spritesheet:drawFrame(frame_id_or_index, x, y, r, sx, sy, ox, oy)
    if not self.image then return end

    local quad = self:getQuad(frame_id_or_index)
    if not quad then return end

    local _, _, qw, qh = quad:getViewport()
    local origin_x = ox or (qw / 2)
    local origin_y = oy or (qh / 2)

    love.graphics.draw(
        self.image,
        quad,
        x or 0,
        y or 0,
        r or 0,
        sx or 1,
        sy or 1,
        origin_x,
        origin_y
    )
end

return Spritesheet
