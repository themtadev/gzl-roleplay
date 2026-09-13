local isLocalCuffed = false
local isLocalDragged = false

local function setCuffedState(state)
    isLocalCuffed = (state == true)
    if isLocalCuffed then
        setPedWeaponSlot(localPlayer, 0)
        toggleControl("fire", false)
        toggleControl("aim_weapon", false)
        toggleControl("next_weapon", false)
        toggleControl("previous_weapon", false)
        toggleControl("jump", false)
        toggleControl("sprint", false)
        toggleControl("enter_exit", false)
    else
        toggleControl("fire", true)
        toggleControl("aim_weapon", true)
        toggleControl("next_weapon", true)
        toggleControl("previous_weapon", true)
        toggleControl("jump", true)
        toggleControl("sprint", true)
        toggleControl("enter_exit", true)
    end
end

local function setDraggedState(state)
    isLocalDragged = (state == true)
    toggleControl("forwards", not isLocalDragged)
    toggleControl("backwards", not isLocalDragged)
    toggleControl("left", not isLocalDragged)
    toggleControl("right", not isLocalDragged)
    toggleControl("jump", not isLocalDragged)
    toggleControl("sprint", not isLocalDragged)
    toggleControl("crouch", not isLocalDragged)
    toggleControl("enter_exit", not isLocalDragged)
end

addEvent("pd:onCuffStateChanged", true)
addEventHandler("pd:onCuffStateChanged", root, function(state)
    setCuffedState(state)
end)

addEventHandler("onClientElementDataChange", localPlayer, function(dataName, oldValue)
    if dataName == "isCuffed" or dataName == "cuffed" then
        local newVal = getElementData(localPlayer, dataName)
        setCuffedState(newVal == true)
    elseif dataName == "isDragged" then
        local newVal = getElementData(localPlayer, dataName)
        setDraggedState(newVal == true)
    end
end)

addEventHandler("onClientPreRender", root, function()
    if isLocalCuffed then
        setPedWeaponSlot(localPlayer, 0)
    end
end)

addEventHandler("onClientResourceStart", resourceRoot, function()
    if getElementData(localPlayer, "isCuffed") == true or getElementData(localPlayer, "cuffed") == true then
        setCuffedState(true)
    end
    if getElementData(localPlayer, "isDragged") == true then
        setDraggedState(true)
    end
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    if isLocalCuffed then
        setCuffedState(false)
    end
    if isLocalDragged then
        setDraggedState(false)
    end
end)

function isPlayerCuffed(player)
    player = player or localPlayer
    if not isElement(player) then return false end
    return (getElementData(player, "isCuffed") == true or getElementData(player, "cuffed") == true)
end

function isPlayerDragged(player)
    player = player or localPlayer
    if not isElement(player) then return false end
    return (getElementData(player, "isDragged") == true)
end