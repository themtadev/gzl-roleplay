local function trustedAdminLevel(player)
    local auth = getResourceFromName("gzl_auth")
    if not isElement(player) or not auth or getResourceState(auth) ~= "running" then return 0 end
    return exports.gzl_auth:getAdminLevel(player)
end

local spawnedVehicles = {}

local function notifyPlayer(player, msg, nType)
    if not isElement(player) or not msg then return end
    local cleanMsg = tostring(msg):gsub("#%x%x%x%x%x%x", "")
    pcall(function()
        if exports.gzl_ui and exports.gzl_ui.showToast then
            exports.gzl_ui:showToast(player, cleanMsg, nType or "info")
        elseif exports.gzl_ui and exports.gzl_ui.showNotification then
            exports.gzl_ui:showNotification(player, nil, cleanMsg, nType or "info")
        else
            outputChatBox(msg, player, 255, 255, 255, true)
        end
    end)
end

local function unpackVehicleColor(value)
    value = math.max(0, math.floor(tonumber(value) or 0))
    if value <= 255 then
        return value, 0, 0
    end
    local red = math.floor(value / 65536) % 256
    local green = math.floor(value / 256) % 256
    local blue = value % 256
    return red, green, blue
end

local function packVehicleColor(red, green, blue)
    red = math.max(0, math.min(255, math.floor(tonumber(red) or 0)))
    green = math.max(0, math.min(255, math.floor(tonumber(green) or 0)))
    blue = math.max(0, math.min(255, math.floor(tonumber(blue) or 0)))
    return red * 65536 + green * 256 + blue
end

local function generateRandomPlate()
    local letters = ""
    for i = 1, 3 do
        letters = letters .. string.char(math.random(65, 90))
    end
    local numbers = string.format("%03d", math.random(100, 999))
    return string.format("%s %s %s", VehConfig.DefaultPlateCity, letters, numbers)
end

local function applyVehicleAttributes(veh, row)
    if not isElement(veh) then return end
    setElementData(veh, "veh:id", row.id, true)
    setElementData(veh, "veh:owner", row.owner_id, "broadcast", "deny")
    setElementData(veh, "veh:owner_name", row.owner_name, true)
    setElementData(veh, "veh:plate", row.plate, true)
    setElementData(veh, "veh:fuel", tonumber(row.fuel) or 100)
    setElementData(veh, "veh:locked", tonumber(row.locked) == 1)
    setElementData(veh, "veh:engine", false)
    setVehicleEngineState(veh, false)
    setVehiclePlateText(veh, row.plate)
    setElementHealth(veh, tonumber(row.health) or 1000)
    setVehicleLocked(veh, tonumber(row.locked) == 1)
    local color1 = math.max(0, math.floor(tonumber(row.color1) or 0))
    local color2 = math.max(0, math.floor(tonumber(row.color2) or 0))
    if color1 <= 255 and color2 <= 255 then
        setVehicleColor(veh, color1, color2, 0, 0)
    else
        local red1, green1, blue1 = unpackVehicleColor(color1)
        local red2, green2, blue2 = unpackVehicleColor(color2)
        setVehicleColor(veh, red1, green1, blue1, red2, green2, blue2)
    end

    if row.upgrades and tostring(row.upgrades) ~= "" then
        for upgId in string.gmatch(tostring(row.upgrades), "([^,]+)") do
            local id = tonumber(upgId)
            if id then
                addVehicleUpgrade(veh, id)
            end
        end
    end

    if row.headlights and tostring(row.headlights) ~= "" then
        local hr, hg, hb = string.match(tostring(row.headlights), "(%d+),(%d+),(%d+)")
        if hr and hg and hb and setVehicleHeadLightColor then
            setVehicleHeadLightColor(veh, tonumber(hr), tonumber(hg), tonumber(hb))
        end
    end

    if row.neon and tostring(row.neon) ~= "" then
        local neonData = fromJSON(tostring(row.neon))
        if neonData then
            setElementData(veh, "veh:neon", neonData)
        end
    end

    local trunkItems = {}
    if row.trunk_items and row.trunk_items ~= "" then
        local decoded = fromJSON(row.trunk_items)
        if type(decoded) == "table" then trunkItems = decoded end
    end
    setElementData(veh, "veh:trunk_items", trunkItems)

    local gloveboxItems = {}
    if row.glovebox_items and row.glovebox_items ~= "" then
        local decoded = fromJSON(row.glovebox_items)
        if type(decoded) == "table" then gloveboxItems = decoded end
    end
    setElementData(veh, "veh:glovebox_items", gloveboxItems)

    spawnedVehicles[row.id] = veh
end

function saveVehicleToDB(veh)
    if not isElement(veh) then return end
    local vehId = getElementData(veh, "veh:id")
    if not vehId then return end
    local db = getVehicleDB()
    if not db then return end

    local x, y, z = getElementPosition(veh)
    local _, _, rz = getElementRotation(veh)
    local int = getElementInterior(veh)
    local dim = getElementDimension(veh)
    local health = getElementHealth(veh)
    local fuel = getElementData(veh, "veh:fuel") or 100
    local locked = isVehicleLocked(veh) and 1 or 0
    local plate = getVehiclePlateText(veh)
    local red1, green1, blue1, red2, green2, blue2 = getVehicleColor(veh, true)
    local color1 = packVehicleColor(red1, green1, blue1)
    local color2 = packVehicleColor(red2, green2, blue2)

    local upgs = getVehicleUpgrades(veh) or {}
    local upgStr = table.concat(upgs, ",")

    local hr, hg, hb = 255, 255, 255
    if getVehicleHeadLightColor then
        hr, hg, hb = getVehicleHeadLightColor(veh)
    end
    local headStr = string.format("%d,%d,%d", hr, hg, hb)

    local neonData = getElementData(veh, "veh:neon")
    local neonStr = neonData and toJSON(neonData) or ""

    local trunkData = getElementData(veh, "veh:trunk_items")
    local trunkStr = type(trunkData) == "table" and toJSON(trunkData, false) or (type(trunkData) == "string" and trunkData or "[]")

    local gloveData = getElementData(veh, "veh:glovebox_items")
    local gloveStr = type(gloveData) == "table" and toJSON(gloveData, false) or (type(gloveData) == "string" and gloveData or "[]")

    local q = [[
        UPDATE vehicles SET
            pos_x = ?, pos_y = ?, pos_z = ?, rot_z = ?,
            interior = ?, dimension = ?, health = ?, fuel = ?,
            locked = ?, plate = ?, color1 = ?, color2 = ?,
            upgrades = ?, headlights = ?, neon = ?,
            trunk_items = ?, glovebox_items = ?,
            last_active = CURRENT_TIMESTAMP
        WHERE id = ?
    ]]
    dbExec(db, q, x, y, z, rz, int, dim, health, fuel, locked, plate, color1, color2, upgStr, headStr, neonStr, trunkStr, gloveStr, vehId)
end

function setVehiclePlate(veh, newPlate)
    if not isElement(veh) or not newPlate then return false end
    setVehiclePlateText(veh, newPlate)
    setElementData(veh, "veh:plate", newPlate, true)
    setElementData(veh, "taxi:plate", newPlate, true)
    local vehId = getElementData(veh, "veh:id")
    if vehId then
        local db = getVehicleDB()
        if db then
            dbExec(db, "UPDATE vehicles SET plate = ? WHERE id = ?", newPlate, vehId)
        end
    end
    return true
end

function requestVehiclePlateChange(veh, newPlate, callbackResource, requestId)
    if not isElement(veh) or getElementType(veh) ~= "vehicle" or not newPlate then
        if isElement(callbackResource) then
            triggerEvent("gzl_vehicles:vehiclePlateChanged", callbackResource, requestId, veh, false)
        end
        return false
    end
    local vehId = tonumber(getElementData(veh, "veh:id"))
    local db = getVehicleDB()
    if not vehId or not db then
        if isElement(callbackResource) then
            triggerEvent("gzl_vehicles:vehiclePlateChanged", callbackResource, requestId, veh, false)
        end
        return false
    end
    dbQuery(function(queryHandle)
        local result, affectedRows = dbPoll(queryHandle, 0)
        local success = result ~= false and result ~= nil and (affectedRows == nil or affectedRows > 0)
        if success and isElement(veh) then
            setVehiclePlateText(veh, newPlate)
            setElementData(veh, "veh:plate", newPlate, true)
            setElementData(veh, "taxi:plate", newPlate, true)
        end
        if isElement(callbackResource) then
            triggerEvent("gzl_vehicles:vehiclePlateChanged", callbackResource, requestId, veh, success)
        end
    end, db, "UPDATE vehicles SET plate = ? WHERE id = ?", newPlate, vehId)
    return true
end

function getVehicleOwner(veh)
    if not isElement(veh) then return nil end
    return getElementData(veh, "veh:owner")
end

function getVehicleDbId(veh)
    if not isElement(veh) then return nil end
    return getElementData(veh, "veh:id")
end

function isVehicleOwner(player, veh)
    if not isElement(player) or not isElement(veh) then return false end
    local charId = tonumber(getElementData(player, "character:id") or getElementData(player, "char:id"))
    local ownerId = tonumber(getElementData(veh, "veh:owner"))
    return charId and ownerId and charId == ownerId
end

function spawnPlayerVehicle(vehId, spawnX, spawnY, spawnZ, spawnRot)
    vehId = tonumber(vehId)
    if not vehId then return false end
    if isElement(spawnedVehicles[vehId]) then
        return spawnedVehicles[vehId]
    end

    local db = getVehicleDB()
    if not db then return false end

    dbQuery(function(qh)
        local result = dbPoll(qh, 0)
        if result and #result > 0 then
            local row = result[1]
            local sx = spawnX or tonumber(row.pos_x) or 2206.3
            local sy = spawnY or tonumber(row.pos_y) or -2198.9
            local sz = spawnZ or tonumber(row.pos_z) or 13.3
            local srot = spawnRot or tonumber(row.rot_z) or 314.0

            local veh = createVehicle(row.model, sx, sy, sz, 0, 0, srot)
            if isElement(veh) then
                setElementInterior(veh, tonumber(row.interior) or 0)
                setElementDimension(veh, tonumber(row.dimension) or 0)
                applyVehicleAttributes(veh, row)
                dbExec(db, "UPDATE vehicles SET in_garage = 0 WHERE id = ?", row.id)
            end
        end
    end, db, "SELECT * FROM vehicles WHERE id = ?", vehId)
    return true
end

function storePlayerVehicle(vehId)
    vehId = tonumber(vehId)
    if not vehId then return false end
    local veh = spawnedVehicles[vehId]
    if isElement(veh) then
        saveVehicleToDB(veh)
        destroyElement(veh)
        spawnedVehicles[vehId] = nil
    end
    local db = getVehicleDB()
    if db then
        dbExec(db, "UPDATE vehicles SET in_garage = 1 WHERE id = ?", vehId)
    end
    return true
end

local function loadAllWorldVehicles()
    local db = getVehicleDB()
    if not db then
        setTimer(loadAllWorldVehicles, 500, 1)
        return
    end

    dbQuery(function(qh)
        local result = dbPoll(qh, 0)
        if result then
            for _, row in ipairs(result) do
                if tonumber(row.in_garage) == 0 and not isElement(spawnedVehicles[row.id]) then
                    local veh = createVehicle(row.model, row.pos_x, row.pos_y, row.pos_z, 0, 0, row.rot_z)
                    if isElement(veh) then
                        setElementInterior(veh, tonumber(row.interior) or 0)
                        setElementDimension(veh, tonumber(row.dimension) or 0)
                        applyVehicleAttributes(veh, row)
                    end
                end
            end
        end
    end, db, "SELECT * FROM vehicles WHERE in_garage = 0")
end

addEventHandler("onResourceStart", resourceRoot, function()
    setTimer(loadAllWorldVehicles, 500, 1)
end)

addEventHandler("onResourceStop", resourceRoot, function()
    for _, veh in pairs(spawnedVehicles) do
        if isElement(veh) then
            saveVehicleToDB(veh)
            destroyElement(veh)
        end
    end
    spawnedVehicles = {}
end)

local function findTargetPlayer(query)
    if not query or query == "" or query == "me" then return nil end
    local numId = tonumber(query)
    if numId then
        for _, p in ipairs(getElementsByType("player")) do
            local charId = tonumber(getElementData(p, "character:id") or getElementData(p, "char:id") or getElementData(p, "id"))
            if charId == numId then
                return p
            end
        end
    end
    local qLower = string.lower(query)
    for _, p in ipairs(getElementsByType("player")) do
        local pName = string.lower(getPlayerName(p))
        if string.find(pName, qLower, 1, true) then
            return p
        end
    end
    return nil
end

local function isAdmin(player)
    return trustedAdminLevel(player) > 0
end

function hasVehicleKey(player, veh)
    if not isElement(player) or not isElement(veh) then return false end
    if isAdmin(player) then return true end

    local charId = tonumber(getElementData(player, "character:id") or getElementData(player, "char:id"))
    local ownerId = tonumber(getElementData(veh, "veh:owner"))
    if charId and ownerId and charId == ownerId then
        return true
    end

    if exports.gzl_inventory and exports.gzl_inventory.getPlayerItems then
        local items = exports.gzl_inventory:getPlayerItems(player)
        if type(items) == "table" then
            local vPlate = string.upper(tostring(getElementData(veh, "veh:plate") or getVehiclePlateText(veh) or ""))
            local vId = tonumber(getElementData(veh, "veh:id"))
            for _, itm in pairs(items) do
                if itm and itm.name == "carkey" and itm.metadata then
                    local kPlate = itm.metadata.plate and string.upper(tostring(itm.metadata.plate))
                    local kId = tonumber(itm.metadata.vehid or itm.metadata.vehicle_id or itm.metadata.dbid)
                    if (kPlate and kPlate ~= "" and kPlate == vPlate) or (kId and vId and kId == vId) then
                        return true
                    end
                end
            end
        end
    end
    return false
end

function toggleVehicleEngine(player, veh)
    if not isElement(player) then return false, "Geçersiz oyuncu." end
    if not isElement(veh) then
        veh = getPedOccupiedVehicle(player)
    end
    if not isElement(veh) or getVehicleOccupant(veh, 0) ~= player then
        return false, "Aracın sürücü koltuğunda değilsiniz."
    end

    if not hasVehicleKey(player, veh) then
        return false, "Bu aracın anahtarına sahip değilsiniz!"
    end

    local fuel = tonumber(getElementData(veh, "veh:fuel")) or 0
    if fuel <= 0 then
        return false, "Aracın yakıtı bitmiş! Motor çalıştırılamıyor."
    end

    local curState = getVehicleEngineState(veh)
    local newState = not curState
    setVehicleEngineState(veh, newState)
    setElementData(veh, "veh:engine", newState)
    playSoundFrontEnd(player, newState and 41 or 42)
    return true, newState and "Motor çalıştırıldı." or "Motor durduruldu."
end

addEvent("gzl_vehicles:toggleEngine", true)
addEventHandler("gzl_vehicles:toggleEngine", root, function()
    if client then
        local ac = getResourceFromName("gzl_anticheat")
        if not ac or getResourceState(ac) ~= "running" or not exports.gzl_anticheat:allowEvent(client, "gzl_vehicles:toggleEngine") then return end
    end
    local p = client or source
    if isElement(p) then
        local success, msg = toggleVehicleEngine(p)
        if msg then
            notifyPlayer(p, msg, success and "success" or "error")
        end
    end
end)

addCommandHandler("motor", function(player)
    if not isElement(player) then return end
    local success, msg = toggleVehicleEngine(player)
    if msg then
        notifyPlayer(player, msg, success and "success" or "error")
    end
end)

addCommandHandler("engine", function(player)
    executeCommandHandler("motor", player)
end)

addEventHandler("onVehicleEnter", root, function(player, seat, door)
    if seat == 0 then
        local engineState = getElementData(source, "veh:engine")
        if engineState == nil then
            engineState = false
            setElementData(source, "veh:engine", false)
        end
        setVehicleEngineState(source, engineState == true)
        if not engineState then
            outputChatBox("#38bdf8[ARAÇ]#ffffff Motor kapalı. Çalıştırmak için #facc15[J]#ffffff tuşuna basın veya #facc15/motor#ffffff yazın.", player, 255, 255, 255, true)
        end
    end
end)

addCommandHandler("makeveh", function(player, cmd, modelInput, targetQuery, plateInput)
    if not isElement(player) then return end
    if not isAdmin(player) then
        outputChatBox("#ef4444[GZL-ADMIN]#ffffff Bu komutu kullanmak için yönetici yetkiniz bulunmamaktadır!", player, 255, 255, 255, true)
        return
    end

    if not modelInput or modelInput == "" then
        outputChatBox("#38bdf8[GZL-ADMIN]#ffffff Kullanım: #e2e8f0/makeveh <model_id / isim> [oyuncu_id / me] [özel_plaka]", player, 255, 255, 255, true)
        return
    end

    local modelId = tonumber(modelInput)
    if not modelId then
        modelId = getVehicleModelFromName(modelInput)
    end
    if not modelId or modelId < 400 or modelId > 611 then
        outputChatBox("#ef4444[GZL-ADMIN]#ffffff Geçersiz araç modeli: #e2e8f0" .. tostring(modelInput), player, 255, 255, 255, true)
        return
    end

    local targetPlayer = player
    if targetQuery and targetQuery ~= "" and targetQuery ~= "me" then
        local found = findTargetPlayer(targetQuery)
        if found then
            targetPlayer = found
        else
            outputChatBox("#ef4444[GZL-ADMIN]#ffffff Hedef oyuncu bulunamadı: #e2e8f0" .. tostring(targetQuery), player, 255, 255, 255, true)
            return
        end
    end

    local charId = tonumber(getElementData(targetPlayer, "character:id") or getElementData(targetPlayer, "char:id"))
    local charName = getElementData(targetPlayer, "character:name") or getElementData(targetPlayer, "char:name") or getPlayerName(targetPlayer)

    if not charId then
        charId = 1
    end

    local finalPlate = plateInput
    if not finalPlate or finalPlate == "" then
        finalPlate = generateRandomPlate()
    end

    local x, y, z = getElementPosition(targetPlayer)
    local _, _, rz = getElementRotation(targetPlayer)
    local int = getElementInterior(targetPlayer)
    local dim = getElementDimension(targetPlayer)

    local db = getVehicleDB()
    if not db then
        outputChatBox("#ef4444[GZL-ADMIN]#ffffff Veritabanı bağlantısı kurulamadı!", player, 255, 255, 255, true)
        return
    end

    local insertQuery = [[
        INSERT INTO vehicles (owner_id, owner_name, model, plate, color1, color2, pos_x, pos_y, pos_z, rot_z, interior, dimension, health, fuel, locked, in_garage)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]]

    dbQuery(function(qh)
        local _, _, lastId = dbPoll(qh, 0)
        if not lastId then
            lastId = 1
        end

        local veh = createVehicle(modelId, x, y, z + 0.2, 0, 0, rz)
        if isElement(veh) then
            setElementInterior(veh, int)
            setElementDimension(veh, dim)
            warpPedIntoVehicle(targetPlayer, veh, 0)

            local row = {
                id = lastId,
                owner_id = charId,
                owner_name = charName,
                model = modelId,
                plate = finalPlate,
                color1 = 0,
                color2 = 0,
                fuel = 100,
                health = 1000,
                locked = 0
            }
            applyVehicleAttributes(veh, row)

            setElementData(targetPlayer, "taxi:playerVehicle", veh)

            if exports.gzl_inventory and exports.gzl_inventory.addItem then
                exports.gzl_inventory:addItem(targetPlayer, "carkey", 1, {
                    plate = finalPlate,
                    vehid = lastId,
                    label = "Araç Anahtarı (" .. finalPlate .. ")"
                })
            end

            local vehName = getVehicleNameFromModel(modelId) or "Araç"
            outputChatBox(string.format("#38bdf8[GZL-ARAÇ]#ffffff Kalıcı araç tescillendi: #34d399%s #ffffff| Plaka: #facc15%s #ffffff| Sahip: #38bdf8%s #ffffff(DB ID: #a7f3d0%d#ffffff)", vehName, finalPlate, charName, lastId), player, 255, 255, 255, true)
            if targetPlayer ~= player then
                outputChatBox(string.format("#38bdf8[GZL-ARAÇ]#ffffff Üzerinize kalıcı bir araç tescillendi: #34d399%s #ffffff| Plaka: #facc15%s", vehName, finalPlate), targetPlayer, 255, 255, 255, true)
            end
        end
    end, db, insertQuery, charId, charName, modelId, finalPlate, 0, 0, x, y, z, rz, int, dim, 1000.0, 100.0, 0, 0)
end)

addCommandHandler("myvehs", function(player, cmd)
    if not isElement(player) then return end
    local charId = tonumber(getElementData(player, "character:id") or getElementData(player, "char:id"))
    if not charId then
        outputChatBox("#ef4444[GZL-ARAÇ]#ffffff Karakter veriniz yüklenemedi!", player, 255, 255, 255, true)
        return
    end

    local db = getVehicleDB()
    if not db then return end

    dbQuery(function(qh)
        local result = dbPoll(qh, 0)
        if not isElement(player) then return end
        if not result or #result == 0 then
            outputChatBox("#facc15[GZL-ARAÇ]#ffffff Üzerinize kayıtlı hiçbir araç bulunamadı.", player, 255, 255, 255, true)
            return
        end

        outputChatBox("#38bdf8========= SAHİP OLDUĞUNUZ ARAÇLAR =========", player, 255, 255, 255, true)
        for _, row in ipairs(result) do
            local vName = getVehicleNameFromModel(row.model) or "Araç"
            local status = tonumber(row.in_garage) == 1 and "#94a3b8[Garajda]" or "#22c55e[Dışarıda]"
            local spawnedStatus = isElement(spawnedVehicles[row.id]) and "#34d399(Aktif)" or ""
            outputChatBox(string.format("#ffffffID: #facc15%d #ffffff| Model: #38bdf8%s #ffffff| Plaka: #fbbf24%s #ffffff| Durum: %s %s", row.id, vName, row.plate, status, spawnedStatus), player, 255, 255, 255, true)
        end
        outputChatBox("#94a3b8Komutlar: /spawnveh <id> (aracı çıkart) | /park (aracı kaydet/park et)", player, 255, 255, 255, true)
    end, db, "SELECT * FROM vehicles WHERE owner_id = ?", charId)
end)
addCommandHandler("araclarim", function(p, c) executeCommandHandler("myvehs", p) end)

addCommandHandler("park", function(player, cmd)
    if not isElement(player) then return end
    local veh = getPedOccupiedVehicle(player)
    if not isElement(veh) then
        local px, py, pz = getElementPosition(player)
        for _, v in ipairs(getElementsByType("vehicle")) do
            local vx, vy, vz = getElementPosition(v)
            if getDistanceBetweenPoints3D(px, py, pz, vx, vy, vz) <= 5.0 then
                veh = v
                break
            end
        end
    end

    if not isElement(veh) then
        notifyPlayer(player, "Park etmek için bir araca binmeli veya yakınında olmalısınız!", "error")
        return
    end

    local vehId = getElementData(veh, "veh:id")
    if not vehId then
        notifyPlayer(player, "Bu araç kalıcı veritabanı aracı değildir!", "error")
        return
    end

    if not hasVehicleKey(player, veh) and not isAdmin(player) then
        notifyPlayer(player, "Bu aracın sahibi veya anahtarı sizde değil!", "error")
        return
    end

    saveVehicleToDB(veh)
    notifyPlayer(player, "Aracınızın konumu ve durumu kaydedildi.", "success")
end)

addCommandHandler("spawnveh", function(player, cmd, vehIdInput)
    if not isElement(player) then return end
    local vehId = tonumber(vehIdInput)
    if not vehId then
        outputChatBox("#38bdf8[GZL-ARAÇ]#ffffff Kullanım: #e2e8f0/spawnveh <araç_id>", player, 255, 255, 255, true)
        return
    end

    local charId = tonumber(getElementData(player, "character:id") or getElementData(player, "char:id"))
    local db = getVehicleDB()
    if not db then return end

    dbQuery(function(qh)
        local result = dbPoll(qh, 0)
        if not isElement(player) then return end
        if not result or #result == 0 then
            notifyPlayer(player, "Belirtilen ID'ye ait araç bulunamadı!", "error")
            return
        end

        local row = result[1]
        if tonumber(row.owner_id) ~= charId and not isAdmin(player) then
            notifyPlayer(player, "Bu aracın sahibi siz değilsiniz!", "error")
            return
        end

        if isElement(spawnedVehicles[vehId]) then
            notifyPlayer(player, "Aracınız zaten dışarıda aktif! Haritada aracınızın yanına gidin veya /park edin.", "warning")
            return
        end

        local px, py, pz = getElementPosition(player)
        local _, _, prz = getElementRotation(player)
        local pint = getElementInterior(player)
        local pdim = getElementDimension(player)

        local veh = createVehicle(row.model, px + 2.0, py, pz + 0.2, 0, 0, prz)
        if isElement(veh) then
            setElementInterior(veh, pint)
            setElementDimension(veh, pdim)
            applyVehicleAttributes(veh, row)
            setElementData(player, "taxi:playerVehicle", veh)
            dbExec(db, "UPDATE vehicles SET in_garage = 0 WHERE id = ?", vehId)
            local vName = getVehicleNameFromModel(row.model) or "Araç"
            notifyPlayer(player, string.format("%s (Plaka: %s) yanınıza getirildi.", vName, row.plate), "success")
        end
    end, db, "SELECT * FROM vehicles WHERE id = ?", vehId)
end)
addCommandHandler("araccikar", function(p, c, id) executeCommandHandler("spawnveh", p, id) end)

addCommandHandler("lock", function(player, cmd)
    if not isElement(player) then return end
    local veh = getPedOccupiedVehicle(player)
    if not isElement(veh) then
        local px, py, pz = getElementPosition(player)
        local closest = 6.0
        for _, v in ipairs(getElementsByType("vehicle")) do
            local vx, vy, vz = getElementPosition(v)
            local dist = getDistanceBetweenPoints3D(px, py, pz, vx, vy, vz)
            if dist < closest and hasVehicleKey(player, v) then
                closest = dist
                veh = v
            end
        end
    end

    if not isElement(veh) then
        notifyPlayer(player, "Yakınınızda kilitleyebileceğiniz anahtarına sahip olduğunuz bir araç bulunamadı!", "error")
        return
    end

    if not hasVehicleKey(player, veh) then
        notifyPlayer(player, "Bu aracın anahtarı sizde değil!", "error")
        return
    end

    local isLocked = isVehicleLocked(veh)
    local newState = not isLocked
    setVehicleLocked(veh, newState)
    setElementData(veh, "veh:locked", newState)
    playSoundFrontEnd(player, newState and 41 or 42)
    if newState then
        notifyPlayer(player, "Aracınızı kilitlediniz.", "warning")
    else
        notifyPlayer(player, "Aracınızın kilidini açtınız.", "success")
    end
    saveVehicleToDB(veh)
end)
addCommandHandler("kilit", function(p, c) executeCommandHandler("lock", p) end)

addCommandHandler("getveh", function(player, cmd, vehIdInput)
    if not isElement(player) then return end
    local charId = tonumber(getElementData(player, "character:id") or getElementData(player, "char:id"))
    if not charId then
        outputChatBox("#ef4444[GZL-ARAC]#ffffff Karakter veriniz yuklenemedi!", player, 255, 255, 255, true)
        return
    end

    local db = getVehicleDB()
    if not db then return end

    local vehId = tonumber(vehIdInput)

    if not vehId then
        dbQuery(function(qh)
            local result = dbPoll(qh, 0)
            if not isElement(player) then return end
            if not result or #result == 0 then
                outputChatBox("#facc15[GZL-ARAC]#ffffff Uzerinize kayitli hicbir arac bulunamadi.", player, 255, 255, 255, true)
                return
            end

            outputChatBox("#38bdf8========= SAHIP OLDUGUNUZ ARACLAR =========", player, 255, 255, 255, true)
            for _, row in ipairs(result) do
                local vName = getVehicleNameFromModel(row.model) or "Arac"
                local isSpawned = isElement(spawnedVehicles[row.id])
                local status = isSpawned and "#34d399[Disarida / Aktif]" or (tonumber(row.in_garage) == 1 and "#94a3b8[Garajda]" or "#f59e0b[Park Halinde]")
                outputChatBox(string.format("#ffffffArac ID: #facc15%d #ffffff| Model: #38bdf8%s #ffffff| Plaka: #fbbf24%s #ffffff| Durum: %s", row.id, vName, row.plate, status), player, 255, 255, 255, true)
            end
            outputChatBox("#94a3b8Kullanim: #ffffff/getveh <arac_id> #94a3b8(Aracinizi yaniniza cekmek icin ID girin)", player, 255, 255, 255, true)
        end, db, "SELECT * FROM vehicles WHERE owner_id = ?", charId)
        return
    end

    dbQuery(function(qh)
        local result = dbPoll(qh, 0)
        if not isElement(player) then return end
        if not result or #result == 0 then
            notifyPlayer(player, "Belirtilen ID'ye (" .. tostring(vehId) .. ") ait arac bulunamadi!", "error")
            return
        end

        local row = result[1]
        if tonumber(row.owner_id) ~= charId and not isAdmin(player) then
            notifyPlayer(player, "Bu aracin sahibi siz degilsiniz!", "error")
            return
        end

        local px, py, pz = getElementPosition(player)
        local _, _, prz = getElementRotation(player)
        local pint = getElementInterior(player)
        local pdim = getElementDimension(player)

        local rad = math.rad(prz + 90)
        local spawnX = px + 2.5 * math.cos(rad)
        local spawnY = py + 2.5 * math.sin(rad)
        local spawnZ = pz + 0.3

        local veh = spawnedVehicles[vehId]

        if isElement(veh) then

            setElementInterior(veh, pint)
            setElementDimension(veh, pdim)
            setElementPosition(veh, spawnX, spawnY, spawnZ)
            setElementRotation(veh, 0, 0, prz)
            setElementVelocity(veh, 0, 0, 0)
            setElementAngularVelocity(veh, 0, 0, 0)
            saveVehicleToDB(veh)

            local vName = getVehicleName(veh) or getVehicleNameFromModel(row.model) or "Arac"
            notifyPlayer(player, vName .. " (Plaka: " .. tostring(row.plate) .. ") yaniniza cekildi.", "success")
        else

            veh = createVehicle(row.model, spawnX, spawnY, spawnZ, 0, 0, prz)
            if isElement(veh) then
                setElementInterior(veh, pint)
                setElementDimension(veh, pdim)
                applyVehicleAttributes(veh, row)
                setElementData(player, "taxi:playerVehicle", veh)
                dbExec(db, "UPDATE vehicles SET in_garage = 0, pos_x = ?, pos_y = ?, pos_z = ?, rot_z = ? WHERE id = ?", spawnX, spawnY, spawnZ, prz, vehId)

                local vName = getVehicleNameFromModel(row.model) or "Arac"
                notifyPlayer(player, vName .. " (Plaka: " .. tostring(row.plate) .. ") garajdan cikarilip getirildi.", "success")
            end
        end
    end, db, "SELECT * FROM vehicles WHERE id = ?", vehId)
end)
addCommandHandler("araccek", function(p, c, id) executeCommandHandler("getveh", p, id) end)