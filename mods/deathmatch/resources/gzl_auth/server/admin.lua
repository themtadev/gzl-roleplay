local sessions = {}

function getAdminLevel(player)
    if not isElement(player) then return 0 end
    local session = sessions[player]
    if session and session.level and session.level > 0 then
        return session.level
    end
    return tonumber(getElementData(player, "account:admin")) or 0
end

function setAdminLevel(player, level)
    if not isElement(player) then return false end
    level = math.max(0, math.min(10, math.floor(tonumber(level) or 0)))
    if not sessions[player] then
        sessions[player] = {
            username = getPlayerName(player),
            level = level
        }
    else
        sessions[player].level = level
    end
    setElementData(player, "account:admin", level, "broadcast", "deny")
    return true
end

function registerAdminSession(player, row)
    if not isElement(player) then return end
    sessions[player] = {
        username = row.username,
        level = math.max(0, math.min(10, math.floor(tonumber(row.admin_level) or 0)))
    }
    setElementData(player, "account:admin", sessions[player].level, "broadcast", "deny")
end

addEventHandler("onPlayerQuit", root, function() sessions[source] = nil end)
addEventHandler("onPlayerLogout", root, function()
    sessions[source] = nil
    setElementData(source, "account:admin", 0, "broadcast", "deny")
end)

local function findTargetPlayer(query)
    if not query or query == "" then return nil end
    local numId = tonumber(query)

    if numId then
        for _, p in ipairs(getElementsByType("player")) do
            local charId = tonumber(getElementData(p, "character:id") or getElementData(p, "char:id") or getElementData(p, "id"))
            if charId == numId then
                return p
            end
        end
        local all = getElementsByType("player")
        if all[numId] then
            return all[numId]
        end
    end

    local qLower = string.lower(query)
    for _, p in ipairs(getElementsByType("player")) do
        local pName = string.lower(getPlayerName(p))
        if pName == qLower or string.find(pName, qLower, 1, true) then
            return p
        end
    end

    for _, p in ipairs(getElementsByType("player")) do
        local accUser = getElementData(p, "account:username")
        if accUser and string.lower(accUser) == qLower then
            return p
        end
    end

    return nil
end

local function handleSetAdminCommand(actor, _, targetQuery, levelInput)
    local isPlayerCaller = isElement(actor) and getElementType(actor) == "player"
    if isPlayerCaller then
        local actorLevel = getAdminLevel(actor)
        if actorLevel < 8 then
            outputChatBox("#ef4444[GZL-ADMIN]#ffffff Bu komutu kullanmak için yetkiniz bulunmamaktadır!", actor, 255, 255, 255, true)
            return
        end
    end

    local level = tonumber(levelInput)
    if not targetQuery or not level or level ~= math.floor(level) or level < 0 or level > 10 then
        local usageMsg = "Kullanim: setadmin <oyuncu_id / oyuncu_nick / hesap_adi> <0-10>"
        if isPlayerCaller then
            outputChatBox("#38bdf8[GZL-ADMIN]#ffffff " .. usageMsg, actor, 255, 255, 255, true)
        else
            outputServerLog("[GZL-ADMIN] " .. usageMsg)
        end
        return
    end

    local db = getDatabase()
    local onlineTarget = findTargetPlayer(targetQuery)

    if onlineTarget then
        local pName = getPlayerName(onlineTarget)
        sessions[onlineTarget] = sessions[onlineTarget] or { username = pName }
        sessions[onlineTarget].level = level
        setElementData(onlineTarget, "account:admin", level, true)
        setElementData(onlineTarget, "admin_level", level, true)

        local accId = getElementData(onlineTarget, "account:id")
        if accId and db then
            dbExec(db, "UPDATE accounts SET admin_level = ? WHERE id = ?", level, accId)
        end

        local successMsg = string.format("'%s' adli online oyuncuya Seviye %d admin yetkisi verildi.", pName, level)
        if isPlayerCaller then
            outputChatBox("#00f5a0[GZL-ADMIN]#ffffff " .. successMsg, actor, 255, 255, 255, true)
        else
            outputServerLog("[GZL-ADMIN] BASARILI: " .. successMsg)
        end
        outputChatBox(string.format("#00f5a0[GZL-ADMIN]#ffffff Size Seviye %d admin yetkisi verildi.", level), onlineTarget, 255, 255, 255, true)
        return
    end

    if not db then
        local dbErr = "HATA: Veritabani baglantisi aktif degil!"
        if isPlayerCaller then
            outputChatBox("#ef4444[GZL-ADMIN]#ffffff " .. dbErr, actor, 255, 255, 255, true)
        else
            outputServerLog("[GZL-ADMIN] " .. dbErr)
        end
        return
    end

    dbQuery(function(handle)
        local rows = dbPoll(handle, 0)
        if not rows or #rows ~= 1 then
            local notFound = string.format("'%s' adinda ne online oyuncu ne de kayitli hesap bulunamadi! Oyuncu oyundaysa nick/id yazin veya kayit olmasini bekleyin.", tostring(targetQuery))
            if isPlayerCaller then
                outputChatBox("#ef4444[GZL-ADMIN]#ffffff " .. notFound, actor, 255, 255, 255, true)
            else
                outputServerLog("[GZL-ADMIN] " .. notFound)
            end
            return
        end

        local row = rows[1]
        dbExec(db, "UPDATE accounts SET admin_level = ? WHERE id = ?", level, row.id)
        local okMsg = string.format("'%s' adli hesaba Seviye %d admin yetkisi tanimlandi (Veritabanina kaydedildi).", row.username, level)
        if isPlayerCaller then
            outputChatBox("#00f5a0[GZL-ADMIN]#ffffff " .. okMsg, actor, 255, 255, 255, true)
        else
            outputServerLog("[GZL-ADMIN] BASARILI: " .. okMsg)
        end
    end, db, "SELECT id, username, admin_level FROM accounts WHERE LOWER(username) = LOWER(?)", targetQuery)
end

addCommandHandler("setadmin", handleSetAdminCommand)
addCommandHandler("accountadmin", handleSetAdminCommand)
addCommandHandler("makeadmin", handleSetAdminCommand)