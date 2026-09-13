local screenW, screenH = guiGetScreenSize()

local isCinematicActive = false
local currentDialogueText = ""
local displayedCharCount = 0
local textTimer = nil
local isTextFinished = false
local liveNecoPed = nil

local function getSafeUtf8Len(str)
    if utf8 and utf8.len then
        return utf8.len(str) or #str
    end
    return #str
end

local function getSafeUtf8Sub(str, i, j)
    if utf8 and utf8.sub then
        return utf8.sub(str, i, j)
    end
    return string.sub(str, i, j)
end

local function getSafeFont(fontType, size)
    if exports.gzl_ui and exports.gzl_ui.getFont then
        local f = exports.gzl_ui:getFont(fontType, size)
        if f then return f end
    end
    return fontType == "bold" and "default-bold" or "default"
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

local function closeCinematic()
    isCinematicActive = false
    showCursor(false)
    setCameraTarget(localPlayer)
    setElementFrozen(localPlayer, false)
    if isTimer(textTimer) then
        killTimer(textTimer)
        textTimer = nil
    end
    removeEventHandler("onClientRender", root, renderNecoCinematicUI)
    removeEventHandler("onClientClick", root, handleCinematicClick)
end

function handleCinematicClick(button, state)
    if not isCinematicActive or button ~= "left" or state ~= "down" then
        return
    end

    local panelW = math.min(880, screenW * 0.75)
    local panelH = 190
    local panelX = (screenW - panelW) / 2
    local panelY = screenH - panelH - 45

    local btnW = 145
    local btnH = 38
    local btnGap = 12

    local noBtnX = panelX + panelW - btnW - 20
    local noBtnY = panelY + 18
    local yesBtnX = noBtnX - btnW - btnGap
    local yesBtnY = noBtnY

    if isCursorOver(yesBtnX, yesBtnY, btnW, btnH) then
        playSoundFrontEnd(41)
        triggerServerEvent("taxi:confirmPlatePurchase", resourceRoot)
        closeCinematic()
    elseif isCursorOver(noBtnX, noBtnY, btnW, btnH) then
        playSoundFrontEnd(41)
        closeCinematic()
    end
end

function renderNecoCinematicUI()
    if not isCinematicActive then
        return
    end

    local cam = TaxiConfig.CameraCinematic
    setCameraMatrix(cam.camX, cam.camY, cam.camZ, cam.targetX, cam.targetY, cam.targetZ)

    local panelW = math.min(880, screenW * 0.75)
    local panelH = 190
    local panelX = (screenW - panelW) / 2
    local panelY = screenH - panelH - 45

    drawSafeRoundedRect(panelX - 16, panelY - 14, panelW + 32, panelH + 28, 28, tocolor(0, 0, 0, 80))
    drawSafeRoundedRect(panelX - 8, panelY - 7, panelW + 16, panelH + 14, 22, tocolor(0, 0, 0, 150))
    drawSafeGlass(panelX, panelY, panelW, panelH, 16, tocolor(10, 15, 28, 252))
    if exports.gzl_ui and exports.gzl_ui.drawRoundedBorder then
        exports.gzl_ui:drawRoundedBorder(panelX, panelY, panelW, panelH, 16, 1, tocolor(255, 255, 255, 35))
    end

    local fontTitle = getSafeFont("bold", 14)
    local fontSub = getSafeFont("bold", 11)
    local fontBody = getSafeFont("medium", 13)
    local fontBtn = getSafeFont("bold", 11)

    local badgeW = 34
    local badgeH = 34
    local badgeX = panelX + 24
    local badgeY = panelY + 18
    drawSafeRoundedRect(badgeX, badgeY, badgeW, badgeH, 10, tocolor(245, 158, 11, 230))
    if exports.gzl_ui and exports.gzl_ui.drawIconSVG then
        exports.gzl_ui:drawIconSVG("car", badgeX + 7, badgeY + 7, 20, tocolor(255, 255, 255, 255))
    else
        dxDrawText("TAXI", badgeX, badgeY, badgeX + badgeW, badgeY + badgeH, tocolor(255, 255, 255, 255), 1.0, getSafeFont("bold", 9), "center", "center")
    end

    local titleX = badgeX + badgeW + 12
    local titleRight = panelX + panelW - 320
    dxDrawText(TaxiConfig.NecoPed.name, titleX + 1, badgeY + 1, titleRight + 1, badgeY + 19, tocolor(0, 0, 0, 240), 1.0, fontTitle, "left", "center")
    dxDrawText(TaxiConfig.NecoPed.name, titleX, badgeY, titleRight, badgeY + 18, tocolor(254, 240, 138, 255), 1.0, fontTitle, "left", "center")

    dxDrawText(TaxiConfig.NecoPed.title, titleX + 1, badgeY + 19, titleRight + 1, badgeY + 35, tocolor(0, 0, 0, 240), 1.0, fontSub, "left", "center")
    dxDrawText(TaxiConfig.NecoPed.title, titleX, badgeY + 18, titleRight, badgeY + 34, tocolor(226, 232, 240, 255), 1.0, fontSub, "left", "center")

    local btnW = 145
    local btnH = 38
    local btnGap = 12

    local noBtnX = panelX + panelW - btnW - 20
    local noBtnY = panelY + 18
    local yesBtnX = noBtnX - btnW - btnGap
    local yesBtnY = noBtnY

    local isYesHover = isCursorOver(yesBtnX, yesBtnY, btnW, btnH)
    local isNoHover = isCursorOver(noBtnX, noBtnY, btnW, btnH)

    local yesColor = isYesHover and tocolor(34, 197, 94, 240) or tocolor(22, 163, 74, 200)
    local noColor = isNoHover and tocolor(239, 68, 68, 240) or tocolor(220, 38, 38, 190)

    drawSafeRoundedRect(yesBtnX, yesBtnY, btnW, btnH, 8, yesColor)
    drawSafeRoundedRect(noBtnX, noBtnY, btnW, btnH, 8, noColor)

    dxDrawText("EVET ($1.000)", yesBtnX + 1, yesBtnY + 1, yesBtnX + btnW + 1, yesBtnY + btnH + 1, tocolor(0, 0, 0, 180), 1.0, fontBtn, "center", "center")
    dxDrawText("EVET ($1.000)", yesBtnX, yesBtnY, yesBtnX + btnW, yesBtnY + btnH, tocolor(255, 255, 255, 255), 1.0, fontBtn, "center", "center")

    dxDrawText("HAYIR", noBtnX + 1, noBtnY + 1, noBtnX + btnW + 1, noBtnY + btnH + 1, tocolor(0, 0, 0, 180), 1.0, fontBtn, "center", "center")
    dxDrawText("HAYIR", noBtnX, noBtnY, noBtnX + btnW, noBtnY + btnH, tocolor(255, 255, 255, 255), 1.0, fontBtn, "center", "center")

    local divY = panelY + 64
    drawSafeRoundedRect(panelX + 24, divY, panelW - 48, 1, 1, tocolor(255, 255, 255, 25))

    local textX = panelX + 26
    local textY = divY + 16
    local textW = panelW - 52
    local textH = panelH - 85

    local activeSlice = getSafeUtf8Sub(currentDialogueText, 1, displayedCharCount)
    dxDrawText(activeSlice, textX + 1, textY + 1, textX + textW + 1, textY + textH + 1, tocolor(0, 0, 0, 240), 1.0, fontBody, "left", "top", true, true)
    dxDrawText(activeSlice, textX, textY, textX + textW, textY + textH, tocolor(248, 250, 252, 255), 1.0, fontBody, "left", "top", true, true)
end

addEvent("taxi:openNecoCinematic", true)
addEventHandler("taxi:openNecoCinematic", root, function(dialogueText)
    if isCinematicActive then
        return
    end

    currentDialogueText = dialogueText or "Taksi plakası mı lazım genç adam?"
    displayedCharCount = 0
    isTextFinished = false
    isCinematicActive = true

    setElementFrozen(localPlayer, true)
    showCursor(true)

    if isTimer(textTimer) then
        killTimer(textTimer)
    end

    textTimer = setTimer(function()
        local totalLen = getSafeUtf8Len(currentDialogueText)
        if displayedCharCount < totalLen then
            displayedCharCount = displayedCharCount + 1
        else
            isTextFinished = true
            killTimer(textTimer)
            textTimer = nil
        end
    end, 32, 0)

    addEventHandler("onClientRender", root, renderNecoCinematicUI)
    addEventHandler("onClientClick", root, handleCinematicClick)
end)

addEvent("taxi:purchaseResult", true)
addEventHandler("taxi:purchaseResult", root, function(success, messageOrPlate)
    if success then
        if exports.gzl_ui and exports.gzl_ui.showNotification then
            exports.gzl_ui:showNotification("success", "Taksi Plakası Alındı", messageOrPlate .. " plakası aracına başarıyla takıldı!")
        else
            outputChatBox("#22c55e[GZL-TAKSI]#ffffff Plakaniz basariyla takildi: #facc15" .. tostring(messageOrPlate), 255, 255, 255, true)
        end
    else
        if exports.gzl_ui and exports.gzl_ui.showNotification then
            exports.gzl_ui:showNotification("error", "Plaka Alınamadı", messageOrPlate)
        else
            outputChatBox("#ef4444[GZL-TAKSI]#ffffff " .. tostring(messageOrPlate), 255, 255, 255, true)
        end
    end
end)

local function getLiveNecoPed()
    if isElement(liveNecoPed) then
        return liveNecoPed
    end
    for _, p in ipairs(getElementsByType("ped")) do
        if getElementData(p, "taxi:isNeco") then
            liveNecoPed = p
            return p
        end
    end
    return nil
end

local function getLiveNecoPosition()
    local ped = getLiveNecoPed()
    if isElement(ped) then
        return getElementPosition(ped)
    end
    local cfg = TaxiConfig.NecoSeatAttachment
    return cfg.anchorPos.x, cfg.anchorPos.y, cfg.anchorPos.z
end

addEventHandler("onClientElementStreamIn", root, function()
    if getElementData(source, "taxi:isNeco") then
        liveNecoPed = source
        local chair = getElementAttachedTo(source)
        if isElement(chair) then
            setElementCollidableWith(source, chair, false)
        end
        local cfg = TaxiConfig.NecoSeatAttachment
        setPedAnimation(source, cfg.animBlock, cfg.animName, -1, true, false, false, false)
    end
end)

addEventHandler("onClientElementStreamOut", root, function()
    if source == liveNecoPed then
        liveNecoPed = nil
    end
end)

addEventHandler("onClientResourceStart", resourceRoot, function()
    local ped = getLiveNecoPed()
    if isElement(ped) then
        local chair = getElementAttachedTo(ped)
        if isElement(chair) then
            setElementCollidableWith(ped, chair, false)
        end
        local cfg = TaxiConfig.NecoSeatAttachment
        setPedAnimation(ped, cfg.animBlock, cfg.animName, -1, true, false, false, false)
    end
end)

addEventHandler("onClientRender", root, function()
    if isCinematicActive then
        return
    end

    local px, py, pz = getElementPosition(localPlayer)
    local nx, ny, nz = getLiveNecoPosition()
    local dist = getDistanceBetweenPoints3D(px, py, pz, nx, ny, nz)

    if dist <= 3.8 then
        local sx, sy = getScreenFromWorldPosition(nx, ny, nz + 0.85)
        if sx and sy then
            local cardW = 210
            local cardH = 50
            local cardX = sx - cardW / 2
            local cardY = sy - cardH / 2

            drawSafeGlass(cardX, cardY, cardW, cardH, 10, tocolor(15, 23, 42, 230))
            if exports.gzl_ui and exports.gzl_ui.drawRoundedBorder then
                exports.gzl_ui:drawRoundedBorder(cardX, cardY, cardW, cardH, 10, 1, tocolor(255, 255, 255, 40))
            end

            local keyW = 28
            local keyH = 28
            local keyX = cardX + 12
            local keyY = cardY + (cardH - keyH) / 2
            drawSafeRoundedRect(keyX, keyY, keyW, keyH, 6, tocolor(255, 255, 255, 230))
            dxDrawText("E", keyX, keyY, keyX + keyW, keyY + keyH, tocolor(15, 23, 42, 255), 1.0, getSafeFont("bold", 12), "center", "center")

            local fontTitle = getSafeFont("bold", 10)
            local fontSub = getSafeFont("regular", 9)
            local textLeft = keyX + keyW + 10
            dxDrawText("KAVUNCU NECO", textLeft, keyY, cardX + cardW - 10, keyY + 14, tocolor(255, 255, 255, 255), 1.0, fontTitle, "left", "center")
            dxDrawText("Taksi Plakası Al", textLeft, keyY + 14, cardX + cardW - 10, keyY + 28, tocolor(250, 204, 21, 230), 1.0, fontSub, "left", "center")
        end
    end
end)

bindKey("e", "down", function()
    if isCursorShowing() then return end
    if (exports.gzl_core and exports.gzl_core.isPlayerTyping and exports.gzl_core:isPlayerTyping()) or guiGetInputEnabled() or isChatBoxInputActive() or isConsoleActive() then return end
    if isCinematicActive then
        return
    end

    local px, py, pz = getElementPosition(localPlayer)
    local nx, ny, nz = getLiveNecoPosition()
    local dist = getDistanceBetweenPoints3D(px, py, pz, nx, ny, nz)

    if dist <= 3.5 then
        triggerServerEvent("taxi:requestNecoCinematic", resourceRoot)
    end
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    if isCinematicActive then
        closeCinematic()
    end
end)