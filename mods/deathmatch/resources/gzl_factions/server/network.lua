

local actionCooldowns = {}

local function checkCooldown(player, cooldownMs)
    cooldownMs = cooldownMs or 800
    local now = getTickCount()
    local last = actionCooldowns[player] or 0
    if (now - last) < cooldownMs then
        return false
    end
    actionCooldowns[player] = now
    return true
end

addEventHandler("onPlayerQuit", root, function()
    actionCooldowns[source] = nil
    if PendingFactionInvites then
        PendingFactionInvites[source] = nil
    end
end)

local function sanitizeText(text, maxLen)
    if not text then return "" end
    local str = tostring(text):gsub("[<>]", ""):gsub("[\r\n]", " ")
    str = str:match("^%s*(.-)%s*$") or ""
    if maxLen and #str > maxLen then
        str = string.sub(str, 1, maxLen)
    end
    return str
end

local function findTargetPlayer(query)
    if not query then return nil end
    if isElement(query) and getElementType(query) == "player" then
        return query
    end

    local num = tonumber(query)
    if num then
        for _, p in ipairs(getElementsByType("player")) do
            local pid = tonumber(getElementData(p, "playerid") or getElementData(p, "id"))
            if pid == num then return p end
        end
        for _, p in ipairs(getElementsByType("player")) do
            local cid = tonumber(getElementData(p, "character:id") or getElementData(p, "char:id"))
            if cid == num then return p end
        end
    end

    local qLower = string.lower(tostring(query)):gsub("#%x%x%x%x%x%x", "")
    for _, p in ipairs(getElementsByType("player")) do
        local pName = string.lower(getPlayerName(p)):gsub("#%x%x%x%x%x%x", "")
        local cName = string.lower(tostring(getElementData(p, "character:name") or getElementData(p, "char:name") or "")):gsub("_", " ")
        if string.find(pName, qLower, 1, true) or (cName ~= "" and string.find(cName, qLower, 1, true)) then
            return p
        end
    end
    return nil
end

addEvent("faction:requestPanelData", true)
addEventHandler("faction:requestPanelData", root, function()
    local player = client or source
    if not isElement(player) or getElementType(player) ~= "player" then return end
    if client and client ~= player then return end

    local isLogged = getElementData(player, "loggedin_character") or getElementData(player, "character:id") or getElementData(player, "char:id")
    if not isLogged then return end

    local pData = PlayerFactions[player]
    if not pData then
        if loadPlayerFaction then loadPlayerFaction(player) end
        pData = PlayerFactions[player]
    end

    if not pData then
        triggerClientEvent(player, "faction:receivePanelData", resourceRoot, nil, "Herhangi bir birliğe üye değilsiniz!")
        return
    end

    local fId = pData.faction_id
    local fData = Factions[fId]
    if not fData then
        triggerClientEvent(player, "faction:receivePanelData", resourceRoot, nil, "Birlik verileri bulunamadı!")
        return
    end

    local clientCharId = pData.character_id
    local clientRank = pData.rank_id
    local canManage = FactionConfig.canManageMembers(fId, clientRank)
    local canInvite = FactionConfig.canInviteMembers(fId, clientRank)
    local canWithdraw = FactionConfig.canWithdrawVault(fId, clientRank)
    local maxRank = FactionConfig.getMaxRank(fId)

    local db = getFactionDB()
    if not db then return end

    dbQuery(function(qh)
        local rows = dbPoll(qh, 0) or {}
        if not isElement(player) then return end

        local memberList = {}
        local onlineCount = 0

        for _, row in ipairs(rows) do
            local cId = tonumber(row.character_id)
            local rId = tonumber(row.rank_id) or 1
            local rankInfo = fData.ranks and fData.ranks[rId]
            local rankTitle = rankInfo and rankInfo.name or ("Derece " .. tostring(rId))

            local onlinePlayer = nil
            for p, actData in pairs(PlayerFactions) do
                if isElement(p) and actData.character_id == cId then
                    onlinePlayer = p
                    break
                end
            end

            local isOnline = (onlinePlayer ~= nil)
            if isOnline then onlineCount = onlineCount + 1 end

            if isOnline and PlayerFactions[onlinePlayer] then
                rId = tonumber(PlayerFactions[onlinePlayer].rank_id) or rId
                rankInfo = fData.ranks and fData.ranks[rId]
                rankTitle = rankInfo and rankInfo.name or ("Derece " .. tostring(rId))
            end

            local activeDuty = isOnline and (PlayerFactions[onlinePlayer].duty_status == 1) or (tonumber(row.duty_status) == 1)
            local charName = row.character_name
            if (not charName or charName == "") and isOnline then
                charName = getElementData(onlinePlayer, "character:name") or getPlayerName(onlinePlayer):gsub("#%x%x%x%x%x%x", "")
            end
            if not charName or charName == "" then
                charName = "Karakter #" .. tostring(cId)
            end

            table.insert(memberList, {
                character_id = cId,
                character_name = charName,
                rank_id = rId,
                rank_name = rankTitle,
                is_online = isOnline,
                duty_status = activeDuty,
                ping = isOnline and getPlayerPing(onlinePlayer) or nil,
                server_id = isOnline and (getElementData(onlinePlayer, "playerid") or getElementData(onlinePlayer, "id")) or nil
            })
        end

        dbQuery(function(lQh)
            local logRows = dbPoll(lQh, 0) or {}
            if not isElement(player) then return end

            local vaultLogs = {}
            for _, l in ipairs(logRows) do
                table.insert(vaultLogs, {
                    id = tonumber(l.id),
                    character_name = l.character_name or "Bilinmeyen",
                    action_type = l.action_type or "unknown",
                    amount = tonumber(l.amount) or 0,
                    reason = l.reason or "",
                    created_at = l.created_at or ""
                })
            end

            local nearbyPlayers = {}
            local px, py, pz = getElementPosition(player)
            local pDim = getElementDimension(player)
            local pInt = getElementInterior(player)

            for _, p in ipairs(getElementsByType("player")) do
                if p ~= player and isElement(p) and (getElementData(p, "loggedin_character") or getElementData(p, "character:id")) and not PlayerFactions[p] and not getElementData(p, "character:faction") and not getElementData(p, "faction") then
                    if getElementDimension(p) == pDim and getElementInterior(p) == pInt then
                        local tx, ty, tz = getElementPosition(p)
                        if getDistanceBetweenPoints3D(px, py, pz, tx, ty, tz) <= 20 then
                            local cName = getElementData(p, "character:name") or getPlayerName(p):gsub("#%x%x%x%x%x%x", "")
                            local cId = tonumber(getElementData(p, "character:id") or getElementData(p, "char:id")) or 0
                            local sId = tonumber(getElementData(p, "playerid") or getElementData(p, "id")) or 0
                            table.insert(nearbyPlayers, {
                                element = p,
                                name = cName,
                                char_id = cId,
                                server_id = sId
                            })
                        end
                    end
                end
            end

            local pCash = 0
            if exports.gzl_characters and exports.gzl_characters.getPlayerCash then
                pCash = exports.gzl_characters:getPlayerCash(player)
            else
                pCash = tonumber(getElementData(player, "character:money") or getPlayerMoney(player)) or 0
            end

            local payload = {
                faction = {
                    id = fId,
                    name = fData.name,
                    short_name = fData.short_name,
                    type = fData.faction_type,
                    vault_balance = fData.vault_balance or 0,
                    max_members = fData.max_members or 50,
                    ranks = fData.ranks or {}
                },
                player = {
                    character_id = clientCharId,
                    character_name = getElementData(player, "character:name") or getPlayerName(player):gsub("#%x%x%x%x%x%x", ""),
                    rank_id = clientRank,
                    rank_name = (fData.ranks and fData.ranks[clientRank]) and fData.ranks[clientRank].name or ("Derece " .. clientRank),
                    duty = (pData.duty_status == 1),
                    cash = pCash,
                    canManage = canManage,
                    canInvite = canInvite,
                    canWithdraw = canWithdraw,
                    maxRank = maxRank
                },
                members = memberList,
                vaultLogs = vaultLogs,
                nearbyPlayers = nearbyPlayers,
                onlineCount = onlineCount,
                totalCount = #memberList
            }

            triggerClientEvent(player, "faction:receivePanelData", resourceRoot, payload)
        end, db, "SELECT * FROM faction_vault_logs WHERE faction_id = ? ORDER BY id DESC LIMIT 20", fId)
    end, db, "SELECT * FROM faction_members WHERE faction_id = ? ORDER BY rank_id DESC, character_name ASC", fId)
end)

addEvent("faction:toggleDuty", true)
addEventHandler("faction:toggleDuty", root, function()
    local player = client or source
    if not isElement(player) or getElementType(player) ~= "player" then return end
    if client and client ~= player then return end
    if not getElementData(player, "loggedin_character") then return end
    if not checkCooldown(player, 600) then return end

    local pData = PlayerFactions[player]
    if not pData then return end

    local fId = pData.faction_id
    local fData = Factions[fId]
    if not fData then return end

    local newDuty = (pData.duty_status == 1) and 0 or 1
    pData.duty_status = newDuty

    local db = getFactionDB()
    if db then
        dbExec(db, "UPDATE faction_members SET duty_status = ? WHERE character_id = ?", newDuty, pData.character_id)
    end

    syncPlayerFaction(player)

    local rankName = (fData.ranks and fData.ranks[pData.rank_id]) and fData.ranks[pData.rank_id].name or "Üye"
    local pName = getElementData(player, "character:name") or getPlayerName(player)

    if newDuty == 1 then
        outputChatBox(string.format("#34d399[BİRLİK]#ffffff Görev durumu: #34d399Aktif (Mesai Başladı)#ffffff. Birim: #38bdf8%s #ffffff- Rütbe: #e2e8f0%s", fData.short_name, rankName), player, 255, 255, 255, true)
        for p, data in pairs(PlayerFactions) do
            if isElement(p) and data.faction_id == fId and p ~= player then
                outputChatBox(string.format("#38bdf8[%s TELSİZ]#ffffff %s %s mesaiye başladı.", fData.short_name, rankName, pName), p, 255, 255, 255, true)
            end
        end
    else
        outputChatBox(string.format("#ef4444[BİRLİK]#ffffff Görev durumu: #ef4444Pasif (Mesai Bitti / İzinli)#ffffff.", fData.short_name), player, 255, 255, 255, true)
        for p, data in pairs(PlayerFactions) do
            if isElement(p) and data.faction_id == fId and p ~= player then
                outputChatBox(string.format("#e2e8f0[%s TELSİZ]#ffffff %s %s mesaiyi bitirdi.", fData.short_name, rankName, pName), p, 255, 255, 255, true)
            end
        end
    end

    triggerClientEvent(player, "faction:dutyUpdated", resourceRoot, newDuty == 1)
end)

addEvent("faction:manageMember", true)
addEventHandler("faction:manageMember", root, function(action, targetCharId)
    local player = client or source
    if not isElement(player) or getElementType(player) ~= "player" then return end
    if client and client ~= player then return end
    if not getElementData(player, "loggedin_character") then return end
    if not checkCooldown(player, 700) then return end

    local pData = PlayerFactions[player]
    if not pData then
        triggerClientEvent(player, "faction:actionResponse", resourceRoot, false, "Birliğe üye değilsiniz!")
        return
    end

    local fId = pData.faction_id
    local fData = Factions[fId]
    if not fData then return end

    if not FactionConfig.canManageMembers(fId, pData.rank_id) then
        triggerClientEvent(player, "faction:actionResponse", resourceRoot, false, "Üye yönetimi için yetkiniz bulunmuyor!")
        return
    end

    targetCharId = tonumber(targetCharId)
    if not targetCharId or targetCharId <= 0 then
        triggerClientEvent(player, "faction:actionResponse", resourceRoot, false, "Geçersiz üye seçimi!")
        return
    end

    if targetCharId == pData.character_id then
        triggerClientEvent(player, "faction:actionResponse", resourceRoot, false, "Kendi üzerinizde işlem yapamazsınız!")
        return
    end

    local db = getFactionDB()
    if not db then return end

    dbQuery(function(qh)
        local rows = dbPoll(qh, 0)
        if not isElement(player) then return end
        if not rows or #rows == 0 then
            triggerClientEvent(player, "faction:actionResponse", resourceRoot, false, "Hedef üye bu birlikte bulunamadı!")
            return
        end

        local targetRow = rows[1]
        local targetRank = tonumber(targetRow.rank_id) or 1
        local targetName = targetRow.character_name or ("Karakter #" .. targetCharId)

        if targetRank >= pData.rank_id then
            triggerClientEvent(player, "faction:actionResponse", resourceRoot, false, "Sizinle aynı veya üst rütbedeki bir üyeye işlem yapamazsınız!")
            return
        end

        local targetOnlinePlayer = nil
        for p, actData in pairs(PlayerFactions) do
            if isElement(p) and actData.character_id == targetCharId then
                targetOnlinePlayer = p
                break
            end
        end

        local maxRank = FactionConfig.getMaxRank(fId)

        if action == "promote" then
            local newRank = targetRank + 1
            if newRank >= pData.rank_id then
                triggerClientEvent(player, "faction:actionResponse", resourceRoot, false, "Üyeyi kendi rütbenize veya daha yükseğe terfi ettiremezsiniz!")
                return
            end
            if newRank > maxRank then
                triggerClientEvent(player, "faction:actionResponse", resourceRoot, false, "Üye zaten en yüksek rütbede!")
                return
            end

            dbExec(db, "UPDATE faction_members SET rank_id = ? WHERE character_id = ?", newRank, targetCharId)
            if CharacterFactions[targetCharId] then
                CharacterFactions[targetCharId].rank_id = newRank
            end
            if targetOnlinePlayer then
                PlayerFactions[targetOnlinePlayer].rank_id = newRank
                syncPlayerFaction(targetOnlinePlayer)
                local rankInfo = fData.ranks and fData.ranks[newRank]
                local rTitle = rankInfo and rankInfo.name or ("Derece " .. newRank)
                outputChatBox(string.format("#34d399[BİRLİK]#ffffff Tebrikler! Yetkili tarafından rütbeniz yükseltildi: #38bdf8%s (D-%d)", rTitle, newRank), targetOnlinePlayer, 255, 255, 255, true)
            end

            local rankInfo = fData.ranks and fData.ranks[newRank]
            local rTitle = rankInfo and rankInfo.name or ("Derece " .. newRank)
            triggerClientEvent(player, "faction:actionResponse", resourceRoot, true, string.format("%s adlı üye terfi ettirildi: %s (D-%d)", targetName, rTitle, newRank))

        elseif action == "demote" then
            local newRank = targetRank - 1
            if newRank < 1 then
                triggerClientEvent(player, "faction:actionResponse", resourceRoot, false, "Üye zaten en alt rütbede!")
                return
            end

            dbExec(db, "UPDATE faction_members SET rank_id = ? WHERE character_id = ?", newRank, targetCharId)
            if CharacterFactions[targetCharId] then
                CharacterFactions[targetCharId].rank_id = newRank
            end
            if targetOnlinePlayer then
                PlayerFactions[targetOnlinePlayer].rank_id = newRank
                syncPlayerFaction(targetOnlinePlayer)
                local rankInfo = fData.ranks and fData.ranks[newRank]
                local rTitle = rankInfo and rankInfo.name or ("Derece " .. newRank)
                outputChatBox(string.format("#ef4444[BİRLİK]#ffffff Birlik rütbeniz düşürüldü: #e2e8f0%s (D-%d)", rTitle, newRank), targetOnlinePlayer, 255, 255, 255, true)
            end

            local rankInfo = fData.ranks and fData.ranks[newRank]
            local rTitle = rankInfo and rankInfo.name or ("Derece " .. newRank)
            triggerClientEvent(player, "faction:actionResponse", resourceRoot, true, string.format("%s adlı üyenin rütbesi düşürüldü: %s (D-%d)", targetName, rTitle, newRank))

        elseif action == "kick" then
            dbExec(db, "DELETE FROM faction_members WHERE character_id = ?", targetCharId)
            CharacterFactions[targetCharId] = nil

            if targetOnlinePlayer then
                PlayerFactions[targetOnlinePlayer] = nil
                clearPlayerFactionData(targetOnlinePlayer)
                local pName = getElementData(player, "character:name") or getPlayerName(player)
                outputChatBox(string.format("#ef4444[BİRLİK]#ffffff Yetkili %s tarafından birlikten ihraç edildiniz!", pName), targetOnlinePlayer, 255, 255, 255, true)
                triggerClientEvent(targetOnlinePlayer, "faction:receivePanelData", resourceRoot, nil, "Birliğinizden ihraç edildiniz.")
            end

            triggerClientEvent(player, "faction:actionResponse", resourceRoot, true, string.format("%s adlı üye birlikten ihraç edildi.", targetName))
        else
            triggerClientEvent(player, "faction:actionResponse", resourceRoot, false, "Bilinmeyen yönetim eylemi!")
        end
    end, db, "SELECT * FROM faction_members WHERE character_id = ? AND faction_id = ?", targetCharId, fId)
end)

addEvent("faction:invitePlayer", true)
addEventHandler("faction:invitePlayer", root, function(targetArg, rankId)
    local player = client or source
    if not isElement(player) or getElementType(player) ~= "player" then return end
    if client and client ~= player then return end

    local isLogged = getElementData(player, "loggedin_character") or getElementData(player, "character:id") or getElementData(player, "char:id")
    if not isLogged then return end
    if not checkCooldown(player, 800) then return end

    local pData = PlayerFactions[player]
    if not pData then
        triggerClientEvent(player, "faction:actionResponse", resourceRoot, false, "Birliğe üye değilsiniz!")
        return
    end

    local fId = pData.faction_id
    local fData = Factions[fId]
    if not fData then return end

    if not FactionConfig.canInviteMembers(fId, pData.rank_id) then
        triggerClientEvent(player, "faction:actionResponse", resourceRoot, false, "Üye davet etme yetkiniz bulunmuyor!")
        return
    end

    local target = findTargetPlayer(targetArg)
    if not target or not isElement(target) then
        triggerClientEvent(player, "faction:actionResponse", resourceRoot, false, "Hedef oyuncu bulunamadı!")
        return
    end

    if target == player then
        triggerClientEvent(player, "faction:actionResponse", resourceRoot, false, "Kendinize davet gönderemezsiniz!")
        return
    end

    local targetLogged = getElementData(target, "loggedin_character") or getElementData(target, "character:id") or getElementData(target, "char:id")
    if not targetLogged then
        triggerClientEvent(player, "faction:actionResponse", resourceRoot, false, "Hedef oyuncu henüz karaktere giriş yapmamış!")
        return
    end

    if PlayerFactions[target] or getElementData(target, "character:faction") or getElementData(target, "faction") then
        triggerClientEvent(player, "faction:actionResponse", resourceRoot, false, "Bu oyuncu zaten bir birliğe üye!")
        return
    end

    rankId = math.floor(tonumber(rankId) or 1)
    local maxRank = FactionConfig.getMaxRank(fId)
    if rankId < 1 or rankId >= pData.rank_id or rankId > maxRank then
        rankId = 1
    end

    local rankInfo = fData.ranks and fData.ranks[rankId]
    local rankTitle = rankInfo and rankInfo.name or ("Derece " .. rankId)
    local senderName = getElementData(player, "character:name") or getPlayerName(player):gsub("#%x%x%x%x%x%x", "")
    local targetName = getElementData(target, "character:name") or getPlayerName(target):gsub("#%x%x%x%x%x%x", "")

    PendingFactionInvites = PendingFactionInvites or {}
    PendingFactionInvites[target] = {
        faction_id = fId,
        sender = player,
        sender_name = senderName,
        faction_name = fData.name,
        faction_short = fData.short_name,
        rank_id = rankId,
        rank_name = rankTitle,
        expires = getTickCount() + 60000
    }

    triggerClientEvent(target, "faction:showInvitePrompt", resourceRoot, {
        faction_id = fId,
        faction_name = fData.name,
        faction_short = fData.short_name,
        sender_name = senderName,
        rank_id = rankId,
        rank_name = rankTitle,
        duration = 60
    })

    outputChatBox(string.format("#38bdf8[BİRLİK DAVETİ]#ffffff #34d399%s#ffffff sizi #38bdf8%s#ffffff birliğine (#e2e8f0%s#ffffff) davet etti! Açılan pencereden veya #34d399/faccept#ffffff ile kabul edebilirsiniz.", senderName, fData.name, rankTitle), target, 255, 255, 255, true)
    triggerClientEvent(player, "faction:actionResponse", resourceRoot, true, string.format("%s adlı oyuncuya davet gönderildi.", targetName))
end)

addEvent("faction:respondInvite", true)
addEventHandler("faction:respondInvite", root, function(accept)
    local player = client or source
    if not isElement(player) or getElementType(player) ~= "player" then return end
    if client and client ~= player then return end

    local isLogged = getElementData(player, "loggedin_character") or getElementData(player, "character:id") or getElementData(player, "char:id")
    if not isLogged then return end

    PendingFactionInvites = PendingFactionInvites or {}
    local invite = PendingFactionInvites[player]
    if not invite or getTickCount() > invite.expires then
        PendingFactionInvites[player] = nil
        triggerClientEvent(player, "faction:actionResponse", resourceRoot, false, "Bekleyen veya geçerli bir davet bulunmuyor!")
        return
    end

    local fId = invite.faction_id
    local fData = Factions[fId]
    if not fData then
        PendingFactionInvites[player] = nil
        return
    end

    local charId = getPlayerCharacterId(player)
    if not charId then return end

    if accept then
        local rankId = invite.rank_id or 1
        local db = getFactionDB()
        local charName = getElementData(player, "character:name") or getPlayerName(player):gsub("#%x%x%x%x%x%x", "")

        if db then
            dbExec(db, "INSERT OR REPLACE INTO faction_members (character_id, faction_id, character_name, rank_id, duty_status) VALUES (?, ?, ?, ?, 0)", charId, fId, charName, rankId)
        end

        PlayerFactions[player] = {
            character_id = charId,
            faction_id = fId,
            rank_id = rankId,
            duty_status = 0
        }
        CharacterFactions[charId] = PlayerFactions[player]
        syncPlayerFaction(player)

        PendingFactionInvites[player] = nil

        outputChatBox(string.format("#34d399[BİRLİK]#ffffff Tebrikler! #38bdf8%s#ffffff birliğine başarıyla katıldınız.", fData.name), player, 255, 255, 255, true)
        triggerClientEvent(player, "faction:actionResponse", resourceRoot, true, string.format("%s birliğine katıldınız!", fData.name))

        if isElement(invite.sender) then
            outputChatBox(string.format("#34d399[BİRLİK]#ffffff %s adlı oyuncu birlik davetinizi kabul etti.", charName), invite.sender, 255, 255, 255, true)
        end

        for p, data in pairs(PlayerFactions) do
            if isElement(p) and data.faction_id == fId and p ~= player then
                outputChatBox(string.format("#38bdf8[BİRLİK]#ffffff Yeni üye #34d399%s#ffffff aramıza katıldı!", charName), p, 255, 255, 255, true)
            end
        end
    else
        PendingFactionInvites[player] = nil
        outputChatBox("#ef4444[BİRLİK]#ffffff Birlik davetini reddettiniz.", player, 255, 255, 255, true)
        if isElement(invite.sender) then
            local charName = getElementData(player, "character:name") or getPlayerName(player)
            outputChatBox(string.format("#ef4444[BİRLİK]#ffffff %s adlı oyuncu birlik davetinizi reddetti.", charName), invite.sender, 255, 255, 255, true)
        end
    end
end)

addEvent("faction:vaultAction", true)
addEventHandler("faction:vaultAction", root, function(actionType, amount, reason)
    local player = client or source
    if not isElement(player) or getElementType(player) ~= "player" then return end
    if client and client ~= player then return end

    local isLogged = getElementData(player, "loggedin_character") or getElementData(player, "character:id") or getElementData(player, "char:id")
    if not isLogged then return end
    if not checkCooldown(player, 1000) then return end

    local pData = PlayerFactions[player]
    if not pData then
        triggerClientEvent(player, "faction:actionResponse", resourceRoot, false, "Birliğe üye değilsiniz!")
        return
    end

    local fId = pData.faction_id
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 or amount > 100000000 or amount ~= amount then
        triggerClientEvent(player, "faction:actionResponse", resourceRoot, false, "Geçersiz işlem miktarı!")
        return
    end

    reason = sanitizeText(reason, 60)
    if reason == "" then
        reason = (actionType == "deposit") and "Kasa yatırma" or "Kasa çekme"
    end

    if actionType == "deposit" then
        local ok, res = depositFactionVault(player, amount, reason)
        if ok then
            triggerClientEvent(player, "faction:actionResponse", resourceRoot, true, string.format("Kasaya başarıyla $%d yatırıldı.", amount))
            getFactionVaultLogs(fId, 20, function(newLogs)
                if isElement(player) then
                    local pCash = (exports.gzl_characters and exports.gzl_characters.getPlayerCash) and exports.gzl_characters:getPlayerCash(player) or tonumber(getElementData(player, "character:money") or getPlayerMoney(player)) or 0
                    triggerClientEvent(player, "faction:vaultUpdated", resourceRoot, res, newLogs, pCash)
                end
            end)
        else
            triggerClientEvent(player, "faction:actionResponse", resourceRoot, false, tostring(res))
        end

    elseif actionType == "withdraw" then
        if not FactionConfig.canWithdrawVault(fId, pData.rank_id) then
            triggerClientEvent(player, "faction:actionResponse", resourceRoot, false, "Kasadan para çekmek için yetkili rütbede olmalısınız!")
            return
        end

        local ok, res = withdrawFactionVault(player, amount, reason)
        if ok then
            triggerClientEvent(player, "faction:actionResponse", resourceRoot, true, string.format("Kasadan başarıyla $%d çekildi.", amount))
            getFactionVaultLogs(fId, 20, function(newLogs)
                if isElement(player) then
                    local pCash = (exports.gzl_characters and exports.gzl_characters.getPlayerCash) and exports.gzl_characters:getPlayerCash(player) or tonumber(getElementData(player, "character:money") or getPlayerMoney(player)) or 0
                    triggerClientEvent(player, "faction:vaultUpdated", resourceRoot, res, newLogs, pCash)
                end
            end)
        else
            triggerClientEvent(player, "faction:actionResponse", resourceRoot, false, tostring(res))
        end
    else
        triggerClientEvent(player, "faction:actionResponse", resourceRoot, false, "Geçersiz kasa işlemi!")
    end
end)

addEvent("faction:connectRadio", true)
addEventHandler("faction:connectRadio", root, function(targetFreq)
    local player = client or source
    if not isElement(player) or getElementType(player) ~= "player" then return end
    if client and client ~= player then return end

    if not checkCooldown(player, 1000) then
        triggerClientEvent(player, "faction:actionResponse", resourceRoot, false, "Lütfen biraz bekleyin.")
        return
    end

    local pData = PlayerFactions[player]
    if not pData then
        if loadPlayerFaction then loadPlayerFaction(player) end
        pData = PlayerFactions[player]
    end
    if not pData then
        triggerClientEvent(player, "faction:actionResponse", resourceRoot, false, "Herhangi bir birliğe üye değilsiniz!")
        return
    end

    local fId = pData.faction_id
    local fData = Factions[fId]
    local fType = fData and fData.faction_type or "default"
    local theme = FactionConfig.getTypeTheme(fType)
    local allowedFreq = theme and theme.channel

    local freqToConnect = tostring(targetFreq or allowedFreq or "155.0")

    local radioRes = getResourceFromName("gzl_radio")
    if not radioRes or getResourceState(radioRes) ~= "running" then
        triggerClientEvent(player, "faction:actionResponse", resourceRoot, false, "Telsiz sistemi (gzl_radio) şu anda aktif değil!")
        return
    end

    local ok, err = exports.gzl_radio:setPlayerChannel(player, freqToConnect)
    if ok then
        pcall(function() exports.gzl_radio:openRadio(player) end)
        triggerClientEvent(player, "faction:actionResponse", resourceRoot, true, string.format("Teşkilat telsiz frekansına (%s MHz) başarıyla bağlanıldı!", freqToConnect))
    else
        triggerClientEvent(player, "faction:actionResponse", resourceRoot, false, tostring(err or "Frekansa bağlanılamadı!"))
    end
end)