local locations = require("src.data.locations")

local LocationSystem = {}

function LocationSystem.getById(id)
    for _, loc in ipairs(locations) do
        if loc.id == id then
            return loc
        end
    end
    return nil
end

function LocationSystem.assignActivities(world)
    for _, res in pairs(world.residents) do
        local old_loc = res.current_location

        if world.phase_index == 4 then
            res.current_location = res.home_id
            res.current_activity = "sleeping"
        else
            local roll = math.random(1, 100)

            if res.needs.hunger < 40 then
                res.current_location = "cafe"
                res.current_activity = "eating"
            elseif res.needs.fun < 40 or roll > 72 then
                res.current_location = "park"
                res.current_activity = "socializing"
            else
                res.current_location = res.home_id
                res.current_activity = "resting"
            end
        end

        if old_loc ~= res.current_location then
            print(res.name .. " moved to " .. res.current_location)
        end
    end
end

return LocationSystem
