-- Copyright (c) 2026 treevar. All rights reserved.
-- Licensed under the Custom MIT License <https://github.com/treevar/mc-cc/blob/main/LICENSE>
--Stasis Installer
--Process args
local args = { ... }
local createStartup = true
local runAfterInstall = false
if(#args > 0) then
    for _, arg in pairs(args) do
        if(arg == "nostartup") then
            createStartup = true
        elseif(arg == "run") then
            runAfterInstall = true
        end
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
    "common/util.lua"
}

local entryPoint = "/path/to/entry_point.lua"

--Fetch files
local fails = {}
for i, fileName in pairs(filesNeeded) do
    write("[" .. i .. "/" .. #filesNeeded .. "] Fetching '" .. fileName .. "' ")
    if(not loader:get(fileName)) then
        table.insert(fails, fileName)
        write("FAIL\n")
    else
        write("OK\n")
    end
end

if(#fails > 0) then
    print("Failled to fetch " .. #fails .. "/" .. #filesNeeded .. " files")
    for _, fileName in pairs(filesNeeded) do
        write("X ")
        print(fileName)
    end
    return
end

--Create startup file
if(createStartup) then
    print("Creating startup file")
    --Create startup folder if NX
    if(not fs.exists("/startup")) then
        fs.makeDir("/startup")
    end
    local startFile = fs.open("/startup/stasis_loader.lua", "w")
    startFile.write("shell.run(\"" .. entryPoint .. "\")")
    startFile.close()
end

print("Done")

--Execute program
if(runAfterInstall) then
    shell.run(entryPoint)
end