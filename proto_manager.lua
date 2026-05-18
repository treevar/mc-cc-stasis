Proto_Manager = {PROTO = nil, _isClient = nil, timeout = 2}

function Proto_Manager:new(proto, isClient, timeout)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.PROTO = proto
    o._isClient = isClient
    o.timeout = timeout
    return o
end

function Proto_Manager:decode(pckt)
    if(not pckt or not pckt.cmd) then
        return nil
    end
    if(pckt.status ~= 200) then
        if(pckt.data == nil) then
            return pckt.status
        else
            return pckt.data
        end
    end
    return self.PROTO.decodePckt(pckt.cmd, pckt, self._isClient)
end

--Sends a packet to a machine, cmd is the command type, ... is the data to encode for that command (varies by cmd)
function Proto_Manager:send(id, status, cmd, ...)
    local dat = { ... }
    --print("DATA: " .. textutils.serialize(dat))
    local msg = self.PROTO.encodeMsg(self._isClient, status, cmd, dat)
    local sendMsg = { cmd = cmd, status = status, data = msg }
    if(self._isClient) then
        --print("Sending cmd '" .. cmd .. "with proto " .. self.PROTO.SERVER_PROTO .. "' to node " .. id .. " with data: " .. textutils.serialize(msg))
        rednet.send(id, sendMsg, self.PROTO.SERVER_PROTO)
    else
        rednet.send(id, sendMsg, self.PROTO.CLIENT_PROTO)
    end
end

--Receive a packet, returns decoded data if decode is true and raw packet if false, expects packets from expectID if set
function Proto_Manager:recv(expectID)
    local proto = nil
    if(self._isClient) then
        proto = self.PROTO.CLIENT_PROTO
    else
        proto = self.PROTO.SERVER_PROTO
    end
    local id, msg = rednet.receive(proto, self.timeout)
    
    if(not id or not msg or (expectID and id ~= expectID)) then
        return nil
    end
    --print("Received message with proto " .. proto .. " from " .. (id or "nil") .. ": " .. textutils.serialize(msg or "nil"))
    if(msg.status == nil or msg.cmd == nil) then
        return nil
    end

    local res = {id = id, status = msg.status, cmd = msg.cmd, data = msg.data, decoded = self:decode(msg)}
    return res
end

return Proto_Manager