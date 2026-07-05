local class = require("src.core.class")
local Theme = require("src.ui.theme")

local Button = class()

function Button:init(x, y, w, h, text, callback)
    self.x = x
    self.y = y
    self.w = w
    self.h = h
    self.text = text
    self.callback = callback
    self.hovered = false
    self.enabled = true
end

function Button:update(dt)
    local mx, my = love.mouse.getPosition()
    self.hovered = self.enabled and
                   mx >= self.x and mx <= self.x + self.w and
                   my >= self.y and my <= self.y + self.h
end

function Button:setText(text)
    self.text = text
end

function Button:setEnabled(enabled)
    self.enabled = enabled
    if not enabled then
        self.hovered = false
    end
end

function Button:draw()
    if not self.enabled then
        love.graphics.setColor(table.unpack(Theme.colors.button_disabled))
    elseif self.hovered then
        love.graphics.setColor(table.unpack(Theme.colors.button_hover))
    else
        love.graphics.setColor(table.unpack(Theme.colors.button))
    end

    love.graphics.rectangle("fill", self.x, self.y, self.w, self.h, 5)

    love.graphics.setColor(table.unpack(Theme.colors.text))
    love.graphics.setFont(Theme.getFont(13))
    love.graphics.printf(self.text, self.x + 6, self.y + self.h / 2 - 8, self.w - 12, "center")
end

function Button:mousepressed(x, y, button)
    if self.enabled and self.hovered and button == 1 then
        if self.callback then
            self.callback()
        end
        return true
    end
    return false
end

return Button
