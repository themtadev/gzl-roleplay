JobServer = {}

local activeJobs = {}
local playerJobMap = {}
local cleaningSessions = {}
local function nearPoint(player, point, radius)
    if not isElement(player) or getElementType(player) ~= "player" then return false end
    if getElementDimension(player) ~= 0 or getElementInterior(player) ~= 0 then return false end
    local x, y, z = getElementPosition(player)
    return getDistanceBetweenPoints3D(x, y, z, point.x, point.y, point.z) <= radius
end

local function findBuildingById(bId)
    for _, b in ipairs(Config.Buildings) do
        if b.id == bId then
            return b
        end
    end
    return nil
end

function JobServer.getJob(player)
    local jobId = playerJobMap[player]
    return jobId and activeJobs[jobId] or nil
end

function JobServer.startJob(leader, buildingId)
    if playerJobMap[leader] or not nearPoint(leader, Config.DepotLocation.marker, 8) then return end
    local building = findBuildingById(buildingId)
    if not building then return end

    local team = LobbyServer.getTeam(leader)
    if team and team.leader ~= leader then return end
    local members = {}
    local seen = {}
    for _, member in ipairs(team and team.members or {leader}) do
        if seen[member] or playerJobMap[member] or not nearPoint(member, Config.DepotLocation.marker, 30) then return end
        seen[member] = true
        members[#members + 1] = member
    end
    if #members == 0 or #members > Config.MaxGroupMembers then return end

    local jobId = "job_" .. tostring(getTickCount()) .. "_" .. tostring(math.random(1000, 9999))

    local vSpawn = Config.DepotLocation.vehicleSpawn
    local veh = createVehicle(Config.JobVehicleModel, vSpawn.x, vSpawn.y, vSpawn.z, 0, 0, vSpawn.rot)
    if isElement(veh) then
        setElementData(veh, "window_cleaning:jobId", jobId)
    end

    local liftObj = nil
    if building.hasLift and building.lift then
        liftObj = LiftServer.createLift(jobId, building.lift)
    end

    local windowsCopy = {}
    for _, w in ipairs(building.windows) do
        table.insert(windowsCopy, {
            id = w.id,
            x = w.x,
            y = w.y,
            z = w.z,
            isCleaned = false
        })
    end

    local jobData = {
        id = jobId,
        buildingId = building.id,
        buildingName = building.name,
        leader = leader,
        members = members,
        vehicle = veh,
        liftObject = liftObj,
        hasLift = building.hasLift,
        liftConfig = building.lift,
        windows = windowsCopy,
        totalWindows = #windowsCopy,
        cleanedWindows = 0,
        parkingPos = building.vehicleParking
    }

    activeJobs[jobId] = jobData

    for _, member in ipairs(members) do
        if isElement(member) then
            playerJobMap[member] = jobId
            setElementData(member, "window_cleaning:originalSkin", getElementModel(member))
            setElementModel(member, Config.WorkerSkin)

            triggerClientEvent(member, "windowCleaning:clientJobStarted", member, {
                buildingId = building.id,
                buildingName = building.name,
                totalWindows = #windowsCopy,
                cleanedWindows = 0,
                parkingPos = building.vehicleParking,
                windows = windowsCopy
            })

            if isElement(liftObj) then
                triggerClientEvent(member, "windowCleaning:clientSyncLift", member, liftObj, building.lift)
            end
        end
    end
end

function JobServer.finishJob(player)
    local job = JobServer.getJob(player)
    if not job then return end
    if job.finishing or job.cleanedWindows < job.totalWindows then return end
    if not nearPoint(player, Config.DepotLocation.vehicleReturn, 8) then return end
    job.finishing = true

    local memberCount = #job.members
    local groupBonusMultiplier = 1.0 + (math.max(0, memberCount - 1) * Config.Economy.groupMultiplierPerMember)
    local baseTotal = (job.totalWindows * Config.Economy.basePayPerWindow) + Config.Economy.completionBonus
    local finalSalary = math.floor(baseTotal * groupBonusMultiplier)

    for _, member in ipairs(job.members) do
        if isElement(member) then
            local origSkin = getElementData(member, "window_cleaning:originalSkin")
            if origSkin then
                setElementModel(member, origSkin)
                removeElementData(member, "window_cleaning:originalSkin")
            end

            local currentMoney = tonumber(getElementData(member, "character:money") or getPlayerMoney(member)) or 0
            local newMoney = currentMoney + finalSalary
            setElementData(member, "character:money", newMoney, "broadcast", "deny")
            setElementData(member, "char:money", newMoney, "broadcast", "deny")
            setPlayerMoney(member, newMoney)
            if exports.gzl_characters and exports.gzl_characters.saveCharacter then
                exports.gzl_characters:saveCharacter(member)
            end

            cleaningSessions[member] = nil
            playerJobMap[member] = nil
            triggerClientEvent(member, "windowCleaning:clientJobFinished", member)
        end
    end

    if isElement(job.vehicle) then
        destroyElement(job.vehicle)
    end
    LiftServer.destroyLift(job.id)
    activeJobs[job.id] = nil
end

function JobServer.handlePlayerDisconnect(player)
    cleaningSessions[player] = nil
    local job = JobServer.getJob(player)
    if not job then return end

    playerJobMap[player] = nil
    for idx, m in ipairs(job.members) do
        if m == player then
            table.remove(job.members, idx)
            break
        end
    end

    if #job.members == 0 then
        if isElement(job.vehicle) then destroyElement(job.vehicle) end
        LiftServer.destroyLift(job.id)
        activeJobs[job.id] = nil
    end
end

addEvent("windowCleaning:startJob", true)
addEventHandler("windowCleaning:startJob", root, function(buildingId)
    local ply = client or source
    JobServer.startJob(ply, buildingId)
end)

addEvent("windowCleaning:submitCleanWindow", true)
addEventHandler("windowCleaning:submitCleanWindow", root, function(windowId)
    local ply = client or source
    local job = JobServer.getJob(ply)
    if not job then return end

    local targetWin = nil
    for _, w in ipairs(job.windows) do
        if w.id == windowId and not w.isCleaned then
            targetWin = w
            break
        end
    end

    if not targetWin then return end
    local session = cleaningSessions[ply]
    if not session or session.window ~= windowId or session.job ~= job.id then return end
    local elapsed = getTickCount() - session.started
    if elapsed < 1000 or elapsed > 120000 or not nearPoint(ply, targetWin, 6) then return end
    cleaningSessions[ply] = nil

    local px, py, pz = getElementPosition(ply)
    local dist = getDistanceBetweenPoints3D(px, py, pz, targetWin.x, targetWin.y, targetWin.z)
    if dist > 6.0 then return end

    targetWin.isCleaned = true
    job.cleanedWindows = job.cleanedWindows + 1

    for _, member in ipairs(job.members) do
        if isElement(member) then
            triggerClientEvent(member, "windowCleaning:clientWindowStatusUpdated", member, windowId, true, job.cleanedWindows)
        end
    end
end)

addEvent("windowCleaning:submitFinishJob", true)
addEventHandler("windowCleaning:submitFinishJob", root, function()
    local ply = client or source
    JobServer.finishJob(ply)
end)

addEvent("windowCleaning:moveLift", true)
addEventHandler("windowCleaning:moveLift", root, function(direction)
    local ply = client or source
    local job = JobServer.getJob(ply)
    if not job or not job.hasLift then return end
    LiftServer.handleMove(ply, job.id, direction)
end)

addEvent("windowCleaning:startAnimation", true)
addEventHandler("windowCleaning:startAnimation", root, function(windowId)
    local ply = client
    if not ply or source ~= ply or isPedDead(ply) or isPedInVehicle(ply) or isElementFrozen(ply) then return end
    local job = JobServer.getJob(ply)
    if not job then return end
    for _, window in ipairs(job.windows) do
        if window.id == windowId and not window.isCleaned and nearPoint(ply, window, 6) then
            cleaningSessions[ply] = {job = job.id, window = windowId, started = getTickCount(), frozen = true}
            setPedAnimation(ply, "SCRATCHING", "sctratch", -1, true, false, false)
            setElementFrozen(ply, true)
            return
        end
    end
end)

addEvent("windowCleaning:stopAnimation", true)
addEventHandler("windowCleaning:stopAnimation", root, function()
    local ply = client
    local session = cleaningSessions[ply]
    if not ply or source ~= ply or not session or not session.frozen then return end
    session.frozen = false
    setPedAnimation(ply)
    setElementFrozen(ply, false)
end)