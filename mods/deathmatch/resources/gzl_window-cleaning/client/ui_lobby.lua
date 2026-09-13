LobbyUI = {}

local isLobbyOpen = false
local currentTab = "contracts"
local selectedBuildingIndex = 1
local nearbyPlayersList = {}
local activeLobbyData = nil

local panelW = 860
local panelH = 540
local panelX = 0
local panelY = 0

function LobbyUI.open(lobbyData, nearbyPlayers)
    if isLobbyOpen then return end
    local sw, sh = guiGetScreenSize()
    panelW = math.min(900, sw * 0.70)
    panelH = math.min(560, sh * 0.75)
    panelX = (sw - panelW) / 2
    panelY = (sh - panelH) / 2

    activeLobbyData = lobbyData
    nearbyPlayersList = nearbyPlayers or {}
    selectedBuildingIndex = 1
    currentTab = "contracts"
    isLobbyOpen = true
    showCursor(true)
end

function LobbyUI.close()
    if not isLobbyOpen then return end
    isLobbyOpen = false
    showCursor(false)
end

function LobbyUI.isOpen()
    return isLobbyOpen
end

function LobbyUI.updateData(lobbyData, nearbyPlayers)
    activeLobbyData = lobbyData
    if nearbyPlayers then
        nearbyPlayersList = nearbyPlayers
    end
end

local function isLeader()
    if not activeLobbyData or not activeLobbyData.isGroup then return true end
    return activeLobbyData.leader == localPlayer
end

local function drawHeader()
    local title = "CAM TEMİZLEME ŞİRKETİ MERKEZİ"
    dxDrawText(title, panelX + 24, panelY + 16, panelX + 400, panelY + 54, tocolor(255, 255, 255, 240), 1.25, "default-bold", "left", "center")

    local closeHover = isCursorWithin(panelX + panelW - 50, panelY + 16, 34, 34)
    local closeCol = closeHover and tocolor(239, 68, 68, 240) or tocolor(71, 85, 105, 180)
    drawRoundedRectangle(panelX + panelW - 50, panelY + 16, 34, 34, 8, closeCol)
    dxDrawText("✕", panelX + panelW - 50, panelY + 16, panelX + panelW - 16, panelY + 50, tocolor(255, 255, 255, 255), 1.1, "default-bold", "center", "center")
end

local function drawTabs()
    local tabY = panelY + 62
    local tabW = (panelW - 48) / 2

    local contractHover = isCursorWithin(panelX + 24, tabY, tabW - 4, 38)
    local contractActive = (currentTab == "contracts")
    local contractBg = contractActive and tocolor(14, 165, 233, 230) or (contractHover and tocolor(30, 41, 59, 220) or tocolor(15, 23, 42, 180))
    drawRoundedRectangle(panelX + 24, tabY, tabW - 4, 38, 8, contractBg)
    dxDrawText("🏢 Görevler & Binalar", panelX + 24, tabY, panelX + 24 + tabW - 4, tabY + 38, tocolor(255, 255, 255, 255), 1.0, "default-bold", "center", "center")

    local groupHover = isCursorWithin(panelX + 24 + tabW + 4, tabY, tabW - 4, 38)
    local groupActive = (currentTab == "group")
    local groupBg = groupActive and tocolor(14, 165, 233, 230) or (groupHover and tocolor(30, 41, 59, 220) or tocolor(15, 23, 42, 180))
    drawRoundedRectangle(panelX + 24 + tabW + 4, tabY, tabW - 4, 38, 8, groupBg)

    local groupTitle = "👥 Takım & Lobi"
    if activeLobbyData and activeLobbyData.isGroup then
        groupTitle = string.format("👥 Takım (%d/%d)", #activeLobbyData.members, Config.MaxGroupMembers)
    end
    dxDrawText(groupTitle, panelX + 24 + tabW + 4, tabY, panelX + 24 + tabW * 2, tabY + 38, tocolor(255, 255, 255, 255), 1.0, "default-bold", "center", "center")
end

local function drawContractsTab()
    local contentY = panelY + 115
    local listW = (panelW - 60) * 0.46
    local detailsW = (panelW - 60) * 0.54
    local contentH = panelH - 195

    for i, building in ipairs(Config.Buildings) do
        local cardY = contentY + (i - 1) * 82
        local isSelected = (selectedBuildingIndex == i)
        local isHover = isCursorWithin(panelX + 24, cardY, listW, 74)
        local cardBg = isSelected and tocolor(30, 58, 138, 220) or (isHover and tocolor(30, 41, 59, 200) or tocolor(15, 23, 42, 160))

        drawRoundedRectangle(panelX + 24, cardY, listW, 74, 10, cardBg)
        if isSelected then
            drawRoundedRectangle(panelX + 24, cardY, 4, 74, 2, tocolor(56, 189, 248, 255))
        end

        dxDrawText(building.name, panelX + 36, cardY + 10, panelX + 20 + listW, cardY + 32, tocolor(255, 255, 255, 255), 1.05, "default-bold", "left", "center")

        local diffColor = (building.difficulty == "Kolay") and tocolor(34, 197, 94, 255) or ((building.difficulty == "Orta") and tocolor(234, 179, 8, 255) or tocolor(239, 68, 68, 255))
        dxDrawText("Zorluk: " .. building.difficulty, panelX + 36, cardY + 36, panelX + 180, cardY + 56, diffColor, 0.9, "default-bold", "left", "center")

        local winCountStr = string.format("🪟 %d Cam", #building.windows)
        dxDrawText(winCountStr, panelX + listW - 80, cardY + 36, panelX + 20 + listW, cardY + 56, tocolor(148, 163, 184, 255), 0.9, "default-bold", "right", "center")
    end

    local detailX = panelX + 36 + listW
    drawRoundedRectangle(detailX, contentY, detailsW, contentH, 12, tocolor(15, 23, 42, 180))

    local b = Config.Buildings[selectedBuildingIndex]
    if b then
        dxDrawText(b.name, detailX + 20, contentY + 16, detailX + detailsW - 20, contentY + 44, tocolor(56, 189, 248, 255), 1.2, "default-bold", "left", "center")
        dxDrawText(b.description, detailX + 20, contentY + 48, detailX + detailsW - 20, contentY + 110, tocolor(203, 213, 225, 220), 0.95, "default", "left", "top", true)

        local statY = contentY + 120
        drawRoundedRectangle(detailX + 20, statY, detailsW - 40, 36, 6, tocolor(30, 41, 59, 180))
        dxDrawText("Toplam Cam Sayısı:", detailX + 32, statY, detailX + 200, statY + 36, tocolor(148, 163, 184, 255), 0.95, "default", "left", "center")
        dxDrawText(tostring(#b.windows) .. " Adet", detailX + detailsW - 120, statY, detailX + detailsW - 52, statY + 36, tocolor(255, 255, 255, 255), 1.0, "default-bold", "right", "center")

        local statY2 = statY + 44
        drawRoundedRectangle(detailX + 20, statY2, detailsW - 40, 36, 6, tocolor(30, 41, 59, 180))
        dxDrawText("Tahmini Ödül:", detailX + 32, statY2, detailX + 200, statY2 + 36, tocolor(148, 163, 184, 255), 0.95, "default", "left", "center")
        local totalReward = (#b.windows * Config.Economy.basePayPerWindow) + Config.Economy.completionBonus
        dxDrawText("$" .. tostring(totalReward), detailX + detailsW - 120, statY2, detailX + detailsW - 52, statY2 + 36, tocolor(34, 197, 94, 255), 1.05, "default-bold", "right", "center")

        local statY3 = statY2 + 44
        drawRoundedRectangle(detailX + 20, statY3, detailsW - 40, 36, 6, tocolor(30, 41, 59, 180))
        dxDrawText("Vinç / Platform:", detailX + 32, statY3, detailX + 200, statY3 + 36, tocolor(148, 163, 184, 255), 0.95, "default", "left", "center")
        local liftText = b.hasLift and "Mevcut (Gökdelen İskelesi)" or "Gerekmiyor (Zemin/Teras)"
        local liftColor = b.hasLift and tocolor(56, 189, 248, 255) or tocolor(148, 163, 184, 255)
        dxDrawText(liftText, detailX + detailsW - 240, statY3, detailX + detailsW - 52, statY3 + 36, liftColor, 0.9, "default-bold", "right", "center")
    end

    local actionBtnY = panelY + panelH - 64
    local actionBtnW = panelW - 48
    local actionBtnHover = isCursorWithin(panelX + 24, actionBtnY, actionBtnW, 46)

    local canStart = isLeader()
    local btnBg = canStart and (actionBtnHover and tocolor(16, 185, 129, 255) or tocolor(5, 150, 105, 240)) or tocolor(71, 85, 105, 180)
    drawRoundedRectangle(panelX + 24, actionBtnY, actionBtnW, 46, 10, btnBg)

    local btnText = canStart and "İŞE BAŞLA & ARACI ÇIKAR" or "Liderin İşi Başlatması Bekleniyor..."
    dxDrawText(btnText, panelX + 24, actionBtnY, panelX + 24 + actionBtnW, actionBtnY + 46, tocolor(255, 255, 255, 255), 1.1, "default-bold", "center", "center")
end

local function drawGroupTab()
    local contentY = panelY + 115
    local leftW = (panelW - 60) * 0.50
    local rightW = (panelW - 60) * 0.50
    local contentH = panelH - 195

    drawRoundedRectangle(panelX + 24, contentY, leftW, contentH, 12, tocolor(15, 23, 42, 180))
    dxDrawText("Takım Üyeleri", panelX + 40, contentY + 14, panelX + leftW, contentY + 38, tocolor(56, 189, 248, 255), 1.05, "default-bold", "left", "center")

    if activeLobbyData and activeLobbyData.isGroup then
        for i, member in ipairs(activeLobbyData.members) do
            local itemY = contentY + 44 + (i - 1) * 54
            drawRoundedRectangle(panelX + 36, itemY, leftW - 24, 46, 8, tocolor(30, 41, 59, 200))

            local pName = getPlayerName(member.element) or "Bilinmeyen"
            local isMLeader = (member.element == activeLobbyData.leader)
            local roleTag = isMLeader and "👑 Lider" or "Üye"

            dxDrawText(pName, panelX + 48, itemY + 8, panelX + 240, itemY + 38, tocolor(255, 255, 255, 255), 1.0, "default-bold", "left", "center")
            dxDrawText(roleTag, panelX + leftW - 90, itemY + 8, panelX + leftW + 20, itemY + 38, isMLeader and tocolor(234, 179, 8, 255) or tocolor(148, 163, 184, 255), 0.9, "default-bold", "right", "center")
        end
    else
        dxDrawText("Henüz bir takım oluşturmadınız.\nTek başınıza çalışabilir veya takım kurabilirsiniz.", panelX + 40, contentY + 60, panelX + leftW, contentY + 160, tocolor(148, 163, 184, 220), 0.95, "default", "left", "top")

        local createTeamHover = isCursorWithin(panelX + 40, contentY + 150, leftW - 32, 42)
        local createTeamBg = createTeamHover and tocolor(14, 165, 233, 255) or tocolor(2, 132, 199, 230)
        drawRoundedRectangle(panelX + 40, contentY + 150, leftW - 32, 42, 8, createTeamBg)
        dxDrawText("Takım Oluştur", panelX + 40, contentY + 150, panelX + leftW + 8, contentY + 192, tocolor(255, 255, 255, 255), 1.0, "default-bold", "center", "center")
    end

    local rightX = panelX + 36 + leftW
    drawRoundedRectangle(rightX, contentY, rightW, contentH, 12, tocolor(15, 23, 42, 180))
    dxDrawText("Yakındaki Oyuncular (Davet Et)", rightX + 16, contentY + 14, rightX + rightW, contentY + 38, tocolor(56, 189, 248, 255), 1.05, "default-bold", "left", "center")

    if #nearbyPlayersList == 0 then
        dxDrawText("Yakınınızda davet edilecek oyuncu yok.", rightX + 16, contentY + 54, rightX + rightW - 16, contentY + 120, tocolor(148, 163, 184, 200), 0.95, "default", "left", "top")
    else
        for i, ply in ipairs(nearbyPlayersList) do
            if i <= 5 then
                local pItemY = contentY + 44 + (i - 1) * 54
                drawRoundedRectangle(rightX + 12, pItemY, rightW - 24, 46, 8, tocolor(30, 41, 59, 200))

                local pName = getPlayerName(ply)
                dxDrawText(pName, rightX + 24, pItemY + 8, rightX + 180, pItemY + 38, tocolor(255, 255, 255, 255), 0.95, "default-bold", "left", "center")

                if activeLobbyData and activeLobbyData.isGroup and isLeader() then
                    local invHover = isCursorWithin(rightX + rightW - 100, pItemY + 8, 80, 30)
                    local invBg = invHover and tocolor(34, 197, 94, 255) or tocolor(22, 163, 74, 230)
                    drawRoundedRectangle(rightX + rightW - 100, pItemY + 8, 80, 30, 6, invBg)
                    dxDrawText("Davet Et", rightX + rightW - 100, pItemY + 8, rightX + rightW - 20, pItemY + 38, tocolor(255, 255, 255, 255), 0.85, "default-bold", "center", "center")
                end
            end
        end
    end

    local actionBtnY = panelY + panelH - 64
    local actionBtnW = panelW - 48
    if activeLobbyData and activeLobbyData.isGroup then
        local leaveHover = isCursorWithin(panelX + 24, actionBtnY, actionBtnW, 46)
        local leaveBg = leaveHover and tocolor(239, 68, 68, 255) or tocolor(220, 38, 38, 230)
        drawRoundedRectangle(panelX + 24, actionBtnY, actionBtnW, 46, 10, leaveBg)
        local leaveText = isLeader() and "TAKIMI DAĞIT" or "TAKIMDAN AYRIL"
        dxDrawText(leaveText, panelX + 24, actionBtnY, panelX + 24 + actionBtnW, actionBtnY + 46, tocolor(255, 255, 255, 255), 1.1, "default-bold", "center", "center")
    end
end

function LobbyUI.render()
    if not isLobbyOpen then return end

    drawGlassPanel(panelX, panelY, panelW, panelH, 16, 0.96)
    drawHeader()
    drawTabs()

    if currentTab == "contracts" then
        drawContractsTab()
    elseif currentTab == "group" then
        drawGroupTab()
    end
end

addEventHandler("onClientClick", root, function(button, state, absX, absY)
    if not isLobbyOpen or button ~= "left" or state ~= "down" then return end

    if isCursorWithin(panelX + panelW - 50, panelY + 16, 34, 34) then
        Audio.playButtonClick()
        LobbyUI.close()
        return
    end

    local tabY = panelY + 62
    local tabW = (panelW - 48) / 2
    if isCursorWithin(panelX + 24, tabY, tabW - 4, 38) then
        Audio.playButtonClick()
        currentTab = "contracts"
        return
    elseif isCursorWithin(panelX + 24 + tabW + 4, tabY, tabW - 4, 38) then
        Audio.playButtonClick()
        currentTab = "group"
        return
    end

    if currentTab == "contracts" then
        local contentY = panelY + 115
        local listW = (panelW - 60) * 0.46
        for i = 1, #Config.Buildings do
            local cardY = contentY + (i - 1) * 82
            if isCursorWithin(panelX + 24, cardY, listW, 74) then
                Audio.playButtonClick()
                selectedBuildingIndex = i
                return
            end
        end

        local actionBtnY = panelY + panelH - 64
        local actionBtnW = panelW - 48
        if isCursorWithin(panelX + 24, actionBtnY, actionBtnW, 46) then
            if isLeader() then
                Audio.playButtonClick()
                LobbyUI.close()
                local b = Config.Buildings[selectedBuildingIndex]
                triggerServerEvent("windowCleaning:startJob", localPlayer, b.id)
            end
            return
        end
    elseif currentTab == "group" then
        local contentY = panelY + 115
        local leftW = (panelW - 60) * 0.50
        local rightW = (panelW - 60) * 0.50

        if (not activeLobbyData or not activeLobbyData.isGroup) and isCursorWithin(panelX + 40, contentY + 150, leftW - 32, 42) then
            Audio.playButtonClick()
            triggerServerEvent("windowCleaning:createTeam", localPlayer)
            return
        end

        if activeLobbyData and activeLobbyData.isGroup and isLeader() then
            local rightX = panelX + 36 + leftW
            for i, ply in ipairs(nearbyPlayersList) do
                if i <= 5 and isElement(ply) then
                    local pItemY = contentY + 44 + (i - 1) * 54
                    if isCursorWithin(rightX + rightW - 100, pItemY + 8, 80, 30) then
                        Audio.playButtonClick()
                        triggerServerEvent("windowCleaning:invitePlayer", localPlayer, ply)
                        return
                    end
                end
            end
        end

        local actionBtnY = panelY + panelH - 64
        local actionBtnW = panelW - 48
        if activeLobbyData and activeLobbyData.isGroup and isCursorWithin(panelX + 24, actionBtnY, actionBtnW, 46) then
            Audio.playButtonClick()
            triggerServerEvent("windowCleaning:leaveTeam", localPlayer)
            return
        end
    end
end)