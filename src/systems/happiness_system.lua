local MemorySystem = require("src.systems.memory_system")

local HappinessSystem = {}

local NEWS_CAP = 20

local REACTIONS = {
    loved = {
        xp = 35,
        label = "loved",
        positive = true,
    },
    liked = {
        xp = 18,
        label = "liked",
        positive = true,
    },
    neutral = {
        xp = 8,
        label = "felt neutral about",
        positive = true,
    },
    disliked = {
        xp = 2,
        label = "disliked",
        positive = false,
    },
    hated = {
        xp = -8,
        label = "hated",
        positive = false,
    },
}

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

local function clamp(value)
    if value < 0 then return 0 end
    if value > 100 then return 100 end
    return value
end

local function ensureProgression(resident)
    resident.progression = resident.progression or {}
    resident.happiness_xp = tonumber(resident.happiness_xp) or tonumber(resident.progression.happiness_xp) or 0
    resident.level = tonumber(resident.level) or tonumber(resident.progression.happiness_level) or 1
    resident.progression.happiness_xp = resident.happiness_xp
    resident.progression.happiness_level = resident.level
end

local function ensurePreferences(resident)
    resident.preferences = resident.preferences or {}
    resident.preferences.loved = resident.preferences.loved or {}
    resident.preferences.liked = resident.preferences.liked or {}
    resident.preferences.disliked = resident.preferences.disliked or {}
    resident.preferences.hated = resident.preferences.hated or {}
    resident.discovered_preferences = resident.discovered_preferences or {}
end

local function hasItem(bucket, item_id)
    for _, candidate in ipairs(bucket or {}) do
        if candidate == item_id then
            return true
        end
    end
    return false
end

local function addMemory(world, resident, memory_data, result)
    if type(MemorySystem.add) == "function" then
        local memory = MemorySystem.add(world, resident, memory_data)
        if result then
            result.memories = result.memories or {}
            table.insert(result.memories, memory)
        end
        return memory
    end

    local memory = {
        type = memory_data.type or "event",
        text = memory_data.text or "Something happened.",
        participants = cloneTable(memory_data.participants or { resident.id }),
        intensity = memory_data.intensity or 50,
        day = world.day,
        location = memory_data.location or resident.current_location,
        tags = cloneTable(memory_data.tags or {}),
        decay_rate = memory_data.decay_rate or 5,
        metadata = cloneTable(memory_data.metadata or {})
    }
    resident.memories = resident.memories or {}
    table.insert(resident.memories, memory)
    if result then
        result.memories = result.memories or {}
        table.insert(result.memories, memory)
    end
    return memory
end

local function addNews(world, resident, entry_type, text, result)
    world.news_feed = world.news_feed or {}
    world.next_news_id = tonumber(world.next_news_id) or 1

    local entry = {
        id = "n" .. tostring(world.next_news_id),
        day = world.day,
        resident_id = resident.id,
        type = entry_type,
        text = text,
    }

    world.next_news_id = world.next_news_id + 1
    table.insert(world.news_feed, entry)
    if #world.news_feed > NEWS_CAP then
        table.remove(world.news_feed, 1)
    end

    if result then
        result.news_entries = result.news_entries or {}
        table.insert(result.news_entries, entry)
    end

    return entry
end

local function applyEffectsToBucket(resident, bucket_name, effects)
    local bucket = resident[bucket_name]
    if type(bucket) ~= "table" then
        return
    end

    for key, delta in pairs(effects or {}) do
        if bucket[key] ~= nil then
            bucket[key] = clamp(bucket[key] + delta)
        end
    end
end

function HappinessSystem.getReaction(resident, item)
    ensurePreferences(resident)

    if hasItem(resident.preferences.loved, item.id) then
        return "loved"
    end
    if hasItem(resident.preferences.liked, item.id) then
        return "liked"
    end
    if hasItem(resident.preferences.hated, item.id) then
        return "hated"
    end
    if hasItem(resident.preferences.disliked, item.id) then
        return "disliked"
    end

    return "neutral"
end

function HappinessSystem.addXP(world, resident, amount)
    ensureProgression(resident)
    resident.happiness_xp = resident.happiness_xp + amount
    resident.progression.happiness_xp = resident.happiness_xp
    return resident.happiness_xp
end

function HappinessSystem.levelUpIfNeeded(world, resident)
    ensureProgression(resident)

    local leveled_up = false
    local levels_gained = 0

    while resident.happiness_xp >= 100 do
        resident.happiness_xp = resident.happiness_xp - 100
        resident.level = resident.level + 1
        leveled_up = true
        levels_gained = levels_gained + 1
    end

    resident.progression.happiness_xp = resident.happiness_xp
    resident.progression.happiness_level = resident.level

    return leveled_up, levels_gained
end

function HappinessSystem.applyGift(world, resident, item)
    ensureProgression(resident)
    ensurePreferences(resident)

    local reaction = HappinessSystem.getReaction(resident, item)
    local reaction_data = REACTIONS[reaction]
    local first_discovery = resident.discovered_preferences[item.id] == nil
    local previous_level = resident.level

    applyEffectsToBucket(resident, "needs", item.effects)
    applyEffectsToBucket(resident, "mood", item.effects)

    if first_discovery then
        resident.discovered_preferences[item.id] = reaction
    end

    HappinessSystem.addXP(world, resident, reaction_data.xp)
    local leveled_up, levels_gained = HappinessSystem.levelUpIfNeeded(world, resident)

    local result = {
        message = resident.name .. " " .. reaction_data.label .. " the " .. item.name .. ". "
            .. (reaction_data.xp >= 0 and "+" or "") .. tostring(reaction_data.xp) .. " happiness XP.",
        reaction = reaction,
        xp_delta = reaction_data.xp,
        leveled_up = leveled_up,
        positive = reaction_data.positive,
        memories = {},
        news_entries = {},
    }

    if first_discovery then
        addMemory(world, resident, {
            type = "preference_discovery",
            text = "You discovered that " .. resident.name .. " " .. reaction_data.label .. " " .. item.name .. ".",
            intensity = 60,
            tags = { "gift", "discovery", reaction },
            decay_rate = 3,
            metadata = {
                item_id = item.id,
                reaction = reaction,
            }
        }, result)
        addNews(world, resident, "preference_discovery", "You discovered that " .. resident.name .. " " .. reaction_data.label .. " " .. item.name .. ".", result)
    end

    if reaction == "loved" then
        addMemory(world, resident, {
            type = "gift_reaction",
            text = resident.name .. " loved the " .. item.name .. ".",
            intensity = 75,
            tags = { "gift", "loved" },
            decay_rate = 4,
            metadata = {
                item_id = item.id,
                reaction = reaction,
            }
        }, result)
        addNews(world, resident, "gift_reaction", resident.name .. " loved the " .. item.name .. ".", result)
    elseif reaction == "hated" then
        addMemory(world, resident, {
            type = "gift_reaction",
            text = resident.name .. " hated the " .. item.name .. ".",
            intensity = 80,
            tags = { "gift", "hated" },
            decay_rate = 4,
            metadata = {
                item_id = item.id,
                reaction = reaction,
            }
        }, result)
        addNews(world, resident, "gift_reaction", resident.name .. " hated the " .. item.name .. ".", result)
    end

    if leveled_up then
        addMemory(world, resident, {
            type = "level_up",
            text = resident.name .. " reached Happiness Level " .. resident.level .. ".",
            intensity = 85,
            tags = { "progression", "level_up" },
            decay_rate = 2,
            metadata = {
                previous_level = previous_level,
                new_level = resident.level,
                levels_gained = levels_gained,
                xp_delta = reaction_data.xp,
            }
        }, result)
        addNews(world, resident, "level_up", resident.name .. " reached Happiness Level " .. resident.level .. ".", result)
        result.message = result.message .. " Level " .. tostring(resident.level) .. " reached."
    end

    return result
end

return HappinessSystem
