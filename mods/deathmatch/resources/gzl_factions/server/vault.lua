function getFactionVault(factionId)
    factionId = tonumber(factionId)
    if not factionId or not Factions[factionId] then return 0 end
    return Factions[factionId].vault_balance or 0
end

function modifyFactionVault(factionId, amount, reason, player)
    factionId = tonumber(factionId)
    amount = math.floor(tonumber(amount) or 0)
    if not factionId or not Factions[factionId] or amount == 0 then return false end

    local current = Factions[factionId].vault_balance or 0
    if (current + amount) < 0 then return false end

    local newBalance = current + amount
    Factions[factionId].vault_balance = newBalance

    local db = getFactionDB()
    if db then
        dbExec(db, "UPDATE factions SET vault_balance = ? WHERE id = ?", newBalance, factionId)
    end

    if exports.gzl_logs and exports.gzl_logs.logMoney then
        local transType = amount > 0 and "faction_vault_deposit" or "faction_vault_withdraw"
        local sender = amount > 0 and (player or "N/A") or ("FACTION_" .. tostring(factionId))
        local receiver = amount > 0 and ("FACTION_" .. tostring(factionId)) or (player or "N/A")
        pcall(function() exports.gzl_logs:logMoney(sender, receiver, math.abs(amount), transType, reason or "Kasa işlemi") end)
    end

    if addFactionVaultLog then
        local cId = (isElement(player) and getPlayerCharacterId) and getPlayerCharacterId(player) or 0
        local cName = isElement(player) and (getElementData(player, "character:name") or getPlayerName(player)) or (type(player) == "string" and player or "Sistem")
        local actType = amount > 0 and "deposit" or "withdraw"
        addFactionVaultLog(factionId, cId, cName, actType, math.abs(amount), reason or "Kasa işlemi")
    end

    return true, newBalance
end

function depositFactionVault(player, amount, reason)
    if not isElement(player) then return false, "Geçersiz oyuncu" end
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 or amount > 100000000 or amount ~= amount then return false, "Geçersiz miktar" end

    local pData = PlayerFactions[player]
    if not pData then return false, "Herhangi bir birliğe üye değilsiniz" end

    local fId = pData.faction_id
    local pCash = 0
    if exports.gzl_characters and exports.gzl_characters.getPlayerCash then
        pCash = exports.gzl_characters:getPlayerCash(player)
    else
        pCash = tonumber(getElementData(player, "character:money") or getPlayerMoney(player)) or 0
    end

    if pCash < amount then
        return false, "Üzerinizde yeterli nakit para bulunmuyor!"
    end

    local deducted = false
    if exports.gzl_characters and exports.gzl_characters.takePlayerCash then
        deducted = exports.gzl_characters:takePlayerCash(player, amount)
    else
        takePlayerMoney(player, amount)
        setElementData(player, "character:money", pCash - amount, "broadcast", "deny")
        setElementData(player, "char:money", pCash - amount, "broadcast", "deny")
        deducted = true
    end

    if not deducted then
        return false, "Üzerinizden para tahsil edilemedi!"
    end

    local success, newBal = modifyFactionVault(fId, amount, reason or "Oyuncu para yatırdı", player)
    if not success then
        if exports.gzl_characters and exports.gzl_characters.givePlayerCash then
            exports.gzl_characters:givePlayerCash(player, amount)
        else
            givePlayerMoney(player, amount)
            setElementData(player, "character:money", pCash, "broadcast", "deny")
            setElementData(player, "char:money", pCash, "broadcast", "deny")
        end
        return false, "Kasa bakiyesi güncellenemedi!"
    end

    local pName = getElementData(player, "character:name") or getPlayerName(player)
    for p, data in pairs(PlayerFactions) do
        if isElement(p) and data.faction_id == fId then
            outputChatBox(string.format("#38bdf8[BİRLİK KASASI]#ffffff %s adlı üye kasaya #34d399$%d#ffffff yatırdı. Güncel Bakiye: #38bdf8$%d", pName, amount, newBal), p, 255, 255, 255, true)
        end
    end
    return true, newBal
end

function withdrawFactionVault(player, amount, reason)
    if not isElement(player) then return false, "Geçersiz oyuncu" end
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 or amount > 100000000 or amount ~= amount then return false, "Geçersiz miktar" end

    local pData = PlayerFactions[player]
    if not pData then return false, "Herhangi bir birliğe üye değilsiniz" end

    local fId = pData.faction_id
    if not FactionConfig.canWithdrawVault(fId, pData.rank_id) then
        return false, "Kasadan para çekmek için yetkili rütbede olmalısınız!"
    end

    local curVault = getFactionVault(fId)
    if curVault < amount then
        return false, string.format("Birlik kasasında yeterli bakiye yok! (Mevcut: $%d)", curVault)
    end

    local success, newBal = modifyFactionVault(fId, -amount, reason or "Yetkili para çekti", player)
    if success then
        if exports.gzl_characters and exports.gzl_characters.givePlayerCash then
            exports.gzl_characters:givePlayerCash(player, amount)
        else
            givePlayerMoney(player, amount)
            local cur = tonumber(getElementData(player, "character:money") or getPlayerMoney(player)) or 0
            setElementData(player, "character:money", cur + amount, "broadcast", "deny")
            setElementData(player, "char:money", cur + amount, "broadcast", "deny")
        end

        local pName = getElementData(player, "character:name") or getPlayerName(player)
        for p, data in pairs(PlayerFactions) do
            if isElement(p) and data.faction_id == fId then
                outputChatBox(string.format("#ef4444[BİRLİK KASASI]#ffffff %s adlı yetkili kasadan #ef4444$%d#ffffff çekti. Kalan Bakiye: #38bdf8$%d", pName, amount, newBal), p, 255, 255, 255, true)
            end
        end
        return true, newBal
    end

    return false, "Bakiye düşürülemedi"
end