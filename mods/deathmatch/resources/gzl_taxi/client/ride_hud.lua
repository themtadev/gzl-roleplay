local screenW, screenH = guiGetScreenSize()

local activeRide = nil
local currentSpeech = ""
local currentSpeechTick = 0
local bannerActive = false
local bannerStartTick = 0

local completeModalActive = false
local completeRideData = nil
local savedTaxiWaypoint = nil
local taxiWaypointActive = false

local localHudFontCache = {}
local hudFontFiles = {
    ["bold"] = "assets/fonts/SFUIText-Bold.ttf",
    ["semibold"] = "assets/fonts/SFUIText-Semibold.ttf",
    ["medium"] = "assets/fonts/SFUIText-Medium.ttf",
    ["regular"] = "assets/fonts/SFUIText-Regular.ttf"
}

local function preloadRideFonts()
    local sizes = { 9, 10, 11, 12, 13, 24 }
    for fontType, path in pairs(hudFontFiles) do
        if fileExists(path) then
            for _, size in ipairs(sizes) do
                local key = fontType .. "_" .. size
                if not localHudFontCache[key] then
                    localHudFontCache[key] = dxCreateFont(path, size, false, "cleartype")
                end
            end
        end
    end
end

local function getSafeFont(fontType, size)
    fontType = string.lower(fontType or "regular")
    size = math.max(8, math.floor(tonumber(size) or 11))
    local key = fontType .. "_" .. size
    if localHudFontCache[key] and isElement(localHudFontCache[key]) then
        return localHudFontCache[key]
    end

    if exports.gzl_ui and exports.gzl_ui.getFont then
        local f = exports.gzl_ui:getFont(fontType, size)
        if f then return f end
    end
    return "default-bold"
end

function setTaxiRouteWaypoint(x, y)
    if not (exports.gzl_radar and exports.gzl_radar.setWaypoint) then return end
    if not taxiWaypointActive and exports.gzl_radar.getWaypoint then
        local previous = exports.gzl_radar:getWaypoint()
        if type(previous) == "table" and previous.x and previous.y then
            savedTaxiWaypoint = { x = previous.x, y = previous.y }
        else
            savedTaxiWaypoint = nil
        end
    end
    taxiWaypointActive = true
    exports.gzl_radar:setWaypoint(x, y)
end

function clearTaxiRouteWaypoint()
    if not taxiWaypointActive then return end
    taxiWaypointActive = false
    if not (exports.gzl_radar and exports.gzl_radar.clearWaypoint) then
        savedTaxiWaypoint = nil
        return
    end
    if savedTaxiWaypoint and exports.gzl_radar.setWaypoint then
        exports.gzl_radar:setWaypoint(savedTaxiWaypoint.x, savedTaxiWaypoint.y)
    else
        exports.gzl_radar:clearWaypoint()
    end
    savedTaxiWaypoint = nil
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

local function isCursorOver(x, y, w, h)
    if not isCursorShowing() then return false end
    local cx, cy = getCursorPosition()
    cx, cy = cx * screenW, cy * screenH
    return cx >= x and cx <= x + w and cy >= y and cy <= y + h
end

function isRideActive()
    return activeRide ~= nil
end

function setPassengerSpeech(text, durationMs)
    currentSpeech = text
    currentSpeechTick = getTickCount() + (durationMs or 4500)
end

function startTaxiRide(groupData, seat, callId)
    local veh = getPedOccupiedVehicle(localPlayer)
    if not isElement(veh) or getVehicleOccupant(veh, 0) ~= localPlayer or activeRide then
        return false
    end

    local startX, startY, startZ = getElementPosition(veh)
    local dest = groupData.destination

    local pedsList = groupData.peds or {}
    if #pedsList == 0 and groupData.skin and seat then
        local ped = createPed(groupData.skin, startX, startY, startZ)
        if isElement(ped) then
            setElementCollisionsEnabled(ped, false)
            warpPedIntoVehicle(ped, veh, seat)
            table.insert(pedsList, ped)
        end
    end

    activeRide = {
        name = groupData.name,
        classData = groupData.classData,
        destIndex = groupData.destIndex,
        destination = dest,
        initialRating = groupData.rating,
        basePayMultiplier = groupData.classData.payMultiplier or 1.0,
        serviceMultiplier = 1.0,
        currentMultiplier = groupData.classData.payMultiplier or 1.0,
        comfortProgress = 1.0,
        startTick = getTickCount(),
        startPos = { x = startX, y = startY, z = startZ },
        lastDistancePosition = { x = startX, y = startY, z = startZ },
        lastDistanceTick = getTickCount(),
        displayDistance = 0,
        peds = pedsList,
        vehicle = veh,
        nearAlertGiven = false,
        callId = tonumber(callId),
        completing = false
    }

    setTaxiRouteWaypoint(dest.x, dest.y)

    bannerActive = true
    bannerStartTick = getTickCount()

    local welcomeList = TaxiConfig.CustomerReactions.welcome
    local randWelcome = welcomeList[math.random(1, #welcomeList)]
    setPassengerSpeech(randWelcome, 4000)
    return true
end

function stopActiveRide(cleanupPeds)
    if activeRide and cleanupPeds then
        triggerServerEvent("taxi:cancelRide", resourceRoot)
        if activeRide.peds then
            for _, ped in ipairs(activeRide.peds) do
                if isElement(ped) then
                    destroyElement(ped)
                end
            end
        end
    end

    clearTaxiRouteWaypoint()

    activeRide = nil
    currentSpeech = ""
end

local function drawChevronArrow(x, y, z, dirX, dirY, size, color)
    local perpX = -dirY
    local perpY = dirX

    local tipX = x + dirX * size
    local tipY = y + dirY * size

    local leftX = x - dirX * (size * 0.5) + perpX * (size * 0.8)
    local leftY = y - dirY * (size * 0.5) + perpY * (size * 0.8)

    local rightX = x - dirX * (size * 0.5) - perpX * (size * 0.8)
    local rightY = y - dirY * (size * 0.5) - perpY * (size * 0.8)

    dxDrawLine3D(leftX, leftY, z + 0.1, tipX, tipY, z + 0.1, color, 3.5)
    dxDrawLine3D(rightX, rightY, z + 0.1, tipX, tipY, z + 0.1, color, 3.5)
end

local function drawDestinationParkingBox(cx, cy, cz)
    local boxW = 3.6
    local boxL = 6.2

    local x1 = cx - boxW / 2
    local x2 = cx + boxW / 2
    local y1 = cy - boxL / 2
    local y2 = cy + boxL / 2
    local z = cz + 0.15

    local greenCol = tocolor(34, 197, 94, 230)
    dxDrawLine3D(x1, y1, z, x2, y1, z, greenCol, 4.0)
    dxDrawLine3D(x2, y1, z, x2, y2, z, greenCol, 4.0)
    dxDrawLine3D(x2, y2, z, x1, y2, z, greenCol, 4.0)
    dxDrawLine3D(x1, y2, z, x1, y1, z, greenCol, 4.0)

    local numSegments = 16
    local radius = 0.9
    for i = 1, numSegments do
        local a1 = (i - 1) * (math.pi * 2 / numSegments)
        local a2 = i * (math.pi * 2 / numSegments)
        local px1 = cx + math.cos(a1) * radius
        local py1 = cy + math.sin(a1) * radius
        local px2 = cx + math.cos(a2) * radius
        local py2 = cy + math.sin(a2) * radius
        dxDrawLine3D(px1, py1, z, px2, py2, z, tocolor(239, 68, 68, 240), 4.0)
    end
end

local function renderRideTopBanner()
    if not bannerActive then
        return
    end

    local now = getTickCount()
    local elapsed = now - bannerStartTick
    if elapsed > 4500 then
        bannerActive = false
        return
    end

    local alpha = 255
    if elapsed > 3800 then
        alpha = math.floor(255 * (1 - (elapsed - 3800) / 700))
    end

    local banW = 340
    local banH = 68
    local banX = (screenW - banW) / 2
    local banY = 32

    drawSafeGlass(banX, banY, banW, banH, 12, tocolor(15, 23, 42, math.min(235, alpha)))
    if exports.gzl_ui and exports.gzl_ui.drawRoundedBorder then
        exports.gzl_ui:drawRoundedBorder(banX, banY, banW, banH, 12, 1, tocolor(250, 204, 21, math.min(180, alpha)))
    end

    local fontTitle = getSafeFont("bold", 13)
    local fontSub = getSafeFont("medium", 10)

    dxDrawText("YOLCULUK BAŞLADI", banX, banY + 12, banX + banW, banY + 34, tocolor(250, 204, 21, alpha), 1.0, fontTitle, "center", "center")
    dxDrawText("Müşteriyi Belirtilen Hedefe Ulaştır", banX, banY + 36, banX + banW, banY + 56, tocolor(241, 245, 249, alpha), 1.0, fontSub, "center", "center")
end

local function updateDisplayedRideDistance()
    if not activeRide or not isElement(activeRide.vehicle) then
        return 0
    end
    local now = getTickCount()
    if now - activeRide.lastDistanceTick >= 300 then
        local x, y, z = getElementPosition(activeRide.vehicle)
        local previous = activeRide.lastDistancePosition
        local segment = getDistanceBetweenPoints3D(previous.x, previous.y, previous.z, x, y, z)
        if segment <= TaxiConfig.Ride.maximumSampleDistance then
            activeRide.displayDistance = activeRide.displayDistance + segment
        end
        activeRide.lastDistancePosition = { x = x, y = y, z = z }
        activeRide.lastDistanceTick = now
    end
    return activeRide.displayDistance
end

local function renderPassengerCardAndBar()
    if not activeRide then
        return
    end

    local cardW = 280
    local cardH = 86
    local cardX = screenW - cardW - 25
    local barH = 26
    local barGap = 6
    local totalH = cardH + barGap + barH
    local cardY = screenH - totalH - 215

    if currentSpeech ~= "" and getTickCount() < currentSpeechTick then
        local bubbleW = math.min(300, math.max(180, dxGetTextWidth(currentSpeech, 1.0, getSafeFont("medium", 10)) + 36))
        local bubbleH = 44
        local bubbleX = cardX + cardW - bubbleW
        local bubbleY = cardY - bubbleH - 8

        drawSafeRoundedRect(bubbleX - 2, bubbleY - 2, bubbleW + 4, bubbleH + 4, 12, tocolor(0, 0, 0, 140))
        drawSafeGlass(bubbleX, bubbleY, bubbleW, bubbleH, 10, tocolor(15, 23, 42, 248))
        if exports.gzl_ui and exports.gzl_ui.drawRoundedBorder then
            exports.gzl_ui:drawRoundedBorder(bubbleX, bubbleY, bubbleW, bubbleH, 10, 1, tocolor(255, 255, 255, 30))
        end

        dxDrawText(currentSpeech, bubbleX + 12, bubbleY, bubbleX + bubbleW - 12, bubbleY + bubbleH, tocolor(248, 250, 252, 255), 1.0, getSafeFont("medium", 10), "center", "center", true, true)
    end

    drawSafeRoundedRect(cardX - 2, cardY - 2, cardW + 4, cardH + 4, 14, tocolor(0, 0, 0, 140))
    drawSafeGlass(cardX, cardY, cardW, cardH, 12, tocolor(10, 15, 28, 248))
    if exports.gzl_ui and exports.gzl_ui.drawRoundedBorder then
        exports.gzl_ui:drawRoundedBorder(cardX, cardY, cardW, cardH, 12, 1, tocolor(255, 255, 255, 30))
    end

    local avatarSize = 52
    local avatarX = cardX + cardW - avatarSize - 14
    local avatarY = cardY + (cardH - avatarSize) / 2
    drawSafeRoundedRect(avatarX, avatarY, avatarSize, avatarSize, 12, tocolor(30, 41, 59, 200))
    if exports.gzl_ui and exports.gzl_ui.drawIconSVG then
        exports.gzl_ui:drawIconSVG("user", avatarX + 13, avatarY + 13, 26, tocolor(148, 163, 184, 255))
    end

    local textLeft = cardX + 16
    local textMaxRight = avatarX - 10
    local fontName = getSafeFont("bold", 12)
    local fontClass = getSafeFont("regular", 10)
    local fontRating = getSafeFont("bold", 11)

    dxDrawText(activeRide.name, textLeft, cardY + 10, textMaxRight, cardY + 28, tocolor(248, 250, 252, 255), 1.0, fontName, "left", "center", true)

    local curVeh = activeRide.vehicle
    local curDistTraveled = updateDisplayedRideDistance()
    local curRawFare = TaxiConfig.Pricing.baseFare + (curDistTraveled * TaxiConfig.Pricing.perMeterRate)
    local curLiveFare = math.floor(curRawFare * activeRide.currentMultiplier)
    curLiveFare = math.max(TaxiConfig.Pricing.minFare, math.min(TaxiConfig.Pricing.maxFare, curLiveFare))

    local destStr = string.format("Hedef: %s (%dm)", activeRide.destination.name, math.floor(getDistanceBetweenPoints3D(activeRide.destination.x, activeRide.destination.y, activeRide.destination.z, getElementPosition(curVeh))))
    dxDrawText(destStr, textLeft, cardY + 28, textMaxRight, cardY + 46, tocolor(203, 213, 225, 240), 1.0, fontClass, "left", "center", true)

    local fareAndBonus = string.format("Tutar: $%d  •  ★ %.1f", curLiveFare, activeRide.initialRating)
    dxDrawText(fareAndBonus, textLeft, cardY + 46, textMaxRight, cardY + 68, tocolor(52, 211, 153, 255), 1.0, fontRating, "left", "center")

    local barX = cardX
    local barY = cardY + cardH + barGap
    local barW = cardW

    drawSafeRoundedRect(barX - 2, barY - 2, barW + 4, barH + 4, 10, tocolor(0, 0, 0, 140))
    drawSafeGlass(barX, barY, barW, barH, 8, tocolor(15, 23, 42, 245))
    if exports.gzl_ui and exports.gzl_ui.drawRoundedBorder then
        exports.gzl_ui:drawRoundedBorder(barX, barY, barW, barH, 8, 1, tocolor(255, 255, 255, 25))
    end

    local multText = string.format("$%.1fx", activeRide.currentMultiplier)
    local multFont = getSafeFont("bold", 11)
    local multW = 54
    dxDrawText(multText, barX + 10, barY, barX + 10 + multW, barY + barH, tocolor(52, 211, 153, 255), 1.0, multFont, "left", "center")

    local trackX = barX + multW + 10
    local trackY = barY + 7
    local trackW = barW - multW - 20
    local trackH = barH - 14

    drawSafeRoundedRect(trackX, trackY, trackW, trackH, 4, tocolor(51, 65, 85, 220))

    local fillW = math.max(4, trackW * activeRide.comfortProgress)
    local fillColor = activeRide.comfortProgress > 0.4 and tocolor(16, 185, 129, 255) or tocolor(239, 68, 68, 255)
    drawSafeRoundedRect(trackX, trackY, fillW, trackH, 4, fillColor)

    local handleX = trackX + fillW - 2
    drawSafeRoundedRect(handleX, trackY - 2, 4, trackH + 4, 2, tocolor(255, 255, 255, 255))
end

local function render3DDestinationGuides()
    if not activeRide then
        return
    end

    local dest = activeRide.destination
    local veh = activeRide.vehicle
    if not isElement(veh) then
        return
    end

    local vx, vy, vz = getElementPosition(veh)
    local dist = getDistanceBetweenPoints3D(vx, vy, vz, dest.x, dest.y, dest.z)

    if dist <= 85.0 then
        drawDestinationParkingBox(dest.x, dest.y, dest.z)

        local sx, sy = getScreenFromWorldPosition(dest.x, dest.y, dest.z + 1.8)
        if sx and sy then
            local tagW = 140
            local tagH = 50
            local tagX = sx - tagW / 2
            local tagY = sy - tagH / 2

            drawSafeGlass(tagX, tagY, tagW, tagH, 10, tocolor(15, 23, 42, 230))
            if exports.gzl_ui and exports.gzl_ui.drawRoundedBorder then
                exports.gzl_ui:drawRoundedBorder(tagX, tagY, tagW, tagH, 10, 1, tocolor(250, 204, 21, 200))
            end

            local fontBold = getSafeFont("bold", 11)
            local fontSmall = getSafeFont("bold", 10)
            dxDrawText("HEDEF NOKTASI", tagX, tagY + 6, tagX + tagW, tagY + 26, tocolor(250, 204, 21, 255), 1.0, fontBold, "center", "center")
            dxDrawText(string.format("%dm", math.floor(dist)), tagX, tagY + 26, tagX + tagW, tagY + 44, tocolor(255, 255, 255, 255), 1.0, fontSmall, "center", "center")
        end

        if dist <= 38.0 and not activeRide.nearAlertGiven then
            activeRide.nearAlertGiven = true
            setPassengerSpeech("Lütfen yeşil park alanına yanaş kaptan.", 6000)
        end
    end

    local dirX = dest.x - vx
    local dirY = dest.y - vy
    local len = (dirX^2 + dirY^2)^0.5
    if len > 0.1 then
        dirX = dirX / len
        dirY = dirY / len
    end

    local numChevrons = math.min(6, math.max(2, math.floor(dist / 6)))
    local stepDist = 4.5
    for i = 1, numChevrons do
        local arrowDist = i * stepDist
        if arrowDist < dist then
            local ax = vx + dirX * arrowDist
            local ay = vy + dirY * arrowDist
            local az = getGroundPosition(ax, ay, vz + 5.0) or vz
            local arrowCol = dist <= 40.0 and tocolor(34, 197, 94, 210) or tocolor(250, 204, 21, 210)
            drawChevronArrow(ax, ay, az, dirX, dirY, 1.4, arrowCol)
        end
    end

    local dist2D = getDistanceBetweenPoints2D(vx, vy, dest.x, dest.y)
    local distZ = math.abs(vz - dest.z)
    if (dist <= TaxiConfig.Ride.deliveryRadius or (dist2D <= TaxiConfig.Ride.deliveryRadius and distZ <= 3.2)) then
        local spdX, spdY, spdZ = getElementVelocity(veh)
        local speedKmH = ((spdX^2 + spdY^2 + spdZ^2)^0.5) * 180
        if speedKmH <= TaxiConfig.Ride.deliveryMaxSpeed and getVehicleOccupant(veh, 0) == localPlayer then
            finishCurrentRide()
        end
    end
end

function finishCurrentRide()
    if not activeRide or activeRide.completing then
        return
    end
    activeRide.completing = true
    triggerServerEvent("taxi:completeRide", resourceRoot, activeRide.destIndex, activeRide.callId)
end

local function releaseRidePassengers(vehicle, passengers)
    setTimer(function()
        for i, ped in ipairs(passengers) do
            if isElement(ped) then
                if isElement(vehicle) then
                    removePedFromVehicle(ped)
                    setElementCollisionsEnabled(ped, true)
                    local px, py, pz = getElementPosition(vehicle)
                    local _, _, rz = getElementRotation(vehicle)
                    local rad = math.rad(-rz)
                    local rx, ry = math.cos(rad), -math.sin(rad)
                    local fx, fy = math.sin(rad), math.cos(rad)
                    local offsetLong = (i - 1) * 0.95 - (#passengers - 1) * 0.47
                    local exitX = px + rx * 2.3 + fx * offsetLong
                    local exitY = py + ry * 2.3 + fy * offsetLong
                    local exitZ = getGroundPosition(exitX, exitY, pz + 2.0) or pz
                    setElementPosition(ped, exitX, exitY, exitZ + 0.05)
                    setPedAnimation(ped, "PED", "WALK_civi", -1, true, true, false)
                end
            end
        end
        setTimer(function()
            for _, ped in ipairs(passengers) do
                if isElement(ped) then
                    destroyElement(ped)
                end
            end
        end, 3500, 1)
    end, 400, 1)
end

local function showRideCompleted(result)
    if not activeRide then return end
    local ride = activeRide
    completeRideData = {
        name = ride.name,
        className = ride.classData.className,
        distance = math.max(0, math.floor(tonumber(result.distance) or 0)),
        duration = math.max(0, math.floor(tonumber(result.duration) or 0)),
        multiplier = tonumber(result.multiplier) or 1.0,
        fare = math.max(0, math.floor(tonumber(result.amount) or 0))
    }
    local passengers = ride.peds or {}
    ride.peds = nil
    stopActiveRide(false)
    local finishLines = TaxiConfig.CustomerReactions.finish
    setPassengerSpeech(finishLines[math.random(1, #finishLines)], 3500)
    releaseRidePassengers(ride.vehicle, passengers)
    completeModalActive = true
    showCursor(true)
    playSoundFrontEnd(41)
end

local function renderCompletionModal()
    if not completeModalActive or not completeRideData then
        return
    end

    local modalW = 440
    local modalH = 430
    local modalX = (screenW - modalW) / 2
    local modalY = (screenH - modalH) / 2

    drawSafeRoundedRect(modalX - 4, modalY - 4, modalW + 8, modalH + 8, 20, tocolor(0, 0, 0, 80))
    drawSafeGlass(modalX, modalY, modalW, modalH, 18, tocolor(10, 15, 28, 252))
    if exports.gzl_ui and exports.gzl_ui.drawRoundedBorder then
        exports.gzl_ui:drawRoundedBorder(modalX, modalY, modalW, modalH, 18, 1, tocolor(255, 255, 255, 25))
    end

    local badgeW = 180
    local badgeH = 28
    local badgeX = modalX + 24
    local badgeY = modalY + 20
    drawSafeRoundedRect(badgeX, badgeY, badgeW, badgeH, 8, tocolor(16, 185, 129, 35))
    if exports.gzl_ui and exports.gzl_ui.drawRoundedBorder then
        exports.gzl_ui:drawRoundedBorder(badgeX, badgeY, badgeW, badgeH, 8, 1, tocolor(16, 185, 129, 90))
    end
    dxDrawText("YOLCULUK TAMAMLANDI", badgeX, badgeY, badgeX + badgeW, badgeY + badgeH, tocolor(52, 211, 153, 255), 1.0, getSafeFont("bold", 10), "center", "center")

    local closeSize = 28
    local closeX = modalX + modalW - closeSize - 24
    local closeY = modalY + 20
    local isCloseHover = isCursorOver(closeX, closeY, closeSize, closeSize)
    local closeColor = isCloseHover and tocolor(239, 68, 68, 240) or tocolor(30, 41, 59, 200)
    drawSafeRoundedRect(closeX, closeY, closeSize, closeSize, 6, closeColor)
    dxDrawText("✕", closeX, closeY, closeX + closeSize, closeY + closeSize, tocolor(241, 245, 249, 255), 1.0, getSafeFont("bold", 11), "center", "center")

    local avaSize = 44
    local avaX = modalX + 24
    local avaY = modalY + 68
    drawSafeRoundedRect(avaX, avaY, avaSize, avaSize, 22, tocolor(16, 185, 129, 30))
    if exports.gzl_ui and exports.gzl_ui.drawIconSVG then
        exports.gzl_ui:drawIconSVG("user", avaX + 11, avaY + 11, 22, tocolor(52, 211, 153, 255))
    end

    local textLeft = avaX + avaSize + 14
    local maxTextRight = modalX + modalW - 24
    dxDrawText(completeRideData.name, textLeft, avaY + 2, maxTextRight, avaY + 24, tocolor(248, 250, 252, 255), 1.0, getSafeFont("bold", 13), "left", "center", true)
    dxDrawText(completeRideData.className .. "  •  Müşteri Memnuniyeti", textLeft, avaY + 24, maxTextRight, avaY + 42, tocolor(148, 163, 184, 255), 1.0, getSafeFont("regular", 10), "left", "center")

    local quoteX = modalX + 24
    local quoteY = avaY + avaSize + 14
    local quoteW = modalW - 48
    local quoteH = 36
    drawSafeRoundedRect(quoteX, quoteY, quoteW, quoteH, 8, tocolor(30, 41, 59, 160))
    dxDrawText('"Eline sağlık kaptan, teşekkürler!"', quoteX + 12, quoteY, quoteX + quoteW - 12, quoteY + quoteH, tocolor(203, 213, 225, 240), 1.0, getSafeFont("medium", 9), "left", "center")

    local cardX = modalX + 24
    local cardY = quoteY + quoteH + 14
    local cardW = modalW - 48
    local cardH = 92
    drawSafeRoundedRect(cardX, cardY, cardW, cardH, 10, tocolor(15, 23, 42, 190))
    if exports.gzl_ui and exports.gzl_ui.drawRoundedBorder then
        exports.gzl_ui:drawRoundedBorder(cardX, cardY, cardW, cardH, 10, 1, tocolor(255, 255, 255, 18))
    end

    local fontMetaLabel = getSafeFont("regular", 9)
    local fontMetaVal = getSafeFont("bold", 11)

    local col1X = cardX + 16
    local col2X = cardX + cardW / 2 + 10
    local row1Y = cardY + 14
    local row2Y = cardY + 52

    dxDrawText("KAT EDİLEN MESAFE", col1X, row1Y, col1X + 180, row1Y + 16, tocolor(148, 163, 184, 240), 1.0, fontMetaLabel, "left", "center")
    dxDrawText(string.format("%d Metre", completeRideData.distance), col1X, row1Y + 16, col1X + 180, row1Y + 36, tocolor(241, 245, 249, 255), 1.0, fontMetaVal, "left", "center")

    dxDrawText("YOLCULUK SÜRESİ", col2X, row1Y, col2X + 180, row1Y + 16, tocolor(148, 163, 184, 240), 1.0, fontMetaLabel, "left", "center")
    local mins = math.floor(completeRideData.duration / 60)
    local secs = completeRideData.duration % 60
    local durStr = mins > 0 and string.format("%d dk %d sn", mins, secs) or string.format("%d Saniye", secs)
    dxDrawText(durStr, col2X, row1Y + 16, col2X + 180, row1Y + 36, tocolor(241, 245, 249, 255), 1.0, fontMetaVal, "left", "center")

    dxDrawText("SÜRÜŞ ÇARPANI", col1X, row2Y, col1X + 180, row2Y + 16, tocolor(148, 163, 184, 240), 1.0, fontMetaLabel, "left", "center")
    dxDrawText(string.format("%.1fx Konfor Bonusu", completeRideData.multiplier), col1X, row2Y + 16, col1X + 180, row2Y + 36, tocolor(52, 211, 153, 255), 1.0, fontMetaVal, "left", "center")

    dxDrawText("HİZMET DURUMU", col2X, row2Y, col2X + 180, row2Y + 16, tocolor(148, 163, 184, 240), 1.0, fontMetaLabel, "left", "center")
    dxDrawText("Kusursuz Teslimat", col2X, row2Y + 16, col2X + 180, row2Y + 36, tocolor(241, 245, 249, 255), 1.0, fontMetaVal, "left", "center")

    local fareLabelY = cardY + cardH + 12
    dxDrawText("TOPLAM KAZANILAN NAKİT", modalX, fareLabelY, modalX + modalW, fareLabelY + 16, tocolor(148, 163, 184, 255), 1.0, getSafeFont("bold", 10), "center", "center")

    local totalFareStr = string.format("$%d", completeRideData.fare)
    local fareValY = fareLabelY + 16
    dxDrawText(totalFareStr, modalX, fareValY, modalX + modalW, fareValY + 36, tocolor(52, 211, 153, 255), 1.0, getSafeFont("bold", 24), "center", "center")

    local btnW = modalW - 48
    local btnH = 44
    local btnX = modalX + 24
    local btnY = modalY + modalH - btnH - 18
    local isBtnHover = isCursorOver(btnX, btnY, btnW, btnH)
    local btnBg = isBtnHover and tocolor(16, 185, 129, 255) or tocolor(5, 150, 105, 235)
    drawSafeRoundedRect(btnX, btnY, btnW, btnH, 8, btnBg)
    dxDrawText("DEVAM ET", btnX, btnY, btnX + btnW, btnY + btnH, tocolor(255, 255, 255, 255), 1.0, getSafeFont("bold", 12), "center", "center")
end

addEventHandler("onClientRender", root, function()
    renderRideTopBanner()
    render3DDestinationGuides()
    renderPassengerCardAndBar()
    renderCompletionModal()
end)

addEventHandler("onClientClick", root, function(button, state)
    if not completeModalActive or button ~= "left" or state ~= "down" then
        return
    end

    local modalW = 440
    local modalH = 430
    local modalX = (screenW - modalW) / 2
    local modalY = (screenH - modalH) / 2

    local closeSize = 28
    local closeX = modalX + modalW - closeSize - 24
    local closeY = modalY + 20

    local btnW = modalW - 48
    local btnH = 44
    local btnX = modalX + 24
    local btnY = modalY + modalH - btnH - 18

    if isCursorOver(btnX, btnY, btnW, btnH) or isCursorOver(closeX, closeY, closeSize, closeSize) then
        playSoundFrontEnd(12)
        completeModalActive = false
        completeRideData = nil
        showCursor(false)
    end
end)

local lastCollisionLossTick = 0

local function applyRideVehicleDamage()
    if not activeRide then return end
    local now = getTickCount()
    if now - lastCollisionLossTick < 1500 then return end
    lastCollisionLossTick = now
    local crashList = TaxiConfig.CustomerReactions.crash
    local randCrash = crashList[math.random(1, #crashList)]
    setPassengerSpeech(randCrash, 4500)
end

addEventHandler("onClientVehicleDamage", root, function(attacker, weapon, loss)
    if not activeRide then return end
    local veh = getPedOccupiedVehicle(localPlayer)
    if source ~= veh then return end
    if loss and loss > 20 then
        applyRideVehicleDamage()
    end
end)

addEventHandler("onClientVehicleCollision", root, function(collider, force)
    if not activeRide then return end
    local veh = getPedOccupiedVehicle(localPlayer)
    if source ~= veh then return end
    if force and force > 120 then
        applyRideVehicleDamage()
    end
end)

addEventHandler("onClientPlayerVehicleExit", localPlayer, function(veh, seat)
    if seat == 0 then
        if cancelTaxiPickup then
            cancelTaxiPickup(true)
        end
        if activeRide then
            stopActiveRide(true)
            if exports.gzl_ui and exports.gzl_ui.showToast then
                exports.gzl_ui:showToast("warning", "Taksiden indiğin için yolculuk iptal edildi!")
            end
        end
    end
end)

addEventHandler("onClientVehicleExplode", root, function()
    if activeRide and activeRide.vehicle == source then
        stopActiveRide(true)
        if exports.gzl_ui and exports.gzl_ui.showToast then
            exports.gzl_ui:showToast("error", "Araç hasar gördüğü için yolculuk iptal edildi!")
        end
    end
end)

addEventHandler("onClientPlayerWasted", localPlayer, function()
    if activeRide then
        stopActiveRide(true)
    end
end)

addEvent("taxi:forceCancelRide", true)
addEventHandler("taxi:forceCancelRide", root, function(message)
    if cancelTaxiPickup then
        cancelTaxiPickup(true)
    end
    if activeRide then
        stopActiveRide(true)
        if exports.gzl_ui and exports.gzl_ui.showToast then
            exports.gzl_ui:showToast("warning", message or "Yolculuk sonlandırıldı.")
        end
    end
end)

addEvent("taxi:ridePenalty", true)
addEventHandler("taxi:ridePenalty", root, function(amount)
    if not activeRide then return end
    local penalty = math.max(0, tonumber(amount) or 0)
    activeRide.serviceMultiplier = math.max(TaxiConfig.Ride.minimumServiceMultiplier, activeRide.serviceMultiplier - penalty)
    activeRide.currentMultiplier = activeRide.basePayMultiplier * activeRide.serviceMultiplier
    activeRide.comfortProgress = math.max(0.1, activeRide.serviceMultiplier)
    applyRideVehicleDamage()
end)

addEvent("taxi:rideCompleted", true)
addEventHandler("taxi:rideCompleted", root, function(result)
    if type(result) ~= "table" then return end
    showRideCompleted(result)
end)

addEvent("taxi:rideCompletionFailed", true)
addEventHandler("taxi:rideCompletionFailed", root, function(message, terminal)
    if terminal and activeRide then
        stopActiveRide(true)
    elseif activeRide then
        activeRide.completing = false
    end
    if message and exports.gzl_ui and exports.gzl_ui.showToast then
        exports.gzl_ui:showToast("warning", message)
    end
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    stopActiveRide(true)
    completeModalActive = false
    completeRideData = nil
    for _, f in pairs(localHudFontCache) do
        if isElement(f) then
            destroyElement(f)
        end
    end
    localHudFontCache = {}
end)

addEventHandler("onClientResourceStart", resourceRoot, function()
    preloadRideFonts()
end)