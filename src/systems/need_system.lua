local NeedSystem = {}

function NeedSystem.getPriority(resident)
    local lowest_need = nil
    local lowest_val = 101
    
    for k, v in pairs(resident.needs) do
        if v < lowest_val then
            lowest_val = v
            lowest_need = k
        end
    end
    
    return lowest_need, lowest_val
end

function NeedSystem.update(world)
    for _, res in pairs(world.residents) do
        if res.needs.hunger ~= nil then
            res.needs.hunger = math.max(0, res.needs.hunger - 10)
        end
        res.needs.energy = math.max(0, res.needs.energy - 5)
        res.needs.fun = math.max(0, res.needs.fun - 8)
        res.needs.comfort = math.max(0, res.needs.comfort - 4)
        res.needs.affection = math.max(0, res.needs.affection - 3)

        if world.phase_index == 4 then
            res.needs.energy = math.min(100, res.needs.energy + 40)
            res.needs.comfort = math.min(100, res.needs.comfort + 12)
        end
    end
end

return NeedSystem
