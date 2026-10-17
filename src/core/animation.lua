local Animation = {}
Animation.__index = Animation

function Animation.new(sheet, default_anim)
    local self = setmetatable({}, Animation)

    self.sheet = sheet
    self.current_anim_name = nil
    self.current_anim = nil

    self.frames = { 0 }
    self.frame_idx = 1
    self.timer = 0
    self.fps = 12
    self.frame_duration = 1 / 12

    self.is_playing = false
    self.is_finished = false
    self.loop = true
    self.pingpong = false
    self.direction = 1

    self.on_finish = nil
    self.on_finish_callback = nil

    if default_anim then
        self:play(default_anim)
    elseif sheet and sheet.anims then

        local first_k = next(sheet.anims)
        if first_k then
            self:play(first_k)
        end
    end

    return self
end

function Animation:play(anim_name, opts)
    opts = opts or {}

    if not self.sheet then return end

    local anim_def = self.sheet:getAnimationDef(anim_name)
    if not anim_def then

        local quad = self.sheet:getQuad(anim_name)
        if quad then
            self.current_anim_name = anim_name
            self.current_anim = nil
            self.frames = { anim_name }
            self.frame_idx = 1
            self.is_playing = false
            self.is_finished = true
            return
        end
        print(string.format("[Animation] Warning: Animation '%s' not found!", tostring(anim_name)))
        return
    end

    if self.current_anim_name == anim_name and self.is_playing and not opts.force_restart then
        if opts.on_finish ~= nil then
            self.on_finish = opts.on_finish
        end
        return
    end

    self.queued_anim = nil
    self.current_anim_name = anim_name
    self.current_anim = anim_def

    local raw_frames = anim_def.frames or { 0 }
    if type(raw_frames) == "number" then
        self.frames = { raw_frames }
    elseif type(raw_frames) == "table" then
        self.frames = raw_frames
    else
        self.frames = { 0 }
    end

    self.frame_idx = 1
    self.timer = 0
    self.direction = 1
    self.is_playing = true
    self.is_finished = false

    local anim_fps = opts.fps or anim_def.fps or self.sheet.default_fps or 12
    self.fps = math.max(0.1, anim_fps)
    self.frame_duration = 1.0 / self.fps

    if opts.loop ~= nil then
        self.loop = opts.loop
    elseif anim_def.loop ~= nil then
        self.loop = anim_def.loop
    else
        self.loop = (anim_def.on_finish == nil)
    end

    self.pingpong = (opts.pingpong ~= nil) and opts.pingpong or (anim_def.pingpong == true)
    self.on_finish = (opts.on_finish ~= nil) and opts.on_finish or anim_def.on_finish
end

function Animation:waitEndAndGo(next_anim, opts)
    if not self.is_playing or self.is_finished or not self.current_anim then
        self:play(next_anim, opts)
        return self
    end

    self.queued_anim = {
        anim_name = next_anim,
        opts = opts or {}
    }
    return self
end

Animation.queue = Animation.waitEndAndGo
Animation.chain = Animation.waitEndAndGo
Animation.playQueued = Animation.waitEndAndGo

function Animation:clearQueue()
    self.queued_anim = nil
end

function Animation:getQueuedAnim()
    return self.queued_anim and self.queued_anim.anim_name
end

function Animation:update(dt)
    if not self.is_playing or self.is_finished then return end
    if not self.frames or #self.frames <= 1 then return end

    self.timer = self.timer + dt

    while self.timer >= self.frame_duration do
        self.timer = self.timer - self.frame_duration

        local next_idx = self.frame_idx + self.direction

        if self.pingpong then
            if next_idx > #self.frames then
                self.direction = -1
                next_idx = math.max(1, #self.frames - 1)
            elseif next_idx < 1 then
                if self.queued_anim then
                    local q = self.queued_anim
                    self.queued_anim = nil
                    self:play(q.anim_name, q.opts)
                    return
                elseif self.loop then
                    self.direction = 1
                    next_idx = math.min(#self.frames, 2)
                else
                    self:_handleFinish()
                    return
                end
            end
            self.frame_idx = next_idx
        else

            if next_idx > #self.frames then
                if self.queued_anim then
                    local q = self.queued_anim
                    self.queued_anim = nil
                    self:play(q.anim_name, q.opts)
                    return
                elseif self.loop then
                    self.frame_idx = 1
                else
                    self.frame_idx = #self.frames
                    self:_handleFinish()
                    return
                end
            else
                self.frame_idx = next_idx
            end
        end
    end
end

function Animation:_handleFinish()
    self.is_finished = true
    self.is_playing = false

    if self.queued_anim then
        local q = self.queued_anim
        self.queued_anim = nil
        self:play(q.anim_name, q.opts)
        return
    end

    local next_target = self.on_finish

    if type(next_target) == "function" then
        next_target(self)
    elseif type(next_target) == "string" and next_target ~= "" then

        self:play(next_target)
    end
end

function Animation:pause()
    self.is_playing = false
end

function Animation:resume()
    if not self.is_finished then
        self.is_playing = true
    end
end

function Animation:stop()
    self.is_playing = false
    self.is_finished = true
    self.frame_idx = 1
    self.timer = 0
end

function Animation:setFrame(frame_idx)
    if not self.frames then return end
    self.frame_idx = math.max(1, math.min(#self.frames, frame_idx or 1))
    self.timer = 0
end

function Animation:getCurrentFrame()
    if not self.frames or #self.frames == 0 then return 0 end
    return self.frames[self.frame_idx] or self.frames[1] or 0
end

function Animation:getCurrentQuad()
    if not self.sheet then return nil end
    local frame = self:getCurrentFrame()
    return self.sheet:getQuad(frame)
end

function Animation:getCurrentAnimName()
    return self.current_anim_name
end

function Animation:isPlaying()
    return self.is_playing
end

function Animation:isFinished()
    return self.is_finished
end

function Animation:getWidth()
    return self.sheet and self.sheet.frame_width or 0
end

function Animation:getHeight()
    return self.sheet and self.sheet.frame_height or 0
end

function Animation:draw(x, y, r, sx, sy, ox, oy)
    if not self.sheet or not self.sheet.image then return end

    local quad = self:getCurrentQuad()
    if not quad then return end

    local _, _, qw, qh = quad:getViewport()
    local origin_x = ox or (qw / 2)
    local origin_y = oy or (qh / 2)

    love.graphics.draw(
        self.sheet.image,
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

function Animation:clone(default_anim)
    local anim = Animation.new(self.sheet, default_anim or self.current_anim_name)
    return anim
end

return Animation
