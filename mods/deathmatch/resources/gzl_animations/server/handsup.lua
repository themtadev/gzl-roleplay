
addEvent('onClientSyncVOZ', true)
addEventHandler('onClientSyncVOZ', root, function()
    local p = client or source
    if not isElement(p) or isPedDead(p) or isPedInVehicle(p) then return end

    setElementData(p, 'apontar', true)
    setElementData(p, 'handsup', true)

    if getElementData(p, 'gzl:sitting') then
        setElementData(p, 'gzl:sitting', nil)
        triggerClientEvent(root, 'gzl_animations:syncSitAnim', p, p, nil, false)
    end

    setPedAnimation(p, 'GHANDS', 'gsign1', 0, true, false, false)
    setTimer(setPedAnimationProgress, 100, 1, p, 'gsign1', 1.16)
    setTimer(setPedAnimationSpeed, 1500, 1, p, 'gsign1', 0)
end)

addEvent('onClientSyncVOZparar', true)
addEventHandler('onClientSyncVOZparar', root, function()
    local p = client or source
    if not isElement(p) then return end

    setElementData(p, 'apontar', false)
    setElementData(p, 'handsup', nil)

    setTimer(setPedAnimation, 100, 1, p, 'GHANDS', 'gsign1', 5000, false, false, false)
    setTimer(setPedAnimation, 250, 1, p, nil)
end)

local function toggleHandsup(player)
    if not isElement(player) then return end
    if getElementData(player, 'apontar') then
        triggerEvent('onClientSyncVOZparar', player)
    else
        triggerEvent('onClientSyncVOZ', player)
    end
end

addCommandHandler('elkaldir', toggleHandsup, false, false)
addCommandHandler('teslim', toggleHandsup, false, false)
addCommandHandler('handsup', toggleHandsup, false, false)

addEventHandler('onPlayerQuit', root, function()
    setElementData(source, 'apontar', false)
    setElementData(source, 'handsup', nil)
end)

addEventHandler('onPlayerWasted', root, function()
    setElementData(source, 'apontar', false)
    setElementData(source, 'handsup', nil)
end)

addEventHandler('onPlayerVehicleEnter', root, function()
    setElementData(source, 'apontar', false)
    setElementData(source, 'handsup', nil)
    setPedAnimation(source, false)
end)