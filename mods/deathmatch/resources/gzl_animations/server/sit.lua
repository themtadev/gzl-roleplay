
local sittingPlayers = {}

local SitStyles = {
    [1] = { 
        name = "Gerçekçi Sandalyeye Oturma (Eğilerek)", 
        block = "PED", 
        enterAnim = "SEAT_down", 
        enterDuration = 1500, 
        loopAnim = "SEAT_idle", 
        exitBlock = "PED",
        exitAnim = "SEAT_up", 
        exitDuration = 1100, 
        isTransition = true,
        isCustom = false 
    },
    [2] = { 
        name = "Klasik Havada / Bankta Oturuş", 
        block = "sit", 
        anim = "Gun_stand", 
        isTransition = false,
        isCustom = true 
    },
    [3] = { 
        name = "Koltuk / Kanepe", 
        block = "INT_HOUSE", 
        anim = "LOU_Loop", 
        isTransition = false,
        isCustom = false 
    },
    [4] = { 
        name = "Standart Sandalye (Sabit)", 
        block = "PED", 
        anim = "SEAT_idle", 
        isTransition = false,
        isCustom = false 
    },
    [5] = { 
        name = "Park / Bank (Erkek)", 
        block = "BEACH", 
        anim = "ParkSit_M_loop", 
        isTransition = false,
        isCustom = false 
    },
    [6] = { 
        name = "Park / Bank (Kadın)", 
        block = "BEACH", 
        anim = "ParkSit_W_loop", 
        isTransition = false,
        isCustom = false 
    },
    [7] = { 
        name = "Kaldırım / Basamak", 
        block = "ATTRACTORS", 
        anim = "Stepsit_loop", 
        isTransition = false,
        isCustom = false 
    },
    [8] = { 
        name = "Yere Bağdaş Kurma", 
        block = "BEACH", 
        anim = "SitnWait_loop_W", 
        exitBlock = "PED",
        exitAnim = "getup_front",
        exitDuration = 1200,
        isTransition = false,
        isCustom = false 
    },
    [9] = { 
        name = "Yere Uzanma", 
        block = "BEACH", 
        anim = "Lay_Bac_Loop", 
        exitBlock = "PED",
        exitAnim = "getup",
        exitDuration = 1200,
        isTransition = false,
        isCustom = false 
    },
    [10] = { 
        name = "Yerde Dinlenme", 
        block = "CRACK", 
        anim = "crckidle2", 
        exitBlock = "PED",
        exitAnim = "getup_front",
        exitDuration = 1200,
        isTransition = false,
        isCustom = false 
    },
    [11] = { 
        name = "Meditasyon Oturuşu", 
        block = "PARK", 
        anim = "Tai_Chi_Loop", 
        isTransition = false,
        isCustom = false 
    },
}

local function sendNotification(player, message, notifType)
    if not isElement(player) then return end
    if exports.gzl_ui and exports.gzl_ui.showNotification then
        exports.gzl_ui:showNotification(player, message, notifType or "info")
    else
        local r, g, b = 0, 200, 255
        if notifType == "error" then r, g, b = 255, 60, 60
        elseif notifType == "success" then r, g, b = 60, 255, 120
        elseif notifType == "warning" then r, g, b = 255, 180, 0 end
        outputChatBox("[Animasyon] " .. message, player, r, g, b)
    end
end

local function stopSitting(player, silent)
    if not isElement(player) then return end
    if not sittingPlayers[player] then return end

    local prevStyle = sittingPlayers[player]
    sittingPlayers[player] = nil
    setElementData(player, "gzl:sitting", nil)
    triggerClientEvent(root, "gzl_animations:syncSitAnim", player, player, prevStyle, false)

    if not silent then
        sendNotification(player, "Ayağa kalktınız.", "info")
    end
end

local function startSitting(player, styleId)
    if not isElement(player) then return end

    if isPedInVehicle(player) then
        sendNotification(player, "Araç içerisindeyken oturamazsınız.", "error")
        return
    end

    if isPedDead(player) then return end

    if isElementInWater(player) then
        sendNotification(player, "Su içerisindeyken oturamazsınız.", "error")
        return
    end

    styleId = tonumber(styleId) or 1
    if styleId < 1 or styleId > #SitStyles then
        styleId = 1
    end

    local style = SitStyles[styleId]
    if not style then return end

    if sittingPlayers[player] == styleId then
        stopSitting(player)
        return
    end

    sittingPlayers[player] = styleId
    setElementData(player, "gzl:sitting", styleId)

    triggerClientEvent(root, "gzl_animations:syncSitAnim", player, player, styleId, true)
    sendNotification(player, style.name .. " stiliyle oturdunuz. (Kalkmak için: WASD, X veya Space)", "success")
end

local function handleSitCommand(player, cmd, styleArg)
    if not isElement(player) then return end

    if styleArg and (styleArg:lower() == "liste" or styleArg:lower() == "yardim" or styleArg:lower() == "help") then
        outputChatBox("=====[ Oturma Stilleri ]=====", player, 0, 200, 255)
        for id = 1, #SitStyles do
            outputChatBox(string.format("#3b82f6/%s %d #ffffff- %s", cmd, id, SitStyles[id].name), player, 255, 255, 255, true)
        end
        outputChatBox("#9ca3afKalkmak için: #ffffffWASD, X veya Space tuşuna basın", player, 255, 255, 255, true)
        return
    end

    local styleId = tonumber(styleArg)
    if not styleId then
        if sittingPlayers[player] then
            stopSitting(player)
            return
        else
            styleId = 1
        end
    end

    startSitting(player, styleId)
end

addCommandHandler("otur", handleSitCommand, false, false)
addCommandHandler("sit", handleSitCommand, false, false)

addCommandHandler("kalk", function(player)
    if sittingPlayers[player] then
        stopSitting(player)
    else
        sendNotification(player, "Zaten oturmuyorsunuz.", "warning")
    end
end, false, false)

local function showSitList(player)
    outputChatBox("=====[ Oturma Stilleri ]=====", player, 0, 200, 255)
    for id = 1, #SitStyles do
        outputChatBox(string.format("#3b82f6/otur %d #ffffff- %s", id, SitStyles[id].name), player, 255, 255, 255, true)
    end
    outputChatBox(string.format("#9ca3afKullanım: #ffffff/otur [1-%d] #9ca3af| Kalkmak: #ffffffWASD, X veya Space", #SitStyles), player, 255, 255, 255, true)
end
addCommandHandler("oturliste", showSitList, false, false)
addCommandHandler("oturlar", showSitList, false, false)

for i = 1, #SitStyles do
    addCommandHandler("otur" .. i, function(player)
        startSitting(player, i)
    end, false, false)
    addCommandHandler("sit" .. i, function(player)
        startSitting(player, i)
    end, false, false)
end

addEvent("gzl_animations:requestStopSit", true)
addEventHandler("gzl_animations:requestStopSit", root, function()
    local p = client or source
    if isElement(p) and sittingPlayers[p] then
        stopSitting(p, true)
    end
end)

addEventHandler("onPlayerQuit", root, function()
    sittingPlayers[source] = nil
end)

addEventHandler("onPlayerWasted", root, function()
    if sittingPlayers[source] then
        stopSitting(source, true)
    end
end)

addEventHandler("onPlayerVehicleEnter", root, function()
    if sittingPlayers[source] then
        stopSitting(source, true)
    end
end)