local screenW, screenH = guiGetScreenSize()
local localFontCache = {}
local pickupCustomer = nil
local pendingCall = nil
local acceptedCall = nil
local callRequestPending = false
local nextCallRequestTick = 0
local isHoldingR = false
local holdStartTick = 0
local holdProgress = 0
local heldSpotId = nil
local pickupRequestPending = false
local rMustRelease = false

local function getTaxiFont(fontType, size)
    fontType = string.lower(fontType or "regular")
    size = math.max(8, math.floor(tonumber(size) or 11))
    local key = fontType .. "_" .. size
    if localFontCache[key] and isElement(localFontCache[key]) then
        return localFontCache[key]
    end
    return "default-bold"
end

local function preloadTaxiFonts()
    local fileMap = {
        ["bold"] = "assets/fonts/SFUIText-Bold.ttf",
        ["semibold"] = "assets/fonts/SFUIText-Semibold.ttf",
        ["medium"] = "assets/fonts/SFUIText-Medium.ttf",
        ["regular"] = "assets/fonts/SFUIText-Regular.ttf"
    }
    local sizes = { 9, 10, 11, 12 }
    for fontType, path in pairs(fileMap) do
        if fileExists(path) then
            for _, size in ipairs(sizes) do
                local key = fontType .. "_" .. size
                if not localFontCache[key] then
                    localFontCache[key] = dxCreateFont(path, size, false, "cleartype")
                end
            end
        end
    end
end

local function drawSafeGlass(x, y, w, h, radius, color)
    if exports.gzl_ui and exports.gzl_ui.drawGlassPanel then
        exports.gzl_ui:drawGlassPanel(x, y, w, h, radius, color)
    elseif exports.gzl_ui and exports.gzl_ui.drawRoundedRectangle then
        exports.gzl_ui:drawRoundedRectangle(x, y, w, h, radius, color or tocolor(15, 23, 42, 230))
    else
        dxDrawRectangle(x, y, w, h, color or tocolor(15, 23, 42, 230))
    end
end

local function drawSafeRoundedRect(x, y, w, h, radius, color)
    if exports.gzl_ui and exports.gzl_ui.drawRoundedRectangle then
        exports.gzl_ui:drawRoundedRectangle(x, y, w, h, radius, color)
    else
        dxDrawRectangle(x, y, w, h, color)
    end
end

local function findRotation(x1, y1, x2, y2)
    local rotation = -math.deg(math.atan2(x2 - x1, y2 - y1))
    return rotation < 0 and rotation + 360 or rotation
end

local function getTaxiDriverVehicle()
    local vehicle = getPedOccupiedVehicle(localPlayer)
    if not isElement(vehicle) or getVehicleOccupant(vehicle, 0) ~= localPlayer then
        return nil
    end
    if not isVehicleTaxi(vehicle) or getElementInterior(vehicle) ~= 0 or getElementDimension(vehicle) ~= 0 then
        return nil
    end
    return vehicle
end

local function getVehicleSpeedKmh(vehicle)
    local vx, vy, vz = getElementVelocity(vehicle)
    return math.sqrt(vx * vx + vy * vy + vz * vz) * 180
end

local function getSpotById(spotId)
    for _, spot in ipairs(TaxiConfig.CustomerSpawns) do
        if spot.id == tonumber(spotId) then
            return spot
        end
    end
    return nil
end

local function getCustomerDataForSpot(spot)
    local classData = TaxiConfig.CustomerClasses[spot.classIdx] or TaxiConfig.CustomerClasses[1]
    local destData = TaxiConfig.Destinations[spot.destIdx] or TaxiConfig.Destinations[1]
    local name = TaxiConfig.Names[spot.nameIdx] or TaxiConfig.Names[1]
    local skin = classData.skinIds[spot.skinIdx] or classData.skinIds[1]
    local ratingSeed = ((spot.id * 31 + spot.classIdx * 7) % 10) / 10
    local rating = classData.minRating + ratingSeed * (classData.maxRating - classData.minRating)
    return classData, destData, name, skin, math.floor(rating * 10 + 0.5) / 10
end

local function clearPickupCustomer()
    if pickupCustomer then
        if isElement(pickupCustomer.blip) then
            destroyElement(pickupCustomer.blip)
        end
        if isElement(pickupCustomer.ped) then
            destroyElement(pickupCustomer.ped)
        end
    end
    pickupCustomer = nil
end

function clearAllActiveCustomers()
    clearPickupCustomer()
end

local function setTaxiNavigation(x, y)
    if setTaxiRouteWaypoint then
        setTaxiRouteWaypoint(x, y)
    elseif exports.gzl_radar and exports.gzl_radar.setWaypoint then
        exports.gzl_radar:setWaypoint(x, y)
    end
end

local function clearTaxiNavigation()
    if clearTaxiRouteWaypoint then
        clearTaxiRouteWaypoint()
    elseif exports.gzl_radar and exports.gzl_radar.clearWaypoint then
        exports.gzl_radar:clearWaypoint()
    end
end

local function resetPickupState(restoreRoute)
    clearPickupCustomer()
    acceptedCall = nil
    isHoldingR = false
    holdProgress = 0
    heldSpotId = nil
    pickupRequestPending = false
    rMustRelease = false
    if restoreRoute then
        clearTaxiNavigation()
    end
end

function cancelTaxiPickup(restoreRoute)
    pendingCall = nil
    callRequestPending = false
    resetPickupState(restoreRoute ~= false)
end

local function createPickupCustomer(spotId)
    clearPickupCustomer()
    local spot = getSpotById(spotId)
    if not spot then return false end
    local classData, destination, name, skin, rating = getCustomerDataForSpot(spot)
    local ped = createPed(skin, spot.x, spot.y, spot.z + 0.05, spot.rot)
    if not isElement(ped) then return false end
    setElementInterior(ped, 0)
    setElementDimension(ped, 0)
    setElementRotation(ped, 0, 0, spot.rot)
    setElementCollisionsEnabled(ped, true)
    setElementFrozen(ped, true)
    setPedAnimation(ped, "PED", "IDLE_taxi", -1, true, false, false)
    local blip = createBlip(spot.x, spot.y, spot.z, 0, 2, 250, 204, 21, 220, 0, 99999)
    pickupCustomer = {
        id = spot.id,
        ped = ped,
        blip = blip,
        x = spot.x,
        y = spot.y,
        z = spot.z,
        classData = classData,
        destination = destination,
        name = name,
        skin = skin,
        rating = rating
    }
    return true
end

local function requestTaxiCall()
    if callRequestPending or pendingCall or acceptedCall or (isRideActive and isRideActive()) then return end
    local now = getTickCount()
    if now < nextCallRequestTick then return end
    local vehicle = getTaxiDriverVehicle()
    if not vehicle then return end
    callRequestPending = true
    nextCallRequestTick = now + TaxiConfig.Ride.callRequestCooldown
    triggerServerEvent("taxi:requestTaxiCall", resourceRoot)
end

local function respondToPendingCall(accepted)
    if not pendingCall then return end
    if isChatBoxInputActive() or isConsoleActive() then return end
    local callId = pendingCall.id
    pendingCall = nil
    triggerServerEvent("taxi:respondToTaxiCall", resourceRoot, callId, accepted == true)
end

local function drawIncomingCall()
    if not pendingCall then return end
    local remaining = math.max(0, math.ceil((pendingCall.expiresTick - getTickCount()) / 1000))
    local spot = getSpotById(pendingCall.spotId)
    if not spot then return end
    local classData, destination, name = getCustomerDataForSpot(spot)
    local cardW = 360
    local cardH = 132
    local cardX = screenW - cardW - 28
    local cardY = 34
    drawSafeRoundedRect(cardX - 3, cardY - 3, cardW + 6, cardH + 6, 18, tocolor(0, 0, 0, 120))
    drawSafeGlass(cardX, cardY, cardW, cardH, 15, tocolor(10, 15, 28, 248))
    if exports.gzl_ui and exports.gzl_ui.drawRoundedBorder then
        exports.gzl_ui:drawRoundedBorder(cardX, cardY, cardW, cardH, 15, 1, tocolor(250, 204, 21, 130))
    end
    drawSafeRoundedRect(cardX + 16, cardY + 16, 42, 42, 12, tocolor(250, 204, 21, 220))
    if exports.gzl_ui and exports.gzl_ui.drawIconSVG then
        exports.gzl_ui:drawIconSVG("phone", cardX + 27, cardY + 27, 20, tocolor(15, 23, 42, 255))
    end
    dxDrawText("YENİ TAKSİ ÇAĞRISI", cardX + 70, cardY + 16, cardX + cardW - 16, cardY + 34, tocolor(250, 204, 21, 255), 1.0, getTaxiFont("bold", 11), "left", "center")
    dxDrawText(name .. "  •  " .. classData.className, cardX + 70, cardY + 34, cardX + cardW - 16, cardY + 52, tocolor(241, 245, 249, 255), 1.0, getTaxiFont("semibold", 10), "left", "center", true)
    dxDrawText("Hedef: " .. destination.name, cardX + 16, cardY + 68, cardX + cardW - 16, cardY + 86, tocolor(203, 213, 225, 255), 1.0, getTaxiFont("regular", 10), "left", "center", true)
    dxDrawText(string.format("Araç: ★ %.1f   Müşteri: ★ %.1f   %ds", pendingCall.vehicleRating, pendingCall.requiredRating, remaining), cardX + 16, cardY + 88, cardX + cardW - 16, cardY + 104, tocolor(148, 163, 184, 255), 1.0, getTaxiFont("medium", 9), "left", "center")
    drawSafeRoundedRect(cardX + 16, cardY + 110, 152, 28, 8, tocolor(5, 150, 105, 235))
    drawSafeRoundedRect(cardX + 176, cardY + 110, 168, 28, 8, tocolor(71, 85, 105, 220))
    dxDrawText("Y  KABUL ET", cardX + 16, cardY + 110, cardX + 168, cardY + 138, tocolor(255, 255, 255, 255), 1.0, getTaxiFont("bold", 10), "center", "center")
    dxDrawText("N  REDDET", cardX + 176, cardY + 110, cardX + 344, cardY + 138, tocolor(255, 255, 255, 255), 1.0, getTaxiFont("bold", 10), "center", "center")
end

local function getPickupDistance(vehicle)
    if not pickupCustomer then return math.huge end
    local vx, vy, vz = getElementPosition(vehicle)
    return getDistanceBetweenPoints3D(vx, vy, vz, pickupCustomer.x, pickupCustomer.y, pickupCustomer.z)
end

local function canStartPickup()
    local vehicle = getTaxiDriverVehicle()
    if not vehicle or not acceptedCall or not pickupCustomer or pickupRequestPending then
        return nil
    end
    if getVehicleSpeedKmh(vehicle) > TaxiConfig.Ride.pickupMaxSpeed then
        return nil
    end
    if getPickupDistance(vehicle) > TaxiConfig.Ride.pickupRadius then
        return nil
    end
    return vehicle
end

local function drawPickupWorld()
    local vehicle = getTaxiDriverVehicle()
    if not vehicle or not pickupCustomer then return end
    local distance = getPickupDistance(vehicle)
    if distance < 45 then
        local vx, vy = getElementPosition(vehicle)
        local rotation = findRotation(pickupCustomer.x, pickupCustomer.y, vx, vy)
        if isElement(pickupCustomer.ped) then
            setElementRotation(pickupCustomer.ped, 0, 0, rotation)
        end
    end
    if distance > 36 or not isElement(pickupCustomer.ped) then return end
    local headX, headY, headZ = getPedBonePosition(pickupCustomer.ped, 6)
    if not headX then
        headX, headY, headZ = pickupCustomer.x, pickupCustomer.y, pickupCustomer.z + 1.2
    else
        headZ = headZ + 0.35
    end
    local sx, sy = getScreenFromWorldPosition(headX, headY, headZ)
    if not sx or not sy then return end
    local pillW = 86
    local pillH = 26
    local pillX = sx - pillW / 2
    local pillY = sy - 42
    drawSafeRoundedRect(pillX - 2, pillY - 2, pillW + 4, pillH + 4, 10, tocolor(0, 0, 0, 140))
    drawSafeGlass(pillX, pillY, pillW, pillH, 8, tocolor(15, 23, 42, 240))
    dxDrawText(string.format("★ %.1f", pickupCustomer.rating), pillX, pillY, pillX + pillW, pillY + pillH, tocolor(250, 204, 21, 255), 1.0, getTaxiFont("bold", 11), "center", "center")
    if distance > 14 then return end
    local cardW = 190
    local cardH = 68
    local cardX = sx - cardW / 2
    local cardY = pillY + pillH + 8
    drawSafeRoundedRect(cardX - 2, cardY - 2, cardW + 4, cardH + 4, 12, tocolor(0, 0, 0, 150))
    drawSafeGlass(cardX, cardY, cardW, cardH, 10, tocolor(15, 23, 42, 248))
    if exports.gzl_ui and exports.gzl_ui.drawRoundedBorder then
        exports.gzl_ui:drawRoundedBorder(cardX, cardY, cardW, cardH, 10, 1, tocolor(255, 255, 255, 35))
    end
    dxDrawText(pickupCustomer.name, cardX + 12, cardY + 8, cardX + cardW - 12, cardY + 26, tocolor(248, 250, 252, 255), 1.0, getTaxiFont("bold", 10), "center", "center", true)
    local actionText = pickupRequestPending and "Onay bekleniyor..." or (isHoldingR and string.format("Alınıyor... %%%d", math.floor(holdProgress * 100)) or "R  Müşteriyi Al")
    drawSafeRoundedRect(cardX + 12, cardY + 34, cardW - 24, 24, 6, isHoldingR and tocolor(5, 150, 105, 235) or tocolor(30, 41, 59, 230))
    dxDrawText(actionText, cardX + 12, cardY + 34, cardX + cardW - 12, cardY + 58, tocolor(255, 255, 255, 255), 1.0, getTaxiFont("bold", 10), "center", "center")
end

local function updatePickupHold()
    if not isHoldingR then return end
    if not canStartPickup() or heldSpotId ~= (pickupCustomer and pickupCustomer.id) then
        isHoldingR = false
        holdProgress = 0
        return
    end
    holdProgress = math.min(1.0, (getTickCount() - holdStartTick) / 1000)
    if holdProgress < 1 then return end
    pickupRequestPending = true
    isHoldingR = false
    holdProgress = 0
    rMustRelease = true
    triggerServerEvent("taxi:requestBoardCustomer", resourceRoot, acceptedCall.spotId, acceptedCall.id)
end

bindKey("r", "down", function()
    if isCursorShowing() then return end
    if (exports.gzl_core and exports.gzl_core.isPlayerTyping and exports.gzl_core:isPlayerTyping()) or guiGetInputEnabled() or isChatBoxInputActive() or isConsoleActive() then return end
    if rMustRelease then return end
    local vehicle = canStartPickup()
    if not vehicle or not pickupCustomer then return end
    isHoldingR = true
    holdStartTick = getTickCount()
    holdProgress = 0
    heldSpotId = pickupCustomer.id
end)

bindKey("r", "up", function()
    isHoldingR = false
    holdProgress = 0
    heldSpotId = nil
    rMustRelease = false
end)

bindKey("y", "down", function()
    if isCursorShowing() then return end
    if (exports.gzl_core and exports.gzl_core.isPlayerTyping and exports.gzl_core:isPlayerTyping()) or guiGetInputEnabled() or isChatBoxInputActive() or isConsoleActive() then return end
    respondToPendingCall(true)
end)

bindKey("n", "down", function()
    if isCursorShowing() then return end
    if (exports.gzl_core and exports.gzl_core.isPlayerTyping and exports.gzl_core:isPlayerTyping()) or guiGetInputEnabled() or isChatBoxInputActive() or isConsoleActive() then return end
    respondToPendingCall(false)
end)

addEventHandler("onClientRender", root, function()
    local vehicle = getTaxiDriverVehicle()
    if not vehicle then
        if acceptedCall then
            triggerServerEvent("taxi:cancelRide", resourceRoot)
            resetPickupState(true)
        end
        isHoldingR = false
        holdProgress = 0
        drawIncomingCall()
        return
    end
    if isRideActive and isRideActive() then
        if acceptedCall then
            resetPickupState(false)
        end
        isHoldingR = false
        holdProgress = 0
        return
    end
    requestTaxiCall()
    drawIncomingCall()
    drawPickupWorld()
    updatePickupHold()
end)

addEvent("taxi:incomingCall", true)
addEventHandler("taxi:incomingCall", root, function(callId, spotId, lifetime, vehicleRating, requiredRating)
    callRequestPending = false
    local spot = getSpotById(spotId)
    if not spot or not getTaxiDriverVehicle() then
        triggerServerEvent("taxi:respondToTaxiCall", resourceRoot, callId, false)
        return
    end
    pendingCall = {
        id = tonumber(callId),
        spotId = tonumber(spotId),
        expiresTick = getTickCount() + math.max(0, tonumber(lifetime) or 0),
        vehicleRating = tonumber(vehicleRating) or 1.0,
        requiredRating = tonumber(requiredRating) or 1.0
    }
end)

addEvent("taxi:callAccepted", true)
addEventHandler("taxi:callAccepted", root, function(callId, spotId, vehicleRating, requiredRating)
    callRequestPending = false
    pendingCall = nil
    acceptedCall = {
        id = tonumber(callId),
        spotId = tonumber(spotId),
        vehicleRating = tonumber(vehicleRating) or 1.0,
        requiredRating = tonumber(requiredRating) or 1.0
    }
    if createPickupCustomer(acceptedCall.spotId) then
        setTaxiNavigation(pickupCustomer.x, pickupCustomer.y)
    else
        triggerServerEvent("taxi:cancelRide", resourceRoot)
        resetPickupState(true)
    end
end)

addEvent("taxi:callUnavailable", true)
addEventHandler("taxi:callUnavailable", root, function(message)
    callRequestPending = false
    if message and exports.gzl_ui and exports.gzl_ui.showToast then
        exports.gzl_ui:showToast("info", message)
    end
end)

addEvent("taxi:callExpired", true)
addEventHandler("taxi:callExpired", root, function(message)
    pendingCall = nil
    callRequestPending = false
    resetPickupState(true)
    if message and exports.gzl_ui and exports.gzl_ui.showToast then
        exports.gzl_ui:showToast("warning", message)
    end
end)

addEvent("taxi:callCancelled", true)
addEventHandler("taxi:callCancelled", root, function(message)
    pendingCall = nil
    callRequestPending = false
    resetPickupState(true)
    if message and exports.gzl_ui and exports.gzl_ui.showToast then
        exports.gzl_ui:showToast("info", message)
    end
end)

addEvent("taxi:pickupDenied", true)
addEventHandler("taxi:pickupDenied", root, function(message)
    pickupRequestPending = false
    if message and exports.gzl_ui and exports.gzl_ui.showToast then
        exports.gzl_ui:showToast("warning", message)
    end
end)

addEvent("taxi:syncBoardingAndStartRide", true)
addEventHandler("taxi:syncBoardingAndStartRide", root, function(spotId, seat, callId)
    if not acceptedCall or acceptedCall.id ~= tonumber(callId) or acceptedCall.spotId ~= tonumber(spotId) then return end
    local vehicle = getTaxiDriverVehicle()
    local spot = getSpotById(spotId)
    if not vehicle or not spot then return end
    local classData, destination, name, skin, rating = getCustomerDataForSpot(spot)
    resetPickupState(false)
    if startTaxiRide then
        local started = startTaxiRide({
            name = name,
            classData = classData,
            destIndex = spot.destIdx,
            destination = destination,
            rating = rating,
            skin = skin,
            peds = {}
        }, seat, callId)
        if not started then
            triggerServerEvent("taxi:cancelRide", resourceRoot)
            clearTaxiNavigation()
        end
    end
end)

addEventHandler("onClientResourceStart", resourceRoot, function()
    preloadTaxiFonts()
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    clearPickupCustomer()
    clearTaxiNavigation()
    for _, font in pairs(localFontCache) do
        if isElement(font) then
            destroyElement(font)
        end
    end
    localFontCache = {}
end)