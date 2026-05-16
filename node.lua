local util = require("util")
local config = require("config")
local modem = peripheral.find("modem", function(name, peripheral) return peripheral.isWireless() end)
local relay = {}
local wrappedRelay = peripheral.find("redstone_relay", function(name, r)
    local idx = string.sub(name, #"redstone_relay_" + 1, #name)
    relay[idx] = r
    return true
end)
local ID = os.getComputerID()
local configFileName = "stasis/data/user.cfg"
local netCodeActive = true
local IN_PROTO = "stasis"
local OUT_PROTO = "stasis_res"
local shouldRun = true
local defState = false

function sideToUsr(relayIdx, side)
    if(util.isSide(side)) then
        for key, value in pairs(config.getKey("map")) do
            if(value.relayIdx ~= relayIdx) then
                return nil
            end
            if(value.side == side) then 
                return key
            end
        end
    end
    return nil
end

function printMappings(map)
    for k, v in pairs(map) do
        print(k, "-> r:", v.relayIdx, " s:", v.side)
    end
end

--Pulse stasis
function triggerStasis(relayIdx, side)
    local relay = relay[relayIdx]
    if(relay == nil) then
        util.log(util.logLevel.WARN, "Attempted to trigger nonexistant relay index " .. relayIdx)
        return
    end
    local defState = config.getKey("def_state")
    relay.setOutput(side, not defState)
    util.log(util.logLevel.INFO, "Triggered side", side, "on relay", relayIdx)
    sleep(0.2) --Wait to trigger redstone
    relay.setOutput(side, defState)
end

function procRednet()
    while true do
        if(netCodeActive) then
            local id, msg = rednet.receive(IN_PROTO)
            handleNetMsg(id, msg)
        else
            --Yield
            sleep(0.1)
        end
    end
end

function procTerminal()
    while true do
        write(config.getKey("loc") .. "> ")
        local cmd = util.split(read(), ' ')
        if(cmd[1] == "exit") then
            return
        end
        handleCmd(cmd)
    end
end

--Handles rednet messages
function handleNetMsg(id, msg)
    sleep(0.1) --Small delay so client doesn't immediately timeout while waiting for response
    local userID = msg.userID
    local cmd = msg.cmd
    if(cmd == "tp") then
        local user = config.getKey("map")[userID]
        if(user == nil) then
            rednet.send(id, {
                status = 401,
                data = "User not set on node"
            }, OUT_PROTO)
        else
            rednet.send(id, {
                status = 200,
                data = "Triggering"
            }, OUT_PROTO)
            triggerStasis(user.relayIdx, user.side)
        end
    elseif(cmd == "info") then
        local status = "0"
        if(not (config.getKey("map")[userID] == nil)) then
            status = "1"
        end
        rednet.send(id, {
            status = 200,
            data = config.getKey("loc") .. " " .. status
        }, OUT_PROTO)
    elseif(cmd == "ping") then
        rednet.send(id, {
            status = 200,
            data = "pong"
        }, OUT_PROTO)
    else
        rednet.send(id, {
            status = 404,
            data = "404"
        }, OUT_PROTO)
    end
end


--Handles terminal commands
function handleCmd(cmd)
    if(#cmd == 0) then return end
    if(cmd[1] == "nonet") then
        netCodeActive = false
    elseif(cmd[1] == "net") then
        netCodeActive = true
    elseif(cmd[1] == "set") then --set [userID] [side] [relay Idx]
        if(#cmd < 4) then
            print("Invalid usage, correct is set [userID] [side] [relay Idx]")
            return
        end
        local userID = cmd[2]
        local side = cmd[3]
        local relayIdx = cmd[4]
        if(not util.isSide(side)) then
            print("Invalid side")
            return
        end
        if(relay[relayIdx] == nil) then
            print("Invalid relay index")
            return
        end
        local curSideUsr = sideToUsr(relayIdx, side)
        if(curSideUsr) then
            print("Side already registered to ", curSideUsr)
            print("clear must be called on the user/side before set")
            return
        end
        util.log(util.logLevel.INFO, "Set " .. userID .. " to relay " .. relayIdx .. ", side " .. side)
        config.getKey("map")[userID] = { relayIdx = relayIdx, side = side }
        config.saveConfig(configFileName)
    elseif(cmd[1] == "clear") then --clear (user/side) [user/side] [relay idx if side]
        if((#cmd < 3 and cmd[2] == "user") or (#cmd < 4 and cmd[2] == "side")) then
            print("Invalid usage, correct is clear (user/side) [user/side] [relay idx if side]")
            return
        end
        if(cmd[2] == "side") then
            if(not util.isSide(cmd[3])) then
                print("Invalid side")
                return
            end
            local relayIdx = cmd[4]
            if(relay[relayIdx] == nil) then
                print("Invalid relay index")
                return
            end
            local curUsr = sideToUsr(relayIdx, cmd[3])
            if(curUsr) then
                config.getKey("map")[curUsr] = nil
                config.saveConfig(configFileName)
                util.log(util.logLevel.INFO, "Relay " .. relayIdx .. ": Cleared side " .. cmd[3] .. " registered to " .. curUsr)
            end
        else --User
            config.getKey("map")[cmd[3]] = nil
            util.log(util.logLevel.INFO, "Cleared user " .. cmd[3])
            config.saveConfig(configFileName)
        end
    elseif(cmd[1] == "save") then
        config.saveConfig(configFileName)
    elseif(cmd[1] == "config") then --config [key] {value}
        if(#cmd == 1) then
            print("Config:")
            print(textutils.serialise(config.data))
            return
        end
        local key = cmd[2]
        if(#cmd == 3) then
            print("Value: ", config.getKey(key))
        else
            local value = cmd[3]
            config.setKey(key, value)
        end
    elseif(cmd[1] == "map") then
        print("Mappings:")
        printMappings(config.getKey("map"))
    elseif(cmd[1] == "relays") then
        print("Relays:")
        for idx, r in pairs(relay) do
            print(idx)
        end
    elseif(cmd[1] == "help") then
        print("Commands:")
        print("exit - Exit the program")
        --print("nonet - Disable rednet message processing")
        --print("net - Enable rednet message processing")
        print("set [userID] [side] [relay Idx] - Set a user ID to a relay and side")
        print("clear (user/side) [userID/side] [relay idx if side] - Clear a user or side mapping")
        print("save - Save config to disk")
        print("config [key] {value} - Get or set config values")
        print("map - Print user to relay/side mappings")
        print("relays - Print available relays and their indexes")
    else
        print("Unknown command")
    end
end

function initRedstoneRelay(relayIdx, state)
    r = relay[relayIdx]
    if (relay == nil) then
        util.log(util.logLevel.WARN, "Attempted to initialize nonexistant relay index", tostring(relayIdx))
        return
    end
    r.setOutput("top", state)
    r.setOutput("bottom", state)
    r.setOutput("left", state)
    r.setOutput("right", state)
    r.setOutput("front", state)
    r.setOutput("back", state)
end

--Load Config
util.clearLog()
config.loadConfig(configFileName)

if(not config.hasKey("loc")) then
    write("Enter the name of this location: ")
    local loc = read()
    config.setKey("loc", loc)
end

if(not config.hasKey("map")) then
    config.setKey("map", {})
end

if(not config.hasKey("def_state")) then
    config.setKey("def_state", false)
end

config.saveConfig(configFileName)

--Main

print("Logged in to node '" .. config.getKey("loc") .. "'")

--Init Peripherals
if modem == nil then
    util.log(util.logLevel.FATAL, "Modem not found")
    return
else
    if(modem == nil) then
        util.log(util.logLevel.FATAL, "Wireless modem not found")
        return
    end
    rednet.open(peripheral.getName(modem))
    print("Rednet modem initialized on " .. peripheral.getName(modem))
end

if (wrappedRelay == nil) then
    util.log(util.logLevel.FATAL, "Redstone relay not found")
    return
end

--Init Relays
for i, r in pairs(relay) do
    print("Initializing redstone_relay_" .. i)
    initRedstoneRelay(i, config.getKey("def_state"))
end
print("Current Mappings:")
printMappings(config.getKey("map"))
rednet.host(IN_PROTO, config.getKey("loc"))
print("Hosting stasis service")
--Start Net and Cmd Threads
parallel.waitForAny(procRednet, procTerminal)

--Cleanup
rednet.unhost(OUT_PROTO)
print("Goodbye")