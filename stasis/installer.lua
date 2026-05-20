--Stasis Installer
--Process args
local args = { ... }
local isClient = nil
local createStartup = false
local runAfterInstall = false
if(#args > 0) then
    for _, arg in pairs(args) do
        if(arg == "startup") then
            createStartup = true
        elseif(arg == "run") then
            runAfterInstall = true
        elseif(arg == "node") then
            isClient = false
        elseif(arg == "client") then
            isClient = true
        end
    end 
end

if(isClient == nil) then
    if(pocket) then
        isClient = true
    else
        isClient = false
    end
end

--Load GitHub Loader
--URL for GitHub Loader package
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

--Add proper entry point file
local entryPoint = ""

if(isClient) then 
    entryPoint = "stasis/client.lua"
else
    entryPoint = "stasis/node.lua"
end

table.insert(filesNeeded, entryPoint)

--Fetch files

for i, fileName in pairs(filesNeeded) do
    write("[" .. i .. "/" .. #filesNeeded .. "] Fetching '" .. fileName "' ")
    if(not loader:get(fileName)) then
        write("FAIL\n")
    else
        write("OK\n")
    end
end

--Create startup file
if(createStartup) then
    print("Creating startup file")
    local startFile = fs.open("/startup/stasis_loader.lua", "w")
    startFile.write("shell.run(\"" .. entryPoint .. "\")")
    startFile.close()
end

print("Done")

--Execute program
if(runAfterInstall) then
    shell.run(entryPoint)
end