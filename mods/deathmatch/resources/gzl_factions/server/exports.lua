function getPlayerFaction(player)
    if not isElement(player) then return nil end
    local pData = PlayerFactions[player]
    return pData and pData.faction_id or nil
end

function getPlayerFactionData(player)
    if not isElement(player) then return nil end
    local pData = PlayerFactions[player]
    if not pData then return nil end

    local fId = pData.faction_id
    local fData = Factions[fId]
    if not fData then return nil end

    local rankInfo = fData.ranks and fData.ranks[pData.rank_id]
    local rankName = rankInfo and rankInfo.name or ("Derece " .. tostring(pData.rank_id))

    return {
        id = fId,
        name = fData.name,
        short_name = fData.short_name,
        type = fData.faction_type,
        rank = pData.rank_id,
        rank_name = rankName,
        duty = (pData.duty_status == 1)
    }
end

function isPlayerInFaction(player, factionIdOrType)
    if not isElement(player) or not factionIdOrType then return false end
    local pData = PlayerFactions[player]
    if not pData then return false end

    local fId = pData.faction_id
    if type(factionIdOrType) == "number" or tonumber(factionIdOrType) then
        return fId == tonumber(factionIdOrType)
    end

    local fData = Factions[fId]
    if fData then
        local query = string.lower(tostring(factionIdOrType))
        if fData.faction_type and string.lower(fData.faction_type) == query then
            return true
        end
        if fData.short_name and string.lower(fData.short_name) == query then
            return true
        end
        if fData.name and string.lower(fData.name) == query then
            return true
        end
    end

    return false
end

function isPlayerOnDuty(player, factionType)
    if not isElement(player) then return false end
    local pData = PlayerFactions[player]
    if not pData or pData.duty_status ~= 1 then return false end

    if not factionType then
        return true
    end

    return isPlayerInFaction(player, factionType)
end

function getPlayerFactionRank(player)
    if not isElement(player) then return nil, nil end
    local pData = PlayerFactions[player]
    if not pData then return nil, nil end

    local fData = Factions[pData.faction_id]
    local rankInfo = fData and fData.ranks and fData.ranks[pData.rank_id]
    local rankName = rankInfo and rankInfo.name or ("Derece " .. tostring(pData.rank_id))

    return pData.rank_id, rankName
end

function setPlayerDuty(player, state)
    if not isElement(player) then return false end
    local pData = PlayerFactions[player]
    if not pData then return false end

    local dutyVal = (state == true or state == 1) and 1 or 0
    pData.duty_status = dutyVal

    local db = getFactionDB()
    if db then
        dbExec(db, "UPDATE faction_members SET duty_status = ? WHERE character_id = ?", dutyVal, pData.character_id)
    end

    syncPlayerFaction(player)
    return true
end

function setPlayerFaction(player, factionId, rankId)
    if not isElement(player) then return false end
    factionId = tonumber(factionId)
    rankId = tonumber(rankId) or 1
    if not factionId or not Factions[factionId] then return false end

    local charId = getPlayerCharacterId(player)
    if not charId then return false end

    local db = getFactionDB()
    if db then
        dbExec(db, "INSERT OR REPLACE INTO faction_members (character_id, faction_id, rank_id, duty_status) VALUES (?, ?, ?, 0)", charId, factionId, rankId)
    end

    PlayerFactions[player] = {
        character_id = charId,
        faction_id = factionId,
        rank_id = rankId,
        duty_status = 0
    }
    CharacterFactions[charId] = PlayerFactions[player]
    syncPlayerFaction(player)
    return true
end

function removePlayerFaction(player)
    if not isElement(player) then return false end
    local pData = PlayerFactions[player]
    if not pData then return false end

    local charId = pData.character_id
    local db = getFactionDB()
    if db then
        dbExec(db, "DELETE FROM faction_members WHERE character_id = ?", charId)
    end

    PlayerFactions[player] = nil
    CharacterFactions[charId] = nil
    clearPlayerFactionData(player)
    return true
end

function getFactionMembers(factionId)
    factionId = tonumber(factionId)
    local members = {}
    for p, data in pairs(PlayerFactions) do
        if isElement(p) and data.faction_id == factionId then
            table.insert(members, {
                element = p,
                character_id = data.character_id,
                rank_id = data.rank_id,
                duty = (data.duty_status == 1)
            })
        end
    end
    return members
end

function getFactions()
    return Factions or {}
end