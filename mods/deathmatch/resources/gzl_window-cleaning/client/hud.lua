JobHUD = {}

local activeJobData = nil
local nearbyPromptWindow = nil

function JobHUD.setJobData(data)
    activeJobData = data
end

function JobHUD.clearJobData()
    activeJobData = nil
    nearbyPromptWindow = nil
end

function JobHUD.getJobData()
    return activeJobData
end

function JobHUD.getNearbyWindow()
    return nearbyPromptWindow
end

local function drawActiveJobCard()
    if not activeJobData then return end

    local sw, sh = guiGetScreenSize()
    local cardW = 320
    local cardH = 125
    local cardX = sw - cardW - 24
    local cardY = 24

    drawGlassPanel(cardX, cardY, cardW, cardH, 12, 0.94)

    local buildingName = activeJobData.buildingName or "Bilinmeyen Bina"
    dxDrawText(buildingName, cardX + 16, cardY + 12, cardX + cardW - 16, cardY + 34, tocolor(56, 189, 248, 255), 1.05, "default-bold", "left", "center")

    local totalWins = activeJobData.totalWindows or 1
    local cleanedWins = activeJobData.cleanedWindows or 0
    local progRatio = math.max(0, math.min(1, cleanedWins / totalWins))

    local progText = string.format("İlerleme: %d / %d Cam", cleanedWins, totalWins)
    dxDrawText(progText, cardX + 16, cardY + 38, cardX + cardW - 16, cardY + 56, tocolor(226, 232, 240, 240), 0.9, "default-bold", "left", "center")

    local progBarW = cardW - 32
    drawProgressBar(cardX + 16, cardY + 60, progBarW, 14, 4, progRatio, tocolor(14, 165, 233, 255), tocolor(30, 41, 59, 220))

    local statusText = (cleanedWins >= totalWins) and "✓ Tüm camlar temizlendi! Aracı depoya teslim edin." or "Kirli pencerelere yaklaşın ve [E] ile temizleyin."
    local statusCol = (cleanedWins >= totalWins) and tocolor(34, 197, 94, 255) or tocolor(148, 163, 184, 255)
    dxDrawText(statusText, cardX + 16, cardY + 82, cardX + cardW - 16, cardY + 115, statusCol, 0.85, "default", "left", "center", true)
end

local function draw3DWindowMarkers()
    if not activeJobData or not activeJobData.windows then return end

    local px, py, pz = getElementPosition(localPlayer)
    nearbyPromptWindow = nil
    local minDistance = 2.8

    for _, win in ipairs(activeJobData.windows) do
        local dist = getDistanceBetweenPoints3D(px, py, pz, win.x, win.y, win.z)
        if dist < 35.0 then
            local sx, sy = getScreenFromWorldPosition(win.x, win.y, win.z + 0.3)
            if sx and sy then
                local isCleaned = win.isCleaned
                local badgeW = 120
                local badgeH = 32
                local badgeX = sx - badgeW / 2
                local badgeY = sy - badgeH / 2

                if isCleaned then
                    drawGlassPanel(badgeX, badgeY, badgeW, badgeH, 6, 0.85)
                    drawRoundedRectangle(badgeX + 2, badgeY + 2, badgeW - 4, badgeH - 4, 4, tocolor(16, 185, 129, 180))
                    dxDrawText("✓ Temizlendi", badgeX, badgeY, badgeX + badgeW, badgeY + badgeH, tocolor(255, 255, 255, 255), 0.9, "default-bold", "center", "center")
                else
                    if dist < minDistance and not CleaningGame.isActive() then
                        nearbyPromptWindow = win
                        local promptW = 160
                        local promptH = 44
                        local pX = sx - promptW / 2
                        local pY = sy - promptH / 2
                        drawGlassPanel(pX, pY, promptW, promptH, 8, 0.95)
                        drawRoundedRectangle(pX + 2, pY + 2, promptW - 4, promptH - 4, 6, tocolor(14, 165, 233, 200))
                        dxDrawText("🪟 Cam #" .. tostring(win.id) .. "\n[ E ] Camı Temizle", pX, pY, pX + promptW, pY + promptH, tocolor(255, 255, 255, 255), 0.9, "default-bold", "center", "center")
                    else
                        drawGlassPanel(badgeX, badgeY, badgeW, badgeH, 6, 0.85)
                        drawRoundedRectangle(badgeX + 2, badgeY + 2, badgeW - 4, badgeH - 4, 4, tocolor(239, 68, 68, 160))
                        dxDrawText("🪟 Kirli Cam #" .. tostring(win.id), badgeX, badgeY, badgeX + badgeW, badgeY + badgeH, tocolor(255, 255, 255, 255), 0.85, "default-bold", "center", "center")
                    end
                end
            end
        end
    end
end

local function drawDepotPrompt()
    if activeJobData then return end
    local px, py, pz = getElementPosition(localPlayer)
    local dPos = Config.DepotLocation.marker
    local dist = getDistanceBetweenPoints3D(px, py, pz, dPos.x, dPos.y, dPos.z)
    if dist < 3.0 and not LobbyUI.isOpen() then
        local sx, sy = getScreenFromWorldPosition(dPos.x, dPos.y, dPos.z + 1.2)
        if sx and sy then
            local pW = 200
            local pH = 44
            local pX = sx - pW / 2
            local pY = sy - pH / 2
            drawGlassPanel(pX, pY, pW, pH, 8, 0.95)
            dxDrawText("CAM TEMİZLEME MERKEZİ\n[ E ] Menüyü Aç", pX, pY, pX + pW, pY + pH, tocolor(56, 189, 248, 255), 0.9, "default-bold", "center", "center")
        end
    end
end

function JobHUD.render()
    drawDepotPrompt()
    draw3DWindowMarkers()
    drawActiveJobCard()
end