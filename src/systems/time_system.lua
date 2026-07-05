local TimeSystem = {}

TimeSystem.PHASES = { "Morning", "Afternoon", "Evening", "Night" }

function TimeSystem.advance(world)
    world.phase_index = world.phase_index + 1

    if world.phase_index > #TimeSystem.PHASES then
        world.phase_index = 1
        world.day = world.day + 1
    end
    world.tick = world.tick + 1

    local NeedSystem = require("src.systems.need_system")
    local MoodSystem = require("src.systems.mood_system")
    local EventSystem = require("src.systems.event_system")
    local MemorySystem = require("src.systems.memory_system")
    local LocationSystem = require("src.systems.location_system")
    local RelationshipSystem = require("src.systems.relationship_system")
    local ProblemSystem = require("src.systems.problem_system")

    NeedSystem.update(world)
    MoodSystem.update(world)
    ProblemSystem.generate(world)
    MemorySystem.update(world)
    LocationSystem.assignActivities(world)
    EventSystem.generate(world)
    RelationshipSystem.refreshAll(world)

    print("Time Advanced: Day " .. world.day .. ", " .. TimeSystem.PHASES[world.phase_index])
end

function TimeSystem.getPhaseName(world)
    return TimeSystem.PHASES[world.phase_index]
end

return TimeSystem
