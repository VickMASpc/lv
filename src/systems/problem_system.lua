local EventSystem = require("src.systems.event_system")

local ProblemSystem = {}

function ProblemSystem.update(world)
    for _, res in pairs(world.residents) do
        res.problem_bubble = res.problem_bubble or { active = false }
        
        if not res.problem_bubble.active then
            local is_queued = false
            for _, entry in ipairs(world.event_queue or {}) do
                for _, p_id in ipairs(entry.participants or {}) do
                    if p_id == res.id then
                        is_queued = true
                        break
                    end
                end
                if is_queued then break end
            end
            
            if not is_queued then
                if (res.needs.hunger or 100) <= 30 then
                    if math.random() < 0.5 then
                        res.problem_bubble = {
                            active = true,
                            type = "hungry",
                            created_day = world.day,
                            created_phase = world.phase_index,
                            target_item_tag = "food"
                        }
                    end
                end
            end
        end
    end
end

function ProblemSystem.resolve(world, resident, item)
    if not resident.problem_bubble.active then return false, "No active problem." end
    
    if resident.problem_bubble.type == "hungry" then
        if item.type ~= "food" then
            return false, "That's not food!"
        end
        
        resident.problem_bubble.active = false
        resident.problem_bubble.type = nil
        
        local TasteSystem = require("src.systems.taste_system")
        local HappinessSystem = require("src.systems.happiness_system")
        
        local reaction = TasteSystem.evaluateItem(resident, item)
        TasteSystem.applyReaction(world, resident, reaction)
        
        if reaction.category == "loved" then
            HappinessSystem.addXP(world, resident.id, 50)
            resident.needs.hunger = math.min(100, (resident.needs.hunger or 0) + 80)
            return true, resident.name .. " loved it! The problem is resolved."
        elseif reaction.category == "liked" then
            HappinessSystem.addXP(world, resident.id, 30)
            resident.needs.hunger = math.min(100, (resident.needs.hunger or 0) + 60)
            return true, resident.name .. " liked it! The problem is resolved."
        elseif reaction.category == "disliked" then
            HappinessSystem.addXP(world, resident.id, 5)
            resident.needs.hunger = math.min(100, (resident.needs.hunger or 0) + 30)
            return true, resident.name .. " didn't like it much, but ate it."
        elseif reaction.category == "hated" then
            resident.needs.hunger = math.min(100, (resident.needs.hunger or 0) + 10)
            return true, resident.name .. " hated it!"
        else
            HappinessSystem.addXP(world, resident.id, 15)
            resident.needs.hunger = math.min(100, (resident.needs.hunger or 0) + 40)
            return true, resident.name .. " ate the food. Problem resolved."
        end
    end
    
    return false, "Unknown problem type."
end

return ProblemSystem
