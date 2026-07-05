local utils = require("src.core.utils")
local MemorySystem = require("src.systems.memory_system")

local TasteSystem = {}

local NEWS_CAP = 20

local REACTION_DATA = {
    love = {
        score = 2,
        xp = 30,
        mood = { happiness = 15, affection = 10, confidence = 5, stress = -5 },
        label = "loved",
    },
    like = {
        score = 1,
        xp = 18,
        mood = { happiness = 8, affection = 5, confidence = 2 },
        label = "liked",
    },
    neutral = {
        score = 0,
        xp = 8,
        mood = { happiness = 2 },
        label = "felt neutral about",
    },
    dislike = {
        score = -1,
        xp = 3,
        mood = { happiness = -6, stress = 8 },
        label = "disliked",
    },
    hate = {
        score = -2,
        xp = 0,
        mood = { happiness = -12, stress = 15, anger = 10 },
        label = "hated",
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

local function getReactionFromScore(score)
    if score >= 60 then return "love" end
    if score >= 20 then return "like" end
    if score > -20 then return "neutral" end
    if score > -60 then return "dislike" end
    return "hate"
end

local function getLevelThreshold(level)
    return 100 + ((level - 1) * 25)
end

local function addStatChange(result, bucket, key, delta)
    result.stat_changes[bucket][key] = (result.stat_changes[bucket][key] or 0) + delta
end

local function applyStatTable(result, resident, bucket, changes)
    local target = resident[bucket]
    for key, delta in pairs(changes or {}) do
        if target and target[key] ~= nil then
            target[key] = utils.clamp(target[key] + delta, 0, 100)
            addStatChange(result, bucket, key, delta)
        end
    end
end

local function addNewsEntry(world, resident, entry_type, text, result)
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
    table.insert(result.news_entries, entry)
end

local function addMemory(world, resident, memory_data, result)
    local memory = MemorySystem.add(world, resident, memory_data)
    table.insert(result.memories, memory)
    return memory
end

local function chooseDiscoveryTag(resident, item)
    local best_tag
    local best_score = -1
    for _, tag in ipairs(item.taste_tags or {}) do
        if resident.known_preferences.tags[tag] == nil then
            local score = math.abs((resident.taste_profile.tags or {})[tag] or 0)
            if score > best_score then
                best_score = score
                best_tag = tag
            end
        end
    end
    return best_tag
end

function TasteSystem.getReactionForItem(resident, item)
    local item_score = resident.taste_profile.items and resident.taste_profile.items[item.id]
    if item_score ~= nil then
        return getReactionFromScore(item_score), item_score, "item"
    end

    local total = 0
    local count = 0
    for _, tag in ipairs(item.taste_tags or {}) do
        total = total + ((resident.taste_profile.tags or {})[tag] or 0)
        count = count + 1
    end

    if count == 0 then
        return "neutral", 0, "default"
    end

    local score = total / count
    return getReactionFromScore(score), score, "tags"
end

function TasteSystem.getKnownReactionForItem(resident, item)
    local known_item = resident.known_preferences.items[item.id]
    if known_item then
        return known_item
    end

    local total = 0
    local count = 0
    for _, tag in ipairs(item.taste_tags or {}) do
        local known_tag = resident.known_preferences.tags[tag]
        if known_tag then
            total = total + REACTION_DATA[known_tag].score
            count = count + 1
        end
    end

    if count == 0 then
        return nil
    end

    local average = total / count
    if average >= 1.5 then return "love" end
    if average >= 0.5 then return "like" end
    if average > -0.5 then return "neutral" end
    if average > -1.5 then return "dislike" end
    return "hate"
end

function TasteSystem.getKnownPreferenceSummary(resident)
    local summary = {
        likes = {},
        dislikes = {},
        items = {},
    }

    for item_id, reaction in pairs(resident.known_preferences.items or {}) do
        table.insert(summary.items, item_id .. " (" .. reaction .. ")")
    end
    table.sort(summary.items)

    for tag, reaction in pairs(resident.known_preferences.tags or {}) do
        if reaction == "love" or reaction == "like" then
            table.insert(summary.likes, tag)
        elseif reaction == "hate" or reaction == "dislike" then
            table.insert(summary.dislikes, tag)
        end
    end

    table.sort(summary.likes)
    table.sort(summary.dislikes)
    return summary
end

function TasteSystem.getLevelThreshold(level)
    return getLevelThreshold(level)
end

function TasteSystem.resolveGift(world, resident, item)
    local reaction, score, source = TasteSystem.getReactionForItem(resident, item)
    local reaction_data = REACTION_DATA[reaction]
    local result = {
        reaction = reaction,
        stat_changes = {
            needs = {},
            mood = {},
        },
        xp_gained = reaction_data.xp,
        leveled_up = false,
        new_level = resident.progression.happiness_level,
        discovered_tag = nil,
        discovered_item = nil,
        memories = {},
        news_entries = {},
        message = "",
        score = score,
        source = source,
    }

    applyStatTable(result, resident, "needs", item.effects or {})
    applyStatTable(result, resident, "mood", item.effects or {})
    applyStatTable(result, resident, "mood", reaction_data.mood)

    resident.progression.happiness_xp = resident.progression.happiness_xp + reaction_data.xp
    while resident.progression.happiness_xp >= getLevelThreshold(resident.progression.happiness_level) do
        resident.progression.happiness_xp = resident.progression.happiness_xp - getLevelThreshold(resident.progression.happiness_level)
        resident.progression.happiness_level = resident.progression.happiness_level + 1
        result.leveled_up = true
    end
    result.new_level = resident.progression.happiness_level

    if source == "item" and resident.known_preferences.items[item.id] == nil then
        resident.known_preferences.items[item.id] = reaction
        result.discovered_item = item.id
    elseif source == "tags" then
        local discovered_tag = chooseDiscoveryTag(resident, item)
        if discovered_tag then
            local discovered_reaction = getReactionFromScore((resident.taste_profile.tags or {})[discovered_tag] or 0)
            resident.known_preferences.tags[discovered_tag] = discovered_reaction
            result.discovered_tag = discovered_tag
        end
    end

    if reaction == "love" or reaction == "dislike" or reaction == "hate" then
        addMemory(world, resident, {
            type = "gift_reaction",
            text = resident.name .. " " .. reaction_data.label .. " the " .. item.name .. ".",
            intensity = 70,
            tags = { "gift", reaction },
            decay_rate = 4,
            metadata = {
                item_id = item.id,
                reaction = reaction,
                source = source,
            }
        }, result)
    end

    if result.discovered_item then
        addMemory(world, resident, {
            type = "taste_discovery",
            text = "You learned that " .. resident.name .. " " .. reaction_data.label .. " " .. item.name .. ".",
            intensity = 60,
            tags = { "gift", "discovery", "item" },
            decay_rate = 3,
            metadata = {
                item_id = item.id,
                reaction = reaction,
            }
        }, result)
    elseif result.discovered_tag then
        addMemory(world, resident, {
            type = "taste_discovery",
            text = "You learned that " .. resident.name .. " feels " .. resident.known_preferences.tags[result.discovered_tag] .. " about " .. result.discovered_tag .. " gifts.",
            intensity = 55,
            tags = { "gift", "discovery", result.discovered_tag },
            decay_rate = 3,
            metadata = {
                tag = result.discovered_tag,
                reaction = resident.known_preferences.tags[result.discovered_tag],
            }
        }, result)
    end

    if result.leveled_up then
        addMemory(world, resident, {
            type = "level_up",
            text = resident.name .. " reached Happiness Level " .. resident.progression.happiness_level .. ".",
            intensity = 85,
            tags = { "progression", "level_up" },
            decay_rate = 2,
            metadata = {
                level = resident.progression.happiness_level,
                xp_gained = reaction_data.xp,
            }
        }, result)
        addNewsEntry(world, resident, "level_up", resident.name .. " reached Happiness Level " .. resident.progression.happiness_level .. ".", result)
    end

    if reaction == "love" or reaction == "hate" then
        addNewsEntry(world, resident, "gift_reaction", resident.name .. " " .. reaction_data.label .. " the " .. item.name .. ".", result)
    end

    result.message = resident.name .. " " .. reaction_data.label .. " the " .. item.name .. ". +" .. tostring(result.xp_gained) .. " XP."
    if result.leveled_up then
        result.message = result.message .. " Level " .. tostring(result.new_level) .. " reached."
    end

    return result
end

return TasteSystem
