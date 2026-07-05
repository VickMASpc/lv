local class          = require("src.core.class")
local World          = require("src.core.world")
local RenderSystem   = require("src.systems.render_system")

local StateManager = class()

function StateManager:init()
    self.screens = {}
    self.current_screen = nil

    self.world = World.new()
end

function StateManager:addScreen(name, screen_class)
    self.screens[name] = screen_class(self)
end

function StateManager:setWorld(world)
    self.world = World.normalize(world)
    for _, resident in pairs(self.world.residents) do
        RenderSystem.initResident(resident)
    end
end

function StateManager:switch(name, params)
    if self.current_screen and self.current_screen.exit then
        self.current_screen:exit()
    end

    self.current_screen = self.screens[name]
    
    if self.current_screen and self.current_screen.enter then
        self.current_screen:enter(params)
    end
end

function StateManager:update(dt)
    if self.current_screen and self.current_screen.update then
        self.current_screen:update(dt)
    end
end

function StateManager:draw()
    if self.current_screen and self.current_screen.draw then
        self.current_screen:draw()
    end
end

function StateManager:mousepressed(x, y, button)
    if self.current_screen and self.current_screen.mousepressed then
        self.current_screen:mousepressed(x, y, button)
    end
end

return StateManager
