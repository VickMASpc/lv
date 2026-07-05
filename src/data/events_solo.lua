return {
    {
        id = "solo_hungry",
        type = "solo",
        priority = 80,
        cooldown = 3,
        preconditions = function(world, res)
            return res.needs.hunger < 30
        end,
        weight = function(world, res)
            return (30 - res.needs.hunger) * 2
        end,
        run = function(world, res)
            return {
                title = "Feeling Peckish",
                text = res.name .. " is looking at their empty fridge with deep regret.",
                choices = {
                    {
                        label = "Order Pizza",
                        requirements = {
                            money = 15
                        },
                        effects = {
                            money = -15,
                            needs = {
                                { target = 1, key = "hunger", delta = 40 }
                            },
                            mood = {
                                { target = 1, key = "happiness", delta = 10 }
                            },
                            memories = {
                                {
                                    target = 1,
                                    type = "comfort",
                                    text = "A hot pizza fixed the worst of the hunger.",
                                    intensity = 20,
                                    tags = { "food", "care" },
                                    participants = { res.id }
                                }
                            }
                        },
                        success_text = res.name .. " feels much better after eating."
                    },
                    {
                        label = "Eat a carrot",
                        effects = {
                            needs = {
                                { target = 1, key = "hunger", delta = 10 }
                            },
                            mood = {
                                { target = 1, key = "happiness", delta = -5 }
                            }
                        },
                        success_text = res.name .. " is less hungry, but not impressed."
                    }
                }
            }
        end
    },
    {
        id = "solo_bored",
        type = "solo",
        priority = 40,
        cooldown = 2,
        preconditions = function(world, res)
            return res.needs.fun < 50
        end,
        run = function(world, res)
            return {
                title = "Staring at the wall",
                text = res.name .. " is extremely bored. The wallpaper is starting to look interesting.",
                choices = {
                    {
                        label = "Play Video Games",
                        effects = {
                            needs = {
                                { target = 1, key = "fun", delta = 30 },
                                { target = 1, key = "energy", delta = -10 }
                            },
                            mood = {
                                { target = 1, key = "excitement", delta = 8 }
                            }
                        },
                        success_text = res.name .. " found a little spark again."
                    },
                    {
                        label = "Go for a walk",
                        effects = {
                            needs = {
                                { target = 1, key = "fun", delta = 15 },
                                { target = 1, key = "health", delta = 5 }
                            },
                            mood = {
                                { target = 1, key = "stress", delta = -6 }
                            }
                        },
                        success_text = res.name .. " came back in a better headspace."
                    }
                }
            }
        end
    }
}
