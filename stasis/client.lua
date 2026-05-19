local Config = require("config")
local Log = require("log")
local Util = require("util")
local Stasis_Proto = require("stasis_proto")
local Proto_Manager = require("proto_manager")

local modem = peripheral.find("modem", function(name, per) return per.isWireless() end) or nil

local appDir = "/stasis"
local dataDir = appDir .. "/data"

local log = Log:new(dataDir .. "/latest.log", Log.Level.DEBUG)
local config = Config:new(dataDir .. "/user.cfg", log)
local stasisMgr = Proto_Manager:new(Stasis_Proto, true, 1, log)

local shouldRun = true
--Contains info of nodes found
local nodes = {}
local DEF_TIMEOUT = 2
--ID, Location, Authed, Online
--id, loc, en, on

local terminalCmd = {}
local redNetCmd = {}

--Pings node and rerturns if it responded
function pingNode(id, timeout)
    stasisMgr:send(id, 200, Stasis_Proto.CMD.PING, "ping")
    local res = stasisMgr:recv(id)
    if(res.status == 200 and res.decoded == "pong") then
        return true
    end
    return false
end

--Finds all nodes currently online and queries them
function findNodes()
    print("Searching...")
    local sNodes = { rednet.lookup(Stasis_Proto.SERVER_PROTO) }
    print("Found ", #sNodes, " nodes")
    if(#sNodes == 0) then
        return
    end
    write("Querying nodes...")
    for _, nID in pairs(sNodes) do
        local node = Util.queryNode(stasisMgr, nID, config:get("user_id"))
        if(type(node) == "table") then
            nodes[nID] = node
            write('.')
        elseif(type(node) == "string") then
            write('x')
            log:log(Log.Level.WARN, "Failed to query node " .. nID .. ": " .. node)
        else
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
    stasisMgr:send(node.id, 200, Stasis_Proto.CMD.TP, config:get("user_id"))
    local res = stasisMgr:recv(node.id)
    if(not res or res.status ~= 200) then
        print("Failed to teleport")
    end
end

--Admin CMD
terminalCmd["tpas"] = function(cmd)
    if(not config:has("admin")) then
        return
    end
    if(#cmd < 3) then
        print("Usage:")
        print("tpas [node_id/location] [user_id]")
        return
    end
    local node = resolveNode(cmd[2])
    if(not node) then
        print("Node not found")
        return
    end
    stasisMgr:send(node.id, 200, Stasis_Proto.CMD.TP, cmd[3])
    local res = stasisMgr:recv(node.id)
    if(not res) then
        print("Failed to teleport")
    elseif(res.status ~= 200) then
        print(res.data)
    else
        print("Teleported " .. cmd[3] .. " to " .. node.loc)
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

if(not fs.exists(dataDir)) then
    fs.makeDir(dataDir)
end

shell.setDir(appDir)

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
    local nameGood = false
    local userID = nil
    while not nameGood do
        userID = read()
        if(not Util.isValidName(userID)) then
            print("User ID can't contain spaces, try again")
        else
            nameGood = true
        end
    end
    config:set("user_id", userID)
end

if(not config:has("timeout")) then
    config:set("timeout", DEF_TIMEOUT)
end

config:save()

stasisMgr.timeout = config:get("timeout")

print("Logged in as", config:get("user_id"))
findNodes()

while shouldRun do
    write("sc> ")
    handleInput(Util.split(read(), ' '))
end