local util = require("util")

local config = {}

function loadConfig(fileName)
    if fs.exists(fileName) then
        local file = fs.open(fileName, "r")
        local content = file.readAll()
        file.close()
        
        local loadedData = textutils.unserialize(content)
        if loadedData then
            -- Clear existing data in the original table
            clear()
            -- Populate original table with new data
            for k, v in pairs(loadedData) do config[k] = v end
        end

        util.log(util.logLevel.INFO, "Loaded config from ", fileName)
        return true
    else
        util.log(util.logLevel.WARN, "Config file '", fileName, "' not found")
        return false
    end
end


function saveConfig(fileName)
    local file = fs.open(fileName, "w")
    file.write(textutils.serialize(config))
    file.close()
    util.log(util.logLevel.INFO, "Saved config to ", fileName)
end

function keyExists(key)
    return not (config[key] == nil)
end

function hasKey(key)
    return keyExists(key)
end

function getKey(key)
    return config[key]
end

function setKey(key, value)
    config[key] = value
    util.log(util.logLevel.DEBUG, "Updated config ", key, ": ", value or "nil")
end

function clear()
    for k in pairs(config) do config[k] = nil end
end

return {loadConfig = loadConfig, saveConfig = saveConfig, keyExists = keyExists, hasKey = hasKey, getKey = getKey, setKey = setKey, data = config}