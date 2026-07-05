local utils = require("src.core.utils")

local RelationshipSystem = {}

local function buildDefaultRelationship(a_id, b_id)
    return {
        a = a_id,
        b = b_id,
        a_to_b = {
            familiarity = 0,
            affection = 0,
            trust = 0,
            attraction = 0,
            respect = 0
        },
        b_to_a = {
            familiarity = 0,
            affection = 0,
            trust = 0,
            attraction = 0,
            respect = 0
        },
        tension = 0,
        labels = {
            a_to_b = "Stranger",
            b_to_a = "Stranger"
        }
    }
end

function RelationshipSystem.ensure(world, a_id, b_id)
    local key = RelationshipSystem.getKey(a_id, b_id)
    if not world.relationships[key] then
        world.relationships[key] = buildDefaultRelationship(a_id, b_id)
    else
        local rel = world.relationships[key]
        rel.labels = rel.labels or {}
        rel.labels.a_to_b = rel.labels.a_to_b or "Stranger"
        rel.labels.b_to_a = rel.labels.b_to_a or "Stranger"
    end
    return world.relationships[key]
end

function RelationshipSystem.getKey(a, b)
    local first = a < b and a or b
    local second = a < b and b or a
    return first .. "_" .. second
end

function RelationshipSystem.addAffection(world, from_id, to_id, amount)
    local rel = RelationshipSystem.ensure(world, from_id, to_id)
    local dir = RelationshipSystem.getDirection(rel, from_id)
    dir.affection = utils.clamp(dir.affection + amount, 0, 100)
    dir.familiarity = utils.clamp(dir.familiarity + math.max(1, math.abs(amount)), 0, 100)
    RelationshipSystem.updateLabels(rel)
end

function RelationshipSystem.addTrust(world, from_id, to_id, amount)
    local rel = RelationshipSystem.ensure(world, from_id, to_id)
    local dir = RelationshipSystem.getDirection(rel, from_id)
    dir.trust = utils.clamp(dir.trust + amount, 0, 100)
    dir.familiarity = utils.clamp(dir.familiarity + math.max(1, math.abs(amount)), 0, 100)
    RelationshipSystem.updateLabels(rel)
end

function RelationshipSystem.addTension(world, a_id, b_id, amount)
    local rel = RelationshipSystem.ensure(world, a_id, b_id)
    rel.tension = utils.clamp(rel.tension + amount, 0, 100)
    RelationshipSystem.updateLabels(rel)
end

function RelationshipSystem.getDirection(rel, resident_id)
    if resident_id == rel.a then
        return rel.a_to_b
    end
    return rel.b_to_a
end

function RelationshipSystem.getDirectionalLabel(rel, resident_id)
    if resident_id == rel.a then
        return rel.labels.a_to_b
    end
    return rel.labels.b_to_a
end

function RelationshipSystem.updateLabels(rel)
    local function getDirLabel(dir)
        if rel.tension > 70 and dir.affection < 30 then return "Rival" end
        if dir.affection > 80 and dir.trust > 70 then return "Best Friend" end
        if dir.affection > 50 then return "Friend" end
        if dir.familiarity > 10 then return "Acquaintance" end
        return "Stranger"
    end

    rel.labels = {
        a_to_b = getDirLabel(rel.a_to_b),
        b_to_a = getDirLabel(rel.b_to_a)
    }
end

function RelationshipSystem.refreshAll(world)
    for _, resident in pairs(world.residents) do
        for _, other in pairs(world.residents) do
            if resident.id ~= other.id then
                local rel = RelationshipSystem.ensure(world, resident.id, other.id)
                RelationshipSystem.updateLabels(rel)
            end
        end
    end
end

return RelationshipSystem
