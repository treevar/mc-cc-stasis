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

return {isSide = isSide, split = split, isValidName = isValidName, queryNode = queryNode}