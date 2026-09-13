local spawnedElements = {}

addEventHandler("onResourceStart", resourceRoot, function()

    for _, tableCfg in ipairs(Config.DefaultTables) do
        spawnBlackjackTable(tableCfg)
    end
    outputServerLog("[BLACKJACK] " .. #Config.DefaultTables .. " adet blackjack masası kuruldu.")
end)

addEventHandler("onResourceStop", resourceRoot, function()

    if Game and Game.cleanup then
        Game.cleanup()
    end

    for tId, elems in pairs(spawnedElements) do
        if isElement(elems.object) then destroyElement(elems.object) end
        if isElement(elems.dealerPed) then destroyElement(elems.dealerPed) end
        if isElement(elems.colshape) then destroyElement(elems.colshape) end
        if isElement(elems.blip) then destroyElement(elems.blip) end
    end
    spawnedElements = {}
end)

function spawnBlackjackTable(cfg)
    local x, y, z = cfg.pos.x, cfg.pos.y, cfg.pos.z
    local rotZ = cfg.rot or 0
    local int = cfg.interior or 0
    local dim = cfg.dimension or 0

    local tableObj = createObject(Config.Models.tableBaseID, x, y, z, 0, 0, rotZ)
    setElementParent(tableObj, resourceRoot)
    setElementInterior(tableObj, int)
    setElementDimension(tableObj, dim)
    setElementDoubleSided(tableObj, true)
    setElementData(tableObj, "blackjack:isTable", true)
    setElementData(tableObj, "blackjack:tableId", cfg.id)

    local rad = math.rad(rotZ)
    local cosA, sinA = math.cos(rad), math.sin(rad)
    local dOff = Config.DealerOffset
    local dx = x + (dOff.x * cosA - dOff.y * sinA)
    local dy = y + (dOff.x * sinA + dOff.y * cosA)
    local dz = z + dOff.z
    local dRot = (rotZ + dOff.rot) % 360

    local pedSkin = (cfg.dealerGender == "female") and (Config.Models.femaleDealerBaseID or 172) or Config.Models.dealerBaseID
    local dealerPed = createPed(pedSkin, dx, dy, dz, dRot)
    setElementParent(dealerPed, resourceRoot)
    setElementInterior(dealerPed, int)
    setElementDimension(dealerPed, dim)
    setElementFrozen(dealerPed, true)
    setElementCollisionsEnabled(dealerPed, false)
    setPedStat(dealerPed, 22, 1000)
    setElementData(dealerPed, "blackjack:isDealer", true)
    setElementData(dealerPed, "blackjack:tableId", cfg.id)

    setPedAnimation(dealerPed, false)

    local col = createColSphere(x, y, z, 3.5)
    setElementParent(col, resourceRoot)
    setElementInterior(col, int)
    setElementDimension(col, dim)
    setElementData(col, "blackjack:tableCol", cfg.id)

    local blip = createBlip(x, y, z, 52, 2, 255, 0, 0, 255, 0, 450)
    setElementParent(blip, resourceRoot)
    setElementInterior(blip, int)
    setElementDimension(blip, dim)

    spawnedElements[cfg.id] = {
        object = tableObj,
        dealerPed = dealerPed,
        colshape = col,
        blip = blip,
        config = cfg
    }

    outputServerLog(string.format("[BLACKJACK] Masa '%s' kuruldu -> X:%.2f, Y:%.2f, Z:%.2f | Int:%d | Dim:%d | Obj:%s | Ped:%s",
        cfg.id, x, y, z, int, dim, tostring(tableObj), tostring(dealerPed)))

    Game.initTable(cfg)
end

function setDealerAnim(tableId, animName, duration)
    local elems = spawnedElements[tableId]
    if elems and isElement(elems.dealerPed) then
        duration = duration or 800
        setPedAnimation(elems.dealerPed, "CASINO", animName, duration, false, false, false, false)
        setTimer(function()
            if isElement(elems.dealerPed) then
                setPedAnimation(elems.dealerPed, false)
            end
        end, duration, 1)
    end
end

function getBlackjackTableElement(tableId)
    local elems = spawnedElements[tableId]
    return elems and elems.object or nil
end

addEvent("blackjack:requestJoinTable", true)
addEventHandler("blackjack:requestJoinTable", resourceRoot, function(tableId, seatIndex)
    local player = client
    if not isElement(player) or isPedDead(player) then return end

    if isPedInVehicle(player) then
        triggerClientEvent(player, "blackjack:notify", resourceRoot, "Araçtayken kumar masasına oturamazsınız!", "error")
        return
    end

    local t = Game.Tables[tableId]
    if not t then
        triggerClientEvent(player, "blackjack:notify", resourceRoot, "Masa bulunamadı!", "error")
        return
    end

    local pInt = getElementInterior(player)
    local pDim = getElementDimension(player)
    if pInt ~= (t.config.interior or 0) or pDim ~= (t.config.dimension or 0) then
        triggerClientEvent(player, "blackjack:notify", resourceRoot, "Masa ile aynı mekanda değilsiniz!", "error")
        return
    end

    local px, py, pz = getElementPosition(player)
    local dist = getDistanceBetweenPoints3D(px, py, pz, t.config.pos.x, t.config.pos.y, t.config.pos.z)
    if dist > 5.0 then
        triggerClientEvent(player, "blackjack:notify", resourceRoot, "Masaya çok uzaksınız!", "error")
        return
    end

    local success, err = Game.playerJoinTable(player, tableId, seatIndex)
    if success then
        triggerClientEvent(player, "blackjack:onJoinedTable", resourceRoot, tableId, seatIndex)
    else
        triggerClientEvent(player, "blackjack:notify", resourceRoot, err or "Masaya oturulamadı.", "error")
    end
end)

addEvent("blackjack:requestLeaveTable", true)
addEventHandler("blackjack:requestLeaveTable", resourceRoot, function()
    local player = client
    if not isElement(player) then return end

    local success = Game.playerLeaveTable(player)
    if success then
        triggerClientEvent(player, "blackjack:onLeftTable", resourceRoot)
    end
end)

addEvent("blackjack:requestPlaceBet", true)
addEventHandler("blackjack:requestPlaceBet", resourceRoot, function(amount)
    local player = client
    if not isElement(player) or isPedDead(player) then return end

    local tableId = getElementData(player, "blackjack:tableId")
    local seatIndex = getElementData(player, "blackjack:seatIndex")
    if not tableId or not seatIndex then
        triggerClientEvent(player, "blackjack:notify", resourceRoot, "Bir masada oturmuyorsunuz!", "error")
        return
    end

    local success, err = Game.placeBet(player, tableId, seatIndex, amount)
    if not success then
        triggerClientEvent(player, "blackjack:notify", resourceRoot, err or "Bahis koyulamadı.", "error")
    end
end)

addEvent("blackjack:requestPlayerAction", true)
addEventHandler("blackjack:requestPlayerAction", resourceRoot, function(action)
    local player = client
    if not isElement(player) or isPedDead(player) or type(action) ~= "string" then return end

    local tableId = getElementData(player, "blackjack:tableId")
    local seatIndex = getElementData(player, "blackjack:seatIndex")
    if not tableId or not seatIndex then return end

    Game.playerAction(tableId, seatIndex, action)
end)

addEvent("blackjack:requestSync", true)
addEventHandler("blackjack:requestSync", resourceRoot, function(tableId)
    local player = client
    if not isElement(player) or not tableId then return end
    Game.syncTable(tableId, player)
end)

addEventHandler("onPlayerQuit", root, function()
    Game.playerLeaveTable(source)
end)

addEventHandler("onPlayerWasted", root, function()
    if getElementData(source, "blackjack:tableId") then
        Game.playerLeaveTable(source)
    end
end)

addCommandHandler("createblackjack", function(player, cmd, minBet, maxBet, ...)

    local isAdmin = false
    local gzlCore = getResourceFromName("gzl_core")
    if gzlCore and getResourceState(gzlCore) == "running" then
        isAdmin = exports.gzl_core:isAdmin(player)
    else
        local acc = getPlayerAccount(player)
        isAdmin = isGuestAccount(acc) == false and isObjectInACLGroup("user." .. getAccountName(acc), aclGetGroup("Admin"))
    end

    if not isAdmin then
        outputChatBox("[HATA] Bu komutu kullanmaya yetkiniz yok!", player, 255, 60, 60)
        return
    end

    minBet = tonumber(minBet) or 25
    maxBet = tonumber(maxBet) or 1000
    local name = table.concat({...}, " ")
    if not name or name == "" then
        name = "Özel Blackjack Masası"
    end

    local x, y, z = getElementPosition(player)
    local _, _, rotZ = getElementRotation(player)
    local int = getElementInterior(player)
    local dim = getElementDimension(player)

    local newId = "custom_bj_" .. getTickCount()
    local newCfg = {
        id = newId,
        name = name,
        pos = { x = x, y = y, z = z - 0.95 },
        rot = rotZ,
        interior = int,
        dimension = dim,
        minBet = minBet,
        maxBet = maxBet,
        dealerGender = "male",
        dealerName = "Kurpiyer Alex"
    }

    spawnBlackjackTable(newCfg)
    outputChatBox(string.format("[BLACKJACK] Yeni masa oluşturuldu! ID: %s | Limit: $%d - $%d", newId, minBet, maxBet), player, 80, 220, 100)
end)

addCommandHandler("blackjacktables", function(player)
    outputChatBox("=== AKTİF BLACKJACK MASALARI ===", player, 212, 175, 55)
    for tId, tbl in pairs(Game.Tables) do
        local seated = Game.getSeatedCount(tId)
        outputChatBox(string.format("- [%s] %s | Limit: $%d - $%d | Durum: %s | Oyuncu: %d/4",
            tId, tbl.config.name, tbl.config.minBet, tbl.config.maxBet, tbl.state, seated), player, 255, 255, 255)
    end
end)

function isPlayerAtBlackjackTable(player)
    return getElementData(player, "blackjack:tableId") ~= nil
end

function getPlayerTableData(player)
    local tId = getElementData(player, "blackjack:tableId")
    local sIdx = getElementData(player, "blackjack:seatIndex")
    return tId, sIdx
end