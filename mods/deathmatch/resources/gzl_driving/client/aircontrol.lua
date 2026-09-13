
local isAirControlEnabled = true
local rollSpeed = 1.35
local pitchSpeed = 1.45
local yawSpeed = 0.90
local airDamping = 0.965

local function isTxAdminOpen()
    if exports.gzl_txadmin and exports.gzl_txadmin.isTxAdminOpen then
        return exports.gzl_txadmin:isTxAdminOpen()
    end
    return false
end

local function handleAirControl()
    if not isAirControlEnabled then return end

    local veh = getPedOccupiedVehicle(localPlayer)
    if not veh or getVehicleController(veh) ~= localPlayer then return end

    local vType = getVehicleType(veh)
    if vType ~= "Automobile" and vType ~= "Monster Truck" and vType ~= "Quad" then
        return
    end

    if isVehicleOnGround(veh) then
        return
    end

    if isTxAdminOpen() then return end

    local avx, avy, avz = getElementAngularVelocity(veh)
    if not avx then return end

    local m = getElementMatrix(veh)
    if not m then return end

    local rx, ry, rz = m[1][1], m[1][2], m[1][3]
    local fx, fy, fz = m[2][1], m[2][2], m[2][3]
    local ux, uy, uz = m[3][1], m[3][2], m[3][3]

    local pitchInput = 0
    local rollInput = 0
    local yawInput = 0

    if getKeyState("w") or getKeyState("arrow_u") or getPedControlState(localPlayer, "steer_forward") then
        pitchInput = pitchInput - 1
    end
    if getKeyState("s") or getKeyState("arrow_d") or getPedControlState(localPlayer, "steer_back") then
        pitchInput = pitchInput + 1
    end

    if getKeyState("a") or getKeyState("arrow_l") or getPedControlState(localPlayer, "vehicle_left") then
        rollInput = rollInput - 1
    end
    if getKeyState("d") or getKeyState("arrow_r") or getPedControlState(localPlayer, "vehicle_right") then
        rollInput = rollInput + 1
    end

    if getKeyState("q") then
        yawInput = yawInput + 1
    end
    if getKeyState("e") then
        yawInput = yawInput - 1
    end

    local targetAVX = avx
    local targetAVY = avy
    local targetAVZ = avz

    local hasInput = false

    if pitchInput ~= 0 then
        hasInput = true
        local pForce = pitchInput * pitchSpeed * 0.025
        targetAVX = targetAVX + rx * pForce
        targetAVY = targetAVY + ry * pForce
        targetAVZ = targetAVZ + rz * pForce
    end

    if rollInput ~= 0 then
        hasInput = true
        local rForce = rollInput * rollSpeed * 0.025
        targetAVX = targetAVX + fx * rForce
        targetAVY = targetAVY + fy * rForce
        targetAVZ = targetAVZ + fz * rForce
    end

    if yawInput ~= 0 then
        hasInput = true
        local yForce = yawInput * yawSpeed * 0.020
        targetAVX = targetAVX + ux * yForce
        targetAVY = targetAVY + uy * yForce
        targetAVZ = targetAVZ + uz * yForce
    end

    if not hasInput then
        targetAVX = targetAVX * airDamping
        targetAVY = targetAVY * airDamping
        targetAVZ = targetAVZ * airDamping
    else

        local maxAV = 2.2
        targetAVX = math.max(-maxAV, math.min(maxAV, targetAVX))
        targetAVY = math.max(-maxAV, math.min(maxAV, targetAVY))
        targetAVZ = math.max(-maxAV, math.min(maxAV, targetAVZ))
    end

    setElementAngularVelocity(veh, targetAVX, targetAVY, targetAVZ)
end

addEventHandler("onClientPreRender", root, handleAirControl)

function toggleAirControl(forcedState)
    if forcedState ~= nil then
        isAirControlEnabled = forcedState
    else
        isAirControlEnabled = not isAirControlEnabled
    end

    local status = isAirControlEnabled and "#2ed573AÇIK" or "#ff4757KAPALI"
    if exports.gzl_ui and exports.gzl_ui.showToast then
        exports.gzl_ui:showToast("Havada Kontrol: " .. status)
    else
        outputChatBox("#00f5a0[FiveM AirControl]#ffffff " .. status, 255, 255, 255, true)
    end
end
addCommandHandler("fivemair", toggleAirControl)