local utils = {}

function utils.clamp(val, min, max)
    return math.max(min, math.min(max, val))
end

function utils.lerp(a, b, t)
    return a + (b - a) * t
end

function utils.dist(x1, y1, x2, y2)
    return math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
end

function utils.round(x)
    return math.floor(x + 0.5)
end

-- Convert HSL (0-1 range each) to RGB (0-1 range each).
function utils.hslToRgb(h, s, l)
    h = h % 1.0
    if s == 0 then return l, l, l end
    local function hue2rgb(p, q, t)
        if t < 0 then t = t + 1 end
        if t > 1 then t = t - 1 end
        if t < 1/6 then return p + (q - p) * 6 * t end
        if t < 1/2 then return q end
        if t < 2/3 then return p + (q - p) * (2/3 - t) * 6 end
        return p
    end
    local q = l < 0.5 and l * (1 + s) or l + s - l * s
    local p = 2 * l - q
    return hue2rgb(p, q, h + 1/3),
           hue2rgb(p, q, h),
           hue2rgb(p, q, h - 1/3)
end

return utils
