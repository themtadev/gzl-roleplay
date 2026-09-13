local activeNeons = {}

local function createVehicleNeon(veh, neonData)
    if not isElement(veh) or not neonData or not neonData.enabled then return end
    if activeNeons[veh] then return end

    local r, g, b = neonData.r or 0, neonData.g or 150, neonData.b or 255

    local m1 = createMarker(0, 0, 0, "corona", 0.65, r, g, b, 175)
    local m2 = createMarker(0, 0, 0, "corona", 0.65, r, g, b, 175)

    if m1 and m2 then
        attachElements(m1, veh, -0.65, 0.0, -0.55)
        attachElements(m2, veh, 0.65, 0.0, -0.55)
        activeNeons[veh] = { m1, m2 }
    end
end

local function removeVehicleNeon(veh)
    if activeNeons[veh] then
        for _, m in ipairs(activeNeons[veh]) do
            if isElement(m) then
                destroyElement(m)
            end
        end
        activeNeons[veh] = nil
    end
end

local function updateNeonState(veh)
    if not isElement(veh) then return end
    local neonData = getElementData(veh, "veh:neon")
    if neonData and neonData.enabled then
        removeVehicleNeon(veh)
        createVehicleNeon(veh, neonData)
    else
        removeVehicleNeon(veh)
    end
end

addEventHandler("onClientElementDataChange", root, function(key)
    if key == "veh:neon" and getElementType(source) == "vehicle" then
        updateNeonState(source)
    end
end)

addEventHandler("onClientElementStreamIn", root, function()
    if getElementType(source) == "vehicle" then
        updateNeonState(source)
    end
end)

addEventHandler("onClientElementStreamOut", root, function()
    if getElementType(source) == "vehicle" then
        removeVehicleNeon(source)
    end
end)

addEventHandler("onClientElementDestroy", root, function()
    if getElementType(source) == "vehicle" then
        removeVehicleNeon(source)
    end
end)

addEventHandler("onClientResourceStart", resourceRoot, function()
    for _, veh in ipairs(getElementsByType("vehicle", root, true)) do
        updateNeonState(veh)
    end
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    for veh, _ in pairs(activeNeons) do
        removeVehicleNeon(veh)
    end
    activeNeons = {}
end)
