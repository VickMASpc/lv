local RelationshipSystem = require("src.systems.relationship_system")
local MemorySystem = require("src.systems.memory_system")
local DialogueSystem = require("src.systems.dialogue_system")
local templates = require("src.data.dialogue_templates")

return {
    {
        id = "pair_bad_joke",
        type = "pair",
        priority = 90,
        cooldown = 4,
        preconditions = function(world, a, b)
            local rel = RelationshipSystem.ensure(world, a.id, b.id)
            return a.mood.happiness > 40 and rel.tension < 50
        end,
        run = function(world, a, b)
            local intro = DialogueSystem.resolve(templates.joke_bad, a)
            
            return {
                title = "A Bad Joke",
                text = a.name .. " tries to break the ice with " .. b.name .. ".\n\n\"" .. intro .. "\"",
                choices = {
                    {
                        label = "Tell them it was harmless",
                        effects = {
                            relationships = {
                                { kind = "affection", from = 2, to = 1, delta = -2 },
                                { kind = "tension", from = 1, to = 2, delta = 4 }
                            },
                            memories = {
                                {
                                    target = 1,
                                    type = "awkward",
                                    text = "Told a bad joke to " .. b.name .. ".",
                                    intensity = 30,
                                    tags = { "joke", "awkward" },
                                    participants = { a.id, b.id }
                                },
                                {
                                    target = 2,
                                    type = "awkward",
                                    text = a.name .. " told a weird joke.",
                                    intensity = 20,
                                    tags = { "joke", "awkward" },
                                    participants = { a.id, b.id }
                                }
                            }
                        },
                        success_text = "The moment passes, but the awkwardness lingers."
                    },
                    {
                        label = "Tell " .. a.name .. " to apologize",
                        effects = {
                            relationships = {
                                { kind = "affection", from = 2, to = 1, delta = 5 },
                                { kind = "affection", from = 1, to = 2, delta = 2 },
                                { kind = "trust", from = 2, to = 1, delta = 4 },
                                { kind = "tension", from = 1, to = 2, delta = -5 }
                            },
                            memories = {
                                {
                                    target = 1,
                                    type = "social",
                                    text = "Apologized to " .. b.name .. " for a bad joke.",
                                    intensity = 40,
                                    tags = { "apology", "social" },
                                    participants = { a.id, b.id }
                                },
                                {
                                    target = 2,
                                    type = "social",
                                    text = a.name .. " apologized after a bad joke.",
                                    intensity = 24,
                                    tags = { "apology", "social" },
                                    participants = { a.id, b.id }
                                }
                            }
                        },
                        success_text = "The apology lands better than the joke did."
                    }
                }
            }
        end
    }
}
