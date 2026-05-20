local util = require("common.util")
local Log = require("common.log")

Config = {fileName = "default.cfg", data = {}, logger = nil}

function Config:new(fileName, logger)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.fileName = fileName
    o.logger = logger
    o.data = {}
    return o
end

function Config:_log(level, ...)
    if self.logger then
        self.logger:log(level, ...)
    end
end

function Config:load(fileName)
    fileName = fileName or self.fileName
    if fs.exists(fileName) then
        local file = fs.open(fileName, "r")
        local content = file.readAll()
        file.close()
        
        local loadedData = textutils.unserialize(content)
        if loadedData then
            -- Clear existing data in the original table
            self:clear()
            -- Populate original table with new data
            for k, v in pairs(loadedData) do self.data[k] = v end
        end

        self:_log(Log.Level.INFO, "Loaded config from ", fileName)
        return true
    else
        self:_log(Log.Level.WARN, "Config file '", fileName, "' not found")
        return false
    end
end


function Config:save(fileName)
    fileName = fileName or self.fileName
    local file = fs.open(fileName, "w")
    file.write(textutils.serialize(self.data))
    file.close()
    log(self, Log.Level.INFO, "Saved config to ", fileName)
end

function Config:has(key)
    return self.data[key] ~= nil
end

function Config:get(key)
    return self.data[key]
end

function Config:set(key, value)
    self.data[key] = value
    self:_log(Log.Level.DEBUG, "Updated config ", key, ": ", value or "nil")
end

function Config:clear()
    for k in pairs(self.data) do self.data[k] = nil end
end

return Config