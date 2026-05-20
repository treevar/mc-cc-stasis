package.path = package.path .. ";/?.lua"
local url = "https://raw.githubusercontent.com/treevar/mc-cc/refs/heads/main/common/gh_loader.lua"
local response = http.get(url)

if not response then
    error("Failed to download gh_loader from GitHub!")
end

local content = response.readAll()
response.close()

if(not fs.exists("/common")) then
    fs.makeDir("/common")
end

local file = fs.open("common/gh_loader.lua", "w")
file.write(content)
file.close()

local Github = require("common.gh_loader")
local loader = Github:new("treevar", "mc-cc", "main")

local filesNeeded = {
    "common/config.lua",
    "common/log.lua",
    "commom/proto_manager.lua",
    "common/util.lua",
    "stasis/stasis_proto.lua"
}

if(pocket) then 
    table.insert(filesNeeded, "stasis/client.lua")
else
    table.insert(filesNeeded, "stasis/node.lua")
end


for i, fileName in filesNeeded do
    print("[" .. i .. "/" .. #filesNeeded .. "] Fetching " .. fileName)
    loader:get(fileName)
end