local depotBlip = nil
local depotMarker = nil
local returnMarker = nil
local gpsBlip = nil

local function createDepotElements()
    local d = Config.DepotLocation
    depotBlip = createBlip(d.marker.x, d.marker.y, d.marker.z, 42, 2, 255, 0, 0, 255, 0, 300)
    depotMarker = createMarker(d.marker.x, d.marker.y, d.marker.z - 1.0, "cylinder", 1.5, 56, 189, 248, 150)
end

local function syncRadarRoute()
    local jobData = JobHUD.getJobData()
    if not jobData then
        if exports.gzl_radar and exports.gzl_radar.clearWaypoint then
            exports.gzl_radar:clearWaypoint()
        end
        return
    end

    local totalWins = jobData.totalWindows or 1
    local cleanedWins = jobData.cleanedWindows or 0

    if cleanedWins >= totalWins then
        local ret = Config.DepotLocation.vehicleReturn
        if exports.gzl_radar and exports.gzl_radar.setWaypoint then
            exports.gzl_radar:setWaypoint(ret.x, ret.y)
        end
    else
        if jobData.parkingPos and exports.gzl_radar and exports.gzl_radar.setWaypoint then
            exports.gzl_radar:setWaypoint(jobData.parkingPos.x, jobData.parkingPos.y)
        end
    end
end

local function cleanupJobVisuals()
    if isElement(gpsBlip) then
        destroyElement(gpsBlip)
        gpsBlip = nil
    end
    if isElement(returnMarker) then
        destroyElement(returnMarker)
        returnMarker = nil
    end
    if exports.gzl_radar and exports.gzl_radar.clearWaypoint then
        exports.gzl_radar:clearWaypoint()
    end
    LiftClient.clearLift()
    JobHUD.clearJobData()
    CleaningGame.stop(false)
end

addEventHandler("onClientResourceStart", resourceRoot, function()
    createDepotElements()
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    cleanupJobVisuals()
    if isElement(depotBlip) then destroyElement(depotBlip) end
    if isElement(depotMarker) then destroyElement(depotMarker) end
end)

addEventHandler("onClientPlayerVehicleEnter", localPlayer, function(veh, seat)
    if seat == 0 then
        syncRadarRoute()
    end
end)

addEventHandler("onClientRender", root, function()
    JobHUD.render()
    LiftClient.render()
    CleaningGame.render()
    LobbyUI.render()
end)

addEventHandler("onClientKey", root, function(button, press)
    if not press or button ~= "e" then return end
    if CleaningGame.isActive() or LobbyUI.isOpen() then return end

    local jobData = JobHUD.getJobData()
    if not jobData then
        local px, py, pz = getElementPosition(localPlayer)
        local d = Config.DepotLocation.marker
        local dist = getDistanceBetweenPoints3D(px, py, pz, d.x, d.y, d.z)
        if dist < 3.0 then
            triggerServerEvent("windowCleaning:requestOpenLobby", localPlayer)
            return
        end
    else
        local nearbyWin = JobHUD.getNearbyWindow()
        if nearbyWin and not nearbyWin.isCleaned then
            CleaningGame.start(nearbyWin)
            return
        end

        local totalWins = jobData.totalWindows or 1
        local cleanedWins = jobData.cleanedWindows or 0
        if cleanedWins >= totalWins then
            local px, py, pz = getElementPosition(localPlayer)
            local ret = Config.DepotLocation.vehicleReturn
            local dist = getDistanceBetweenPoints3D(px, py, pz, ret.x, ret.y, ret.z)
            if dist < (ret.radius + 1.0) then
                triggerServerEvent("windowCleaning:submitFinishJob", localPlayer)
                return
            end
        end
    end
end)

addEvent("windowCleaning:clientOpenLobby", true)
addEventHandler("windowCleaning:clientOpenLobby", root, function(lobbyData, nearbyPlayers)
    LobbyUI.open(lobbyData, nearbyPlayers)
end)

addEvent("windowCleaning:clientUpdateLobby", true)
addEventHandler("windowCleaning:clientUpdateLobby", root, function(lobbyData, nearbyPlayers)
    LobbyUI.updateData(lobbyData, nearbyPlayers)
end)

addEvent("windowCleaning:clientJobStarted", true)
addEventHandler("windowCleaning:clientJobStarted", root, function(jobData)
    cleanupJobVisuals()
    JobHUD.setJobData(jobData)

    if jobData.parkingPos then
        gpsBlip = createBlip(jobData.parkingPos.x, jobData.parkingPos.y, jobData.parkingPos.z, 41, 2, 14, 165, 233, 255, 0, 9999)
    end
    syncRadarRoute()
end)

addEvent("windowCleaning:clientWindowStatusUpdated", true)
addEventHandler("windowCleaning:clientWindowStatusUpdated", root, function(windowId, isCleaned, totalCleaned)
    local jobData = JobHUD.getJobData()
    if not jobData or not jobData.windows then return end

    for _, win in ipairs(jobData.windows) do
        if win.id == windowId then
            win.isCleaned = isCleaned
            break
        end
    end
    jobData.cleanedWindows = totalCleaned

    if totalCleaned >= jobData.totalWindows then
        Audio.playContractComplete()
        if isElement(gpsBlip) then
            destroyElement(gpsBlip)
        end
        local ret = Config.DepotLocation.vehicleReturn
        gpsBlip = createBlip(ret.x, ret.y, ret.z, 41, 2, 34, 197, 94, 255, 0, 9999)
        returnMarker = createMarker(ret.x, ret.y, ret.z - 1.0, "cylinder", ret.radius, 34, 197, 94, 150)
        syncRadarRoute()
    end
end)

addEvent("windowCleaning:clientJobFinished", true)
addEventHandler("windowCleaning:clientJobFinished", root, function()
    cleanupJobVisuals()
end)

addEvent("windowCleaning:clientSyncLift", true)
addEventHandler("windowCleaning:clientSyncLift", root, function(liftElement, liftConfig)
    LiftClient.setLiftElement(liftElement, liftConfig)
end)