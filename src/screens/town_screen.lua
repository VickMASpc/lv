local class        = require("src.core.class")
local locations    = require("src.data.locations")
local Button       = require("src.ui.button")
local Theme        = require("src.ui.theme")
local TimeSystem   = require("src.systems.time_system")
local SaveSystem   = require("src.systems.save_system")
local EventSystem  = require("src.systems.event_system")
local RenderSystem = require("src.systems.render_system")

local TownScreen = class()

local BUILDING_THEMES = {
    residence = { wall = {0.62, 0.52, 0.42}, roof = {0.48, 0.32, 0.24}, window = {0.85, 0.90, 1.0} },
    social    = { wall = {0.38, 0.55, 0.70}, roof = {0.26, 0.40, 0.58}, window = {1.0, 0.95, 0.75} },
    shop      = { wall = {0.70, 0.52, 0.38}, roof = {0.55, 0.35, 0.22}, window = {1.0, 0.90, 0.80} },
}

local THEME_DEFAULT = { wall = {0.55, 0.55, 0.55}, roof = {0.35, 0.35, 0.35}, window = {0.90, 0.90, 1.0} }

local function latestNewsText(world)
    local news_log = world.news_log or {}
    local latest = news_log[#news_log]
    if latest and latest.text then
        return latest.text
    end
    return "Town news is quiet for now."
end

function TownScreen:init(state_manager)
    self.mgr = state_manager
    self.locations = locations
    self.status_message = ""
    self.status_color = Theme.colors.text_soft
    self.stars = {}
    for _ = 1, 45 do
        table.insert(self.stars, {
            x = math.random(0, 800),
            y = math.random(65, 270),
            r = math.random() * 1.3 + 0.4
        })
    end

    self.advance_button = Button(640, 12, 148, 34, "Advance Phase", function()
        TimeSystem.advance(self.mgr.world)
        self.status_message = "The town moves into the next phase."
        self.status_color = Theme.colors.text_soft
    end)
    self.shop_button = Button(480, 12, 148, 34, "Visit Shop", function()
        self.mgr:switch("shop")
    end)
    self.save_button = Button(20, 550, 100, 32, "Save Game", function()
        local ok, message = SaveSystem.save(self.mgr.world)
        self.status_message = message
        self.status_color = ok and Theme.colors.success or Theme.colors.error
    end)
    self.load_button = Button(130, 550, 100, 32, "Load Game", function()
        local loaded, message = SaveSystem.load()
        if loaded then
            self.mgr:setWorld(loaded)
            self.status_color = Theme.colors.success
        else
            self.status_color = Theme.colors.error
        end
        self.status_message = message
    end)
end

local function drawBuilding(loc)
    local theme = BUILDING_THEMES[loc.type] or THEME_DEFAULT
    local x, y, w, h = loc.x, loc.y, loc.width, loc.height

    love.graphics.setColor(0, 0, 0, 0.20)
    love.graphics.ellipse("fill", x + w * 0.5, y + h + 6, w * 0.48, 7)

    local roof_h = h * 0.28
    love.graphics.setColor(table.unpack(theme.roof))
    love.graphics.polygon("fill", x, y, x + w, y, x + w * 0.88, y - roof_h, x + w * 0.12, y - roof_h)

    love.graphics.setColor(table.unpack(theme.wall))
    love.graphics.rectangle("fill", x, y, w, h, 3)
    love.graphics.setColor(1, 1, 1, 0.10)
    love.graphics.rectangle("fill", x, y, 4, h, 2)

    local win_w, win_h = w * 0.18, h * 0.16
    local rows = { y + h * 0.18, y + h * 0.50 }
    local cols = { x + w * 0.22, x + w * 0.62 }
    for _, wy in ipairs(rows) do
        for _, wx in ipairs(cols) do
            love.graphics.setColor(0.2, 0.2, 0.2, 0.6)
            love.graphics.rectangle("fill", wx - 1, wy - 1, win_w + 2, win_h + 2, 2)
            love.graphics.setColor(theme.window[1], theme.window[2], theme.window[3], 0.85)
            love.graphics.rectangle("fill", wx, wy, win_w, win_h, 2)
            love.graphics.setColor(1, 1, 1, 0.30)
            love.graphics.rectangle("fill", wx + 1, wy + 1, win_w * 0.35, win_h * 0.40, 1)
        end
    end

    local door_w = w * 0.20
    local door_h = h * 0.28
    local door_x = x + (w - door_w) * 0.5
    local door_y = y + h - door_h
    love.graphics.setColor(0.22, 0.14, 0.08, 1.0)
    love.graphics.rectangle("fill", door_x, door_y, door_w, door_h, 2)
    love.graphics.setColor(0.70, 0.55, 0.30, 1.0)
    love.graphics.circle("fill", door_x + door_w * 0.78, door_y + door_h * 0.52, 2)

    love.graphics.setColor(0.20, 0.15, 0.10, 0.5)
    love.graphics.setLineWidth(1.2)
    love.graphics.rectangle("line", x, y, w, h, 3)
    love.graphics.setLineWidth(1)
end

local function drawAlert(loc, count)
    local bx = loc.x + loc.width - 4
    local by = loc.y - 12
    love.graphics.setColor(0.95, 0.20, 0.20, 0.92)
    love.graphics.circle("fill", bx, by, 12)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(Theme.getFont(12))
    love.graphics.printf(tostring(count), bx - 8, by - 7, 16, "center")
end

local function drawLabel(loc)
    love.graphics.setFont(Theme.getFont(11))
    love.graphics.setColor(0.10, 0.07, 0.05, 0.65)
    love.graphics.rectangle("fill", loc.x - 2, loc.y + loc.height + 4, loc.width + 4, 16, 3)
    love.graphics.setColor(1, 1, 1, 0.95)
    love.graphics.printf(loc.name, loc.x, loc.y + loc.height + 5, loc.width, "center")
end

local function getResidentSlotPos(loc, slot_index)
    local cols = 3
    local col = (slot_index - 1) % cols
    local row = math.floor((slot_index - 1) / cols)
    local sx = loc.x + loc.width * 0.15 + col * (loc.width * 0.28)
    local sy = loc.y + loc.height * 0.55 + row * 22
    return sx, sy
end

local function drawResidentsInLocation(loc, world)
    local slot = 1
    local sorted = RenderSystem.ySortedResidents(world.residents)
    for _, res in ipairs(sorted) do
        if res.current_location == loc.id then
            local sx, sy = getResidentSlotPos(loc, slot)
            RenderSystem.drawTownDot(res, sx, sy)
            love.graphics.setFont(Theme.getFont(11))
            love.graphics.setColor(0, 0, 0, 0.55)
            love.graphics.rectangle("fill", sx - 18, sy + 14, 36, 13, 2)
            love.graphics.setColor(1, 1, 1, 0.95)
            love.graphics.printf(res.name, sx - 18, sy + 15, 36, "center")
            slot = slot + 1
        end
    end
end

function TownScreen:drawLighting()
    local p = self.mgr.world.phase_index
    if p == 1 then
        love.graphics.setColor(1.0, 0.85, 0.50, 0.13)
    elseif p == 2 then
        return
    elseif p == 3 then
        love.graphics.setColor(0.90, 0.45, 0.15, 0.25)
    elseif p == 4 then
        love.graphics.setColor(0.05, 0.05, 0.35, 0.48)
    end
    love.graphics.rectangle("fill", 0, 0, 800, 600)
end

function TownScreen:drawStars()
    if self.mgr.world.phase_index ~= 4 then return end
    love.graphics.setColor(1, 1, 1, 0.55)
    for _, star in ipairs(self.stars) do
        love.graphics.circle("fill", star.x, star.y, star.r)
    end
end

function TownScreen:update(dt)
    self.advance_button:update(dt)
    self.shop_button:update(dt)
    self.save_button:update(dt)
    self.load_button:update(dt)
end

function TownScreen:draw()
    local p = self.mgr.world.phase_index
    if p == 4 then
        love.graphics.clear(0.04, 0.04, 0.18)
    elseif p == 3 then
        love.graphics.clear(0.20, 0.15, 0.10)
    elseif p == 1 then
        love.graphics.clear(0.55, 0.75, 0.90)
    else
        love.graphics.clear(0.42, 0.72, 0.95)
    end

    love.graphics.setColor(0.22, 0.52, 0.22)
    love.graphics.rectangle("fill", 0, 120, 800, 480)

    love.graphics.setColor(0.18, 0.45, 0.18, 0.5)
    for gy = 140, 580, 30 do
        love.graphics.line(0, gy, 800, gy)
    end

    self:drawStars()

    local sorted_locs = {}
    for _, loc in ipairs(self.locations) do
        table.insert(sorted_locs, loc)
    end
    table.sort(sorted_locs, function(a, b) return a.y < b.y end)

    for _, loc in ipairs(sorted_locs) do
        drawBuilding(loc)
        local events_here = EventSystem.getEntriesForLocation(self.mgr.world, loc.id)
        if #events_here > 0 then
            drawAlert(loc, #events_here)
        end
        drawResidentsInLocation(loc, self.mgr.world)
        drawLabel(loc)
    end

    self:drawLighting()

    love.graphics.setColor(0.08, 0.06, 0.10, 0.82)
    love.graphics.rectangle("fill", 0, 0, 800, 82)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(Theme.getFont(16))
    local phase_name = TimeSystem.getPhaseName(self.mgr.world)
    love.graphics.print("Day " .. self.mgr.world.day .. " | " .. phase_name, 20, 18)
    love.graphics.printf("$" .. self.mgr.world.money, 0, 18, 420, "center")
    love.graphics.printf("Queue: " .. tostring(#self.mgr.world.event_queue), 0, 18, 760, "right")

    if self.status_message ~= "" then
        love.graphics.setFont(Theme.getFont(12))
        love.graphics.setColor(table.unpack(self.status_color))
        love.graphics.printf(self.status_message, 250, 46, 520, "right")
    end

    love.graphics.setFont(Theme.getFont(11))
    love.graphics.setColor(table.unpack(Theme.colors.text_soft))
    love.graphics.printf("News: " .. latestNewsText(self.mgr.world), 20, 62, 760, "left")

    self.advance_button:draw()
    self.shop_button:draw()
    self.save_button:draw()
    self.load_button:draw()
end

function TownScreen:mousepressed(x, y, button)
    if self.advance_button:mousepressed(x, y, button) then return end
    if self.shop_button:mousepressed(x, y, button) then return end
    if self.save_button:mousepressed(x, y, button) then return end
    if self.load_button:mousepressed(x, y, button) then return end

    for _, loc in ipairs(self.locations) do
        if x >= loc.x and x <= loc.x + loc.width and y >= loc.y and y <= loc.y + loc.height then
            if loc.type == "residence" then
                self.mgr:switch("apartment", { location_id = loc.id })
            else
                self.mgr:switch("location", { location_id = loc.id })
            end
            return
        end
    end
end

return TownScreen
