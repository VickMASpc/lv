-- render_system.lua
-- Phase 1: Foundational Visual Identity
--
-- Responsibilities:
--   • Compute and cache a unique personality-derived color per resident
--   • Draw layered procedural character sprites (body → outfit → hair → expression)
--   • Provide a small-scale "town dot" renderer for the map view
--   • Provide a large-scale "portrait" renderer for the apartment/profile view
--   • Y-sort helper for depth-correct rendering on the town map

local utils            = require("src.core.utils")
local ExpressionSystem = require("src.systems.expression_system")

local RenderSystem = {}

-- ---------------------------------------------------------------------------
-- Internal sprite tables: each entry describes how to procedurally draw a
-- body, hair, or outfit layer at the reference scale. Scale 1.0 = town map
-- size (~28px tall). Portrait scale ~3.5 for apartment/profile close-ups.
-- ---------------------------------------------------------------------------

-- Body shapes keyed by `appearance.body`
local BODY_SHAPES = {
    default = function(cx, cy, r, color)
        -- Torso
        love.graphics.setColor(color[1], color[2], color[3], 0.15)
        love.graphics.ellipse("fill", cx, cy + r * 2.6, r * 1.0, r * 1.5)
        -- Head placeholder (face drawn by ExpressionSystem)
        love.graphics.setColor(0.96, 0.84, 0.70, 1.0)
        love.graphics.circle("fill", cx, cy, r)
    end,
    round = function(cx, cy, r, color)
        love.graphics.setColor(color[1], color[2], color[3], 0.15)
        love.graphics.ellipse("fill", cx, cy + r * 2.6, r * 1.15, r * 1.6)
        love.graphics.setColor(0.96, 0.84, 0.70, 1.0)
        love.graphics.circle("fill", cx, cy, r * 1.05)
    end,
    slim = function(cx, cy, r, color)
        love.graphics.setColor(color[1], color[2], color[3], 0.15)
        love.graphics.ellipse("fill", cx, cy + r * 2.6, r * 0.85, r * 1.5)
        love.graphics.setColor(0.96, 0.84, 0.70, 1.0)
        love.graphics.circle("fill", cx, cy, r * 0.95)
    end,
}

-- Outfit layers keyed by `appearance.outfit` — drawn as a colored torso fill
local OUTFIT_COLORS = {
    yellow_hoodie  = { 0.97, 0.85, 0.20 },
    blue_shirt     = { 0.25, 0.50, 0.90 },
    red_dress      = { 0.90, 0.22, 0.28 },
    green_jacket   = { 0.25, 0.72, 0.42 },
    white_blouse   = { 0.95, 0.95, 0.95 },
    black_tshirt   = { 0.15, 0.15, 0.15 },
    purple_sweater = { 0.65, 0.30, 0.85 },
    orange_vest    = { 0.97, 0.58, 0.15 },
}
local OUTFIT_COLOR_DEFAULT = { 0.55, 0.55, 0.60 }

-- Hair styles keyed by `appearance.hair`
-- Each function draws hair relative to the head center (cx, cy - r*0.3 top)
local HAIR_STYLES = {
    bob_black   = function(cx, cy, r)
        love.graphics.setColor(0.10, 0.08, 0.06, 1.0)
        love.graphics.arc("fill", cx, cy, r * 1.08, math.pi + 0.2, 2*math.pi - 0.2)
        love.graphics.ellipse("fill", cx - r*1.02, cy - r*0.1, r*0.18, r*0.55)
        love.graphics.ellipse("fill", cx + r*1.02, cy - r*0.1, r*0.18, r*0.55)
    end,
    short_brown = function(cx, cy, r)
        love.graphics.setColor(0.45, 0.28, 0.12, 1.0)
        love.graphics.arc("fill", cx, cy, r * 1.07, math.pi + 0.4, 2*math.pi - 0.4)
        love.graphics.ellipse("fill", cx, cy - r, r * 1.0, r * 0.55)
    end,
    long_blonde = function(cx, cy, r)
        love.graphics.setColor(0.92, 0.82, 0.32, 1.0)
        love.graphics.arc("fill", cx, cy, r * 1.08, math.pi + 0.1, 2*math.pi - 0.1)
        love.graphics.ellipse("fill", cx, cy - r, r * 1.0, r * 0.6)
        love.graphics.ellipse("fill", cx - r, cy + r, r * 0.25, r * 1.5)
        love.graphics.ellipse("fill", cx + r, cy + r, r * 0.25, r * 1.5)
    end,
    curly_red   = function(cx, cy, r)
        love.graphics.setColor(0.80, 0.25, 0.10, 1.0)
        for i = 0, 7 do
            local angle = (i / 8) * math.pi * 2
            local dx = math.cos(angle) * r * 0.9
            local dy = math.sin(angle) * r * 0.6 - r * 0.3
            love.graphics.circle("fill", cx + dx, cy + dy, r * 0.38)
        end
    end,
    bun_dark    = function(cx, cy, r)
        love.graphics.setColor(0.12, 0.08, 0.06, 1.0)
        love.graphics.arc("fill", cx, cy, r * 1.06, math.pi + 0.3, 2*math.pi - 0.3)
        love.graphics.circle("fill", cx, cy - r * 1.1, r * 0.42)
    end,
    ponytail    = function(cx, cy, r)
        love.graphics.setColor(0.35, 0.20, 0.10, 1.0)
        love.graphics.arc("fill", cx, cy, r * 1.06, math.pi + 0.3, 2*math.pi - 0.3)
        love.graphics.ellipse("fill", cx, cy - r * 0.85, r * 0.9, r * 0.5)
        love.graphics.ellipse("fill", cx + r * 0.9, cy, r * 0.18, r * 0.9)
    end,
}
local function drawHairDefault(cx, cy, r)
    love.graphics.setColor(0.30, 0.22, 0.14, 1.0)
    love.graphics.arc("fill", cx, cy, r * 1.05, math.pi + 0.3, 2*math.pi - 0.3)
    love.graphics.ellipse("fill", cx, cy - r, r * 0.95, r * 0.5)
end

-- ---------------------------------------------------------------------------
-- Color Identity
-- Derives a stable, unique hue from a resident's personality vector.
-- The hue is spread over 0..1 by mixing orthogonal personality poles.
-- Saturation and lightness are further modulated to ensure readable contrast.
-- ---------------------------------------------------------------------------
function RenderSystem.computeColor(resident)
    local p = resident.personality
    if not p then return { 0.7, 0.7, 0.7 } end

    -- Hue: driven by playful vs practical and adventurous vs private
    local h = ((p.playful or 50) * 0.004
             + (p.adventurous or 50) * 0.003
             - (p.practical or 50) * 0.002
             + (p.chaotic or 50) * 0.001) % 1.0

    -- Saturation: extroverted, expressive personalities are more vivid
    local s = 0.42 + ((p.expressive or 50) - 25) * 0.005
    s = utils.clamp(s, 0.30, 0.85)

    -- Lightness: calm, stable = slightly lighter; anxious, moody = slightly darker
    local l = 0.48 + ((p.calm or 50) - 40) * 0.003 - ((p.moody or 50) - 40) * 0.002
    l = utils.clamp(l, 0.32, 0.62)

    local r, g, b = utils.hslToRgb(h, s, l)
    return { r, g, b }
end

-- Call once per resident at game load to cache the color.
function RenderSystem.initResident(resident)
    if not resident.visual_color then
        resident.visual_color = RenderSystem.computeColor(resident)
    end
end

-- ---------------------------------------------------------------------------
-- Outfit drawing helper
-- ---------------------------------------------------------------------------
local function drawOutfit(cx, cy, r, outfit_key)
    local oc = OUTFIT_COLORS[outfit_key] or OUTFIT_COLOR_DEFAULT
    love.graphics.setColor(oc[1], oc[2], oc[3], 1.0)
    -- Torso as a rounded rectangle below the head
    local tw = r * 1.1
    local th = r * 1.5
    local tx = cx - tw
    local ty = cy + r * 0.85
    love.graphics.ellipse("fill", cx, ty + th * 0.5, tw, th * 0.6)
    -- Collar hint
    love.graphics.setColor(oc[1]*0.85, oc[2]*0.85, oc[3]*0.85, 1.0)
    love.graphics.arc("fill", cx, cy + r, r * 0.55, math.pi + 0.5, 2*math.pi - 0.5)
end

-- ---------------------------------------------------------------------------
-- drawResident — full layered character at (cx, cy), head centered there.
-- `head_r` is the radius of the head circle (town: ~11, portrait: ~40).
-- ---------------------------------------------------------------------------
function RenderSystem.drawResident(resident, cx, cy, head_r)
    local app = resident.appearance or {}
    local color = resident.visual_color or { 0.7, 0.7, 0.7 }

    -- 1. Body base
    local body_fn = BODY_SHAPES[app.body] or BODY_SHAPES.default
    body_fn(cx, cy, head_r, color)

    -- 2. Outfit (drawn before hair so hair overlaps collar)
    drawOutfit(cx, cy, head_r, app.outfit)

    -- 3. Hair
    local hair_fn = HAIR_STYLES[app.hair] or drawHairDefault
    hair_fn(cx, cy, head_r)

    -- 4. Expression (face drawn on top of everything)
    ExpressionSystem.draw(resident, cx, cy, head_r)
end

-- ---------------------------------------------------------------------------
-- drawTownDot — compact map representation.
-- A small, recognisable character silhouette + personality-color ring.
-- Replaces the flat yellow circle that was in town_screen.lua.
-- ---------------------------------------------------------------------------
function RenderSystem.drawTownDot(resident, cx, cy)
    local color = resident.visual_color or { 0.9, 0.9, 0.5 }

    -- Personality color halo
    love.graphics.setColor(color[1], color[2], color[3], 0.55)
    love.graphics.circle("fill", cx, cy, 11)
    love.graphics.setColor(color[1], color[2], color[3], 1.0)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", cx, cy, 11)
    love.graphics.setLineWidth(1)

    -- Mini character (head + expression at small scale)
    RenderSystem.drawResident(resident, cx, cy - 2, 7)
end

-- ---------------------------------------------------------------------------
-- drawPortrait — large close-up for apartment and profile screens.
-- Draws within a square region starting at (x, y) with `size` side length.
-- ---------------------------------------------------------------------------
function RenderSystem.drawPortrait(resident, x, y, size)
    local cx = x + size * 0.5
    local cy = y + size * 0.38
    local head_r = size * 0.22

    -- Card background
    local color = resident.visual_color or { 0.5, 0.5, 0.5 }
    love.graphics.setColor(color[1] * 0.18, color[2] * 0.18, color[3] * 0.18, 1.0)
    love.graphics.rectangle("fill", x, y, size, size, 8)

    -- Subtle gradient overlay (2-stop approximation via two rects)
    love.graphics.setColor(color[1], color[2], color[3], 0.12)
    love.graphics.rectangle("fill", x, y, size, size * 0.5, 8)
    love.graphics.setColor(color[1] * 0.4, color[2] * 0.4, color[3] * 0.4, 0.12)
    love.graphics.rectangle("fill", x, y + size * 0.5, size, size * 0.5)

    -- Border ring in personality color
    love.graphics.setColor(color[1], color[2], color[3], 0.80)
    love.graphics.setLineWidth(2.5)
    love.graphics.rectangle("line", x + 1, y + 1, size - 2, size - 2, 8)
    love.graphics.setLineWidth(1)

    -- Ground circle for "standing" feel
    love.graphics.setColor(0, 0, 0, 0.20)
    love.graphics.ellipse("fill", cx, y + size * 0.92, size * 0.30, size * 0.06)

    -- Character
    RenderSystem.drawResident(resident, cx, cy, head_r)
end

-- ---------------------------------------------------------------------------
-- Sorting helper — returns a list of residents sorted by Y position (painter's
-- algorithm: those with smaller Y draw first, appearing "further back").
-- ---------------------------------------------------------------------------
function RenderSystem.ySortedResidents(residents)
    local list = {}
    for _, res in pairs(residents) do
        table.insert(list, res)
    end
    table.sort(list, function(a, b)
        local ay = (a.visual_pos and a.visual_pos.y) or 0
        local by = (b.visual_pos and b.visual_pos.y) or 0
        return ay < by
    end)
    return list
end

return RenderSystem
