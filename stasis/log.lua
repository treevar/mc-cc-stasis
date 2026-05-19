Log = {fileName = "log.txt", curLogLevel = 0, enabled = true}

Log.Level = {
    DEBUG = 1,
    INFO = 2,
    WARN = 3,
    ERROR = 4,
    FATAL = 5
}

Log.LevelStr = {
    [1] = "DEBUG",
    [2] = "INFO",
    [3] = "WARN",
    [4] = "ERROR",
    [5] = "FATAL"
}

function Log:new(fileName, logLevel)
    o = {}
    setmetatable(o, self)
    self.__index = self
    o.fileName = fileName
    o.curLogLevel = logLevel or Log.Level.DEBUG
    return o
end

function Log:log(level, ...)
    if (not self.enabled or level < 0 or level > #Log.LevelStr or level < self.curLogLevel) then
        return
    end
    local file = fs.open(self.fileName, "a")
    file.writeLine("[" .. Log.LevelStr[level] .. "] " .. textutils.serialize({...}))
    file.close()
end

function Log:clear()
    local file = fs.open(self.fileName, "w")
    file.write("")
    file.close()
end

return Log