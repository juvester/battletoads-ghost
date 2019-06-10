-- MIT License

-- Copyright (c) 2018 juvester <github.com/juvester>

-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:

-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.

-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.


--### SETTINGS ######################################################
GHOST_MODEL = 3             -- 1 = Rash
                            -- 2 = WireRash
                            -- 3 = Mario

OPACITY = 1.0               -- A value between 0.0 and 1.0, where
                            --   1.0 is not transparent at all
                            --   0.5 is 50% see-through
                            --   0.0 is completely transparent
--###################################################################


-- For BizHawk support
if savestate.registerload == nil then
    savestate.registerload = event.onloadstate

    gui.opacity = function(alpha) end

    memory.readbytesigned = memory.read_s8

    memory.readwordsigned = function(addressLow, addressHigh)
        return 0xFF * memory.read_s8(addressHigh) + memory.read_u8(addressLow)
    end

    joypad.getdown = joypad.get

    gui.drawimage = function(dx, dy, gdStr)
        gui.drawPixel(dx, dy, 0xFFFFFFFF)
    end
end

-- "Globals", needed in onSavestateLoad() callback function
local currentFrames = {}
local ghostFrames = {}
local frameNumber = 1
local saveCurrentRun = false


-- Functions
function onSavestateLoad()
    if (saveCurrentRun) then
        ghostFrames = currentFrames
        print("Ghost saved!")
    end

    currentFrames = {}
    frameNumber = 0
    saveCurrentRun = false
end

function getLevel()
    return memory.readbyte(0x000D)
end

function getCameraX()
    return memory.readwordsigned(0x0087, 0x0088)
end

function getCameraY()
    return memory.readwordsigned(0x0089, 0x008A)
end

function getPlayer1X()
    return memory.readwordsigned(0x03FD, 0x03EE)
end

function getPlayer1Y()
    --     Camera Y     + Player1 Y on screen     - Jump height
    return getCameraY() + memory.readbyte(0x0493) - memory.readbyte(0x0475)
end

function getPlayer1Sprite()
    local sprite = memory.readbytesigned(0x03D0)

    -- Use negative values if facing left
    if (memory.readbyte(0x008E) == 0x40) then
        sprite = -sprite
    end

    return sprite
end

function recordCurrentFrame()
    local frame = {}
    frame.level = getLevel()
    frame.player1X = getPlayer1X()
    frame.player1Y = getPlayer1Y()
    frame.player1Sprite = getPlayer1Sprite()
    return frame
end

function drawGhost(ghostFrame, sprite)
    if (ghostFrame == nil or sprite == nil) then
        return
    end

    local cameraX = getCameraX()
    local cameraY = getCameraY()

    local ghostX = ghostFrame.player1X - cameraX

    -- TODO: Find out how lvl 12 x-position works. Use fixed position for now.
    if (ghostFrame.level == 12) then
        ghostX = 7
    end

    ghostX = ghostX - sprite.deltaX

    local ghostY = ghostFrame.player1Y - cameraY - sprite.deltaY

    gui.drawimage(ghostX, ghostY, sprite.gdStr)
end

--[[
function drawDebugPixels(ghostFrame)
    local cameraX = getCameraX()
    local cameraY = getCameraY()

    local plrX = getPlayer1X() - cameraX
    local plrY = getPlayer1Y() - cameraY
    gui.drawpixel(plrX, plrY, "white")

    if (ghostFrame == nil) then
        return
    end

    local ghoX = ghostFrame.player1X - cameraX
    local ghoY = ghostFrame.player1Y - cameraY
    gui.drawpixel(ghoX, ghoY, "white")
end
--]]

function fileExists(filename)
    local file = io.open(filename, "r")
    if file ~= nil then
        io.close(file)
        return true
    else
        return false
    end
end

function loadSprite(filename)
    if (not fileExists(filename)) then
        return nil
    end

    local file = assert(io.open(filename, "rb"))
	local sprite = file:read("*all")
	file:close()
	return sprite
end

function loadSpriteDeltas(filename)
    local deltas = {}

    for line in io.lines(filename) do
        sprite, rx,ry, lx,ly = line:match("([^,]+),([^,]+),([^,]+),([^,]+),([^,]+)")

        deltas[tonumber(sprite)] = {
            rx = tonumber(rx),
            ry = tonumber(ry),
            lx = tonumber(lx),
            ly = tonumber(ly)
        }
    end

  return deltas
end

-- Returns an array of sprites where items
--   1..n    are facing right
--   n+1..2n are facing left
function loadSprites(ghostModel)
    local sprites = {}
    local path = "sprites/" .. ghostModel .. "/"
    local deltas = loadSpriteDeltas(path .. "deltas")
    local spriteCount = #deltas

    for i = 1, spriteCount do
        sprites[i] = {
            gdStr = loadSprite(path .. i .. ".gd"),
            deltaX = deltas[i].rx,
            deltaY = deltas[i].ry
        }

        sprites[spriteCount + i] = {
            gdStr = loadSprite(path .. i .. "l.gd"),
            deltaX = deltas[i].lx,
            deltaY = deltas[i].ly
        }
    end

    return sprites
end

function toRashSprite(spriteValue)
    local RASH_SPRITES = 103

    if spriteValue < 0 then
        return RASH_SPRITES + math.abs(spriteValue)
    end

    return spriteValue
end

function toMarioSprite(spriteValue)
    --          Run pattern         Jump pattern
    -- Rash     6,3,4,5,4,8,6,7     5,45,5
    -- Mario    2,3,4               5
    -- Mapped   2,3,4,5,4,3,2,5     5,5,5
    -- Alt?     2,3,4,2,4,3,2,4     5,5,5

    local MARIO_SPRITES = 14

    local direction = 0
    if (spriteValue < 0) then
        direction = MARIO_SPRITES
    end

    spriteValue = math.abs(spriteValue)

    if spriteValue == 1 then return direction + 1 end
    if spriteValue == 2 then return direction + 1 end
    if spriteValue == 3 then return direction + 3 end
    if spriteValue == 4 then return direction + 4 end
    if spriteValue == 5 then return direction + 2 end
    if spriteValue == 6 then return direction + 2 end
    if spriteValue == 7 then return direction + 4 end
    if spriteValue == 8 then return direction + 3 end
    if spriteValue == 9 then return direction + 2 end
    if spriteValue == 10 then return direction + 3 end
    if spriteValue == 11 then return direction + 11 end
    if spriteValue == 13 then return direction + 11 end
    if spriteValue == 14 then return direction + 7 end
    if spriteValue == 15 then return direction + 14 end
    if spriteValue == 16 then return direction + 7 end
    if spriteValue == 17 then return direction + 7 end
    if spriteValue == 18 then return direction + 7 end
    if spriteValue == 19 then return direction + 7 end
    if spriteValue == 20 then return direction + 7 end
    if spriteValue == 21 then return direction + 7 end
    if spriteValue == 22 then return direction + 13 end
    if spriteValue == 24 then return direction + 1 end
    if spriteValue == 25 then return direction + 6 end
    if spriteValue == 26 then return direction + 6 end
    if spriteValue == 27 then return direction + 6 end
    if spriteValue == 28 then return direction + 6 end
    if spriteValue == 29 then return direction + 1 end
    if spriteValue == 30 then return direction + 5 end
    if spriteValue == 31 then return direction + 2 end
    if spriteValue == 32 then return direction + 6 end
    if spriteValue == 33 then return direction + 2 end
    if spriteValue == 34 then return direction + 6 end
    if spriteValue == 35 then return direction + 6 end
    if spriteValue == 36 then return direction + 8 end
    if spriteValue == 37 then return direction + 9 end
    if spriteValue == 38 then return direction + 1 end
    if spriteValue == 39 then return direction + 6 end
    if spriteValue == 40 then return direction + 6 end
    if spriteValue == 41 then return direction + 1 end
    if spriteValue == 42 then return direction + 1 end
    if spriteValue == 43 then return direction + 6 end
    if spriteValue == 44 then return direction + 8 end
    if spriteValue == 45 then return direction + 5 end
    if spriteValue == 46 then return direction + 5 end
    if spriteValue == 48 then return direction + 7 end
    if spriteValue == 49 then return direction + 6 end
    if spriteValue == 50 then return direction + 7 end
    if spriteValue == 51 then return direction + 7 end
    if spriteValue == 52 then return direction + 6 end
    if spriteValue == 53 then return direction + 7 end
    if spriteValue == 54 then return direction + 1 end
    if spriteValue == 55 then return direction + 1 end
    if spriteValue == 56 then return direction + 8 end
    if spriteValue == 57 then return direction + 9 end
    if spriteValue == 58 then return direction + 8 end
    if spriteValue == 59 then return direction + 10 end
    if spriteValue == 60 then return direction + 9 end
    if spriteValue == 61 then return direction + 8 end
    if spriteValue == 62 then return direction + 9 end
    if spriteValue == 63 then return direction + 8 end
    if spriteValue == 64 then return direction + 6 end
    if spriteValue == 65 then return direction + 7 end
    if spriteValue == 66 then return direction + 7 end
    if spriteValue == 67 then return direction + 1 end
    if spriteValue == 68 then return direction + 6 end
    if spriteValue == 69 then return direction + 1 end
    if spriteValue == 70 then return direction + 1 end
    if spriteValue == 74 then return direction + 1 end
    if spriteValue == 75 then return direction + 1 end
    if spriteValue == 76 then return direction + 6 end
    if spriteValue == 77 then return direction + 6 end
    if spriteValue == 78 then return direction + 1 end
    if spriteValue == 79 then return direction + 1 end
    if spriteValue == 80 then return direction + 1 end
    if spriteValue == 81 then return direction + 1 end
    if spriteValue == 82 then return direction + 3 end
    if spriteValue == 83 then return direction + 2 end
    if spriteValue == 85 then return direction + 1 end
    if spriteValue == 86 then return direction + 1 end
    if spriteValue == 87 then return direction + 6 end
    if spriteValue == 88 then return direction + 9 end
    if spriteValue == 89 then return direction + 8 end
    if spriteValue == 90 then return direction + 7 end
    if spriteValue == 91 then return direction + 12 end
    if spriteValue == 92 then return direction + 13 end
    if spriteValue == 93 then return direction + 7 end
    if spriteValue == 94 then return direction + 5 end
    if spriteValue == 95 then return direction + 10 end
    if spriteValue == 96 then return direction + 14 end
    if spriteValue == 97 then return direction + 7 end
    if spriteValue == 98 then return direction + 13 end
    if spriteValue == 99 then return direction + 10 end
    if spriteValue == 100 then return direction + 8 end
    if spriteValue == 101 then return direction + 8 end
    if spriteValue == 102 then return direction + 8 end
    if spriteValue == 103 then return direction + 8 end

    return direction + 1 -- unknown
end

function isVisible(ghostFrame, currentFrame)
    return ghostFrame and ghostFrame.player1Sprite ~= 0 and ghostFrame.level == currentFrame.level
end


-- Beginning of execution

local ghostModels = {"Rash", "WireRash", "Mario"}

local sprites = loadSprites(ghostModels[GHOST_MODEL])

local toGhostSprite = toRashSprite
if (GHOST_MODEL == 3) then
    toGhostSprite = toMarioSprite
end

savestate.registerload(onSavestateLoad)

gui.opacity(OPACITY)

while (true) do
    local currentFrame = recordCurrentFrame()
    currentFrames[frameNumber] = currentFrame

    local ghostFrame = ghostFrames[frameNumber]
    if (isVisible(ghostFrame, currentFrame)) then
        drawGhost(ghostFrame, sprites[toGhostSprite(ghostFrame.player1Sprite)])
    end

    local buttonsDown = joypad.getdown(1)
    if (buttonsDown["select"] or buttonsDown["Select"]) then
        saveCurrentRun = true
    end

    -- Debug
    --drawDebugPixels(ghostFrame)
    --drawGhost(currentFrame, sprites[toGhostSprite(currentFrame.player1Sprite)])

    emu.frameadvance()
    frameNumber = frameNumber + 1
end
