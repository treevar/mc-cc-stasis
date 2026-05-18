local Config = require("config")
local Log = require("log")
local Util = require("util")
local Stasis_Proto = require("stasis_proto")
local Proto_Manager = require("proto_manager")

local modem = peripheral.find("modem") or nil

local config = Config:new("/stasis/data/user.cfg")
local log = Log:new("/stasis/data/latest.log", Log.Level.DEBUG)
local stasisMgr = nil

local shouldRun = true
--Contains info of nodes found
local nodes = {}
local DEF_TIMEOUT = 2
--ID, Location, Authed, Online
--id, loc, en, on

local terminalCmd = {}
local redNetCmd = {}

--Returns node based on id
function getNodeByID(id)
    for n in nodes do
        if(n.id == id) then
            return n
        end
    end
end

--Returns node based on location
function getNodeByLoc(loc)
    for n in nodes do
        if(n.loc == loc) then
            return n
        end
    end
end

--Pings node and rerturns if it responded
function pingNode(id, timeout)
    stasisMgr:send(id, 200, Stasis_Proto.cmd.PING, "ping")
    local res = stasisMgr:recv(id)
    if(res.status == 200 and res.decoded == "pong") then
        return true
    end
    return false
end

--Get info from node and return it, returns nil if failed
function queryNode(id)
    --Need user id to see if we're authed
    if(not config:has("user_id")) then
        print("User ID not set, can't query")
        return nil
    end
    --print("USER ID: " .. config:get("user_id"))
    stasisMgr:send(id, 200, Stasis_Proto.cmd.INFO, config:get("user_id"))
    local res = stasisMgr:recv(id)
    if (not res) then
        print("Timeout while waiting for response")
        return nil
    end
    if(res.status ~= 200) then
        log:log(log.Level.ERROR, "Error response from node" .. id .. ": " .. res.data)
        print("Error response from node: " .. res.data)
        return nil
    end

    if(not res.decoded.loc or not res.decoded.authed) then
        log:log(log.Level.ERROR, "invalid response from node" .. id .. ": " .. res.decoded)
        print("invalid response from node")
        return nil
    end
    return {id = id, loc = res.decoded.loc, authed = res.decoded.authed}
end

--Finds all nodes currently online and queries them
function findNodes()
    print("Searching...")
    local sNodes = { rednet.lookup(Stasis_Proto.SERVER_PROTO) }
    print("Found ", #sNodes, " nodes")
    write("Querying nodes...")
    for _, nID in pairs(sNodes) do
        nodes[nID] = queryNode(nID)
        if(nodes[nID]) then
            write('.')
        else
            print("Failed to query node ", nID)
        end
    end
    print("")
    printNodes(nodes)
end

--Print info about node
function printNode(id)
    local n = nodes[id]
    if(not n) then
        return
    end
    print(n.id .. ": '" .. n.loc .. "' " .. n.authed)
end

--Print all nodes with header
function printNodes(nodes)
    print("ID  Loc  Authed")
    for id, n in pairs(nodes) do
        printNode(id)
    end
end

--Resolve id/location to node
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

--Terminal Cmd Callbacks
terminalCmd["exit"] = function(cmd)
    shouldRun = false
end

terminalCmd["nodes"] = function(cmd)
    findNodes()
end

terminalCmd["list"] = function(cmd)
    printNodes(nodes)
end

terminalCmd["tp"] = function(cmd)
    if(#cmd < 2) then
        print("Usage:")
        print("tp [node_id/location]")
        return
    end
    local node = resolveNode(cmd[2])
    if(not node) then
        print("Node not found")
        return
    end
    if(node.authed ~= "1") then
        print("Node not authed")
        return
    end
    stasisMgr:send(node.id, 200, Stasis_Proto.cmd.TP, config:get("user_id"))
    local res = stasisMgr:recv(node.id)
    if(not res or res.status ~= 200) then
        print("Failed to teleport")
    end
end

terminalCmd["ping"] = function(cmd)
    if(#cmd < 2) then
        print("Usage:")
        print("ping [node_id/location]")
        return
    end
    local node = resolveNode(cmd[2])
    if(not node) then
        print("Node not found")
        return
    end
    if(pingNode(node.id)) then
        print("Node [" .. node.id .. "] " .. node.loc .. " is online")
    else
        print("Node [" .. node.id .. "] " .. node.loc .. " is offline")
    end
end

terminalCmd["help"] = function(cmd)
    print("Commands:")
    print(" nodes \n  Search for nodes")
    print(" list \n  List found nodes")
    print(" tp [node_id/location] \n  Teleport to node")
    print(" ping [node_id/location] \n  Ping node")
    print(" exit \n  Exit the program")
    print(" help \n  Show this message")
end

--Handle terminal input
function handleInput(input)
    if(#input == 0) then
        return
    end
    local cmd = input[1]
    if(terminalCmd[cmd]) then
        terminalCmd[cmd](input)
    else
        print("Unknown command")
    end
end


--Main
log:clear()
config:load()

--Init Peripherals
if modem == nil then
    log:log(log.Level.FATAL, "Modem not found")
    print("Install a modem with 'equip' while a modem is in your inventory")
    return
else
    rednet.open(peripheral.getName(modem))
end

if(not config:has("user_id")) then
    write("Enter your user ID: ")
    local userID = read()
    config:set("user_id", userID)
end

if(not config:has("timeout")) then
    config:set("timeout", DEF_TIMEOUT)
end

config:save()

Stasis_Proto.logger = log

stasisMgr = Proto_Manager:new(Stasis_Proto, true, config:get("timeout"))

print("Logged in as ", config:get("user_id"))
findNodes()

while shouldRun do
    write("sc> ")
    handleInput(Util.split(read(), ' '))
end