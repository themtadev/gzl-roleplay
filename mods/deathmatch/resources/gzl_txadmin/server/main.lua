local function authorizeAction(player, target, minimum)
    if not isAdmin(player) then return false end
    local level = exports.gzl_auth:getAdminLevel(player)
    if level < minimum then return false end
    if isElement(target) and target ~= player then
        if getElementType(target) ~= "player" or exports.gzl_auth:getAdminLevel(target) >= level then return false end
    end
    return true
end

local adminVehicles = {}
local playerNotes = {}
local spectatingAdmins = {}

addEvent("txadmin:setNoClipState", true)
addEventHandler("txadmin:setNoClipState", root, function(state)
    if client then
        local ac = getResourceFromName("gzl_anticheat")
        if not ac or getResourceState(ac) ~= "running" or not exports.gzl_anticheat:allowEvent(client, "txadmin:setNoClipState", state) then return end
    end
    if not client or not isAdmin(client) then return end
    local alpha = state and 0 or 255
    setElementAlpha(client, alpha)
    local veh = getPedOccupiedVehicle(client)
    if isElement(veh) then
        setElementAlpha(veh, alpha)
    end
    local x, y, z = getElementPosition(client)
    triggerClientEvent(root, "txadmin:playElectricSparks", root, x, y, z)
end)

addEvent("txadmin:teleportCoords", true)
addEventHandler("txadmin:teleportCoords", root, function(x, y, z)
    if client then
        local ac = getResourceFromName("gzl_anticheat")
        if not ac or getResourceState(ac) ~= "running" or not exports.gzl_anticheat:allowEvent(client, "txadmin:teleportCoords", x, y, z) then return end
    end
    if not client or not isAdmin(client) then return end
    local nx = tonumber(x) or 0
    local ny = tonumber(y) or 0
    local nz = tonumber(z) or 20
    local elem = getPedOccupiedVehicle(client) or client
    setElementPosition(elem, nx, ny, nz + 1.0)
    outputChatBox(string.format("#00f5a0[txAdmin]#ffffff Belirtilen koordinatlara ışınlandınız: %.1f, %.1f, %.1f", nx, ny, nz), client, 255, 255, 255, true)
end)

addEvent("txadmin:teleportToPlayer", true)
addEventHandler("txadmin:teleportToPlayer", root, function(target)
    if client then
        local ac = getResourceFromName("gzl_anticheat")
        if not ac or getResourceState(ac) ~= "running" or not exports.gzl_anticheat:allowEvent(client, "txadmin:teleportToPlayer", target) then return end
    end
    if not client or not isAdmin(client) or not isElement(target) then return end
    local x, y, z = getElementPosition(target)
    local int = getElementInterior(target)
    local dim = getElementDimension(target)
    local elem = getPedOccupiedVehicle(client) or client
    setElementInterior(elem, int)
    setElementDimension(elem, dim)
    setElementPosition(elem, x + 1.2, y + 1.2, z)
    outputChatBox(string.format("#00f5a0[txAdmin]#ffffff %s adlı oyuncunun yanına ışınlandınız.", getPlayerName(target)), client, 255, 255, 255, true)
end)

addEvent("txadmin:spawnVehicle", true)
addEventHandler("txadmin:spawnVehicle", root, function(input)
    if client then
        local ac = getResourceFromName("gzl_anticheat")
        if not ac or getResourceState(ac) ~= "running" or not exports.gzl_anticheat:allowEvent(client, "txadmin:spawnVehicle", input) then return end
    end
    if not client or not isAdmin(client) or not input then return end
    local modelId = tonumber(input)
    if not modelId then
        modelId = getVehicleModelFromName(tostring(input))
    end
    if not modelId or modelId < 400 or modelId > 611 then
        outputChatBox("#f43f5e[txAdmin]#ffffff Geçersiz araç modeli veya adı!", client, 255, 255, 255, true)
        return
    end

    if isElement(adminVehicles[client]) then
        destroyElement(adminVehicles[client])
        adminVehicles[client] = nil
    end

    local x, y, z = getElementPosition(client)
    local _, _, rz = getElementRotation(client)
    local int = getElementInterior(client)
    local dim = getElementDimension(client)

    local veh = createVehicle(modelId, x, y, z + 0.5, 0, 0, rz)
    if isElement(veh) then
        setElementInterior(veh, int)
        setElementDimension(veh, dim)
        warpPedIntoVehicle(client, veh, 0)
        adminVehicles[client] = veh
        local name = getVehicleNameFromModel(modelId) or "Araç"
        outputChatBox(string.format("#00f5a0[txAdmin]#ffffff Araç çıkarıldı: #00f5a0%s #ffffff(ID: %d)", name, modelId), client, 255, 255, 255, true)
    end
end)

addEvent("txadmin:fixVehicle", true)
addEventHandler("txadmin:fixVehicle", root, function()
    if client then
        local ac = getResourceFromName("gzl_anticheat")
        if not ac or getResourceState(ac) ~= "running" or not exports.gzl_anticheat:allowEvent(client, "txadmin:fixVehicle") then return end
    end
    if not client or not isAdmin(client) then return end
    local veh = getPedOccupiedVehicle(client)
    if not isElement(veh) then
        local px, py, pz = getElementPosition(client)
        for _, v in ipairs(getElementsByType("vehicle")) do
            local vx, vy, vz = getElementPosition(v)
            if getDistanceBetweenPoints3D(px, py, pz, vx, vy, vz) <= 6.0 then
                veh = v
                break
            end
        end
    end
    if isElement(veh) then
        fixVehicle(veh)
        setElementHealth(veh, 1000)
        outputChatBox("#00f5a0[txAdmin]#ffffff Araç başarıyla tamir edildi.", client, 255, 255, 255, true)
    else
        outputChatBox("#f43f5e[txAdmin]#ffffff Yakınınızda tamir edilecek araç bulunamadı!", client, 255, 255, 255, true)
    end
end)

addEvent("txadmin:deleteVehicle", true)
addEventHandler("txadmin:deleteVehicle", root, function()
    if client then
        local ac = getResourceFromName("gzl_anticheat")
        if not ac or getResourceState(ac) ~= "running" or not exports.gzl_anticheat:allowEvent(client, "txadmin:deleteVehicle") then return end
    end
    if not client or not isAdmin(client) then return end
    local veh = getPedOccupiedVehicle(client)
    if not isElement(veh) then
        local px, py, pz = getElementPosition(client)
        for _, v in ipairs(getElementsByType("vehicle")) do
            local vx, vy, vz = getElementPosition(v)
            if getDistanceBetweenPoints3D(px, py, pz, vx, vy, vz) <= 6.0 then
                veh = v
                break
            end
        end
    end
    if isElement(veh) then
        for p, sv in pairs(adminVehicles) do
            if sv == veh then
                adminVehicles[p] = nil
                break
            end
        end
        destroyElement(veh)
        outputChatBox("#00f5a0[txAdmin]#ffffff Araç silindi.", client, 255, 255, 255, true)
    else
        outputChatBox("#f43f5e[txAdmin]#ffffff Yakınınızda silinecek araç bulunamadı!", client, 255, 255, 255, true)
    end
end)

addEvent("txadmin:upgradeVehicle", true)
addEventHandler("txadmin:upgradeVehicle", root, function()
    if client then
        local ac = getResourceFromName("gzl_anticheat")
        if not ac or getResourceState(ac) ~= "running" or not exports.gzl_anticheat:allowEvent(client, "txadmin:upgradeVehicle") then return end
    end
    if not client or not isAdmin(client) then return end
    local veh = getPedOccupiedVehicle(client)
    if isElement(veh) then
        addVehicleUpgrade(veh, 1010)
        addVehicleUpgrade(veh, 1087)
        outputChatBox("#00f5a0[txAdmin]#ffffff Araca nitro ve hidrolik eklendi.", client, 255, 255, 255, true)
    end
end)

addEvent("txadmin:healAction", true)
addEventHandler("txadmin:healAction", root, function(targetType)
    if client then
        local ac = getResourceFromName("gzl_anticheat")
        if not ac or getResourceState(ac) ~= "running" or not exports.gzl_anticheat:allowEvent(client, "txadmin:healAction", targetType) then return end
    end
    if not client or not isAdmin(client) then return end
    if targetType == "myself" then
        setElementHealth(client, 100)
        setPedArmor(client, 100)
        setElementData(client, "character:hunger", 100)
        setElementData(client, "character:thirst", 100)
        outputChatBox("#00f5a0[txAdmin]#ffffff Can ve zırhınız tamamen dolduruldu.", client, 255, 255, 255, true)
    elseif targetType == "all" then
        for _, p in ipairs(getElementsByType("player")) do
            setElementHealth(p, 100)
            setPedArmor(p, 100)
            setElementData(p, "character:hunger", 100)
            setElementData(p, "character:thirst", 100)
        end
        outputChatBox("#00f5a0[txAdmin]#ffffff Tüm sunucudaki oyuncuların can ve zırhı dolduruldu.", root, 255, 255, 255, true)
    elseif targetType == "all_revive" then
        for _, p in ipairs(getElementsByType("player")) do
            if isPedDead(p) then
                local x, y, z = getElementPosition(p)
                local skin = getElementModel(p)
                local int = getElementInterior(p)
                local dim = getElementDimension(p)
                spawnPlayer(p, x, y, z, 0, skin, int, dim)
                setCameraTarget(p, p)
            end
            setElementHealth(p, 100)
            setPedArmor(p, 100)
        end
        outputChatBox("#00f5a0[txAdmin]#ffffff Tüm ölü oyuncular yeniden canlandırıldı.", root, 255, 255, 255, true)
    elseif targetType == "revive" then
        if isPedDead(client) then
            local x, y, z = getElementPosition(client)
            local skin = getElementModel(client)
            local int = getElementInterior(client)
            local dim = getElementDimension(client)
            spawnPlayer(client, x, y, z, 0, skin, int, dim)
            setCameraTarget(client, client)
        end
        setElementHealth(client, 100)
        setPedArmor(client, 100)
        outputChatBox("#00f5a0[txAdmin]#ffffff Yeniden canlandırıldınız.", client, 255, 255, 255, true)
    elseif targetType == "clean" then
        outputChatBox("#00f5a0[txAdmin]#ffffff Üstünüz temizlendi.", client, 255, 255, 255, true)
    end
end)

addEvent("txadmin:sendAnnouncement", true)
addEventHandler("txadmin:sendAnnouncement", root, function(msg)
    if client then
        local ac = getResourceFromName("gzl_anticheat")
        if not ac or getResourceState(ac) ~= "running" or not exports.gzl_anticheat:allowEvent(client, "txadmin:sendAnnouncement", msg) then return end
    end
    if not client or not isAdmin(client) or not msg or msg == "" then return end
    local cleanMsg = tostring(msg)
    local adminName = getPlayerName(client)
    outputChatBox(" ", root)
    outputChatBox("#00f5a0[txAdmin DUYURU]#ffffff " .. cleanMsg, root, 255, 255, 255, true)
    outputChatBox(" ", root)
    triggerClientEvent(root, "txadmin:displayAnnouncement", root, adminName, cleanMsg)
end)

addCommandHandler("txannounce", function(player, cmd, ...)
    if not isAdmin(player) then return end
    local msg = table.concat({...}, " ")
    if msg and msg ~= "" then
        local adminName = getPlayerName(player)
        triggerClientEvent(root, "txadmin:displayAnnouncement", root, adminName, msg)
    end
end)

addEvent("txadmin:resetWorldArea", true)
addEventHandler("txadmin:resetWorldArea", root, function(cx, cy, cz, radius)
    if client then
        local ac = getResourceFromName("gzl_anticheat")
        if not ac or getResourceState(ac) ~= "running" or not exports.gzl_anticheat:allowEvent(client, "txadmin:resetWorldArea", cx, cy, cz, radius) then return end
    end
    if not authorizeAction(client, nil, 5) then return end
    if not client or not isAdmin(client) then return end
    cx, cy, cz = tonumber(cx) or 0, tonumber(cy) or 0, tonumber(cz) or 0
    radius = tonumber(radius) or 300

    local deletedVehs = 0
    for _, veh in ipairs(getElementsByType("vehicle")) do
        local vx, vy, vz = getElementPosition(veh)
        if getDistanceBetweenPoints3D(cx, cy, cz, vx, vy, vz) <= radius then
            local hasOccupants = false
            for seat = 0, getVehicleMaxPassengers(veh) do
                if getVehicleOccupant(veh, seat) then
                    hasOccupants = true
                    break
                end
            end
            if not hasOccupants then
                destroyElement(veh)
                deletedVehs = deletedVehs + 1
            end
        end
    end

    outputChatBox(string.format("#00f5a0[txAdmin]#ffffff Bölge sıfırlandı. %d adet sahipsiz araç temizlendi.", deletedVehs), client, 255, 255, 255, true)
end)

addEvent("txadmin:playerAction", true)
addEventHandler("txadmin:playerAction", root, function(target, action, extra)
    if client then
        local ac = getResourceFromName("gzl_anticheat")
        if not ac or getResourceState(ac) ~= "running" or not exports.gzl_anticheat:allowEvent(client, "txadmin:playerAction", target, action, extra) then return end
    end
    if not client or not isAdmin(client) or not isElement(target) then return end
    if not authorizeAction(client, target, 2) then return end
    local targetName = getPlayerName(target)
    local adminName = getPlayerName(client)

    if action == "dm" then
        local msg = tostring(extra or "Yönetici sizinle iletişime geçti.")
        outputChatBox(string.format("#00f5a0[txAdmin DM - %s]#ffffff %s", adminName, msg), target, 255, 255, 255, true)
        outputChatBox(string.format("#00f5a0[txAdmin DM Gönderildi -> %s]#ffffff %s", targetName, msg), client, 255, 255, 255, true)
        triggerClientEvent(target, "txadmin:displayDirectMessage", target, adminName, msg)
    elseif action == "warn" then
        local reason = tostring(extra or "Kural ihlali")
        outputChatBox(string.format("#f43f5e[txAdmin UYARI]#ffffff %s adlı yetkili sizi uyardı: #f59e0b%s", adminName, reason), target, 255, 255, 255, true)
        outputChatBox(string.format("#00f5a0[txAdmin]#ffffff %s adlı oyuncuya uyarı iletildi.", targetName), client, 255, 255, 255, true)
        triggerClientEvent(target, "txadmin:displayWarning", target, adminName, reason)
    elseif action == "kick" then
        local reason = tostring(extra or "Yönetici tarafından atıldınız")
        kickPlayer(target, client, reason)
        outputChatBox(string.format("#f43f5e[txAdmin]#ffffff %s adlı oyuncu sunucudan atıldı (%s).", targetName, reason), root, 255, 255, 255, true)
    elseif action == "giveAdmin" then
        outputChatBox("[ADMIN] Yetki islemleri sunucu konsolundan accountadmin ile yapilir.", client, 255, 180, 0)
    elseif action == "heal" then
        setElementHealth(target, 100)
        setPedArmor(target, 100)
        outputChatBox(string.format("#00f5a0[txAdmin]#ffffff %s adlı oyuncunun can ve zırhı dolduruldu.", targetName), client, 255, 255, 255, true)
        outputChatBox("#00f5a0[txAdmin]#ffffff Bir yönetici tarafından canınız ve zırhınız dolduruldu.", target, 255, 255, 255, true)
    elseif action == "goto" then
        local x, y, z = getElementPosition(target)
        local int = getElementInterior(target)
        local dim = getElementDimension(target)
        local elem = getPedOccupiedVehicle(client) or client
        setElementInterior(elem, int)
        setElementDimension(elem, dim)
        setElementPosition(elem, x + 1.2, y + 1.2, z)
        outputChatBox(string.format("#00f5a0[txAdmin]#ffffff %s adlı oyuncunun yanına gittiniz.", targetName), client, 255, 255, 255, true)
    elseif action == "bring" then
        local x, y, z = getElementPosition(client)
        local int = getElementInterior(client)
        local dim = getElementDimension(client)
        local elem = getPedOccupiedVehicle(target) or target
        setElementInterior(elem, int)
        setElementDimension(elem, dim)
        setElementPosition(elem, x + 1.2, y + 1.2, z)
        outputChatBox(string.format("#00f5a0[txAdmin]#ffffff %s adlı oyuncuyu yanınıza çektiniz.", targetName), client, 255, 255, 255, true)
        outputChatBox("#00f5a0[txAdmin]#ffffff Yönetici sizi yanına çekti.", target, 255, 255, 255, true)
    elseif action == "spectate" then
        if spectatingAdmins[client] == target then
            setCameraTarget(client, client)
            spectatingAdmins[client] = nil
            outputChatBox("#00f5a0[txAdmin]#ffffff İzleme modundan çıkıldı.", client, 255, 255, 255, true)
        else
            setCameraTarget(client, target)
            spectatingAdmins[client] = target
            outputChatBox(string.format("#00f5a0[txAdmin]#ffffff %s adlı oyuncu izleniyor.", targetName), client, 255, 255, 255, true)
        end
    elseif action == "freeze" then
        local isFrozen = isElementFrozen(target)
        setElementFrozen(target, not isFrozen)
        outputChatBox(string.format("#00f5a0[txAdmin]#ffffff %s adlı oyuncu %s.", targetName, not isFrozen and "donduruldu" or "çözüldü"), client, 255, 255, 255, true)
        outputChatBox(string.format("#00f5a0[txAdmin]#ffffff Bir yönetici tarafından %s.", not isFrozen and "donduruldunuz" or "çözüldünüz"), target, 255, 255, 255, true)
    elseif action == "drunk" then
        local isDrunk = getElementData(target, "txadmin:isDrunk")
        if isDrunk then
            setPedAnimation(target, false)
            setElementData(target, "txadmin:isDrunk", nil)
            outputChatBox(string.format("#00f5a0[txAdmin]#ffffff %s adlı oyuncu ayıltıldı (sarhoşluk kaldırıldı).", targetName), client, 255, 255, 255, true)
            outputChatBox("#00f5a0[txAdmin]#ffffff Sarhoşluğunuz yönetici tarafından kaldırıldı.", target, 255, 255, 255, true)
        else
            setPedAnimation(target, "ped", "WALK_drunk", -1, true, true, false, true)
            setElementData(target, "txadmin:isDrunk", true)
            outputChatBox(string.format("#00f5a0[txAdmin]#ffffff %s sarhoş edildi.", targetName), client, 255, 255, 255, true)
            outputChatBox("#00f5a0[txAdmin]#ffffff Bir yönetici tarafından sarhoş edildiniz.", target, 255, 255, 255, true)
        end
    elseif action == "fire" then
        setElementOnFire(target, true)
        outputChatBox(string.format("#00f5a0[txAdmin]#ffffff %s ateşe verildi.", targetName), client, 255, 255, 255, true)
    elseif action == "slap" then
        local vx, vy, vz = getElementVelocity(target)
        setElementVelocity(target, vx, vy, vz + 0.35)
        outputChatBox(string.format("#00f5a0[txAdmin]#ffffff %s tokatlandı.", targetName), client, 255, 255, 255, true)
    end
end)

addEvent("txadmin:savePlayerNote", true)
addEventHandler("txadmin:savePlayerNote", root, function(target, noteText)
    if client then
        local ac = getResourceFromName("gzl_anticheat")
        if not ac or getResourceState(ac) ~= "running" or not exports.gzl_anticheat:allowEvent(client, "txadmin:savePlayerNote", target, noteText) then return end
    end
    if not client or not isAdmin(client) or not isElement(target) then return end
    local serial = getPlayerSerial(target)
    if serial then
        playerNotes[serial] = tostring(noteText or "")
        outputChatBox(string.format("#00f5a0[txAdmin]#ffffff %s için not başarıyla kaydedildi.", getPlayerName(target)), client, 255, 255, 255, true)
    end
end)

addEvent("txadmin:banPlayer", true)
addEventHandler("txadmin:banPlayer", root, function(target, reason, duration)
    if client then
        local ac = getResourceFromName("gzl_anticheat")
        if not ac or getResourceState(ac) ~= "running" or not exports.gzl_anticheat:allowEvent(client, "txadmin:banPlayer", target, reason, duration) then return end
    end
    if not authorizeAction(client, target, 3) then return end
    if not client or not isAdmin(client) or not isElement(target) then return end
    reason = tostring(reason or "Sunucu kurallarını ihlal")
    duration = tonumber(duration) or 7200
    local targetName = getPlayerName(target)
    local adminName = getPlayerName(client)
    banPlayer(target, true, false, true, client, reason, duration)
    outputChatBox(string.format("#f43f5e[txAdmin BAN]#ffffff %s adlı oyuncu %s tarafından yasaklandı. Sebep: #f59e0b%s", targetName, adminName, reason), root, 255, 255, 255, true)
end)

addEvent("txadmin:serverAction", true)
addEventHandler("txadmin:serverAction", root, function(act)
    if client then
        local ac = getResourceFromName("gzl_anticheat")
        if not ac or getResourceState(ac) ~= "running" or not exports.gzl_anticheat:allowEvent(client, "txadmin:serverAction", act) then return end
    end
    if not authorizeAction(client, nil, 5) then return end
    if not client or not isAdmin(client) then return end
    if act == "clearVehicles" then
        local count = 0
        for _, veh in ipairs(getElementsByType("vehicle")) do
            local hasOccupants = false
            for seat = 0, getVehicleMaxPassengers(veh) do
                if getVehicleOccupant(veh, seat) then
                    hasOccupants = true
                    break
                end
            end
            if not hasOccupants then
                destroyElement(veh)
                count = count + 1
            end
        end
        outputChatBox(string.format("#00f5a0[txAdmin]#ffffff Sunucudaki %d sahipsiz araç temizlendi.", count), client, 255, 255, 255, true)
    elseif act == "setTimeDay" then
        setTime(12, 0)
        outputChatBox("#00f5a0[txAdmin]#ffffff Sunucu saati 12:00 olarak ayarlandı.", root, 255, 255, 255, true)
    elseif act == "setTimeNight" then
        setTime(0, 0)
        outputChatBox("#00f5a0[txAdmin]#ffffff Sunucu saati 00:00 olarak ayarlandı.", root, 255, 255, 255, true)
    elseif act == "setWeatherSunny" then
        setWeather(0)
        outputChatBox("#00f5a0[txAdmin]#ffffff Hava durumu güneşli olarak ayarlandı.", root, 255, 255, 255, true)
    elseif act == "restartCountdown" then
        outputChatBox("#f43f5e[txAdmin]#ffffff DİKKAT: Sunucu 60 saniye içinde yeniden başlatılacaktır!", root, 255, 255, 255, true)
    end
end)

addEvent("txadmin:setServerTime", true)
addEventHandler("txadmin:setServerTime", root, function(idx)
    if client then
        local ac = getResourceFromName("gzl_anticheat")
        if not ac or getResourceState(ac) ~= "running" or not exports.gzl_anticheat:allowEvent(client, "txadmin:setServerTime", idx) then return end
    end
    if not authorizeAction(client, nil, 5) then return end
    if not client or not isAdmin(client) then return end
    local hours = {12, 0, 6, 18}
    local h = hours[tonumber(idx) or 1] or 12
    setTime(h, 0)
    outputChatBox(string.format("#00f5a0[txAdmin]#ffffff Sunucu saati %02d:00 olarak ayarlandı.", h), root, 255, 255, 255, true)
end)

addEvent("txadmin:setServerWeather", true)
addEventHandler("txadmin:setServerWeather", root, function(idx)
    if client then
        local ac = getResourceFromName("gzl_anticheat")
        if not ac or getResourceState(ac) ~= "running" or not exports.gzl_anticheat:allowEvent(client, "txadmin:setServerWeather", idx) then return end
    end
    if not authorizeAction(client, nil, 5) then return end
    if not client or not isAdmin(client) then return end
    local weathers = {0, 1, 8, 9, 19}
    local w = weathers[tonumber(idx) or 1] or 0
    setWeather(w)
    outputChatBox("#00f5a0[txAdmin]#ffffff Sunucu hava durumu güncellendi.", root, 255, 255, 255, true)
end)

addEvent("txadmin:startRestartCountdown", true)
addEventHandler("txadmin:startRestartCountdown", root, function(idx)
    if client then
        local ac = getResourceFromName("gzl_anticheat")
        if not ac or getResourceState(ac) ~= "running" or not exports.gzl_anticheat:allowEvent(client, "txadmin:startRestartCountdown", idx) then return end
    end
    if not authorizeAction(client, nil, 5) then return end
    if not client or not isAdmin(client) then return end
    local times = {60, 300, 600}
    local sec = times[tonumber(idx) or 1] or 60
    outputChatBox(string.format("#f43f5e[txAdmin]#ffffff DİKKAT: Sunucu %d saniye içinde yeniden başlatılacaktır!", sec), root, 255, 255, 255, true)
end)

addEventHandler("onPlayerQuit", root, function()
    if isElement(adminVehicles[source]) then
        destroyElement(adminVehicles[source])
        adminVehicles[source] = nil
    end
    setElementAlpha(source, 255)
    for adm, targ in pairs(spectatingAdmins) do
        if targ == source then
            setCameraTarget(adm, adm)
            spectatingAdmins[adm] = nil
        end
    end
end)