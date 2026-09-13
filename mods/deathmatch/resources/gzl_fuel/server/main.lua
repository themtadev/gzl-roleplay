local database = nil
local databaseReady = false
local stations = {}
local employees = {}
local fuelingByPlayer = {}
local fuelingByVehicle = {}
local staffDuty = {}
local rateLimits = {}
local exactFuel = {}
local loadingFuel = {}
local loadedFuel = {}
local dirtyVehicles = {}
local dirtyStations = {}
local emptyWarnings = {}
local lowFuelWarnings = {}
local resourceStopping = false
local trustedCharacterIds = {}
local trustedCash = {}
local trustedBank = {}
local protectedWrites = {}

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function finiteNumber(value)
    value = tonumber(value)
    if not value or value ~= value or value == math.huge or value == -math.huge then return nil end
    return value
end

local function round(value, precision)
    local factor = 10 ^ (precision or 0)
    return math.floor(value * factor + 0.5) / factor
end

local function cleanName(value)
    value = tostring(value or "Bilinmiyor")
    value = string.gsub(value, "#%x%x%x%x%x%x", "")
    value = string.gsub(value, "_", " ")
    return string.sub(value, 1, 48)
end

local function getCharacterId(player)
    if not getElementData(player, "loggedin_character") then return nil end
    if trustedCharacterIds[player] then return trustedCharacterIds[player] end
    local value = finiteNumber(getElementData(player, "character:id") or getElementData(player, "char:id") or getElementData(player, "loggedin_character"))
    return value and math.floor(value) or nil
end

local function getCharacterName(player)
    return cleanName(getElementData(player, "character:name") or getElementData(player, "char:name") or getPlayerName(player))
end

local function getCash(player)
    local value = trustedCash[player]
    if value == nil then value = finiteNumber(getElementData(player, "character:money") or getElementData(player, "char:money") or getPlayerMoney(player)) or 0 end
    return math.max(0, math.floor(value))
end

local function setCash(player, amount)
    if not isElement(player) then return false end
    amount = finiteNumber(amount)
    if not amount then return false end
    amount = math.max(0, math.floor(amount))
    trustedCash[player] = amount
    setElementData(player, "character:money", amount, "broadcast", "deny")
    setElementData(player, "char:money", amount, "broadcast", "deny")
    setPlayerMoney(player, amount)
    if exports.gzl_characters and exports.gzl_characters.saveCharacter then
        exports.gzl_characters:saveCharacter(player)
    end
    return true
end

local function getBank(player)
    local value = trustedBank[player]
    if value == nil then value = finiteNumber(getElementData(player, "character:bank") or getElementData(player, "char:bank_money") or getElementData(player, "char:bank")) or 0 end
    return math.max(0, math.floor(value))
end

local function setBank(player, amount)
    if not isElement(player) then return false end
    amount = finiteNumber(amount)
    if not amount then return false end
    amount = math.max(0, math.floor(amount))
    trustedBank[player] = amount
    setElementData(player, "character:bank", amount, "broadcast", "deny")
    setElementData(player, "char:bank_money", amount)
    setElementData(player, "char:bank", amount, "broadcast", "deny")
    if exports.gzl_characters and exports.gzl_characters.saveCharacter then
        exports.gzl_characters:saveCharacter(player)
    end
    return true
end

local function hasUiExport(name)
    local resource = getResourceFromName("gzl_ui")
    if not resource or getResourceState(resource) ~= "running" then return false end
    return exports.gzl_ui and type(exports.gzl_ui[name]) == "function"
end

local function notify(player, message, kind)
    if not isElement(player) or getElementType(player) ~= "player" then return end
    if hasUiExport("showToast") then
        exports.gzl_ui:showToast(player, message, kind or "info", 4500)
    else
        local red = kind == "error" and 244 or 230
        local green = kind == "success" and 210 or 190
        outputChatBox("[GZL Fuel] " .. tostring(message), player, red, green, 120)
    end
end

local function allowAction(player, action, cooldown)
    local now = getTickCount()
    rateLimits[player] = rateLimits[player] or {}
    local previous = rateLimits[player][action] or 0
    if now - previous < cooldown then return false end
    rateLimits[player][action] = now
    return true
end

local protectedIdentityKeys = {
    ["character:id"] = true,
    ["char:id"] = true
}

local protectedCashKeys = {
    ["character:money"] = true,
    ["char:money"] = true
}

local protectedBankKeys = {
    ["character:bank"] = true,
    ["char:bank_money"] = true,
    ["char:bank"] = true
}

local function protectElementData(player, key, value)
    protectedWrites[player] = protectedWrites[player] or {}
    if protectedWrites[player][key] then return end
    protectedWrites[player][key] = true
    setElementData(player, key, value, true)
    protectedWrites[player][key] = nil
end

local function capturePlayerState(player)
    if not isElement(player) then return end
    local characterId = finiteNumber(getElementData(player, "character:id") or getElementData(player, "char:id") or getElementData(player, "loggedin_character"))
    local cash = finiteNumber(getElementData(player, "character:money") or getElementData(player, "char:money") or getPlayerMoney(player))
    local bank = finiteNumber(getElementData(player, "character:bank") or getElementData(player, "char:bank_money") or getElementData(player, "char:bank"))
    trustedCharacterIds[player] = getElementData(player, "loggedin_character") and characterId and math.floor(characterId) or nil
    trustedCash[player] = cash and math.max(0, math.floor(cash)) or nil
    trustedBank[player] = bank and math.max(0, math.floor(bank)) or nil
    if characterId then
        protectElementData(player, "character:id", getElementData(player, "character:id"))
        protectElementData(player, "char:id", getElementData(player, "char:id"))
    end
    if cash then
        protectElementData(player, "character:money", trustedCash[player])
        protectElementData(player, "char:money", trustedCash[player])
    end
    if bank then
        protectElementData(player, "character:bank", trustedBank[player])
        protectElementData(player, "char:bank_money", trustedBank[player])
        protectElementData(player, "char:bank", trustedBank[player])
    end
end

local function isValidRemote(player)
    return isElement(player) and getElementType(player) == "player" and source == resourceRoot
end

local function isPlayerNearStation(player, stationConfig, maximumDistance)
    if not isElement(player) or not stationConfig then return false end
    if getElementInterior(player) ~= 0 or getElementDimension(player) ~= 0 then return false end
    local x, y, z = getElementPosition(player)
    return getDistanceBetweenPoints3D(x, y, z, stationConfig.x, stationConfig.y, stationConfig.z) <= maximumDistance
end

local function getVehicleDatabaseId(vehicle)
    if not isElement(vehicle) then return nil end
    local value = tonumber(getElementData(vehicle, "veh:id") or getElementData(vehicle, "vehicle:id") or getElementData(vehicle, "dbid"))
    if not value or value < 1 then return nil end
    return math.floor(value)
end

local function persistVehicleFuel(vehicle)
    if not database or not isElement(vehicle) then return false end
    local vehicleId = getVehicleDatabaseId(vehicle)
    local fuel = exactFuel[vehicle]
    if not vehicleId or fuel == nil then return false end
    dbExec(database, "INSERT OR REPLACE INTO vehicle_fuel (vehicle_id, fuel, updated_at) VALUES (?, ?, CURRENT_TIMESTAMP)", vehicleId, round(fuel, 2))
    dirtyVehicles[vehicle] = nil
    return true
end

local function setFuelInternal(vehicle, value, markDirty)
    if not isElement(vehicle) or getElementType(vehicle) ~= "vehicle" then return false end
    value = finiteNumber(value)
    if not value then return false end
    value = round(clamp(value, 0, 100), 2)
    exactFuel[vehicle] = value
    setElementData(vehicle, Config.FuelElementData, value, true)
    if markDirty ~= false and getVehicleDatabaseId(vehicle) then
        dirtyVehicles[vehicle] = true
    end
    if value > 0.05 then
        emptyWarnings[vehicle] = nil
    end
    if value > 5 then
        lowFuelWarnings[vehicle] = nil
    end
    return value
end

local function ensureVehicleFuel(vehicle)
    if not isElement(vehicle) or getElementType(vehicle) ~= "vehicle" then return 0 end
    if exactFuel[vehicle] == nil then
        local existing = tonumber(getElementData(vehicle, Config.FuelElementData))
        if existing then
            exactFuel[vehicle] = clamp(existing, 0, 100)
            loadedFuel[vehicle] = true
            if getVehicleDatabaseId(vehicle) then dirtyVehicles[vehicle] = true end
        else
            exactFuel[vehicle] = Config.DefaultFuelPercent
            setElementData(vehicle, Config.FuelElementData, Config.DefaultFuelPercent, true)
        end
    end

    local vehicleId = getVehicleDatabaseId(vehicle)
    if databaseReady and vehicleId and not loadedFuel[vehicle] and not loadingFuel[vehicle] then
        loadingFuel[vehicle] = true
        dbQuery(function(queryHandle)
            local result = dbPoll(queryHandle, 0)
            loadingFuel[vehicle] = nil
            if not isElement(vehicle) then return end
            loadedFuel[vehicle] = true
            if result and result[1] then
                setFuelInternal(vehicle, tonumber(result[1].fuel) or Config.DefaultFuelPercent, false)
            else
                dirtyVehicles[vehicle] = true
            end
        end, database, "SELECT fuel FROM vehicle_fuel WHERE vehicle_id = ? LIMIT 1", vehicleId)
    end

    return exactFuel[vehicle] or Config.DefaultFuelPercent
end

function getVehicleFuel(vehicle)
    return ensureVehicleFuel(vehicle)
end

function setVehicleFuel(vehicle, value)
    return setFuelInternal(vehicle, value, true)
end

function addVehicleFuel(vehicle, amount)
    if not isElement(vehicle) then return false end
    amount = finiteNumber(amount)
    if not amount then return false end
    return setFuelInternal(vehicle, ensureVehicleFuel(vehicle) + amount, true)
end

function isVehicleFueling(vehicle)
    return isElement(vehicle) and fuelingByVehicle[vehicle] ~= nil or false
end

local function persistStation(station)
    if not database or not station then return false end
    dbExec(database, [[
        UPDATE stations
        SET owner_id = ?, owner_name = ?, price = ?, stock = ?, balance = ?, total_liters = ?, total_revenue = ?, total_customers = ?, updated_at = CURRENT_TIMESTAMP
        WHERE id = ?
    ]], station.ownerId, station.ownerName, station.price, station.stock, station.balance, station.totalLiters, station.totalRevenue, station.totalCustomers, station.id)
    dirtyStations[station.id] = nil
    return true
end

local function logStation(stationId, actorId, actorName, eventType, amount, liters)
    if not database then return false end
    return dbExec(database, "INSERT INTO station_logs (station_id, actor_id, actor_name, event_type, amount, liters, created_at) VALUES (?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)", stationId, actorId or 0, cleanName(actorName), eventType, round(tonumber(amount) or 0, 2), round(tonumber(liters) or 0, 2))
end

local function getAccess(player, station)
    local characterId = getCharacterId(player)
    local employee = characterId and employees[station.id] and employees[station.id][characterId] or nil
    local isOwner = characterId and station.ownerId == characterId or false
    local role = isOwner and "owner" or employee and employee.role or nil
    return {
        isOwner = isOwner,
        isStaff = employee ~= nil,
        role = role,
        canViewBusiness = isOwner or employee ~= nil,
        canManage = isOwner or role == "manager",
        canStaff = isOwner,
        canWithdraw = isOwner,
        canDuty = employee ~= nil
    }
end

local function getEmployeeList(stationId)
    local list = {}
    for characterId, employee in pairs(employees[stationId] or {}) do
        list[#list + 1] = {
            characterId = characterId,
            name = employee.name,
            role = employee.role
        }
    end
    table.sort(list, function(a, b)
        if a.role == b.role then return a.name < b.name end
        return a.role == "manager"
    end)
    return list
end

local function getVehicleContext(player)
    local vehicle = getPedOccupiedVehicle(player)
    if not vehicle or getPedOccupiedVehicleSeat(player) ~= 0 then return nil end
    local vehicleType = getVehicleType(vehicle)
    local capacity = getFuelVehicleCapacity(vehicle)
    if not Config.AllowedVehicleTypes[vehicleType] or capacity <= 0 then return nil end
    local fuel = ensureVehicleFuel(vehicle)
    return {
        element = vehicle,
        name = getVehicleName(vehicle),
        model = getElementModel(vehicle),
        fuel = fuel,
        capacity = capacity,
        liters = round(capacity * fuel / 100, 1),
        missingLiters = round(capacity * (100 - fuel) / 100, 1),
        engineOn = getVehicleEngineState(vehicle),
        fueling = fuelingByVehicle[vehicle] ~= nil
    }
end

local function buildStationPayload(station, config)
    return {
        id = station.id,
        name = config.name,
        district = config.district,
        ownerId = station.ownerId,
        ownerName = station.ownerName,
        price = round(station.price, 2),
        wholesalePrice = config.wholesalePrice,
        stock = round(station.stock, 1),
        maxStock = config.maxStock,
        balance = math.floor(station.balance),
        totalLiters = round(station.totalLiters, 1),
        totalRevenue = math.floor(station.totalRevenue),
        totalCustomers = station.totalCustomers,
        purchasePrice = config.purchasePrice
    }
end

local function sendContext(player, stationId)
    if not databaseReady or not isElement(player) then return false end
    local config = getFuelStationConfig(stationId)
    local station = config and stations[config.id] or nil
    if not config or not station then return false end
    local access = getAccess(player, station)
    local payload = {
        station = buildStationPayload(station, config),
        access = access,
        player = {
            characterId = getCharacterId(player) or 0,
            name = getCharacterName(player),
            cash = getCash(player),
            bank = getBank(player),
            duty = staffDuty[player] == station.id
        },
        vehicle = getVehicleContext(player),
        employees = access.canViewBusiness and getEmployeeList(station.id) or {},
        logs = {}
    }

    if not access.canViewBusiness then
        payload.station.balance = 0
        payload.station.totalRevenue = 0
        payload.station.totalCustomers = 0
        triggerClientEvent(player, "gzl_fuel:receiveContext", resourceRoot, payload)
        return true
    end

    dbQuery(function(queryHandle)
        local result = dbPoll(queryHandle, 0)
        if not isElement(player) then return end
        payload.logs = result or {}
        triggerClientEvent(player, "gzl_fuel:receiveContext", resourceRoot, payload)
    end, database, "SELECT actor_name, event_type, amount, liters, created_at FROM station_logs WHERE station_id = ? ORDER BY id DESC LIMIT 8", station.id)
    return true
end

local function sendResult(player, success, message, stationId)
    if not isElement(player) then return end
    triggerClientEvent(player, "gzl_fuel:actionResult", resourceRoot, success, message)
    if stationId then
        setTimer(function(target, id)
            if isElement(target) then sendContext(target, id) end
        end, 80, 1, player, stationId)
    end
end

local function validateStationAction(player, stationId, action, cooldown)
    if not isValidRemote(player) then return nil end
    if not allowAction(player, action, cooldown or 600) then return nil end
    local config = getFuelStationConfig(stationId)
    local station = config and stations[config.id] or nil
    if not databaseReady or not config or not station then
        notify(player, "İstasyon verileri henüz hazır değil.", "warning")
        return nil
    end
    if not getCharacterId(player) then
        notify(player, "Bu işlem için aktif bir karakter gerekiyor.", "error")
        return nil
    end
    if not isPlayerNearStation(player, config, Config.InteractionDistance + 1.5) then
        notify(player, "İstasyondan çok uzaktasınız.", "error")
        return nil
    end
    return station, config
end

local function findOnlineCharacter(characterId)
    for _, player in ipairs(getElementsByType("player")) do
        if getCharacterId(player) == characterId then return player end
    end
    return nil
end

local function countOwnedStations(characterId)
    local count = 0
    for _, station in pairs(stations) do
        if station.ownerId == characterId then count = count + 1 end
    end
    return count
end

local function findAttendant(stationId, customer)
    local config = getFuelStationConfig(stationId)
    if not config then return nil end
    local closest = nil
    local closestDistance = Config.AttendantRange + 0.01
    for player, dutyStationId in pairs(staffDuty) do
        if dutyStationId == stationId and player ~= customer and isElement(player) then
            local x, y, z = getElementPosition(player)
            local distance = getDistanceBetweenPoints3D(x, y, z, config.x, config.y, config.z)
            if distance < closestDistance then
                closest = player
                closestDistance = distance
            end
        end
    end
    return closest
end

local finishFueling

local function processFueling(player)
    local session = fuelingByPlayer[player]
    if not session then return end
    local vehicle = session.vehicle
    local station = stations[session.stationId]
    local config = getFuelStationConfig(session.stationId)

    if not isElement(player) or not isElement(vehicle) or not station or not config then
        finishFueling(player, false, "Dolum bağlantısı kesildi.")
        return
    end
    if getPedOccupiedVehicle(player) ~= vehicle or getPedOccupiedVehicleSeat(player) ~= 0 then
        finishFueling(player, false, "Araçtan ayrıldığınız için dolum durdu.")
        return
    end
    if getVehicleEngineState(vehicle) then
        finishFueling(player, false, "Motor çalıştırıldığı için dolum durdu.")
        return
    end
    if not isPlayerNearStation(player, config, Config.FuelingDistance) then
        finishFueling(player, false, "Pompadan uzaklaştığınız için dolum durdu.")
        return
    end

    local remaining = session.targetLiters - session.delivered
    local currentFuel = ensureVehicleFuel(vehicle)
    local missing = session.capacity * (100 - currentFuel) / 100
    local step = math.min(Config.FuelingLitersPerTick, remaining, missing, station.stock)
    if step <= 0.01 then
        finishFueling(player, session.delivered > 0, station.stock <= 0.01 and "İstasyon stoğu tükendi." or "Depo doldu.")
        return
    end

    local newDelivered = session.delivered + step
    local newPaid = math.ceil(newDelivered * session.unitPrice)
    local charge = newPaid - session.paid
    local cash = getCash(player)
    if charge > cash then
        finishFueling(player, false, "Nakit bakiyeniz yetersiz kaldı.")
        return
    end

    if charge > 0 then setCash(player, cash - charge) end
    session.delivered = newDelivered
    session.paid = newPaid
    station.stock = math.max(0, station.stock - step)
    station.balance = station.balance + charge
    dirtyStations[station.id] = true
    local newFuel = currentFuel + step / session.capacity * 100
    setFuelInternal(vehicle, newFuel, true)

    triggerClientEvent(player, "gzl_fuel:fuelingProgress", resourceRoot, {
        delivered = round(session.delivered, 1),
        target = round(session.targetLiters, 1),
        paid = session.paid,
        fuel = round(ensureVehicleFuel(vehicle), 1),
        stock = round(station.stock, 1)
    })

    if session.delivered + 0.01 >= session.targetLiters or ensureVehicleFuel(vehicle) >= 99.99 then
        finishFueling(player, true, "Yakıt dolumu tamamlandı.")
    end
end

finishFueling = function(player, completed, reason)
    local session = fuelingByPlayer[player]
    if not session then return false end
    if session.timer and isTimer(session.timer) then killTimer(session.timer) end
    fuelingByPlayer[player] = nil
    if isElement(session.vehicle) then fuelingByVehicle[session.vehicle] = nil end

    local station = stations[session.stationId]
    if station and session.delivered > 0.01 then
        station.totalLiters = station.totalLiters + session.delivered
        station.totalRevenue = station.totalRevenue + session.paid
        station.totalCustomers = station.totalCustomers + 1

        local attendant = session.attendant
        if attendant and isElement(attendant) and staffDuty[attendant] == session.stationId then
            local config = getFuelStationConfig(session.stationId)
            if config and isPlayerNearStation(attendant, config, Config.AttendantRange) then
                local wage = math.floor(session.delivered * Config.AttendantPayPerLiter + 0.5)
                wage = math.min(wage, math.floor(station.balance))
                if wage > 0 then
                    station.balance = station.balance - wage
                    setCash(attendant, getCash(attendant) + wage)
                    notify(attendant, "Pompa hizmetinden $" .. tostring(wage) .. " kazandınız.", "success")
                    logStation(station.id, getCharacterId(attendant), getCharacterName(attendant), "wage", wage, session.delivered)
                end
            end
        end

        logStation(station.id, getCharacterId(player), getCharacterName(player), "fuel_sale", session.paid, session.delivered)
        persistStation(station)
    end

    if isElement(session.vehicle) then persistVehicleFuel(session.vehicle) end
    if isElement(player) and not resourceStopping then
        triggerClientEvent(player, "gzl_fuel:fuelingEnded", resourceRoot, {
            completed = completed,
            message = reason or "Dolum durdu.",
            delivered = round(session.delivered, 1),
            paid = session.paid,
            fuel = isElement(session.vehicle) and round(ensureVehicleFuel(session.vehicle), 1) or 0
        })
        if station then sendContext(player, station.id) end
    end
    return true
end

addEvent("gzl_fuel:requestContext", true)
addEventHandler("gzl_fuel:requestContext", resourceRoot, function(stationId)
    local player = client
    if not isValidRemote(player) or not allowAction(player, "context", 250) then return end
    if not databaseReady then
        triggerClientEvent(player, "gzl_fuel:actionResult", resourceRoot, false, "İstasyon verileri henüz hazır değil.")
        return
    end
    local config = getFuelStationConfig(stationId)
    if not config or not isPlayerNearStation(player, config, Config.InteractionDistance + 2) then
        notify(player, "Geçerli bir istasyonun yakınında değilsiniz.", "error")
        return
    end
    sendContext(player, config.id)
end)

addEvent("gzl_fuel:startFueling", true)
addEventHandler("gzl_fuel:startFueling", resourceRoot, function(stationId, requestedLiters)
    local player = client
    local station, config = validateStationAction(player, stationId, "fuel", 800)
    if not station then return end
    if fuelingByPlayer[player] then
        notify(player, "Zaten devam eden bir dolum işleminiz var.", "warning")
        return
    end

    local vehicle = getPedOccupiedVehicle(player)
    if not vehicle or getPedOccupiedVehicleSeat(player) ~= 0 then
        notify(player, "Yakıt almak için sürücü koltuğunda olmalısınız.", "error")
        return
    end
    if fuelingByVehicle[vehicle] then
        notify(player, "Bu araçta zaten dolum yapılıyor.", "warning")
        return
    end
    if getVehicleEngineState(vehicle) then
        notify(player, "Dolumdan önce motoru kapatın.", "warning")
        return
    end
    if isVehicleBlown(vehicle) then
        notify(player, "Hasarlı araca yakıt doldurulamaz.", "error")
        return
    end

    local vehicleType = getVehicleType(vehicle)
    local capacity = getFuelVehicleCapacity(vehicle)
    if not Config.AllowedVehicleTypes[vehicleType] or capacity <= 0 then
        notify(player, "Bu araç türü pompa ile uyumlu değil.", "error")
        return
    end

    local liters = finiteNumber(requestedLiters)
    if not liters or liters < 0.1 or liters > 250 then
        notify(player, "Geçersiz yakıt miktarı.", "error")
        return
    end
    liters = round(liters, 1)
    local currentFuel = ensureVehicleFuel(vehicle)
    local missing = capacity * (100 - currentFuel) / 100
    liters = math.min(liters, missing, station.stock)
    if liters < 0.1 then
        notify(player, station.stock < 0.1 and "İstasyon stoğu tükendi." or "Aracın deposu zaten dolu.", "warning")
        return
    end

    local estimatedCost = math.ceil(liters * station.price)
    if getCash(player) < estimatedCost then
        notify(player, "Bu dolum için yeterli nakdiniz yok.", "error")
        return
    end

    local session = {
        player = player,
        vehicle = vehicle,
        stationId = station.id,
        capacity = capacity,
        targetLiters = liters,
        delivered = 0,
        paid = 0,
        unitPrice = station.price,
        attendant = findAttendant(station.id, player)
    }
    fuelingByPlayer[player] = session
    fuelingByVehicle[vehicle] = player
    session.timer = setTimer(processFueling, Config.FuelingTickMs, 0, player)
    triggerClientEvent(player, "gzl_fuel:fuelingStarted", resourceRoot, {
        target = liters,
        estimatedCost = estimatedCost,
        unitPrice = station.price,
        attendant = session.attendant and getCharacterName(session.attendant) or nil
    })
end)

addEvent("gzl_fuel:stopFueling", true)
addEventHandler("gzl_fuel:stopFueling", resourceRoot, function()
    local player = client
    if not isValidRemote(player) or not allowAction(player, "stop", 500) then return end
    finishFueling(player, false, "Yakıt dolumu durduruldu.")
end)

addEvent("gzl_fuel:purchaseStation", true)
addEventHandler("gzl_fuel:purchaseStation", resourceRoot, function(stationId)
    local player = client
    local station, config = validateStationAction(player, stationId, "purchase", 1200)
    if not station then return end
    if station.ownerId > 0 then
        sendResult(player, false, "Bu istasyonun zaten bir sahibi var.", station.id)
        return
    end
    local characterId = getCharacterId(player)
    if countOwnedStations(characterId) >= Config.MaxOwnedStations then
        sendResult(player, false, "En fazla " .. tostring(Config.MaxOwnedStations) .. " istasyona sahip olabilirsiniz.", station.id)
        return
    end
    local bank = getBank(player)
    if bank < config.purchasePrice then
        sendResult(player, false, "Banka bakiyeniz satın alma için yetersiz.", station.id)
        return
    end
    setBank(player, bank - config.purchasePrice)
    station.ownerId = characterId
    station.ownerName = getCharacterName(player)
    station.balance = 0
    station.totalLiters = 0
    station.totalRevenue = 0
    station.totalCustomers = 0
    station.price = config.basePrice
    persistStation(station)
    logStation(station.id, characterId, station.ownerName, "business_purchase", config.purchasePrice, 0)
    sendResult(player, true, "İstasyon işletmesini satın aldınız.", station.id)
end)

addEvent("gzl_fuel:setPrice", true)
addEventHandler("gzl_fuel:setPrice", resourceRoot, function(stationId, requestedPrice)
    local player = client
    local station = validateStationAction(player, stationId, "price", 700)
    if not station then return end
    local access = getAccess(player, station)
    if not access.canManage then
        sendResult(player, false, "Fiyat değiştirme yetkiniz yok.", station.id)
        return
    end
    local price = finiteNumber(requestedPrice)
    if not price then return end
    price = round(math.floor(price / Config.PriceStep + 0.5) * Config.PriceStep, 2)
    if price < Config.MinFuelPrice or price > Config.MaxFuelPrice then
        sendResult(player, false, "Litre fiyatı izin verilen aralığın dışında.", station.id)
        return
    end
    station.price = price
    persistStation(station)
    logStation(station.id, getCharacterId(player), getCharacterName(player), "price_change", price, 0)
    sendResult(player, true, "Litre fiyatı güncellendi.", station.id)
end)

addEvent("gzl_fuel:orderStock", true)
addEventHandler("gzl_fuel:orderStock", resourceRoot, function(stationId, requestedAmount, paymentMethod)
    local player = client
    local station, config = validateStationAction(player, stationId, "stock", 900)
    if not station then return end
    local access = getAccess(player, station)
    if not access.canManage then
        sendResult(player, false, "Stok siparişi yetkiniz yok.", station.id)
        return
    end
    local amount = finiteNumber(requestedAmount)
    if not amount then return end
    amount = math.floor(amount / Config.StockOrderStep + 0.5) * Config.StockOrderStep
    amount = math.min(amount, Config.MaxStockOrder, math.floor(config.maxStock - station.stock))
    if amount < Config.StockOrderStep then
        sendResult(player, false, "Depoda bu sipariş için yeterli alan yok.", station.id)
        return
    end
    local cost = math.ceil(amount * config.wholesalePrice)
    if paymentMethod == "balance" then
        if station.balance < cost then
            sendResult(player, false, "İstasyon kasası bu sipariş için yetersiz.", station.id)
            return
        end
        station.balance = station.balance - cost
    elseif paymentMethod == "bank" and access.isOwner then
        local bank = getBank(player)
        if bank < cost then
            sendResult(player, false, "Banka bakiyeniz bu sipariş için yetersiz.", station.id)
            return
        end
        setBank(player, bank - cost)
    else
        sendResult(player, false, "Geçersiz ödeme yöntemi.", station.id)
        return
    end
    station.stock = math.min(config.maxStock, station.stock + amount)
    persistStation(station)
    logStation(station.id, getCharacterId(player), getCharacterName(player), "stock_order", cost, amount)
    sendResult(player, true, tostring(amount) .. " litre yakıt stoğa eklendi.", station.id)
end)

addEvent("gzl_fuel:withdrawBalance", true)
addEventHandler("gzl_fuel:withdrawBalance", resourceRoot, function(stationId, requestedAmount)
    local player = client
    local station = validateStationAction(player, stationId, "withdraw", 900)
    if not station then return end
    local access = getAccess(player, station)
    if not access.canWithdraw then
        sendResult(player, false, "Kasa çekme yetkiniz yok.", station.id)
        return
    end
    local amount = finiteNumber(requestedAmount)
    if not amount then return end
    amount = math.floor(amount)
    if amount < 1 or amount > math.floor(station.balance) then
        sendResult(player, false, "Geçersiz kasa çekim tutarı.", station.id)
        return
    end
    station.balance = station.balance - amount
    setBank(player, getBank(player) + amount)
    persistStation(station)
    logStation(station.id, getCharacterId(player), getCharacterName(player), "withdraw", amount, 0)
    sendResult(player, true, "$" .. tostring(amount) .. " banka hesabınıza aktarıldı.", station.id)
end)

addEvent("gzl_fuel:addEmployee", true)
addEventHandler("gzl_fuel:addEmployee", resourceRoot, function(stationId, targetCharacterId, requestedRole)
    local player = client
    local station = validateStationAction(player, stationId, "hire", 900)
    if not station then return end
    local access = getAccess(player, station)
    if not access.canStaff then
        sendResult(player, false, "Personel yönetimi yalnızca işletme sahibine açıktır.", station.id)
        return
    end
    local targetId = finiteNumber(targetCharacterId)
    local role = tostring(requestedRole or "")
    if not targetId or targetId ~= math.floor(targetId) or targetId < 1 or (role ~= "cashier" and role ~= "manager") then
        sendResult(player, false, "Geçersiz personel bilgisi.", station.id)
        return
    end
    if targetId == station.ownerId then
        sendResult(player, false, "İşletme sahibi personel olarak eklenemez.", station.id)
        return
    end
    local employeeCount = #getEmployeeList(station.id)
    if employeeCount >= Config.MaxEmployees then
        sendResult(player, false, "Maksimum personel sınırına ulaşıldı.", station.id)
        return
    end
    employees[station.id] = employees[station.id] or {}
    if employees[station.id][targetId] then
        sendResult(player, false, "Bu karakter zaten personel listesinde.", station.id)
        return
    end
    local target = findOnlineCharacter(targetId)
    if not target then
        sendResult(player, false, "Bu karakter şu anda çevrimiçi değil.", station.id)
        return
    end
    local employeeName = getCharacterName(target)
    employees[station.id][targetId] = { name = employeeName, role = role }
    dbExec(database, "INSERT OR REPLACE INTO station_employees (station_id, character_id, name, role, joined_at) VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP)", station.id, targetId, employeeName, role)
    logStation(station.id, getCharacterId(player), getCharacterName(player), role == "manager" and "hire_manager" or "hire_cashier", 0, 0)
    notify(target, station.ownerName .. " sizi " .. getFuelStationConfig(station.id).name .. " işletmesine ekledi.", "success")
    sendResult(player, true, employeeName .. " personel listesine eklendi.", station.id)
end)

addEvent("gzl_fuel:removeEmployee", true)
addEventHandler("gzl_fuel:removeEmployee", resourceRoot, function(stationId, targetCharacterId)
    local player = client
    local station = validateStationAction(player, stationId, "fire", 800)
    if not station then return end
    local access = getAccess(player, station)
    if not access.canStaff then
        sendResult(player, false, "Personel yönetimi yalnızca işletme sahibine açıktır.", station.id)
        return
    end
    local targetId = finiteNumber(targetCharacterId)
    if not targetId or targetId ~= math.floor(targetId) or targetId < 1 then
        sendResult(player, false, "Geçersiz personel bilgisi.", station.id)
        return
    end
    targetId = math.floor(targetId)
    local employee = employees[station.id] and employees[station.id][targetId] or nil
    if not employee then
        sendResult(player, false, "Personel kaydı bulunamadı.", station.id)
        return
    end
    employees[station.id][targetId] = nil
    for dutyPlayer, dutyStationId in pairs(staffDuty) do
        if dutyStationId == station.id and getCharacterId(dutyPlayer) == targetId then
            staffDuty[dutyPlayer] = nil
        end
    end
    dbExec(database, "DELETE FROM station_employees WHERE station_id = ? AND character_id = ?", station.id, targetId)
    logStation(station.id, getCharacterId(player), getCharacterName(player), "employee_removed", 0, 0)
    local target = findOnlineCharacter(targetId)
    if target then notify(target, getFuelStationConfig(station.id).name .. " personelinden çıkarıldınız.", "warning") end
    sendResult(player, true, employee.name .. " personel listesinden çıkarıldı.", station.id)
end)

addEvent("gzl_fuel:toggleDuty", true)
addEventHandler("gzl_fuel:toggleDuty", resourceRoot, function(stationId)
    local player = client
    local station = validateStationAction(player, stationId, "duty", 700)
    if not station then return end
    local access = getAccess(player, station)
    if not access.canDuty then
        sendResult(player, false, "Mesai için bu istasyonun personeli olmalısınız.", station.id)
        return
    end
    if getPedOccupiedVehicle(player) then
        sendResult(player, false, "Mesaiye başlamak için araçtan inin.", station.id)
        return
    end
    if staffDuty[player] == station.id then
        staffDuty[player] = nil
        sendResult(player, true, "Mesainiz sona erdi.", station.id)
    else
        staffDuty[player] = station.id
        sendResult(player, true, "Pompa görevlisi mesainiz başladı.", station.id)
    end
end)

addEvent("gzl_fuel:sellStation", true)
addEventHandler("gzl_fuel:sellStation", resourceRoot, function(stationId)
    local player = client
    local station, config = validateStationAction(player, stationId, "sell", 1500)
    if not station then return end
    local access = getAccess(player, station)
    if not access.isOwner then
        sendResult(player, false, "Bu işletmenin sahibi değilsiniz.", station.id)
        return
    end
    for _, session in pairs(fuelingByPlayer) do
        if session.stationId == station.id then
            sendResult(player, false, "Aktif dolumlar bitmeden işletme satılamaz.", station.id)
            return
        end
    end
    local payout = math.floor(config.purchasePrice * Config.BusinessSaleRate + station.balance)
    setBank(player, getBank(player) + payout)
    logStation(station.id, getCharacterId(player), getCharacterName(player), "business_sale", payout, 0)
    station.ownerId = 0
    station.ownerName = ""
    station.price = config.basePrice
    station.balance = 0
    station.totalLiters = 0
    station.totalRevenue = 0
    station.totalCustomers = 0
    employees[station.id] = {}
    for dutyPlayer, dutyStationId in pairs(staffDuty) do
        if dutyStationId == station.id then staffDuty[dutyPlayer] = nil end
    end
    dbExec(database, "DELETE FROM station_employees WHERE station_id = ?", station.id)
    persistStation(station)
    sendResult(player, true, "İşletme devredildi. $" .. tostring(payout) .. " bankanıza yatırıldı.", station.id)
end)

addEventHandler("onVehicleEnter", root, function(player, seat)
    if seat ~= 0 then return end
    local vehicle = source
    ensureVehicleFuel(vehicle)
    setTimer(function(target, driver)
        if isElement(target) and isElement(driver) and getVehicleFuel(target) <= 0.05 then
            setVehicleEngineState(target, false)
            notify(driver, "Yakıt deposu boş. Motor çalıştırılamaz.", "warning")
        end
    end, 700, 1, vehicle, player)
end)

addEventHandler("onElementDataChange", root, function(dataName, oldValue, newValue)
    local elementType = getElementType(source)
    if elementType == "player" and (protectedIdentityKeys[dataName] or protectedCashKeys[dataName] or protectedBankKeys[dataName]) then
        if protectedWrites[source] and protectedWrites[source][dataName] then return end
        if client then
            protectElementData(source, dataName, oldValue)
            return
        end
        local value = finiteNumber(newValue)
        if protectedIdentityKeys[dataName] then
            trustedCharacterIds[source] = value and math.floor(value) or nil
        elseif protectedCashKeys[dataName] then
            trustedCash[source] = value and math.max(0, math.floor(value)) or nil
        elseif protectedBankKeys[dataName] then
            trustedBank[source] = value and math.max(0, math.floor(value)) or nil
        end
        if value and sourceResource ~= getThisResource() then protectElementData(source, dataName, newValue) end
        return
    end
    if dataName ~= Config.FuelElementData or elementType ~= "vehicle" then return end
    if client then
        local trustedValue = exactFuel[source] or finiteNumber(oldValue) or Config.DefaultFuelPercent
        setFuelInternal(source, trustedValue, true)
        return
    end
    local value = finiteNumber(newValue)
    if value then
        exactFuel[source] = clamp(value, 0, 100)
        if getVehicleDatabaseId(source) then dirtyVehicles[source] = true end
    end
end)

addEventHandler("onElementDestroy", root, function()
    if getElementType(source) ~= "vehicle" then return end
    local player = fuelingByVehicle[source]
    if player then finishFueling(player, false, "Araç artık kullanılamıyor.") end
    persistVehicleFuel(source)
    exactFuel[source] = nil
    loadingFuel[source] = nil
    loadedFuel[source] = nil
    dirtyVehicles[source] = nil
    emptyWarnings[source] = nil
    lowFuelWarnings[source] = nil
end)

addEventHandler("onPlayerQuit", root, function()
    if fuelingByPlayer[source] then finishFueling(source, false, "Oyuncu bağlantısı kesildi.") end
    staffDuty[source] = nil
    rateLimits[source] = nil
    trustedCharacterIds[source] = nil
    trustedCash[source] = nil
    trustedBank[source] = nil
    protectedWrites[source] = nil
end)

setTimer(function()
    for _, vehicle in ipairs(getElementsByType("vehicle")) do
        if not fuelingByVehicle[vehicle] and getVehicleEngineState(vehicle) then
            local controller = getVehicleController(vehicle)
            local vehicleType = getVehicleType(vehicle)
            local capacity = getFuelVehicleCapacity(vehicle)
            local consumption = Config.VehicleConsumption[vehicleType]
            if controller and capacity > 0 and consumption then
                local fuel = ensureVehicleFuel(vehicle)
                if fuel <= 0.05 then
                    setFuelInternal(vehicle, 0, true)
                    setVehicleEngineState(vehicle, false)
                    if not emptyWarnings[vehicle] then
                        emptyWarnings[vehicle] = true
                        notify(controller, "Yakıtınız tükendi. Motor durduruldu.", "warning")
                    end
                else
                    local vx, vy, vz = getElementVelocity(vehicle)
                    local speed = getDistanceBetweenPoints3D(0, 0, 0, vx, vy, vz) * 180
                    local traveledKm = speed * Config.ConsumptionTickMs / 3600000
                    local usedLiters = traveledKm * consumption / 100 * Config.ConsumptionMultiplier
                    usedLiters = usedLiters + 0.004 * Config.ConsumptionMultiplier
                    local newFuel = fuel - usedLiters / capacity * 100
                    setFuelInternal(vehicle, newFuel, true)
                    if newFuel <= 5 and (not lowFuelWarnings[vehicle] or getTickCount() - lowFuelWarnings[vehicle] > 120000) then
                        lowFuelWarnings[vehicle] = getTickCount()
                        notify(controller, "Yakıt seviyesi kritik: %" .. tostring(math.floor(math.max(0, newFuel))) .. ".", "warning")
                    end
                end
            end
        end
    end
end, Config.ConsumptionTickMs, 0)

setTimer(function()
    for vehicle in pairs(dirtyVehicles) do
        if isElement(vehicle) then
            persistVehicleFuel(vehicle)
        else
            dirtyVehicles[vehicle] = nil
        end
    end
end, Config.VehicleSaveIntervalMs, 0)

setTimer(function()
    for stationId in pairs(dirtyStations) do
        if stations[stationId] then persistStation(stations[stationId]) end
    end
    for player, stationId in pairs(staffDuty) do
        local config = getFuelStationConfig(stationId)
        if not isElement(player) or not config or not isPlayerNearStation(player, config, Config.AttendantRange) then
            if isElement(player) then notify(player, "İstasyondan uzaklaştığınız için mesainiz sona erdi.", "warning") end
            staffDuty[player] = nil
        end
    end
end, Config.StationSaveIntervalMs, 0)

addEventHandler("onResourceStart", resourceRoot, function()
    database = dbConnect("sqlite", "fuel.db", "", "", "share=1;batch=1;queue=gzl_fuel")
    if not database then
        outputDebugString("[GZL Fuel] Veritabanı bağlantısı kurulamadı.", 1)
        return
    end

    dbExec(database, [[
        CREATE TABLE IF NOT EXISTS stations (
            id INTEGER PRIMARY KEY,
            owner_id INTEGER NOT NULL DEFAULT 0,
            owner_name TEXT NOT NULL DEFAULT '',
            price REAL NOT NULL,
            stock REAL NOT NULL,
            balance REAL NOT NULL DEFAULT 0,
            total_liters REAL NOT NULL DEFAULT 0,
            total_revenue REAL NOT NULL DEFAULT 0,
            total_customers INTEGER NOT NULL DEFAULT 0,
            updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
        )
    ]])
    dbExec(database, [[
        CREATE TABLE IF NOT EXISTS station_employees (
            station_id INTEGER NOT NULL,
            character_id INTEGER NOT NULL,
            name TEXT NOT NULL,
            role TEXT NOT NULL,
            joined_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (station_id, character_id)
        )
    ]])
    dbExec(database, [[
        CREATE TABLE IF NOT EXISTS station_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            station_id INTEGER NOT NULL,
            actor_id INTEGER NOT NULL DEFAULT 0,
            actor_name TEXT NOT NULL,
            event_type TEXT NOT NULL,
            amount REAL NOT NULL DEFAULT 0,
            liters REAL NOT NULL DEFAULT 0,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        )
    ]])
    dbExec(database, [[
        CREATE TABLE IF NOT EXISTS vehicle_fuel (
            vehicle_id INTEGER PRIMARY KEY,
            fuel REAL NOT NULL,
            updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
        )
    ]])

    for _, config in ipairs(Config.Stations) do
        dbExec(database, "INSERT OR IGNORE INTO stations (id, price, stock) VALUES (?, ?, ?)", config.id, config.basePrice, config.stock)
    end

    dbQuery(function(stationQuery)
        local stationRows = dbPoll(stationQuery, 0) or {}
        for _, row in ipairs(stationRows) do
            local config = getFuelStationConfig(row.id)
            if config then
                stations[config.id] = {
                    id = config.id,
                    ownerId = math.max(0, math.floor(tonumber(row.owner_id) or 0)),
                    ownerName = cleanName(row.owner_name or ""),
                    price = clamp(tonumber(row.price) or config.basePrice, Config.MinFuelPrice, Config.MaxFuelPrice),
                    stock = clamp(tonumber(row.stock) or config.stock, 0, config.maxStock),
                    balance = math.max(0, tonumber(row.balance) or 0),
                    totalLiters = math.max(0, tonumber(row.total_liters) or 0),
                    totalRevenue = math.max(0, tonumber(row.total_revenue) or 0),
                    totalCustomers = math.max(0, math.floor(tonumber(row.total_customers) or 0))
                }
                employees[config.id] = {}
            end
        end

        dbQuery(function(employeeQuery)
            local employeeRows = dbPoll(employeeQuery, 0) or {}
            for _, row in ipairs(employeeRows) do
                local stationId = tonumber(row.station_id)
                local characterId = tonumber(row.character_id)
                if employees[stationId] and characterId then
                    employees[stationId][characterId] = {
                        name = cleanName(row.name),
                        role = row.role == "manager" and "manager" or "cashier"
                    }
                end
            end
            databaseReady = true
            for _, player in ipairs(getElementsByType("player")) do
                capturePlayerState(player)
            end
            for _, vehicle in ipairs(getElementsByType("vehicle")) do
                ensureVehicleFuel(vehicle)
            end
            outputDebugString("[GZL Fuel] " .. tostring(#Config.Stations) .. " istasyon hazır.", 3)
        end, database, "SELECT station_id, character_id, name, role FROM station_employees")
    end, database, "SELECT id, owner_id, owner_name, price, stock, balance, total_liters, total_revenue, total_customers FROM stations")
end)

addEventHandler("onResourceStop", resourceRoot, function()
    resourceStopping = true
    local activePlayers = {}
    for player in pairs(fuelingByPlayer) do
        activePlayers[#activePlayers + 1] = player
    end
    for _, player in ipairs(activePlayers) do
        finishFueling(player, false, "Yakıt sistemi durduruldu.")
    end
    for vehicle in pairs(dirtyVehicles) do
        if isElement(vehicle) then persistVehicleFuel(vehicle) end
    end
    for stationId in pairs(dirtyStations) do
        if stations[stationId] then persistStation(stations[stationId]) end
    end
end)