addEventHandler("onClientResourceStart", resourceRoot, function()
    fadeCamera(true, Config.FadeInDuration)
    setAmbientSoundEnabled("general", true)
    setAmbientSoundEnabled("gunfire", true)
end)

local function isResRunning(name)
    local res = getResourceFromName(name)
    return res and getResourceState(res) == "running"
end

function isPlayerTyping(allowPhoneMovement)
    if isChatBoxInputActive and isChatBoxInputActive() then return true end
    if isConsoleActive and isConsoleActive() then return true end
    if guiGetInputEnabled and guiGetInputEnabled() then return true end
    if isResRunning("gzl_ui") and exports.gzl_ui.getActiveEditBox and exports.gzl_ui:getActiveEditBox() then return true end
    if isResRunning("gzl_chat") and exports.gzl_chat.isChatInputOpen and exports.gzl_chat:isChatInputOpen() then return true end
    if isResRunning("gzl_atm") and exports.gzl_atm.isATMOpen and exports.gzl_atm:isATMOpen() then return true end
    if isResRunning("high_phone") and exports.high_phone.getActiveEditBox and exports.high_phone:getActiveEditBox() then return true end
    if isResRunning("high_phone") and exports.high_phone.isKeypadTypingActive and exports.high_phone:isKeypadTypingActive() then return true end
    if isResRunning("gzl_phone") and exports.gzl_phone.isPhoneOpenState and exports.gzl_phone:isPhoneOpenState() then
        if not allowPhoneMovement or (exports.gzl_phone.isKeypadTypingActive and exports.gzl_phone:isKeypadTypingActive()) then return true end
    end
    if isResRunning("cylex_phone") and exports.cylex_phone.isPhoneOpenState and exports.cylex_phone:isPhoneOpenState() then
        if not allowPhoneMovement or (exports.cylex_phone.isKeypadTypingActive and exports.cylex_phone:isKeypadTypingActive()) then return true end
    end
    if isResRunning("gzl_pd") and exports.gzl_pd.isPDTabletOpen and exports.gzl_pd:isPDTabletOpen() then return true end
    return false
end
local isTyping = isPlayerTyping

local function toggleCursor()
    if isTyping() then return end
    local newState = not isCursorShowing()
    showCursor(newState)
    pcall(guiSetInputMode, "allow_binds")
end

addCommandHandler("cursor", toggleCursor)

addEventHandler("onClientKey", root, function(button, press)
    if press and button == "m" then
        toggleCursor()
    end
end)

local isWalkByDefaultEnabled = Config.DefaultWalkEnabled ~= false

local function handleWalkByDefault()
    if not isWalkByDefaultEnabled then
        return
    end

    if isPedInVehicle(localPlayer) or isPedDead(localPlayer) or isElementInWater(localPlayer) then
        return
    end

    local isMoving = getPedControlState(localPlayer, "forwards") or getPedControlState(localPlayer, "backwards") or getPedControlState(localPlayer, "left") or getPedControlState(localPlayer, "right")
    if not isMoving and not getPedControlState(localPlayer, "walk") and not getPedControlState(localPlayer, "sprint") then return end

    if isTyping(true) then
        return
    end

    local isShiftPressed = getKeyState("lshift") or getKeyState("rshift")

    if isShiftPressed then
        setPedControlState(localPlayer, "walk", false)
        if isMoving then
            setPedControlState(localPlayer, "sprint", true)
            if not getKeyState("space") then
                setPedControlState(localPlayer, "jump", false)
            end
        else
            setPedControlState(localPlayer, "sprint", false)
        end
    else
        setPedControlState(localPlayer, "sprint", false)
        if isMoving then
            setPedControlState(localPlayer, "walk", true)
        else
            setPedControlState(localPlayer, "walk", false)
        end
    end
end

addEventHandler("onClientPreRender", root, handleWalkByDefault)

addEventHandler("onClientResourceStop", resourceRoot, function()
    setPedControlState(localPlayer, "walk", false)
    setPedControlState(localPlayer, "sprint", false)
end)

addCommandHandler("walkmode", function()
    isWalkByDefaultEnabled = not isWalkByDefaultEnabled
    setPedControlState(localPlayer, "walk", false)
    setPedControlState(localPlayer, "sprint", false)
    if isResRunning("gzl_ui") and exports.gzl_ui.showNotification then
        if isWalkByDefaultEnabled then
            exports.gzl_ui:showNotification("Varsayilan Yurume: Aktif (Shift ile kosu)", "success")
        else
            exports.gzl_ui:showNotification("Varsayilan Yurume: Devre Disi (Klasik GTA)", "info")
        end
    else
        if isWalkByDefaultEnabled then
            outputChatBox("[GZL-CORE] Varsayilan yurume modu aktif edildi (Shift ile kosu).", 0, 255, 120)
        else
            outputChatBox("[GZL-CORE] Varsayilan yurume modu devre disi birakildi (Klasik GTA).", 255, 180, 0)
        end
    end
end)

function isWalkByDefaultActive()
    return isWalkByDefaultEnabled
end

function setWalkByDefaultActive(state)
    isWalkByDefaultEnabled = not not state
    if not isWalkByDefaultEnabled then
        setPedControlState(localPlayer, "walk", false)
        setPedControlState(localPlayer, "sprint", false)
    end
end