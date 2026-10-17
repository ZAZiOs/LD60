local IniParser = {}

local function trim(s)
    return s:match("^%s*(.-)%s*$")
end

local function parse_value(val_str, key)
    local v = trim(val_str)

    local lower = v:lower()
    if lower == "true" or lower == "yes" or lower == "on" then
        return true
    elseif lower == "false" or lower == "no" or lower == "off" then
        return false
    end

    if key == "frames" or key == "frame_sequence" then
        local frames = {}
        for part in v:gmatch("([^,]+)") do
            part = trim(part)
            local r_start, r_end = part:match("^(%d+)%s*-%s*(%d+)$")
            if r_start and r_end then
                local s_num = tonumber(r_start)
                local e_num = tonumber(r_end)
                local step = (s_num <= e_num) and 1 or -1
                for f = s_num, e_num, step do
                    table.insert(frames, f)
                end
            elseif tonumber(part) then
                table.insert(frames, tonumber(part))
            end
        end
        if #frames > 0 then
            return frames
        end
    end

    local num = tonumber(v)
    if num then
        return num
    end

    local q_str = v:match('^"(.*)"$') or v:match("^'(.*)'$")
    if q_str then
        return q_str
    end

    return v
end

function IniParser.parse(input)
    if not input or input == "" then
        return {}
    end

    local text = input

    if not input:find("\n") then
        if love and love.filesystem and love.filesystem.getInfo(input) then
            local content, _ = love.filesystem.read(input)
            if content then
                text = content
            end
        else
            local f = io.open(input, "r")
            if f then
                text = f:read("*all")
                f:close()
            end
        end
    end

    local result = {
        meta = {},
        anims = {},
        frames = {}
    }

    local current_section = "meta"
    local current_sub_type = nil
    local current_sub_id = nil

    for line in text:gmatch("[^\r\n]+") do
        local l = trim(line)

        if l ~= "" and not l:match("^[;#]") then

            local section = l:match("^%[([^%]]+)%]$")
            if section then
                section = trim(section)
                local sub_type, sub_id = section:match("^([%w_]+)%s*:%s*([%w_%-%.]+)$")
                if sub_type and sub_id then
                    current_section = sub_type
                    current_sub_type = sub_type
                    current_sub_id = sub_id
                    if sub_type == "anim" or sub_type == "animation" then
                        result.anims[sub_id] = result.anims[sub_id] or { id = sub_id }
                    elseif sub_type == "frame" or sub_type == "sprite" then
                        result.frames[sub_id] = result.frames[sub_id] or {}
                    end
                else
                    current_section = section
                    current_sub_type = nil
                    current_sub_id = nil
                    if not result[section] then
                        result[section] = {}
                    end
                end
            else

                local key, val = l:match("^([^=]+)=(.*)$")
                if key and val then
                    key = trim(key)
                    val = parse_value(val, key)

                    if current_sub_type == "anim" or current_sub_type == "animation" then
                        result.anims[current_sub_id][key] = val
                    elseif current_sub_type == "frame" or current_sub_type == "sprite" then
                        if key == "index" or key == "frame" then
                            result.frames[current_sub_id] = val
                        else
                            if type(result.frames[current_sub_id]) ~= "table" then
                                result.frames[current_sub_id] = { index = result.frames[current_sub_id] }
                            end
                            result.frames[current_sub_id][key] = val
                        end
                    elseif current_section == "meta" then
                        result.meta[key] = val
                    else
                        result[current_section][key] = val
                    end
                end
            end
        end
    end

    return result
end

return IniParser
