local function trustedAdminLevel(player)
    local auth = getResourceFromName("gzl_auth")
    if not isElement(player) or not auth or getResourceState(auth) ~= "running" then return 0 end
    return exports.gzl_auth:getAdminLevel(player)
end

local database
local databaseReady = false
local channels = {}
local playerChannels = {}
local lastRequests = {}

local function trim(value)
    return tostring(value or ""):match("^%s*(.-)%s*$")
end

local function normalizeFrequency(value)
    local number = tonumber(trim(value))
    if not number or number ~= number then return nil end
    if number < RadioConfig.MinimumFrequency or number > RadioConfig.MaximumFrequency then return nil end
    return string.format("%.1f", math.floor(number * 10 + 0.5) / 10)
end

local function normalizePassword(value)
    local password = trim(value)
    if password == "" then return nil end
    local length = utf8.len(password)
    if not length or length > RadioConfig.MaximumPasswordLength then return false end
    return password
end

local function getPlayerKey(player)
    local characterId = tonumber(getElementData(player, "character:id") or getElementData(player, "char:id"))
    if characterId then return "character:" .. tostring(characterId) end
    local account = getPlayerAccount(player)
    if account and not isGuestAccount(account) then
        return "account:" .. getAccountName(account)
    end
    return "serial:" .. getPlayerSerial(player)
end

local function getMemberId(player)
    return tostring(getElementData(player, "character:id") or getElementData(player, "char:id") or getPlayerSerial(player))
end

local function getMemberName(player)
    local name = getElementData(player, "character:name") or getElementData(player, "char:name") or getPlayerName(player)
    return tostring(name):gsub("_", " ")
end

local function getJob(player)
    if exports.gzl_factions and exports.gzl_factions.getPlayerFactionData then
        local ok, data = pcall(exports.gzl_factions.getPlayerFactionData, exports.gzl_factions, player)
        if ok and data and data.type and data.duty then
            return string.lower(data.type)
        end
    end
    local job = getElementData(player, "char:job") or getElementData(player, "job") or getElementData(player, "character:faction") or getElementData(player, "faction")
    return string.lower(tostring(job or "civilian"))
end

local function hasRadio(player)
    local inventoryResource = getResourceFromName("gzl_inventory")
    if not inventoryResource or getResourceState(inventoryResource) ~= "running" then return false end
    if not exports.gzl_inventory or not exports.gzl_inventory.hasItem then return false end
    local success, result = pcall(function()
        return exports.gzl_inventory:hasItem(player, RadioConfig.ItemName, 1)
    end)
    return success and result == true
end

local function respond(player, requestId, data)
    if isElement(player) then
        triggerClientEvent(player, "gzl_radio:response", resourceRoot, requestId, data)
    end
end

local function notify(player, message, notificationType)
    if isElement(player) then
        triggerClientEvent(player, "gzl_radio:notify", resourceRoot, message, notificationType or "info")
    end
end

local function collectMembers(frequency)
    local result = {}
    local channel = channels[frequency]
    if not channel then return result end
    for player in pairs(channel.members) do
        if isElement(player) then
            result[#result + 1] = {
                id = getMemberId(player),
                name = getMemberName(player)
            }
        end
    end
    table.sort(result, function(a, b)
        return a.name < b.name
    end)
    return result
end

local function getChannelPlayers(frequency)
    local result = {}
    local channel = channels[frequency]
    if not channel then return result end
    for player in pairs(channel.members) do
        if isElement(player) then
            result[#result + 1] = player
        end
    end
    return result
end

local function updateVoiceRouting(frequency)
    local players = getChannelPlayers(frequency)
    for _, speaker in ipairs(players) do
        local recipients = {}
        for _, listener in ipairs(players) do
            if listener ~= speaker then
                recipients[#recipients + 1] = listener
            end
        end
        setPlayerVoiceBroadcastTo(speaker, recipients)
    end
end

local function broadcastState(frequency)
    local players = getChannelPlayers(frequency)
    if #players == 0 then return end
    triggerClientEvent(players, "gzl_radio:state", resourceRoot, {
        frequency = frequency,
        members = collectMembers(frequency)
    })
end

local function leaveChannel(player, forced)
    local frequency = playerChannels[player]
    if not frequency then return false end
    local channel = channels[frequency]
    playerChannels[player] = nil
    if channel then
        channel.members[player] = nil
    end
    if isElement(player) then
        setPlayerVoiceBroadcastTo(player, root)
        setElementData(player, "radio:channel", false, false)
    end
    updateVoiceRouting(frequency)
    broadcastState(frequency)
    if forced and isElement(player) then
        triggerClientEvent(player, "gzl_radio:forceKick", resourceRoot)
    end
    return true
end

local function joinChannel(player, frequency)
    if playerChannels[player] == frequency then
        return true
    end
    leaveChannel(player, false)
    local channel = channels[frequency]
    if not channel then return false end
    channel.members[player] = true
    playerChannels[player] = frequency
    setElementData(player, "radio:channel", frequency, false)
    updateVoiceRouting(frequency)
    broadcastState(frequency)
    return true
end

local function isChannelAllowed(player, frequency)
    local jobs = RadioConfig.RestrictedChannels[frequency]
    if not jobs then return true end

    if exports and exports.gzl_factions then
        if exports.gzl_factions.getPlayerFactionData then
            local ok, fData = pcall(function() return exports.gzl_factions:getPlayerFactionData(player) end)
            if ok and fData then
                local fType = fData.type and string.lower(fData.type)
                local fId = fData.id and tostring(fData.id)
                if (fType and jobs[fType] == true) or (fId and jobs[fId] == true) then
                    return true
                end
            end
        end
        if exports.gzl_factions.isPlayerOnDuty then
            for jb in pairs(jobs) do
                local s, onDuty = pcall(function() return exports.gzl_factions:isPlayerOnDuty(player, jb) end)
                if s and onDuty then return true end
            end
        end
    end

    local pFactionId = tostring(getElementData(player, "character:faction") or getElementData(player, "faction") or "")
    if pFactionId ~= "" and jobs[pFactionId] == true then
        return true
    end

    local pJob = getJob(player)
    if jobs[pJob] == true then return true end

    if trustedAdminLevel(player) > 0 then return true end
    return false
end

local function queryFavorites(player, callback)
    if not databaseReady or not database or not isElement(database) then
        callback({})
        return
    end
    local playerKey = getPlayerKey(player)
    dbQuery(function(handle)
        local rows = dbPoll(handle, -1) or {}
        local favorites = {}
        for _, row in ipairs(rows) do
            favorites[#favorites + 1] = tostring(row.frequency)
        end
        table.sort(favorites, function(a, b)
            return (tonumber(a) or 0) < (tonumber(b) or 0)
        end)
        callback(favorites)
    end, database, "SELECT frequency FROM radio_favorites WHERE player_key = ? ORDER BY CAST(frequency AS REAL)", playerKey)
end

local function isFavorite(favorites, frequency)
    for _, value in ipairs(favorites or {}) do
        if value == frequency then return true end
    end
    return false
end

local function completeConnection(player, requestId, frequency, status)
    joinChannel(player, frequency)
    local mems = collectMembers(frequency)
    respond(player, requestId, {
        ok = true,
        status = status,
        frequency = frequency,
        favorite = false,
        favorites = {},
        members = mems,
        message = "Telsiz bağlantısı kuruldu."
    })
    queryFavorites(player, function(favorites)
        if isElement(player) and playerChannels[player] == frequency then
            triggerClientEvent(player, "gzl_radio:state", resourceRoot, {
                frequency = frequency,
                favorite = isFavorite(favorites, frequency),
                favorites = favorites,
                members = collectMembers(frequency)
            })
        end
    end)
end

local function handleBootstrap(player, requestId)
    queryFavorites(player, function(favorites)
        local frequency = playerChannels[player]
        respond(player, requestId, {
            ok = true,
            frequency = frequency,
            favorite = frequency and isFavorite(favorites, frequency) or false,
            favorites = favorites,
            members = frequency and collectMembers(frequency) or {}
        })
    end)
end

local function handleCreate(player, requestId, data)
    local frequency = normalizeFrequency(data.frequency)
    local password = normalizePassword(data.password)
    if not frequency then
        respond(player, requestId, { ok = false, message = "Geçerli bir frekans girin." })
        return
    end
    if password == false then
        respond(player, requestId, { ok = false, message = "Şifre en fazla 32 karakter olabilir." })
        return
    end
    if not isChannelAllowed(player, frequency) then
        respond(player, requestId, { ok = false, status = "restricted", message = "Bu frekans mesleğinize kapalı." })
        return
    end
    if channels[frequency] then
        respond(player, requestId, { ok = false, message = "Bu frekans zaten oluşturulmuş." })
        return
    end
    local passwordHash = password and hash("sha256", password) or nil
    channels[frequency] = { passwordHash = passwordHash, members = {} }
    dbExec(database, "INSERT OR REPLACE INTO radio_channels (frequency, password_hash) VALUES (?, ?)", frequency, passwordHash or "")
    completeConnection(player, requestId, frequency, "created")
end

local function handleConnect(player, requestId, data)
    local frequency = normalizeFrequency(data.frequency)
    if not frequency then
        respond(player, requestId, { ok = false, message = "Geçerli bir frekans girin." })
        return
    end
    if not isChannelAllowed(player, frequency) then
        respond(player, requestId, { ok = false, status = "restricted", message = "Bu frekans mesleğinize kapalı." })
        return
    end
    if not channels[frequency] then
        channels[frequency] = { passwordHash = nil, members = {} }
        dbExec(database, "INSERT OR IGNORE INTO radio_channels (frequency, password_hash) VALUES (?, NULL)", frequency)
        completeConnection(player, requestId, frequency, "created")
        return
    end
    if channels[frequency].passwordHash then
        respond(player, requestId, { ok = true, status = "password", frequency = frequency })
        return
    end
    completeConnection(player, requestId, frequency, "connected")
end

local function handlePassword(player, requestId, data)
    local frequency = normalizeFrequency(data.frequency)
    local password = normalizePassword(data.password)
    local channel = frequency and channels[frequency]
    if not channel then
        respond(player, requestId, { ok = false, status = "missing", message = "Frekans bulunamadı." })
        return
    end
    if not isChannelAllowed(player, frequency) then
        respond(player, requestId, { ok = false, status = "restricted", message = "Bu frekans mesleğinize kapalı." })
        return
    end
    if password and channel.passwordHash == hash("sha256", password) then
        completeConnection(player, requestId, frequency, "connected")
    else
        respond(player, requestId, { ok = false, status = "wrong_password", message = "Telsiz şifresi yanlış." })
    end
end

local function handleFavorite(player, requestId, data)
    local frequency = normalizeFrequency(data.frequency)
    if not frequency or not channels[frequency] then
        respond(player, requestId, { ok = false, message = "Frekans bulunamadı." })
        return
    end
    local playerKey = getPlayerKey(player)
    dbQuery(function(handle)
        local rows = dbPoll(handle, 0) or {}
        local favorite = #rows == 0
        if favorite then
            dbExec(database, "INSERT OR IGNORE INTO radio_favorites (player_key, frequency) VALUES (?, ?)", playerKey, frequency)
        else
            dbExec(database, "DELETE FROM radio_favorites WHERE player_key = ? AND frequency = ?", playerKey, frequency)
        end
        queryFavorites(player, function(favorites)
            respond(player, requestId, {
                ok = true,
                favorite = favorite,
                frequency = frequency,
                favorites = favorites,
                message = favorite and "Frekans favorilere eklendi." or "Frekans favorilerden çıkarıldı."
            })
        end)
    end, database, "SELECT 1 FROM radio_favorites WHERE player_key = ? AND frequency = ? LIMIT 1", playerKey, frequency)
end

local requestHandlers = {
    bootstrap = handleBootstrap,
    createChannel = handleCreate,
    connect = handleConnect,
    password = handlePassword,
    favorite = handleFavorite,
    disconnect = function(player, requestId)
        local disconnected = leaveChannel(player, false)
        respond(player, requestId, {
            ok = disconnected,
            message = disconnected and "Telsiz bağlantısı kesildi." or "Aktif telsiz bağlantınız yok."
        })
    end
}

addEvent("gzl_radio:request", true)
addEventHandler("gzl_radio:request", resourceRoot, function(requestId, action, data)
    local player = client
    if not player or source ~= resourceRoot or not isElement(player) then return end
    if type(requestId) ~= "number" or type(action) ~= "string" or type(data) ~= "table" then return end
    if not databaseReady then
        respond(player, requestId, { ok = false, message = "Telsiz sistemi hazırlanıyor." })
        return
    end
    if not hasRadio(player) then
        leaveChannel(player, true)
        respond(player, requestId, { ok = false, message = "Üzerinizde telsiz yok." })
        return
    end
    local now = getTickCount()
    if lastRequests[player] and now - lastRequests[player] < RadioConfig.RequestCooldown then
        respond(player, requestId, { ok = false, message = "Biraz yavaşlayın." })
        return
    end
    lastRequests[player] = now
    local handler = requestHandlers[action]
    if handler then
        handler(player, requestId, data)
    end
end)

function openRadio(player)
    if not isElement(player) or getElementType(player) ~= "player" then return false end
    if not hasRadio(player) then
        notify(player, "Üzerinizde telsiz yok.", "error")
        return false
    end
    triggerClientEvent(player, "gzl_radio:open", resourceRoot)
    return true
end

function toggleRadio(player, state)
    if not isElement(player) or getElementType(player) ~= "player" then return false end
    if not hasRadio(player) then
        notify(player, "Telsiziniz bulunmuyor.", "error")
        return false
    end
    triggerClientEvent(player, "gzl_radio:toggle", resourceRoot, state)
    return true
end

function getRadioChannel(player)
    if not isElement(player) or getElementType(player) ~= "player" then return false end
    return playerChannels[player] or false
end

function setPlayerChannel(player, frequency)
    if not isElement(player) or getElementType(player) ~= "player" then return false, "Geçersiz oyuncu" end
    local freq = normalizeFrequency(frequency)
    if not freq then return false, "Geçersiz frekans formatı" end
    if not isChannelAllowed(player, freq) then
        return false, "Bu frekans teşkilatınıza kapalıdır! Yalnızca yetkili personel bağlanabilir."
    end
    if not channels[freq] then
        channels[freq] = { passwordHash = nil, members = {} }
        if databaseReady and database then
            dbExec(database, "INSERT OR IGNORE INTO radio_channels (frequency, password_hash) VALUES (?, NULL)", freq)
        end
    end
    local ok = joinChannel(player, freq)
    if ok then
        broadcastState(freq)
        triggerClientEvent(player, "gzl_radio:state", resourceRoot, {
            frequency = freq,
            members = collectMembers(freq)
        })
    end
    return ok
end

addCommandHandler("radio", function(player)
    toggleRadio(player)
end)

addEventHandler("onPlayerQuit", root, function()
    leaveChannel(source, false)
    lastRequests[source] = nil
end)

addEvent("gzl_radio:setTalking", true)
addEventHandler("gzl_radio:setTalking", resourceRoot, function(talking)
    local player = client
    if not player or source ~= resourceRoot or not isElement(player) then return end
    local frequency = playerChannels[player]
    if not frequency then return end
    setElementData(player, "radio:talking", talking == true, true)
    local players = getChannelPlayers(frequency)
    triggerClientEvent(players, "gzl_radio:talking", resourceRoot, getMemberId(player), talking == true)
end)

addEventHandler("onPlayerVoiceStart", root, function()
    local frequency = playerChannels[source]
    if not frequency then return end
    setElementData(source, "radio:talking", true, true)
    local players = getChannelPlayers(frequency)
    triggerClientEvent(players, "gzl_radio:talking", resourceRoot, getMemberId(source), true)
end)

addEventHandler("onPlayerVoiceStop", root, function()
    local frequency = playerChannels[source]
    if not frequency then return end
    setElementData(source, "radio:talking", false, true)
    local players = getChannelPlayers(frequency)
    triggerClientEvent(players, "gzl_radio:talking", resourceRoot, getMemberId(source), false)
end)

addEventHandler("onResourceStart", resourceRoot, function()
    database = dbConnect("sqlite", "radio.db")
    if not database then return end
    dbExec(database, "CREATE TABLE IF NOT EXISTS radio_channels (frequency TEXT PRIMARY KEY, password_hash TEXT)")
    dbExec(database, "CREATE TABLE IF NOT EXISTS radio_favorites (player_key TEXT NOT NULL, frequency TEXT NOT NULL, PRIMARY KEY (player_key, frequency))")
    dbQuery(function(handle)
        local rows = dbPoll(handle, -1) or {}
        for _, row in ipairs(rows) do
            channels[tostring(row.frequency)] = {
                passwordHash = row.password_hash ~= "" and row.password_hash or nil,
                members = {}
            }
        end
        databaseReady = true
    end, database, "SELECT frequency, password_hash FROM radio_channels")
end)

addEventHandler("onResourceStop", resourceRoot, function()
    for player in pairs(playerChannels) do
        if isElement(player) then
            setPlayerVoiceBroadcastTo(player, root)
        end
    end
    if database and isElement(database) then
        destroyElement(database)
    end
end)

setTimer(function()
    for player in pairs(playerChannels) do
        if not isElement(player) then
            playerChannels[player] = nil
        elseif not hasRadio(player) then
            leaveChannel(player, true)
            notify(player, "Telsiziniz olmadığı için bağlantı kesildi.", "error")
        end
    end
end, RadioConfig.ItemCheckInterval, 0)