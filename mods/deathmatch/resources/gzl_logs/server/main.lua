local function trustedAdminLevel(player)
    local auth = getResourceFromName("gzl_auth")
    if not isElement(player) or not auth or getResourceState(auth) ~= "running" then return 0 end
    return exports.gzl_auth:getAdminLevel(player)
end

local function resolveEntity(entity)
    if not entity then return nil, "N/A" end
    if isElement(entity) and getElementType(entity) == "player" then
        local cid = tonumber(getElementData(entity, "character:id") or getElementData(entity, "char:id"))
        local cname = getElementData(entity, "character:name") or getElementData(entity, "char:name") or getPlayerName(entity)
        return cid, cname
    elseif type(entity) == "number" then
        return entity, "Char#" .. tostring(entity)
    elseif type(entity) == "string" then
        local num = tonumber(entity)
        if num then
            return num, "Char#" .. tostring(num)
        end
        return nil, entity
    elseif type(entity) == "table" then
        return tonumber(entity.id), entity.name or "N/A"
    end
    return nil, tostring(entity)
end

local function getAdminLevel(player)
    if not isElement(player) then return 0 end
    return trustedAdminLevel(player)
end

function logAdmin(playerOrId, command, targetOrId, details)
    local db = getLogsDB()
    if not db then return false end

    local pId, pName = resolveEntity(playerOrId)
    local tId, tName = resolveEntity(targetOrId)
    local adminLvl = isElement(playerOrId) and getAdminLevel(playerOrId) or 0
    local cmd = tostring(command or "UNKNOWN")
    local det = details and tostring(details) or ""

    local query = "INSERT INTO log_admin (player_id, player_name, admin_level, command, target_id, target_name, details) VALUES (?, ?, ?, ?, ?, ?, ?)"
    return dbExec(db, query, pId, pName, adminLvl, cmd, tId, tName, det)
end

function logMoney(sender, receiver, amount, transType, reason)
    local db = getLogsDB()
    if not db then return false end

    local sId, sName = resolveEntity(sender)
    local rId, rName = resolveEntity(receiver)
    local amt = math.floor(tonumber(amount) or 0)
    local tType = tostring(transType or "cash")
    local rsn = reason and tostring(reason) or ""

    local query = "INSERT INTO log_money (sender_id, sender_name, receiver_id, receiver_name, amount, trans_type, reason) VALUES (?, ?, ?, ?, ?, ?, ?)"
    return dbExec(db, query, sId, sName, rId, rName, amt, tType, rsn)
end

function logItem(player, action, itemName, count, target, details)
    local db = getLogsDB()
    if not db then return false end

    local pId, pName = resolveEntity(player)
    local tId, tName = resolveEntity(target)
    local act = tostring(action or "move")
    local itm = tostring(itemName or "item")
    local cnt = math.floor(tonumber(count) or 1)
    local det = details and tostring(details) or ""

    local query = "INSERT INTO log_items (player_id, player_name, action, item_name, item_count, target_id, target_name, details) VALUES (?, ?, ?, ?, ?, ?, ?, ?)"
    return dbExec(db, query, pId, pName, act, itm, cnt, tId, tName, det)
end

function logCombat(victim, killer, weapon, bodypart, distance, isCombatLog, details)
    local db = getLogsDB()
    if not db then return false end

    local vId, vName = resolveEntity(victim)
    local kId, kName = resolveEntity(killer)
    local wepId = (weapon ~= nil) and tonumber(weapon) or nil
    local wepName = "N/A"
    if wepId ~= nil then
        wepName = getWeaponNameFromID(wepId) or (wepId == 0 and "Fist" or ("Weapon#" .. tostring(wepId)))
    elseif isCombatLog == 1 or isCombatLog == true then
        wepName = "Combat Log"
    end
    local bp = tonumber(bodypart) or 3
    local dist = tonumber(distance) or 0.0
    local cLog = (isCombatLog == true or isCombatLog == 1) and 1 or 0
    local det = details and tostring(details) or ""

    local query = "INSERT INTO log_combat (victim_id, victim_name, killer_id, killer_name, weapon_id, weapon_name, bodypart, distance, is_combat_log, details) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
    return dbExec(db, query, vId, vName, kId, kName, wepId, wepName, bp, dist, cLog, det)
end

function logSession(playerOrAccount, eventType, details)
    local db = getLogsDB()
    if not db then return false end

    local accountId = nil
    local charId = nil
    local pName = "N/A"
    local serial = "N/A"
    local ip = "N/A"

    if isElement(playerOrAccount) and getElementType(playerOrAccount) == "player" then
        local p = playerOrAccount
        accountId = tonumber(getElementData(p, "account:id"))
        charId = tonumber(getElementData(p, "character:id") or getElementData(p, "char:id"))
        pName = getElementData(p, "character:name") or getElementData(p, "char:name") or getPlayerName(p)
        serial = getPlayerSerial(p) or "N/A"
        ip = getPlayerIP(p) or "N/A"
    elseif type(playerOrAccount) == "table" then
        accountId = tonumber(playerOrAccount.accountId)
        charId = tonumber(playerOrAccount.characterId)
        pName = tostring(playerOrAccount.name or "N/A")
        serial = tostring(playerOrAccount.serial or "N/A")
        ip = tostring(playerOrAccount.ip or "N/A")
    end

    local eType = tostring(eventType or "event")
    local det = details and tostring(details) or ""

    local query = "INSERT INTO log_sessions (account_id, character_id, player_name, serial, ip, event_type, details) VALUES (?, ?, ?, ?, ?, ?, ?)"
    return dbExec(db, query, accountId, charId, pName, serial, ip, eType, det)
end

function logSystem(category, level, message, sourceResource)
    local db = getLogsDB()
    if not db then return false end

    local cat = tostring(category or "SYSTEM")
    local lvl = tostring(level or "INFO")
    local msg = tostring(message or "")
    local src = sourceResource and tostring(sourceResource) or (sourceResourceRoot and getResourceName(sourceResourceRoot) or "gzl_logs")

    local query = "INSERT INTO log_system (category, level, message, source_resource) VALUES (?, ?, ?, ?)"
    return dbExec(db, query, cat, lvl, msg, src)
end

function queryLogs(tableType, filters, limit, callback)
    local db = getLogsDB()
    if not db or type(callback) ~= "function" then return false end

    tableType = tostring(tableType):lower()
    local validTables = {
        admin = "log_admin",
        money = "log_money",
        items = "log_items",
        combat = "log_combat",
        sessions = "log_sessions",
        system = "log_system"
    }

    local tableName = validTables[tableType]
    if not tableName then
        callback(false, "Invalid log category")
        return false
    end

    limit = math.min(LogsConfig.MaxQueryLimit or 200, math.max(1, tonumber(limit) or (LogsConfig.DefaultQueryLimit or 50)))

    local whereClauses = {}
    local params = {}

    if type(filters) == "table" then
        for k, v in pairs(filters) do
            if type(k) == "string" and not string.find(k, "[^%w_]") then
                table.insert(whereClauses, k .. " = ?")
                table.insert(params, v)
            end
        end
    end

    local queryStr = "SELECT * FROM " .. tableName
    if #whereClauses > 0 then
        queryStr = queryStr .. " WHERE " .. table.concat(whereClauses, " AND ")
    end
    queryStr = queryStr .. " ORDER BY id DESC LIMIT " .. tostring(limit)

    local function onQueryResult(qh)
        local results = dbPoll(qh, 0)
        callback(results or {})
    end

    if #params > 0 then
        dbQuery(onQueryResult, db, queryStr, unpack(params))
    else
        dbQuery(onQueryResult, db, queryStr)
    end

    return true
end

addEventHandler("onPlayerWasted", root, function(ammo, killer, weapon, bodypart)
    local victim = source
    if not isElement(victim) then return end

    local dist = 0.0
    if isElement(killer) and getElementType(killer) == "player" then
        local vx, vy, vz = getElementPosition(victim)
        local kx, ky, kz = getElementPosition(killer)
        dist = getDistanceBetweenPoints3D(vx, vy, vz, kx, ky, kz)
    end

    logCombat(victim, killer, weapon, bodypart, dist, 0, "onPlayerWasted event")
end)

addEventHandler("onPlayerQuit", root, function(quitType, reason, responsibleElement)
    local player = source
    if not isElement(player) then return end

    local isComa = (getElementData(player, "ems:isDead") == true or getElementData(player, "character:is_dead") == 1)
    local isCuffed = (getElementData(player, "isCuffed") == true or getElementData(player, "cuffed") == true)

    if isComa or isCuffed then
        local reasonText
        if isComa and isCuffed then
            reasonText = "Oyuncu hem kelepçeli hem de koma/ağır yaralı durumdayken sunucudan ayrıldı!"
        elseif isComa then
            reasonText = "Oyuncu koma/ağır yaralı durumdayken sunucudan ayrıldı!"
        else
            reasonText = "Oyuncu kelepçeliyken sunucudan ayrıldı!"
        end
        logCombat(player, nil, nil, nil, 0, 1, string.format("[COMBAT LOG] %s (QuitType: %s, Reason: %s)", reasonText, tostring(quitType), tostring(reason or "none")))
    end

    local sessionEventType = (isComa or isCuffed) and "combat_log_quit" or "quit"
    logSession(player, sessionEventType, string.format("QuitType: %s, Reason: %s", tostring(quitType), tostring(reason or "none")))
end)

addEvent("gzl:onPlayerAccountLogin", false)
addEventHandler("gzl:onPlayerAccountLogin", root, function(accountData)
    local player = source
    if not isElement(player) then return end
    local uName = accountData and accountData.username or "N/A"
    local accId = accountData and accountData.id or getElementData(player, "account:id") or "N/A"
    logSession(player, "account_login", string.format("Kullanıcı Adı: %s, Hesap ID: %s", tostring(uName), tostring(accId)))
end)

addEvent("char:spawnSuccess", true)
addEventHandler("char:spawnSuccess", root, function(charData)
    local player = client or source
    if not isElement(player) then return end
    local charName = tostring(charData and charData.name or getElementData(player, "character:name") or getPlayerName(player))
    local charId = tostring(charData and charData.id or getElementData(player, "character:id") or "N/A")
    logSession(player, "character_select", string.format("Karakter Seçildi: %s (ID: %s)", charName, charId))
end)

addCommandHandler("checklogs", function(player, cmd, category, limit)
    if not isElement(player) then return end
    if getAdminLevel(player) < 2 then
        outputChatBox("#ef4444[GZL-LOGS]#ffffff Bu komutu kullanmak için yetkiniz bulunmamaktadır!", player, 255, 255, 255, true)
        return
    end

    category = category and string.lower(category) or "admin"
    limit = tonumber(limit) or 10

    outputChatBox(string.format("#38bdf8[GZL-LOGS]#ffffff Son #34d399%d#ffffff kayıt sorgulanıyor: #e2e8f0%s#ffffff...", limit, category), player, 255, 255, 255, true)

    queryLogs(category, {}, limit, function(results)
        if not isElement(player) then return end
        if not results or #results == 0 then
            outputChatBox("#f59e0b[GZL-LOGS]#ffffff Hiçbir kayıt bulunamadı.", player, 255, 255, 255, true)
            return
        end

        outputChatBox(string.format("#38bdf8[GZL-LOGS] === %s Kayıtları (%d adet) ===", string.upper(category), #results), player, 255, 255, 255, true)
        for i, row in ipairs(results) do
            if category == "money" then
                outputChatBox(string.format("#e2e8f0[%s]#ffffff %s -> %s: #34d399$%d#ffffff (%s) - %s", row.created_at or "", row.sender_name or "?", row.receiver_name or "?", row.amount or 0, row.trans_type or "", row.reason or ""), player, 255, 255, 255, true)
            elseif category == "combat" then
                outputChatBox(string.format("#e2e8f0[%s]#ffffff Kurban: #ef4444%s#ffffff | Katil: #38bdf8%s#ffffff | Silah: %s | C-Log: %s | %s", row.created_at or "", row.victim_name or "?", row.killer_name or "N/A", row.weapon_name or "?", (row.is_combat_log == 1 and "#ef4444EVET" or "#34d399HAYIR"), row.details or ""), player, 255, 255, 255, true)
            elseif category == "items" then
                outputChatBox(string.format("#e2e8f0[%s]#ffffff %s: #38bdf8%s#ffffff (x%d) -> Hedef: %s (%s)", row.created_at or "", row.action or "", row.item_name or "", row.item_count or 1, row.target_name or "Yok", row.player_name or "?"), player, 255, 255, 255, true)
            elseif category == "admin" then
                outputChatBox(string.format("#e2e8f0[%s]#ffffff %s (Lvl %d) -> #38bdf8/%s#ffffff Hedef: %s - %s", row.created_at or "", row.player_name or "?", row.admin_level or 0, row.command or "", row.target_name or "-", row.details or ""), player, 255, 255, 255, true)
            else
                outputChatBox(string.format("#e2e8f0[%s]#ffffff %s", row.created_at or "", row.details or row.message or "Kayıt"), player, 255, 255, 255, true)
            end
        end
    end)
end)