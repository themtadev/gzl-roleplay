local isCustomAnimsEnabled = true
local loadedIFPs = {}
local replacedPeds = {}

local function applyAnimationsToPed(ped)
    if not isElement(ped) or not isCustomAnimsEnabled then
        return
    end
    for _, pkg in ipairs(AnimationPackages) do
        if loadedIFPs[pkg.customBlock] then
            for _, anim in ipairs(pkg.anims) do
                engineReplaceAnimation(ped, pkg.block, anim, pkg.customBlock, anim)
            end
        end
    end
    replacedPeds[ped] = true
end

local function restoreAnimationsOnPed(ped)
    if not isElement(ped) then
        return
    end
    engineRestoreAnimation(ped)
    replacedPeds[ped] = nil
end

local function applyToAll()
    if not isCustomAnimsEnabled then
        return
    end
    applyAnimationsToPed(localPlayer)
    for _, p in ipairs(getElementsByType("player")) do
        if p ~= localPlayer and isElementStreamedIn(p) then
            applyAnimationsToPed(p)
        end
    end
    for _, p in ipairs(getElementsByType("ped")) do
        if isElementStreamedIn(p) then
            applyAnimationsToPed(p)
        end
    end
end

local function restoreAll()
    restoreAnimationsOnPed(localPlayer)
    for p in pairs(replacedPeds) do
        if isElement(p) then
            restoreAnimationsOnPed(p)
        end
    end
    replacedPeds = {}
end

addEventHandler("onClientResourceStart", resourceRoot, function()
    for _, pkg in ipairs(AnimationPackages) do
        local ifp = engineLoadIFP(pkg.file, pkg.customBlock)
        if ifp then
            loadedIFPs[pkg.customBlock] = ifp
        end
    end
    applyToAll()
end)

addEventHandler("onClientElementStreamIn", root, function()
    local elType = getElementType(source)
    if elType == "player" or elType == "ped" then
        if isCustomAnimsEnabled then
            applyAnimationsToPed(source)
        end
    end
end)

addEventHandler("onClientElementStreamOut", root, function()
    local elType = getElementType(source)
    if elType == "player" or elType == "ped" then
        if replacedPeds[source] then
            restoreAnimationsOnPed(source)
        end
    end
end)

addEventHandler("onClientElementDestroy", root, function()
    replacedPeds[source] = nil
end)

addEventHandler("onClientPlayerSpawn", localPlayer, function()
    if isCustomAnimsEnabled then
        setTimer(applyAnimationsToPed, 200, 1, localPlayer)
    end
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    setPedAnimation(localPlayer)
    restoreAll()
    for _, ifp in pairs(loadedIFPs) do
        if isElement(ifp) then
            destroyElement(ifp)
        end
    end
    loadedIFPs = {}
end)

addCommandHandler("yk22", function()
    isCustomAnimsEnabled = not isCustomAnimsEnabled
    if isCustomAnimsEnabled then
        applyToAll()
        if exports.gzl_ui and exports.gzl_ui.showNotification then
            exports.gzl_ui:showNotification("YK22 Animasyon Paketi: Aktif", "success")
        else
            outputChatBox("[YK22] Ozel animasyon paketi aktif edildi.", 0, 255, 120)
        end
    else
        restoreAll()
        if exports.gzl_ui and exports.gzl_ui.showNotification then
            exports.gzl_ui:showNotification("YK22 Animasyon Paketi: Devre Disi", "info")
        else
            outputChatBox("[YK22] Ozel animasyon paketi devre disi birakildi.", 255, 180, 0)
        end
    end
end)

addCommandHandler("anims", function()
    executeCommandHandler("yk22")
end)

local isPlayingIdleAnim = false
local lastActiveTick = getTickCount()

local function cancelIdleAnim()
    if isPlayingIdleAnim then
        isPlayingIdleAnim = false
        setPedAnimation(localPlayer)
        triggerServerEvent("gzl_animations:setPedIdleAnim", localPlayer, nil)
    end
end

local function playIdleAnim(animName)
    if not isElement(localPlayer) or isPedInVehicle(localPlayer) or isPedDead(localPlayer) or isElementInWater(localPlayer) then
        return
    end
    animName = animName or (math.random(1, 2) == 1 and "stretch" or "shldr")
    isPlayingIdleAnim = true
    setPedAnimation(localPlayer, "lcs_playidles", animName, -1, false, false, true, false)
    triggerServerEvent("gzl_animations:setPedIdleAnim", localPlayer, animName)
end

setTimer(function()
    local isMoving = getPedControlState(localPlayer, "forwards") or getPedControlState(localPlayer, "backwards") or getPedControlState(localPlayer, "left") or getPedControlState(localPlayer, "right")
    local isAction = getPedControlState(localPlayer, "jump") or getPedControlState(localPlayer, "fire") or getPedControlState(localPlayer, "aim_weapon") or getPedControlState(localPlayer, "crouch")

    if isMoving or isAction or isPedInVehicle(localPlayer) or isPedDead(localPlayer) or isElementInWater(localPlayer) then
        lastActiveTick = getTickCount()
        if isPlayingIdleAnim then
            cancelIdleAnim()
        end
    end
end, 100, 0)

addEventHandler("onClientKey", root, function()
    lastActiveTick = getTickCount()
    if isPlayingIdleAnim then
        cancelIdleAnim()
    end
end)

setTimer(function()
    if isPlayingIdleAnim then
        return
    end
    if isPedInVehicle(localPlayer) or isPedDead(localPlayer) or isElementInWater(localPlayer) or isCursorShowing() then
        lastActiveTick = getTickCount()
        return
    end
    if hasPedAnimationLayers(localPlayer) or getPedWeapon(localPlayer) ~= 0 then
        lastActiveTick = getTickCount()
        return
    end
    if getTickCount() - lastActiveTick >= 30000 then
        local choices = {"stretch", "shldr"}
        local chosen = choices[math.random(1, #choices)]
        playIdleAnim(chosen)
    end
end, 500, 0)

addCommandHandler("idle", function()
    if isPlayingIdleAnim then
        cancelIdleAnim()
    else
        playIdleAnim("stretch")
    end
end)

addCommandHandler("crossarms", function()
    if isPlayingIdleAnim then
        cancelIdleAnim()
    else
        playIdleAnim("shldr")
    end
end)

addCommandHandler("kollar", function()
    executeCommandHandler("crossarms")
end)

function isAnimationsEnabled()
    return isCustomAnimsEnabled
end

function setAnimationsEnabled(state)
    if state == isCustomAnimsEnabled then
        return
    end
    isCustomAnimsEnabled = state
    if isCustomAnimsEnabled then
        applyToAll()
    else
        restoreAll()
        cancelIdleAnim()
    end
end