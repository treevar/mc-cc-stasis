--Follows standard proto structure
Stasis_Proto = {
    CLIENT_PROTO = "stasis_res",
    SERVER_PROTO = "stasis",
    cmd = {
        PING = "ping", --Ping node, returns pong
        INFO = "info", --Get info about node, returns location and if authed
        TP = "tp" --Teleport to node
    },
    logger = nil
}

Stasis_Proto.decoders = { --Functions to decode each cmd type, returns decoded data or nil if failed
    [Stasis_Proto.cmd.PING] = function(pckt, isClient) return pckt.data end,
    [Stasis_Proto.cmd.TP] = function(pckt, isClient) 
        if(isClient) then
            return pckt.data
        end
        return {userID = pckt.data} 
    end,
    [Stasis_Proto.cmd.INFO] = function(pckt, isClient) 
        if(isClient) then
            if(not pckt.data.loc or not pckt.data.authed) then
                Stasis_Proto.logger:log(Log.Level.WARN, "Invalid info packet data: " .. textutils.serialize(pckt.data))
                return nil
            end
            return { loc = pckt.data.loc, authed = pckt.data.authed }
        end
        return {userID = pckt.data}
    end
}

Stasis_Proto.encoders = { --Functions to encode data for each cmd type, returns nil if failed
    [Stasis_Proto.cmd.PING] = function(isClient, data) return data[1] end,
    [Stasis_Proto.cmd.TP] = function(isClient, data) return data[1] end,
    [Stasis_Proto.cmd.INFO] = function(isClient, data)
        if(not isClient) then
            local loc = data[1]
            local authed = data[2]
            if(not loc or not authed) then
                Stasis_Proto.logger:log(Log.Level.WARN, "Invalid info encoder data: " .. textutils.serialize(data))
                return nil
            end
            return {loc = loc, authed = authed}
        else
            return data[1] --User ID
        end
    end
}

Stasis_Proto.decodePckt = function(cmd, pckt, isClient) --Decode packet from node
    --print("Decoding packet with cmd '" .. cmd .. "': " .. textutils.serialize(pckt))
    if(not pckt or not cmd) then
        Stasis_Proto.logger:log(Log.Level.WARN, "Tried to decode nil packet or cmd")
        return nil
    end
    if(pckt.status == nil or pckt.data == nil) then
        Stasis_Proto.logger:log(Log.Level.WARN, "Tried to decode invalid packet: " .. textutils.serialize(pckt))
        return nil
    end

    if(pckt.status ~= 200) then
        return pckt.data
    end
    local decoder = Stasis_Proto.decoders[cmd]
    if(not decoder) then
        Stasis_Proto.logger:log(Log.Level.WARN, "No decoder for cmd " .. cmd)
        return nil
    end
    return decoder(pckt, isClient)
end

Stasis_Proto.encodeMsg = function(isClient, status, cmd, dat) --Encode packet to send to node, returns string or nil if failed
    --print("Encoding data " .. dat)
    if(status ~= 200) then
        return dat[1]
    end
    if(not cmd) then
        Stasis_Proto.logger:log(Log.Level.WARN, "Tried to encode nil cmd")
        return nil
    end
    local encoder = Stasis_Proto.encoders[cmd]
    if(not encoder) then
        Stasis_Proto.logger:log(Log.Level.WARN, "No encoder for cmd " .. cmd)
        return nil
    end
    
    return encoder(isClient, dat)
end


return Stasis_Proto