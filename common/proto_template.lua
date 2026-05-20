-- Copyright (c) 2026 treevar. All rights reserved.
-- Licensed under the Custom MIT License <https://github.com/treevar/mc-cc/blob/main/LICENSE>
--Follows standard proto structure
Proto_Template = {
    CLIENT_PROTO = "Proto_Template_res",
    SERVER_PROTO = "Proto_Template",
    CMD = {
        --CMD_NAME = "net_cmd_name"
    },
}

Proto_Template.decoders = { --Functions to decode each cmd type, returns decoded data or nil if failed
   --[[ [Proto_Template.CMD.CMD_NAME] = {
        allowedStatus = {200}, --Allowed status codes for this cmd
        fn = function(isClient, pckt) return pckt.data end --Decode Function, takes isClient and full packet as args, returns decoded data or nil if failed
    }
    --]]
}

Stasis_Proto.encoders = { --Functions to encode data for each cmd type, returns nil if failed
    --[[ [Proto_Template.CMD.CMD_NAME] = {
        allowedStatus = {200}, --Allowed status codes for this cmd
        fn = function(isClient, data) return data[1] end --Encode Function, takes isClient and data to encode as args, returns encoded data or nil if failed
    }
    --]]
}

return Proto_Template