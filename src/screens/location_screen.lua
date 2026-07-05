local class = require("src.core.class")
local Button = require("src.ui.button")
local Theme = require("src.ui.theme")
local locations = require("src.data.locations")
local EventSystem = require("src.systems.event_system")
local MoodSystem = require("src.systems.mood_system")
local RenderSystem = require("src.systems.render_system")

local LocationScreen = class()

function LocationScreen:init(state_manager)
    self.mgr = state_manager
    self.location_id = nil
    self.location = nil
    self.status_message = ""
    self.status_color = Theme.colors.text_soft
    self.resident_buttons = {}
    self.event_button = Button(560, 500, 220, 40, "Handle Event", function()
        self:openTopEvent()
    end)
    self.back_button = Button(20, 540, 120, 40, "Back to Town", function()
        self.mgr:switch("town")
    end)
end

local function findLocation(location_id)
    for _, loc in ipairs(locations) do
        if loc.id == location_id then
            return loc
        end
    end
    return nil
end

function LocationScreen:refreshButtons()
    self.resident_buttons = {}
    local y = 170
    for _, resident in ipairs(self:getResidentsHere()) do
        local target = resident
        local button = Button(520, y, 240, 36, "View " .. resident.name, function()
            self.mgr:switch("profile", {
                resident = target,
                prev_screen = "location",
                prev_params = { location_id = self.location_id }
            })
        end)
        table.insert(self.resident_buttons, button)
        y = y + 46
    end
end

function LocationScreen:getResidentsHere()
    local residents = {}
    for _, resident in pairs(self.mgr.world.residents) do
        if resident.current_location == self.location_id then
            table.insert(residents, resident)
        end
    end

    table.sort(residents, function(a, b)
        return a.name < b.name
    end)
    return residents
end

function LocationScreen:enter(params)
    self.location_id = params and params.location_id or nil
    self.location = findLocation(self.location_id)
    self.status_message = ""
    self.status_color = Theme.colors.text_soft
    self:refreshButtons()
end

function LocationScreen:getPendingEvents()
    if not self.location_id then
        return {}
    end
    return EventSystem.getEntriesForLocation(self.mgr.world, self.location_id)
end

function LocationScreen:openTopEvent()
    local entries = self:getPendingEvents()
    if #entries == 0 then
        self.status_message = "No pending events are waiting here."
        self.status_color = Theme.colors.text_soft
        return
    end

    self.mgr:switch("event", {
        instance_id = entries[1].instance_id,
        return_screen = "location",
        return_params = { location_id = self.location_id }
    })
end

function LocationScreen:update(dt)
    self.back_button:update(dt)
    self.event_button:setEnabled(#self:getPendingEvents() > 0)
    self.event_button:update(dt)

    for _, button in ipairs(self.resident_buttons) do
        button:update(dt)
    end
end

function LocationScreen:draw()
    love.graphics.clear(0.09, 0.12, 0.18)

    love.graphics.setColor(table.unpack(Theme.colors.panel))
    love.graphics.rectangle("fill", 0, 0, 800, 70)
    love.graphics.setColor(table.unpack(Theme.colors.text))
    love.graphics.setFont(Theme.getFont(24))
    love.graphics.print(self.location and self.location.name or "Location", 24, 20)

    love.graphics.setFont(Theme.getFont(14))
    love.graphics.setColor(table.unpack(Theme.colors.text_soft))
    love.graphics.print("Public space view", 26, 48)

    love.graphics.setColor(0.18, 0.28, 0.38, 0.95)
    love.graphics.rectangle("fill", 20, 90, 460, 470, 12)
    love.graphics.setColor(0.13, 0.17, 0.24, 0.95)
    love.graphics.rectangle("fill", 500, 90, 280, 470, 12)

    local residents = self:getResidentsHere()
    love.graphics.setFont(Theme.getFont(18))
    love.graphics.setColor(table.unpack(Theme.colors.text))
    love.graphics.print("Residents Present", 38, 110)

    if #residents == 0 then
        love.graphics.setFont(Theme.getFont(14))
        love.graphics.setColor(table.unpack(Theme.colors.text_soft))
        love.graphics.print("No residents are here right now.", 38, 145)
    end

    local y = 150
    for _, resident in ipairs(residents) do
        love.graphics.setColor(0.22, 0.26, 0.35, 0.95)
        love.graphics.rectangle("fill", 34, y, 430, 88, 10)
        RenderSystem.drawPortrait(resident, 46, y + 8, 72)
        love.graphics.setColor(table.unpack(Theme.colors.text))
        love.graphics.setFont(Theme.getFont(18))
        love.graphics.print(resident.name, 132, y + 14)
        love.graphics.setFont(Theme.getFont(13))
        love.graphics.setColor(table.unpack(Theme.colors.text_soft))
        love.graphics.print("Activity: " .. (resident.current_activity or "resting"), 132, y + 42)
        love.graphics.print("Mood: " .. select(1, MoodSystem.getPrimaryMood(resident)), 132, y + 62)
        y = y + 100
    end

    love.graphics.setFont(Theme.getFont(18))
    love.graphics.setColor(table.unpack(Theme.colors.text))
    love.graphics.print("Scene Hooks", 520, 110)

    local events = self:getPendingEvents()
    if #events == 0 then
        love.graphics.setFont(Theme.getFont(14))
        love.graphics.setColor(table.unpack(Theme.colors.text_soft))
        love.graphics.printf("No pending social event is waiting here.", 520, 145, 240, "left")
    else
        local top = events[1]
        love.graphics.setFont(Theme.getFont(14))
        love.graphics.setColor(table.unpack(Theme.colors.warning))
        love.graphics.printf("Pending events: " .. tostring(#events), 520, 145, 240, "left")
        love.graphics.setColor(table.unpack(Theme.colors.text_soft))
        love.graphics.printf("Top event: " .. top.event_id, 520, 168, 240, "left")
    end

    for _, button in ipairs(self.resident_buttons) do
        button:draw()
    end
    self.event_button:draw()
    self.back_button:draw()

    if self.status_message ~= "" then
        love.graphics.setFont(Theme.getFont(13))
        love.graphics.setColor(table.unpack(self.status_color))
        love.graphics.printf(self.status_message, 520, 455, 240, "left")
    end
end

function LocationScreen:mousepressed(x, y, button)
    if self.back_button:mousepressed(x, y, button) then return end
    if self.event_button:mousepressed(x, y, button) then return end

    for _, resident_button in ipairs(self.resident_buttons) do
        if resident_button:mousepressed(x, y, button) then
            return
        end
    end
end

return LocationScreen
