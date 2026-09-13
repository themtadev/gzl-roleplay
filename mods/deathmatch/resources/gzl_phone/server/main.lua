local OnlinePhones = {}
local PlayerData = {}
local ActiveCalls = {}
local RequestWindows = {}
local ClientReady = {}
local DataLoadInProgress = {}
local AllowedEndpoints = {
    getBootstrapData = true,
    saveWallpaper = true,
    updateSettings = true,
    updateNotes = true,
    savePhoto = true,
    deletePhoto = true,
    getPhotos = true,
    updatePhotos = true,
    updateContacts = true,
    createContact = true,
    addContact = true,
    editContact = true,
    deleteContact = true,
    getChats = true,
    updateChats = true,
    readMessages = true,
    markChatRead = true,
    markChatAsRead = true,
    sendMessage = true,
    togglePinChat = true,
    deleteChat = true,
    batchMarkRead = true,
    batchDeleteChats = true,
    clearDeletedChats = true,
    recoverAllChats = true,
    restoreAllChats = true,
    toggleMuteChat = true,
    blockContact = true,
    deleteSingleMessage = true,
    markChatAsUnread = true,
    call = true,
    startCall = true,
    initiateCall = true,
    pickupCall = true,
    endCall = true,
    declineCall = true,
    hangupCall = true,
    deleteCall = true,
    clearAllCalls = true,
    clearCalls = true,
    getCalls = true,
    updateCalls = true,
    getNotes = true,
    createNote = true,
    addNote = true,
    deleteNote = true,
    getDarkMessages = true,
    sendDarkMessage = true,
    viewTweets = true,
    updateTweets = true,
    postTweet = true,
    likeTweet = true,
    setWallpaper = true,
    transferMoney = true,
    transfer = true,
    updateAds = true,
    getAds = true,
    postAd = true
}

function getPlayerByPhoneNumber(number)
    if not number then return nil end
    local clean = tostring(number):gsub("%s+", "")
    return OnlinePhones[clean] or OnlinePhones[tostring(number)]
end

function addPlayerCallRecord(player, callObj)
    if not isElement(player) or not callObj then return end
    local pData = PlayerData[player]
    if not pData then return end
    if not pData.calls then pData.calls = {} end
    table.insert(pData.calls, 1, callObj)

    if #pData.calls > 100 then
        table.remove(pData.calls, #pData.calls)
    end
    local db = getPhoneDB()
    if db then
        local charId = pData.charId or getElementData(player, "char:id") or 1
        dbExec(db, "UPDATE phone_users SET calls = ? WHERE phone_number = ? OR char_id = ?",
            toJSON(pData.calls), tostring(pData.number), charId)
    end
    triggerClientEvent(player, "cylex_phone:syncCallHistory", resourceRoot, pData.calls)
end

function addOfflineCallRecord(phoneNumber, callObj)
    local db = getPhoneDB()
    if not db or not phoneNumber or not callObj then return end
    dbQuery(function(qh)
        local rows = dbPoll(qh, 0) or {}
        if #rows > 0 then
            local row = rows[1]
            local calls = fromJSON(row.calls or "") or {}
            table.insert(calls, 1, callObj)
            if #calls > 100 then table.remove(calls, #calls) end
            dbExec(db, "UPDATE phone_users SET calls = ? WHERE phone_number = ?", toJSON(calls), tostring(phoneNumber))
        end
    end, db, "SELECT calls FROM phone_users WHERE phone_number = ? LIMIT 1", tostring(phoneNumber))
end

local function generatePhoneNumber(charId)
    if charId then
        local padded = string.format("%04d", charId % 10000)
        return "555-" .. padded
    end
    return "555-" .. tostring(math.random(1000, 9999))
end

local function generateIBAN(charId)
    if charId then
        local padded = string.format("%04d", charId % 10000)
        return "GZL-" .. padded
    end
    return "GZL-" .. tostring(math.random(1000, 9999))
end

function loadPlayerPhoneData(player)
    if not isElement(player) then return end
    if DataLoadInProgress[player] then return end
    local charId = getElementData(player, "char:id") or getElementData(player, "character:id") or getElementData(player, "account:id") or 1
    local db = getPhoneDB()
    if not db then return end

    DataLoadInProgress[player] = true
    dbQuery(function(qh)
        local result = dbPoll(qh, 0)
        DataLoadInProgress[player] = nil
        if not isElement(player) then return end
        if result and #result > 0 then
            local row = result[1]
            local pData = {
                id = row.id,
                charId = row.char_id,
                number = row.phone_number,
                iban = row.iban,
                twitter = row.twitter_account,
                mail = row.mail_account,
                darkchat = fromJSON(row.darkchat_user or "") or { nickname = "Anonim", photo = "" },
                settings = fromJSON(row.settings or "") or {},
                calls = fromJSON(row.calls or "") or {},
                notes = fromJSON(row.notes or "") or {},
                photos = fromJSON(row.photos or "") or {}
            }
            PlayerData[player] = pData
            OnlinePhones[tostring(pData.number)] = player
            setElementData(player, "char:phone", pData.number)
            setElementData(player, "char:iban", pData.iban)
            if ClientReady[player] then
                triggerClientEvent(player, "cylex_phone:clientInitData", resourceRoot, pData)
            end
        else

            local phoneNum = generatePhoneNumber(charId)
            local iban = generateIBAN(charId)
            local defaultSettings = toJSON({
                wallpaper = "components/media/74ebb5cae06a3d0699398ed780f12fe5.jpg",
                ringtone = "media/sounds/ringtone.ogg",
                darkmode = true,
                volume = 100
            })

            dbExec(db, "INSERT INTO phone_users (char_id, phone_number, iban, settings, calls, notes, photos) VALUES (?, ?, ?, ?, '[]', '[]', '[]')",
                charId, phoneNum, iban, defaultSettings)

            local pData = {
                charId = charId,
                number = phoneNum,
                iban = iban,
                twitter = nil,
                mail = nil,
                darkchat = { nickname = "Anonim", photo = "" },
                settings = fromJSON(defaultSettings),
                calls = {},
                notes = {},
                photos = {}
            }
            PlayerData[player] = pData
            OnlinePhones[tostring(phoneNum)] = player
            setElementData(player, "char:phone", phoneNum)
            setElementData(player, "char:iban", iban)
            if ClientReady[player] then
                triggerClientEvent(player, "cylex_phone:clientInitData", resourceRoot, pData)
            end
        end
    end, db, "SELECT * FROM phone_users WHERE char_id = ? LIMIT 1", charId)
end

addEventHandler("onResourceStart", resourceRoot, function()
    for _, player in ipairs(getElementsByType("player")) do
        loadPlayerPhoneData(player)
    end
end)

addEventHandler("onPlayerJoin", root, function()
    loadPlayerPhoneData(source)
end)

addEventHandler("onPlayerSpawn", root, function()
    loadPlayerPhoneData(source)
end)

addEvent("cylex_phone:requestBootstrap", true)
addEventHandler("cylex_phone:requestBootstrap", resourceRoot, function()
    local player = client or source
    loadPlayerPhoneData(player)
end)

addEvent("cylex_phone:clientReady", true)
addEventHandler("cylex_phone:clientReady", root, function()
    local player = client
    if not isElement(player) or source ~= player then return end
    ClientReady[player] = true
    if PlayerData[player] then
        triggerClientEvent(player, "cylex_phone:clientInitData", resourceRoot, PlayerData[player])
    else
        loadPlayerPhoneData(player)
    end
end)

addEventHandler("onPlayerQuit", root, function()
    local pData = PlayerData[source]
    if pData and pData.number then
        OnlinePhones[tostring(pData.number)] = nil
    end

    local callInfo = ActiveCalls[source]
    if callInfo then
        local otherPlayer = callInfo.target
        if isElement(otherPlayer) then
            local duration = 0
            if callInfo.status == "active" and callInfo.activeStartTick then
                duration = math.max(1, math.floor((getTickCount() - callInfo.activeStartTick) / 1000))
            end
            local wasActive = (callInfo.status == "active")
            local nowTs = getRealTime().timestamp
            local nowTime = string.format("%02d:%02d", getRealTime().hour, getRealTime().minute)

            local otherCall = {
                id = tostring(getTickCount()) .. "_" .. tostring(math.random(1000, 9999)),
                number = (ActiveCalls[otherPlayer] and ActiveCalls[otherPlayer].targetNumber) or (pData and pData.number) or "555-0000",
                name = (ActiveCalls[otherPlayer] and ActiveCalls[otherPlayer].targetName) or getPlayerName(source):gsub("#%x%x%x%x%x%x", ""),
                type = wasActive and "incoming" or "missed",
                label = "cep",
                timestamp = nowTs,
                time = nowTime,
                duration = duration
            }
            addPlayerCallRecord(otherPlayer, otherCall)
            triggerClientEvent(otherPlayer, "cylex_phone:endCall", resourceRoot)
            ActiveCalls[otherPlayer] = nil
        end
    end

    PlayerData[source] = nil
    ActiveCalls[source] = nil
    RequestWindows[source] = nil
    ClientReady[source] = nil
    DataLoadInProgress[source] = nil
end)

addEvent("cylex_phone:serverCallback", true)
addEventHandler("cylex_phone:serverCallback", root, function(endpoint, data, cbId)
    local player = client
    if not isElement(player) or source ~= player or type(endpoint) ~= "string" or not AllowedEndpoints[endpoint] then return end
    local now = getTickCount()
    local requestWindow = RequestWindows[player]
    if not requestWindow or now - requestWindow.started >= 1000 then
        requestWindow = { started = now, count = 0 }
        RequestWindows[player] = requestWindow
    end
    requestWindow.count = requestWindow.count + 1
    if requestWindow.count > 60 then
        triggerClientEvent(player, "cylex_phone:serverCallbackResponse", resourceRoot, cbId, { success = false, error = "rate_limited" })
        return
    end
    if data ~= nil and type(data) ~= "table" then return end
    local pData = PlayerData[player] or {}
    local myNumber = pData.number or "555-0000"
    local myIban = pData.iban or "GZL-0000"
    local db = getPhoneDB()

    local function sendResponse(resData)
        triggerClientEvent(player, "cylex_phone:serverCallbackResponse", resourceRoot, cbId, resData or {})
    end

    if endpoint == "getBootstrapData" then
        local charId = getElementData(player, "char:id") or getElementData(player, "character:id") or getElementData(player, "account:id") or 1
        dbQuery(function(qhUser)
            local userRows = dbPoll(qhUser, 0) or {}
            if #userRows > 0 then
                local row = userRows[1]
                pData = {
                    id = row.id,
                    charId = row.char_id,
                    number = row.phone_number,
                    iban = row.iban,
                    twitter = row.twitter_account,
                    mail = row.mail_account,
                    darkchat = fromJSON(row.darkchat_user or "") or { nickname = "Anonim", photo = "" },
                    settings = fromJSON(row.settings or "") or {},
                    calls = fromJSON(row.calls or "") or {},
                    notes = fromJSON(row.notes or "") or {},
                    photos = fromJSON(row.photos or "") or {}
                }
                PlayerData[player] = pData
                myNumber = pData.number
                myIban = pData.iban
                OnlinePhones[tostring(myNumber)] = player
            end

            dbQuery(function(qh)
                local contacts = dbPoll(qh, 0) or {}
                dbQuery(function(qhChats)
                    local chats = dbPoll(qhChats, 0) or {}
                    dbQuery(function(qhMsgs)
                        local messages = dbPoll(qhMsgs, 0) or {}

                        local mappedMsgs = {}
                        for _, m in ipairs(messages) do
                            local otherNum = (m.from_number == myNumber) and m.to_number or m.from_number
                            if not mappedMsgs[otherNum] then mappedMsgs[otherNum] = {} end
                            table.insert(mappedMsgs[otherNum], m)
                        end

                        dbQuery(function(qhTw)
                            local tweets = dbPoll(qhTw, 0) or {}
                            dbQuery(function(qhTx)
                                local transactions = dbPoll(qhTx, 0) or {}
                                dbQuery(function(qhDark)
                                    local darkMsgs = dbPoll(qhDark, 0) or {}
                                    local bank = tonumber(getElementData(player, "character:bank") or getElementData(player, "char:bank_money") or getElementData(player, "char:bank")) or 0
                                    local bootData = {
                                        phoneNumber = myNumber,
                                        iban = myIban,
                                        bankBalance = bank,
                                        wallpaper = (pData.settings and pData.settings.wallpaper) or "components/media/74ebb5cae06a3d0699398ed780f12fe5.jpg",
                                        settings = pData.settings or {},
                                        photos = pData.photos or {},
                                        contacts = contacts,
                                        calls = pData.calls or {},
                                        callHistory = pData.calls or {},
                                        chats = chats,
                                        messages = mappedMsgs,
                                        tweets = tweets,
                                        notes = pData.notes or {},
                                        transactions = transactions,
                                        darkMessages = darkMsgs
                                    }
                                    triggerClientEvent(player, "cylex_phone:receiveBootstrapData", resourceRoot, bootData)
                                    sendResponse(bootData)
                                end, db, "SELECT * FROM phone_darkmessages ORDER BY id DESC LIMIT 50")
                            end, db, "SELECT * FROM phone_transactions WHERE from_iban = ? OR to_iban = ? ORDER BY id DESC LIMIT 30", myIban, myIban)
                        end, db, "SELECT * FROM phone_tweets ORDER BY id DESC LIMIT 50")
                    end, db, "SELECT * FROM phone_messages WHERE from_number = ? OR to_number = ? ORDER BY time ASC LIMIT 300", myNumber, myNumber)
                end, db, "SELECT * FROM phone_chats WHERE owner_number = ? ORDER BY is_pinned DESC, last_time DESC", myNumber)
            end, db, "SELECT * FROM phone_contacts WHERE owner_number = ?", myNumber)
        end, db, "SELECT * FROM phone_users WHERE char_id = ? OR phone_number = ? LIMIT 1", charId, myNumber)
        return

    elseif endpoint == "saveWallpaper" then
        if data and data.wallpaper then
            if not pData.settings then pData.settings = {} end
            pData.settings.wallpaper = data.wallpaper
            dbExec(db, "UPDATE phone_users SET settings = ? WHERE phone_number = ? OR char_id = ?", toJSON(pData.settings), myNumber, pData.charId)
        end
        sendResponse("ok")

    elseif endpoint == "updateSettings" then
        if data and data.settings then
            pData.settings = data.settings
            dbExec(db, "UPDATE phone_users SET settings = ? WHERE phone_number = ? OR char_id = ?", toJSON(data.settings), myNumber, pData.charId)
        end
        sendResponse("ok")

    elseif endpoint == "updateNotes" then
        if data and data.notes then
            pData.notes = data.notes
            dbExec(db, "UPDATE phone_users SET notes = ? WHERE phone_number = ?", toJSON(data.notes), myNumber)
        end
        sendResponse("ok")

    elseif endpoint == "savePhoto" then
        if data then
            local photoSrc = tostring(data.src or data.photo or "")
            if #photoSrc > 1000 then
                photoSrc = "components/media/photos/photo_" .. tostring(data.id or getTickCount()) .. ".jpg"
            end
            local photoObj = {
                id = data.id or (tostring(getTickCount()) .. "_" .. tostring(math.random(1000, 9999))),
                src = photoSrc,
                time = tostring(data.time or ""),
                date = tostring(data.date or "")
            }
            if not pData.photos then pData.photos = {} end
            local found = false
            for _, p in ipairs(pData.photos) do
                if tostring(p.id) == tostring(photoObj.id) then
                    found = true
                    break
                end
            end
            if not found then
                table.insert(pData.photos, 1, photoObj)
            end

            local ok, jsonStr = pcall(toJSON, pData.photos)
            if ok and jsonStr and #jsonStr < 100000 then
                local charId = getElementData(player, "char:id") or getElementData(player, "character:id") or getElementData(player, "account:id") or pData.charId or 1
                dbExec(db, "UPDATE phone_users SET photos = ? WHERE phone_number = ? OR char_id = ?", jsonStr, myNumber, charId)
            end
            sendResponse({ success = true, photo = photoObj })
            return
        end
        sendResponse({ success = false })

    elseif endpoint == "deletePhoto" then
        if data and pData.photos then
            local targetId = type(data) == "table" and (data.id or data.src) or data
            local targetSrc = type(data) == "table" and (data.src or data.photo) or data
            local targets = {}
            if type(data) == "table" and type(data.ids) == "table" then
                for _, id in ipairs(data.ids) do targets[tostring(id)] = true end
            end
            for idx = #pData.photos, 1, -1 do
                local p = pData.photos[idx]
                local photoId = type(p) == "table" and p.id or p
                local photoSrc = type(p) == "table" and (p.src or p.photo or p.url) or p
                if targets[tostring(photoId)] or targetId ~= nil and tostring(photoId) == tostring(targetId) or targetSrc ~= nil and photoSrc == targetSrc then
                    table.remove(pData.photos, idx)
                end
            end
            local charId = getElementData(player, "char:id") or getElementData(player, "character:id") or getElementData(player, "account:id") or pData.charId or 1
            dbExec(db, "UPDATE phone_users SET photos = ? WHERE phone_number = ? OR char_id = ?", toJSON(pData.photos), myNumber, charId)
        end
        sendResponse("ok")

    elseif endpoint == "getPhotos" or endpoint == "updatePhotos" then
        sendResponse(pData.photos or {})

    elseif endpoint == "updateContacts" then
        dbQuery(function(qh)
            local rows = dbPoll(qh, 0) or {}
            sendResponse(rows)
        end, db, "SELECT * FROM phone_contacts WHERE owner_number = ?", myNumber)

    elseif endpoint == "createContact" or endpoint == "addContact" then
        if data and data.number and data.name then
            local photoStr = tostring(data.avatar or data.photo or "")
            local notesStr = tostring(data.notes or data.tag or "")
            dbExec(db, "INSERT INTO phone_contacts (owner_number, number, name, photo, tag) VALUES (?, ?, ?, ?, ?)",
                myNumber, tostring(data.number), tostring(data.name), photoStr, notesStr)
        end
        sendResponse("ok")

    elseif endpoint == "editContact" then
        if data and data.id then
            dbExec(db, "UPDATE phone_contacts SET number = ?, name = ?, photo = ?, tag = ? WHERE id = ? AND owner_number = ?",
                tostring(data.number), tostring(data.name), tostring(data.photo or ""), tostring(data.tag or ""), data.id, myNumber)
        end
        sendResponse("ok")

    elseif endpoint == "deleteContact" then
        if data and data.id then
            dbExec(db, "DELETE FROM phone_contacts WHERE id = ? AND owner_number = ?", data.id, myNumber)
        end
        sendResponse("ok")

    elseif endpoint == "getChats" or endpoint == "updateChats" then
        local folder = tostring(data and data.folder or "inbox")
        dbQuery(function(qh)
            local rows = dbPoll(qh, 0) or {}
            sendResponse(rows)
        end, db, "SELECT * FROM phone_chats WHERE owner_number = ? AND folder = ? ORDER BY is_pinned DESC, last_time DESC", myNumber, folder)

    elseif endpoint == "readMessages" or endpoint == "markChatRead" or endpoint == "markChatAsRead" then
        local targetNum = tostring(data and (data.number or data.targetNumber) or "")
        local nowTimeStr = string.format("%02d:%02d", getRealTime().hour, getRealTime().minute)
        dbExec(db, "UPDATE phone_messages SET is_read = 1, read_time = ? WHERE to_number = ? AND from_number = ? AND is_read = 0", nowTimeStr, myNumber, targetNum)
        dbExec(db, "UPDATE phone_chats SET is_read = 1, unread = 0 WHERE owner_number = ? AND number = ?", myNumber, targetNum)

        local senderPlayer = getPlayerByPhoneNumber(targetNum)
        if isElement(senderPlayer) then
            triggerClientEvent(senderPlayer, "cylex_phone:messagesRead", resourceRoot, {
                readerNumber = myNumber,
                readTime = nowTimeStr
            })
        end

        dbQuery(function(qh)
            local msgs = dbPoll(qh, 0) or {}
            for _, m in ipairs(msgs) do
                if type(m.attachments) == "string" and (string.sub(m.attachments, 1, 1) == "{" or string.sub(m.attachments, 1, 1) == "[") then
                    local parsed = fromJSON(m.attachments)
                    if type(parsed) == "table" then
                        for k, v in pairs(parsed) do
                            m[k] = v
                        end
                    end
                end
            end
            sendResponse(msgs)
        end, db, "SELECT * FROM phone_messages WHERE (from_number = ? AND to_number = ?) OR (from_number = ? AND to_number = ?) ORDER BY time ASC",
            myNumber, targetNum, targetNum, myNumber)

    elseif endpoint == "sendMessage" then
        local targetNum = tostring(data and (data.number or data.targetNumber or data.target) or "")
        local msgText = tostring(data and (data.message or data.text) or "")
        local rawAttach = data and data.attachments
        local attachStr = ""
        local attachTable = nil

        if type(rawAttach) == "table" then
            attachStr = toJSON(rawAttach)
            attachTable = rawAttach
        elseif type(rawAttach) == "string" then
            attachStr = rawAttach
            if string.sub(rawAttach, 1, 1) == "{" or string.sub(rawAttach, 1, 1) == "[" then
                attachTable = fromJSON(rawAttach)
            end
        end

        local nowTick = getRealTime().timestamp

        if #targetNum > 0 and (#msgText > 0 or #attachStr > 0) then
            local targetPlayer = getPlayerByPhoneNumber(targetNum)
            local isDelivered = isElement(targetPlayer)

            dbExec(db, "INSERT INTO phone_messages (from_number, to_number, message, time, is_read, attachments, folder) VALUES (?, ?, ?, ?, 0, ?, 'inbox')",
                myNumber, targetNum, msgText, nowTick, attachStr)

            local lastSummary = (#msgText > 0 and msgText or ((attachTable and attachTable.is_photo) and "📸 Fotoğraf" or "📎 Ek dosya"))

            dbQuery(function(qhCheck)
                local rows = dbPoll(qhCheck, 0) or {}
                if #rows > 0 then
                    dbExec(db, "UPDATE phone_chats SET last_message = ?, last_time = ?, folder = 'inbox', is_read = 1, unread = 0 WHERE owner_number = ? AND number = ?",
                        lastSummary, nowTick, myNumber, targetNum)
                else
                    dbExec(db, "INSERT INTO phone_chats (owner_number, number, name, photo, folder, last_message, last_time, is_read, unread) VALUES (?, ?, ?, ?, 'inbox', ?, ?, 1, 0)",
                        myNumber, targetNum, tostring(data.name or targetNum), tostring(data.photo or ""), lastSummary, nowTick)
                end
            end, db, "SELECT id FROM phone_chats WHERE owner_number = ? AND number = ? LIMIT 1", myNumber, targetNum)

            local msgObj = {
                from = myNumber,
                from_number = myNumber,
                from_name = getPlayerName(player):gsub("#%x%x%x%x%x%x", ""),
                to = targetNum,
                to_number = targetNum,
                message = msgText,
                time = nowTick,
                attachments = attachStr,
                is_read = 0,
                is_delivered = isDelivered
            }

            if attachTable and type(attachTable) == "table" then
                for k, v in pairs(attachTable) do
                    msgObj[k] = v
                end
            end

            if isDelivered then
                dbQuery(function(qhTargetCheck)
                    local tRows = dbPoll(qhTargetCheck, 0) or {}
                    if #tRows > 0 then
                        dbExec(db, "UPDATE phone_chats SET last_message = ?, last_time = ?, folder = 'inbox', is_read = 0, unread = unread + 1 WHERE owner_number = ? AND number = ?",
                            lastSummary, nowTick, targetNum, myNumber)
                    else
                        dbExec(db, "INSERT INTO phone_chats (owner_number, number, name, photo, folder, last_message, last_time, is_read, unread) VALUES (?, ?, ?, ?, 'inbox', ?, ?, 0, 1)",
                            targetNum, myNumber, myNumber, "", lastSummary, nowTick)
                    end
                end, db, "SELECT id FROM phone_chats WHERE owner_number = ? AND number = ? LIMIT 1", targetNum, myNumber)

                triggerClientEvent(targetPlayer, "cylex_phone:receivedMessage", resourceRoot, msgObj)
                triggerClientEvent(targetPlayer, "cylex_phone:incomingMessage", resourceRoot, msgObj)
            else
                dbQuery(function(qhTargetOffline)
                    local toRows = dbPoll(qhTargetOffline, 0) or {}
                    if #toRows > 0 then
                        dbExec(db, "UPDATE phone_chats SET last_message = ?, last_time = ?, is_read = 0, unread = unread + 1 WHERE owner_number = ? AND number = ?",
                            lastSummary, nowTick, targetNum, myNumber)
                    else
                        dbExec(db, "INSERT INTO phone_chats (owner_number, number, name, photo, folder, last_message, last_time, is_read, unread) VALUES (?, ?, ?, ?, 'inbox', ?, ?, 0, 1)",
                            targetNum, myNumber, myNumber, "", lastSummary, nowTick)
                    end
                end, db, "SELECT id FROM phone_chats WHERE owner_number = ? AND number = ? LIMIT 1", targetNum, myNumber)
            end

            sendResponse({ success = true, message = msgObj, is_delivered = isDelivered })
            return
        end
        sendResponse({ success = false })

    elseif endpoint == "togglePinChat" then
        local targetNum = tostring(data and (data.number or data.targetNumber) or "")
        local newPinState = (data and data.is_pinned) and 1 or 0
        dbExec(db, "UPDATE phone_chats SET is_pinned = ? WHERE owner_number = ? AND number = ?", newPinState, myNumber, targetNum)
        sendResponse({ success = true, is_pinned = newPinState })

    elseif endpoint == "deleteChat" then
        local targetNum = tostring(data and (data.number or data.targetNumber) or "")
        local hardDelete = (data and data.permanent == true)
        local nowTick = getRealTime().timestamp
        if #targetNum > 0 then
            if hardDelete then
                dbExec(db, "DELETE FROM phone_chats WHERE owner_number = ? AND number = ?", myNumber, targetNum)
                dbExec(db, "DELETE FROM phone_messages WHERE (from_number = ? AND to_number = ?) OR (from_number = ? AND to_number = ?)",
                    myNumber, targetNum, targetNum, myNumber)
            else
                dbExec(db, "UPDATE phone_chats SET folder = 'deleted' WHERE owner_number = ? AND number = ?", myNumber, targetNum)
                dbExec(db, "UPDATE phone_messages SET folder = 'deleted', deleted_at = ? WHERE (from_number = ? AND to_number = ?) OR (from_number = ? AND to_number = ?)",
                    nowTick, myNumber, targetNum, targetNum, myNumber)
            end
        end
        sendResponse({ success = true })

    elseif endpoint == "batchMarkRead" then
        local numbers = data and data.numbers or {}
        for _, num in ipairs(numbers) do
            dbExec(db, "UPDATE phone_messages SET is_read = 1 WHERE to_number = ? AND from_number = ?", myNumber, tostring(num))
            dbExec(db, "UPDATE phone_chats SET is_read = 1, unread = 0 WHERE owner_number = ? AND number = ?", myNumber, tostring(num))
        end
        sendResponse({ success = true })

    elseif endpoint == "batchDeleteChats" then
        local numbers = data and data.numbers or {}
        local hardDelete = (data and data.permanent == true)
        local nowTick = getRealTime().timestamp
        for _, num in ipairs(numbers) do
            if hardDelete then
                dbExec(db, "DELETE FROM phone_chats WHERE owner_number = ? AND number = ?", myNumber, tostring(num))
                dbExec(db, "DELETE FROM phone_messages WHERE (from_number = ? AND to_number = ?) OR (from_number = ? AND to_number = ?)",
                    myNumber, tostring(num), tostring(num), myNumber)
            else
                dbExec(db, "UPDATE phone_chats SET folder = 'deleted' WHERE owner_number = ? AND number = ?", myNumber, tostring(num))
                dbExec(db, "UPDATE phone_messages SET folder = 'deleted', deleted_at = ? WHERE (from_number = ? AND to_number = ?) OR (from_number = ? AND to_number = ?)",
                    nowTick, myNumber, tostring(num), tostring(num), myNumber)
            end
        end
        sendResponse({ success = true })

    elseif endpoint == "recoverAllChats" or endpoint == "restoreAllChats" then
        dbExec(db, "UPDATE phone_chats SET folder = 'inbox' WHERE owner_number = ? AND folder = 'deleted'", myNumber)
        dbExec(db, "UPDATE phone_messages SET folder = 'inbox', deleted_at = 0 WHERE (from_number = ? OR to_number = ?) AND folder = 'deleted'", myNumber, myNumber)
        sendResponse({ success = true })

    elseif endpoint == "clearDeletedChats" then
        dbExec(db, "DELETE FROM phone_chats WHERE owner_number = ? AND folder = 'deleted'", myNumber)
        sendResponse({ success = true })

    elseif endpoint == "toggleMuteChat" then
        local targetNum = tostring(data and (data.number or data.targetNumber) or "")
        local newMute = (data and data.muted) and 1 or 0
        dbExec(db, "UPDATE phone_chats SET muted = ? WHERE owner_number = ? AND number = ?", newMute, myNumber, targetNum)
        sendResponse({ success = true, muted = newMute })

    elseif endpoint == "blockContact" then
        local targetNum = tostring(data and (data.number or data.targetNumber) or "")
        local newBlock = (data and data.blocked == false) and 0 or 1
        dbExec(db, "UPDATE phone_chats SET is_blocked = ?, folder = ? WHERE owner_number = ? AND number = ?",
            newBlock, (newBlock == 1 and "spam" or "inbox"), myNumber, targetNum)
        sendResponse({ success = true, blocked = newBlock })

    elseif endpoint == "deleteSingleMessage" then
        local msgTime = data and data.time
        local msgText = data and data.message
        local targetNum = tostring(data and (data.number or data.target) or "")
        if msgTime then
            dbExec(db, "DELETE FROM phone_messages WHERE time = ? AND ((from_number = ? AND to_number = ?) OR (from_number = ? AND to_number = ?))",
                msgTime, myNumber, targetNum, targetNum, myNumber)
        elseif msgText and #targetNum > 0 then
            dbExec(db, "DELETE FROM phone_messages WHERE message = ? AND ((from_number = ? AND to_number = ?) OR (from_number = ? AND to_number = ?)) LIMIT 1",
                msgText, myNumber, targetNum, targetNum, myNumber)
        end
        sendResponse({ success = true })

    elseif endpoint == "markChatAsUnread" then
        local targetNum = tostring(data and (data.number or data.targetNumber) or "")
        if #targetNum > 0 then
            dbExec(db, "UPDATE phone_chats SET is_read = 0, unread = 1 WHERE owner_number = ? AND number = ?", myNumber, targetNum)
            dbExec(db, "UPDATE phone_messages SET is_read = 0 WHERE to_number = ? AND from_number = ?", myNumber, targetNum)
        end
        sendResponse({ success = true })

    elseif endpoint == "call" or endpoint == "startCall" or endpoint == "initiateCall" then
        local targetNum = tostring(data and (data.targetNumber or data.toNumber or data.number) or "")
        local targetName = data and (data.targetName or data.name) or nil
        local targetPlayer = getPlayerByPhoneNumber(targetNum)
        local nowTs = getRealTime().timestamp
        local nowTime = string.format("%02d:%02d", getRealTime().hour, getRealTime().minute)

        if Config.JobContacts then
            for jobKey, jobData in pairs(Config.JobContacts) do
                if jobData.number == targetNum then
                    local callObjCaller = {
                        id = tostring(getTickCount()) .. "_" .. tostring(math.random(1000, 9999)),
                        number = targetNum,
                        name = jobData.name or targetNum,
                        type = "outgoing",
                        label = "hizmet",
                        timestamp = nowTs,
                        time = nowTime,
                        duration = 0
                    }
                    addPlayerCallRecord(player, callObjCaller)

                    local px, py, pz = getElementPosition(player)
                    local callerName = getPlayerName(player):gsub("#%x%x%x%x%x%x", "")
                    local district = getZoneName(px, py, pz)
                    local dispatchInfo = {
                        service = jobKey,
                        serviceName = jobData.name,
                        callerName = callerName,
                        callerNumber = myNumber,
                        location = { x = px, y = py, z = pz },
                        district = district,
                        time = nowTime
                    }

                    for _, p in ipairs(getElementsByType("player")) do
                        local pJob = getElementData(p, "char:job") or getElementData(p, "job") or getElementData(p, "faction")
                        if pJob == jobKey or pJob == "police" or pJob == 1 or pJob == "lspd" or pJob == "ems" or pJob == "mechanic" or pJob == "taxi" then
                            triggerClientEvent(p, "cylex_phone:emergencyDispatch", resourceRoot, dispatchInfo)
                            local uiResource = getResourceFromName("gzl_ui")
                            if uiResource and getResourceState(uiResource) == "running" and exports.gzl_ui and exports.gzl_ui.showNotification then
                                exports.gzl_ui:showNotification(p, jobData.name .. " Çağrısı", string.format("%s (%s) - Konum: %s", callerName, myNumber, district), "info")
                            end
                        end
                    end

                    sendResponse({ status = "calling", target = targetNum, isService = true })
                    return
                end
            end
        end

        if isElement(targetPlayer) and targetPlayer ~= player then

            if ActiveCalls[targetPlayer] then
                local callObjCaller = {
                    id = tostring(getTickCount()) .. "_" .. tostring(math.random(1000, 9999)),
                    number = targetNum,
                    name = targetName or targetNum,
                    type = "outgoing",
                    label = "cep",
                    timestamp = nowTs,
                    time = nowTime,
                    duration = 0
                }
                addPlayerCallRecord(player, callObjCaller)

                local callObjTarget = {
                    id = tostring(getTickCount()) .. "_" .. tostring(math.random(1000, 9999)),
                    number = myNumber,
                    name = getPlayerName(player):gsub("#%x%x%x%x%x%x", ""),
                    type = "missed",
                    label = "cep",
                    timestamp = nowTs,
                    time = nowTime,
                    duration = 0
                }
                addPlayerCallRecord(targetPlayer, callObjTarget)
                triggerClientEvent(player, "cylex_phone:cantReach", player)
                sendResponse({ status = "busy", message = "Meşgul" })
                return
            end

            ActiveCalls[player] = {
                target = targetPlayer,
                targetNumber = targetNum,
                targetName = targetName or targetNum,
                callerNumber = myNumber,
                callerName = getPlayerName(player):gsub("#%x%x%x%x%x%x", ""),
                status = "calling",
                startTick = getTickCount(),
                isCaller = true
            }
            ActiveCalls[targetPlayer] = {
                target = player,
                targetNumber = myNumber,
                targetName = getPlayerName(player):gsub("#%x%x%x%x%x%x", ""),
                callerNumber = myNumber,
                callerName = getPlayerName(player):gsub("#%x%x%x%x%x%x", ""),
                status = "ringing",
                startTick = getTickCount(),
                isCaller = false
            }

            triggerClientEvent(targetPlayer, "cylex_phone:incomingCall", resourceRoot, {
                callerNumber = myNumber,
                callerName = getPlayerName(player):gsub("#%x%x%x%x%x%x", ""),
                number = myNumber,
                status = "ringing"
            })
            sendResponse({ status = "calling", target = targetNum })
        else

            local callObjCaller = {
                id = tostring(getTickCount()) .. "_" .. tostring(math.random(1000, 9999)),
                number = targetNum,
                name = targetName or targetNum,
                type = "outgoing",
                label = "cep",
                timestamp = nowTs,
                time = nowTime,
                duration = 0
            }
            addPlayerCallRecord(player, callObjCaller)

            local callObjTarget = {
                id = tostring(getTickCount()) .. "_" .. tostring(math.random(1000, 9999)),
                number = myNumber,
                name = getPlayerName(player):gsub("#%x%x%x%x%x%x", ""),
                type = "missed",
                label = "cep",
                timestamp = nowTs,
                time = nowTime,
                duration = 0
            }
            addOfflineCallRecord(targetNum, callObjTarget)

            triggerClientEvent(player, "cylex_phone:cantReach", player)
            sendResponse({ status = "unavailable", message = "Numaraya ulaşılamıyor" })
        end

    elseif endpoint == "pickupCall" then
        local callInfo = ActiveCalls[player]
        if callInfo and isElement(callInfo.target) then
            callInfo.status = "active"
            callInfo.activeStartTick = getTickCount()
            if ActiveCalls[callInfo.target] then
                ActiveCalls[callInfo.target].status = "active"
                ActiveCalls[callInfo.target].activeStartTick = getTickCount()
            end

            setPlayerVoiceBroadcastTo(player, callInfo.target)
            setPlayerVoiceBroadcastTo(callInfo.target, player)

            triggerClientEvent(callInfo.target, "cylex_phone:changeCallStatus", resourceRoot, "active")
            triggerClientEvent(player, "cylex_phone:changeCallStatus", resourceRoot, "active")
            sendResponse({ status = "active" })
        else
            sendResponse({ status = "ended" })
        end

    elseif endpoint == "endCall" or endpoint == "declineCall" or endpoint == "hangupCall" then
        local callInfo = ActiveCalls[player]
        if callInfo then
            local otherPlayer = callInfo.target
            local duration = 0
            if callInfo.status == "active" and callInfo.activeStartTick then
                duration = math.max(1, math.floor((getTickCount() - callInfo.activeStartTick) / 1000))
            end
            local wasActive = (callInfo.status == "active")
            local nowTs = getRealTime().timestamp
            local nowTime = string.format("%02d:%02d", getRealTime().hour, getRealTime().minute)

            local callerP = callInfo.isCaller and player or otherPlayer
            local targetP = callInfo.isCaller and otherPlayer or player

            if isElement(player) then setPlayerVoiceBroadcastTo(player, nil) end
            if isElement(otherPlayer) then setPlayerVoiceBroadcastTo(otherPlayer, nil) end

            if isElement(callerP) then
                local callCaller = {
                    id = tostring(getTickCount()) .. "_" .. tostring(math.random(1000, 9999)),
                    number = (ActiveCalls[callerP] and ActiveCalls[callerP].targetNumber) or myNumber,
                    name = (ActiveCalls[callerP] and ActiveCalls[callerP].targetName) or "Arama",
                    type = "outgoing",
                    label = "cep",
                    timestamp = nowTs,
                    time = nowTime,
                    duration = duration
                }
                addPlayerCallRecord(callerP, callCaller)
            end

            if isElement(targetP) then
                local callTarget = {
                    id = tostring(getTickCount()) .. "_" .. tostring(math.random(1000, 9999)),
                    number = (ActiveCalls[targetP] and ActiveCalls[targetP].targetNumber) or myNumber,
                    name = (ActiveCalls[targetP] and ActiveCalls[targetP].targetName) or "Arama",
                    type = wasActive and "incoming" or "missed",
                    label = "cep",
                    timestamp = nowTs,
                    time = nowTime,
                    duration = duration
                }
                addPlayerCallRecord(targetP, callTarget)
            end

            if isElement(otherPlayer) then
                triggerClientEvent(otherPlayer, "cylex_phone:endCall", resourceRoot)
                ActiveCalls[otherPlayer] = nil
            end
            ActiveCalls[player] = nil
        end
        sendResponse("ok")

    elseif endpoint == "deleteCall" then
        if data and pData.calls then
            local callId = type(data) == "table" and (data.id or data.timestamp or data.time) or data
            for i, c in ipairs(pData.calls) do
                if tostring(c.id) == tostring(callId) or tostring(c.timestamp) == tostring(callId) then
                    table.remove(pData.calls, i)
                    break
                end
            end
            local charId = pData.charId or getElementData(player, "char:id") or 1
            dbExec(db, "UPDATE phone_users SET calls = ? WHERE phone_number = ? OR char_id = ?",
                toJSON(pData.calls), tostring(myNumber), charId)
            triggerClientEvent(player, "cylex_phone:syncCallHistory", resourceRoot, pData.calls)
        end
        sendResponse("ok")

    elseif endpoint == "clearAllCalls" or endpoint == "clearCalls" then
        pData.calls = {}
        local charId = pData.charId or getElementData(player, "char:id") or 1
        dbExec(db, "UPDATE phone_users SET calls = '[]' WHERE phone_number = ? OR char_id = ?",
            tostring(myNumber), charId)
        triggerClientEvent(player, "cylex_phone:syncCallHistory", resourceRoot, pData.calls)
        sendResponse("ok")

    elseif endpoint == "getCalls" or endpoint == "updateCalls" then
        sendResponse(pData.calls or {})

    elseif endpoint == "getNotes" then
        sendResponse(pData.notes or {})

    elseif endpoint == "createNote" or endpoint == "addNote" then
        if data and data.title then
            if not pData.notes then pData.notes = {} end
            local newNote = {
                id = data.id or (tostring(getTickCount()) .. "_" .. tostring(math.random(100, 999))),
                title = tostring(data.title),
                content = tostring(data.content or ""),
                date = tostring(data.date or "Bugün")
            }
            local updated = false
            for index, note in ipairs(pData.notes) do
                if tostring(note.id) == tostring(newNote.id) then
                    pData.notes[index] = newNote
                    updated = true
                    break
                end
            end
            if not updated then table.insert(pData.notes, 1, newNote) end
            local charId = pData.charId or getElementData(player, "char:id") or 1
            dbExec(db, "UPDATE phone_users SET notes = ? WHERE phone_number = ? OR char_id = ?",
                toJSON(pData.notes), tostring(myNumber), charId)
            sendResponse({ success = true, note = newNote, notes = pData.notes })
            return
        end
        sendResponse({ success = false })

    elseif endpoint == "deleteNote" then
        if data and pData.notes then
            local noteId = type(data) == "table" and data.id or data
            for idx, n in ipairs(pData.notes) do
                if tostring(n.id) == tostring(noteId) then
                    table.remove(pData.notes, idx)
                    break
                end
            end
            local charId = pData.charId or getElementData(player, "char:id") or 1
            dbExec(db, "UPDATE phone_users SET notes = ? WHERE phone_number = ? OR char_id = ?",
                toJSON(pData.notes), tostring(myNumber), charId)
            sendResponse({ success = true, notes = pData.notes })
            return
        end
        sendResponse({ success = false })

    elseif endpoint == "getDarkMessages" then
        dbQuery(function(qh)
            local rows = dbPoll(qh, 0) or {}
            sendResponse(rows)
        end, db, "SELECT * FROM phone_darkmessages ORDER BY id ASC LIMIT 50")

    elseif endpoint == "sendDarkMessage" then
        if data and data.text then
            local darkNick = (pData.darkchat and pData.darkchat.nickname) or ("Anon" .. tostring(math.random(100, 999)))
            local msgText = tostring(data.text or data.message or "")
            local nowTick = getRealTime().timestamp
            local nowTime = string.format("%02d:%02d", getRealTime().hour, getRealTime().minute)

            dbExec(db, "INSERT INTO phone_darkmessages (group_id, sender, message, time) VALUES (1, ?, ?, ?)",
                darkNick, msgText, nowTick)

            local darkObj = {
                user = darkNick,
                text = msgText,
                time = nowTime,
                timestamp = nowTick
            }
            triggerClientEvent(root, "cylex_phone:receivedDarkMessage", resourceRoot, darkObj)
            sendResponse({ success = true, message = darkObj })
            return
        end
        sendResponse({ success = false })

    elseif endpoint == "viewTweets" or endpoint == "updateTweets" then
        dbQuery(function(qh)
            local tweets = dbPoll(qh, 0) or {}
            for i, tw in ipairs(tweets) do
                tw.likes = fromJSON(tw.likes or "") or {}
            end
            sendResponse(tweets)
        end, db, "SELECT * FROM phone_tweets WHERE reply_to IS NULL ORDER BY time DESC LIMIT ?", Config.TweetLimit or 30)

    elseif endpoint == "postTweet" then
        if data and data.content then
            local nowTick = getRealTime().timestamp
            local twName = pData.twitter or getPlayerName(player)
            dbExec(db, "INSERT INTO phone_tweets (author_email, author_name, author_avatar, content, image, time, likes) VALUES (?, ?, ?, ?, ?, ?, '[]')",
                myNumber, twName, tostring(data.avatar or ""), tostring(data.content), tostring(data.image or ""), nowTick)

            local twObj = {
                author_email = myNumber,
                author_name = twName,
                author_avatar = tostring(data.avatar or ""),
                content = tostring(data.content),
                image = tostring(data.image or ""),
                time = nowTick,
                likes = {}
            }
            triggerClientEvent(root, "cylex_phone:addTweet", resourceRoot, twObj)
            sendResponse({ success = true, tweet = twObj })
            return
        end
        sendResponse("ok")

    elseif endpoint == "likeTweet" then
        if data and data.id then
            dbQuery(function(qh)
                local res = dbPoll(qh, 0)
                if res and #res > 0 then
                    local likes = fromJSON(res[1].likes or "") or {}
                    local hasLiked = false
                    for idx, liker in ipairs(likes) do
                        if liker == myNumber then
                            table.remove(likes, idx)
                            hasLiked = true
                            break
                        end
                    end
                    if not hasLiked then
                        table.insert(likes, myNumber)
                    end
                    dbExec(db, "UPDATE phone_tweets SET likes = ? WHERE id = ?", toJSON(likes), data.id)
                    triggerClientEvent(root, "cylex_phone:tweetLiked", resourceRoot, data.id, likes)
                end
            end, db, "SELECT likes FROM phone_tweets WHERE id = ? LIMIT 1", data.id)
        end
        sendResponse("ok")

    elseif endpoint == "saveWallpaper" or endpoint == "setWallpaper" then
        if data and data.wallpaper then
            if pData then
                if not pData.settings then pData.settings = {} end
                pData.settings.wallpaper = tostring(data.wallpaper)
                dbExec(db, "UPDATE phone_users SET settings = ? WHERE char_id = ?", toJSON(pData.settings), pData.charId)
            end
        end
        sendResponse("ok")

    elseif endpoint == "transferMoney" or endpoint == "transfer" then
        local targetIban = tostring(data.iban or data.target or "")
        local amount = math.floor(tonumber(data.amount) or 0)
        local reason = tostring(data.reason or "Transfer")
        local playerBank = tonumber(getElementData(player, "character:bank") or getElementData(player, "char:bank_money") or getElementData(player, "char:bank")) or 0

        if amount > 0 and playerBank >= amount then
            dbQuery(function(qh)
                local targetRows = dbPoll(qh, 0)
                if targetRows and #targetRows > 0 then
                    local targetRow = targetRows[1]
                    local targetCharId = targetRow.char_id
                    local targetNum = targetRow.phone_number

                    local newSenderBank = playerBank - amount
                    setElementData(player, "character:bank", newSenderBank, "broadcast", "deny")
                    setElementData(player, "char:bank_money", newSenderBank)
                    setElementData(player, "char:bank", newSenderBank, "broadcast", "deny")
                    if exports.gzl_characters and exports.gzl_characters.saveCharacter then
                        exports.gzl_characters:saveCharacter(player)
                    end

                    local nowTick = getRealTime().timestamp
                    dbExec(db, "INSERT INTO phone_transactions (from_iban, to_iban, amount, reason, time) VALUES (?, ?, ?, ?, ?)",
                        myIban, targetIban, amount, reason, nowTick)

                    local newTxSender = {
                        from_iban = myIban,
                        to_iban = targetIban,
                        amount = amount,
                        reason = reason,
                        time = nowTick,
                        type = "debit"
                    }

                    local targetP = OnlinePhones[tostring(targetNum)]
                    if isElement(targetP) then
                        local recBank = tonumber(getElementData(targetP, "character:bank") or getElementData(targetP, "char:bank_money") or getElementData(targetP, "char:bank")) or 0
                        local newRecBank = recBank + amount
                        setElementData(targetP, "character:bank", newRecBank, "broadcast", "deny")
                        setElementData(targetP, "char:bank_money", newRecBank)
                        setElementData(targetP, "char:bank", newRecBank, "broadcast", "deny")
                        if exports.gzl_characters and exports.gzl_characters.saveCharacter then
                            exports.gzl_characters:saveCharacter(targetP)
                        end
                        local uiResource = getResourceFromName("gzl_ui")
                        if uiResource and getResourceState(uiResource) == "running" and exports.gzl_ui and exports.gzl_ui.showNotification then
                            exports.gzl_ui:showNotification(targetP, "Banka", string.format("$%d para transferi aldınız (%s).", amount, reason), "success")
                        end
                        triggerClientEvent(targetP, "cylex_phone:newTransaction", resourceRoot, {
                            from_iban = myIban,
                            to_iban = targetIban,
                            amount = amount,
                            reason = reason,
                            time = nowTick,
                            type = "credit"
                        })
                    else
                        local charRes = getResourceFromName("gzl_characters")
                        if charRes and exports.gzl_characters and exports.gzl_characters.getCharacterDB then
                            local cDb = exports.gzl_characters:getCharacterDB()
                            if cDb and targetCharId then
                                dbExec(cDb, "UPDATE characters SET bank_money = bank_money + ? WHERE id = ?", amount, targetCharId)
                            end
                        end
                    end

                    sendResponse({ success = true, balance = newSenderBank, transaction = newTxSender })
                else
                    sendResponse({ success = false, message = "Geçersiz IBAN veya hesap numarası!" })
                end
            end, db, "SELECT * FROM phone_users WHERE iban = ? OR phone_number = ? LIMIT 1", targetIban, targetIban)
        else
            sendResponse({ success = false, message = "Yetersiz bakiye!" })
        end

    elseif endpoint == "updateAds" or endpoint == "getAds" then
        dbQuery(function(qh)
            local ads = dbPoll(qh, 0) or {}
            sendResponse(ads)
        end, db, "SELECT * FROM phone_ads ORDER BY time DESC LIMIT ?", Config.AdsLimit or 30)

    elseif endpoint == "postAd" then
        if data and data.title and data.content then
            local nowTick = getRealTime().timestamp
            local authorName = getPlayerName(player)
            dbExec(db, "INSERT INTO phone_ads (owner_number, author, title, content, image, data, time) VALUES (?, ?, ?, ?, ?, ?, ?)",
                myNumber, authorName, tostring(data.title), tostring(data.content), tostring(data.image or ""), toJSON(data.data or {}), nowTick)

            local adObj = {
                owner_number = myNumber,
                author = authorName,
                title = tostring(data.title),
                content = tostring(data.content),
                image = tostring(data.image or ""),
                data = data.data or {},
                time = nowTick
            }
            triggerClientEvent(root, "cylex_phone:addAdvertisment", resourceRoot, adObj)
            sendResponse({ success = true, ad = adObj })
            return
        end
        sendResponse("ok")

    else
        sendResponse("ok")
    end
end)

function sendPhoneNotification(player, title, message, appIcon)
    if isElement(player) then
        triggerClientEvent(player, "cylex_phone:sendNotification", resourceRoot, {
            title = title or "Bildirim",
            content = message or "",
            icon = appIcon or "fa-bell"
        })
    end
end

function getPhoneNumber(player)
    local pData = PlayerData[player]
    return pData and pData.number or getElementData(player, "char:phone")
end

addEvent("cylex_phone:serverUploadPhoto", true)
addEventHandler("cylex_phone:serverUploadPhoto", root, function(photoObj, base64Data)
    local player = client or source
    if not isElement(player) or client and source ~= client or not photoObj then return end
    local pData = PlayerData[player]
    if not pData then return end

    if not pData.photos then pData.photos = {} end
    local found = false
    for _, p in ipairs(pData.photos) do
        if tostring(p.id) == tostring(photoObj.id) then
            found = true
            break
        end
    end
    if not found then
        table.insert(pData.photos, 1, photoObj)
    end

    local db = getPhoneDB()
    local charId = getElementData(player, "char:id") or getElementData(player, "character:id") or getElementData(player, "account:id") or pData.charId or 1
    local myNumber = pData.number or "555-0000"
    if db then
        dbExec(db, "UPDATE phone_users SET photos = ? WHERE phone_number = ? OR char_id = ?", toJSON(pData.photos), myNumber, charId)
    end

    local webhookUrl = Config.DiscordWebhook
    if webhookUrl and #webhookUrl > 15 and string.find(webhookUrl, "discord") and base64Data then
        local rawBytes = decodeString("base64", base64Data)
        if rawBytes then
            local boundary = "----MTAFormBoundary" .. tostring(math.random(10000000, 99999999))
            local payload = string.format('{"content":"📸 **GZL Phone Photo** | %s %s"}', tostring(photoObj.date or ""), tostring(photoObj.time or ""))

            local body = "--" .. boundary .. "\r\n"
            body = body .. 'Content-Disposition: form-data; name="payload_json"\r\n'
            body = body .. 'Content-Type: application/json\r\n\r\n'
            body = body .. payload .. "\r\n"
            body = body .. "--" .. boundary .. "\r\n"
            body = body .. 'Content-Disposition: form-data; name="files[0]"; filename="photo_' .. tostring(photoObj.id) .. '.jpg"\r\n'
            body = body .. 'Content-Type: image/jpeg\r\n\r\n'
            body = body .. rawBytes .. "\r\n"
            body = body .. "--" .. boundary .. "--\r\n"

            local targetUrl = webhookUrl
            if not string.find(targetUrl, "%?") then
                targetUrl = targetUrl .. "?wait=true"
            end

            local options = {
                method = "POST",
                headers = {
                    ["Content-Type"] = "multipart/form-data; boundary=" .. boundary
                },
                postData = body
            }

            fetchRemote(targetUrl, options, function(responseData, errorNo)
                if errorNo == 0 and responseData then
                    local resObj = fromJSON(responseData)
                    if resObj and resObj.attachments and resObj.attachments[1] and resObj.attachments[1].url then
                        local cdnUrl = resObj.attachments[1].url
                        photoObj.src = cdnUrl

                        for _, p in ipairs(pData.photos) do
                            if tostring(p.id) == tostring(photoObj.id) then
                                p.src = cdnUrl
                                break
                            end
                        end

                        if db then
                            dbExec(db, "UPDATE phone_users SET photos = ? WHERE phone_number = ? OR char_id = ?", toJSON(pData.photos), myNumber, charId)
                        end

                        triggerClientEvent(player, "cylex_phone:photoUploaded", resourceRoot, photoObj.id, cdnUrl)
                    end
                end
            end)
        end
    end
end)

addEvent("cylex_phone:syncHoldAnim", true)
addEventHandler("cylex_phone:syncHoldAnim", root, function(enable)
    if not client or source ~= client or type(enable) ~= "boolean" then return end
    local player = client
    if isElement(player) and getElementType(player) == "player" then
        if enable and not isPedDead(player) and not isPedInVehicle(player) then
            setElementData(player, "cylex_phone:holding", true, true)
        else
            setElementData(player, "cylex_phone:holding", false, true)
        end
    end
end)

addEventHandler("onPlayerQuit", root, function()
    setElementData(source, "cylex_phone:holding", nil, true)
end)

addEventHandler("onResourceStop", resourceRoot, function()
    for _, player in ipairs(getElementsByType("player")) do
        if getElementData(player, "cylex_phone:holding") then
            setElementData(player, "cylex_phone:holding", nil, true)
        end
        setPlayerVoiceBroadcastTo(player, nil)
    end
end)

addEventHandler("onPlayerWasted", root, function()
    setElementData(source, "cylex_phone:holding", false, true)
end)

addEventHandler("onPlayerVehicleEnter", root, function()
    if getElementData(source, "cylex_phone:holding") then
        setElementData(source, "cylex_phone:holding", false, true)
    end
end)