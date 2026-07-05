local class = require("src.core.class")
local Button = require("src.ui.button")
local Theme = require("src.ui.theme")
local EventSystem = require("src.systems.event_system")
local RenderSystem = require("src.systems.render_system")

local EventScreen = class()

function EventScreen:init(state_manager)
    self.mgr = state_manager
    self.queue_entry = nil
    self.participants = {}
    self.choice_buttons = {}
    self.title = ""
    self.text = ""
    self.return_screen = "town"
    self.return_params = nil
    self.status_message = ""
    self.status_color = Theme.colors.error
    self.close_button = Button(320, 520, 160, 38, "Return", function()
        self.mgr:switch(self.return_screen, self.return_params)
    end)
end

function EventScreen:enter(params)
    self.return_screen = params.return_screen or "town"
    self.return_params = params.return_params
    self.queue_entry = EventSystem.getEntryById(self.mgr.world, params.instance_id)
    self.choice_buttons = {}
    self.status_message = ""
    self.status_color = Theme.colors.error

    if not self.queue_entry then
        self.title = "Event expired"
        self.text = "That event is no longer in the queue."
        self.participants = {}
        return
    end

    local event_data, participants = EventSystem.instantiate(self.mgr.world, self.queue_entry)
    if not event_data then
        self.title = "Event unavailable"
        self.text = "This event definition could not be loaded."
        self.participants = {}
        return
    end
    self.participants = participants or {}
    self.title = event_data.title or "Event"
    self.text = event_data.text or ""

    local y = 420
    for _, choice in ipairs(event_data.choices or {}) do
        local selected = choice
        local button = Button(180, y, 440, 40, selected.label, function()
            local ok, message = EventSystem.resolveChoice(self.mgr.world, self.queue_entry, selected)
            if ok then
                self.mgr:switch(self.return_screen, self.return_params)
            else
                self.status_message = message
                self.status_color = Theme.colors.error
            end
        end)
        local allowed = EventSystem.canChoose(self.mgr.world, self.participants, selected)
        button:setEnabled(allowed)
        table.insert(self.choice_buttons, button)
        y = y + 50
    end
end

function EventScreen:update(dt)
    self.close_button:update(dt)
    for _, btn in ipairs(self.choice_buttons) do
        btn:update(dt)
    end
end

function EventScreen:draw()
    love.graphics.clear(0.09, 0.11, 0.20)

    love.graphics.setColor(table.unpack(Theme.colors.text))
    love.graphics.setFont(Theme.getFont(24))
    love.graphics.printf(self.title, 0, 50, 800, "center")

    love.graphics.setFont(Theme.getFont(17))
    love.graphics.printf(self.text, 100, 120, 600, "center")

    if #self.participants == 1 then
        RenderSystem.drawPortrait(self.participants[1], 320, 210, 160)
    elseif #self.participants >= 2 then
        RenderSystem.drawPortrait(self.participants[1], 160, 210, 150)
        RenderSystem.drawPortrait(self.participants[2], 490, 210, 150)
    end

    for _, btn in ipairs(self.choice_buttons) do
        btn:draw()
    end

    if #self.choice_buttons == 0 then
        self.close_button:draw()
    end

    if self.status_message ~= "" then
        love.graphics.setFont(Theme.getFont(13))
        love.graphics.setColor(table.unpack(self.status_color))
        love.graphics.printf(self.status_message, 180, 580, 440, "center")
    end
end

function EventScreen:mousepressed(x, y, button)
    if self.close_button:mousepressed(x, y, button) then return end
    for _, btn in ipairs(self.choice_buttons) do
        if btn:mousepressed(x, y, button) then return end
    end
end

return EventScreen
