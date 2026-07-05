local MemorySystem = require("src.systems.memory_system")

local HappinessSystem = {}

local NEWS_CAP = 20

local REACTIONS = {
    loved = { xp = 35, positive = true },
    liked = { xp = 18, positive = true },
    neutral = { xp = 8, positive = true },
    disliked = { xp = 2, positive = false },
    hated = { xp = -8, positive = false },
}

local DISCOVERY_PHRASES = {
    loved = "loves",
    liked = "likes",
    neutral = "feels neutral about",
    disliked = "dislikes",
    hated = "hates",
}

local DEFAULT_NAME = "Someone"
local DEFAULT_ITEM_NAME = "that gift"

local MESSAGE_TEMPLATES = {
    default = {
        loved = {
            "{name} loved {item}.",
            "{name} lit up over {item}.",
        },
        liked = {
            "{name} liked {item}.",
            "{name} seemed happy with {item}.",
        },
        neutral = {
            "{name} took {item} calmly.",
            "{name} accepted {item} without much fuss.",
        },
        disliked = {
            "{name} disliked {item}.",
            "{name} made a face at {item}.",
        },
        hated = {
            "{name} hated {item}.",
            "{name} recoiled from {item}.",
        },
        level_up = {
            " Level {level}!",
            " Now level {level}.",
        },
    },
    playful = {
        loved = {
            "{name} treated {item} like treasure.",
            "{name} got weirdly giddy over {item}.",
        },
        liked = {
            "{name} perked right up at {item}.",
            "{name} looked delighted by {item}.",
        },
        neutral = {
            "{name} poked at {item} with polite curiosity.",
            "{name} made {item} into a tiny moment.",
        },
        disliked = {
            "{name} gave {item} a dramatic side-eye.",
            "{name} acted like {item} told a bad joke.",
        },
        hated = {
            "{name} treated {item} like a cursed prop.",
            "{name} looked personally offended by {item}.",
        },
        level_up = {
            " Tiny victory dance. Level {level}!",
            " Level {level}, somehow.",
        },
    },
    blunt = {
        loved = {
            "{name} loved {item}. No debate.",
            "{name} called {item} a good choice.",
        },
        liked = {
            "{name} approved of {item}.",
            "{name} said {item} was decent.",
        },
        neutral = {
            "{name} had no strong opinion on {item}.",
            "{name} called {item} fine.",
        },
        disliked = {
            "{name} said {item} was a miss.",
            "{name} did not enjoy {item}.",
        },
        hated = {
            "{name} said {item} was awful.",
            "{name} rejected {item} immediately.",
        },
        level_up = {
            " Level {level}. Moving on.",
            " Level {level}, apparently.",
        },
    },
    anxious = {
        loved = {
            "{name} loved {item} and overthought it instantly.",
            "{name} clutched {item} like it might vanish.",
        },
        liked = {
            "{name} liked {item}, maybe too much.",
            "{name} seemed relieved by {item}.",
        },
        neutral = {
            "{name} accepted {item} very carefully.",
            "{name} looked unsure, but kept {item}.",
        },
        disliked = {
            "{name} worried {item} was a bad sign.",
            "{name} tensed up at {item}.",
        },
        hated = {
            "{name} looked alarmed by {item}.",
            "{name} reacted to {item} like a tiny crisis.",
        },
        level_up = {
            " Level {level}... somehow okay.",
            " Level {level}, after much internal panic.",
        },
    },
    practical = {
        loved = {
            "{name} appreciated {item} immediately.",
            "{name} found {item} genuinely useful.",
        },
        liked = {
            "{name} approved of {item}.",
            "{name} gave {item} a satisfied nod.",
        },
        neutral = {
            "{name} accepted {item} without comment.",
            "{name} filed {item} under acceptable.",
        },
        disliked = {
            "{name} found {item} impractical.",
            "{name} was not sold on {item}.",
        },
        hated = {
            "{name} dismissed {item} outright.",
            "{name} looked unimpressed by {item}.",
        },
        level_up = {
            " Level {level}. Efficient.",
            " Level {level}, neatly done.",
        },
    },
}

local CATEGORY_OVERRIDES = {
    food = {
        loved = "{name} looked ready to defend {item} with their life.",
        hated = "{name} stared at {item} like lunch had betrayed them.",
    },
    drink = {
        loved = "{name} took one look at {item} and softened.",
        neutral = "{name} sipped {item} without ceremony.",
    },
    toy = {
        loved = "{name} locked onto {item} immediately.",
        disliked = "{name} looked tired just seeing {item}.",
    },
    decoration = {
        loved = "{name} brightened at the sight of {item}.",
        hated = "{name} looked haunted by {item}.",
    },
    gift = {
        loved = "{name} treated {item} like a perfect gesture.",
        disliked = "{name} did not connect with {item}.",
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

local function ensureWorld(world)
    world = world or {}
    world.day = tonumber(world.day) or 1
    world.phase_index = tonumber(world.phase_index) or 1
    world.memories = world.memories or {}
    world.next_memory_id = tonumber(world.next_memory_id) or 1
    world.news_log = world.news_log or {}
    return world
end

local function ensureResident(resident)
    resident = resident or {}
    resident.name = resident.name or DEFAULT_NAME
    resident.progression = resident.progression or {}
    resident.happiness_xp = tonumber(resident.happiness_xp) or tonumber(resident.progression.happiness_xp) or 0
    resident.level = tonumber(resident.level) or tonumber(resident.progression.happiness_level) or 1
    resident.progression.happiness_xp = resident.happiness_xp
    resident.progression.happiness_level = resident.level
    resident.preferences = resident.preferences or {}
    resident.preferences.loved = resident.preferences.loved or {}
    resident.preferences.liked = resident.preferences.liked or {}
    resident.preferences.disliked = resident.preferences.disliked or {}
    resident.preferences.hated = resident.preferences.hated or {}
    resident.discovered_preferences = resident.discovered_preferences or {}
    resident.memories = resident.memories or {}
    resident.personality = resident.personality or {}
    return resident
end

local function ensureItem(item)
    item = item or {}
    item.id = item.id or "unknown_item"
    item.name = item.name or DEFAULT_ITEM_NAME
    item.effects = item.effects or {}
    return item
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

    table.insert(resident.memories, memory)
    if result then
        result.memories = result.memories or {}
        table.insert(result.memories, memory)
    end
    return memory
end

local function addNewsLogEntry(world, text, result)
    local entry = {
        day = world.day,
        phase_index = world.phase_index,
        text = text,
    }

    table.insert(world.news_log, entry)
    while #world.news_log > NEWS_CAP do
        table.remove(world.news_log, 1)
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
            bucket[key] = clamp((bucket[key] or 0) + delta)
        end
    end
end

local function pickTone(resident)
    local personality = resident.personality or {}
    if (personality.playful or 0) >= 70 then
        return "playful"
    end
    if (personality.blunt or 0) >= 70 then
        return "blunt"
    end
    if (personality.anxious or 0) >= 70 then
        return "anxious"
    end
    if (personality.practical or 0) >= 70 then
        return "practical"
    end
    return "default"
end

local function pickTemplate(templates, resident, item, reaction, level)
    local category_templates = CATEGORY_OVERRIDES[item.category or ""]
    local template

    if category_templates and category_templates[reaction] then
        template = category_templates[reaction]
    end

    if not template then
        local tone = pickTone(resident)
        local tone_templates = templates[tone] or templates.default
        local candidates = tone_templates[reaction] or templates.default[reaction] or {}
        if #candidates == 0 then
            candidates = templates.default[reaction] or {}
        end

        if #candidates > 0 then
            local seed = #resident.name + #item.name + resident.level + level
            local index = (seed % #candidates) + 1
            template = candidates[index]
        end
    end

    template = template or "{name} reacted to {item}."
    template = template:gsub("{name}", resident.name)
    template = template:gsub("{item}", item.name)
    template = template:gsub("{level}", tostring(level))
    return template
end

local function buildMessage(resident, item, reaction, xp_delta, leveled_up, level)
    local base = pickTemplate(MESSAGE_TEMPLATES, resident, item, reaction, level)
    local xp_text = (xp_delta >= 0 and "+" or "") .. tostring(xp_delta) .. " happiness XP."
    local message = base .. " " .. xp_text

    if leveled_up then
        local suffix = pickTemplate(MESSAGE_TEMPLATES, resident, item, "level_up", level)
        message = message .. suffix
    end

    return message
end

function HappinessSystem.getReaction(resident, item)
    resident = ensureResident(resident)
    item = ensureItem(item)

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
    ensureWorld(world)
    resident = ensureResident(resident)
    resident.happiness_xp = resident.happiness_xp + amount
    resident.progression.happiness_xp = resident.happiness_xp
    return resident.happiness_xp
end

function HappinessSystem.levelUpIfNeeded(world, resident)
    ensureWorld(world)
    resident = ensureResident(resident)

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
    world = ensureWorld(world)
    resident = ensureResident(resident)
    item = ensureItem(item)

    local reaction = HappinessSystem.getReaction(resident, item)
    local reaction_data = REACTIONS[reaction] or REACTIONS.neutral
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
        message = "",
        reaction = reaction,
        xp_delta = reaction_data.xp,
        leveled_up = leveled_up,
        positive = reaction_data.positive,
        memories = {},
        news_entries = {},
    }

    result.message = buildMessage(resident, item, reaction, result.xp_delta, leveled_up, resident.level)

    if first_discovery then
        local discovery_phrase = DISCOVERY_PHRASES[reaction] or "reacts to"
        addMemory(world, resident, {
            type = "preference_discovery",
            text = "You discovered that " .. resident.name .. " " .. discovery_phrase .. " " .. item.name .. ".",
            intensity = 60,
            tags = { "gift", "discovery", reaction },
            decay_rate = 3,
            metadata = {
                item_id = item.id,
                reaction = reaction,
            }
        }, result)

        if reaction == "loved" then
            addNewsLogEntry(world, resident.name .. " discovered a deep love of " .. item.name .. ".", result)
        elseif reaction == "hated" then
            addNewsLogEntry(world, resident.name .. " discovered a dramatic hatred of " .. item.name .. ".", result)
        end
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
        addNewsLogEntry(world, resident.name .. " reached Happiness Level " .. resident.level .. ".", result)
    end

    return result
end

return HappinessSystem
