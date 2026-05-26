-- Copyright (c) 2026 treevar. All rights reserved.
-- Licensed under a modified MIT License <https://github.com/treevar/mc-cc/blob/main/LICENSE>

-- GCode mappings
GCode = {}
--Inclusive
GCode.worldLimits = {
    X = {
        min = {
            overworld = -29999984,
            nether = -29999984,
            ender = -29999984
        },
        max = {
            overworld = 29999984,
            nether = 29999984,
            ender = 29999984
        },
        float = true
    },
    Y = {
        min = {
            overworld = -64,
            nether = 0,
            ender = 0
        },
        max = {
            overworld = 319,
            nether = 255,
            ender = 255
        },
        float = true
    },
    Z = {
        min = {
            overworld = -29999984,
            nether = -29999984,
            ender = -29999984
        },
        max = {
            overworld = 29999984,
            nether = 29999984,
            ender = 29999984
        },
        float = true
    }
}

GCode.modal = {
    --G
    MOTION = "MOTION",
    PLANE = "PLANE",
    DISTANCE = "DISTANCE",
    UNIT = "UNIT",
    SCALE = "SCALE",
    CANNED = "CANNED",
    WCS = "WCS",
    --M
    PROG_FLOW = "PROG_FLOW"
}

GCode.plane = {
    XY = "XY",
    ZX = "ZX",
    YZ = "YZ"
}

GCode.unit = {
    IN = "IN",
    MM = "MM"
}

GCode.coordMode = {
    ABS = "ABS",
    REL = "REL"
}

GCode.motionMode = {
    MOVE = "MOVE", --No cut
    LINE = "LINE", --Cut
    CIRC_CW = "CIRC_CW",
    CIRC_CCW = "CIRC_CCW",
    DRILL = "DRILL"
}

--Inclusive
GCode.validParam = { --Params that may be used by commands, any others are ignored
    --Coords
    X = GCode.worldLimits.X,
    Y = GCode.worldLimits.Y,
    Z = GCode.worldLimits.Z,
    --Arc
    I = GCode.worldLimits.X, --X center point
    J = GCode.worldLimits.Y, --Y center point,
    K = GCode.worldLimits.Z, --Z center point,
    R = { --Radius of arc
        min = 0,
        max = GCode.worldLimits.X.max
    },

    T = { --Tool
        min = 1,
        max = 16,
    },
    Q = { --Quantity
        min = 0,
        max = 64
    },
    P = { --Dwell time
        float = true --Allow floating point numbers
    },
    L = { --Param tag
        validVal = {
            [2] = true, --Set absolute pos
            [3] = true, --Set dimension
            [10] = true, --Define tool slot
            [20] = true --Set heading
        }
    }
}

GCode.code = {
    G00 = {
        str = "G00",
        desc = "Rapid move", --No cutting
        optArgs = {"X", "Y", "Z"},
        modal = GCode.modal.MOTION
    },
    G01 = {
        str = "G01",
        desc = "Linear interpolation",
        optArgs = {"X", "Y", "Z"},
        modal = GCode.modal.MOTION
    },
    G02 = {
        str = "G02",
        desc = "Circular interpolation (CW)",
        optArgs = {"X", "Y", "Z"},
        reqArgs = {"R"},
        modal = GCode.modal.MOTION
    },
    G03 = {
        str = "G03",
        desc = "Circular interpolation (CCW)",
        optArgs = {"X", "Y", "Z"},
        reqArgs = {"R"},
        modal = GCode.modal.MOTION
    },
    G04 = {
        str = "G04",
        desc = "Dwell sec",
        reqArgs = {"P"}
    },
    G10 = {
        str = "G10",
        desc = "Set params",
        reqArgs = {"L"},
        optArgs = {"X", "Y", "Z", "P", "T", "Q"}
        --No modal
    },
    G13 = {
        str = "G13",
        desc = "Circular Pocket Milling (CCW)",
        reqArgs = {"K"},
        optArgs = {"X", "Y", "Z", "I", "Q"},
        modal = GCode.modal.MOTION
    },
    G17 = {
        str = "G17",
        desc = "Select XY plane",
        modal = GCode.modal.PLANE
    },
    G18 = {
        str = "G18",
        desc = "Select ZX plane",
        modal = GCode.modal.PLANE
    },
    G19 = {
        str = "G19",
        desc = "Select YZ plane",
        modal = GCode.modal.PLANE
    },
    G20 = {
        str = "G20",
        desc = "Set units to inches",
        modal = GCode.modal.UNIT
    },
    G21 = {
        str = "G21",
        desc = "Set units to millimeters",
        modal = GCode.modal.UNIT
    },
    G28 = {
        str = "G28",
        desc = "Return to home position"
        --No modal
    },
    G50 = {
        str = "G50",
        desc = "Cancel scaling",
        modal = GCode.modal.SCALE
    },
    G51 = {
        str = "G51",
        desc = "Scale",
        optArgs = {"X", "Y", "Z", "P", "I", "J", "K"},
         modal = GCode.modal.SCALE
    },
    G54 = {
        str = "G54",
        desc = "Work coord 1",
        modal = GCode.modal.WCS
    },
    G55 = {
        str = "G55",
        desc = "Work coord 2",
        modal = GCode.modal.WCS
    },
    G56 = {
        str = "G56",
        desc = "Work coord 3",
        modal = GCode.modal.WCS
    },
    G57 = {
        str = "G57",
        desc = "Work coord 4",
        modal = GCode.modal.WCS
    },
    G58 = {
        str = "G58",
        desc = "Work coord 5",
        modal = GCode.modal.WCS
    },
    G59 = {
        str = "G59",
        desc = "Work coord 6",
        modal = GCode.modal.WCS
    },
    G81 = {
        str = "G81",
        desc = "Drilling cycle",
        optArgs = {"X", "Y", "Z"},
        modal = GCode.modal.MOTION
    },
    G90 = {
        str = "G90",
        desc = "Absolute coords",
        modal = GCode.modal.DISTANCE
    },
    G91 = {
        str = "G91",
        desc = "Relative coords",
        modal = GCode.modal.DISTANCE
    },
    G92 = {
        str = "G92",
        desc = "Set pos"
        --No modal
    },
    G98 = {
        str = "G98",
        desc = "Return to initial point",
        modal = GCode.modal.CANNED
    },
    G99 = {
        str = "G99",
        desc = "Return to R point",
        modal = GCode.modal.CANNED
    },
    G150 = {
        str = "G150",
        desc = "Rectangular Pocket Milling",
        reqArgs = {"I", "K"}, -- width and length
        optArgs = {"X", "Y", "Z", "Q"},
        modal = GCode.modal.MOTION
    },
    M00 = {
        str = "M00",
        desc = "Halt until user interrupts",
        modal = GCode.modal.PROG_FLOW
    },
    M02 = {
        str = "M02",
        desc = "Halt",
        modal = GCode.modal.PROG_FLOW
    },
    M06 = {
        str = "M06",
        desc = "Tool change",
        reqArgs = {"T"}
        --No modal
    },
    M30 = {
        str = "M30",
        desc = "Halt & rewind",
        modal = GCode.modal.PROG_FLOW
    },
    M98 = {
        str = "M98",
        desc = "Call subprogram",
        reqArgs = {"P"},
        optArgs = {"X", "Y", "Z", "I", "J", "K", "R", "T", "Q", "L"}
        --No modal
    },
    M99 = {
        str = "M99",
        desc = "Return from subprogram"
        --No modal
    },
    --Jokes
    M08 = {
        str = "M08",
        desc = "Flood coolant"
        --No modal
    },
    M09 = {
        str = "M09",
        desc = "Coolant off"
        --No modal
    }
}