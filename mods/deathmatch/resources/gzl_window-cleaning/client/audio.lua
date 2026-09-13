Audio = {}

local activeWipeSound = nil
local lastWipeTick = 0

function Audio.playWipeEffect()
    local now = getTickCount()
    if now - lastWipeTick > 280 then
        lastWipeTick = now
        playSoundFrontEnd(41)
    end
end

function Audio.playSuccess()
    playSoundFrontEnd(13)
end

function Audio.playContractComplete()
    playSoundFrontEnd(12)
end

function Audio.playButtonClick()
    playSoundFrontEnd(41)
end