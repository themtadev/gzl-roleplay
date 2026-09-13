
bindKey("j", "down", function()
    local veh = getPedOccupiedVehicle(localPlayer)
    if not isElement(veh) then return end
    if getVehicleOccupant(veh, 0) == localPlayer then
        triggerServerEvent("gzl_vehicles:toggleEngine", localPlayer)
    end
end)