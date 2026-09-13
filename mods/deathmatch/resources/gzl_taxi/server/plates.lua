local necoPedElement = nil
local necoChairElement = nil
local necoAnchorElement = nil

local function findOfficeChair()
    local cPos = TaxiConfig.NecoSeatAttachment.chairPos
    for _, obj in ipairs(getElementsByType("object")) do
        if getElementModel(obj) == TaxiConfig.NecoSeatAttachment.chairModel then
            local ox, oy, oz = getElementPosition(obj)
            if getDistanceBetweenPoints3D(ox, oy, oz, cPos.x, cPos.y, cPos.z) < 4.0 then
                return obj
            end
        end
    end
    return nil
end

local function spawnNecoPresident()
    if isElement(necoPedElement) then
        destroyElement(necoPedElement)
        necoPedElement = nil
    end
    if isElement(necoAnchorElement) then
        destroyElement(necoAnchorElement)
        necoAnchorElement = nil
    end

    local cfg = TaxiConfig.NecoSeatAttachment
    local chair = findOfficeChair()
    if isElement(chair) then
        necoChairElement = chair
        setElementPosition(chair, cfg.chairPos.x, cfg.chairPos.y, cfg.chairPos.z)
        setElementRotation(chair, 0, 0, cfg.chairPos.rot)
        setElementCollisionsEnabled(chair, false)
        setElementFrozen(chair, true)
    end

    local aPos = cfg.anchorPos
    necoAnchorElement = createObject(3003, aPos.x, aPos.y, aPos.z, 0, 0, aPos.rot)
    if isElement(necoAnchorElement) then
        setElementAlpha(necoAnchorElement, 0)
        setElementCollisionsEnabled(necoAnchorElement, false)
        setElementFrozen(necoAnchorElement, true)
        setElementInterior(necoAnchorElement, 0)
        setElementDimension(necoAnchorElement, 0)
    end

    necoPedElement = createPed(TaxiConfig.NecoPed.skin, aPos.x, aPos.y, aPos.z, aPos.rot)
    if isElement(necoPedElement) then
        setElementInterior(necoPedElement, 0)
        setElementDimension(necoPedElement, 0)
        setElementCollisionsEnabled(necoPedElement, false)
        setElementFrozen(necoPedElement, true)
        setElementData(necoPedElement, "taxi:isNeco", true, "broadcast", "deny")
        setElementData(necoPedElement, "npc:name", TaxiConfig.NecoPed.name)
        setElementData(necoPedElement, "npc:role", TaxiConfig.NecoPed.title)

        if isElement(necoAnchorElement) then
            attachElements(necoPedElement, necoAnchorElement, 0, 0, 0, 0, 0, 0)
        end

        addEventHandler("onPedDamage", necoPedElement, cancelEvent)
        addEventHandler("onPedWasted", necoPedElement, function()
            setTimer(spawnNecoPresident, 500, 1)
        end)

        setTimer(function()
            if isElement(necoPedElement) then
                setPedAnimation(
                    necoPedElement,
                    cfg.animBlock,
                    cfg.animName,
                    -1,
                    true,
                    false,
                    false,
                    false
                )
            end
        end, 100, 1)
    end
end

addEventHandler("onResourceStart", resourceRoot, function()
    spawnNecoPresident()
end)

addEventHandler("onResourceStop", resourceRoot, function()
    if isElement(necoPedElement) then
        destroyElement(necoPedElement)
        necoPedElement = nil
    end
    if isElement(necoAnchorElement) then
        destroyElement(necoAnchorElement)
        necoAnchorElement = nil
    end
end)

addEventHandler("onVehicleEnter", root, function(player, seat)
    if isElement(player) and seat == 0 then
        setElementData(player, "taxi:playerVehicle", source)
    end
end)

local function isPlayerAdmin(player)
    if not isElement(player) then return false end
    local account = getPlayerAccount(player)
    if not account or isGuestAccount(account) then return false end
    local adminGroup = aclGetGroup("Admin")
    if not adminGroup then return false end
    return isObjectInACLGroup("user." .. getAccountName(account), adminGroup)
end

local function generateRandomPlateCandidate()
    local numbers = string.format("%04d", math.random(100, 9999))
    return string.format("%s T %s", TaxiConfig.PlateCityCode, numbers)
end

local function isPlateOccupiedInWorld(plate)
    for _, v in ipairs(getElementsByType("vehicle")) do
        if getVehiclePlateText(v) == plate or getElementData(v, "taxi:plate") == plate then
            return true
        end
    end
    return false
end

local platePurchaseCooldowns = {}
local platePurchaseInFlight = {}
local reservedPlateCandidates = {}
local pendingPlateUpdates = {}
local nextPlateUpdateId = 0

local function getRemotePlayer()
    if client and source == resourceRoot and isElement(client) and getElementType(client) == "player" then
        return client
    end
    return nil
end

local function getCharacterId(player)
    local value = tonumber(getElementData(player, "character:id") or getElementData(player, "char:id"))
    if not value or value < 1 then return nil end
    return math.floor(value)
end

local function getCash(player)
    return math.max(0, math.floor(tonumber(getPlayerMoney(player)) or 0))
end

local function setCash(player, amount)
    amount = math.max(0, math.floor(tonumber(amount) or 0))
    setElementData(player, "character:money", amount, "broadcast", "deny")
    setElementData(player, "char:money", amount, "broadcast", "deny")
    setPlayerMoney(player, amount)
    if exports.gzl_characters and exports.gzl_characters.saveCharacter then
        exports.gzl_characters:saveCharacter(player)
    end
end

local function isVehicleSystemReady()
    local resource = getResourceFromName("gzl_vehicles")
    return resource and getResourceState(resource) == "running" and exports.gzl_vehicles and exports.gzl_vehicles.isVehicleOwner and exports.gzl_vehicles.getVehicleDbId and exports.gzl_vehicles.requestVehiclePlateChange
end

local function isOwnedDriverVehicle(player, vehicle)
    if not isVehicleSystemReady() or not isElement(vehicle) or getVehicleOccupant(vehicle, 0) ~= player then
        return false
    end
    local vehicleId = tonumber(exports.gzl_vehicles:getVehicleDbId(vehicle))
    return vehicleId and vehicleId > 0 and exports.gzl_vehicles:isVehicleOwner(player, vehicle) == true
end

local function findSuitableVehicleForPlayer(player)
    local vehicle = getPedOccupiedVehicle(player)
    if isOwnedDriverVehicle(player, vehicle) then
        return vehicle
    end
    return nil
end

local function removeTaxiPlateRecord(plate)
    local db = getTaxiDB()
    if db then
        dbExec(db, "DELETE FROM taxi_plates WHERE plate_text = ?", plate)
    end
    if unregisterTaxiPlate then
        unregisterTaxiPlate(plate)
    end
end

local function finishPlatePurchase(player, success, message)
    platePurchaseInFlight[player] = nil
    if isElement(player) then
        triggerClientEvent(player, "taxi:purchaseResult", player, success, message)
    end
end

local function finishAdminPlateUpdate(player, success, message)
    platePurchaseInFlight[player] = nil
    if isElement(player) then
        local color = success and "#22c55e" or "#ef4444"
        outputChatBox(color .. "[GZL-TAKSI]#ffffff " .. message, player, 255, 255, 255, true)
    end
end

addEvent("gzl_vehicles:vehiclePlateChanged", false)
addEventHandler("gzl_vehicles:vehiclePlateChanged", resourceRoot, function(requestId, vehicle, success)
    local pending = pendingPlateUpdates[tonumber(requestId)]
    if not pending or pending.vehicle ~= vehicle then return end
    pendingPlateUpdates[pending.id] = nil
    reservedPlateCandidates[pending.plate] = nil
    if not success then
        removeTaxiPlateRecord(pending.plate)
        if pending.admin then
            finishAdminPlateUpdate(pending.player, false, "Araç plakası kaydedilemedi.")
            return
        end
        if isElement(pending.player) then
            setCash(pending.player, getCash(pending.player) + pending.cost)
        end
        finishPlatePurchase(pending.player, false, "Araç plakası kaydedilemedi, ücret iade edildi.")
        return
    end
    if isElement(vehicle) then
        setElementData(vehicle, "taxi:isTaxi", true, "broadcast", "deny")
        setElementData(vehicle, "taxi:plate", pending.plate, "broadcast", "deny")
        if setTaxiVehicleRating then
            setTaxiVehicleRating(vehicle, TaxiConfig.VehicleRatings[getElementModel(vehicle)] or TaxiConfig.DefaultVehicleRating)
        end
        setVehicleColor(vehicle, 245, 158, 11, 245, 158, 11)
        if exports.gzl_vehicles and exports.gzl_vehicles.saveVehicleToDB then
            exports.gzl_vehicles:saveVehicleToDB(vehicle)
        end
    end
    if registerTaxiPlate then
        registerTaxiPlate(pending.plate)
    end
    if pending.oldPlate and pending.oldPlate ~= pending.plate and isTaxiPlateRegistered and isTaxiPlateRegistered(pending.oldPlate) then
        removeTaxiPlateRecord(pending.oldPlate)
    end
    if pending.admin then
        finishAdminPlateUpdate(pending.player, true, "Araç taksi plakası güncellendi: #facc15" .. pending.plate)
    else
        finishPlatePurchase(pending.player, true, pending.plate)
    end
end)

addEvent("taxi:requestNecoCinematic", true)
addEventHandler("taxi:requestNecoCinematic", resourceRoot, function()
    local player = getRemotePlayer()
    if not player or not isElement(necoPedElement) then
        return
    end

    if getElementInterior(player) ~= getElementInterior(necoPedElement) or getElementDimension(player) ~= getElementDimension(necoPedElement) then
        return
    end

    local px, py, pz = getElementPosition(player)
    local nx, ny, nz = getElementPosition(necoPedElement)
    local dist = getDistanceBetweenPoints3D(px, py, pz, nx, ny, nz)

    if dist > 6.0 then
        return
    end

    local randomIdx = math.random(1, #TaxiConfig.NecoDialogues)
    local selectedDialogue = TaxiConfig.NecoDialogues[randomIdx]

    triggerClientEvent(player, "taxi:openNecoCinematic", player, selectedDialogue)
end)

addEvent("taxi:confirmPlatePurchase", true)
addEventHandler("taxi:confirmPlatePurchase", resourceRoot, function()
    local player = getRemotePlayer()
    if not player or not isElement(necoPedElement) then
        return
    end

    if platePurchaseInFlight[player] then
        triggerClientEvent(player, "taxi:purchaseResult", player, false, "Plaka işlemi zaten sürüyor.")
        return
    end

    local now = getTickCount()
    if platePurchaseCooldowns[player] and (now - platePurchaseCooldowns[player]) < 2500 then
        return
    end
    platePurchaseCooldowns[player] = now

    if getElementInterior(player) ~= getElementInterior(necoPedElement) or getElementDimension(player) ~= getElementDimension(necoPedElement) then
        triggerClientEvent(player, "taxi:purchaseResult", player, false, "Neco Başkanın yanında değilsin!")
        return
    end

    local px, py, pz = getElementPosition(player)
    local nx, ny, nz = getElementPosition(necoPedElement)
    local dist = getDistanceBetweenPoints3D(px, py, pz, nx, ny, nz)

    if dist > 12.0 then
        triggerClientEvent(player, "taxi:purchaseResult", player, false, "Neco Başkanın yanında değilsin!")
        return
    end

    if not isVehicleSystemReady() then
        triggerClientEvent(player, "taxi:purchaseResult", player, false, "Araç sistemi hazır değil, daha sonra tekrar dene.")
        return
    end

    local targetVeh = findSuitableVehicleForPlayer(player)
    if not isElement(targetVeh) then
        triggerClientEvent(player, "taxi:purchaseResult", player, false, "Kendi aracının sürücü koltuğunda olmalısın.")
        return
    end

    local currentPlate = getElementData(targetVeh, "veh:plate") or getVehiclePlateText(targetVeh)
    if isTaxiPlateRegistered and isTaxiPlateRegistered(currentPlate) then
        triggerClientEvent(player, "taxi:purchaseResult", player, false, "Bu araçta zaten kayıtlı bir taksi plakası var.")
        return
    end

    local charId = getCharacterId(player)
    if not charId then
        triggerClientEvent(player, "taxi:purchaseResult", player, false, "Karakter bilgisi doğrulanamadı.")
        return
    end

    local money = getCash(player)
    if money < TaxiConfig.PlateCost then
        triggerClientEvent(player, "taxi:purchaseResult", player, false, string.format("Yetersiz bakiye! Gereken: $1.000, Sendeki: $%d", money))
        return
    end

    local db = getTaxiDB()
    if not db then
        triggerClientEvent(player, "taxi:purchaseResult", player, false, "Veritabani baglantisi kurulamadi!")
        return
    end

    platePurchaseInFlight[player] = {
        vehicle = targetVeh,
        characterId = charId,
        oldPlate = currentPlate
    }

    local function attemptGenerateAndAssignPlate(attemptCount)
        if not platePurchaseInFlight[player] then return end
        if attemptCount > 20 then
            finishPlatePurchase(player, false, "Plaka üretiminde yoğunluk var, tekrar dene.")
            return
        end

        local candidate = generateRandomPlateCandidate()
        if reservedPlateCandidates[candidate] or isPlateOccupiedInWorld(candidate) or (isTaxiPlateRegistered and isTaxiPlateRegistered(candidate)) then
            attemptGenerateAndAssignPlate(attemptCount + 1)
            return
        end
        reservedPlateCandidates[candidate] = true

        dbQuery(function(queryHandle)
            local result = dbPoll(queryHandle, 0)
            if result == false then
                reservedPlateCandidates[candidate] = nil
                attemptGenerateAndAssignPlate(attemptCount + 1)
                return
            end
            if not isElement(player) or not isElement(targetVeh) or not isOwnedDriverVehicle(player, targetVeh) then
                reservedPlateCandidates[candidate] = nil
                removeTaxiPlateRecord(candidate)
                finishPlatePurchase(player, false, "Araç sahipliği doğrulanamadı.")
                return
            end
            local latestMoney = getCash(player)
            if latestMoney < TaxiConfig.PlateCost then
                reservedPlateCandidates[candidate] = nil
                removeTaxiPlateRecord(candidate)
                finishPlatePurchase(player, false, "Bakiye işlem sırasında yetersiz kaldı.")
                return
            end
            setCash(player, latestMoney - TaxiConfig.PlateCost)
            nextPlateUpdateId = nextPlateUpdateId + 1
            local requestId = nextPlateUpdateId
            pendingPlateUpdates[requestId] = {
                id = requestId,
                player = player,
                vehicle = targetVeh,
                plate = candidate,
                cost = TaxiConfig.PlateCost
            }
            local started = exports.gzl_vehicles:requestVehiclePlateChange(targetVeh, candidate, resourceRoot, requestId)
            if not started and pendingPlateUpdates[requestId] then
                pendingPlateUpdates[requestId] = nil
                reservedPlateCandidates[candidate] = nil
                removeTaxiPlateRecord(candidate)
                setCash(player, getCash(player) + TaxiConfig.PlateCost)
                finishPlatePurchase(player, false, "Araç plakası kaydedilemedi, ücret iade edildi.")
            end
        end, db, "INSERT INTO taxi_plates (plate_text, owner_char_id, vehicle_model) VALUES (?, ?, ?)", candidate, charId, getElementModel(targetVeh))
    end

    attemptGenerateAndAssignPlate(1)
end)

addCommandHandler("settaxiplate", function(player, cmd, ...)
    if not isElement(player) or not isPlayerAdmin(player) or platePurchaseInFlight[player] then return end
    if not isVehicleSystemReady() then
        outputChatBox("#ef4444[GZL-TAKSI]#ffffff Araç sistemi hazır değil.", player, 255, 255, 255, true)
        return
    end

    local plateText = table.concat({...}, " ")
    if not plateText or plateText == "" then
        plateText = generateRandomPlateCandidate()
    end
    plateText = string.upper(plateText)
    if not string.match(plateText, "^%d%d%s*T%s*%d+$") then
        outputChatBox("#ef4444[GZL-TAKSI]#ffffff Geçerli bir taksi plakası gir.", player, 255, 255, 255, true)
        return
    end

    local veh = findSuitableVehicleForPlayer(player)
    if not isElement(veh) then
        outputChatBox("#ef4444[GZL-TAKSI]#ffffff Kendi aracının sürücü koltuğunda olmalısın.", player, 255, 255, 255, true)
        return
    end
    if isPlateOccupiedInWorld(plateText) or (isTaxiPlateRegistered and isTaxiPlateRegistered(plateText)) then
        outputChatBox("#ef4444[GZL-TAKSI]#ffffff Bu plaka zaten kullanımda.", player, 255, 255, 255, true)
        return
    end
    local charId = getCharacterId(player)
    local db = getTaxiDB()
    if not charId or not db then
        outputChatBox("#ef4444[GZL-TAKSI]#ffffff Karakter veya veritabanı doğrulanamadı.", player, 255, 255, 255, true)
        return
    end
    platePurchaseInFlight[player] = { vehicle = veh, admin = true }
    reservedPlateCandidates[plateText] = true
    dbQuery(function(queryHandle)
        local result = dbPoll(queryHandle, 0)
        if result == false then
            reservedPlateCandidates[plateText] = nil
            finishAdminPlateUpdate(player, false, "Plaka veritabanına kaydedilemedi.")
            return
        end
        nextPlateUpdateId = nextPlateUpdateId + 1
        local requestId = nextPlateUpdateId
        pendingPlateUpdates[requestId] = {
            id = requestId,
            player = player,
            vehicle = veh,
            plate = plateText,
            oldPlate = getVehiclePlateText(veh),
            admin = true
        }
        local started = exports.gzl_vehicles:requestVehiclePlateChange(veh, plateText, resourceRoot, requestId)
        if not started and pendingPlateUpdates[requestId] then
            pendingPlateUpdates[requestId] = nil
            reservedPlateCandidates[plateText] = nil
            removeTaxiPlateRecord(plateText)
            finishAdminPlateUpdate(player, false, "Araç plakası kaydedilemedi.")
        end
    end, db, "INSERT INTO taxi_plates (plate_text, owner_char_id, vehicle_model) VALUES (?, ?, ?)", plateText, charId, getElementModel(veh))
end)

local taxiBlip = nil

addEventHandler("onResourceStart", resourceRoot, function()
    taxiBlip = createBlip(2206.3, -2198.9, 13.3, 62, 2, 255, 255, 255, 255, 0, 99999)
end)

addEventHandler("onResourceStop", resourceRoot, function()
    if isElement(taxiBlip) then
        destroyElement(taxiBlip)
        taxiBlip = nil
    end
end)