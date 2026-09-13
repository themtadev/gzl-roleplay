local trackedVehicles = {}
local steerCandidateNames = {
    "movsteer_1.0",
    "steering_dummy",
    "steeringwheel",
    "steer_dummy",
    "steering",
    "wheel_steering",
    "extra_steer",
    "steer"
}

local axisOverrides = {}
local defaultMaxAngle = 55.0
local defaultTurnSpeed = 4.2
local defaultReturnSpeed = 5.5

local function findSteeringComponent(veh)
    local comps = getVehicleComponents(veh)
    if not comps then return nil end

    for _, name in ipairs(steerCandidateNames) do
        if comps[name] then
            return name
        end
    end

    for compName, _ in pairs(comps) do
        local lower = string.lower(compName)
        if string.find(lower, "steer") and not string.find(lower, "wheel_") then
            return compName
        end
    end

    return nil
end

local function initVehicleSteer(veh)
    if not isElement(veh) or trackedVehicles[veh] then
        return
    end

    local vType = getVehicleType(veh)
    if vType ~= "Automobile" and vType ~= "Monster Truck" then
        return
    end

    local compName = findSteeringComponent(veh)
    if not compName then
        return
    end

    local rx, ry, rz = getVehicleComponentRotation(veh, compName, "parent")
    local model = getElementModel(veh)
    local chosenAxis = axisOverrides[model] or "y"

    trackedVehicles[veh] = {
        comp = compName,
        baseRx = rx or 0,
        baseRy = ry or 0,
        baseRz = rz or 0,
        curAngle = 0,
        targetAngle = 0,
        axis = chosenAxis,
        multiplier = 1.0
    }
end

local function removeVehicleSteer(veh)
    if trackedVehicles[veh] then
        if isElement(veh) then
            local data = trackedVehicles[veh]
            setVehicleComponentRotation(veh, data.comp, data.baseRx, data.baseRy, data.baseRz, "parent")
        end
        trackedVehicles[veh] = nil
    end
end

addEventHandler("onClientResourceStart", resourceRoot, function()
    for _, veh in ipairs(getElementsByType("vehicle")) do
        if isElementStreamedIn(veh) then
            initVehicleSteer(veh)
        end
    end
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    for veh, data in pairs(trackedVehicles) do
        if isElement(veh) then
            setVehicleComponentRotation(veh, data.comp, data.baseRx, data.baseRy, data.baseRz, "parent")
        end
    end
    trackedVehicles = {}
end)

addEventHandler("onClientElementStreamIn", root, function()
    if getElementType(source) == "vehicle" then
        initVehicleSteer(source)
    end
end)

addEventHandler("onClientElementStreamOut", root, function()
    if getElementType(source) == "vehicle" then
        removeVehicleSteer(source)
    end
end)

addEventHandler("onClientElementDestroy", root, function()
    if getElementType(source) == "vehicle" then
        removeVehicleSteer(source)
    end
end)

local lastTick = getTickCount()

addEventHandler("onClientPreRender", root, function()
    local now = getTickCount()
    local dt = (now - lastTick) / 1000.0
    lastTick = now
    if dt <= 0 or dt > 0.1 then
        dt = 0.016
    end

    for veh, data in pairs(trackedVehicles) do
        if not isElement(veh) or not isElementStreamedIn(veh) then
            trackedVehicles[veh] = nil
        else
            local driver = getVehicleOccupant(veh, 0)
            local steerInput = 0

            if driver then
                if driver == localPlayer then
                    local leftAnalog = getAnalogControlState("vehicle_left") or 0
                    local rightAnalog = getAnalogControlState("vehicle_right") or 0
                    steerInput = rightAnalog - leftAnalog

                    if steerInput == 0 then
                        if getPedControlState(driver, "vehicle_right") then
                            steerInput = 1.0
                        elseif getPedControlState(driver, "vehicle_left") then
                            steerInput = -1.0
                        end
                    end
                else
                    if getPedControlState(driver, "vehicle_right") then
                        steerInput = 1.0
                    elseif getPedControlState(driver, "vehicle_left") then
                        steerInput = -1.0
                    end
                end
            end

            local vx, vy, vz = getElementVelocity(veh)
            local speedKmH = (vx * vx + vy * vy + vz * vz) ^ 0.5 * 180
            local speedFactor = math.max(0.45, 1.0 - (speedKmH / 200.0) * 0.5)

            data.targetAngle = steerInput * defaultMaxAngle * speedFactor
            local rate = (steerInput ~= 0) and defaultTurnSpeed or defaultReturnSpeed
            data.curAngle = data.curAngle + (data.targetAngle - data.curAngle) * math.min(1.0, dt * rate)

            local angle = data.curAngle * data.multiplier
            if data.axis == "y" then
                setVehicleComponentRotation(veh, data.comp, data.baseRx, data.baseRy + angle, data.baseRz, "parent")
            elseif data.axis == "x" then
                setVehicleComponentRotation(veh, data.comp, data.baseRx + angle, data.baseRy, data.baseRz, "parent")
            elseif data.axis == "z" then
                setVehicleComponentRotation(veh, data.comp, data.baseRx, data.baseRy, data.baseRz + angle, "parent")
            end
        end
    end
end)

addCommandHandler("steerdebug", function()
    local veh = getPedOccupiedVehicle(localPlayer)
    if not veh then
        outputChatBox("[STEER] Bir aracta degilsiniz.", 255, 100, 100)
        return
    end

    local comps = getVehicleComponents(veh)
    outputChatBox("[STEER] Arac Modeli: " .. getElementModel(veh) .. " (" .. getVehicleName(veh) .. ")", 0, 255, 180)
    local found = findSteeringComponent(veh)
    if found then
        local data = trackedVehicles[veh]
        local axis = data and data.axis or "y"
        outputChatBox("[STEER] Direksiyon Parçası: #00ff00" .. found .. " #ffffff(Eksen: " .. axis .. ")", 255, 255, 255, true)
    else
        outputChatBox("[STEER] Ayrik direksiyon parçası bulunamadi.", 255, 200, 0)
        local count = 0
        for name, _ in pairs(comps) do
            count = count + 1
        end
        outputChatBox("[STEER] Toplam bilesen sayisi: " .. count, 200, 200, 200)
    end
end)

addCommandHandler("steeraxis", function(cmd, newAxis)
    local veh = getPedOccupiedVehicle(localPlayer)
    if not veh then
        outputChatBox("[STEER] Bir aracta degilsiniz.", 255, 100, 100)
        return
    end

    if not newAxis or (newAxis ~= "x" and newAxis ~= "y" and newAxis ~= "z") then
        outputChatBox("[STEER] Kullanim: /steeraxis [x/y/z]", 255, 200, 0)
        return
    end

    local model = getElementModel(veh)
    axisOverrides[model] = newAxis
    if trackedVehicles[veh] then
        trackedVehicles[veh].axis = newAxis
    end
    outputChatBox("[STEER] Arac modeli " .. model .. " icin direksiyon ekseni '" .. newAxis .. "' olarak ayarlandi.", 0, 255, 120)
end)

addCommandHandler("steerspeed", function(cmd, newSpeed)
    local speed = tonumber(newSpeed)
    if not speed or speed <= 0 or speed > 30 then
        outputChatBox("[STEER] Kullanim: /steerspeed [1.0 - 15.0] (Mevcut: " .. defaultTurnSpeed .. ")", 255, 200, 0)
        return
    end
    defaultTurnSpeed = speed
    defaultReturnSpeed = speed * 1.25
    outputChatBox("[STEER] Direksiyon donus hizi " .. defaultTurnSpeed .. " olarak ayarlandi.", 0, 255, 120)
end)

addCommandHandler("steerangle", function(cmd, newAngle)
    local angle = tonumber(newAngle)
    if not angle or angle <= 0 or angle > 360 then
        outputChatBox("[STEER] Kullanim: /steerangle [10 - 180] (Mevcut: " .. defaultMaxAngle .. ")", 255, 200, 0)
        return
    end
    defaultMaxAngle = angle
    outputChatBox("[STEER] Maksimum direksiyon donus acisi " .. defaultMaxAngle .. " derece yapildi.", 0, 255, 120)
end)

function getVehicleSteeringComponent(veh)
    if not isElement(veh) then return nil end
    local data = trackedVehicles[veh]
    return data and data.comp or nil
end

function setVehicleSteeringAxis(model, axis)
    if type(model) == "number" and (axis == "x" or axis == "y" or axis == "z") then
        axisOverrides[model] = axis
        return true
    end
    return false
end

function setSteerMaxAngle(angle)
    if type(angle) == "number" and angle > 0 then
        defaultMaxAngle = angle
        return true
    end
    return false
end

function setSteerTurnSpeed(speed)
    if type(speed) == "number" and speed > 0 then
        defaultTurnSpeed = speed
        defaultReturnSpeed = speed * 1.25
        return true
    end
    return false
end