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

--Parsing

function Interp.rmComment(line)
    if(line == nil) then return nil end
    local commentStart = string.find(line, ';', 1, true)
    if(commentStart == nil) then return line end
    return string.sub(line, 1, commentStart-1)
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
function Interp.parseLine(line)
    if(#line == 0) then return nil end
    local args = Util.split(line, ' ')
    if(#args == 0) then return nil end --Empty line

    local cmd = GCode.code[args[1]]
    --Unknown command
    --if(cmd == nil) then return nil end
    --Parse args
    local retObj = {
        cmd = cmd,
        args = {}
    }
    local startIdx = 2
    if(cmd == nil) then --Invalid command, assume using prev modal
        startIdx = 1
    end
    for i = startIdx, #args do
        local parsedArg = Interp.parseCmdPart(args[i])
        if(parsedArg == nil) then
            return i
        end
        retObj.args[parsedArg.letter] = parsedArg.val
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