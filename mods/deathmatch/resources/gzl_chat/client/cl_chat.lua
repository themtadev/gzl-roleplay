local screenW, screenH = guiGetScreenSize()
local guiBrowserElem = nil
local chatBrowser = nil
local isBrowserReady = false
local chatInputActive = false
local isChatVisible = true
local ignoreCharTick = 0

local chatW = math.max(520, math.floor(screenW * 0.35))
local chatH = math.max(480, math.floor(screenH * 0.45))

addEvent("chat:addMessage", true)
addEvent("chat:addSuggestion", true)
addEvent("chat:addSuggestions", true)
addEvent("chat:removeSuggestion", true)
addEvent("chat:resetSuggestions", true)
addEvent("chat:addTemplate", true)
addEvent("chat:client:ClearChat", true)
addEvent("chat:clear", true)
addEvent("chat:onNuiCallback", true)

local function sendNuiMessage(data)
    if not chatBrowser or not isElement(chatBrowser) then return end
    local jsonStr = toJSON(data, true)
    if jsonStr:sub(1, 1) == "[" and jsonStr:sub(-1) == "]" then
        jsonStr = jsonStr:sub(2, -2)
    end
    executeBrowserJavascript(chatBrowser, string.format("if (window.sendNuiMessage) { window.sendNuiMessage(%s); }", jsonStr))
end

local function initChatBrowser()
    if isElement(guiBrowserElem) then return end

    guiBrowserElem = guiCreateBrowser(20, 20, chatW, chatH, true, true, false)
    if not guiBrowserElem then return end

    guiSetVisible(guiBrowserElem, true)
    guiMoveToBack(guiBrowserElem)
    pcall(guiSetInputMode, "allow_binds")
    chatBrowser = guiGetBrowser(guiBrowserElem)

    if chatBrowser and isElement(chatBrowser) then
        addEventHandler("onClientBrowserCreated", chatBrowser, function()
            loadBrowserURL(source, "http://mta/local/html/index.html")
        end)

        addEventHandler("onClientBrowserDocumentReady", chatBrowser, function()
            isBrowserReady = true
            triggerServerEvent("chat:init", resourceRoot)
        end)
    end
end

local isInAuthScreen = false

local function isCharacterLoaded()
    return (getElementData(localPlayer, "character:id") or getElementData(localPlayer, "char:id") or getElementData(localPlayer, "loggedin_character")) and true or false
end

local function canUseChat()
    if isInAuthScreen then return false end
    if not isCharacterLoaded() then return false end
    return true
end

function openChat(initialText)
    if not canUseChat() then return end
    if chatInputActive then return end
    if isChatBoxInputActive() or isConsoleActive() then return end
    if not isElement(guiBrowserElem) then initChatBrowser() end

    ignoreCharTick = getTickCount()
    chatInputActive = true
    isChatVisible = true
    setElementData(localPlayer, "gzl_chat:isOpen", true, false)

    guiSetVisible(guiBrowserElem, true)
    guiBringToFront(guiBrowserElem)
    guiFocus(guiBrowserElem)
    if chatBrowser and isElement(chatBrowser) then
        focusBrowser(chatBrowser)
    end
    pcall(guiSetInputMode, "no_binds")
    pcall(guiSetInputEnabled, true)
    showCursor(true, true)

    setTimer(function()
        if chatInputActive and isElement(guiBrowserElem) then
            guiBringToFront(guiBrowserElem)
            guiFocus(guiBrowserElem)
            if chatBrowser and isElement(chatBrowser) then
                focusBrowser(chatBrowser)
            end
        end
    end, 50, 1)

    sendNuiMessage({
        type = "ON_OPEN",
        message = initialText or ""
    })
end

function closeChat()
    if not chatInputActive then return end
    chatInputActive = false
    setElementData(localPlayer, "gzl_chat:isOpen", false, false)
    setElementData(localPlayer, "gzl_chat:lastClosedTick", getTickCount(), false)
    showCursor(false)
    if chatBrowser and isElement(chatBrowser) then
        focusBrowser(nil)
    end
    if isElement(guiBrowserElem) then
        guiBlur(guiBrowserElem)
        guiMoveToBack(guiBrowserElem)
    end
    pcall(guiSetInputEnabled, false)
    pcall(guiSetInputMode, "allow_binds")

    sendNuiMessage({
        type = "ON_CLOSE"
    })
end

function setChatVisible(state)
    isChatVisible = (state == true)
    if isElement(guiBrowserElem) then
        guiSetVisible(guiBrowserElem, isChatVisible)
    end
    if not isChatVisible and chatInputActive then
        closeChat()
    end
end
addEvent("chat:setChatVisible", true)
addEventHandler("chat:setChatVisible", root, setChatVisible)

function isChatInputOpen()
    return chatInputActive == true
end

addEventHandler("onClientPreRender", root, function()
    showChat(false)

    local active = canUseChat()
    local isPaused = isMainMenuActive() or isTransferBoxActive()

    if (not active or isPaused) and chatInputActive then
        closeChat()
    end
end)

local clientCommands = {
    ["cleardebug"] = function()
        pcall(clearDebugBox)
    end,
    ["reloadmods"] = function()
        triggerEvent("gzl_mods:clientReload", root)
    end,
    ["clear"] = function()
        clearChat()
    end,
    ["clearchat"] = function()
        clearChat()
    end,
    ["inventory"] = function()
        if exports.gzl_inventory and exports.gzl_inventory.toggleInventory then
            exports.gzl_inventory:toggleInventory()
        end
    end,
    ["inv"] = function()
        if exports.gzl_inventory and exports.gzl_inventory.toggleInventory then
            exports.gzl_inventory:toggleInventory()
        end
    end,
    ["hotbar"] = function()
        if exports.gzl_inventory and exports.gzl_inventory.toggleHotbarDisplay then
            exports.gzl_inventory:toggleHotbarDisplay()
        end
    end,
    ["hud"] = function()
        if exports.gzl_hud and exports.gzl_hud.toggleSettings then
            exports.gzl_hud:toggleSettings()
        end
    end,
    ["map"] = function()
        if exports.gzl_radar and exports.gzl_radar.togglePauseMenu then
            exports.gzl_radar:togglePauseMenu()
        end
    end
}

addEventHandler("chat:onNuiCallback", root, function(eventName, payloadJson)
    local data = fromJSON(payloadJson)
    if data == nil then
        data = tonumber(payloadJson) or payloadJson
    end

    if eventName == "loaded" then
        isBrowserReady = true
        triggerServerEvent("chat:init", resourceRoot)
    elseif eventName == "chatResult" then
        closeChat()

        if type(data) == "table" and not data.canceled and data.message and data.message ~= "" then
            local msg = data.message
            if msg:sub(1, 1) == "/" then
                local fullCmd = msg:sub(2)
                local parts = {}
                for part in string.gmatch(fullCmd, "%S+") do
                    table.insert(parts, part)
                end

                if #parts > 0 then
                    local cmdName = parts[1]:lower()
                    table.remove(parts, 1)

                    if clientCommands[cmdName] then
                        clientCommands[cmdName](unpack(parts))
                    else
                        local executed = false
                        pcall(function()
                            executed = executeCommandHandler(cmdName, table.concat(parts, " "))
                        end)
                        if not executed then
                            triggerServerEvent("chat:commandEntered", resourceRoot, cmdName, table.concat(parts, " "), fullCmd, parts)
                        end
                    end
                end
            else
                triggerServerEvent("chat:messageEntered", resourceRoot, getPlayerName(localPlayer), { 255, 255, 255 }, msg)
            end
        end
    end
end)

function addMessage(message)
    if not isBrowserReady and not isElement(guiBrowserElem) then
        initChatBrowser()
    end
    sendNuiMessage({
        type = "ON_MESSAGE",
        message = message
    })
end
addEventHandler("chat:addMessage", root, addMessage)

function addSuggestion(name, help, params)
    sendNuiMessage({
        type = "ON_SUGGESTION_ADD",
        suggestion = {
            name = name,
            help = help or "",
            params = params or {}
        }
    })
end
addEventHandler("chat:addSuggestion", root, addSuggestion)

function addSuggestions(suggestions)
    if type(suggestions) == "table" then
        for _, s in ipairs(suggestions) do
            sendNuiMessage({
                type = "ON_SUGGESTION_ADD",
                suggestion = s
            })
        end
    end
end
addEventHandler("chat:addSuggestions", root, addSuggestions)

function removeSuggestion(name)
    sendNuiMessage({
        type = "ON_SUGGESTION_REMOVE",
        name = name
    })
end
addEventHandler("chat:removeSuggestion", root, removeSuggestion)

addEventHandler("chat:resetSuggestions", root, function()
    sendNuiMessage({
        type = "ON_COMMANDS_RESET"
    })
end)

addEventHandler("chat:addTemplate", root, function(id, html)
    sendNuiMessage({
        type = "ON_TEMPLATE_ADD",
        template = {
            id = id,
            html = html
        }
    })
end)

function clearChat()
    sendNuiMessage({
        type = "ON_CLEAR"
    })
end
addEventHandler("chat:client:ClearChat", root, clearChat)
addEventHandler("chat:clear", root, clearChat)

local player3DTexts = {}

addEvent("chat:onPlayer3DText", true)
addEventHandler("chat:onPlayer3DText", root, function(sender, text, textType)
    if not isElement(sender) or not text or text == "" then return end
    if not player3DTexts[sender] then
        player3DTexts[sender] = {}
    end

    table.insert(player3DTexts[sender], {
        text = text,
        type = textType or "me",
        startTick = getTickCount(),
        duration = 6500
    })

    if #player3DTexts[sender] > 3 then
        table.remove(player3DTexts[sender], 1)
    end
end)

addEventHandler("onClientRender", root, function()
    local now = getTickCount()
    local cx, cy, cz = getCameraMatrix()
    local myDim = getElementDimension(localPlayer)
    local myInt = getElementInterior(localPlayer)

    for player, list in pairs(player3DTexts) do
        if isElement(player) and getElementDimension(player) == myDim and getElementInterior(player) == myInt and isElementOnScreen(player) then

            for i = #list, 1, -1 do
                if (now - list[i].startTick) > list[i].duration then
                    table.remove(list, i)
                end
            end

            if #list > 0 then
                local px, py, pz = getPedBonePosition(player, 3)
                if not px then
                    local bx, by, bz = getElementPosition(player)
                    px, py, pz = bx, by, bz + 0.3
                end

                local dist = getDistanceBetweenPoints3D(cx, cy, cz, px, py, pz)
                if dist <= 22.0 and isLineOfSightClear(cx, cy, cz, px, py, pz, true, false, false, true, false, false, false, player) then
                    for idx, item in ipairs(list) do
                        local elapsed = now - item.startTick
                        local alpha = 255
                        if elapsed > (item.duration - 1500) then
                            alpha = math.floor(255 * (1 - (elapsed - (item.duration - 1500)) / 1500))
                        end

                        local offsetZ = 0.08 - ((idx - 1) * 0.14)
                        local sx, sy = getScreenFromWorldPosition(px, py, pz + offsetZ, 0.05)
                        if sx and sy then
                            local scale = math.max(0.75, (1.0 - (dist / 28.0))) * 1.35
                            local r, g, b = 194, 162, 218
                            if item.type == "do" then
                                r, g, b = 0, 255, 255
                            elseif item.type == "dice" then
                                r, g, b = 255, 187, 51
                            end

                            local displayText = item.text
                            local font = "default-bold"

                            dxDrawText(displayText, sx - 1, sy - 1, sx - 1, sy - 1, tocolor(0, 0, 0, alpha), scale, font, "center", "center")
                            dxDrawText(displayText, sx + 1, sy - 1, sx + 1, sy - 1, tocolor(0, 0, 0, alpha), scale, font, "center", "center")
                            dxDrawText(displayText, sx - 1, sy + 1, sx - 1, sy + 1, tocolor(0, 0, 0, alpha), scale, font, "center", "center")
                            dxDrawText(displayText, sx + 1, sy + 1, sx + 1, sy + 1, tocolor(0, 0, 0, alpha), scale, font, "center", "center")

                            dxDrawText(displayText, sx, sy, sx, sy, tocolor(r, g, b, alpha), scale, font, "center", "center")
                        end
                    end
                end
            end
        else
            player3DTexts[player] = nil
        end
    end
end)

addEventHandler("onClientChatMessage", root, function(text, r, g, b)
    cancelEvent()
    addMessage({
        type = "BİLGİ",
        typeColor = "#3b82f6",
        header = "BİLGİ",
        content = text
    })
end)

addEventHandler("onClientCharacter", root, function(char)
    if (getTickCount() - ignoreCharTick) < 120 then
        cancelEvent()
    end
end)

addEventHandler("onClientKey", root, function(button, press)
    if not press then return end

    if chatInputActive then
        if button == "escape" then
            cancelEvent()
            closeChat()
        end
    else
        if not canUseChat() then return end
        if not isChatBoxInputActive() and not isConsoleActive() then
            if button == "t" or button == "y" then
                cancelEvent()
                openChat("")
            elseif button == "/" then
                cancelEvent()
                openChat("/")
            end
        end
    end
end)

addEvent("auth:showLoginScreen", true)
addEventHandler("auth:showLoginScreen", root, function()
    isInAuthScreen = true
    setChatVisible(false)
    closeChat()
end)

addEvent("char:spawnSuccess", true)
addEventHandler("char:spawnSuccess", root, function()
    isInAuthScreen = false
    setChatVisible(true)
end)

addEventHandler("onClientPlayerSpawn", localPlayer, function()
    if isCharacterLoaded() then
        isInAuthScreen = false
        setChatVisible(true)
    end
end)

addEventHandler("onClientElementDataChange", localPlayer, function(dataName)
    if dataName == "character:id" or dataName == "char:id" or dataName == "loggedin_character" then
        if canUseChat() then
            setChatVisible(true)
        else
            setChatVisible(false)
            closeChat()
        end
    end
end)

addEventHandler("onClientResourceStart", resourceRoot, function()
    showChat(false)
    pcall(guiSetInputMode, "allow_binds")
    initChatBrowser()
    setChatVisible(canUseChat())
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    showChat(true)
    if isElement(guiBrowserElem) then
        destroyElement(guiBrowserElem)
    end
end)

addCommandHandler("openchat", function()
    openChat("")
end)

addCommandHandler("clearchat", function()
    clearChat()
end)

addCommandHandler("clear", function()
    clearChat()
end)

addCommandHandler("cleardebug", function()
    pcall(clearDebugBox)
end)