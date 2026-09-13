local function trustedAdminLevel(player)
    local auth = getResourceFromName("gzl_auth")
    if not isElement(player) or not auth or getResourceState(auth) ~= "running" then return 0 end
    return exports.gzl_auth:getAdminLevel(player)
end

PendingFactionInvites = PendingFactionInvites or {}
local pendingInvites = PendingFactionInvites

local function findTarget(query)
    if not query or query == "" then return nil end
    local num = tonumber(query)
    if num then
        for _, p in ipairs(getElementsByType("player")) do
            local cid = tonumber(getElementData(p, "character:id") or getElementData(p, "char:id") or getElementData(p, "id") or getElementData(p, "playerid"))
            if cid == num then return p end
        end
    end
    local qLower = string.lower(query):gsub("#%x%x%x%x%x%x", "")
    for _, p in ipairs(getElementsByType("player")) do
        local pName = string.lower(getPlayerName(p)):gsub("#%x%x%x%x%x%x", "")
        local cName = string.lower(tostring(getElementData(p, "character:name") or getElementData(p, "char:name") or "")):gsub("_", " ")
        if string.find(pName, qLower, 1, true) or (cName ~= "" and string.find(cName, qLower, 1, true)) then
            return p
        end
    end
    return nil
end

addEventHandler("onPlayerQuit", root, function()
    pendingInvites[source] = nil
end)

addCommandHandler("duty", function(player, cmd)
    if not isElement(player) or not getElementData(player, "loggedin_character") then return end

    local pData = PlayerFactions[player]
    if not pData then
        outputChatBox("#ef4444[BİRLİK]#ffffff Herhangi bir kamu veya resmi birliğe üye değilsiniz!", player, 255, 255, 255, true)
        return
    end

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
end)
addCommandHandler("gorev", function(player, cmd)
    executeCommandHandler("duty", player)
end)

local function handleFactionChat(player, cmd, ...)
    if not isElement(player) or not getElementData(player, "loggedin_character") then return end

    local pData = PlayerFactions[player]
    if not pData then
        outputChatBox("#ef4444[BİRLİK]#ffffff Birlik telsizini kullanmak için bir birlikte olmalısınız!", player, 255, 255, 255, true)
        return
    end

    local rawMsg = table.concat({...}, " ")
    rawMsg = string.gsub(rawMsg, "^%s*(.-)%s*$", "%1")
    if rawMsg == "" then
        outputChatBox("#38bdf8[KULLANIM]#ffffff /" .. cmd .. " [mesaj]", player, 255, 255, 255, true)
        return
    end

    local fId = pData.faction_id
    local fData = Factions[fId]
    if not fData then return end

    local rankName = (fData.ranks and fData.ranks[pData.rank_id]) and fData.ranks[pData.rank_id].name or "Üye"
    local pName = getElementData(player, "character:name") or getPlayerName(player)
    local dutyTag = (pData.duty_status == 1) and "" or " (İzinli)"

    local hexColor = "#38bdf8"
    if fData.faction_type == "ems" then
        hexColor = "#ef4444"
    elseif fData.faction_type == "gov" then
        hexColor = "#f59e0b"
    end

    local formatted = string.format("%s[%s%s | %s %s]#ffffff: %s", hexColor, fData.short_name, dutyTag, rankName, pName, rawMsg)

    for p, data in pairs(PlayerFactions) do
        if isElement(p) and data.faction_id == fId then
            outputChatBox(formatted, p, 255, 255, 255, true)
        end
    end
end
addCommandHandler("f", handleFactionChat)
addCommandHandler("r", handleFactionChat)

addCommandHandler("fmembers", function(player, cmd)
    if not isElement(player) or not getElementData(player, "loggedin_character") then return end

    local pData = PlayerFactions[player]
    if not pData then
        outputChatBox("#ef4444[BİRLİK]#ffffff Bir birlikte bulunmuyorsunuz!", player, 255, 255, 255, true)
        return
    end

    local fId = pData.faction_id
    local fData = Factions[fId]
    if not fData then return end

    outputChatBox(string.format("#38bdf8=== %s Çevrimiçi Üyeler ===", fData.name), player, 255, 255, 255, true)
    local count = 0
    for p, data in pairs(PlayerFactions) do
        if isElement(p) and data.faction_id == fId then
            count = count + 1
            local rInfo = fData.ranks and fData.ranks[data.rank_id]
            local rName = rInfo and rInfo.name or ("Derece " .. tostring(data.rank_id))
            local pName = getElementData(p, "character:name") or getPlayerName(p)
            local dutyStr = (data.duty_status == 1) and "#34d399[MESAİDE]" or "#94a3b8[İZİNLİ]"
            outputChatBox(string.format("  #ffffff- %s #e2e8f0%s #38bdf8(%s)", dutyStr, pName, rName), player, 255, 255, 255, true)
        end
    end
    outputChatBox(string.format("#38bdf8Toplam Aktif Üye:#ffffff %d", count), player, 255, 255, 255, true)
end)
addCommandHandler("birlikuyeler", function(player, cmd)
    executeCommandHandler("fmembers", player)
end)

addCommandHandler("finvite", function(player, cmd, targetArg)
    if not isElement(player) or not getElementData(player, "loggedin_character") then return end

    local pData = PlayerFactions[player]
    if not pData then return end

    local fId = pData.faction_id
    local fData = Factions[fId]
    if not fData then return end

    local maxR = FactionConfig.getMaxRank(fId)
    local canInvite = false
    if pData.rank_id >= maxR then
        canInvite = true
    elseif maxR <= 5 then
        canInvite = (pData.rank_id >= 3)
    else
        canInvite = (pData.rank_id >= (FactionConfig.MinInviteRank or 4))
    end

    if not canInvite then
        outputChatBox("#ef4444[BİRLİK]#ffffff Üye davet etmek için yetkiniz bulunmamaktadır!", player, 255, 255, 255, true)
        return
    end

    local target = findTarget(targetArg)
    if not target then
        outputChatBox("#38bdf8[KULLANIM]#ffffff /" .. cmd .. " [oyuncu_id / isim]", player, 255, 255, 255, true)
        return
    end

    if target == player then
        outputChatBox("#ef4444[BİRLİK]#ffffff Kendinizi davet edemezsiniz!", player, 255, 255, 255, true)
        return
    end

    if not getElementData(target, "loggedin_character") then
        outputChatBox("#ef4444[BİRLİK]#ffffff Hedef oyuncu bir karaktere giriş yapmamış!", player, 255, 255, 255, true)
        return
    end

    if PlayerFactions[target] then
        outputChatBox("#ef4444[BİRLİK]#ffffff Bu oyuncu zaten bir birliğe üye!", player, 255, 255, 255, true)
        return
    end

    local rankInfo = fData.ranks and fData.ranks[1]
    local rankTitle = rankInfo and rankInfo.name or "Derece 1"

    local pName = getElementData(player, "character:name") or getPlayerName(player):gsub("#%x%x%x%x%x%x", "")
    local tName = getElementData(target, "character:name") or getPlayerName(target):gsub("#%x%x%x%x%x%x", "")

    pendingInvites[target] = {
        faction_id = pData.faction_id,
        sender = player,
        sender_name = pName,
        faction_name = fData.name,
        faction_short = fData.short_name,
        rank_id = 1,
        rank_name = rankTitle,
        expires = getTickCount() + 60000
    }

    triggerClientEvent(target, "faction:showInvitePrompt", resourceRoot, {
        faction_id = pData.faction_id,
        faction_name = fData.name,
        faction_short = fData.short_name,
        sender_name = pName,
        rank_id = 1,
        rank_name = rankTitle,
        duration = 60
    })

    outputChatBox(string.format("#34d399[BİRLİK]#ffffff %s adlı oyuncuyu #38bdf8%s#ffffff birliğine davet ettiniz.", tName, fData.name), player, 255, 255, 255, true)
    outputChatBox(string.format("#38bdf8[BİRLİK DAVETİ]#ffffff #34d399%s#ffffff sizi #38bdf8%s#ffffff birliğine davet etti! Açılan pencereden veya #34d399/faccept#ffffff yazarak kabul edebilirsiniz.", pName, fData.name), target, 255, 255, 255, true)
end)
addCommandHandler("birlikdavet", function(player, cmd, targetArg)
    executeCommandHandler("finvite", player, targetArg)
end)

addCommandHandler("faccept", function(player, cmd)
    if not isElement(player) or not getElementData(player, "loggedin_character") then return end

    local invite = pendingInvites[player]
    if not invite or getTickCount() > invite.expires then
        outputChatBox("#ef4444[BİRLİK]#ffffff Bekleyen veya geçerli bir birlik davetiniz bulunmuyor!", player, 255, 255, 255, true)
        pendingInvites[player] = nil
        return
    end

    local fId = invite.faction_id
    local fData = Factions[fId]
    if not fData then
        pendingInvites[player] = nil
        return
    end

    local charId = getPlayerCharacterId(player)
    if not charId then return end

    local rankId = invite.rank_id or 1
    local pName = getElementData(player, "character:name") or getPlayerName(player):gsub("#%x%x%x%x%x%x", "")

    local db = getFactionDB()
    if db then
        dbExec(db, "INSERT OR REPLACE INTO faction_members (character_id, faction_id, character_name, rank_id, duty_status) VALUES (?, ?, ?, ?, 0)", charId, fId, pName, rankId)
    end

    PlayerFactions[player] = {
        character_id = charId,
        faction_id = fId,
        rank_id = rankId,
        duty_status = 0
    }
    CharacterFactions[charId] = PlayerFactions[player]
    syncPlayerFaction(player)
    pendingInvites[player] = nil

    outputChatBox(string.format("#34d399[BİRLİK]#ffffff Tebrikler! #38bdf8%s#ffffff birliğine başarıyla katıldınız.", fData.name), player, 255, 255, 255, true)
    triggerClientEvent(player, "faction:actionResponse", resourceRoot, true, string.format("%s birliğine katıldınız!", fData.name))

    if isElement(invite.sender) then
        outputChatBox(string.format("#34d399[BİRLİK]#ffffff %s adlı oyuncu birlik davetinizi kabul etti.", pName), invite.sender, 255, 255, 255, true)
    end

    for p, data in pairs(PlayerFactions) do
        if isElement(p) and data.faction_id == fId and p ~= player then
            outputChatBox(string.format("#38bdf8[BİRLİK]#ffffff Yeni üye #34d399%s#ffffff birliğimize katıldı!", pName), p, 255, 255, 255, true)
        end
    end
end)
addCommandHandler("birlikkabul", function(player, cmd)
    executeCommandHandler("faccept", player)
end)

addCommandHandler("fkick", function(player, cmd, targetArg)
    if not isElement(player) or not getElementData(player, "loggedin_character") then return end

    local pData = PlayerFactions[player]
    if not pData then return end

    if not FactionConfig.canManageMembers(pData.faction_id, pData.rank_id) then
        outputChatBox("#ef4444[BİRLİK]#ffffff Üye ihraç etmek için yetkiniz bulunmamaktadır!", player, 255, 255, 255, true)
        return
    end

    local target = findTarget(targetArg)
    if not target then
        outputChatBox("#38bdf8[KULLANIM]#ffffff /" .. cmd .. " [oyuncu_id / isim]", player, 255, 255, 255, true)
        return
    end

    if target == player then
        outputChatBox("#ef4444[BİRLİK]#ffffff Kendinizi ihraç edemezsiniz!", player, 255, 255, 255, true)
        return
    end

    local tData = PlayerFactions[target]
    if not tData or tData.faction_id ~= pData.faction_id then
        outputChatBox("#ef4444[BİRLİK]#ffffff Bu oyuncu birliğinizde bulunmuyor!", player, 255, 255, 255, true)
        return
    end

    if tData.rank_id >= pData.rank_id then
        outputChatBox("#ef4444[BİRLİK]#ffffff Sizinle aynı veya üst rütbedeki bir üyeyi ihraç edemezsiniz!", player, 255, 255, 255, true)
        return
    end

    local charId = tData.character_id
    local db = getFactionDB()
    if db then
        dbExec(db, "DELETE FROM faction_members WHERE character_id = ?", charId)
    end

    pendingInvites[target] = nil
    PlayerFactions[target] = nil
    CharacterFactions[charId] = nil
    clearPlayerFactionData(target)

    local tName = getElementData(target, "character:name") or getPlayerName(target)
    local pName = getElementData(player, "character:name") or getPlayerName(player)

    outputChatBox(string.format("#ef4444[BİRLİK]#ffffff %s adlı üyeyi birlikten ihraç ettiniz.", tName), player, 255, 255, 255, true)
    outputChatBox(string.format("#ef4444[BİRLİK]#ffffff Yetkili %s tarafından birlikten ihraç edildiniz!", pName), target, 255, 255, 255, true)
    triggerClientEvent(target, "faction:receivePanelData", resourceRoot, nil, "Birliğinizden ihraç edildiniz.")
end)
addCommandHandler("birlikat", function(player, cmd, targetArg)
    executeCommandHandler("fkick", player, targetArg)
end)

addCommandHandler("fsetrank", function(player, cmd, targetArg, rankArg)
    if not isElement(player) or not getElementData(player, "loggedin_character") then return end

    local pData = PlayerFactions[player]
    if not pData then return end

    if not FactionConfig.canManageMembers(pData.faction_id, pData.rank_id) then
        outputChatBox("#ef4444[BİRLİK]#ffffff Rütbe vermek için yetkiniz bulunmamaktadır!", player, 255, 255, 255, true)
        return
    end

    local fId = pData.faction_id
    local fData = Factions[fId]
    if not fData then return end

    local maxRank = FactionConfig.getMaxRank(fId)
    local target = findTarget(targetArg)
    local newRank = tonumber(rankArg)

    if not target or not newRank then
        outputChatBox(string.format("#38bdf8[KULLANIM]#ffffff /%s [oyuncu_id / isim] [yeni_derece (1-%d)]", cmd, maxRank), player, 255, 255, 255, true)
        return
    end

    if newRank < 1 or newRank > maxRank or math.floor(newRank) ~= newRank then
        outputChatBox(string.format("#ef4444[HATA]#ffffff Geçersiz rütbe! 1 ile %d arasında bir tam sayı girmelisiniz.", maxRank), player, 255, 255, 255, true)
        return
    end

    if target == player then
        outputChatBox("#ef4444[BİRLİK]#ffffff Kendi rütbenizi değiştiremezsiniz!", player, 255, 255, 255, true)
        return
    end

    local tData = PlayerFactions[target]
    if not tData or tData.faction_id ~= pData.faction_id then
        outputChatBox("#ef4444[BİRLİK]#ffffff Bu oyuncu birliğinizde bulunmuyor!", player, 255, 255, 255, true)
        return
    end

    if newRank >= pData.rank_id then
        outputChatBox("#ef4444[BİRLİK]#ffffff Kendi rütbenizden daha yüksek veya eşit bir rütbe veremezsiniz!", player, 255, 255, 255, true)
        return
    end

    if tData.rank_id >= pData.rank_id then
        outputChatBox("#ef4444[BİRLİK]#ffffff Sizinle aynı veya daha üst rütbedeki bir üyenin rütbesini değiştiremezsiniz!", player, 255, 255, 255, true)
        return
    end

    tData.rank_id = newRank
    local db = getFactionDB()
    if db then
        dbExec(db, "UPDATE faction_members SET rank_id = ? WHERE character_id = ?", newRank, tData.character_id)
    end
    syncPlayerFaction(target)

    local rankInfo = fData.ranks and fData.ranks[newRank]
    local rName = rankInfo and rankInfo.name or ("Derece " .. tostring(newRank))

    local tName = getElementData(target, "character:name") or getPlayerName(target)
    outputChatBox(string.format("#34d399[BİRLİK]#ffffff %s adlı üyenin rütbesi güncellendi: #38bdf8%s (Derece %d)", tName, rName, newRank), player, 255, 255, 255, true)
    outputChatBox(string.format("#34d399[BİRLİK]#ffffff Birlik rütbeniz güncellendi: #38bdf8%s (Derece %d)", rName, newRank), target, 255, 255, 255, true)
end)
addCommandHandler("rutbever", function(player, cmd, targetArg, rankArg)
    executeCommandHandler("fsetrank", player, targetArg, rankArg)
end)

addCommandHandler("fvault", function(player, cmd, subCmd, amountArg)
    if not isElement(player) or not getElementData(player, "loggedin_character") then return end

    local pData = PlayerFactions[player]
    if not pData then
        outputChatBox("#ef4444[BİRLİK]#ffffff Bir birliğe üye değilsiniz!", player, 255, 255, 255, true)
        return
    end

    subCmd = subCmd and string.lower(subCmd) or "bakiye"

    if subCmd == "bakiye" or subCmd == "balance" then
        local bal = getFactionVault(pData.faction_id)
        local fData = Factions[pData.faction_id]
        outputChatBox(string.format("#38bdf8[%s KASASI]#ffffff Mevcut Kasa Bakiyesi: #34d399$%d", (fData and fData.short_name or "BİRLİK"), bal), player, 255, 255, 255, true)
    elseif subCmd == "yatir" or subCmd == "deposit" then
        local amt = tonumber(amountArg)
        if not amt or amt <= 0 then
            outputChatBox("#38bdf8[KULLANIM]#ffffff /" .. cmd .. " yatir [miktar]", player, 255, 255, 255, true)
            return
        end
        local ok, msg = depositFactionVault(player, amt, "Oyuncu elden kasaya yatırdı")
        if not ok then
            outputChatBox("#ef4444[BİRLİK KASASI]#ffffff " .. tostring(msg), player, 255, 255, 255, true)
        end
    elseif subCmd == "cek" or subCmd == "withdraw" then
        local amt = tonumber(amountArg)
        if not amt or amt <= 0 then
            outputChatBox("#38bdf8[KULLANIM]#ffffff /" .. cmd .. " cek [miktar]", player, 255, 255, 255, true)
            return
        end
        local ok, msg = withdrawFactionVault(player, amt, "Yetkili kasadan çekti")
        if not ok then
            outputChatBox("#ef4444[BİRLİK KASASI]#ffffff " .. tostring(msg), player, 255, 255, 255, true)
        end
    else
        outputChatBox("#38bdf8[KULLANIM]#ffffff /" .. cmd .. " [bakiye | yatir <miktar> | cek <miktar>]", player, 255, 255, 255, true)
    end
end)
addCommandHandler("kasa", function(player, cmd, subCmd, amountArg)
    executeCommandHandler("fvault", player, subCmd, amountArg)
end)

addCommandHandler("setfaction", function(player, cmd, targetArg, factionArg, rankArg)
    local isConsole = not isElement(player)
    if not isConsole then
        local adminLvl = trustedAdminLevel(player)
        local hasAcl = false
        if adminLvl < 2 and not hasAcl then
            outputChatBox("#ef4444[YETKİ]#ffffff Bu komutu kullanmak için yönetici yetkiniz bulunmamaktadır!", player, 255, 255, 255, true)
            return
        end
    end

    local function sendAdminMsg(msg, isErr)
        if isConsole then
            outputServerLog(msg:gsub("#%x%x%x%x%x%x", ""))
        else
            outputChatBox(msg, player, 255, 255, 255, true)
        end
    end

    local target = findTarget(targetArg)
    local fId = tonumber(factionArg)
    local rId = tonumber(rankArg) or 1

    if not target or not fId then
        sendAdminMsg("#38bdf8[KULLANIM]#ffffff /setfaction [oyuncu_id/isim] [birlik_id (0=çıkar)] [derece (1-10)]", false)
        sendAdminMsg("  #e2e8f0Birlikler: 1=LSPD, 2=EMS, 3=GOV, 0=Sivil (Birliği Kaldır)", false)
        return
    end

    local charId = getPlayerCharacterId(target)
    if not charId then
        sendAdminMsg("#ef4444[HATA]#ffffff Hedef oyuncunun aktif karakteri bulunamadı!", true)
        return
    end

    local db = getFactionDB()
    if fId == 0 then
        if db then
            dbExec(db, "DELETE FROM faction_members WHERE character_id = ?", charId)
        end
        pendingInvites[target] = nil
        PlayerFactions[target] = nil
        CharacterFactions[charId] = nil
        clearPlayerFactionData(target)
        sendAdminMsg("#34d399[YÖNETİCİ]#ffffff Oyuncu tüm birliklerden çıkarıldı.", false)
        outputChatBox("#ef4444[BİRLİK]#ffffff Bir yönetici tarafından birlikten çıkarıldınız.", target, 255, 255, 255, true)
        triggerClientEvent(target, "faction:receivePanelData", resourceRoot, nil, "Bir yönetici tarafından birlikten çıkarıldınız.")
        return
    end

    local fData = Factions[fId]
    if not fData then
        sendAdminMsg("#ef4444[HATA]#ffffff Belirtilen ID'ye sahip bir birlik bulunamadı!", true)
        return
    end

    local maxRank = FactionConfig.getMaxRank(fId)
    if rId < 1 or rId > maxRank or math.floor(rId) ~= rId then
        sendAdminMsg(string.format("#ef4444[HATA]#ffffff Bu birlik için geçerli rütbe aralığı 1 ile %d arasındadır!", maxRank), true)
        return
    end

    local tName = getElementData(target, "character:name") or getPlayerName(target):gsub("#%x%x%x%x%x%x", "")
    if db then
        dbExec(db, "INSERT OR REPLACE INTO faction_members (character_id, faction_id, character_name, rank_id, duty_status) VALUES (?, ?, ?, ?, 0)", charId, fId, tName, rId)
    end

    pendingInvites[target] = nil
    PlayerFactions[target] = {
        character_id = charId,
        faction_id = fId,
        rank_id = rId,
        duty_status = 0
    }
    CharacterFactions[charId] = PlayerFactions[target]
    syncPlayerFaction(target)

    local rankName = (fData.ranks and fData.ranks[rId]) and fData.ranks[rId].name or ("Derece " .. tostring(rId))
    sendAdminMsg(string.format("#34d399[YÖNETİCİ]#ffffff %s adlı oyuncu #38bdf8%s#ffffff birliğine atandı (#e2e8f0%s#ffffff).", getPlayerName(target), fData.name, rankName), false)
    outputChatBox(string.format("#34d399[BİRLİK]#ffffff Yönetici tarafından #38bdf8%s#ffffff birliğine atandınız (#e2e8f0%s#ffffff).", fData.name, rankName), target, 255, 255, 255, true)

    if exports.gzl_logs and exports.gzl_logs.logAdmin then
        pcall(function() exports.gzl_logs:logAdmin(player, "setfaction", target, string.format("Assigned to faction %s (Rank %d)", fData.short_name, rId)) end)
    end
end)