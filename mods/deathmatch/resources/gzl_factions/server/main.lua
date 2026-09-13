Factions = {}
PlayerFactions = {}
CharacterFactions = {}
PendingFactionInvites = {}

local function countTable(t)
    local c = 0
    for _ in pairs(t or {}) do c = c + 1 end
    return c
end

local function initDefaultFactions()
    for fId, fData in pairs(FactionConfig.DefaultFactions or {}) do
        Factions[fId] = {
            id = fData.id,
            name = fData.name,
            short_name = fData.short_name,
            faction_type = fData.faction_type,
            vault_balance = tonumber(fData.vault_balance) or 0,
            max_members = tonumber(fData.max_members) or 50,
            ranks = {}
        }
        for rId, rData in pairs(fData.ranks or {}) do
            Factions[fId].ranks[rId] = {
                name = rData.name,
                salary = tonumber(rData.salary) or 500,
                permissions = {}
            }
        end
    end
end
initDefaultFactions()

function loadAllFactionsFromDB()
    local db = getFactionDB()
    if not db then return end

    dbQuery(function(fQh)
        local fRows = dbPoll(fQh, 0)
        if not fRows then return end

        dbQuery(function(rQh)
            local rRows = dbPoll(rQh, 0) or {}
            local ranksByFaction = {}
            for _, r in ipairs(rRows) do
                local fId = tonumber(r.faction_id)
                ranksByFaction[fId] = ranksByFaction[fId] or {}
                ranksByFaction[fId][tonumber(r.rank_id)] = {
                    name = r.name,
                    salary = tonumber(r.salary) or 500,
                    permissions = fromJSON(r.permissions or "{}") or {}
                }
            end

            Factions = {}
            for _, f in ipairs(fRows) do
                local id = tonumber(f.id)
                Factions[id] = {
                    id = id,
                    name = f.name,
                    short_name = f.short_name,
                    faction_type = f.faction_type,
                    vault_balance = tonumber(f.vault_balance) or 0,
                    max_members = tonumber(f.max_members) or 50,
                    ranks = ranksByFaction[id] or {}
                }
            end

            outputServerLog(string.format("[gzl_factions] Toplam %d birlik belleğe yüklendi.", countTable(Factions)))

            for _, p in ipairs(getElementsByType("player")) do
                if getElementData(p, "loggedin_character") then
                    loadPlayerFaction(p)
                end
            end
        end, db, "SELECT * FROM faction_ranks ORDER BY rank_id ASC")
    end, db, "SELECT * FROM factions ORDER BY id ASC")
end

function getPlayerCharacterId(player)
    if not isElement(player) then return nil end
    return tonumber(getElementData(player, "character:id") or getElementData(player, "char:id"))
end

function loadPlayerFaction(player)
    if not isElement(player) then return end
    local charId = getPlayerCharacterId(player)
    if not charId then
        PlayerFactions[player] = nil
        clearPlayerFactionData(player)
        return
    end

    local db = getFactionDB()
    if not db then return end

    dbQuery(function(qh)
        local rows = dbPoll(qh, 0)
        if not isElement(player) then return end

        if rows and #rows > 0 then
            local row = rows[1]
            local fId = tonumber(row.faction_id)
            local rId = tonumber(row.rank_id) or 1
            local duty = tonumber(row.duty_status) or 0

            PlayerFactions[player] = {
                character_id = charId,
                faction_id = fId,
                rank_id = rId,
                duty_status = duty
            }
            CharacterFactions[charId] = PlayerFactions[player]
            syncPlayerFaction(player)

            local charName = getElementData(player, "character:name") or getElementData(player, "char:name") or getPlayerName(player):gsub("#%x%x%x%x%x%x", "")
            if charName and charName ~= "" then
                dbExec(db, "UPDATE faction_members SET character_name = ? WHERE character_id = ?", charName, charId)
            end
        else
            PlayerFactions[player] = nil
            CharacterFactions[charId] = nil
            clearPlayerFactionData(player)
        end
    end, db, "SELECT * FROM faction_members WHERE character_id = ?", charId)
end

function clearPlayerFactionData(player)
    if not isElement(player) then return end
    setElementData(player, "character:faction", nil)
    setElementData(player, "faction", nil)
    setElementData(player, "faction:id", nil)
    setElementData(player, "faction:name", nil)
    setElementData(player, "faction:short", nil)
    setElementData(player, "faction:type", nil)
    setElementData(player, "faction:rank", nil)
    setElementData(player, "faction:rank_name", nil)
    setElementData(player, "faction:duty", false)
    setElementData(player, "duty:police", false)
    setElementData(player, "duty:ems", false)
    setElementData(player, "duty:gov", false)
    setElementData(player, "duty", false)
    local curJob = getElementData(player, "char:job")
    if curJob == "police" or curJob == "ems" or curJob == "gov" then
        setElementData(player, "char:job", "civilian")
    end
end

function syncPlayerFaction(player)
    if not isElement(player) then return end
    local data = PlayerFactions[player]
    if not data then
        clearPlayerFactionData(player)
        return
    end

    local fId = data.faction_id
    local fData = Factions[fId]
    if not fData then return end

    local rankInfo = fData.ranks and fData.ranks[data.rank_id]
    local rankName = rankInfo and rankInfo.name or ("Derece " .. tostring(data.rank_id))
    local onDuty = (data.duty_status == 1)

    setElementData(player, "character:faction", fId)
    setElementData(player, "faction", fId)
    setElementData(player, "faction:id", fId)
    setElementData(player, "faction:name", fData.name)
    setElementData(player, "faction:short", fData.short_name)
    setElementData(player, "faction:type", fData.faction_type)
    setElementData(player, "faction:rank", data.rank_id)
    setElementData(player, "faction:rank_name", rankName)
    setElementData(player, "faction:duty", onDuty)

    setElementData(player, "duty:police", false)
    setElementData(player, "duty:ems", false)
    setElementData(player, "duty:gov", false)

    if fData.faction_type == "police" then
        setElementData(player, "duty:police", onDuty)
        setElementData(player, "duty", onDuty and "police" or false)
        setElementData(player, "char:job", onDuty and "police" or "civilian")
    elseif fData.faction_type == "ems" then
        setElementData(player, "duty:ems", onDuty)
        setElementData(player, "duty", onDuty and "ems" or false)
        setElementData(player, "char:job", onDuty and "ems" or "civilian")
        setElementData(player, "job", onDuty and "ems" or "civilian")
    elseif fData.faction_type == "gov" then
        setElementData(player, "duty:gov", onDuty)
        setElementData(player, "duty", onDuty and "gov" or false)
        setElementData(player, "char:job", onDuty and "gov" or "civilian")
    end
end

addEvent("char:spawnSuccess", true)
addEventHandler("char:spawnSuccess", root, function()
    local player = client or source
    if isElement(player) then
        loadPlayerFaction(player)
    end
end)

addEventHandler("onPlayerQuit", root, function()
    PlayerFactions[source] = nil
end)