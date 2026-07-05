local Theme = {
    colors = {
        button = { 0.24, 0.30, 0.52 },
        button_hover = { 0.34, 0.41, 0.66 },
        button_disabled = { 0.22, 0.22, 0.28 },
        panel = { 0.10, 0.09, 0.14, 0.90 },
        panel_soft = { 0.18, 0.20, 0.28, 0.92 },
        text = { 0.96, 0.96, 0.98, 1.0 },
        text_soft = { 0.70, 0.72, 0.80, 1.0 },
        success = { 0.45, 0.84, 0.54, 1.0 },
        warning = { 0.92, 0.75, 0.30, 1.0 },
        error = { 0.92, 0.36, 0.36, 1.0 },
        accent = { 0.42, 0.78, 0.90, 1.0 },
        level_up = { 1.0, 0.84, 0.35, 1.0 },
    },
}

local font_cache = {}

function Theme.getFont(size)
    if not font_cache[size] then
        font_cache[size] = love.graphics.newFont(size)
    end
    return font_cache[size]
end

return Theme
