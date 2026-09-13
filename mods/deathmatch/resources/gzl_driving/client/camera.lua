
local screenW, screenH = guiGetScreenSize()
local centerW, centerH = math.floor(screenW * 0.5), math.floor(screenH * 0.5)

local isCamEnabled = true
local isCamActive = false

local camModes = {
    [1] = { dist = 4.6, height = 1.35, pitch = 7.0 },
    [2] = { dist = 6.0, height = 1.65, pitch = 9.0 },
    [3] = { dist = 7.6, height = 2.05, pitch = 11.0 }
}
local currentModeIndex = 2

local curCamX, curCamY, curCamZ = nil, nil, nil
local curTargetX, curTargetY, curTargetZ = nil, nil, nil
local curYaw = 0
local curPitch = 9.0
local curDist = 6.0
local curFOV = 72.0

local mouseYaw = 0
local mousePitch = 0
local mouseSensitivity = 0.32
local lastMouseMoveTick = 0
local autoRecenterDelay = 2600

local isLookingBack = false

local function clamp(val, minV, maxV)
    return math.max(minV, math.min(maxV, val))
end

local function getAngleDiff(target, source)
    local diff = (target - source) % 360
    if diff > 180 then diff = diff - 360 end
    if diff < -180 then diff = diff + 360 end
    return diff
end

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function isTxAdminOpen()
    if exports.gzl_txadmin and exports.gzl_txadmin.isTxAdminOpen then
        return exports.gzl_txadmin:isTxAdminOpen()
    end
    return false
end

local function isFPSActive()
    if exports.gzl_firstperson and exports.gzl_firstperson.isFirstPersonActive then
        return exports.gzl_firstperson:isFirstPersonActive()
    end
    return false
end

local function showDrivingNotification(msg)
    if exports.gzl_ui and exports.gzl_ui.showToast then
        exports.gzl_ui:showToast(msg)
    else
        outputChatBox("#00f5a0[FiveM Cam]#ffffff " .. msg, 255, 255, 255, true)
    end
end

local lastTick = getTickCount()

local function updateFiveMCamera()
    local now = getTickCount()
    local dt = math.min(0.1, (now - lastTick) / 1000)
    lastTick = now

    local veh = getPedOccupiedVehicle(localPlayer)
    if not veh or not isCamEnabled or isFPSActive() or isTxAdminOpen() then
        if isCamActive then
            setCameraTarget(localPlayer)
            setCameraFieldOfView("player", 70)
            isCamActive = false
        end
        return
    end

    local vType = getVehicleType(veh)

    if vType ~= "Automobile" and vType ~= "Monster Truck" and vType ~= "Bike" and vType ~= "Quad" and vType ~= "BMX" then
        if isCamActive then
            setCameraTarget(localPlayer)
            isCamActive = false
        end
        return
    end

    isCamActive = true

    local vx, vy, vz = getElementPosition(veh)
    local rx, ry, rz = getElementRotation(veh)

    local targetHeightOffset = 0.55
    if vType == "Monster Truck" or vType == "Quad" then
        targetHeightOffset = 0.85
    end

    local rawTargetX = vx
    local rawTargetY = vy
    local rawTargetZ = vz + targetHeightOffset

    if not curTargetX then
        curTargetX, curTargetY, curTargetZ = rawTargetX, rawTargetY, rawTargetZ
        curYaw = rz
    end

    local targetLerpSpeed = 16.0 * dt
    curTargetX = lerp(curTargetX, rawTargetX, math.min(1.0, targetLerpSpeed))
    curTargetY = lerp(curTargetY, rawTargetY, math.min(1.0, targetLerpSpeed))
    curTargetZ = lerp(curTargetZ, rawTargetZ, math.min(1.0, targetLerpSpeed))

    local velX, velY, velZ = getElementVelocity(veh)
    local speedKmh = ((velX * velX + velY * velY + velZ * velZ) ^ 0.5) * 180

    local radZ = math.rad(rz)
    local fwdX = -math.sin(radZ)
    local fwdY = math.cos(radZ)
    local forwardSpeed = velX * fwdX + velY * fwdY
    local isReversing = (forwardSpeed < -0.05 and speedKmh > 8)

    local vehHeading = rz
    local desiredYaw = vehHeading

    if isReversing then

        desiredYaw = (vehHeading + 180) % 360
    elseif speedKmh > 10 then
        local moveHeading = (math.deg(math.atan2(-velX, velY))) % 360
        local slip = getAngleDiff(moveHeading, vehHeading)

        local centrifugalFactor = clamp(slip * 0.35, -28, 28)
        desiredYaw = vehHeading + centrifugalFactor
    end

    if isLookingBack then
        desiredYaw = (vehHeading + 180) % 360
        curYaw = desiredYaw
    else

        local yawDiff = getAngleDiff(desiredYaw, curYaw)
        local absYawDiff = math.abs(yawDiff)

        local catchUpBoost = 1.0
        if absYawDiff > 50 then
            catchUpBoost = 1.0 + ((absYawDiff - 50) / 70) * 2.5
        end

        local baseRate = (speedKmh > 15) and 6.8 or 4.2
        local yawFollowRate = baseRate * catchUpBoost * dt
        curYaw = (curYaw + yawDiff * math.min(1.0, yawFollowRate)) % 360
    end

    if not isCursorShowing() and not isChatBoxInputActive() and not isMainMenuActive() then

        if speedKmh > 6 and (now - lastMouseMoveTick) > autoRecenterDelay then
            local decayRate = 3.0 * dt
            mouseYaw = lerp(mouseYaw, 0, math.min(1.0, decayRate))
            mousePitch = lerp(mousePitch, 0, math.min(1.0, decayRate))
        end
    end

    local activePreset = camModes[currentModeIndex] or camModes[2]
    local targetDist = activePreset.dist
    local targetPitch = activePreset.pitch + mousePitch

    local accPitch = clamp(velZ * 20, -5, 5)
    targetPitch = targetPitch + accPitch

    curPitch = lerp(curPitch, clamp(targetPitch, -35, 75), math.min(1.0, 10.0 * dt))

    local finalYaw = (curYaw - mouseYaw) % 360
    local radYaw = math.rad(finalYaw)
    local radPitch = math.rad(curPitch)

    local speedFovBoost = clamp((speedKmh / 160) * 12.0, 0, 14.0)
    local targetFOV = 70.0 + speedFovBoost
    curFOV = lerp(curFOV, targetFOV, math.min(1.0, 6.0 * dt))

    local cosPitch = math.cos(radPitch)
    local sinPitch = math.sin(radPitch)
    local sinYaw = math.sin(radYaw)
    local cosYaw = math.cos(radYaw)

    local offsetX = sinYaw * targetDist * cosPitch
    local offsetY = -cosYaw * targetDist * cosPitch
    local offsetZ = sinPitch * targetDist + activePreset.height

    local idealCamX = curTargetX + offsetX
    local idealCamY = curTargetY + offsetY
    local idealCamZ = curTargetZ + offsetZ

    local hit, hitX, hitY, hitZ = processLineOfSight(
        curTargetX, curTargetY, curTargetZ + 0.2,
        idealCamX, idealCamY, idealCamZ,
        true,
        true,
        false,
        true,
        true,
        false,
        false,
        true,
        veh
    )

    local finalCamX, finalCamY, finalCamZ = idealCamX, idealCamY, idealCamZ
    if hit then

        local dirX = curTargetX - hitX
        local dirY = curTargetY - hitY
        local dirZ = (curTargetZ + 0.2) - hitZ
        local len = ((dirX * dirX + dirY * dirY + dirZ * dirZ) ^ 0.5)
        if len > 0.001 then
            finalCamX = hitX + (dirX / len) * 0.35
            finalCamY = hitY + (dirY / len) * 0.35
            finalCamZ = hitZ + (dirZ / len) * 0.35
        else
            finalCamX, finalCamY, finalCamZ = hitX, hitY, hitZ
        end
    end

    if not curCamX then
        curCamX, curCamY, curCamZ = finalCamX, finalCamY, finalCamZ
    else
        local camSmoothSpeed = 18.0 * dt
        curCamX = lerp(curCamX, finalCamX, math.min(1.0, camSmoothSpeed))
        curCamY = lerp(curCamY, finalCamY, math.min(1.0, camSmoothSpeed))
        curCamZ = lerp(curCamZ, finalCamZ, math.min(1.0, camSmoothSpeed))
    end

    local lookAtX = curTargetX
    local lookAtY = curTargetY
    local lookAtZ = curTargetZ + 0.15

    setCameraMatrix(curCamX, curCamY, curCamZ, lookAtX, lookAtY, lookAtZ, 0, curFOV)
end

local function handleCursorMove(rx, ry, ax, ay)
    if not isCamActive or isCursorShowing() or isChatBoxInputActive() or isMainMenuActive() or isTxAdminOpen() or isFPSActive() then
        return
    end

    local diffX = ax - centerW
    local diffY = ay - centerH

    if math.abs(diffX) > 1 or math.abs(diffY) > 1 then
        mouseYaw = (mouseYaw + diffX * mouseSensitivity) % 360
        mousePitch = clamp(mousePitch - diffY * mouseSensitivity, -30, 45)
        lastMouseMoveTick = getTickCount()
        setCursorPosition(centerW, centerH)
    end
end

local function handleCycleCameraKey()
    if not isCamActive or isChatBoxInputActive() or isMainMenuActive() or isTxAdminOpen() or isFPSActive() then
        return
    end

    currentModeIndex = currentModeIndex + 1
    if currentModeIndex > #camModes then
        currentModeIndex = 1
    end

    local modeNames = { [1] = "Yakın", [2] = "Normal (FiveM)", [3] = "Uzak" }
    showDrivingNotification("Kamera Modu: " .. (modeNames[currentModeIndex] or "Normal"))
    playSoundFrontEnd(41)
end

local function handleLookBackKey(key, state)
    if not isCamActive or isFPSActive() then return end
    isLookingBack = (state == "down")
end

addEventHandler("onClientPreRender", root, updateFiveMCamera)
addEventHandler("onClientCursorMove", root, handleCursorMove)

bindKey("v", "down", handleCycleCameraKey)
bindKey("c", "both", handleLookBackKey)
bindKey("mouse3", "both", handleLookBackKey)
bindKey("num_1", "both", handleLookBackKey)

function toggleFiveMCamera(forcedState)
    if forcedState ~= nil then
        isCamEnabled = forcedState
    else
        isCamEnabled = not isCamEnabled
    end

    if not isCamEnabled then
        setCameraTarget(localPlayer)
        setCameraFieldOfView("player", 70)
        curCamX, curCamY, curCamZ = nil, nil, nil
        curTargetX, curTargetY, curTargetZ = nil, nil, nil
        isCamActive = false
        showDrivingNotification("FiveM Kamera: #ff4757KAPALI")
    else
        showDrivingNotification("FiveM Kamera: #2ed573AÇIK")
    end
end
addCommandHandler("fivemcam", toggleFiveMCamera)

function isFiveMCameraActive()
    return isCamActive
end

function setFiveMCameraActive(state)
    toggleFiveMCamera(state)
end

local function resetCameraToPlayer()
    if isCamActive then
        setCameraTarget(localPlayer)
        setCameraFieldOfView("player", 70)
        curCamX, curCamY, curCamZ = nil, nil, nil
        curTargetX, curTargetY, curTargetZ = nil, nil, nil
        mouseYaw = 0
        mousePitch = 0
        isCamActive = false
    end
end

addEventHandler("onClientPlayerVehicleExit", localPlayer, resetCameraToPlayer)
addEventHandler("onClientPlayerWasted", localPlayer, resetCameraToPlayer)

addEventHandler("onClientResourceStop", resourceRoot, function()
    setCameraTarget(localPlayer)
    setCameraFieldOfView("player", 70)
    unbindKey("v", "down", handleCycleCameraKey)
    unbindKey("c", "both", handleLookBackKey)
    unbindKey("mouse3", "both", handleLookBackKey)
    unbindKey("num_1", "both", handleLookBackKey)
end)