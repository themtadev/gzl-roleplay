
local activeOfficers = {}

addEventHandler("onResourceStart", resourceRoot, function()
    PDStorage.init()
end)

addEventHandler("onPlayerQuit", root, function()
    activeOfficers[source] = nil
end)

local function getOfficerName(player)
    return getElementData(player, "character:name") or getElementData(player, "char:name") or getPlayerName(player)
end

addCommandHandler("pd", function(player, cmd)
    if not isElement(player) then return end

    if not PDConfig.canAccess(player) then
        outputChatBox("[LSPD] Bu terminale erişim yetkiniz bulunmuyor!", player, 255, 69, 58)
        return
    end

    local offName = getOfficerName(player)
    local offRank = "Memur"
    if exports.gzl_factions and exports.gzl_factions.getPlayerFactionData then
        local s, fData = pcall(function() return exports.gzl_factions:getPlayerFactionData(player) end)
        if s and fData and fData.rank_name then
            offRank = fData.rank_name
        end
    end

    if not activeOfficers[player] then
        activeOfficers[player] = {
            name = offName,
            status = "10-8",
            rank = offRank
        }
    else
        activeOfficers[player].name = offName
        activeOfficers[player].rank = offRank
    end

    triggerClientEvent(player, "pd:openTablet", resourceRoot, activeOfficers[player])
end)

addEvent("pd:requestDashboardData", true)
addEventHandler("pd:requestDashboardData", root, function()
    if not client or not PDConfig.canAccess(client) then return end
    local callingPlayer = client

    PDStorage.getBulletins(function(bulletins)
        PDStorage.getAllWantedCitizens(function(wantedList)
            PDStorage.getAllWantedVehicles(function(wantedVehicles)
                if isElement(callingPlayer) then
                    local officersList = {}
                    for p, data in pairs(activeOfficers) do
                        if isElement(p) then
                            table.insert(officersList, {
                                name = data.name,
                                status = data.status,
                                rank = data.rank
                            })
                        end
                    end

                    triggerClientEvent(callingPlayer, "pd:receiveDashboardData", resourceRoot, {
                        officers = officersList,
                        bulletins = bulletins,
                        wantedCount = #wantedList,
                        boloCount = #wantedVehicles
                    })
                end
            end)
        end)
    end)
end)

addEvent("pd:setStatus", true)
addEventHandler("pd:setStatus", root, function(newStatusCode)
    if not client or not PDConfig.canAccess(client) then return end
    local callingPlayer = client

    if activeOfficers[callingPlayer] then
        activeOfficers[callingPlayer].status = tostring(newStatusCode)
        local offName = activeOfficers[callingPlayer].name

        for offPlayer, _ in pairs(activeOfficers) do
            if isElement(offPlayer) then
                triggerClientEvent(offPlayer, "pd:onOfficerStatusUpdate", resourceRoot, offName, newStatusCode)
            end
        end

        triggerClientEvent(callingPlayer, "pd:onActionAck", resourceRoot, "status", true, "Durumunuz güncellendi: " .. tostring(newStatusCode))
    end
end)

addEvent("pd:triggerPanicButton", true)
addEventHandler("pd:triggerPanicButton", root, function()
    if not client or not PDConfig.canAccess(client) then return end
    local callingPlayer = client
    local offName = getOfficerName(callingPlayer)
    local x, y, z = getElementPosition(callingPlayer)

    outputServerLog(string.format("[LSPD 10-99 EMERGENCY] Officer '%s' triggered panic button at %.1f, %.1f, %.1f", offName, x, y, z))

    for offPlayer, _ in pairs(activeOfficers) do
        if isElement(offPlayer) then
            triggerClientEvent(offPlayer, "pd:onPanicAlert", resourceRoot, offName, x, y, z)
            outputChatBox(string.format("[10-99 ACİL DURUM] Memur %s acil destek istiyor! (GPS haritada işaretlendi)", offName), offPlayer, 255, 50, 50)
        end
    end
end)

addEvent("pd:searchCitizen", true)
addEventHandler("pd:searchCitizen", root, function(queryName)
    if not client or not PDConfig.canAccess(client) then return end
    local callingPlayer = client
    if type(queryName) ~= "string" or string.len(queryName) < 2 then return end

    PDStorage.getRecords(queryName, function(records)
        PDStorage.getAllWantedCitizens(function(wantedList)
            if isElement(callingPlayer) then

                local warrant = nil
                for _, w in ipairs(wantedList) do
                    if string.lower(w.target_name) == string.lower(queryName) or string.find(string.lower(w.target_name), string.lower(queryName), 1, true) then
                        warrant = w
                        break
                    end
                end

                triggerClientEvent(callingPlayer, "pd:receiveCitizenData", resourceRoot, queryName, records, warrant)
            end
        end)
    end)
end)

addEvent("pd:issueFine", true)
addEventHandler("pd:issueFine", root, function(targetName, crimeTitle, fineAmount, jailTime)
    if not client or not PDConfig.canAccess(client) then return end
    local callingPlayer = client
    local officerName = getOfficerName(callingPlayer)

    if type(targetName) ~= "string" or type(crimeTitle) ~= "string" then return end
    targetName = string.sub(targetName:gsub("[%c]", ""), 1, 32)
    crimeTitle = string.sub(crimeTitle:gsub("[%c]", ""), 1, 64)
    if string.len(targetName) < 3 or string.len(crimeTitle) < 2 then return end

    fineAmount = math.floor(tonumber(fineAmount) or 0)
    jailTime = math.floor(tonumber(jailTime) or 0)

    if fineAmount < 0 or fineAmount > 50000 then return end
    if jailTime < 0 or jailTime > 120 then return end
    if fineAmount == 0 and jailTime == 0 then return end

    PDStorage.addRecord(targetName, officerName, crimeTitle, fineAmount, jailTime, function(success)
        if isElement(callingPlayer) then
            if success then
                triggerClientEvent(callingPlayer, "pd:onActionAck", resourceRoot, "issueFine", true, string.format("%s adına ceza kaydı oluşturuldu ($%d).", targetName, fineAmount))
                for _, p in ipairs(getElementsByType("player")) do
                    local pName = getElementData(p, "character:name") or getPlayerName(p)
                    if string.lower(pName) == string.lower(targetName) then
                        outputChatBox(string.format("[LSPD] Memur %s tarafından size ceza kesildi: '%s' ($%d)", officerName, crimeTitle, fineAmount), p, 255, 100, 100)
                        if fineAmount > 0 then
                            if exports.gzl_characters and exports.gzl_characters.takePlayerCash then
                                exports.gzl_characters:takePlayerCash(p, fineAmount)
                            else
                                takePlayerMoney(p, fineAmount)
                                local cur = tonumber(getElementData(p, "character:money") or getPlayerMoney(p)) or 0
                                local newCash = math.max(0, cur - fineAmount)
                                setElementData(p, "character:money", newCash, "broadcast", "deny")
                                setElementData(p, "char:money", newCash, "broadcast", "deny")
                                setPlayerMoney(p, newCash)
                                if exports.gzl_characters and exports.gzl_characters.saveCharacter then
                                    exports.gzl_characters:saveCharacter(p)
                                end
                            end
                            if exports.gzl_logs and exports.gzl_logs.logMoney then
                                pcall(function() exports.gzl_logs:logMoney(p, "LSPD", fineAmount, "pd_fine", crimeTitle) end)
                            end
                            if exports.gzl_factions and exports.gzl_factions.modifyFactionVault then
                                pcall(function() exports.gzl_factions:modifyFactionVault(1, fineAmount, "Ceza Geliri: " .. crimeTitle, callingPlayer) end)
                            end
                        end
                        break
                    end
                end
            else
                triggerClientEvent(callingPlayer, "pd:onActionAck", resourceRoot, "issueFine", false, "Ceza kaydı veritabanına eklenemedi!")
            end
        end
    end)
end)

addEvent("pd:setWantedStatus", true)
addEventHandler("pd:setWantedStatus", root, function(targetName, wantedLevel, reason)
    if not client or not PDConfig.canAccess(client) then return end
    local callingPlayer = client
    local officerName = getOfficerName(callingPlayer)

    if type(targetName) ~= "string" or string.len(targetName) < 3 then return end
    targetName = string.sub(targetName:gsub("[%c]", ""), 1, 32)
    wantedLevel = math.floor(tonumber(wantedLevel) or 0)
    if wantedLevel < 0 or wantedLevel > 6 then return end
    reason = type(reason) == "string" and string.sub(reason:gsub("[%c]", ""), 1, 64) or "Şüpheli"

    PDStorage.setWantedCitizen(targetName, wantedLevel, reason, officerName, function(success)
        if isElement(callingPlayer) then
            triggerClientEvent(callingPlayer, "pd:onActionAck", resourceRoot, "setWanted", true, string.format("%s için aranma durumu güncellendi (Seviye %d).", targetName, wantedLevel))
        end
    end)
end)

addEvent("pd:searchVehicle", true)
addEventHandler("pd:searchVehicle", root, function(plate)
    if not client or not PDConfig.canAccess(client) then return end
    local callingPlayer = client
    local cleanPlate = string.upper(tostring(plate)):gsub("%s+", "")

    PDStorage.getAllWantedVehicles(function(allBolo)
        if not isElement(callingPlayer) then return end

        local bolo = nil
        for _, b in ipairs(allBolo) do
            if b.plate == cleanPlate then
                bolo = b
                break
            end
        end

        triggerClientEvent(callingPlayer, "pd:receiveVehicleData", resourceRoot, cleanPlate, bolo, allBolo)
    end)
end)

addEvent("pd:setVehicleBolo", true)
addEventHandler("pd:setVehicleBolo", root, function(plate, modelName, reason, isRemove)
    if not client or not PDConfig.canAccess(client) then return end
    local callingPlayer = client
    local officerName = getOfficerName(callingPlayer)

    PDStorage.setWantedVehicle(plate, modelName, reason, officerName, isRemove == true, function(success)
        if isElement(callingPlayer) then
            local msg = isRemove and (plate .. " BOLO kaydı silindi.") or (plate .. " için BOLO (Aranma) kaydı açıldı.")
            triggerClientEvent(callingPlayer, "pd:onActionAck", resourceRoot, "setBolo", true, msg)
        end
    end)
end)

addEvent("pd:addBulletin", true)
addEventHandler("pd:addBulletin", root, function(title, description)
    if not client or not PDConfig.canAccess(client) then return end
    local callingPlayer = client
    local officerName = getOfficerName(callingPlayer)

    PDStorage.addBulletin(title, description, officerName, function(success)
        if isElement(callingPlayer) then
            triggerClientEvent(callingPlayer, "pd:onActionAck", resourceRoot, "addBulletin", true, "Yeni APB bülteni yayınlandı.")
        end
    end)
end)