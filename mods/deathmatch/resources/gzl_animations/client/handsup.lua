
local function isBusy()
    return isChatBoxInputActive()
        or isCursorShowing()
        or isMainMenuActive()
        or (getElementData(localPlayer, 'gzl_chat:isOpen') == true)
        or isPedInVehicle(localPlayer)
        or isPedDead(localPlayer)
        or isElementInWater(localPlayer)
end

bindKey('x', 'both', function(key, state)
    if state == 'down' then
        if isBusy() then return end

        if not getElementData(localPlayer, 'apontar') then
            setElementData(localPlayer, 'apontar', true)
            triggerServerEvent('onClientSyncVOZ', localPlayer)
        end
    else
        if getElementData(localPlayer, 'apontar') then
            setElementData(localPlayer, 'apontar', false)
            triggerServerEvent('onClientSyncVOZparar', localPlayer)
        end
    end
end)

addEventHandler('onClientResourceStop', resourceRoot, function()
    if getElementData(localPlayer, 'apontar') then
        setElementData(localPlayer, 'apontar', false)
        setPedAnimation(localPlayer, false)
    end
end)