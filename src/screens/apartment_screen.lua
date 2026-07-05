local class        = require("src.core.class")
local Button       = require("src.ui.button")
local Theme        = require("src.ui.theme")
local RenderSystem = require("src.systems.render_system")
local MoodSystem   = require("src.systems.mood_system")
local EventSystem  = require("src.systems.event_system")
local TasteSystem  = require("src.systems.taste_system")
local HappinessSystem = require("src.systems.happiness_system")
local ProblemSystem = require("src.systems.problem_system")
local item_data     = require("src.data.items")

local ApartmentScreen = class()

local ACTIVITY_LABELS = {
    reading = "Reading",
    cooking = "Cooking",
    eating = "Eating",
    sleeping = "Sleeping",
    working = "Working",
    socializing = "Socializing",
    gaming = "Gaming",
    exercising = "Exercising",
    resting = "Resting",
    exploring = "Exploring",
}

local function getItem(id)
    for _, item in ipairs(item_data) do
        if item.id == id then return item end
    end
    return nil
end

local function needColor(v)
    if v >= 60 then return 0.30, 0.82, 0.45 end
    if v >= 30 then return 0.95, 0.78, 0.20 end
    return 0.92, 0.28, 0.28
end

function ApartmentScreen:init(state_manager)
    self.mgr = state_manager
    self.location_id = nil
    self.resident = nil
    self.status_message = ""
    self.status_color = Theme.colors.text_soft

    self.back_button = Button(10, 550, 110, 40, "Back to Town", function()
        self.mgr:switch("town")
    end)
    self.profile_button = Button(130, 550, 160, 40, "View Profile", function()
        if self.resident then
            self.mgr:switch("profile", {
                resident = self.resident,
                prev_screen = "apartment",
                prev_params = { location_id = self.location_id }
            })
        end
    end)
    self.event_button = Button(300, 550, 180, 40, "Handle Home Event", function()
        self:openTopEvent()
    end)
    self.gift_buttons = {}
    self.problem_buttons = {}
    self.problem_deferred = false
end

function ApartmentScreen:getResidentForLocation()
    for _, res in pairs(self.mgr.world.residents) do
        if res.home_id == self.location_id then
            return res
        end
    end
    return nil
end

function ApartmentScreen:getPendingEvents()
    return EventSystem.getEntriesForLocation(self.mgr.world, self.location_id)
end

function ApartmentScreen:enter(params)
    self.location_id = params and params.location_id or "unknown"
    self.resident = self:getResidentForLocation()
    self.status_message = ""
    self.status_color = Theme.colors.text_soft

    self.gift_buttons = {}
    self.problem_buttons = {}
    self.problem_deferred = false
    local gy = 120

    for i, item_id in ipairs(self.mgr.world.inventory) do
        local itm = getItem(item_id)
        if itm then
            local item_index = i
            local label = "Give " .. itm.name
            if self.resident then
                local known_reaction = TasteSystem.getKnownReactionForItem(self.resident, itm)
                if known_reaction then
                    label = label .. " (" .. known_reaction .. ")"
                end
            end
            local button = Button(570, gy, 210, 28, label, function()
                self:giveItem(item_index, itm)
            end)
            table.insert(self.gift_buttons, button)
            gy = gy + 34
        end
        if gy > 490 then break end
    end

    local problem = self.resident and self.resident.problem_bubble
    local is_active = problem and (problem.active or problem.status == "active")
    if is_active and problem.type == "need_food" then
        local py = 350
        for i, item_id in ipairs(self.mgr.world.inventory) do
            local item = getItem(item_id)
            if item and item.category == "food" then
                local item_index = i
                local button = Button(285, py, 230, 28, "Give " .. item.name, function()
                    self:resolveFoodProblem(item_index, item)
                end)
                table.insert(self.problem_buttons, button)
                py = py + 34
            end
        end

        if #self.problem_buttons == 0 then
            py = 390
        end

        self.maybe_later_button = Button(285, py, 230, 28, "Maybe later", function()
            self.problem_deferred = true
            self.status_message = "The request is still waiting."
            self.status_color = Theme.colors.text_soft
        end)
    else
        self.maybe_later_button = nil
    end
end

function ApartmentScreen:openTopEvent()
    local events = self:getPendingEvents()
    if #events == 0 then
        self.status_message = "Nothing urgent is waiting at home."
        self.status_color = Theme.colors.text_soft
        return
    end

    self.mgr:switch("event", {
        instance_id = events[1].instance_id,
        return_screen = "apartment",
        return_params = { location_id = self.location_id }
    })
end

function ApartmentScreen:giveItem(index, item)
    if not self.resident then return end
    if not item then
        self.status_message = "That item could not be found."
        self.status_color = Theme.colors.warning
        return
    end

    local result = HappinessSystem.applyGift(self.mgr.world, self.resident, item)

    table.remove(self.mgr.world.inventory, index)
    self:enter({ location_id = self.location_id })
    self.status_message = result.message

    if result.reaction == "disliked" or result.reaction == "hated" then
        self.status_color = Theme.colors.warning
    else
        self.status_color = Theme.colors.success
    end
end

function ApartmentScreen:resolveFoodProblem(index, item)
    if not self.resident or not item then return end

    local result = ProblemSystem.resolveFoodProblem(self.mgr.world, self.resident, item)
    if result.ok then
        table.remove(self.mgr.world.inventory, index)
        self:enter({ location_id = self.location_id })
        self.status_message = result.message
        self.status_color = Theme.colors.success
    else
        self.status_message = result.message
        self.status_color = Theme.colors.warning
    end
end

function ApartmentScreen:update(dt)
    self.back_button:update(dt)
    self.profile_button:setEnabled(self.resident ~= nil)
    self.profile_button:update(dt)
    self.event_button:setEnabled(#self:getPendingEvents() > 0)
    self.event_button:update(dt)

    for _, btn in ipairs(self.gift_buttons) do
        btn:update(dt)
    end
    if not self.problem_deferred then
        for _, btn in ipairs(self.problem_buttons) do
            btn:update(dt)
        end
        if self.maybe_later_button then
            self.maybe_later_button:update(dt)
        end
    end
end

local function drawRoom(color)
    love.graphics.setColor(color[1] * 0.28, color[2] * 0.28, color[3] * 0.28, 1.0)
    love.graphics.rectangle("fill", 30, 60, 520, 480)

    love.graphics.setColor(0.45, 0.32, 0.22, 1.0)
    love.graphics.rectangle("fill", 30, 460, 520, 80)

    love.graphics.setColor(0.40, 0.28, 0.18, 0.7)
    for fx = 30, 550, 35 do
        love.graphics.line(fx, 460, fx, 540)
    end

    love.graphics.setColor(0.60, 0.48, 0.35, 1.0)
    love.graphics.rectangle("fill", 30, 456, 520, 6)

    love.graphics.setColor(0.50, 0.65, 0.85, 0.35)
    love.graphics.rectangle("fill", 80, 100, 120, 140, 4)
    love.graphics.setColor(0.70, 0.85, 1.0, 0.55)
    love.graphics.rectangle("fill", 82, 102, 55, 65, 2)
    love.graphics.setColor(0.40, 0.35, 0.30, 0.8)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", 80, 100, 120, 140, 4)
    love.graphics.setLineWidth(1)

    love.graphics.setColor(color[1], color[2], color[3], 0.08)
    love.graphics.rectangle("fill", 30, 60, 520, 480)
end

local function drawNeedBar(x, y, w, h, label, value)
    local r, g, b = needColor(value)
    love.graphics.setColor(0.15, 0.15, 0.20, 0.80)
    love.graphics.rectangle("fill", x, y, w, h, 3)
    love.graphics.setColor(r, g, b, 0.85)
    love.graphics.rectangle("fill", x, y, (value / 100) * w, h, 3)
    love.graphics.setColor(1, 1, 1, 0.15)
    love.graphics.rectangle("line", x, y, w, h, 3)
    love.graphics.setFont(Theme.getFont(11))
    love.graphics.setColor(0.85, 0.85, 0.85, 1.0)
    love.graphics.print(label, x + w + 6, y + 1)
end

function ApartmentScreen:draw()
    love.graphics.clear(0.10, 0.09, 0.14)

    local res = self.resident
    local color = (res and res.visual_color) or { 0.45, 0.45, 0.50 }
    drawRoom(color)

    if res then
        local px, py, psize = 280, 90, 160
        RenderSystem.drawPortrait(res, px, py, psize)
        love.graphics.setFont(Theme.getFont(12))
        love.graphics.setColor(color[1], color[2], color[3], 0.85)
        local act_label = ACTIVITY_LABELS[res.current_activity] or (res.current_activity or "Resting")
        love.graphics.printf(act_label, px, py + psize + 6, psize, "center")
    end

    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle("fill", 0, 0, 800, 58)

    if res then
        love.graphics.setFont(Theme.getFont(22))
        love.graphics.setColor(table.unpack(color))
        love.graphics.print(res.name, 20, 14)

        love.graphics.setFont(Theme.getFont(13))
        love.graphics.setColor(table.unpack(Theme.colors.text_soft))
        love.graphics.print("Current location: " .. (res.current_location or "?"), 220, 18)
        love.graphics.print("Home: " .. self.location_id, 220, 36)

        local primary_mood = MoodSystem.getPrimaryMood(res)
        local resident_level = res.level or (res.progression and res.progression.happiness_level) or 1
        love.graphics.setColor(color[1], color[2], color[3], 0.25)
        love.graphics.rectangle("fill", 580, 14, 140, 28, 6)
        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.printf("Mood: " .. primary_mood, 580, 20, 140, "center")
        love.graphics.setColor(table.unpack(Theme.colors.level_up))
        love.graphics.printf("Lv " .. tostring(resident_level), 725, 20, 55, "right")
    else
        love.graphics.setFont(Theme.getFont(22))
        love.graphics.setColor(0.70, 0.70, 0.75)
        love.graphics.print("Empty Apartment", 20, 14)
    end
    
    local problem = res and res.problem_bubble
    local problem_active = problem and (problem.active or problem.status == "active")
    if problem_active and not self.problem_deferred then
        love.graphics.setColor(0.10, 0.09, 0.14, 0.88)
        love.graphics.rectangle("fill", 265, 270, 275, 220, 8)
        love.graphics.setFont(Theme.getFont(14))
        love.graphics.setColor(table.unpack(Theme.colors.warning))
        if problem.type == "need_food" then
            love.graphics.printf(problem.prompt or "I'm hungry. Could you give me something to eat?", 280, 292, 245, "center")
            for _, btn in ipairs(self.problem_buttons) do btn:draw() end
            if #self.problem_buttons == 0 then
                love.graphics.setFont(Theme.getFont(11))
                love.graphics.setColor(table.unpack(Theme.colors.text_soft))
                love.graphics.printf("You do not have any food items.", 280, 350, 245, "center")
            end
            if self.maybe_later_button then self.maybe_later_button:draw() end
        else
            love.graphics.printf(problem.prompt or (res.name .. " has a problem!"), 280, 292, 245, "center")
        end
    end

    if res then
        love.graphics.setFont(Theme.getFont(13))
        love.graphics.setColor(1, 1, 1, 0.55)
        love.graphics.print("NEEDS", 30, 68)

        local ny = 88
        for key, value in pairs(res.needs or {}) do
            drawNeedBar(30, ny, 120, 10, key, value)
            ny = ny + 22
            if ny > 460 then break end
        end

        if res.current_location ~= self.location_id then
            love.graphics.setFont(Theme.getFont(12))
            love.graphics.setColor(table.unpack(Theme.colors.warning))
            love.graphics.printf(res.name .. " is out right now, but you can still plan from home.", 280, 275, 230, "center")
        end
    end

    love.graphics.setFont(Theme.getFont(13))
    love.graphics.setColor(1, 1, 1, 0.55)
    love.graphics.print("INVENTORY", 570, 96)

    for _, btn in ipairs(self.gift_buttons) do btn:draw() end

    if #self.gift_buttons == 0 then
        love.graphics.setFont(Theme.getFont(11))
        love.graphics.setColor(0.55, 0.55, 0.60)
        love.graphics.print("No items available. Visit the shop.", 570, 120)
    end

    if self.status_message ~= "" then
        love.graphics.setFont(Theme.getFont(12))
        love.graphics.setColor(table.unpack(self.status_color))
        love.graphics.printf(self.status_message, 560, 500, 220, "left")
    end

    self.back_button:draw()
    self.profile_button:draw()
    self.event_button:draw()
end

function ApartmentScreen:mousepressed(x, y, button)
    if self.back_button:mousepressed(x, y, button) then return end
    if self.profile_button:mousepressed(x, y, button) then return end
    if self.event_button:mousepressed(x, y, button) then return end

    for _, btn in ipairs(self.gift_buttons) do
        if btn:mousepressed(x, y, button) then return end
    end
    if not self.problem_deferred then
        for _, btn in ipairs(self.problem_buttons) do
            if btn:mousepressed(x, y, button) then return end
        end
        if self.maybe_later_button and self.maybe_later_button:mousepressed(x, y, button) then return end
    end
end

return ApartmentScreen
