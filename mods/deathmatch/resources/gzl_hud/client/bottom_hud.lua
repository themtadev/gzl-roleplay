local screenW, screenH = guiGetScreenSize()

local isEnabled = true
local currentAlpha = 0
local targetAlpha = 0
local animSpeed = 0.14

local currentPing = 0
local packetLoss = 0
local playerId = 1

local svgCache = {}
local fontCache = {}

local isCharSpawned = false
local isBigmapOpen = false
local isRadarPauseOpen = false

local fontScale = 1.0
local panelH = 26
local radius = 7
local marginX = 20
local marginY = 14

local serverName = "GZL"
local idLabel = "ID"
local pingLabel = "MS"

local dotSize = 10
local iconSize = 12
local padX = 10
local itemSpacing = 8
local dividerW = 1

local idValue = "#1"
local pingValue = "0"
local lossText = ""

local srvW = 0
local idLabelW = 0
local pingLabelW = 0
local srvNameW = 0

local idW = 0
local idValW = 0
local pingW = 0
local pingValW = 0
local lossW = 0
local hasLoss = false
local totalW = 180

local cachedGlassSvg = nil
local cachedLiveDotSvg = nil
local cachedSigSvg = nil
local lastPingState = ""

local pingColor = {16, 185, 129}

local function loadBottomHudSettings()
    if fileExists("@bottom_hud.json") then
        local file = fileOpen("@bottom_hud.json")
        if file then
            local size = fileGetSize(file)
            local content = (size > 0) and fileRead(file, size) or ""
            fileClose(file)
            if content and content ~= "" then
                local parsed = fromJSON(content)
                if type(parsed) == "table" and parsed.enabled ~= nil then
                    isEnabled = (parsed.enabled == true)
                    return
                end
            end
        end
    end
    isEnabled = true
end

local function saveBottomHudSettings()
    if fileExists("@bottom_hud.json") then
        fileDelete("@bottom_hud.json")
    end
    local file = fileCreate("@bottom_hud.json")
    if file then
        local data = { enabled = isEnabled }
        fileWrite(file, toJSON(data))
        fileClose(file)
    end
end

local function getUIFont(weight, size)
    local key = weight .. "_" .. tostring(size)
    if not fontCache[key] then
        if exports.gzl_ui and exports.gzl_ui.getFont then
            fontCache[key] = exports.gzl_ui:getFont(weight, size) or "default-bold"
        else
            fontCache[key] = "default-bold"
        end
    end
    return fontCache[key]
end

local currentPillSvg = nil
local currentPillW = 0
local currentPillH = 0
local currentPillR = 0

local function getGlassPillSVG(w, h, r)
    local roundedW = math.max(16, math.ceil(w / 4) * 4)
    if isElement(currentPillSvg) and roundedW == currentPillW and h == currentPillH and r == currentPillR then
        return currentPillSvg
    end

    if isElement(currentPillSvg) then
        destroyElement(currentPillSvg)
        currentPillSvg = nil
        svgCache["bottom_hud_pill"] = nil
    end

    local strokeW = 1.0
    local innerW = roundedW - strokeW
    local innerH = h - strokeW

    local svgData = string.format([[
        <svg width="%d" height="%d" viewBox="0 0 %d %d" fill="none" xmlns="http://www.w3.org/2000/svg">
            <defs>
                <linearGradient id="bg" x1="0%%" y1="0%%" x2="0%%" y2="100%%">
                    <stop offset="0%%" stop-color="#121620" stop-opacity="0.94"/>
                    <stop offset="100%%" stop-color="#0b0f17" stop-opacity="0.98"/>
                </linearGradient>
                <linearGradient id="stroke" x1="0%%" y1="0%%" x2="100%%" y2="100%%">
                    <stop offset="0%%" stop-color="#ffffff" stop-opacity="0.14"/>
                    <stop offset="50%%" stop-color="#ffffff" stop-opacity="0.04"/>
                    <stop offset="100%%" stop-color="#ffffff" stop-opacity="0.02"/>
                </linearGradient>
            </defs>
            <rect x="0.5" y="0.5" width="%.2f" height="%.2f" rx="%.1f" ry="%.1f" fill="url(#bg)" stroke="url(#stroke)" stroke-width="1.0"/>
        </svg>
    ]], roundedW, h, roundedW, h, innerW, innerH, r, r)

    currentPillSvg = svgCreate(roundedW, h, svgData)
    currentPillW = roundedW
    currentPillH = h
    currentPillR = r
    svgCache["bottom_hud_pill"] = currentPillSvg
    return currentPillSvg
end

local function getLiveDotSVG(size)
    local key = "bottom_hud_live_dot_" .. size
    if not svgCache[key] or not isElement(svgCache[key]) then
        local r = size / 2
        local innerR = r * 0.55
        local svgData = string.format([[
            <svg width="%d" height="%d" viewBox="0 0 %d %d" fill="none" xmlns="http://www.w3.org/2000/svg">
                <circle cx="%.1f" cy="%.1f" r="%.1f" fill="#10b981" fill-opacity="0.25"/>
                <circle cx="%.1f" cy="%.1f" r="%.1f" fill="#10b981"/>
            </svg>
        ]], size, size, size, size, r, r, r, r, r, innerR)
        svgCache[key] = svgCreate(size, size, svgData)
    end
    return svgCache[key]
end

local function getSignalIconSVG(size, ping)
    local state = (ping > 120 and "poor") or (ping > 60 and "medium") or "good"
    local key = "bottom_hud_signal_" .. size .. "_" .. state
    if not svgCache[key] or not isElement(svgCache[key]) then
        local c1 = (state == "poor" and "#f43f5e" or (state == "medium" and "#f59e0b" or "#10b981"))
        local c2 = (state == "poor" and "rgba(255,255,255,0.18)" or (state == "medium" and "#f59e0b" or "#10b981"))
        local c3 = (state == "poor" and "rgba(255,255,255,0.18)" or (state == "medium" and "rgba(255,255,255,0.18)" or "#10b981"))

        local svgData = string.format([[
            <svg width="%d" height="%d" viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg">
                <rect x="2" y="10" width="3" height="5" rx="0.8" fill="%s"/>
                <rect x="6.5" y="6" width="3" height="9" rx="0.8" fill="%s"/>
                <rect x="11" y="2" width="3" height="13" rx="0.8" fill="%s"/>
            </svg>
        ]], size, size, c1, c2, c3)

        svgCache[key] = svgCreate(size, size, svgData)
    end
    return svgCache[key]
end

local function recalculateTotalWidth()
    local fontBold = getUIFont("bold", 9)
    local fontMedium = getUIFont("medium", 8)
    local fontHeavy = getUIFont("heavy", 9)

    srvNameW = dxGetTextWidth(serverName, fontScale, fontHeavy)
    srvW = dotSize + 5 + srvNameW
    idLabelW = dxGetTextWidth(idLabel, fontScale, fontMedium)
    pingLabelW = dxGetTextWidth(pingLabel, fontScale, fontMedium)

    idValW = dxGetTextWidth(idValue, fontScale, fontBold)
    idW = idLabelW + 4 + idValW


    pingValW = dxGetTextWidth(pingValue, fontScale, fontBold)
    pingW = iconSize + 4 + pingValW + 3 + pingLabelW

    hasLoss = (packetLoss > 0.5)
    if hasLoss then
        lossText = "LOSS " .. tostring(packetLoss) .. "%"
        lossW = dxGetTextWidth(lossText, fontScale, fontBold)
    else
        lossW = 0
    end

    totalW = padX * 2 + srvW + dividerW + itemSpacing * 2 + idW + dividerW + itemSpacing * 2 + pingW
    if hasLoss then
        totalW = totalW + dividerW + itemSpacing * 2 + lossW
    end
    totalW = math.max(16, math.ceil(totalW / 4) * 4)

    cachedGlassSvg = getGlassPillSVG(totalW, panelH, radius)
end

function setBottomHUDVisible(state)
    isEnabled = (state == true)
    saveBottomHudSettings()
end

function isBottomHUDVisible()
    return isEnabled
end

local function updatePingAndNetwork()
    currentPing = getPlayerPing(localPlayer) or 0
    local pId = getElementData(localPlayer, "character:id") or getElementData(localPlayer, "char:id") or getElementData(localPlayer, "account:id") or 1
    playerId = tonumber(pId) or 1
    idValue = "#" .. tostring(playerId)
    pingValue = tostring(currentPing)

    local stats = getNetworkStats()
    if stats and stats.packetlossLastSecond then
        packetLoss = math.floor(stats.packetlossLastSecond * 10) / 10
    else
        packetLoss = 0
    end

    if currentPing <= 60 then
        pingColor = {16, 185, 129}
    elseif currentPing <= 120 then
        pingColor = {245, 158, 11}
    else
        pingColor = {244, 63, 94}
    end

    local pingState = (currentPing > 120 and "poor") or (currentPing > 60 and "medium") or "good"
    if pingState ~= lastPingState or not isElement(cachedSigSvg) then
        lastPingState = pingState
        cachedSigSvg = getSignalIconSVG(iconSize, currentPing)
    end

    recalculateTotalWidth()
end

setTimer(updatePingAndNetwork, 1000, 0)

setTimer(function()
    if exports.gzl_radar and exports.gzl_radar.isPauseMenuOpen then
        isRadarPauseOpen = exports.gzl_radar:isPauseMenuOpen()
    else
        isRadarPauseOpen = false
    end
end, 250, 0)

addEventHandler("onClientElementDataChange", localPlayer, function(key)
    if key == "character:id" or key == "char:id" or key == "loggedin_character" or key == "account:id" then
        isCharSpawned = (getElementData(localPlayer, "character:id") or getElementData(localPlayer, "char:id") or getElementData(localPlayer, "loggedin_character")) and true or false
        local pId = getElementData(localPlayer, "character:id") or getElementData(localPlayer, "char:id") or getElementData(localPlayer, "account:id") or 1
        playerId = tonumber(pId) or 1
        idValue = "#" .. tostring(playerId)
        recalculateTotalWidth()
    elseif key == "bigmap:isOpen" then
        isBigmapOpen = (getElementData(localPlayer, key) == true)
    end
end)

addEventHandler("onClientRender", root, function()
    local now = getTickCount()

    local isHudOn = true
    if isHUDVisible then
        isHudOn = isHUDVisible()
    end

    local isMapShowing = isPlayerMapVisible() or isBigmapOpen or isRadarPauseOpen
    local shouldShow = isEnabled and isHudOn and isCharSpawned and not isMapShowing and not isMainMenuActive()

    targetAlpha = shouldShow and 1 or 0
    currentAlpha = currentAlpha + (targetAlpha - currentAlpha) * animSpeed
    if math.abs(targetAlpha - currentAlpha) < 0.005 then
        currentAlpha = targetAlpha
    end

    if currentAlpha <= 0.01 then return end

    local fontBold = getUIFont("bold", 9)
    local fontMedium = getUIFont("medium", 8)
    local fontHeavy = getUIFont("heavy", 9)

    local posX = screenW - totalW - marginX
    local posY = screenH - panelH - marginY
    local alphaByte = math.floor(currentAlpha * 255)
    local mutedAlpha = math.floor(currentAlpha * 160)
    local dividerAlpha = math.floor(currentAlpha * 25)

    if cachedGlassSvg and isElement(cachedGlassSvg) then
        dxDrawImage(posX, posY, totalW, panelH, cachedGlassSvg, 0, 0, 0, tocolor(255, 255, 255, alphaByte), false)
    else
        dxDrawRectangle(posX, posY, totalW, panelH, tocolor(11, 15, 23, math.floor(currentAlpha * 240)), false)
    end

    local curX = posX + padX
    local centerY = posY + panelH / 2

    if cachedLiveDotSvg then
        local pulse = 0.85 + 0.15 * math.sin(now / 350)
        dxDrawImage(curX, math.floor(centerY - dotSize / 2), dotSize, dotSize, cachedLiveDotSvg, 0, 0, 0, tocolor(255, 255, 255, math.floor(alphaByte * pulse)), false)
    end
    curX = curX + dotSize + 5

    dxDrawText(serverName, curX, posY, curX + 100, posY + panelH, tocolor(248, 250, 252, alphaByte), fontScale, fontHeavy, "left", "center", false, false, false, false)
    curX = curX + srvNameW + itemSpacing

    dxDrawRectangle(curX, posY + 7, dividerW, panelH - 14, tocolor(255, 255, 255, dividerAlpha), false)
    curX = curX + dividerW + itemSpacing

    dxDrawText(idLabel, curX, posY, curX + idLabelW, posY + panelH, tocolor(148, 163, 184, mutedAlpha), fontScale, fontMedium, "left", "center", false, false, false, false)
    curX = curX + idLabelW + 4

    dxDrawText(idValue, curX, posY, curX + idValW, posY + panelH, tocolor(56, 189, 248, alphaByte), fontScale, fontBold, "left", "center", false, false, false, false)
    curX = curX + idValW + itemSpacing

    dxDrawRectangle(curX, posY + 7, dividerW, panelH - 14, tocolor(255, 255, 255, dividerAlpha), false)
    curX = curX + dividerW + itemSpacing

    if cachedSigSvg then
        dxDrawImage(curX, math.floor(centerY - iconSize / 2), iconSize, iconSize, cachedSigSvg, 0, 0, 0, tocolor(255, 255, 255, alphaByte), false)
    end
    curX = curX + iconSize + 4

    dxDrawText(pingValue, curX, posY, curX + pingValW, posY + panelH, tocolor(pingColor[1], pingColor[2], pingColor[3], alphaByte), fontScale, fontBold, "left", "center", false, false, false, false)
    curX = curX + pingValW + 3

    dxDrawText(pingLabel, curX, posY, curX + pingLabelW, posY + panelH, tocolor(148, 163, 184, mutedAlpha), fontScale, fontMedium, "left", "center", false, false, false, false)
    curX = curX + pingLabelW

    if hasLoss then
        curX = curX + itemSpacing
        dxDrawRectangle(curX, posY + 7, dividerW, panelH - 14, tocolor(255, 255, 255, dividerAlpha), false)
        curX = curX + dividerW + itemSpacing

        dxDrawText(lossText, curX, posY, curX + lossW, posY + panelH, tocolor(244, 63, 94, alphaByte), fontScale, fontBold, "left", "center", false, false, false, false)
    end
end)

local function toggleBottomHudCommand()
    isEnabled = not isEnabled
    saveBottomHudSettings()

    local stateMsg = isEnabled and "aktif edildi." or "devre dışı bırakıldı."
    local stateType = isEnabled and "success" or "info"

    if exports.gzl_ui and exports.gzl_ui.showNotification then
        exports.gzl_ui:showNotification("SİSTEM GÖSTERGESİ", "Sağ alt HUD " .. stateMsg, stateType, 2200)
    else
        outputChatBox("[GZL] Sağ alt HUD " .. stateMsg, 45, 212, 191)
    end
end

addCommandHandler("bottomhud", toggleBottomHudCommand)

addEventHandler("onClientResourceStart", resourceRoot, function()
    loadBottomHudSettings()
    isCharSpawned = (getElementData(localPlayer, "character:id") or getElementData(localPlayer, "char:id") or getElementData(localPlayer, "loggedin_character")) and true or false
    isBigmapOpen = (getElementData(localPlayer, "bigmap:isOpen") == true)
    cachedLiveDotSvg = getLiveDotSVG(dotSize)
    cachedSigSvg = getSignalIconSVG(iconSize, currentPing)
    recalculateTotalWidth()
end)

addEventHandler("onClientRestore", root, function()
    screenW, screenH = guiGetScreenSize()
    if not isElement(cachedLiveDotSvg) then cachedLiveDotSvg = getLiveDotSVG(dotSize) end
    if not isElement(cachedSigSvg) then cachedSigSvg = getSignalIconSVG(iconSize, currentPing) end
    recalculateTotalWidth()
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    for _, svg in pairs(svgCache) do
        if isElement(svg) then
            destroyElement(svg)
        end
    end
    svgCache = {}
    fontCache = {}
    cachedGlassSvg = nil
    cachedLiveDotSvg = nil
    cachedSigSvg = nil
    currentPillSvg = nil
    currentPillW = 0
    currentPillH = 0
    currentPillR = 0
    lastPingState = ""
end)