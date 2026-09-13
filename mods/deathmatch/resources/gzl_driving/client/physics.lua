
local isDriftAssistEnabled = true

local function clamp(val, minV, maxV)
    return math.max(minV, math.min(maxV, val))
end

local function getAngleDiff(target, source)
    local diff = (target - source) % 360
    if diff > 180 then diff = diff - 360 end
    if diff < -180 then diff = diff + 360 end
    return diff
end

local function handleDriftAssist()
    if not isDriftAssistEnabled then return end

    local veh = getPedOccupiedVehicle(localPlayer)
    if not veh or getVehicleController(veh) ~= localPlayer then return end

    local vType = getVehicleType(veh)
    if vType ~= "Automobile" and vType ~= "Monster Truck" then return end

    if not isVehicleOnGround(veh) then return end

    local vx, vy, vz = getElementVelocity(veh)
    local speed = ((vx * vx + vy * vy + vz * vz) ^ 0.5) * 180
    if speed < 18 then return end

    local _, _, rz = getElementRotation(veh)
    local vehHeading = rz
    local moveHeading = (math.deg(math.atan2(-vx, vy))) % 360
    local slipAngle = getAngleDiff(moveHeading, vehHeading)

    local absSlip = math.abs(slipAngle)

    if absSlip >= 12 and absSlip <= 75 then
        local isCounterSteering = false
        local steerLeft = getPedControlState(localPlayer, "vehicle_left") or getKeyState("a") or getKeyState("arrow_l")
        local steerRight = getPedControlState(localPlayer, "vehicle_right") or getKeyState("d") or getKeyState("arrow_r")

        if slipAngle > 0 and steerLeft then
            isCounterSteering = true
        elseif slipAngle < 0 and steerRight then
            isCounterSteering = true
        end

        if isCounterSteering then
            local avx, avy, avz = getElementAngularVelocity(veh)
            if avx then

                local correctionFactor = (absSlip / 50.0) * 0.010
                if slipAngle > 0 then

                    avz = avz + correctionFactor
                else

                    avz = avz - correctionFactor
                end

                avz = avz * 0.94
                setElementAngularVelocity(veh, avx, avy, avz)
            end
        end
    end
end

addEventHandler("onClientPreRender", root, handleDriftAssist)

addCommandHandler("fivemdrift", function()
    isDriftAssistEnabled = not isDriftAssistEnabled
    local status = isDriftAssistEnabled and "#2ed573AÇIK" or "#ff4757KAPALI"
    if exports.gzl_ui and exports.gzl_ui.showToast then
        exports.gzl_ui:showToast("Drift & Kontra Asistanı: " .. status)
    else
        outputChatBox("#00f5a0[FiveM Drift]#ffffff " .. status, 255, 255, 255, true)
    end
end)