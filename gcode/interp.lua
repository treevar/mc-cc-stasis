-- Copyright (c) 2026 treevar. All rights reserved.
-- Licensed under a modified MIT License <https://github.com/treevar/mc-cc/blob/main/LICENSE>

--GCode(Fanuc) interpreter for a turtle
local GCode = require("gcode.map")
local Util = require("common.util")

Interp = {
    reg = { --Command registers
        halted = false
    },

    haltMsg = ""
}

Interp.handler = {}

Interp.__index = Interp

function Interp:new()
    local o = {}
    setmetatable(o, self)
    return o
end

function Interp.constructErrMsg(err, idx)
    return err .. " at pos " .. idx
end

function Interp:halt(reason, idx)
    if(type(idx) == "number") then
        self.haltMsg = Interp.constructErrMsg(reason, idx)
    else
        self.haltMsg = reason
    end
    self.reg.halted = true
end


--Validation

function Interp.isValidArg(cmd, argLetter)
    if(cmd.optArgs and #cmd.optArgs > 0) then
        if(Util.tableContains(cmd.optArgs, argLetter)) then return true end
    end
    if(cmd.reqArgs and #cmd.reqArgs > 0) then
        if(Util.tableContains(cmd.reqArgs, argLetter)) then return true end
    end
    return false
end

function Interp.verifyArgs(cmd, args)
    if(cmd.reqArgs and #cmd.reqArgs > 0) then
        for k, v in pairs(cmd.reqArgs) do
            if(not Util.tableContains(args)) then end
        end
    end
end

function Interp.validLetter(l)
    if(l == nil or #l ~= 1) then return false end
    return l == "M" or l == "G" or GCode.validParam[l] ~= nil
end

--Validates that the command follows proper syntax
--If atleast one syntax violation is found, the index of the first violation will be returned
--Otherwise returns nil
function Interp.getBadSyntaxIndex(line)
    if(line == nil) then return nil end
    if(#line == 0) then return nil end

    local patterns = {
        "^[^" .. GCode.validParamsStr .."]",                --Starts with a non valid char (Must start with a letter)
        "[^%d" .. GCode.validLettersStr .. "%.]",            --Match any that are NOT digit, valid, or dot
        string.rep("[" .. GCode.validLettersStr .. "]", 2),  --Match multiple concurrent letters 
        "[%D]%.",                                   --Dot trailing a non digit
        "%.[%D]",                                   --Dot preceding a non digit
        --"%.0-[123456789]" --Non zero following dot
    }
    local lowestIdx = nil
    for _, p in pairs(patterns) do
        local idx = string.find(line, p)
        if(idx and idx < lowestIdx) then lowestIdx = idx end
    end
    return lowestIdx
end

--Parsing

--Removed comments and WS from the line 
function Interp.cleanLine(line)
    local clean = ""
    if(line ~= nil) then 
        clean = string.gsub(line, "%s", "") --Rm WS
        clean = string.gsub(clean, "%(.-%)", "") --Rm comments
    end
    return clean
end

--Parse entire line
function Interp.parseLine(line)
    local retObj = {
        modal = {},
        nonModal = {},
        args = {},
        parsingStr = "", --Actual string we parse (all WS rm)
        badIdx = nil, --Index (of parsingStr) of parsing failure
        failureStr = "" --Reason for failure
    }

    if(type(line) ~= "string" or #line == 0) then return retObj end --Empty line

    local pString = Interp.cleanLine(line)
    retObj.parsingStr = pString

    retObj.badIdx = Interp.getBadSyntaxIndex(pString)
    if(retObj.badIdx ~= nil) then
        retObj.failureStr = GCode.error.SYNTAX
        return retObj
    end
    local curLetter = string.sub(pString, 1, 1)

    local curPartStart = 1

    local loopFn = function(i)
        local part = pString:sub(curPartStart, i-1)
        local cmd = GCode.cmd[part]
        if(cmd ~= nil) then
            if(cmd.modal) then
                retObj.modal[cmd.modal] = cmd
            else
                table.insert(retObj.nonModal, cmd)
            end
        else --Parameter
            if(GCode.allCmdLettersStr:find(curLetter, 1, true)) then
                retObj.badIdx = curPartStart
                retObj.failureStr = GCode.error.CMD_UNKNOWN
                return
            end
            retObj.args[curLetter] = pString:sub(curPartStart+1, i-1)
        end
    end

    for i = 2, #pString do
        if(retObj.badIdx ~= nil) then return retObj end --Last loop iter caused parsing failure
        local c = pString:sub(i, i)
        if(c:match("%a")) then --Letter
            loopFn(i)
            curLetter = c
            curPartStart = i
        end
    end

    loopFn(#pString + 1) --Add last cmd
    
    return retObj
end

function Interp:read(fileName)
    if(fileName == nil or #fileName == 0 or not fs.exists(fileName)) then
        self:halt(GCode.error.FILE_NX)
        return
    end
    local file = fs.open(fileName)
    if(file == nil) then
        self:halt(GCode.error.FILE_OPEN)
        return
    end
    local line = file.readLine()
    local parsed = nil
    while line do
        if(#line > 1) then
            parsed = Interp.parseLine(line)
            if(parsed.badIdx) then
                self:halt(parsed.failureStr, parsed.badIdx)
                file.close()
                return
            end
            line = file.readLine()
        end
    end
    file.close()
end