local events_solo = require("src.data.events_solo")
local events_pair = require("src.data.events_pair")
local MemorySystem = require("src.systems.memory_system")
local RelationshipSystem = require("src.systems.relationship_system")
local World = require("src.core.world")

local EventSystem = {}

local EVENT_LOOKUP = {}
for _, event in ipairs(events_solo) do
    EVENT_LOOKUP[event.id] = event
end
for _, event in ipairs(events_pair) do
    EVENT_LOOKUP[event.id] = event
end

local function residentByTarget(participants, target)
    if type(target) == "number" then
        return participants[target]
    end
    if type(target) == "string" then
        for _, resident in ipairs(participants) do
            if resident.id == target then
                return resident
            end
        end
    end
    return nil
end

function EventSystem.getEventData(id)
    return EVENT_LOOKUP[id]
end

function EventSystem.makeDedupeKey(event_id, participants, location)
    local key_parts = { event_id, location }
    local sorted = {}
    for _, participant in ipairs(participants) do
        table.insert(sorted, participant)
    end
    table.sort(sorted)
    for _, participant_id in ipairs(sorted) do
        table.insert(key_parts, participant_id)
    end
    return table.concat(key_parts, ":")
end

local function getCooldownUntil(world, dedupe_key)
    return tonumber(world.event_cooldowns[dedupe_key] or 0) or 0
end

local function isQueued(world, dedupe_key)
    for _, entry in ipairs(world.event_queue) do
        if entry.dedupe_key == dedupe_key then
            return true
        end
    end
    return false
end

local function canQueue(world, event_def, participants, location)
    if #world.event_queue >= World.MAX_QUEUE_SIZE then
        return false
    end

    local dedupe_key = EventSystem.makeDedupeKey(event_def.id, participants, location)
    if isQueued(world, dedupe_key) then
        return false
    end

    local until_tick = getCooldownUntil(world, dedupe_key)
    if until_tick > world.tick then
        return false
    end

    return true
end

function EventSystem.generate(world)
    local possible = {}
    local loc_map = {}

    for _, res in pairs(world.residents) do
        loc_map[res.current_location] = loc_map[res.current_location] or {}
        table.insert(loc_map[res.current_location], res)
    end

    for loc_id, res_list in pairs(loc_map) do
        if #res_list >= 2 then
            for _, evt in ipairs(events_pair) do
                for i = 1, #res_list do
                    for j = i + 1, #res_list do
                        local a, b = res_list[i], res_list[j]
                        if (not evt.preconditions or evt.preconditions(world, a, b))
                            and canQueue(world, evt, { a.id, b.id }, loc_id) then
                            local weight = evt.weight and evt.weight(world, a, b) or 10
                            table.insert(possible, {
                                evt = evt,
                                participants = { a.id, b.id },
                                weight = weight,
                                location = loc_id
                            })
                        end
                    end
                end
            end
        end
    end

    for _, res in pairs(world.residents) do
        for _, evt in ipairs(events_solo) do
            if (not evt.preconditions or evt.preconditions(world, res))
                and canQueue(world, evt, { res.id }, res.current_location) then
                local weight = evt.weight and evt.weight(world, res) or 10
                table.insert(possible, {
                    evt = evt,
                    participants = { res.id },
                    weight = weight,
                    location = res.current_location
                })
            end
        end
    end

    table.sort(possible, function(a, b)
        if a.weight == b.weight then
            return a.evt.priority > b.evt.priority
        end
        return a.weight > b.weight
    end)

    local room_left = World.MAX_QUEUE_SIZE - #world.event_queue
    for i = 1, math.min(room_left, 2, #possible) do
        local candidate = possible[i]
        local dedupe_key = EventSystem.makeDedupeKey(candidate.evt.id, candidate.participants, candidate.location)
        table.insert(world.event_queue, {
            instance_id = world.next_event_instance_id,
            event_id = candidate.evt.id,
            type = candidate.evt.type,
            participants = candidate.participants,
            location = candidate.location,
            priority = candidate.evt.priority or 50,
            dedupe_key = dedupe_key,
            created_day = world.day,
            created_phase = world.phase_index,
        })
        world.next_event_instance_id = world.next_event_instance_id + 1
    end
end

function EventSystem.getResidentsForEntry(world, entry)
    local participants = {}
    for _, resident_id in ipairs(entry.participants or {}) do
        local resident = world.residents[resident_id]
        if resident then
            table.insert(participants, resident)
        end
    end
    return participants
end

function EventSystem.instantiate(world, entry)
    local event_def = EventSystem.getEventData(entry.event_id)
    if not event_def then
        return nil
    end

    local participants = EventSystem.getResidentsForEntry(world, entry)
    local event_data
    if #participants >= 2 then
        event_data = event_def.run(world, participants[1], participants[2])
    else
        event_data = event_def.run(world, participants[1])
    end

    event_data = event_data or {}
    event_data.choices = event_data.choices or {}
    return event_data, participants, event_def
end

function EventSystem.canChoose(world, participants, choice)
    local requirements = choice.requirements or {}
    if requirements.money and world.money < requirements.money then
        return false, "Not enough money for that choice."
    end

    return true, nil
end

local function applyStatEffects(stat_table, entries, participants)
    for _, effect in ipairs(entries or {}) do
        local resident = residentByTarget(participants, effect.target)
        if resident and stat_table(resident)[effect.key] ~= nil then
            local current = stat_table(resident)[effect.key]
            stat_table(resident)[effect.key] = math.max(0, math.min(100, current + effect.delta))
        end
    end
end

local function applyRelationshipEffects(world, entries, participants)
    for _, effect in ipairs(entries or {}) do
        local from_resident = residentByTarget(participants, effect.from)
        local to_resident = residentByTarget(participants, effect.to)
        if from_resident and to_resident then
            if effect.kind == "affection" then
                RelationshipSystem.addAffection(world, from_resident.id, to_resident.id, effect.delta)
            elseif effect.kind == "trust" then
                RelationshipSystem.addTrust(world, from_resident.id, to_resident.id, effect.delta)
            elseif effect.kind == "tension" then
                RelationshipSystem.addTension(world, from_resident.id, to_resident.id, effect.delta)
            end
        end
    end
end

local function applyMemories(world, entries, participants)
    for _, memory in ipairs(entries or {}) do
        local resident = residentByTarget(participants, memory.target)
        if resident then
            MemorySystem.add(world, resident, {
                type = memory.type,
                text = memory.text,
                intensity = memory.intensity,
                tags = memory.tags,
                participants = memory.participants or {},
                location = memory.location,
                decay_rate = memory.decay_rate,
            })
        end
    end
end

local function removeEntry(world, instance_id)
    for index, entry in ipairs(world.event_queue) do
        if entry.instance_id == instance_id then
            table.remove(world.event_queue, index)
            return
        end
    end
end

function EventSystem.resolveChoice(world, entry, choice)
    local event_data, participants, event_def = EventSystem.instantiate(world, entry)
    if not event_data or not event_def then
        removeEntry(world, entry.instance_id)
        return false, "That event is no longer available."
    end

    local ok, reason = EventSystem.canChoose(world, participants, choice)
    if not ok then
        return false, reason
    end

    local effects = choice.effects or {}
    world.money = world.money + (effects.money or 0)
    if world.money < 0 then
        world.money = 0
    end

    applyStatEffects(function(resident) return resident.needs end, effects.needs, participants)
    applyStatEffects(function(resident) return resident.mood end, effects.mood, participants)
    applyRelationshipEffects(world, effects.relationships, participants)
    applyMemories(world, effects.memories, participants)

    if choice.effect then
        choice.effect(world, participants)
    end

    removeEntry(world, entry.instance_id)
    local cooldown = choice.cooldown or event_def.cooldown or 2
    world.event_cooldowns[entry.dedupe_key] = world.tick + cooldown
    return true, choice.success_text or "Choice resolved."
end

function EventSystem.getEntryById(world, instance_id)
    for _, entry in ipairs(world.event_queue) do
        if entry.instance_id == instance_id then
            return entry
        end
    end
    return nil
end

function EventSystem.getEntriesForLocation(world, location_id)
    local entries = {}
    for _, entry in ipairs(world.event_queue) do
        if entry.location == location_id then
            table.insert(entries, entry)
        end
    end
    table.sort(entries, function(a, b)
        if a.priority == b.priority then
            return a.instance_id < b.instance_id
        end
        return a.priority > b.priority
    end)
    return entries
end

return EventSystem
