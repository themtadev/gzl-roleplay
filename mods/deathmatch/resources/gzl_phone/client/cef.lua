local screenWidth, screenHeight = guiGetScreenSize()
local browser
local browserReady = false
local browserDxVisible = false

local phoneOpen = false
local pendingOpen = false
local closeTimer
local startupTimer
local phoneTyping = false
local bootstrapData = {}
local pendingEndpoints = {}
local queuedIncomingCall
local activeCallNumber = ""

local routeMap = {
    ["callapp:getContacts"] = "updateContacts",
    ["contacts:addContact"] = "createContact",
    ["contacts:editContact"] = "editContact",
    ["contacts:removeContact"] = "deleteContact",
    ["contacts:setBlocked"] = "blockContact",
    ["messages:fetchChatMessages"] = "readMessages",
    ["messages:markAsRead"] = "readMessages",
    ["messages:markAsUnread"] = "markChatAsUnread",
    ["messages:removeSingleMessage"] = "deleteSingleMessage",
    ["messages:removeAllMessage"] = "deleteChat",
    ["messages:clearChatMessages"] = "deleteChat",
    ["messages:sendMessage"] = "sendMessage",
    ["startPhoneCall"] = "startCall",
    ["bank:sendMoney"] = "transferMoney",
    ["notes:saveText"] = "createNote",
    ["notes:removeNote"] = "deleteNote",
    ["gallery:sendPhoto"] = "savePhoto",
    ["gallery:removePhotos"] = "deletePhoto",
    ["gallery:removeBrokenImages"] = "deletePhoto",
    ["twitter:fetchTimeline"] = "viewTweets",
    ["twitter:fetchMore"] = "viewTweets",
    ["sendTweet"] = "postTweet",
    ["likeTweet"] = "likeTweet",
    ["yellowPage:fetchPosts"] = "getAds",
    ["yellowPage:fetchMore"] = "getAds",
    ["yellowpage:sendPost"] = "postAd",
    ["darkchat:sendMessage"] = "sendDarkMessage"
}

local function compactJSON(value)
    local encoded = toJSON(value == nil and {} or value, true)
    return encoded and encoded:sub(2, -2) or "null"
end

local function browserValue(functionName, value)
    if not browserReady or not isElement(browser) then return false end
    local json = compactJSON(value)
    local encoded = encodeString("base64", json)
    if not encoded then return false end
    return executeBrowserJavascript(browser, "window." .. functionName .. "(window.__mtaPhoneDecode('" .. encoded .. "'))" )
end

local function browserCallState(state)
    if not browserReady or not isElement(browser) then return false end
    local stateJSON = compactJSON(tostring(state or ""))
    local numberJSON = compactJSON(tostring(activeCallNumber or ""))
    return executeBrowserJavascript(browser, "window.__mtaPhoneCallState(" .. stateJSON .. "," .. numberJSON .. ")")
end

local function resolveBrowser(id, value, failed)
    if not browserReady or not isElement(browser) then return false end
    local safeId = tostring(id or ""):gsub("[^%w_%-]", "")
    if safeId == "" then return false end
    if not failed and type(value) == "string" and value:match("^data:image/jpeg;base64,[A-Za-z0-9+/=]+$") then
        for offset = 1, #value, 48000 do
            local chunk = value:sub(offset, offset + 47999)
            local complete = offset + 48000 > #value and "true" or "false"
            if not executeBrowserJavascript(browser, "window.__mtaPhoneImagePart('" .. safeId .. "','" .. chunk .. "'," .. complete .. ")") then
                executeBrowserJavascript(browser, "window.__mtaPhoneResolve('" .. safeId .. "',false,'camera_transfer_failed')")
                return false
            end
        end
        return true
    end
    local encoded = encodeString("base64", compactJSON(value))
    if not encoded then return false end
    local errorJSON = failed and compactJSON(tostring(failed)) or "false"
    return executeBrowserJavascript(browser, "window.__mtaPhoneResolve('" .. safeId .. "',window.__mtaPhoneDecode('" .. encoded .. "')," .. errorJSON .. ")")
end

local function sendUI(payload)
    return browserValue("__mtaPhoneReceive", payload)
end

local function sendPhoneEvent(kind, value)
    if not browserReady or not isElement(browser) then return false end
    local kindJSON = compactJSON(kind)
    local encoded = encodeString("base64", compactJSON(value))
    if not encoded then return false end
    return executeBrowserJavascript(browser, "window.__mtaPhoneEvent(" .. kindJSON .. ",window.__mtaPhoneDecode('" .. encoded .. "'))")
end

local function cleanPlayerName()
    return getPlayerName(localPlayer):gsub("#%x%x%x%x%x%x", ""):gsub("_", " ")
end

local function enrichBootstrap(data)
    data = type(data) == "table" and data or {}
    local realTime = getRealTime()
    data.playerName = cleanPlayerName()
    data.identifier = getElementData(localPlayer, "char:id") or getElementData(localPlayer, "character:id") or getElementData(localPlayer, "account:id") or data.phoneNumber or ""
    data.phoneNumber = data.phoneNumber or getElementData(localPlayer, "char:phone") or "555-0000"
    data.iban = data.iban or getElementData(localPlayer, "char:iban") or "GZL-0000"
    data.inGameTime = string.format("%02d:%02d", realTime.hour, realTime.minute)
    data.picture = getElementData(localPlayer, "char:photo") or getElementData(localPlayer, "character:photo") or ""
    data.jobs = data.jobs or {
        allJobs = {},
        groups = {},
        playerJob = getElementData(localPlayer, "char:job") or getElementData(localPlayer, "job") or ""
    }
    return data
end

local function sendBootstrap()
    bootstrapData = enrichBootstrap(bootstrapData)
    return browserValue("__mtaPhoneBootstrap", bootstrapData)
end

local function setHoldAnimation(state)
    CylexHold.set(localPlayer, state)
    triggerServerEvent("cylex_phone:syncHoldAnim", localPlayer, state)
end

local function stopCloseTimer()
    if isTimer(closeTimer) then killTimer(closeTimer) end
    closeTimer = nil
end

local function setBrowserPaused(state)
    if isElement(browser) and type(setBrowserRenderingPaused) == "function" then
        return setBrowserRenderingPaused(browser, state)
    end
    return true
end

local function renderPhoneBrowser()
    if browserDxVisible and isElement(browser) then
        CylexCamera.draw()
        dxDrawImage(0, 0, screenWidth, screenHeight, browser, 0, 0, 0, tocolor(255, 255, 255, 255), true)
    end
end

local function setBrowserDrawVisible(state)
    if state == browserDxVisible then return end
    browserDxVisible = state
    if state then
        addEventHandler("onClientRender", root, renderPhoneBrowser)
    else
        removeEventHandler("onClientRender", root, renderPhoneBrowser)
    end
end

local function showBrowser()
    if not browserReady or not isElement(browser) then return false end
    stopCloseTimer()
    setBrowserPaused(false)

    setBrowserDrawVisible(true)
    executeBrowserJavascript(browser, "window.__mtaPhoneSetActive(true)")
    focusBrowser(browser)
    guiSetInputEnabled(phoneTyping)
    guiSetInputMode(phoneTyping and "no_binds" or "allow_binds")
    CylexHold.setInput(true, phoneTyping)
    showCursor(true, false)
    executeBrowserJavascript(browser, "if(window.__mtaPhoneSyncTyping)window.__mtaPhoneSyncTyping()")
    sendBootstrap()
    sendUI({ action = "open", bool = true })
    if queuedIncomingCall then
        browserValue("__mtaPhoneIncomingCall", queuedIncomingCall)
        queuedIncomingCall = nil
    end
    return true
end

local function hideBrowser(immediate)
    CylexCamera.stop()
    phoneTyping = false
    CylexHold.setInput(false, false)
    if browserReady and isElement(browser) then
        sendUI({ action = "open", bool = false })
    end
    guiSetInputEnabled(false)
    guiSetInputMode("allow_binds")
    showCursor(false, false)
    if isElement(browser) then focusBrowser(nil) end
    stopCloseTimer()
    local function finishHide()
        if phoneOpen then return end
        if isElement(browser) then executeBrowserJavascript(browser, "window.__mtaPhoneSetActive(false)") end
        setBrowserPaused(true)
        setBrowserDrawVisible(false)
    end
    if immediate then
        finishHide()
    else
        closeTimer = setTimer(finishHide, 550, 1)
    end
end

local function requestBootstrap()
    triggerServerEvent("cylex_phone:serverCallback", localPlayer, "getBootstrapData", {}, "bootstrap")
end

local function stopStartupTimer()
    if isTimer(startupTimer) then killTimer(startupTimer) end
    startupTimer = nil
end

local function failBrowserStartup(reason)
    stopStartupTimer()
    phoneOpen = false
    pendingOpen = false
    browserReady = false
    hideBrowser(true)
    setHoldAnimation(false)
    if isElement(browser) then destroyElement(browser) end
    browser = nil
    outputDebugString("[cylex_phone] " .. tostring(reason), 1)
    outputChatBox("Telefon yüklenemedi. F4 ile tekrar deneyebilirsin; hata ayrıntısı F8 konsolunda.", 255, 100, 100)
end

addEvent("cylex_phone:browserReady", true)
addEventHandler("cylex_phone:browserReady", root, function()
    if source ~= browser or browserReady then return end
    stopStartupTimer()
    browserReady = true
    sendUI({ action = "clientLoaded", value = true })
    sendBootstrap()
    requestBootstrap()
    if pendingOpen or phoneOpen then
        pendingOpen = false
        showBrowser()
    else
        hideBrowser(true)
    end
end)

addEvent("cylex_phone:browserFailed", true)
addEventHandler("cylex_phone:browserFailed", root, function(reason)
    if source ~= browser or browserReady then return end
    failBrowserStartup(tostring(reason):sub(1, 1000))
end)

local function createPhoneBrowser()
    if isElement(browser) then return true end
    browser = createBrowser(screenWidth, screenHeight, true, true)
    if not browser then
        outputDebugString("[cylex_phone] CEF browser oluşturulamadı.", 1)
        return false
    end
    startupTimer = setTimer(function()
        failBrowserStartup("CEF arayüzü 30 saniye içinde hazır olmadı.")
    end, 30000, 1)
    addEventHandler("onClientBrowserCreated", browser, function()
        if source ~= browser then return end
        if not loadBrowserURL(browser, "http://mta/local/html/index.html") then
            failBrowserStartup("CEF adresi yüklenemedi.")
        end
    end)
    addEventHandler("onClientBrowserLoadingFailed", browser, function(url, errorCode, errorDescription)
        if source ~= browser then return end
        if url and url:find("http://mta/local/html/index.html", 1, true) == 1 then
            failBrowserStartup("CEF yüklenemedi: " .. tostring(url) .. " (" .. tostring(errorCode) .. ") " .. tostring(errorDescription))
        end
    end)
    addEventHandler("onClientBrowserDocumentReady", browser, function()
        if source ~= browser then return end
        executeBrowserJavascript(browser, "if(window.__mtaPhoneNotifyReady)window.__mtaPhoneNotifyReady()")
    end)
    return true
end

local function hasCharacter()
    return getElementData(localPlayer, "char:id") or getElementData(localPlayer, "character:id") or getElementData(localPlayer, "loggedin_character") or getElementData(localPlayer, "account:id")
end

function togglePhone(forceState)
    local targetState = forceState
    if type(targetState) ~= "boolean" then targetState = not phoneOpen end
    if targetState == phoneOpen then return phoneOpen end
    if targetState then
        local dxPhone = getResourceFromName("high_phone")
        if dxPhone and getResourceState(dxPhone) == "running" and exports.high_phone and exports.high_phone.isPhoneOpenState and exports.high_phone.togglePhone and exports.high_phone:isPhoneOpenState() then
            exports.high_phone:togglePhone(false)
        end
    end
    phoneOpen = targetState
    if phoneOpen then
        pendingOpen = true
        setHoldAnimation(true)
        if not createPhoneBrowser() then
            phoneOpen = false
            pendingOpen = false
            setHoldAnimation(false)
            return false
        end
        if browserReady then
            pendingOpen = false
            showBrowser()
            requestBootstrap()
        end
    else
        pendingOpen = false
        setHoldAnimation(false)
        hideBrowser(false)
    end
    return phoneOpen
end

addEvent("gzl_phone:togglePhone", true)
addEventHandler("gzl_phone:togglePhone", root, function(forceState)
    togglePhone(forceState)
end)

addEvent("high_phone:togglePhone", true)
addEventHandler("high_phone:togglePhone", root, function(forceState)
    togglePhone(forceState)
end)

function isPhoneOpenState()
    return phoneOpen
end

function isKeypadTypingActive()
    return phoneOpen and phoneTyping
end

addEvent("cylex_phone:typing", true)
addEventHandler("cylex_phone:typing", root, function(state)
    if source ~= browser or not phoneOpen or type(state) ~= "boolean" then return end
    phoneTyping = state
    CylexHold.setInput(true, state)
    guiSetInputEnabled(state)
    guiSetInputMode(state and "no_binds" or "allow_binds")
    if isElement(browser) and state then
        focusBrowser(browser)
    end
end)

local function transformRequest(endpoint, data)
    data = type(data) == "table" and data or {}
    if endpoint == "contacts:addContact" then
        return {
            name = tostring(data.firstname or "") .. " " .. tostring(data.lastname or ""),
            number = data.phoneNumber,
            photo = data.picture or data.avatar,
            tag = data.tag
        }
    end
    if endpoint == "contacts:editContact" then
        local newData = type(data.newData) == "table" and data.newData or data
        return {
            id = newData.id or (type(data.oldData) == "table" and data.oldData.id),
            name = tostring(newData.firstname or "") .. " " .. tostring(newData.lastname or ""),
            number = newData.phoneNumber,
            photo = newData.picture or newData.avatar,
            tag = newData.tag
        }
    end
    if endpoint == "contacts:removeContact" then
        local oldData = type(data.oldData) == "table" and data.oldData or data
        return { id = oldData.id }
    end
    if endpoint == "contacts:setBlocked" then
        return { number = data.phoneNumber or data.number, blocked = data.blocked }
    end
    if endpoint:find("^messages:") then
        local target = data.selectedMessageId or data.messageId or data.number or data.targetNumber or data.target
        if not target and type(data.list) == "table" and type(data.list[1]) == "table" then
            target = data.list[1].phoneNumber or data.list[1].number or data.list[1].target
        end
        local attachment = {}
        if data.image then attachment.image = data.image end
        if data.video then attachment.video = data.video end
        if data.audio then attachment.audio = data.audio end
        if data.coords then attachment.coords = data.coords end
        return {
            number = target,
            targetNumber = target,
            target = target,
            message = data.message or data.text or "",
            time = type(data.msgData) == "table" and data.msgData.time or data.time,
            attachments = attachment,
            permanent = true
        }
    end
    if endpoint == "startPhoneCall" then
        activeCallNumber = tostring(data.number or "")
        return { targetNumber = activeCallNumber, targetName = data.name }
    end
    if endpoint == "bank:sendMoney" then
        return { iban = data.iban, target = data.iban, amount = tonumber(data.amount), reason = data.reason or "Telefon transferi" }
    end
    if endpoint == "notes:saveText" then
        local note = type(data.selected) == "table" and data.selected or data
        return { id = note.id, title = note.title or "Not", content = note.text or note.content or "", date = note.date or "Bugün" }
    end
    if endpoint == "notes:removeNote" then
        local note = type(data.selected) == "table" and data.selected or data
        return { id = note.id }
    end
    if endpoint == "gallery:sendPhoto" then
        return { id = data.id, src = data.url or data.src, photo = data.url or data.src, date = data.date, time = data.time }
    end
    if endpoint == "gallery:removePhotos" or endpoint == "gallery:removeBrokenImages" then
        return { ids = data.ids, id = data.id }
    end
    if endpoint == "sendTweet" then
        return { content = data.text or data.content, image = data.image, mentions = data.mentions, quotedTweet = data.quotedTweet }
    end
    if endpoint == "yellowpage:sendPost" then
        return { title = data.title, content = data.text or data.content, image = type(data.images) == "table" and data.images[1] or data.image, data = data }
    end
    if endpoint == "darkchat:sendMessage" then
        return { text = data.message or data.text, image = data.image, selectedMessageId = data.selectedMessageId }
    end
    return data
end

local function sendWaypoint(data)
    local coords = type(data) == "table" and (data.coords or data.location) or nil
    if type(coords) ~= "table" then return false end
    local x = tonumber(coords.x or coords[1])
    local y = tonumber(coords.y or coords[2])
    if not x or not y then return false end
    local radar = getResourceFromName("gzl_radar")
    if radar and getResourceState(radar) == "running" and exports.gzl_radar and exports.gzl_radar.setWaypoint then
        exports.gzl_radar:setWaypoint(x, y)
        return true
    end
    return false
end

addEvent("cylex_phone:cameraViewport", true)
addEventHandler("cylex_phone:cameraViewport", root, function(body)
    if source ~= browser or not phoneOpen or type(body) ~= "string" or #body > 4096 then return end
    local data = fromJSON(body)
    if type(data) == "table" then CylexCamera.setViewport(data) end
end)

addEvent("cylex_phone:browserRequest", true)
addEventHandler("cylex_phone:browserRequest", root, function(id, endpoint, body)
    if source ~= browser or type(id) ~= "string" or #id > 16 or type(endpoint) ~= "string" or #endpoint > 80 or not endpoint:match("^[%w_:%-]+$") then return end
    if type(body) ~= "string" or #body > 250000 then
        resolveBrowser(id, false, "invalid_payload")
        return
    end
    local data = fromJSON(body)
    if type(data) ~= "table" then data = {} end
    if endpoint == "JSLoaded" then
        resolveBrowser(id, { success = true })
        return
    end
    if endpoint == "camera:takePhoto" or endpoint == "camera:frame" then
        if not phoneOpen then resolveBrowser(id, false, "camera_closed") return end
        CylexCamera.capture(endpoint == "camera:takePhoto", function(value, failure)
            resolveBrowser(id, value, failure)
        end)
        return
    end
    if endpoint:find("^camera:") then
        if not phoneOpen and endpoint ~= "camera:close" then resolveBrowser(id, false, "phone_closed") return end
        resolveBrowser(id, CylexCamera.handle(endpoint, data))
        return
    end
    if endpoint == "messages:getConversations" or endpoint == "messages:getSpecificMessage" then
        resolveBrowser(id, { success = true })
        return
    end
    if endpoint == "genericCallResponse" then
        local serverEndpoint = data.action == "accept" and "pickupCall" or "endCall"
        pendingEndpoints[id] = endpoint
        triggerServerEvent("cylex_phone:serverCallback", localPlayer, serverEndpoint, {}, id)
        return
    end
    if endpoint == "userData:getData" then
        resolveBrowser(id, {
            iban = bootstrapData.iban,
            picture = bootstrapData.picture,
            phoneNumber = bootstrapData.phoneNumber,
            firstname = cleanPlayerName():match("^(%S+)") or cleanPlayerName()
        })
        return
    end
    if endpoint == "userData:changePhoneData" then
        bootstrapData.settings = type(bootstrapData.settings) == "table" and bootstrapData.settings or {}
        if data.key then bootstrapData.settings[data.key] = data.value end
        pendingEndpoints[id] = endpoint
        triggerServerEvent("cylex_phone:serverCallback", localPlayer, "updateSettings", { settings = bootstrapData.settings }, id)
        return
    end
    if endpoint == "message:waypoint" or endpoint:find(":waypoint$") or endpoint == "garage:markVehicle" or endpoint == "house:markHouse" or endpoint == "racing:locateRacing" then
        resolveBrowser(id, { success = sendWaypoint(data) })
        return
    end
    local serverEndpoint = routeMap[endpoint]
    if not serverEndpoint then
        resolveBrowser(id, { success = true })
        return
    end
    pendingEndpoints[id] = endpoint
    triggerServerEvent("cylex_phone:serverCallback", localPlayer, serverEndpoint, transformRequest(endpoint, data), id)
end)

addEvent("cylex_phone:closeRequest", true)
addEventHandler("cylex_phone:closeRequest", root, function()
    if source == browser then togglePhone(false) end
end)

addEvent("cylex_phone:serverCallbackResponse", true)
addEventHandler("cylex_phone:serverCallbackResponse", root, function(cbId, data)
    if cbId == "bootstrap" then
        if type(data) == "table" and data.phoneNumber then
            bootstrapData = enrichBootstrap(data)
            sendBootstrap()
        end
        return
    end
    local endpoint = pendingEndpoints[tostring(cbId)] or pendingEndpoints[cbId]
    pendingEndpoints[tostring(cbId)] = nil
    pendingEndpoints[cbId] = nil
    if endpoint == "messages:sendMessage" and type(data) == "table" and type(data.message) == "table" then
        sendPhoneEvent("message", data.message)
    elseif endpoint == "bank:sendMoney" and type(data) == "table" and data.success then
        bootstrapData.bankBalance = data.balance or bootstrapData.bankBalance
        if type(data.transaction) == "table" then sendPhoneEvent("transaction", data.transaction) end
    elseif endpoint == "sendTweet" and type(data) == "table" and type(data.tweet) == "table" then
        sendPhoneEvent("tweet", data.tweet)
    end
    resolveBrowser(cbId, data)
end)

addEvent("cylex_phone:receiveBootstrapData", true)
addEventHandler("cylex_phone:receiveBootstrapData", root, function(data)
    bootstrapData = enrichBootstrap(data)
    sendBootstrap()
end)

addEvent("cylex_phone:clientInitData", true)
addEventHandler("cylex_phone:clientInitData", root, function(data)
    if type(data) ~= "table" then return end
    bootstrapData.phoneNumber = data.number or bootstrapData.phoneNumber
    bootstrapData.iban = data.iban or bootstrapData.iban
    bootstrapData.settings = data.settings or bootstrapData.settings
    bootstrapData.calls = data.calls or bootstrapData.calls
    bootstrapData.notes = data.notes or bootstrapData.notes
    bootstrapData.photos = data.photos or bootstrapData.photos
end)

addEvent("cylex_phone:incomingCall", true)
addEventHandler("cylex_phone:incomingCall", root, function(data)
    queuedIncomingCall = data
    activeCallNumber = tostring(data and (data.number or data.callerNumber) or "")
    togglePhone(true)
    if browserReady and queuedIncomingCall then
        browserValue("__mtaPhoneIncomingCall", queuedIncomingCall)
        queuedIncomingCall = nil
    end
end)

addEvent("cylex_phone:changeCallStatus", true)
addEventHandler("cylex_phone:changeCallStatus", root, function(status)
    browserCallState(status)
end)

addEvent("cylex_phone:endCall", true)
addEventHandler("cylex_phone:endCall", root, function()
    browserCallState("ended")
    activeCallNumber = ""
end)

addEvent("cylex_phone:cantReach", true)
addEventHandler("cylex_phone:cantReach", root, function()
    browserCallState("ended")
    sendPhoneEvent("notification", {
        title = "Telefon",
        text = "Numaraya ulaşılamıyor",
        timeout = 4,
        type = "notification",
        icon = { name = "app-icon/call.png" }
    })
    activeCallNumber = ""
end)

addEvent("cylex_phone:syncCallHistory", true)
addEventHandler("cylex_phone:syncCallHistory", root, function(calls)
    bootstrapData.calls = calls or {}
    bootstrapData.callHistory = bootstrapData.calls
    sendPhoneEvent("calls", bootstrapData.calls)
end)

local function receiveMessage(data)
    if type(data) ~= "table" then return end
    sendPhoneEvent("message", data)
end

addEvent("cylex_phone:incomingMessage", true)
addEventHandler("cylex_phone:incomingMessage", root, receiveMessage)

addEvent("cylex_phone:receivedMessage", true)
addEventHandler("cylex_phone:receivedMessage", root, receiveMessage)

addEvent("cylex_phone:newTransaction", true)
addEventHandler("cylex_phone:newTransaction", root, function(data)
    sendPhoneEvent("transaction", data)
end)

addEvent("cylex_phone:receivedDarkMessage", true)
addEventHandler("cylex_phone:receivedDarkMessage", root, function(data)
    sendPhoneEvent("dark-message", data)
end)

addEvent("cylex_phone:addTweet", true)
addEventHandler("cylex_phone:addTweet", root, function(data)
    sendPhoneEvent("tweet", data)
end)

addEvent("cylex_phone:tweetLiked", true)
addEventHandler("cylex_phone:tweetLiked", root, function(id, likes)
    sendPhoneEvent("tweet-likes", { id = id, likes = likes })
end)

addEvent("cylex_phone:sendNotification", true)
addEventHandler("cylex_phone:sendNotification", root, function(data)
    sendPhoneEvent("notification", data)
end)

addEvent("cylex_phone:photoUploaded", true)
addEventHandler("cylex_phone:photoUploaded", root, function(id, url)
    sendPhoneEvent("photo", { id = id, url = url })
end)

addEvent("cylex_phone:emergencyDispatch", true)
addEventHandler("cylex_phone:emergencyDispatch", root, function(data)
    sendPhoneEvent("notification", {
        title = data.serviceName or "Acil çağrı",
        text = tostring(data.callerName or "") .. " - " .. tostring(data.district or ""),
        timeout = 8,
        type = "notification",
        icon = { name = "app-icon/company.png" },
        _data = data
    })
end)

addEventHandler("onClientPlayerVehicleEnter", localPlayer, function()
    if phoneOpen then togglePhone(false) end
end)

addEventHandler("onClientPlayerWasted", localPlayer, function()
    if phoneOpen then togglePhone(false) end
end)

addEvent("auth:showLoginScreen", true)
addEventHandler("auth:showLoginScreen", root, function()
    if phoneOpen then togglePhone(false) end
end)

addEvent("char:receiveList", true)
addEventHandler("char:receiveList", root, function()
    if phoneOpen then togglePhone(false) end
end)

addEventHandler("onClientResourceStart", resourceRoot, function()
    guiSetInputMode("allow_binds")
    triggerServerEvent("cylex_phone:clientReady", localPlayer)
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    CylexCamera.stop()
    stopCloseTimer()
    stopStartupTimer()
    setBrowserDrawVisible(false)

    phoneOpen = false
    pendingOpen = false
    guiSetInputEnabled(false)
    guiSetInputMode("allow_binds")
    showCursor(false, false)
    CylexHold.setInput(false, false)
    triggerServerEvent("cylex_phone:syncHoldAnim", localPlayer, false)
    setBrowserPaused(true)
    if isElement(browser) then destroyElement(browser) end
    browser = nil
end)

addEventHandler("onClientCursorMove", root, function(_, _, absoluteX, absoluteY)
    if phoneOpen and browserReady and isElement(browser) then
        injectBrowserMouseMove(browser, absoluteX, absoluteY)
    end
end)

addEventHandler("onClientClick", root, function(button, state)
    if phoneOpen and browserReady and isElement(browser) then
        if state == "down" then
            focusBrowser(browser)
            injectBrowserMouseDown(browser, button)
        else
            injectBrowserMouseUp(browser, button)
        end
    end
end)

addEventHandler("onClientKey", root, function(button, press)
    if not phoneOpen or not press or not isElement(browser) then return end
    if button == "mouse_wheel_up" then
        injectBrowserMouseWheel(browser, 40, 0)
    elseif button == "mouse_wheel_down" then
        injectBrowserMouseWheel(browser, -40, 0)
    elseif button == string.lower(Config.OpenKey or "f1") then
        togglePhone(false)
        cancelEvent()
    end
end)

bindKey(string.lower(Config.OpenKey or "f1"), "down", function()
    togglePhone()
end)

addCommandHandler(Config.Command or "telefon", function()
    togglePhone()
end)

addCommandHandler("phone", function()
    togglePhone()
end)