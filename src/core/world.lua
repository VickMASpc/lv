local residents_data = require("src.data.residents")
local RenderSystem = require("src.systems.render_system")

local World = {}

World.SAVE_VERSION = 3
World.DEFAULT_PHASE_INDEX = 1
World.DEFAULT_MONEY = 100
World.MAX_QUEUE_SIZE = 5

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

local function normalizePreferenceBuckets(preferences)
    local normalized = cloneTable(preferences or {})
    normalized.loved = normalized.loved or {}
    normalized.liked = normalized.liked or {}
    normalized.disliked = normalized.disliked or {}
    normalized.hated = normalized.hated or {}
    return normalized
end

local function normalizeResident(raw)
    local resident = cloneTable(raw)
    resident.memories = resident.memories or {}
    resident.flags = resident.flags or {}
    resident.taste_profile = resident.taste_profile or {}
    resident.taste_profile.tags = resident.taste_profile.tags or {}
    resident.taste_profile.items = resident.taste_profile.items or {}
    resident.known_preferences = resident.known_preferences or {}
    resident.known_preferences.tags = resident.known_preferences.tags or {}
    resident.known_preferences.items = resident.known_preferences.items or {}
    resident.progression = resident.progression or {}
    local progression_xp = tonumber(resident.progression.happiness_xp)
    local progression_level = tonumber(resident.progression.happiness_level)
    resident.happiness_xp = tonumber(resident.happiness_xp)
    resident.level = tonumber(resident.level)
    resident.happiness_xp = resident.happiness_xp or progression_xp or 0
    resident.level = resident.level or progression_level or 1
    resident.progression.happiness_xp = resident.happiness_xp
    resident.progression.happiness_level = resident.level
    resident.preferences = normalizePreferenceBuckets(resident.preferences)
    resident.discovered_preferences = resident.discovered_preferences or {}
    resident.current_location = resident.current_location or resident.home_id
    resident.current_activity = resident.current_activity or "resting"
    RenderSystem.initResident(resident)
    return resident
end

local function buildResidentMap(source)
    local residents = {}
    for _, resident in ipairs(source) do
        local normalized = normalizeResident(resident)
        residents[normalized.id] = normalized
    end
    return residents
end

local function normalizeQueueEntry(entry)
    return {
        instance_id = entry.instance_id,
        event_id = entry.event_id,
        participants = cloneTable(entry.participants or {}),
        location = entry.location,
        priority = entry.priority or 0,
        dedupe_key = entry.dedupe_key,
        created_day = entry.created_day or 1,
        created_phase = entry.created_phase or World.DEFAULT_PHASE_INDEX,
    }
end

function World.new()
    return {
        version = World.SAVE_VERSION,
        day = 1,
        phase_index = World.DEFAULT_PHASE_INDEX,
        tick = 0,
        money = World.DEFAULT_MONEY,
        residents = buildResidentMap(residents_data),
        relationships = {},
        memories = {},
        inventory = {},
        unlocked_locations = {
            apt_01 = true,
            apt_02 = true,
            cafe = true,
            park = true,
        },
        event_queue = {},
        event_cooldowns = {},
        next_event_instance_id = 1,
        next_memory_id = 1,
        news_feed = {},
        next_news_id = 1,
    }
end

function World.normalize(loaded_world)
    local world = loaded_world or {}
    world.version = World.SAVE_VERSION
    world.day = tonumber(world.day) or 1
    world.phase_index = tonumber(world.phase_index) or World.DEFAULT_PHASE_INDEX
    world.tick = tonumber(world.tick) or 0
    world.money = tonumber(world.money) or World.DEFAULT_MONEY
    world.relationships = world.relationships or {}
    world.memories = world.memories or {}
    world.inventory = world.inventory or {}
    world.unlocked_locations = world.unlocked_locations or {}
    world.event_cooldowns = world.event_cooldowns or {}
    world.next_event_instance_id = tonumber(world.next_event_instance_id) or 1
    world.next_memory_id = tonumber(world.next_memory_id) or 1
    world.news_feed = world.news_feed or {}
    world.next_news_id = tonumber(world.next_news_id) or 1

    local residents_source = {}
    if world.residents then
        if #world.residents > 0 then
            residents_source = world.residents
        else
            for _, resident in pairs(world.residents) do
                table.insert(residents_source, resident)
            end
        end
    else
        residents_source = residents_data
    end
    world.residents = buildResidentMap(residents_source)

    local queue = {}
    for _, entry in ipairs(world.event_queue or {}) do
        if entry.event_id and entry.location then
            table.insert(queue, normalizeQueueEntry(entry))
        end
    end
    world.event_queue = queue

    return world
end

function World.serialize(world)
    local save = {
        version = World.SAVE_VERSION,
        day = world.day,
        phase_index = world.phase_index,
        tick = world.tick,
        money = world.money,
        residents = {},
        relationships = world.relationships,
        memories = world.memories,
        inventory = world.inventory,
        unlocked_locations = world.unlocked_locations,
        event_queue = {},
        event_cooldowns = world.event_cooldowns,
        next_event_instance_id = world.next_event_instance_id,
        next_memory_id = world.next_memory_id,
        news_feed = cloneTable(world.news_feed),
        next_news_id = world.next_news_id,
    }

    for _, resident in pairs(world.residents) do
        local serialized = cloneTable(resident)
        serialized.visual_color = nil
        table.insert(save.residents, serialized)
    end

    table.sort(save.residents, function(a, b)
        return a.id < b.id
    end)

    for _, entry in ipairs(world.event_queue) do
        table.insert(save.event_queue, normalizeQueueEntry(entry))
    end

    return save
end

return World
