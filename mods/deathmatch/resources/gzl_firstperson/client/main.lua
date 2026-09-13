local screenW, screenH = guiGetScreenSize()
local centerW, centerH = math.floor(screenW * 0.5), math.floor(screenH * 0.5)

local isFPActive = false
local rotX = 0
local rotY = 0
local mouseSensitivity = 0.15
local lastVehRot = false

local math_rad = math.rad
local math_cos = math.cos
local math_sin = math.sin
local math_max = math.max
local math_min = math.min
local math_floor = math.floor

local fpAlpha = 255
local fpForwardOffset = 0.05
local fpUpOffset = 0.02
local lastGear = nil
local isShifting = false
local shiftStartTick = 0
local shiftDuration = 450
local shiftDirection = 1
local gearComponent = nil
local gearBaseRot = nil

local function triggerGearShift(veh, isUpshift)
    isShifting = true
    shiftStartTick = getTickCount()
    shiftDirection = isUpshift and 1 or -1
    playSoundFrontEnd(41)

    if isElement(veh) and not gearComponent then
        local comps = getVehicleComponents(veh)
        if comps then
            for compName, _ in pairs(comps) do
                local lower = string.lower(compName)
                if string.find(lower, "gear") or string.find(lower, "shifter") or string.find(lower, "vites") or string.find(lower, "stick") then
                    gearComponent = compName
                    local rx, ry, rz = getVehicleComponentRotation(veh, compName, "parent")
                    gearBaseRot = { rx or 0, ry or 0, rz or 0 }
                    break
                end
            end
        end
    end
end

local function isTxAdminOpen()
    if exports.gzl_txadmin and exports.gzl_txadmin.isTxAdminOpen then
        return exports.gzl_txadmin:isTxAdminOpen()
    end
    return false
end

local function showNotification(msg)
    if exports.gzl_ui and exports.gzl_ui.showToast then
        exports.gzl_ui:showToast(msg)
    else
        outputChatBox("#00f5a0[FPS]#ffffff " .. msg, 255, 255, 255, true)
    end
end

local function updateFirstPersonCamera()
    if not isFPActive then return end

    if isTxAdminOpen() then
        return
    end

    local radX = math_rad(rotX)
    local radY = math_rad(rotY)
    local cosY = math_cos(radY)
    local sinY = math_sin(radY)
    local cosX = math_cos(radX)
    local sinX = math_sin(radX)

    local fx = cosY * sinX
    local fy = cosY * cosX
    local fz = sinY

    local veh = getPedOccupiedVehicle(localPlayer)
    if veh then
        local _, _, currentVehRot = getElementRotation(veh)
        if lastVehRot then
            local rotDiff = currentVehRot - lastVehRot
            if rotDiff > 180 then
                rotDiff = rotDiff - 360
            elseif rotDiff < -180 then
                rotDiff = rotDiff + 360
            end
            rotX = (rotX - rotDiff) % 360
        end
        lastVehRot = currentVehRot

        local isDriver = (getVehicleOccupant(veh, 0) == localPlayer)
        if isDriver then
            local currentGear = getVehicleCurrentGear(veh)
            if lastGear ~= nil and currentGear ~= lastGear then
                triggerGearShift(veh, currentGear > lastGear)
            end
            lastGear = currentGear
        else
            lastGear = nil
            isShifting = false
        end

        local hx, hy, hz = getPedBonePosition(localPlayer, 8)
        if not hx then
            local vx, vy, vz = getElementPosition(veh)
            hx, hy, hz = vx, vy, vz + 0.6
        end

        local camX = hx + fx * fpForwardOffset
        local camY = hy + fy * fpForwardOffset
        local camZ = hz + fpUpOffset

        local lookX = camX + fx * 5.0
        local lookY = camY + fy * 5.0
        local lookZ = camZ + fz * 5.0

        setCameraMatrix(camX, camY, camZ, lookX, lookY, lookZ, 0, 72)
        setElementAlpha(localPlayer, fpAlpha)
    else
        lastVehRot = false
        lastGear = nil
        isShifting = false

        local hx, hy, hz = getPedBonePosition(localPlayer, 8)
        if not hx then
            local px, py, pz = getElementPosition(localPlayer)
            hx, hy, hz = px, py, pz + 0.68
        end

        local camX = hx + fx * 0.08
        local camY = hy + fy * 0.08
        local camZ = hz + 0.02

        local lookX = camX + fx * 5.0
        local lookY = camY + fy * 5.0
        local lookZ = camZ + fz * 5.0

        setCameraMatrix(camX, camY, camZ, lookX, lookY, lookZ, 0, 72)

        local isAiming = getPedControlState(localPlayer, "aim_weapon") or getPedControlState(localPlayer, "fire")
        local targetRot = -rotX

        if not isAiming then
            local fwd = getPedControlState(localPlayer, "forwards")
            local bwd = getPedControlState(localPlayer, "backwards")
            local left = getPedControlState(localPlayer, "left")
            local right = getPedControlState(localPlayer, "right")

            local moveX = 0
            local moveY = 0

            if fwd and not bwd then
                moveY = 1
            elseif bwd and not fwd then
                moveY = -1
            end

            if left and not right then
                moveX = 1
            elseif right and not left then
                moveX = -1
            end

            if moveY == 1 then
                if moveX == 1 then
                    targetRot = -rotX + 45
                elseif moveX == -1 then
                    targetRot = -rotX - 45
                else
                    targetRot = -rotX
                end
            elseif moveY == -1 then
                if moveX == 1 then
                    targetRot = -rotX + 135
                elseif moveX == -1 then
                    targetRot = -rotX - 135
                else
                    targetRot = -rotX + 180
                end
            elseif moveX == 1 then
                targetRot = -rotX + 90
            elseif moveX == -1 then
                targetRot = -rotX - 90
            end
        end

        setPedRotation(localPlayer, targetRot)
        setElementAlpha(localPlayer, fpAlpha)
    end
end

local function handleCursorMove(rx, ry, ax, ay)
    if not isFPActive or isCursorShowing() or isChatBoxInputActive() or isMainMenuActive() or isTxAdminOpen() then
        return
    end

    local diffX = ax - centerW
    local diffY = ay - centerH

    if diffX ~= 0 or diffY ~= 0 then
        rotX = (rotX + diffX * mouseSensitivity) % 360
        rotY = math_max(-80, math_min(80, rotY - diffY * mouseSensitivity))
        setCursorPosition(centerW, centerH)
    end
end

local fpBloom = 0
local fpLastRenderTick = getTickCount()
local fpCrosshairMode = 1

local function isUIBlocked()
    if isCursorShowing() or isChatBoxInputActive() or isMainMenuActive() or isConsoleActive() or isTxAdminOpen() then
        return true
    end
    local coreRes = getResourceFromName("gzl_core")
    if coreRes and getResourceState(coreRes) == "running" and exports.gzl_core:isPlayerTyping() then
        return true
    end
    return false
end

local function isGunEquipped()
    local weapon = getPedWeapon(localPlayer)
    return (weapon >= 22 and weapon <= 38) or (weapon >= 16 and weapon <= 18)
end

local function renderFirstPersonCrosshair()
    if not isFPActive or isPedDead(localPlayer) or isUIBlocked() or fpCrosshairMode == 0 then
        return
    end

    local veh = getPedOccupiedVehicle(localPlayer)
    if veh then
        local isDriveBy = getPedControlState(localPlayer, "vehicle_fire") or getPedControlState(localPlayer, "aim_weapon")
        if not isDriveBy then return end
    end

    if not isGunEquipped() then
        return
    end

    local now = getTickCount()
    local dt = now - fpLastRenderTick
    fpLastRenderTick = now
    if dt > 0 then
        fpBloom = math_max(0, fpBloom - dt * 0.018)
    end

    local isAiming = getPedControlState(localPlayer, "aim_weapon")
        or getPedControlState(localPlayer, "fire")
        or getKeyState("mouse2")

    local cx, cy = centerW, centerH
    local reticleColor = tocolor(235, 245, 240, 230)
    local dotBg = tocolor(0, 0, 0, 140)

    dxDrawRectangle(cx - 2, cy - 2, 4, 4, dotBg)
    dxDrawRectangle(cx - 1, cy - 1, 2, 2, reticleColor)

    if isAiming or fpCrosshairMode == 2 then
        local gap = 5 + math_floor(fpBloom)
        local size = 5

        local shadow = tocolor(0, 0, 0, 130)

        dxDrawLine(cx - gap - size - 1, cy, cx - gap + 1, cy, shadow, 4)
        dxDrawLine(cx + gap - 1, cy, cx + gap + size + 1, cy, shadow, 4)
        dxDrawLine(cx, cy - gap - size - 1, cx, cy - gap + 1, shadow, 4)
        dxDrawLine(cx, cy + gap - 1, cx, cy + gap + size + 1, shadow, 4)

        dxDrawLine(cx - gap - size, cy, cx - gap, cy, reticleColor, 2)
        dxDrawLine(cx + gap, cy, cx + gap + size, cy, reticleColor, 2)
        dxDrawLine(cx, cy - gap - size, cx, cy - gap, reticleColor, 2)
        dxDrawLine(cx, cy + gap, cx, cy + gap + size, reticleColor, 2)
    end
end

addEventHandler("onClientPlayerWeaponFire", localPlayer, function()
    if isFPActive then
        fpBloom = math_min(14, fpBloom + 3)
    end
end)

addEventHandler("onClientRestore", root, function()
    screenW, screenH = guiGetScreenSize()
    centerW, centerH = math_floor(screenW * 0.5), math_floor(screenH * 0.5)
end)

function toggleFirstPerson(forcedState)
    if forcedState ~= nil then
        isFPActive = forcedState
    else
        isFPActive = not isFPActive
    end

    if isFPActive then
        local veh = getPedOccupiedVehicle(localPlayer)
        if veh then
            local _, _, vz = getElementRotation(veh)
            rotX = -vz
            lastVehRot = vz
        else
            local pedRot = getPedRotation(localPlayer)
            rotX = -pedRot
            lastVehRot = false
        end
        rotY = 0

        setCursorPosition(centerW, centerH)
        setNearClipDistance(0.08)
        fpLastRenderTick = getTickCount()
        fpBloom = 0
        addEventHandler("onClientPreRender", root, updateFirstPersonCamera)
        addEventHandler("onClientCursorMove", root, handleCursorMove)
        addEventHandler("onClientRender", root, renderFirstPersonCrosshair)
        setElementAlpha(localPlayer, fpAlpha)
        playSoundFrontEnd(41)
        showNotification("Birinci Şahıs (FPS): AÇIK")
    else
        lastVehRot = false
        isShifting = false
        lastGear = nil
        setNearClipDistance(0.3)
        removeEventHandler("onClientPreRender", root, updateFirstPersonCamera)
        removeEventHandler("onClientCursorMove", root, handleCursorMove)
        removeEventHandler("onClientRender", root, renderFirstPersonCrosshair)
        setCameraTarget(localPlayer)
        setElementAlpha(localPlayer, 255)
        playSoundFrontEnd(41)
        showNotification("Birinci Şahıs (FPS): KAPALI")
    end
end

function isFirstPersonActive()
    return isFPActive
end

function setFirstPersonActive(state)
    toggleFirstPerson(state)
end

local function handleCameraCycle(key)
    local combat = getResourceFromName("gzl_combat")
    if isChatBoxInputActive() or isMainMenuActive() or isCursorShowing() or isTxAdminOpen() then
        return
    end

    if key=="home" then
        toggleFirstPerson()
        return
    end
    if combat and getResourceState(combat)=="running" and exports.gzl_combat:cycleCombatCamera() then return end

    local veh = getPedOccupiedVehicle(localPlayer)
    if isFPActive then
        toggleFirstPerson(false)
        if veh then
            setCameraViewMode(3, 3)
        else
            setCameraViewMode(3, 3)
        end
        return
    end

    local currentVehMode, currentPedMode = getCameraViewMode()
    currentVehMode = tonumber(currentVehMode) or 2
    currentPedMode = tonumber(currentPedMode) or 2

    if veh then
        if currentVehMode == 1 or currentVehMode == 0 then
            toggleFirstPerson(true)
        elseif currentVehMode == 2 then
            setCameraViewMode(1, currentPedMode)
        else
            setCameraViewMode(2, currentPedMode)
        end
    else
        if currentPedMode == 1 then
            toggleFirstPerson(true)
        elseif currentPedMode == 2 then
            setCameraViewMode(currentVehMode, 1)
        else
            setCameraViewMode(currentVehMode, 2)
        end
    end
end

toggleControl("change_camera", false)
bindKey("v", "down", handleCameraCycle)
bindKey("home", "down", handleCameraCycle)

addCommandHandler("fp", function()
    toggleFirstPerson()
end)

addCommandHandler("firstperson", function()
    toggleFirstPerson()
end)

addCommandHandler("fpbody", function()
    fpAlpha = (fpAlpha == 255) and 0 or 255
    if isFPActive then
        setElementAlpha(localPlayer, fpAlpha)
    end
    showNotification("FPS Gövde Görünürlüğü: " .. ((fpAlpha == 255) and "AÇIK" or "KAPALI"))
end)

addCommandHandler("fpforward", function(cmd, val)
    local num = tonumber(val)
    if num then
        fpForwardOffset = num
        showNotification("FPS İleri Ofseti: " .. fpForwardOffset)
    else
        showNotification("Kullanım: /fpforward [-0.1 ile 0.3] (Mevcut: " .. fpForwardOffset .. ")")
    end
end)

addCommandHandler("fpup", function(cmd, val)
    local num = tonumber(val)
    if num then
        fpUpOffset = num
        showNotification("FPS Yükseklik Ofseti: " .. fpUpOffset)
    else
        showNotification("Kullanım: /fpup [-0.1 ile 0.2] (Mevcut: " .. fpUpOffset .. ")")
    end
end)

addCommandHandler("vites", function()
    local veh = getPedOccupiedVehicle(localPlayer)
    if veh and getVehicleOccupant(veh, 0) == localPlayer then
        triggerGearShift(veh, true)
    end
end)

addCommandHandler("shift", function()
    local veh = getPedOccupiedVehicle(localPlayer)
    if veh and getVehicleOccupant(veh, 0) == localPlayer then
        triggerGearShift(veh, true)
    end
end)

addEventHandler("onClientPedsProcessed", root, function()
    if not isElement(localPlayer) or not isFPActive then
        return
    end

    local veh = getPedOccupiedVehicle(localPlayer)
    if not veh or getVehicleOccupant(veh, 0) ~= localPlayer then
        isShifting = false
        return
    end

    local leftAnalog = getAnalogControlState("vehicle_left") or 0
    local rightAnalog = getAnalogControlState("vehicle_right") or 0
    local steerInput = rightAnalog - leftAnalog
    if steerInput == 0 then
        if getPedControlState(localPlayer, "vehicle_right") then
            steerInput = 1.0
        elseif getPedControlState(localPlayer, "vehicle_left") then
            steerInput = -1.0
        end
    end

    local lShoulderPitch = 32.0 + steerInput * 8.0
    local lShoulderYaw = 38.0 + steerInput * 12.0
    local lShoulderRoll = -10.0 + steerInput * 10.0

    local lElbowYaw = -28.0 + steerInput * 15.0
    local lElbowPitch = -12.0
    local lElbowRoll = -18.0

    local lWristPitch = -15.0
    local lWristYaw = steerInput * 10.0
    local lWristRoll = 0.0

    setElementBoneRotation(localPlayer, 32, lShoulderYaw, lShoulderPitch, lShoulderRoll)
    setElementBoneRotation(localPlayer, 33, lElbowYaw, lElbowPitch, lElbowRoll)
    setElementBoneRotation(localPlayer, 34, lWristYaw, lWristPitch, lWristRoll)

    if isShifting then
        local now = getTickCount()
        local elapsed = now - shiftStartTick
        if elapsed >= shiftDuration then
            isShifting = false
            if gearComponent and isElement(veh) and gearBaseRot then
                setVehicleComponentRotation(veh, gearComponent, gearBaseRot[1], gearBaseRot[2], gearBaseRot[3], "parent")
            end
        else
            local t = elapsed / shiftDuration
            local progress = math.sin(t * math.pi)

            local shoulderPitch = -32.0 * progress
            local shoulderYaw = 22.0 * progress
            local shoulderRoll = -12.0 * progress

            local elbowYaw = -38.0 * progress
            local elbowPitch = 12.0 * progress
            local elbowRoll = 8.0 * progress

            local wristPitch = (shiftDirection * 14.0) * progress
            local wristYaw = -10.0 * progress
            local wristRoll = 0.0

            setElementBoneRotation(localPlayer, 22, shoulderYaw, shoulderPitch, shoulderRoll)
            setElementBoneRotation(localPlayer, 23, elbowYaw, elbowPitch, elbowRoll)
            setElementBoneRotation(localPlayer, 24, wristYaw, wristPitch, wristRoll)

            if gearComponent and isElement(veh) and gearBaseRot then
                local gearTilt = shiftDirection * 15.0 * progress
                setVehicleComponentRotation(veh, gearComponent, gearBaseRot[1] + gearTilt, gearBaseRot[2], gearBaseRot[3], "parent")
            end
        end
    end

    updateElementRpHAnim(localPlayer)
end)

addEventHandler("onClientPlayerWasted", localPlayer, function()
    if isFPActive then
        toggleFirstPerson(false)
    end
end)

addCommandHandler("fpcross", function()
    fpCrosshairMode = (fpCrosshairMode + 1) % 3
    local names = {
        [0] = "KAPALI",
        [1] = "FiveM (Nokta / Aim Reticle)",
        [2] = "Surekli Tam Reticle"
    }
    showNotification("FPS Crosshair Modu: " .. (names[fpCrosshairMode] or "AÇIK"))
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    toggleControl("change_camera", true)
    if isFPActive then
        lastVehRot = false
        isShifting = false
        lastGear = nil
        removeEventHandler("onClientPreRender", root, updateFirstPersonCamera)
        removeEventHandler("onClientCursorMove", root, handleCursorMove)
        removeEventHandler("onClientRender", root, renderFirstPersonCrosshair)
        setCameraTarget(localPlayer)
        setElementAlpha(localPlayer, 255)
    end
end)