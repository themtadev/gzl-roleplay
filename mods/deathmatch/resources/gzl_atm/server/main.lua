local atmObjects = {}
local mapObjects = {}

local function ensureMapObjectsLoaded()
    local existing = getElementsByType("object", resourceRoot)

    if #existing <= (#ATMConfig.Locations + 5) then
        local xml = xmlLoadFile("maps/fleeca_map.map")
        if xml then
            local children = xmlNodeGetChildren(xml)
            if children then
                for _, node in ipairs(children) do
                    if xmlNodeGetName(node) == "object" then
                        local attrs = xmlNodeGetAttributes(node)
                        local model = tonumber(attrs.model)
                        local px = tonumber(attrs.posX)
                        local py = tonumber(attrs.posY)
                        local pz = tonumber(attrs.posZ)
                        local rx = tonumber(attrs.rotX) or 0
                        local ry = tonumber(attrs.rotY) or 0
                        local rz = tonumber(attrs.rotZ) or 0
                        local interior = tonumber(attrs.interior) or 0
                        local dimension = tonumber(attrs.dimension) or 0
                        local scale = tonumber(attrs.scale) or 1
                        local collisions = (attrs.collisions ~= "false")
                        local breakable = (attrs.breakable == "true")
                        local doublesided = (attrs.doublesided == "true")

                        if model and px and py and pz then
                            local obj = createObject(model, px, py, pz, rx, ry, rz)
                            if obj then
                                setElementInterior(obj, interior)
                                setElementDimension(obj, dimension)
                                setObjectScale(obj, scale)
                                setElementCollisionsEnabled(obj, collisions)
                                setObjectBreakable(obj, breakable and (model ~= 4006))
                                setElementDoubleSided(obj, doublesided or (model == 4006))
                                setElementParent(obj, resourceRoot)
                                table.insert(mapObjects, obj)
                            end
                        end
                    end
                end
            end
            xmlUnloadFile(xml)
        end
    end
end

addEventHandler("onResourceStart", resourceRoot, function()
    removeWorldModel(4006, 500, 1394.36, -1620.66, 32.15, 0)
    removeWorldModel(4055, 500, 1394.36, -1620.66, 32.15, 0)
    for _, loc in ipairs(ATMConfig.Locations) do
        local obj = createObject(ATMConfig.ModelID, loc.x, loc.y, loc.z, 0, 0, loc.rz or 0)
        if obj then
            setElementFrozen(obj, true)
            setElementData(obj, "isATM", true)
            table.insert(atmObjects, obj)
        end
    end
    ensureMapObjectsLoaded()
end)

addEventHandler("onResourceStop", resourceRoot, function()
    restoreWorldModel(4006, 500, 1394.36, -1620.66, 32.15, 0)
    restoreWorldModel(4055, 500, 1394.36, -1620.66, 32.15, 0)
    for _, obj in ipairs(atmObjects) do
        if isElement(obj) then
            destroyElement(obj)
        end
    end
    atmObjects = {}
    for _, obj in ipairs(mapObjects) do
        if isElement(obj) then
            destroyElement(obj)
        end
    end
    mapObjects = {}
end)

local function getPlayerData(player)
    if not isElement(player) then return 0, 0, 0, "Bilinmiyor" end
    local charId = tonumber(getElementData(player, "character:id") or getElementData(player, "char:id")) or 0
    local charName = getElementData(player, "character:name") or getPlayerName(player)
    local cash = tonumber(getElementData(player, "character:money") or getElementData(player, "char:money") or getPlayerMoney(player)) or 0
    local bank = tonumber(getElementData(player, "character:bank") or getElementData(player, "char:bank_money") or getElementData(player, "char:bank")) or 0

    local cRes = getResourceFromName("gzl_characters")
    if cRes and getResourceState(cRes) == "running" then
        pcall(function()
            if exports.gzl_characters.getPlayerCash then
                local val = exports.gzl_characters:getPlayerCash(player)
                if val then cash = val end
            end
            if exports.gzl_characters.getPlayerBank then
                local val = exports.gzl_characters:getPlayerBank(player)
                if val then bank = val end
            end
        end)
    end

    return cash, bank, charId, charName
end

local function notifyPlayer(player, title, message, msgType)
    if exports.gzl_ui and exports.gzl_ui.showNotification then
        exports.gzl_ui:showNotification(player, title, message, msgType or "info")
    else
        outputChatBox("#38bdf8[" .. title .. "] #ffffff" .. message, player, 255, 255, 255, true)
    end
end

local function isPlayerNearATM(player)
    if not isElement(player) then return false end
    local px, py, pz = getElementPosition(player)
    local pDim = getElementDimension(player)
    local pInt = getElementInterior(player)

    for _, obj in ipairs(atmObjects) do
        if isElement(obj) and getElementDimension(obj) == pDim and getElementInterior(obj) == pInt then
            local ox, oy, oz = getElementPosition(obj)
            if getDistanceBetweenPoints3D(px, py, pz, ox, oy, oz) <= 5.0 then
                return true
            end
        end
    end

    if pDim == 0 and pInt == 0 then
        for _, loc in ipairs(ATMConfig.Locations or {}) do
            if getDistanceBetweenPoints3D(px, py, pz, loc.x, loc.y, loc.z) <= 5.0 then
                return true
            end
        end
    end
    return false
end

addEvent("atm:requestData", true)
addEventHandler("atm:requestData", root, function()
    if client then
        local ac = getResourceFromName("gzl_anticheat")
        if not ac or getResourceState(ac) ~= "running" or not exports.gzl_anticheat:allowEvent(client, "atm:requestData") then return end
    end
    local player = client or source
    if not isElement(player) then return end

    local cash, bank, charId, charName = getPlayerData(player)
    local db = getATMDB()

    if db and charId > 0 then
        local q = "SELECT * FROM atm_transactions WHERE char_id = ? ORDER BY id DESC LIMIT 10"
        dbQuery(function(qh)
            local result = dbPoll(qh, -1) or {}
            triggerClientEvent(player, "atm:receiveData", player, {
                cash = cash,
                bank = bank,
                charId = charId,
                charName = charName,
                transactions = result
            })
        end, db, q, charId)
    else
        triggerClientEvent(player, "atm:receiveData", player, {
            cash = cash,
            bank = bank,
            charId = charId,
            charName = charName,
            transactions = {}
        })
    end
end)

addEvent("atm:withdraw", true)
addEventHandler("atm:withdraw", root, function(amount)
    if client then
        local ac = getResourceFromName("gzl_anticheat")
        if not ac or getResourceState(ac) ~= "running" or not exports.gzl_anticheat:allowEvent(client, "atm:withdraw", amount) then return end
    end
    local player = client or source
    if not isElement(player) then return end

    if not isPlayerNearATM(player) then
        notifyPlayer(player, "ATM", "ATM'ye yeterince yakın değilsiniz!", "error")
        return
    end

    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then
        notifyPlayer(player, "ATM", "Geçersiz çekim tutarı!", "error")
        return
    end

    if amount > ATMConfig.MaxSingleTransaction then
        notifyPlayer(player, "ATM", "Tek seferde en fazla $" .. ATMConfig.MaxSingleTransaction .. " çekebilirsiniz!", "warning")
        return
    end

    local cash, bank, charId, charName = getPlayerData(player)
    if bank < amount then
        notifyPlayer(player, "ATM", "Banka hesabınızda yeterli bakiye bulunmuyor!", "error")
        return
    end

    local newBank = bank - amount
    local newCash = cash + amount

    local cRes = getResourceFromName("gzl_characters")
    local handled = false
    if cRes and getResourceState(cRes) == "running" then
        pcall(function()
            if exports.gzl_characters.setPlayerBank and exports.gzl_characters.setPlayerCash then
                exports.gzl_characters:setPlayerBank(player, newBank)
                exports.gzl_characters:setPlayerCash(player, newCash)
                handled = true
            end
        end)
    end

    if not handled then
        setElementData(player, "character:bank", newBank, "broadcast", "deny")
        setElementData(player, "char:bank_money", newBank)
        setElementData(player, "char:bank", newBank, "broadcast", "deny")
        setElementData(player, "character:money", newCash, "broadcast", "deny")
        setElementData(player, "char:money", newCash, "broadcast", "deny")
        setPlayerMoney(player, newCash)
    end

    if cRes and getResourceState(cRes) == "running" then
        pcall(function()
            if exports.gzl_characters.saveCharacter then
                exports.gzl_characters:saveCharacter(player)
            end
        end)
    end

    logATMTransaction(charId, charName, "withdraw", amount, newBank, "ATM Nakit Çekim")
    notifyPlayer(player, "ATM", "$" .. amount .. " nakit para çekildi.", "success")

    triggerEvent("atm:requestData", player)
end)

addEvent("atm:deposit", true)
addEventHandler("atm:deposit", root, function(amount)
    if client then
        local ac = getResourceFromName("gzl_anticheat")
        if not ac or getResourceState(ac) ~= "running" or not exports.gzl_anticheat:allowEvent(client, "atm:deposit", amount) then return end
    end
    local player = client or source
    if not isElement(player) then return end

    if not isPlayerNearATM(player) then
        notifyPlayer(player, "ATM", "ATM'ye yeterince yakın değilsiniz!", "error")
        return
    end

    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then
        notifyPlayer(player, "ATM", "Geçersiz yatırma tutarı!", "error")
        return
    end

    if amount > ATMConfig.MaxSingleTransaction then
        notifyPlayer(player, "ATM", "Tek seferde en fazla $" .. ATMConfig.MaxSingleTransaction .. " yatırabilirsiniz!", "warning")
        return
    end

    local cash, bank, charId, charName = getPlayerData(player)
    if cash < amount then
        notifyPlayer(player, "ATM", "Cüzdanınızda yeterli nakit bulunmuyor!", "error")
        return
    end

    local newBank = bank + amount
    local newCash = cash - amount

    local cRes = getResourceFromName("gzl_characters")
    local handled = false
    if cRes and getResourceState(cRes) == "running" then
        pcall(function()
            if exports.gzl_characters.setPlayerBank and exports.gzl_characters.setPlayerCash then
                exports.gzl_characters:setPlayerCash(player, newCash)
                exports.gzl_characters:setPlayerBank(player, newBank)
                handled = true
            end
        end)
    end

    if not handled then
        setElementData(player, "character:money", newCash, "broadcast", "deny")
        setElementData(player, "char:money", newCash, "broadcast", "deny")
        setPlayerMoney(player, newCash)
        setElementData(player, "character:bank", newBank, "broadcast", "deny")
        setElementData(player, "char:bank_money", newBank)
        setElementData(player, "char:bank", newBank, "broadcast", "deny")
    end

    if cRes and getResourceState(cRes) == "running" then
        pcall(function()
            if exports.gzl_characters.saveCharacter then
                exports.gzl_characters:saveCharacter(player)
            end
        end)
    end

    logATMTransaction(charId, charName, "deposit", amount, newBank, "ATM Nakit Yatırma")
    notifyPlayer(player, "ATM", "$" .. amount .. " banka hesabınıza yatırıldı.", "success")

    triggerEvent("atm:requestData", player)
end)

local function findTargetPlayer(query)
    if not query or query == "" then return nil end
    local numId = tonumber(query)

    if numId then
        for _, p in ipairs(getElementsByType("player")) do
            local cid = tonumber(getElementData(p, "character:id") or getElementData(p, "char:id"))
            if cid == numId then
                return p
            end
        end
    end

    local qLower = string.lower(tostring(query))
    for _, p in ipairs(getElementsByType("player")) do
        local pName = string.lower(getElementData(p, "character:name") or getPlayerName(p))
        if string.find(pName, qLower, 1, true) then
            return p
        end
    end

    return nil
end

addEvent("atm:transfer", true)
addEventHandler("atm:transfer", root, function(targetQuery, amount, note)
    if client then
        local ac = getResourceFromName("gzl_anticheat")
        if not ac or getResourceState(ac) ~= "running" or not exports.gzl_anticheat:allowEvent(client, "atm:transfer", targetQuery, amount, note) then return end
    end
    local player = client or source
    if not isElement(player) then return end

    if not isPlayerNearATM(player) then
        notifyPlayer(player, "ATM", "ATM'ye yeterince yakın değilsiniz!", "error")
        return
    end

    amount = math.floor(tonumber(amount) or 0)
    note = tostring(note or "Banka Havalesi")
    if amount <= 0 then
        notifyPlayer(player, "ATM", "Geçersiz havale tutarı!", "error")
        return
    end

    local cash, bank, charId, charName = getPlayerData(player)
    if bank < amount then
        notifyPlayer(player, "ATM", "Banka hesabınızda yeterli bakiye bulunmuyor!", "error")
        return
    end

    local targetPlayer = findTargetPlayer(targetQuery)

    if isElement(targetPlayer) then
        if targetPlayer == player then
            notifyPlayer(player, "ATM", "Kendi hesabınıza havale yapamazsınız!", "warning")
            return
        end

        local tCash, tBank, tCharId, tCharName = getPlayerData(targetPlayer)
        local newSenderBank = bank - amount
        local newReceiverBank = tBank + amount

        if exports.gzl_characters and exports.gzl_characters.setPlayerBank then
            exports.gzl_characters:setPlayerBank(player, newSenderBank)
            exports.gzl_characters:setPlayerBank(targetPlayer, newReceiverBank)
        else
            setElementData(player, "character:bank", newSenderBank, "broadcast", "deny")
            setElementData(player, "char:bank_money", newSenderBank)
            setElementData(player, "char:bank", newSenderBank, "broadcast", "deny")
            setElementData(targetPlayer, "character:bank", newReceiverBank, "broadcast", "deny")
            setElementData(targetPlayer, "char:bank_money", newReceiverBank)
            setElementData(targetPlayer, "char:bank", newReceiverBank, "broadcast", "deny")
        end

        if exports.gzl_characters and exports.gzl_characters.saveCharacter then
            exports.gzl_characters:saveCharacter(player)
            exports.gzl_characters:saveCharacter(targetPlayer)
        end

        logATMTransaction(charId, charName, "transfer_out", amount, newSenderBank, "Havale -> " .. tCharName .. " (" .. note .. ")")
        logATMTransaction(tCharId, tCharName, "transfer_in", amount, newReceiverBank, "Havale <- " .. charName .. " (" .. note .. ")")

        notifyPlayer(player, "ATM", tCharName .. " kişisine $" .. amount .. " havale gönderildi.", "success")
        notifyPlayer(targetPlayer, "ATM", charName .. " size $" .. amount .. " havale gönderdi (" .. note .. ").", "success")

        triggerEvent("atm:requestData", player)
    else
        local db = exports.gzl_characters and exports.gzl_characters.getCharacterDB and exports.gzl_characters:getCharacterDB()
        if not db then
            notifyPlayer(player, "ATM", "Alıcı bulunamadı!", "error")
            return
        end

        local numId = tonumber(targetQuery)
        local searchSQL = numId and "SELECT id, name, bank_money FROM characters WHERE id = ? LIMIT 1" or "SELECT id, name, bank_money FROM characters WHERE LOWER(name) = LOWER(?) LIMIT 1"
        local searchParam = numId and numId or tostring(targetQuery)

        dbQuery(function(qh)
            local res = dbPoll(qh, 0)
            if res and #res > 0 then
                local row = res[1]
                local tCharId = row.id
                local tCharName = row.name
                local tBank = tonumber(row.bank_money) or 0

                if tCharId == charId then
                    notifyPlayer(player, "ATM", "Kendi hesabınıza havale yapamazsınız!", "warning")
                    return
                end

                local newSenderBank = bank - amount
                local newReceiverBank = tBank + amount

                if exports.gzl_characters and exports.gzl_characters.setPlayerBank then
                    exports.gzl_characters:setPlayerBank(player, newSenderBank)
                else
                    setElementData(player, "character:bank", newSenderBank, "broadcast", "deny")
                    setElementData(player, "char:bank_money", newSenderBank)
                    setElementData(player, "char:bank", newSenderBank, "broadcast", "deny")
                end

                if exports.gzl_characters and exports.gzl_characters.saveCharacter then
                    exports.gzl_characters:saveCharacter(player)
                end

                dbExec(db, "UPDATE characters SET bank_money = ? WHERE id = ?", newReceiverBank, tCharId)

                logATMTransaction(charId, charName, "transfer_out", amount, newSenderBank, "Havale -> " .. tCharName .. " (" .. note .. ")")
                logATMTransaction(tCharId, tCharName, "transfer_in", amount, newReceiverBank, "Havale <- " .. charName .. " (" .. note .. ")")

                notifyPlayer(player, "ATM", tCharName .. " kişisine $" .. amount .. " havale gönderildi.", "success")
                triggerEvent("atm:requestData", player)
            else
                notifyPlayer(player, "ATM", "Belirtilen alıcı bulunamadı!", "error")
            end
        end, db, searchSQL, searchParam)
    end
end)