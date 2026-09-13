local liftCurrentState = false
local isLiftMoving = false
local liftMovingSound = nil
local attachedVehicle = nil

local function getVehicleOnLift()
    local station = Config.Stations.main or Config.Stations.lift
    local x, y = (station and station.x or 2276.71), (station and station.y or -1995.61)
    for _, veh in ipairs(getElementsByType("vehicle", root, true)) do
        local vx, vy, vz = getElementPosition(veh)
        if getDistanceBetweenPoints2D(x, y, vx, vy) <= 3.2 and vz >= 13.5 and vz <= 18.0 then
            return veh
        end
    end
    return nil
end

function isLiftRaised()
    return liftCurrentState
end

function isLiftActive()
    return isLiftMoving
end

addEvent("mechanic:syncLiftState", true)
addEventHandler("mechanic:syncLiftState", root, function(targetRaised)
    local liftObj = getLiftObject()
    if not liftObj or not isElement(liftObj) then return end

    liftCurrentState = targetRaised
    isLiftMoving = true

    local lx, ly, lz = getElementPosition(liftObj)
    local targetZ = targetRaised and Config.LiftHeight.up or Config.LiftHeight.down
    local duration = Config.LiftHeight.duration

    if fileExists("assets/sounds/lift_hum.wav") then
        if liftMovingSound and isElement(liftMovingSound) then
            stopSound(liftMovingSound)
        end
        liftMovingSound = playSound3D("assets/sounds/lift_hum.wav", lx, ly, lz)
        if liftMovingSound then
            setSoundMaxDistance(liftMovingSound, 35)
            setSoundVolume(liftMovingSound, 0.8)
        end
    end

    local veh = getVehicleOnLift()
    if veh and isElement(veh) then
        attachedVehicle = veh
        local vx, vy, vz = getElementPosition(veh)
        local rx, ry, rz = getElementRotation(veh)
        local lrx, lry, lrz = getElementRotation(liftObj)
        attachElements(veh, liftObj, vx - lx, vy - ly, vz - lz, rx - lrx, ry - lry, rz - lrz)
    end

    moveObject(liftObj, duration, lx, ly, targetZ, 0, 0, 0, "InOutQuad")

    setTimer(function()
        isLiftMoving = false
        if attachedVehicle and isElement(attachedVehicle) then
            detachElements(attachedVehicle, liftObj)

            local vx, vy, vz = getElementPosition(attachedVehicle)
            setElementPosition(attachedVehicle, vx, vy, vz + 0.05)
            attachedVehicle = nil
        end
    end, duration + 100, 1)
end)