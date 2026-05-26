-- Copyright (c) 2026 treevar. All rights reserved.
-- Licensed under a modified MIT License <https://github.com/treevar/mc-cc/blob/main/LICENSE>

--GCode(Fanuc) interpreter for a turtle
local GCode = require("gcode.map")
local Util = require("common.util")

Interp = {
    state = {
        x = 0,
        y = 0,
        z = 0,

        heading = 0,
        plane = GCode.plane.XY,
        activeTool = 0,
        dwellTime = 0,
        unit = GCode.units.MM,
        scale = 1.0,
        coordMode = GCode.coordMode.ABS,
        motionMode = nil,
        retractPlane = nil,

        activeWCS = "G54",
        wcs = { --Indices are the cmd string, it's easier
            ["G54"] = {x = 0, y = 0, z = 0},
            ["G55"] = {x = 0, y = 0, z = 0},
            ["G56"] = {x = 0, y = 0, z = 0},
            ["G57"] = {x = 0, y = 0, z = 0},
            ["G58"] = {x = 0, y = 0, z = 0},
            ["G59"] = {x = 0, y = 0, z = 0},
        },
        callStack = {},
        halted = false,
    },
    reg = { --Command registers

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

function Interp:halt(reason)
    self.haltMsg = reason
    self.state.halted = true
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

--Validates letters,
--Ensures only valid chars,
--Ensures decimal place is between numbers,
--Ensures number follows letter
--Line starts with a valid letter
function Interp.validateLine(line)
    if(line == nil) then return nil end
    if(#line == 0) then return nil end

    local validLetters = "GM"
    for _, l in pairs(GCode.validParam) do
        validLetters = validLetters .. l
    end

    local patterns = {
        "^[^" .. validLetters .."]", --Starts with a non valid char
        "[^%d" .. validLetters .. "%.]", --Match any that are NOT digit, valid, or dot
        string.rep("[" .. validLetters .. "]", 2), --Match multiple concurrent letters 
        "[%D]%.", --Dot trailing a non digit
        "%.[%D]", --Dot preceding a non digit
        --"%.0-[123456789]" --Non zero following dot
    }
    local idx = nil
    for _, p in pairs(patterns) do
        idx = string.find(line, p)
        if(idx) then return idx end
    end
    return nil
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

--Parse 'G00' and returns .letter = 'G', .val = "00"
function Interp.parseCmdPart(cmd)
    if(#cmd < 2) then return nil end --Need atleast letter and a digit
    local retObj = {}
    retObj.letter = string.upper(string.sub(cmd, 1, 2))
    retObj.val = string.sub(cmd, 2)
    return retObj
end

--Parse entire line
--[[Returns array of each parsed part
    {
        G00 = { --If command
            cmd (from gcode map),
            args = {
                K = 10,
                X = 9,
                ...
            }
        },...
        --If arg only
        X = 1, 
        Y = 2
    }
    OR
    Arg index of bad arg
]]
-- Remove all whitespace
-- Parsing is easy
-- If we dont start with a letter -> HALT
-- If letter with no value -> HALT
-- store letter and then parse until we find the next letter to get our number
-- Repeat
-- Return registers
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

    retObj.badIdx = Interp.validateLine(pString)
    if(retObj.badIdx ~= nil) then
        retObj.failureStr = "Invalid syntax"
        return retObj
    end
    local curLetter = string.sub(pString, 1, 1)

    local curValStart = startIdx + 1
    local foundDot = false
    for i = startIdx + 1, #pString do
        if(retObj.badIdx ~= 0) then return retObj end --Last char caused parsing failure
        local c = pString:sub(i, i)
        if(inComment) then
            if(c == ")") then inComment = false end
        else
            if(c:match("%a")) then --Letter
                --Set value for prev letter
                foundDot = false
                local numStr = pString:sub(curValStart, i-1)
                local num = tonumber(numStr)
                if(num == nil) then
                    retObj.badIdx = i
                    retObj.failureStr = "Failure parsing number"
                else
                    if(curLetter == "G" or curLetter == "M") then
                        local cmd = GCode.cmd[curLetter .. numStr]
                        if(cmd == nil) then
                            retObj.badIdx = i
                            retObj.failureStr = "Unknown command"
                        else
                            if(cmd.modal == nil) then
                                table.insert(retObj.nonModal, cmd)
                            else
                                retObj.modal[cmd.modal] = cmd
                            end
                        end
                    else
                        retObj.args[curLetter] = num
                    end
                end
                if(not Interp.validLetter(c)) then
                    retObj.badIdx = i
                    retObj.failureStr = "Illegal character"
                else
                    curLetter = c
                end
            elseif(c:match("%d")) then --Number
                if(foundDot and tonumber(c) ~= 0) then --Non 0 after decimal point
                    retObj.badIdx = i
                    retObj.failureStr = "Grid violation"
                end
            else
                if(c == "(") then inComment = true
                elseif((c == "." and foundDot) or c ~= ".") then 
                    retObj.badIdx = i
                    retObj.failureStr = "Illegal character"
                else
                    foundDot = true
                end
            end
        end
    end

    if(inComment) then
        retObj.badIdx = #pString
        retObj.failureStr = "No comment closure"
    end
    
    return retObj
end

function Interp:read(fileName)
    if(fileName == nil or #fileName == 0) then
        self:halt("Bad file name")
        return
    end
    local file = fs.open(fileName)
    if(file == nil) then
        self:halt("Can't open file")
        return
    end
end