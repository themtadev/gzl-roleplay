CleaningGame = {}

local isCleaningActive = false
local currentWindowData = nil
local gridRows = 12
local gridCols = 18
local dirtGrid = {}
local totalDirtCells = gridRows * gridCols
local cleanedDirtCells = 0
local cleanPercentage = 0.0

local canvasW = 720
local canvasH = 480
local canvasX = 0
local canvasY = 0

local isMouseDown = false
local lastMouseX = 0
local lastMouseY = 0
local wipeRadius = 38

local toolAnimOffset = 0
local cleanSucceeded = false
local finishTick = 0

local function initDirtGrid()
    dirtGrid = {}
    cleanedDirtCells = 0
    cleanPercentage = 0.0
    for r = 1, gridRows do
        dirtGrid[r] = {}
        for c = 1, gridCols do
            dirtGrid[r][c] = {
                opacity = 0.85 + (math.random(0, 15) / 100),
                cleaned = false
            }
        end
    end
end

function CleaningGame.start(windowData)
    if isCleaningActive then return end
    local sw, sh = guiGetScreenSize()
    canvasW = math.min(760, sw * 0.55)
    canvasH = math.min(500, sh * 0.60)
    canvasX = (sw - canvasW) / 2
    canvasY = (sh - canvasH) / 2

    currentWindowData = windowData
    isCleaningActive = true
    cleanSucceeded = false
    finishTick = 0
    showCursor(true)

    initDirtGrid()

    triggerServerEvent("windowCleaning:startAnimation", localPlayer, windowData.id)
end

function CleaningGame.stop(success)
    if not isCleaningActive then return end
    isCleaningActive = false
    showCursor(false)
    triggerServerEvent("windowCleaning:stopAnimation", localPlayer)

    if success and currentWindowData then
        Audio.playSuccess()
        triggerServerEvent("windowCleaning:submitCleanWindow", localPlayer, currentWindowData.id)
    end
    currentWindowData = nil
end

function CleaningGame.isActive()
    return isCleaningActive
end

local function wipeAt(px, py)
    if px < canvasX or px > canvasX + canvasW or py < canvasY or py > canvasY + canvasH then
        return
    end

    local relX = px - canvasX
    local relY = py - canvasY
    local cellW = canvasW / gridCols
    local cellH = canvasH / gridRows

    local hitAny = false

    for r = 1, gridRows do
        local cy = (r - 0.5) * cellH
        for c = 1, gridCols do
            local cx = (c - 0.5) * cellW
            local dist = math.sqrt((relX - cx)^2 + (relY - cy)^2)
            if dist <= wipeRadius then
                local cell = dirtGrid[r][c]
                if cell and not cell.cleaned then
                    cell.opacity = cell.opacity - 0.50
                    if cell.opacity <= 0.05 then
                        cell.opacity = 0
                        cell.cleaned = true
                        cleanedDirtCells = cleanedDirtCells + 1
                        hitAny = true
                    end
                end
            end
        end
    end

    if hitAny then
        Audio.playWipeEffect()
    end

    cleanPercentage = cleanedDirtCells / totalDirtCells
    if cleanPercentage >= Config.CleanRequirement and not cleanSucceeded then
        cleanSucceeded = true
        finishTick = getTickCount()
    end
end

addEventHandler("onClientClick", root, function(button, state, absX, absY)
    if not isCleaningActive then return end
    if button == "left" then
        if state == "down" then
            local cancelBtnX = canvasX + canvasW - 110
            local cancelBtnY = canvasY - 45
            if isCursorWithin(cancelBtnX, cancelBtnY, 110, 36) then
                Audio.playButtonClick()
                CleaningGame.stop(false)
                return
            end
            isMouseDown = true
            lastMouseX = absX
            lastMouseY = absY
            wipeAt(absX, absY)
        elseif state == "up" then
            isMouseDown = false
        end
    end
end)

addEventHandler("onClientCursorMove", root, function(relX, relY, absX, absY)
    if not isCleaningActive then return end
    lastMouseX = absX
    lastMouseY = absY
    if isMouseDown then
        wipeAt(absX, absY)
    end
end)

addEventHandler("onClientKey", root, function(button, press)
    if not isCleaningActive or not press then return end
    if button == "escape" or button == "backspace" then
        cancelEvent()
        CleaningGame.stop(false)
    end
end)

function CleaningGame.render()
    if not isCleaningActive then return end

    local sw, sh = guiGetScreenSize()

    drawGlassPanel(canvasX - 16, canvasY - 60, canvasW + 32, canvasH + 110, 16, 0.95)

    local headerText = "CAM TEMİZLEME İŞLEMİ"
    dxDrawText(headerText, canvasX, canvasY - 48, canvasX + 300, canvasY - 16, tocolor(255, 255, 255, 240), 1.2, "default-bold", "left", "center")

    local cancelHover = isCursorWithin(canvasX + canvasW - 110, canvasY - 48, 110, 32)
    local cancelColor = cancelHover and tocolor(239, 68, 68, 240) or tocolor(71, 85, 105, 200)
    drawRoundedRectangle(canvasX + canvasW - 110, canvasY - 48, 110, 32, 6, cancelColor)
    dxDrawText("İptal (ESC)", canvasX + canvasW - 110, canvasY - 48, canvasX + canvasW, canvasY - 16, tocolor(255, 255, 255, 255), 1.0, "default-bold", "center", "center")

    drawRoundedRectangle(canvasX, canvasY, canvasW, canvasH, 8, tocolor(15, 23, 42, 230))
    drawRoundedRectangle(canvasX + 2, canvasY + 2, canvasW - 4, canvasH - 4, 6, tocolor(203, 213, 225, 45))

    local cellW = canvasW / gridCols
    local cellH = canvasH / gridRows

    for r = 1, gridRows do
        local cy = canvasY + (r - 1) * cellH
        for c = 1, gridCols do
            local cx = canvasX + (c - 1) * cellW
            local cell = dirtGrid[r][c]
            if cell and cell.opacity > 0.01 then
                local alpha = math.floor(cell.opacity * 220)
                local dirtColor = tocolor(84, 58, 38, alpha)
                drawRoundedRectangle(cx + 1, cy + 1, cellW - 2, cellH - 2, 4, dirtColor)
            end
        end
    end

    local progBarY = canvasY + canvasH + 16
    local progBarW = canvasW - 160
    local progBarH = 24
    drawProgressBar(canvasX, progBarY, progBarW, progBarH, 6, cleanPercentage, tocolor(14, 165, 233, 255), tocolor(30, 41, 59, 230))

    local percentLabel = string.format("%%%d Temizlendi", math.floor(cleanPercentage * 100))
    dxDrawText(percentLabel, canvasX, progBarY, canvasX + progBarW, progBarY + progBarH, tocolor(255, 255, 255, 255), 1.0, "default-bold", "center", "center")

    local targetLabel = string.format("Hedef: %%%d", math.floor(Config.CleanRequirement * 100))
    dxDrawText(targetLabel, canvasX + progBarW + 16, progBarY, canvasX + canvasW, progBarY + progBarH, tocolor(148, 163, 184, 255), 1.0, "default-bold", "right", "center")

    if isCursorShowing() and lastMouseX >= canvasX and lastMouseX <= canvasX + canvasW and lastMouseY >= canvasY and lastMouseY <= canvasY + canvasH then
        local squeegeeW = 44
        local squeegeeH = 28
        local sqColor = isMouseDown and tocolor(56, 189, 248, 255) or tocolor(226, 232, 240, 220)
        drawRoundedRectangle(lastMouseX - squeegeeW/2, lastMouseY - squeegeeH/2, squeegeeW, 8, 4, sqColor)
        drawRoundedRectangle(lastMouseX - 4, lastMouseY - squeegeeH/2 + 8, 8, 20, 3, tocolor(100, 116, 139, 240))
        drawCircle(lastMouseX, lastMouseY, wipeRadius, tocolor(56, 189, 248, 30))
    end

    if cleanSucceeded then
        local bannerW = 340
        local bannerH = 70
        local bx = canvasX + (canvasW - bannerW) / 2
        local by = canvasY + (canvasH - bannerH) / 2
        drawGlassPanel(bx, by, bannerW, bannerH, 12, 0.98)
        drawRoundedRectangle(bx + 4, by + 4, bannerW - 8, bannerH - 8, 8, tocolor(16, 185, 129, 220))
        dxDrawText("CAM PARILDIR! TEMİZLENDİ", bx, by, bx + bannerW, by + bannerH, tocolor(255, 255, 255, 255), 1.2, "default-bold", "center", "center")

        if getTickCount() - finishTick > 800 then
            CleaningGame.stop(true)
        end
    end
end