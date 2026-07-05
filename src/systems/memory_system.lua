local MemorySystem = {}

local function cloneTable(value)
    if type(value) ~= "table" then
        return value
    end

    local copy = {}
    for key, nested in pairs(value) do
        copy[key] = cloneTable(nested)
    end
    return copy
end

function MemorySystem.add(world, resident, memory_data)
    local memory = {
        id = "m" .. tostring(world.next_memory_id),
        type = memory_data.type or "event",
        text = memory_data.text or "Something happened.",
        participants = memory_data.participants or { resident.id },
        intensity = memory_data.intensity or 50,
        day = world.day,
        location = memory_data.location or resident.current_location,
        tags = memory_data.tags or {},
        decay_rate = memory_data.decay_rate or 5,
        metadata = cloneTable(memory_data.metadata or {})
    }

    world.next_memory_id = world.next_memory_id + 1
    table.insert(resident.memories, memory)
    world.memories[memory.id] = memory

    if #resident.memories > 20 then
        local removed = table.remove(resident.memories, 1)
        if removed then
            world.memories[removed.id] = nil
        end
    end

    return memory
end

function MemorySystem.update(world)
    for _, res in pairs(world.residents) do
        for i = #res.memories, 1, -1 do
            local m = res.memories[i]
            m.intensity = m.intensity - m.decay_rate
            if m.intensity <= 0 then
                world.memories[m.id] = nil
                table.remove(res.memories, i)
            end
        end
    end
end

function MemorySystem.hasTag(resident, tag)
    for _, m in ipairs(resident.memories) do
        if m.type == tag then return true end
        for _, memory_tag in ipairs(m.tags or {}) do
            if memory_tag == tag then
                return true
            end
        end
    end
    return false
end

return MemorySystem
