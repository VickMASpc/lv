local class = require("src.core.class")
local Button = require("src.ui.button")
local Theme = require("src.ui.theme")
local items = require("src.data.items")

local ShopScreen = class()

function ShopScreen:init(state_manager)
    self.mgr = state_manager
    self.item_buttons = {}
    self.status_message = ""
    self.status_color = Theme.colors.text_soft
    self.back_button = Button(10, 550, 120, 40, "Back to Town", function()
        self.mgr:switch("town")
    end)

    local y = 100
    for _, item in ipairs(items) do
        local selected = item
        local btn = Button(50, y, 700, 50, item.name .. " ($" .. item.cost .. ") - " .. item.description, function()
            if self.mgr.world.money >= selected.cost then
                self.mgr.world.money = self.mgr.world.money - selected.cost
                table.insert(self.mgr.world.inventory, selected.id)
                self.status_message = "Bought " .. selected.name .. "."
                self.status_color = Theme.colors.success
            else
                self.status_message = "Not enough money for " .. selected.name .. "."
                self.status_color = Theme.colors.error
            end
        end)
        table.insert(self.item_buttons, btn)
        y = y + 60
    end
end

function ShopScreen:update(dt)
    self.back_button:update(dt)
    for _, btn in ipairs(self.item_buttons) do
        btn:update(dt)
    end
end

function ShopScreen:draw()
    love.graphics.clear(0.15, 0.15, 0.25)

    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(Theme.getFont(24))
    love.graphics.printf("Town General Store", 0, 30, 800, "center")

    love.graphics.setFont(Theme.getFont(16))
    love.graphics.print("Funds: $" .. self.mgr.world.money, 50, 70)

    for _, btn in ipairs(self.item_buttons) do
        btn:draw()
    end

    if self.status_message ~= "" then
        love.graphics.setFont(Theme.getFont(13))
        love.graphics.setColor(table.unpack(self.status_color))
        love.graphics.printf(self.status_message, 50, 500, 700, "center")
    end

    self.back_button:draw()
end

function ShopScreen:mousepressed(x, y, button)
    if self.back_button:mousepressed(x, y, button) then return end
    for _, btn in ipairs(self.item_buttons) do
        if btn:mousepressed(x, y, button) then return end
    end
end

return ShopScreen
