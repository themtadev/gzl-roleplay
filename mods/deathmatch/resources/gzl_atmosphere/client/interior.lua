
Interior = {}
Interior.__index = Interior

local currentFactor = 0.0
local targetFactor = 0.0
local lastCheckTick = 0
local checkInterval = 200
local lastFrameTick = getTickCount()

local SEAMLESS_INTERIORS = {
    { name = "24-7 Idlewood",   x = 1918.85, y = -1776.33, z = 16.98, radius = 22.0, minZ = 12.0, maxZ = 22.0 },
    { name = "24-7 Come-A-Lot", x = 2179.76, y = 2472.34,  z = 14.45, radius = 22.0, minZ = 10.0, maxZ = 20.0 },
    { name = "24-7 Spinybed",   x = 2146.83, y = 2727.00,  z = 14.43, radius = 22.0, minZ = 10.0, maxZ = 20.0 },
    { name = "24-7 Garcia",     x = -1710.56, y = 399.12,  z = 10.63, radius = 22.0, minZ = 6.0,  maxZ = 16.0 },
    { name = "24-7 Redsands",   x = 1590.21, y = 2227.41,  z = 14.44, radius = 22.0, minZ = 10.0, maxZ = 20.0 },
    { name = "24-7 Pilgrim",    x = 2114.17, y = 890.01,   z = 14.43, radius = 22.0, minZ = 10.0, maxZ = 20.0 },
}

local function checkCeilingOcclusion(cx, cy, cz)

    local hit, _, _, _, hitElement = processLineOfSight(
        cx, cy, cz + 0.5,
        cx, cy, cz + 16.0,
        true,
        false,
        false,
        true,
        false,
        false,
        false,
        false
    )
    return hit
end

function Interior.init()
    currentFactor = 0.0
    targetFactor = 0.0
    lastFrameTick = getTickCount()
end

function Interior.update()
    local now = getTickCount()
    local dt = math.min(0.1, (now - lastFrameTick) / 1000.0)
    lastFrameTick = now

    if (now - lastCheckTick) >= checkInterval then
        lastCheckTick = now

        local isInterior = false

        local pInt = getElementInterior(localPlayer)
        local pDim = getElementDimension(localPlayer)
        if pInt > 0 or pDim > 0 then
            isInterior = true
        end

        if not isInterior then
            local px, py, pz = getElementPosition(localPlayer)
            for _, zone in ipairs(SEAMLESS_INTERIORS) do
                local distSq = (px - zone.x)^2 + (py - zone.y)^2
                if distSq <= (zone.radius * zone.radius) and pz >= zone.minZ and pz <= zone.maxZ then
                    isInterior = true
                    break
                end
            end
        end

        if not isInterior then
            local cx, cy, cz = getCameraMatrix()
            local px, py, pz = getElementPosition(localPlayer)

            if checkCeilingOcclusion(cx, cy, cz) and checkCeilingOcclusion(px, py, pz + 1.0) then
                isInterior = true
            end
        end

        targetFactor = isInterior and 1.0 or 0.0
    end

    local blendSpeed = targetFactor > currentFactor and 3.2 or 2.6
    currentFactor = currentFactor + (targetFactor - currentFactor) * math.min(1.0, dt * blendSpeed)

    if math.abs(targetFactor - currentFactor) < 0.002 then
        currentFactor = targetFactor
    end

    return currentFactor
end

function Interior.getFactor()
    return currentFactor
end

function Interior.isInside()
    return currentFactor > 0.5
end

function Interior.reset()
    currentFactor = 0.0
    targetFactor = 0.0
end