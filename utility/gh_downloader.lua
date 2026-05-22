package.path = package.path .. ";/?.lua"

local Github = require("common.gh_loader")
local Util = require("common.util")

local loader = Github:new("treevar", "mc-cc", "main")

local userIn = nil


print("[GH fileName] {local file}")

while (userIn ~= "exit") do
    userIn = Util.prompt("Enter file: ")
    print("Fetching...")
    local args = Util.split(userIn, ' ')
    if(not loader:get(args[1], args[2])) then
        print("Unable to fetch file")
    else
        print("OK")
    end
end