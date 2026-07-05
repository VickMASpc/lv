local HappinessSystem = require("src.systems.happiness_system")
local MemorySystem = require("src.systems.memory_system")

local ProblemSystem = {}

local FOOD_PROBLEM_TYPE = "need_food"
local FOOD_REWARD_MONEY = 10

local function ensureWorld(world)
    world = world or {}
    world.day = tonumber(world.day) or 1
    world.phase_index = tonumber(world.phase_index) or 1
    world.money = tonumber(world.money) or 0
    world.memories = world.memories or {}
    world.next_memory_id = tonumber(world.next_memory_id) or 1
    return world
end

local function ensureResident(resident)
    resident = resident or {}
    resident.needs = resident.needs or {}
    resident.memories = resident.memories or {}
    return resident
end

local function isActiveProblem(problem)
    return problem and (problem.active or problem.status == "active")
end

local function addResolutionMemory(world, resident, item, reward_money, gift_result)
    if type(MemorySystem.add) ~= "function" then
        return nil
    end

    local reaction = gift_result and gift_result.reaction or "neutral"
    return MemorySystem.add(world, resident, {
        type = "problem_resolved",
        text = resident.name .. "'s food problem was resolved with " .. item.name .. ".",
        intensity = 65,
        tags = { "problem", "resolved", FOOD_PROBLEM_TYPE, reaction },
        decay_rate = 4,
        metadata = {
            problem_type = FOOD_PROBLEM_TYPE,
            item_id = item.id,
            item_name = item.name,
            reward_money = reward_money,
            reaction = reaction,
        }
    })
end

function ProblemSystem.getForResident(resident)
    resident = ensureResident(resident)
    if isActiveProblem(resident.problem_bubble) then
        return resident.problem_bubble
    end
    return nil
end

function ProblemSystem.clear(resident)
    resident = ensureResident(resident)
    resident.problem_bubble = nil
    return true
end

function ProblemSystem.generate(world)
    world = ensureWorld(world)

    local generated = {}

    for _, resident in pairs(world.residents or {}) do
        resident = ensureResident(resident)

        if not isActiveProblem(resident.problem_bubble) then
            local hunger = resident.needs.hunger
            if hunger ~= nil and hunger <= 35 then
                local bubble = {
                    active = true,
                    status = "active",
                    type = FOOD_PROBLEM_TYPE,
                    priority = 100 - hunger,
                    created_day = world.day,
                    created_phase = world.phase_index,
                    target_need = "hunger",
                    prompt = "I'm hungry. Could you give me something to eat?",
                    target_item_tag = "food",
                }

                resident.problem_bubble = bubble
                table.insert(generated, {
                    resident = resident,
                    problem = bubble,
                })
            end
        end
    end

    return generated
end

function ProblemSystem.resolveFoodProblem(world, resident, item)
    world = ensureWorld(world)
    resident = ensureResident(resident)
    item = item or {}

    local active_problem = ProblemSystem.getForResident(resident)
    if not active_problem then
        return {
            ok = false,
            message = "No active problem.",
            problem_resolved = false,
            gift_result = nil,
            reward_money = 0,
            reason = "no_active_problem",
        }
    end

    if active_problem.type ~= FOOD_PROBLEM_TYPE then
        return {
            ok = false,
            message = "That problem cannot be resolved with food.",
            problem_resolved = false,
            gift_result = nil,
            reward_money = 0,
            reason = "wrong_problem_type",
        }
    end

    if item.category ~= "food" then
        return {
            ok = false,
            message = "That item is not food.",
            problem_resolved = false,
            gift_result = nil,
            reward_money = 0,
            reason = "invalid_item_category",
        }
    end

    local gift_result = HappinessSystem.applyGift(world, resident, item)
    world.money = world.money + FOOD_REWARD_MONEY
    ProblemSystem.clear(resident)

    local result = {
        ok = true,
        message = resident.name .. " accepted the food. Problem resolved.",
        problem_resolved = true,
        gift_result = gift_result,
        reward_money = FOOD_REWARD_MONEY,
    }

    local memory = addResolutionMemory(world, resident, item, FOOD_REWARD_MONEY, gift_result)
    if memory then
        result.memory = memory
    end

    return result
end

function ProblemSystem.update(world)
    return ProblemSystem.generate(world)
end

function ProblemSystem.resolve(world, resident, item)
    local result = ProblemSystem.resolveFoodProblem(world, resident, item)
    return result.ok, result.message, result
end

return ProblemSystem
