-- Logging
local logLevelStrMap = {}

logLevelStrMap[0] = "DEBUG"
logLevelStrMap[1] = "INFO"
logLevelStrMap[2] = "WARN"
logLevelStrMap[3] = "ERROR"
logLevelStrMap[4] = "FATAL"

local logLevelMap = {
    DEBUG = 0,
    INFO = 1,
    WARN = 2,
    ERROR = 3,
    FATAL = 4
}

local curLogLevel = 0
local loggingFileName = "stasis/data/latest.log"

function log(level, ...)
    if level < curLogLevel then
        return
    end
    local args = {...}
    local str = ""
    for i, v in ipairs(args) do
        str = str .. tostring(v) .. " "
    end
    local file = fs.open(loggingFileName, "a")
    file.write("[" .. logLevelStrMap[level] .. "] " .. str .. "\n" )
    file.close()
end

function clearLog()
    local file = fs.open(loggingFileName, "w")
    file.write("")
    file.close()
end

--User ID

local userID = ""

function setUserID(id, fileName)
    if(not (id == userID)) then
        log(logLevelMap.INFO, "User ID updated from " .. userID .. " to " .. id)
    end
    userID = id
    if(fileName) then
        local file = fs.open(fileName, "w")
        file.write(id)
        file.close()
    end
end

function getUserID()
    return userID
end

function loadUserID(fileName)
    if fs.exists(fileName) then
        local file = fs.open(fileName, "r")
        local id = file.read()
        file.close()
        setUserID(id)
    else
        log(logLevelMap.WARN, "User ID file not found, starting with empty user ID")
    end
end

function isSide(side)
    return  side == "top" or 
            side == "bottom" or 
            side == "left" or
            side == "right" or
            side == "front" or
            side == "back"
end

function split(str, c)
    local prevPos = 1
    local ret = {}
    while(prevPos and prevPos <= #str) do
        local newPos = string.find(str, c, prevPos, true)
        if(newPos) then 
            newPos = newPos - 1 
        else
            newPos = #str
        end
        table.insert(ret, string.sub(str, prevPos, newPos))
        prevPos = newPos + 1 + #c -- + 1 for the -1 earlier and +c to get past sep
    end
    return ret
end

return {log = log, curLogLevel = curLogLevel, logLevel = logLevelMap, userID = userID, isSide = isSide, loggingFileName = loggingFileName, split = split, clearLog = clearLog}