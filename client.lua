local config = require("config")
local util = require("util")
local modem = peripheral.find("modem") or nil
local ID = os.getComputerID()
local configFileName = "stasis/data/user.cfg"
local shouldRun = true
local nodes = {}
local OUT_PROTO = "stasis"
local IN_PROTO = "stasis_res"
local DEF_TIMEOUT = 2
--ID, Location, Authed, Online
--id, loc, en, on

function getNodeByID(id)
    for n in nodes do
        if(n.id == id) then
            return n
        end
    end
end

function getNodeByLoc(loc)
    for n in nodes do
        if(n.loc == loc) then
            return n
        end
    end
end

function pingNode(id, timeout)
    timeout = timeout or config.getKey("timeout")
    rednet.send(id, {cmd = "ping"}, OUT_PROTO)
    local nId, msg = rednet.receive(IN_PROTO, timeout)
    if(msg and msg == "pong") then 
        return true 
    end
    return false
end

function queryNode(id)
    if(not config.hasKey("user_id")) then
        print("User ID not set, can't query")
        return nil
    end
    rednet.send(id, {userID = config.getKey("user_id"), cmd = "info"}, OUT_PROTO)
    local rID, res = rednet.receive(IN_PROTO, config.getKey("timeout"))
    if (not res) then
        print("Timeout while waiting for response")
        return nil
    end
    if(rID ~= id) then
        util.log(util.logLevel.ERROR, "recv from wrong node")
        print("recv from wrong node")
        return nil
    end
    if(res) then
        if(res.status ~= 200) then
            util.log(util.logLevel.ERROR, "Error response from node" .. id .. ": " .. res.data)
            print("Error response from node: " .. res.data)
            return
        end
        local parts = util.split(res.data, ' ')
        if(#parts ~= 2) then
            util.log(util.logLevel.ERROR, "invalid response from node" .. id .. ": " .. res.data)
            print("invalid response from node")
            return nil
        end
        return {id = id, loc = parts[1], authed = parts[2]}
    end
end

function findNodes()
    print("Searching...")
    local sNodes = { rednet.lookup("stasis") }
    print("Found ", #sNodes, " nodes")
    print("Querying nodes...")
    for _, nID in pairs(sNodes) do
        nodes[nID] = queryNode(nID)
        if(nodes[nID]) then
            printNode(nID)
        else
            print("Failed to query node ", nID)
        end
    end
end

function printNode(id)
    local n = nodes[id]
    if(not n) then
        return
    end
    print(n.id .. ": '" .. n.loc .. "' " .. n.authed)
end

function printNodes(nodes)
    for id, n in pairs(nodes) do
        printNode(id)
    end
end

function resolveNode(input)
    local id = tonumber(input)
    if(not id) then
        for nID, n in pairs(nodes) do
            if(n.loc == input) then
                return n
            end
        end
        return nil
    end
    if(nodes[id] == nil) then
        return nil
    end
    return nodes[id]
end

function handleInput(input)
    if(#input == 0) then
        return
    end
    if(input[1] == "exit") then
        shouldRun = false
    elseif(input[1] == "nodes") then
        findNodes()
        --printNodes(nodes)
    elseif(input[1] == "tp") then
        if(#input < 2) then
            print("Usage: tp [node_id/location]")
            return
        end
        local node = resolveNode(input[2])
        if(not node) then
            print("Node not found")
            return
        end
        if(node.authed == "0") then
            print("Node not authed")
            return
        end
        rednet.send(node.id, {userID = config.getKey("user_id"), cmd = "tp"}, OUT_PROTO)
        rednet.receive(IN_PROTO, config.getKey("timeout"))
    elseif(input[1] == "list") then
        printNodes(nodes)
    elseif(input[1] == "ping") then
        if(#input < 2) then
            print("Usage: ping [node_id/location]")
            return
        end
        local node = resolveNode(input[2])
        if(not node) then
            print("Node not found")
            return
        end
        if(pingNode(node.id)) then
            print("Node [" .. node.id .. "] " .. node.loc .. " is online")
        else
            print("Node [" .. node.id .. "] " .. node.loc .. " is offline")
        end
    elseif(input[1] == "help") then
        print("Commands:")
        print("nodes - Search for stasis nodes")
        print("list - List found nodes")
        print("tp [node_id/location] - Teleport to node")
        print("ping [node_id/location] - Ping node to check if it's online")
        print("exit - Exit the program")
        print("help - Show this message")
    else
        print("Unknown command")
    end
end


--Main
util.clearLog()

--Main
--Init Peripherals
if modem == nil then
    util.log(util.logLevel.FATAL, "Modem not found")
    print("Install a modem with 'equip' while a modem is in your inventory")
    return
else
    rednet.open(peripheral.getName(modem))
end

--Load Config
config.loadConfig(configFileName)

if(not config.hasKey("user_id")) then
    write("Enter your user ID: ")
    local userID = read()
    config.setKey("user_id", userID)
end

if(not config.hasKey("timeout")) then
    config.setKey("timeout", DEF_TIMEOUT)
end

config.saveConfig(configFileName)

print("Logged in as ", config.getKey("user_id"))
findNodes()

while shouldRun do
    write("sc> ")
    handleInput(util.split(read(), ' '))
end