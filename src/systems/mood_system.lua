local MoodSystem = {}

function MoodSystem.getPrimaryMood(resident)
    local highest_mood = "neutral"
    local highest_val = 0
    
    for k, v in pairs(resident.mood) do
        if v > highest_val then
            highest_val = v
            highest_mood = k
        end
    end
    
    return highest_mood, highest_val
end

function MoodSystem.update(world)
    for _, res in pairs(world.residents) do
        if res.needs.hunger < 20 then
            res.mood.happiness = math.max(0, res.mood.happiness - 10)
            res.mood.stress = math.min(100, res.mood.stress + 10)
        end

        if res.needs.fun < 25 then
            res.mood.loneliness = math.min(100, res.mood.loneliness + 6)
            res.mood.happiness = math.max(0, res.mood.happiness - 4)
        elseif res.needs.fun > 80 then
            res.mood.happiness = math.min(100, res.mood.happiness + 5)
        end

        if res.needs.affection < 30 then
            res.mood.loneliness = math.min(100, res.mood.loneliness + 5)
        end

        if res.needs.comfort < 25 then
            res.mood.stress = math.min(100, res.mood.stress + 4)
        end

        res.mood.stress = math.max(0, res.mood.stress - 2)
        res.mood.excitement = math.max(0, res.mood.excitement - 1)
    end
end

return MoodSystem
