local json = require("src.core.json")
local World = require("src.core.world")

local SaveSystem = {}

function SaveSystem.save(world, slot)
    slot = slot or "autosave"
    local filename = slot .. ".json"

    local ok, data = pcall(json.encode, World.serialize(world))
    if not ok then
        return false, "Could not serialize the save file."
    end

    local success, message = love.filesystem.write(filename, data)
    if success then
        return true, "Game saved to " .. filename .. "."
    end
    return false, "Could not write " .. filename .. "."
end

function SaveSystem.load(slot)
    slot = slot or "autosave"
    local filename = slot .. ".json"

    if not love.filesystem.getInfo(filename) then
        return nil, "No save file was found."
    end

    local data = love.filesystem.read(filename)
    if not data then
        return nil, "The save file could not be read."
    end

    local ok, world = pcall(json.decode, data)
    if not ok then
        return nil, "The save file is not valid."
    end

    if world.version ~= World.SAVE_VERSION then
        return nil, "This save file uses an older format."
    end

    return World.normalize(world), "Game loaded from " .. filename .. "."
end

return SaveSystem
