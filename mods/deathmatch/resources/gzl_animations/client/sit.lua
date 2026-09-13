
local sitIFP = nil
local isLocalSitting = false
local localSittingStyle = nil
local isExiting = false
local sitStartTick = 0

local SitStyles = {
    [1] = { 
        name = "Gerçekçi Sandalyeye Oturma (Eğilerek)", 
        block = "PED", 
        enterAnim = "SEAT_down", 
        enterDuration = 1500, 
        loopAnim = "SEAT_idle", 
        exitBlock = "PED",
        exitAnim = "SEAT_up", 
        exitDuration = 1100, 
        isTransition = true,
        isCustom = false,
        blend = 150
    },
    [2] = { 
        name = "Klasik Havada / Bankta Oturuş", 
        block = "sit", 
        anim = "Gun_stand", 
        isTransition = false,
        isCustom = true, 
        blend = 250 
    },
    [3] = { 
        name = "Koltuk / Kanepe", 
        block = "INT_HOUSE", 
        anim = "LOU_Loop", 
        isTransition = false,
        isCustom = false, 
        blend = 250 
    },
    [4] = { 
        name = "Standart Sandalye (Sabit)", 
        block = "PED", 
        anim = "SEAT_idle", 
        isTransition = false,
        isCustom = false, 
        blend = 200 
    },
    [5] = { 
        name = "Park / Bank (Erkek)", 
        block = "BEACH", 
        anim = "ParkSit_M_loop", 
        isTransition = false,
        isCustom = false, 
        blend = 250 
    },
    [6] = { 
        name = "Park / Bank (Kadın)", 
        block = "BEACH", 
        anim = "ParkSit_W_loop", 
        isTransition = false,
        isCustom = false, 
        blend = 250 
    },
    [7] = { 
        name = "Kaldırım / Basamak", 
        block = "ATTRACTORS", 
        anim = "Stepsit_loop", 
        isTransition = false,
        isCustom = false, 
        blend = 250 
    },
    [8] = { 
        name = "Yere Bağdaş Kurma", 
        block = "BEACH", 
        anim = "SitnWait_loop_W", 
        exitBlock = "PED",
        exitAnim = "getup_front",
        exitDuration = 1200,
        isTransition = false,
        isCustom = false, 
        blend = 350 
    },
    [9] = { 
        name = "Yere Uzanma", 
        block = "BEACH", 
        anim = "Lay_Bac_Loop", 
        exitBlock = "PED",
        exitAnim = "getup",
        exitDuration = 1200,
        isTransition = false,
        isCustom = false, 
        blend = 350 
    },
    [10] = { 
        name = "Yerde Dinlenme", 
        block = "CRACK", 
        anim = "crckidle2", 
        exitBlock = "PED",
        exitAnim = "getup_front",
        exitDuration = 1200,
        isTransition = false,
        isCustom = false, 
        blend = 350 
    },
    [11] = { 
        name = "Meditasyon Oturuşu", 
        block = "PARK", 
        anim = "Tai_Chi_Loop", 
        isTransition = false,
        isCustom = false, 
        blend = 300 
    },
}

local pedTimers = {}

local function clearPedTimers(ped)
    if pedTimers[ped] then
        if isTimer(pedTimers[ped].enterTimer) then
            killTimer(pedTimers[ped].enterTimer)
        end
        if isTimer(pedTimers[ped].exitTimer) then
            killTimer(pedTimers[ped].exitTimer)
        end
        pedTimers[ped] = nil
    end
end

local function loadSitIFPs()
    if not isElement(sitIFP) then
        sitIFP = engineLoadIFP("files/sit.ifp", "sit")
        if not sitIFP then
            outputDebugString("[gzl_animations] files/sit.ifp yüklenemedi!", 2)
        end
    end
end

local function applySitAnimation(ped, styleId, skipTransition)
    if not isElement(ped) then return end
    local style = SitStyles[styleId]
    if not style then return end

    clearPedTimers(ped)

    if style.isCustom then
        loadSitIFPs()
    end

    if style.isTransition and not skipTransition and style.enterAnim then
        local enterBlk = style.enterBlock or "PED"
        setPedAnimation(ped, enterBlk, style.enterAnim, style.enterDuration or 1500, false, false, false, true, style.blend or 150)

        pedTimers[ped] = {}
        pedTimers[ped].enterTimer = setTimer(function()
            if isElement(ped) and getElementData(ped, "gzl:sitting") == styleId then
                local loopAnim = style.loopAnim or style.anim
                setPedAnimation(ped, style.block, loopAnim, -1, true, false, false, false, 150)
            end
        end, (style.enterDuration or 1500) - 50, 1)
    else
        local targetAnim = style.loopAnim or style.anim
        setPedAnimation(ped, style.block, targetAnim, -1, true, false, false, false, style.blend or 250)
    end
end

local function triggerStandUp()
    if not isLocalSitting or isExiting then return end
    if not isElement(localPlayer) then return end

    local currentStyle = localSittingStyle
    local style = currentStyle and SitStyles[currentStyle]

    if isPedDead(localPlayer) or isPedInVehicle(localPlayer) then
        isLocalSitting = false
        localSittingStyle = nil
        isExiting = false
        triggerServerEvent("gzl_animations:requestStopSit", localPlayer)
        setPedAnimation(localPlayer, false)
        return
    end

    isLocalSitting = false
    localSittingStyle = nil
    isExiting = true

    triggerServerEvent("gzl_animations:requestStopSit", localPlayer)

    if style and style.exitAnim then
        isExiting = true
        local exitBlk = style.exitBlock or "PED"
        local exitDur = style.exitDuration or 1100

        setPedAnimation(localPlayer, exitBlk, style.exitAnim, exitDur, false, false, false, true, 150)
        setTimer(function()
            if isElement(localPlayer) then
                setPedAnimation(localPlayer, false)
            end
            isExiting = false
        end, exitDur - 250, 1)
    else
        setPedAnimation(localPlayer, false)
        isExiting = false
    end
end

local function stopSitAnimation(ped, styleId)
    if not isElement(ped) then return end

    clearPedTimers(ped)

    local style = styleId and SitStyles[styleId]
    if not style then
        local currentData = getElementData(ped, "gzl:sitting")
        style = currentData and SitStyles[currentData]
    end

    if not isPedDead(ped) and not isPedInVehicle(ped) and style and style.exitAnim then
        local exitBlk = style.exitBlock or "PED"
        local exitDur = style.exitDuration or 1100

        setPedAnimation(ped, exitBlk, style.exitAnim, exitDur, false, false, false, true, 150)
        pedTimers[ped] = {}
        pedTimers[ped].exitTimer = setTimer(function()
            if isElement(ped) and not getElementData(ped, "gzl:sitting") then
                setPedAnimation(ped, false)
            end
        end, exitDur - 250, 1)
    else
        setPedAnimation(ped, false)
    end
end

addEventHandler("onClientResourceStart", resourceRoot, function()
    loadSitIFPs()

    for _, p in ipairs(getElementsByType("player")) do
        local sitStyle = getElementData(p, "gzl:sitting")
        if sitStyle and SitStyles[sitStyle] then
            applySitAnimation(p, sitStyle, true)
            if p == localPlayer then
                isLocalSitting = true
                localSittingStyle = sitStyle
                isExiting = false
                sitStartTick = getTickCount()
            end
        end
    end
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    if isLocalSitting then
        stopSitAnimation(localPlayer)
        isLocalSitting = false
        localSittingStyle = nil
        isExiting = false
    end

    for _, p in ipairs(getElementsByType("player")) do
        clearPedTimers(p)
        if getElementData(p, "gzl:sitting") then
            setPedAnimation(p, false)
        end
    end

    if isElement(sitIFP) then
        destroyElement(sitIFP)
        sitIFP = nil
    end
end)

addEventHandler("onClientElementStreamIn", root, function()
    if getElementType(source) == "player" then
        local sitStyle = getElementData(source, "gzl:sitting")
        if sitStyle and SitStyles[sitStyle] then
            setTimer(applySitAnimation, 100, 1, source, sitStyle, true)
        end
    end
end)

addEventHandler("onClientElementDestroy", root, function()
    clearPedTimers(source)
end)

addEvent("gzl_animations:syncSitAnim", true)
addEventHandler("gzl_animations:syncSitAnim", root, function(arg1, arg2, arg3)
    local ped, styleId, isSitting
    if isElement(arg1) then
        ped = arg1
        styleId = arg2
        isSitting = arg3
    else
        ped = source
        styleId = arg1
        isSitting = arg2
    end

    if not isElement(ped) then return end

    if isSitting and styleId and SitStyles[styleId] then
        isExiting = false
        applySitAnimation(ped, styleId, false)
        if ped == localPlayer then
            isLocalSitting = true
            localSittingStyle = styleId
            sitStartTick = getTickCount()
        end
    else
        if ped == localPlayer then
            isLocalSitting = false
            localSittingStyle = nil
            if not isExiting then
                stopSitAnimation(ped, styleId)
            end
        else
            stopSitAnimation(ped, styleId)
        end
    end
end)

addEventHandler("onClientPreRender", root, function()
    if not isLocalSitting or isExiting then return end
    if not isElement(localPlayer) then return end

    if isChatBoxInputActive() or isCursorShowing() or (getElementData(localPlayer, "gzl_chat:isOpen") == true) then
        return
    end

    if getTickCount() - sitStartTick < 500 then return end

    local isMoving = getPedControlState(localPlayer, "forwards")
        or getPedControlState(localPlayer, "backwards")
        or getPedControlState(localPlayer, "left")
        or getPedControlState(localPlayer, "right")
        or getPedControlState(localPlayer, "jump")

    local isKeyPressed = getKeyState("w")
        or getKeyState("a")
        or getKeyState("s")
        or getKeyState("d")
        or getKeyState("x")
        or getKeyState("space")

    if isMoving or isKeyPressed or isPedInVehicle(localPlayer) or isPedDead(localPlayer) or isElementInWater(localPlayer) then
        triggerStandUp()
    end
end)

addEventHandler("onClientKey", root, function(button, press)
    if not press or not isLocalSitting or isExiting then return end
    if isChatBoxInputActive() or isCursorShowing() or (getElementData(localPlayer, "gzl_chat:isOpen") == true) then
        return
    end

    if getTickCount() - sitStartTick < 500 then return end

    local btn = button:lower()
    if btn == "x" or btn == "space" or btn == "w" or btn == "a" or btn == "s" or btn == "d" then
        triggerStandUp()
    end
end)

loadSitIFPs()