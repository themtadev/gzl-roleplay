local screenW, screenH = guiGetScreenSize()
local browserGUI
local browser
local pageReady = false
local serverReady = false
local currentProgress = 0
local totalResources = 0
local loadedResources = 0
local startedAt = getTickCount()
local completionSent = false
local updateTimer
local wasChatVisible = isChatVisible()
local loadingDurationMs = 30000
local loadingActive = true

local socialLinks = {
    discord = "discord.gg/gzlroleplay",
    x = "x.com/gzlroleplay",
    tiktok = "tiktok.com/@gzlroleplay",
    linkedin = "linkedin.com/company/gzlroleplay",
    instagram = "instagram.com/gzlroleplay"
}

local function isResourceRunning(name)
    local resource = getResourceFromName(name)
    return resource and getResourceState(resource) == "running"
end

local function hasActiveCharacter()
    return getElementData(localPlayer, "char:id") or getElementData(localPlayer, "character:id") or getElementData(localPlayer, "loggedin_character")
end

local function suppressInterface()
    if not loadingActive or hasActiveCharacter() then return end
    showChat(false)
    setPlayerHudComponentVisible("all", false)

    if isResourceRunning("gzl_hud") and exports.gzl_hud and type(exports.gzl_hud.setHUDVisible) == "function" then
        exports.gzl_hud:setHUDVisible(false)
    end
    if isResourceRunning("gzl_chat") and exports.gzl_chat and type(exports.gzl_chat.setChatVisible) == "function" then
        exports.gzl_chat:setChatVisible(false)
    end
    if isResourceRunning("gzl_radar") and exports.gzl_radar and type(exports.gzl_radar.setRadarVisible) == "function" then
        exports.gzl_radar:setRadarVisible(false)
    end
end

local function restoreInterface()
    if not hasActiveCharacter() then return false end
    showChat(wasChatVisible)
    setPlayerHudComponentVisible("all", false)
    setPlayerHudComponentVisible("crosshair", true)
    if isResourceRunning("gzl_hud") and exports.gzl_hud and type(exports.gzl_hud.setHUDVisible) == "function" then
        exports.gzl_hud:setHUDVisible(true)
    end
    if isResourceRunning("gzl_radar") and exports.gzl_radar and type(exports.gzl_radar.setRadarVisible) == "function" then
        exports.gzl_radar:setRadarVisible(true)
    end
    return true
end

local function callBrowser(functionName, payload)
    if not pageReady or not isElement(browser) then return false end
    local data = toJSON(payload or {}, true)
    return executeBrowserJavascript(browser, "window." .. functionName .. "(" .. data .. ")")
end

local function getDisplayProgress()
    local elapsed = getTickCount() - startedAt
    local ratio = elapsed / loadingDurationMs
    local readyToEnter = serverReady and not isTransferBoxActive()

    if elapsed < loadingDurationMs or not readyToEnter then
        ratio = math.min(ratio, 0.99)
    else
        ratio = 1
    end

    return math.floor(math.max(0, math.min(1, ratio)) * 100)
end

local function closeLoadingScreen()
    loadingActive = false
    showCursor(false)
    focusBrowser(nil)
    pcall(guiSetInputMode, "allow_binds")
    if isElement(browserGUI) then
        destroyElement(browserGUI)
    end
    browserGUI = nil
    browser = nil
    pageReady = false

    if isTimer(updateTimer) then
        killTimer(updateTimer)
        updateTimer = nil
    end

    fadeCamera(true, 1.2)

    if not restoreInterface() and getElementData(localPlayer, "loggedin") then
        showChat(false)
        setPlayerHudComponentVisible("all", false)
    elseif not hasActiveCharacter() then
        showChat(false)
        setPlayerHudComponentVisible("all", false)
    end
end

local function updateLoadingScreen()
    if not pageReady then return end

    local percent = getDisplayProgress()
    callBrowser("setLoadingState", {
        percent = percent,
        loaded = loadedResources,
        total = totalResources,
        status = percent >= 100 and "Oyun hazır" or "Oyun yükleniyor"
    })

    local canComplete = serverReady and not isTransferBoxActive() and getTickCount() - startedAt >= loadingDurationMs
    if canComplete and not completionSent then
        completionSent = true
        callBrowser("completeLoading", {})
        setTimer(closeLoadingScreen, 1400, 1)
    end
end

addEvent("gzl_loading:status", true)
addEventHandler("gzl_loading:status", resourceRoot, function(progress, total, busy, ready)
    currentProgress = math.max(0, tonumber(progress) or 0)
    totalResources = math.max(0, tonumber(total) or 0)
    serverReady = ready == true and busy ~= true
    updateLoadingScreen()
end)

addEvent("gzl_loading:close", false)
addEventHandler("gzl_loading:close", root, function()
    if source ~= browser then return end
    closeLoadingScreen()
end)

addEvent("gzl_loading:social", false)
addEventHandler("gzl_loading:social", root, function(platform)
    if source ~= browser or type(platform) ~= "string" then return end
    local link = socialLinks[platform]
    if not link then return end
    setClipboard("https://" .. link)
    callBrowser("showToast", { text = link .. " panoya kopyalandı" })
end)

addEventHandler("onClientResourceStart", root, function(startedResource)
    if hasActiveCharacter() then return end
    if source == resourceRoot or not loadingActive or completionSent or not isElement(browserGUI) then return end
    loadedResources = loadedResources + 1
    suppressInterface()
    setTimer(suppressInterface, 250, 1)
    updateLoadingScreen()
end)

addEvent("char:spawnSuccess", true)
addEventHandler("char:spawnSuccess", root, function()
    closeLoadingScreen()
end)

addEventHandler("onClientPlayerSpawn", localPlayer, function()
    if hasActiveCharacter() then
        closeLoadingScreen()
    end
end)

addEventHandler("onClientResourceStart", resourceRoot, function()
    fadeCamera(false, 0)
    suppressInterface()
    browserGUI = guiCreateBrowser(0, 0, screenW, screenH, true, false, false)
    if not browserGUI then return end

    browser = guiGetBrowser(browserGUI)
    if not browser then
        destroyElement(browserGUI)
        browserGUI = nil
        return
    end

    showCursor(true)
    guiSetInputMode("no_binds_when_editing")

    addEventHandler("onClientBrowserCreated", browser, function()
        loadBrowserURL(source, "http://mta/local/html/index.html")
    end)

    addEventHandler("onClientBrowserDocumentReady", browser, function()
        pageReady = true
        focusBrowser(source)
        updateLoadingScreen()
    end)

    updateTimer = setTimer(updateLoadingScreen, 250, 0)
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    closeLoadingScreen()
end)