-- expression_system.lua
-- Reads a resident's mood table and produces a readable face overlay.
-- All faces are drawn procedurally via love.graphics — no sprite assets required.

local ExpressionSystem = {}

-- ---------------------------------------------------------------------------
-- Expression resolution: picks dominant expression from mood values.
-- Priority order matters — anger > embarrassment > stress > loneliness >
-- excitement > suspicion > happiness > neutral.
-- ---------------------------------------------------------------------------
local EXPRESSION_RULES = {
    { key = "angry",       test = function(m) return m.anger        >= 50 end },
    { key = "embarrassed", test = function(m) return m.embarrassment >= 45 end },
    { key = "stressed",    test = function(m) return m.stress        >= 60 end },
    { key = "lonely",      test = function(m) return m.loneliness    >= 65 end },
    { key = "excited",     test = function(m) return m.excitement    >= 60 end },
    { key = "suspicious",  test = function(m) return m.suspicion     >= 50 end },
    { key = "happy",       test = function(m) return m.happiness     >= 65 end },
}

function ExpressionSystem.resolve(resident)
    local m = resident.mood
    for _, rule in ipairs(EXPRESSION_RULES) do
        if rule.test(m) then
            return rule.key
        end
    end
    return "neutral"
end

-- ---------------------------------------------------------------------------
-- Draw: renders the expression face at (cx, cy) with given radius.
-- cx/cy = center of the face circle. Assumes caller already set up transform.
-- ---------------------------------------------------------------------------
function ExpressionSystem.draw(resident, cx, cy, radius)
    local expr = ExpressionSystem.resolve(resident)
    local r = radius

    -- Face base
    love.graphics.setColor(0.96, 0.84, 0.70, 1.0)
    love.graphics.circle("fill", cx, cy, r)
    love.graphics.setColor(0.2, 0.15, 0.1, 0.5)
    love.graphics.circle("line", cx, cy, r)

    -- Eyes
    local eye_y      = cy - r * 0.18
    local eye_offset = r * 0.30
    local eye_r      = r * 0.12

    if expr == "suspicious" then
        -- Narrowed / side-eye
        love.graphics.setColor(0.15, 0.10, 0.08)
        love.graphics.ellipse("fill", cx - eye_offset, eye_y, eye_r, eye_r * 0.5)
        love.graphics.ellipse("fill", cx + eye_offset, eye_y, eye_r * 0.7, eye_r * 0.5)
    elseif expr == "excited" then
        -- Wide open eyes
        love.graphics.setColor(0.15, 0.10, 0.08)
        love.graphics.circle("fill", cx - eye_offset, eye_y, eye_r * 1.3)
        love.graphics.circle("fill", cx + eye_offset, eye_y, eye_r * 1.3)
        -- Shines
        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.circle("fill", cx - eye_offset + eye_r*0.3, eye_y - eye_r*0.3, eye_r*0.35)
        love.graphics.circle("fill", cx + eye_offset + eye_r*0.3, eye_y - eye_r*0.3, eye_r*0.35)
    elseif expr == "stressed" or expr == "angry" then
        -- Furrowed, small eyes
        love.graphics.setColor(0.15, 0.10, 0.08)
        love.graphics.ellipse("fill", cx - eye_offset, eye_y, eye_r, eye_r * 0.6)
        love.graphics.ellipse("fill", cx + eye_offset, eye_y, eye_r, eye_r * 0.6)
        -- Eyebrow furrow lines
        love.graphics.setColor(0.15, 0.10, 0.08, 0.8)
        love.graphics.setLineWidth(1.5)
        love.graphics.line(cx - eye_offset - eye_r, eye_y - eye_r*1.4,
                           cx - eye_offset + eye_r, eye_y - eye_r*0.9)
        love.graphics.line(cx + eye_offset - eye_r, eye_y - eye_r*0.9,
                           cx + eye_offset + eye_r, eye_y - eye_r*1.4)
        love.graphics.setLineWidth(1)
    elseif expr == "lonely" then
        -- Droopy eyes
        love.graphics.setColor(0.15, 0.10, 0.08)
        love.graphics.ellipse("fill", cx - eye_offset, eye_y + eye_r*0.2, eye_r, eye_r * 0.7)
        love.graphics.ellipse("fill", cx + eye_offset, eye_y + eye_r*0.2, eye_r, eye_r * 0.7)
    else
        -- Default round eyes
        love.graphics.setColor(0.15, 0.10, 0.08)
        love.graphics.circle("fill", cx - eye_offset, eye_y, eye_r)
        love.graphics.circle("fill", cx + eye_offset, eye_y, eye_r)
    end

    -- Blush cheeks (embarrassed / affectionate)
    if expr == "embarrassed" then
        love.graphics.setColor(0.95, 0.50, 0.50, 0.55)
        love.graphics.ellipse("fill", cx - eye_offset, eye_y + eye_r * 1.8, eye_r * 1.5, eye_r * 0.7)
        love.graphics.ellipse("fill", cx + eye_offset, eye_y + eye_r * 1.8, eye_r * 1.5, eye_r * 0.7)
    elseif resident.mood.affection and resident.mood.affection >= 55 then
        love.graphics.setColor(1.0, 0.65, 0.70, 0.35)
        love.graphics.ellipse("fill", cx - eye_offset, eye_y + eye_r * 1.8, eye_r * 1.2, eye_r * 0.5)
        love.graphics.ellipse("fill", cx + eye_offset, eye_y + eye_r * 1.8, eye_r * 1.2, eye_r * 0.5)
    end

    -- Mouth
    local mouth_y = cy + r * 0.35
    local mw      = r * 0.42

    love.graphics.setColor(0.25, 0.12, 0.10, 0.9)
    love.graphics.setLineWidth(1.5)

    if expr == "happy" or expr == "excited" then
        -- Smile arc (drawn as a series of line segments)
        local segs = 10
        for i = 0, segs - 1 do
            local t1 = i / segs
            local t2 = (i + 1) / segs
            local a1 = math.pi * t1
            local a2 = math.pi * t2
            love.graphics.line(
                cx - mw + t1 * mw * 2,  mouth_y + math.sin(a1) * r * 0.18,
                cx - mw + t2 * mw * 2,  mouth_y + math.sin(a2) * r * 0.18
            )
        end
    elseif expr == "angry" then
        -- Scowl (inverted curve)
        local segs = 8
        for i = 0, segs - 1 do
            local t1 = i / segs
            local t2 = (i + 1) / segs
            local a1 = math.pi * t1
            local a2 = math.pi * t2
            love.graphics.line(
                cx - mw + t1 * mw * 2,  mouth_y - math.sin(a1) * r * 0.15,
                cx - mw + t2 * mw * 2,  mouth_y - math.sin(a2) * r * 0.15
            )
        end
    elseif expr == "lonely" or expr == "stressed" then
        -- Slight downward droop
        love.graphics.line(cx - mw * 0.7, mouth_y, cx + mw * 0.7, mouth_y + r * 0.10)
    elseif expr == "embarrassed" then
        -- Small flat-ish open mouth
        love.graphics.ellipse("fill", cx, mouth_y, mw * 0.4, r * 0.10)
    else
        -- Neutral straight line
        love.graphics.line(cx - mw * 0.6, mouth_y, cx + mw * 0.6, mouth_y)
    end

    love.graphics.setLineWidth(1)
end

return ExpressionSystem
