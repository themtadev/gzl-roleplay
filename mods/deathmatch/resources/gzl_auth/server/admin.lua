local sessions = {}

function getAdminLevel(player)
    local session = sessions[player]
    return session and session.level or 0
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

addCommandHandler("accountadmin", function(actor, _, username, level)
    if isElement(actor) then return end
    level = tonumber(level)
    if not username or not level or level ~= math.floor(level) or level < 0 or level > 10 then
        outputServerLog("Usage: accountadmin <account username> <0-10>")
        return
    end
    local db = getDatabase()
    if not db then return end
    dbQuery(function(handle)
        local rows = dbPoll(handle, 0)
        if not rows or #rows ~= 1 then
            outputServerLog("[ADMIN] Account not found or ambiguous.")
            return
        end
        local row = rows[1]
        dbQuery(function(updateHandle)
            local result, affected = dbPoll(updateHandle, 0)
            if not result or affected ~= 1 then
                outputServerLog("[ADMIN] Database update failed; permissions unchanged.")
                return
            end
            for player, session in pairs(sessions) do
                if session.username == row.username then
                    session.level = level
                    setElementData(player, "account:admin", level, "broadcast", "deny")
                end
            end
            outputServerLog(string.format("[ADMIN] CONSOLE account=%s level=%s -> %d", row.username, tostring(row.admin_level), level))
        end, db, "UPDATE accounts SET admin_level = ? WHERE id = ?", level, row.id)
    end, db, "SELECT id, username, admin_level FROM accounts WHERE LOWER(username) = LOWER(?)", username)
end)