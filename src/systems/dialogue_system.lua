local DialogueSystem = {}

function DialogueSystem.getStyleForResident(res)
    -- Determine dialogue style based on personality traits
    if res.personality.introverted > 70 then return "shy" end
    if res.personality.expressive > 70 then return "dramatic" end
    if res.personality.blunt > 60 then return "blunt" end
    if res.personality.playful > 70 then return "playful" end
    return "default"
end

function DialogueSystem.resolve(template, res, vars)
    local style = DialogueSystem.getStyleForResident(res)
    local line = template[style] or template.default
    
    -- Interpolation
    for k, v in pairs(vars or {}) do
        line = line:gsub("{" .. k .. "}", v)
    end
    
    return line
end

return DialogueSystem
