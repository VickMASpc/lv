local class              = require("src.core.class")
local Button             = require("src.ui.button")
local Theme              = require("src.ui.theme")
local RelationshipSystem = require("src.systems.relationship_system")
local RenderSystem       = require("src.systems.render_system")
local item_data          = require("src.data.items")

local ProfileScreen = class()

local MAX_KNOWN_TASTES = 6

local function buildItemNameMap()
    local by_id = {}
    for _, item in ipairs(item_data) do
        by_id[item.id] = item.name
    end
    return by_id
end

local ITEM_NAMES = buildItemNameMap()

local function getProgression(resident)
    local progression = resident.progression or {}
    local level = tonumber(resident.level) or tonumber(progression.happiness_level) or 1
    local xp = tonumber(resident.happiness_xp) or tonumber(progression.happiness_xp) or 0
    return level, xp
end

local function getKnownTastes(resident)
    local discovered = resident.discovered_preferences or {}
    local known_tastes = {}

    for item_id, reaction in pairs(discovered) do
        table.insert(known_tastes, {
            item_name = ITEM_NAMES[item_id] or item_id,
            reaction = reaction,
        })
    end

    table.sort(known_tastes, function(a, b)
        return a.item_name < b.item_name
    end)

    return known_tastes
end

function ProfileScreen:init(state_manager)
    self.mgr = state_manager
    self.resident = nil
    self.prev_screen = "town"
    self.prev_params = nil
    self.tab = "status"

    self.back_button = Button(10, 550, 100, 40, "Back", function()
        self.mgr:switch(self.prev_screen or "town", self.prev_params)
    end)

    self.status_tab_btn = Button(50, 100, 100, 30, "Status", function() self.tab = "status" end)
    self.rel_tab_btn = Button(160, 100, 120, 30, "Relationships", function() self.tab = "relationships" end)
    self.mem_tab_btn = Button(290, 100, 120, 30, "Memories", function() self.tab = "memories" end)
end

function ProfileScreen:enter(params)
    self.resident = params.resident
    self.prev_screen = params.prev_screen
    self.prev_params = params.prev_params
    self.tab = "status"
end

function ProfileScreen:update(dt)
    self.back_button:update(dt)
    self.status_tab_btn:update(dt)
    self.rel_tab_btn:update(dt)
    self.mem_tab_btn:update(dt)
end

function ProfileScreen:draw()
    love.graphics.clear(0.10, 0.09, 0.14)
    if not self.resident then return end

    local res = self.resident
    local color = res.visual_color or { 0.5, 0.5, 0.6 }

    love.graphics.setColor(color[1] * 0.22, color[2] * 0.22, color[3] * 0.22, 1.0)
    love.graphics.rectangle("fill", 0, 0, 800, 90)
    love.graphics.setColor(color[1], color[2], color[3], 0.70)
    love.graphics.rectangle("fill", 0, 88, 800, 2)

    RenderSystem.drawPortrait(res, 8, 4, 80)

    love.graphics.setFont(Theme.getFont(28))
    love.graphics.setColor(1, 1, 1, 1.0)
    love.graphics.print(res.name, 98, 16)

    love.graphics.setFont(Theme.getFont(13))
    love.graphics.setColor(math.min(1, color[1] + 0.3), math.min(1, color[2] + 0.3), math.min(1, color[3] + 0.3), 0.9)
    love.graphics.print(res.pronouns .. " | " .. res.age_category, 100, 52)

    self.status_tab_btn:draw()
    self.rel_tab_btn:draw()
    self.mem_tab_btn:draw()

    love.graphics.setColor(1, 1, 1)
    if self.tab == "status" then
        self:drawStatus()
    elseif self.tab == "relationships" then
        self:drawRelationships()
    else
        self:drawMemories()
    end

    self.back_button:draw()
end

function ProfileScreen:drawStatus()
    local level, xp = getProgression(self.resident)
    local threshold = 100
    local known_tastes = getKnownTastes(self.resident)

    love.graphics.setFont(Theme.getFont(16))
    love.graphics.print("Current Activity: " .. (self.resident.current_activity or "resting"), 50, 150)
    love.graphics.print("Level: " .. level, 50, 176)

    love.graphics.setFont(Theme.getFont(12))
    love.graphics.setColor(0.6, 0.6, 0.6)
    love.graphics.rectangle("line", 50, 202, 180, 15)
    love.graphics.setColor(table.unpack(Theme.colors.level_up))
    love.graphics.rectangle("fill", 50, 202, math.min(1, xp / threshold) * 180, 15)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Happiness: " .. xp .. " / " .. threshold, 240, 200)

    love.graphics.setFont(Theme.getFont(16))
    love.graphics.print("Needs", 50, 232)
    love.graphics.setFont(Theme.getFont(12))
    local y = 262
    for key, value in pairs(self.resident.needs or {}) do
        love.graphics.setColor(0.6, 0.6, 0.6)
        love.graphics.rectangle("line", 50, y, 150, 15)
        love.graphics.setColor(0.4, 0.8, 0.4)
        love.graphics.rectangle("fill", 50, y, (value / 100) * 150, 15)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(key, 210, y)
        y = y + 25
        if y > 500 then break end
    end

    love.graphics.setFont(Theme.getFont(16))
    love.graphics.print("Mood", 450, 150)
    love.graphics.setFont(Theme.getFont(12))
    y = 180
    for key, value in pairs(self.resident.mood or {}) do
        love.graphics.print(key .. ": " .. value .. "%", 450, y)
        y = y + 20
    end

    love.graphics.setFont(Theme.getFont(16))
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Known Tastes", 450, 360)
    love.graphics.setFont(Theme.getFont(12))

    if #known_tastes == 0 then
        love.graphics.setColor(table.unpack(Theme.colors.text_soft))
        love.graphics.printf("No known tastes yet. Try giving gifts.", 450, 388, 300, "left")
    else
        y = 388
        for i = 1, math.min(#known_tastes, MAX_KNOWN_TASTES) do
            local taste = known_tastes[i]
            local reaction_color = Theme.colors.text_soft
            if taste.reaction == "loved" or taste.reaction == "liked" then
                reaction_color = Theme.colors.success
            elseif taste.reaction == "neutral" then
                reaction_color = Theme.colors.accent
            elseif taste.reaction == "disliked" or taste.reaction == "hated" then
                reaction_color = Theme.colors.warning
            end

            love.graphics.setColor(1, 1, 1)
            love.graphics.print(taste.item_name, 450, y)
            love.graphics.setColor(table.unpack(reaction_color))
            love.graphics.print(taste.reaction, 620, y)
            y = y + 22
        end
    end

    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Quirks: " .. table.concat(self.resident.quirks or {}, ", "), 450, 460)
    love.graphics.print("Likes: " .. table.concat(self.resident.likes or {}, ", "), 450, 490)
end

function ProfileScreen:drawRelationships()
    love.graphics.setFont(Theme.getFont(16))
    love.graphics.print("Relationships", 50, 150)
    love.graphics.setFont(Theme.getFont(12))

    local y = 180
    local found = false
    for _, other in pairs(self.mgr.world.residents) do
        if other.id ~= self.resident.id then
            local rel = RelationshipSystem.ensure(self.mgr.world, self.resident.id, other.id)
            local dir = RelationshipSystem.getDirection(rel, self.resident.id)
            local label = RelationshipSystem.getDirectionalLabel(rel, self.resident.id)

            love.graphics.setColor(0.2, 0.2, 0.3)
            love.graphics.rectangle("fill", 50, y, 700, 40, 5)
            love.graphics.setColor(1, 1, 1)
            love.graphics.print(other.name .. " (" .. label .. ")", 70, y + 12)
            love.graphics.print("Affection: " .. dir.affection .. " | Trust: " .. dir.trust .. " | Tension: " .. rel.tension, 330, y + 12)
            y = y + 50
            found = true
        end
    end

    if not found then
        love.graphics.print("No relationships recorded yet.", 50, 180)
    end
end

function ProfileScreen:drawMemories()
    love.graphics.setFont(Theme.getFont(16))
    love.graphics.print("Memories", 50, 150)
    love.graphics.setFont(Theme.getFont(12))

    local y = 180
    if #self.resident.memories == 0 then
        love.graphics.print("No memories yet. The story has only just begun.", 50, 180)
        return
    end

    for i = #self.resident.memories, 1, -1 do
        local memory = self.resident.memories[i]
        love.graphics.setColor(0.2, 0.25, 0.35)
        love.graphics.rectangle("fill", 50, y, 700, 46, 5)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("Day " .. memory.day .. ": " .. memory.text, 70, y + 10)
        love.graphics.print("Intensity: " .. memory.intensity, 600, y + 10)
        if memory.type == "gift_reaction" or memory.type == "taste_discovery" then
            love.graphics.setColor(table.unpack(Theme.colors.accent))
            love.graphics.print("Gift", 540, y + 10)
            love.graphics.setColor(1, 1, 1)
        elseif memory.type == "level_up" then
            love.graphics.setColor(table.unpack(Theme.colors.level_up))
            love.graphics.print("Level Up", 520, y + 10)
            love.graphics.setColor(1, 1, 1)
        end
        if memory.tags and #memory.tags > 0 then
            love.graphics.setColor(table.unpack(Theme.colors.text_soft))
            love.graphics.print("Tags: " .. table.concat(memory.tags, ", "), 70, y + 26)
        end
        y = y + 56
        if y > 500 then break end
    end
end

function ProfileScreen:mousepressed(x, y, button)
    if self.back_button:mousepressed(x, y, button) then return end
    if self.status_tab_btn:mousepressed(x, y, button) then return end
    if self.rel_tab_btn:mousepressed(x, y, button) then return end
    if self.mem_tab_btn:mousepressed(x, y, button) then return end
end

return ProfileScreen
