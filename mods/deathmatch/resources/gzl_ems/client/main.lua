local isComaActive = false
local comaEndTick = 0
local totalComaSec = 180
local holdStartTime = 0
local isHoldingE = false
local distressCooldownUntil = 0
local distressBliplist = {}

function isPlayerInComa()
    return isComaActive
end

function getDeathTimeRemaining()
    if not isComaActive then return 0 end
    local now = getTickCount()
    local remMs = math.max(0, comaEndTick - now)
    return math.ceil(remMs / 1000)
end

function getHoldProgress()
    if not isHoldingE or holdStartTime == 0 then return 0 end
    local holdDurationMs = (Config.HoldToRespawnTime or 3) * 1000
    local elapsed = getTickCount() - holdStartTime
    return math.min(1.0, elapsed / holdDurationMs)
end

function getDistressCooldownRemaining()
    local now = getTickCount()
    if now >= distressCooldownUntil then return 0 end
    return math.ceil((distressCooldownUntil - now) / 1000)
end

addEvent("gzl_ems:onClientEnterComa", true)
addEventHandler("gzl_ems:onClientEnterComa", root, function(durationSec)
    durationSec = tonumber(durationSec) or Config.BleedoutTime or 180
    if durationSec < 0 then durationSec = 0 end
    isComaActive = true
    totalComaSec = durationSec
    comaEndTick = getTickCount() + (durationSec * 1000)
    holdStartTime = 0
    isHoldingE = false

    outputChatBox("#ef4444[DURUM]#ffffff Ağır yaralandınız! Acil servis çağırmak için #38bdf8[G]#ffffff tuşuna basın.", 255, 255, 255, true)

    toggleAllControls(false, true, false)
    setPedWeaponSlot(localPlayer, 0)
end)

addEvent("gzl_ems:onClientRevived", true)
addEventHandler("gzl_ems:onClientRevived", root, function()
    isComaActive = false
    comaEndTick = 0
    holdStartTime = 0
    isHoldingE = false

    toggleAllControls(true, true, true)
end)

addEventHandler("onClientElementDataChange", localPlayer, function(dataName, oldValue)
    if dataName == "ems:isDead" then
        local isDead = (getElementData(localPlayer, "ems:isDead") == true)
        if isDead and not isComaActive then
            local rem = tonumber(getElementData(localPlayer, "character:death_time_remaining")) or 0
            isComaActive = true
            totalComaSec = rem
            comaEndTick = getTickCount() + (rem * 1000)
            holdStartTime = 0
            isHoldingE = false
            toggleAllControls(false, true, false)
            setPedWeaponSlot(localPlayer, 0)
        elseif not isDead and isComaActive then
            isComaActive = false
            comaEndTick = 0
            holdStartTime = 0
            isHoldingE = false
            toggleAllControls(true, true, true)
        end
    end
end)

addEventHandler("onClientResourceStart", resourceRoot, function()
    if getElementData(localPlayer, "ems:isDead") == true then
        local rem = tonumber(getElementData(localPlayer, "character:death_time_remaining")) or 0
        isComaActive = true
        totalComaSec = rem
        comaEndTick = getTickCount() + (rem * 1000)
        holdStartTime = 0
        isHoldingE = false
        toggleAllControls(false, true, false)
        setPedWeaponSlot(localPlayer, 0)
    end
end)

addEvent("gzl_ems:createDistressBlip", true)
addEventHandler("gzl_ems:createDistressBlip", root, function(x, y, z, victimName)
    local blip = createBlip(x, y, z, 0, 2, 239, 68, 68, 255, 0, 99999)
    if isElement(blip) then
        setBlipOrdering(blip, 100)
        table.insert(distressBliplist, {
            blip = blip,
            created = getTickCount(),
            duration = Config.BlipDuration or 60000
        })
    end
end)

setTimer(function()
    local now = getTickCount()
    for i = #distressBliplist, 1, -1 do
        local item = distressBliplist[i]
        if (now - item.created) >= item.duration or not isElement(item.blip) then
            if isElement(item.blip) then
                destroyElement(item.blip)
            end
            table.remove(distressBliplist, i)
        end
    end
end, 3000, 0)

addEventHandler("onClientKey", root, function(button, press)
    if not isComaActive then return end

    if button == "g" and press then
        local now = getTickCount()
        if now < distressCooldownUntil then
            local rem = math.ceil((distressCooldownUntil - now) / 1000)
            outputChatBox(string.format("#f59e0b[EMS]#ffffff Tekrar sinyal gönderebilmek için #ffffff%d#f59e0b saniye bekleyin.", rem), 255, 255, 255, true)
            return
        end

        distressCooldownUntil = now + ((Config.DistressCooldown or 45) * 1000)
        triggerServerEvent("gzl_ems:sendDistress", localPlayer)
        playSoundFrontEnd(43)
        return
    end

    if button == "e" then
        if press then
            local remSec = getDeathTimeRemaining()
            if remSec <= 0 then
                isHoldingE = true
                holdStartTime = getTickCount()
            end
        else
            isHoldingE = false
            holdStartTime = 0
        end
        return
    end
end)

addEventHandler("onClientPreRender", root, function()
    if not isComaActive then return end

    setPedWeaponSlot(localPlayer, 0)

    if isHoldingE and holdStartTime > 0 then
        local remSec = getDeathTimeRemaining()
        if remSec <= 0 then
            local holdDurationMs = (Config.HoldToRespawnTime or 3) * 1000
            local elapsed = getTickCount() - holdStartTime
            if elapsed >= holdDurationMs then
                isHoldingE = false
                holdStartTime = 0
                triggerServerEvent("gzl_ems:requestHospitalRespawn", localPlayer)
                playSoundFrontEnd(101)
            end
        else
            isHoldingE = false
            holdStartTime = 0
        end
    end
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    if isComaActive then
        toggleAllControls(true, true, true)
    end
    for _, item in ipairs(distressBliplist) do
        if isElement(item.blip) then
            destroyElement(item.blip)
        end
    end
    distressBliplist = {}
end)