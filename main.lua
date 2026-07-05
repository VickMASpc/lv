local StateManager = require("src.core.state")
local TownScreen = require("src.screens.town_screen")
local ApartmentScreen = require("src.screens.apartment_screen")
local LocationScreen = require("src.screens.location_screen")
local ProfileScreen = require("src.screens.profile_screen")
local EventScreen = require("src.screens.event_screen")
local ShopScreen = require("src.screens.shop_screen")

local game

function love.load()
    math.randomseed(os.time())
    game = StateManager()

    game:addScreen("town", TownScreen)
    game:addScreen("apartment", ApartmentScreen)
    game:addScreen("location", LocationScreen)
    game:addScreen("profile", ProfileScreen)
    game:addScreen("event", EventScreen)
    game:addScreen("shop", ShopScreen)

    game:switch("town")
end

function love.update(dt)
    game:update(dt)
end

function love.draw()
    game:draw()
end

function love.mousepressed(x, y, button)
    game:mousepressed(x, y, button)
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    end
end
