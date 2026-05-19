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

function isValidName(name)
    if(not name or #name == 0) then
        return false
    end
    if(string.find(name, " ", 1, true)) then
        return false    end
    return true
end

--Get info from node and return it, returns nil if failed
function queryNode(stasisMgr, id, userID)
    --Need user id to see if we're authed
    if(not userID) then
        return "User ID not set, can't query"
    end
    stasisMgr:send(id, 200, Stasis_Proto.CMD.INFO, userID)
    local res = stasisMgr:recv(id)
    if (not res) then
        return "Timeout while waiting for response"
    end
    if(res.status ~= 200) then
        return "Error response from node: " .. res.data
    end

    if(not res.decoded.loc or not res.decoded.authed) then
        return "Invalid response from node"
    end
    return {id = id, loc = res.decoded.loc, authed = res.decoded.authed}
end

return {isSide = isSide, split = split, isValidName = isValidName, queryNode = queryNode}