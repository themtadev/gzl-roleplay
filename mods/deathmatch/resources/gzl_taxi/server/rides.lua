local activeTaxiRides = {}
local pendingTaxiCalls = {}
local callRequestTicks = {}
local trustedTaxiRatings = {}
local nextTaxiCallId = 0
local rideMonitorTimer = nil
local spotsById = {}

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function getRemotePlayer()
    if client and source == resourceRoot and isElement(client) and getElementType(client) == "player" then
        return client
    end
    return nil
end

local function getVehicleSpeedKmh(vehicle)
    local vx, vy, vz = getElementVelocity(vehicle)
    return math.sqrt(vx * vx + vy * vy + vz * vz) * 180
end

local function getTaxiPlate(vehicle)
    return getVehiclePlateText(vehicle)
end

local function isAuthorizedTaxiVehicle(vehicle)
    if not isElement(vehicle) or getElementType(vehicle) ~= "vehicle" then
        return false
    end
    return isTaxiPlateRegistered and isTaxiPlateRegistered(getTaxiPlate(vehicle)) or false
end

function setTaxiVehicleRating(vehicle, rating)
    if not isElement(vehicle) or getElementType(vehicle) ~= "vehicle" then
        return false
    end
    rating = tonumber(rating)
    if not rating then return false end
    rating = clamp(rating, 1.0, 5.0)
    trustedTaxiRatings[vehicle] = rating
    setElementData(vehicle, "taxi:rating", rating, "broadcast", "deny")
    return true
end

local function getTrustedTaxiRating(vehicle)
    local rating = trustedTaxiRatings[vehicle]
    if rating then
        return rating
    end
    return TaxiConfig.VehicleRatings[getElementModel(vehicle)] or TaxiConfig.DefaultVehicleRating
end

local function getDriverTaxiVehicle(player, expectedVehicle)
    local vehicle = getPedOccupiedVehicle(player)
    if not isElement(vehicle) or vehicle ~= expectedVehicle then
        return nil
    end
    if getVehicleOccupant(vehicle, 0) ~= player or not isAuthorizedTaxiVehicle(vehicle) then
        return nil
    end
    if getElementInterior(vehicle) ~= 0 or getElementDimension(vehicle) ~= 0 then
        return nil
    end
    return vehicle
end

local function findEmptyPassengerSeat(vehicle)
    local maxPassengers = getVehicleMaxPassengers(vehicle) or 0
    for seat = 1, maxPassengers do
        if not getVehicleOccupant(vehicle, seat) then
            return seat
        end
    end
    return nil
end

local function hasPassengerOccupant(vehicle)
    local maxPassengers = getVehicleMaxPassengers(vehicle) or 0
    for seat = 1, maxPassengers do
        if getVehicleOccupant(vehicle, seat) then
            return true
        end
    end
    return false
end

local function getSpot(spotId)
    return spotsById[tonumber(spotId)]
end

local function getCustomerData(spot)
    local classData = TaxiConfig.CustomerClasses[spot.classIdx] or TaxiConfig.CustomerClasses[1]
    local destination = TaxiConfig.Destinations[spot.destIdx] or TaxiConfig.Destinations[1]
    local ratingSeed = ((spot.id * 31 + spot.classIdx * 7) % 10) / 10
    local requiredRating = classData.minRating + ratingSeed * (classData.maxRating - classData.minRating)
    requiredRating = math.floor(requiredRating * 10 + 0.5) / 10
    return classData, destination, requiredRating
end

local function getPlayerPositionDistance(player, spot)
    local px, py, pz = getElementPosition(player)
    return getDistanceBetweenPoints3D(px, py, pz, spot.x, spot.y, spot.z)
end

local function nextCallIdentifier()
    nextTaxiCallId = nextTaxiCallId + 1
    if nextTaxiCallId > 2147483000 then
        nextTaxiCallId = 1
    end
    return nextTaxiCallId
end

local function notifyCallEnded(player, eventName, message)
    if isElement(player) then
        triggerClientEvent(player, eventName, player, message)
    end
end

local function clearTaxiState(player, message)
    local hadPendingCall = pendingTaxiCalls[player] ~= nil
    local hadRide = activeTaxiRides[player] ~= nil
    pendingTaxiCalls[player] = nil
    activeTaxiRides[player] = nil
    if hadPendingCall then
        notifyCallEnded(player, "taxi:callCancelled", message or "Çağrı sonlandırıldı.")
    end
    if hadRide then
        notifyCallEnded(player, "taxi:forceCancelRide", message or "Yolculuk sonlandırıldı.")
    end
end

local function applyServicePenalty(ride, amount)
    if not ride or ride.state ~= "destination" then return end
    ride.serviceMultiplier = clamp(ride.serviceMultiplier - amount, TaxiConfig.Ride.minimumServiceMultiplier, TaxiConfig.Ride.maximumServiceMultiplier)
end

local function sampleRideDistance(ride)
    local vehicle = ride.vehicle
    if not isElement(vehicle) then return false end
    local x, y, z = getElementPosition(vehicle)
    local previous = ride.lastPosition
    if previous then
        local segment = getDistanceBetweenPoints3D(previous.x, previous.y, previous.z, x, y, z)
        if segment <= TaxiConfig.Ride.maximumSampleDistance then
            ride.travelDistance = ride.travelDistance + segment
        else
            ride.invalidSegments = ride.invalidSegments + 1
        end
    end
    ride.lastPosition = { x = x, y = y, z = z }
    return true
end

local function selectCallSpot(player, vehicle)
    local vehicleRating = getTrustedTaxiRating(vehicle)
    local candidates = {}
    for _, spot in ipairs(TaxiConfig.CustomerSpawns) do
        local _, _, requiredRating = getCustomerData(spot)
        local distance = getPlayerPositionDistance(player, spot)
        if requiredRating <= vehicleRating + 0.01 and distance >= TaxiConfig.Ride.minimumPickupDistance and distance <= TaxiConfig.Ride.maximumPickupDistance then
            table.insert(candidates, { spot = spot, distance = distance, requiredRating = requiredRating })
        end
    end
    table.sort(candidates, function(a, b)
        return a.distance < b.distance
    end)
    local count = math.min(8, #candidates)
    if count == 0 then
        return nil
    end
    return candidates[math.random(1, count)], vehicleRating
end

local function isCallValid(player, call)
    if not call or pendingTaxiCalls[player] ~= call then
        return false
    end
    if getTickCount() > call.expiresTick then
        return false
    end
    return getDriverTaxiVehicle(player, call.vehicle) ~= nil
end

addEvent("taxi:requestTaxiCall", true)
addEventHandler("taxi:requestTaxiCall", resourceRoot, function()
    local player = getRemotePlayer()
    if not player then return end
    if pendingTaxiCalls[player] or activeTaxiRides[player] then
        triggerClientEvent(player, "taxi:callUnavailable", player, "Önce mevcut çağrını tamamla.")
        return
    end
    local now = getTickCount()
    local previousTick = callRequestTicks[player] or 0
    if now - previousTick < TaxiConfig.Ride.callRequestCooldown then
        triggerClientEvent(player, "taxi:callUnavailable", player, "Yeni çağrı hazırlanıyor.")
        return
    end
    callRequestTicks[player] = now
    local vehicle = getPedOccupiedVehicle(player)
    if not isElement(vehicle) or getVehicleOccupant(vehicle, 0) ~= player or not isAuthorizedTaxiVehicle(vehicle) then
        triggerClientEvent(player, "taxi:callUnavailable", player, "Çağrı almak için taksinin sürücü koltuğunda olmalısın.")
        return
    end
    if getElementInterior(vehicle) ~= 0 or getElementDimension(vehicle) ~= 0 then
        triggerClientEvent(player, "taxi:callUnavailable", player, "Bu bölgede taksi çağrısı alınamıyor.")
        return
    end
    local selected, vehicleRating = selectCallSpot(player, vehicle)
    if not selected then
        triggerClientEvent(player, "taxi:callUnavailable", player, "Aracına uygun yakında müşteri bulunamadı.")
        return
    end
    local call = {
        id = nextCallIdentifier(),
        spotId = selected.spot.id,
        vehicle = vehicle,
        expiresTick = now + TaxiConfig.Ride.callLifetime,
        vehicleRating = vehicleRating,
        requiredRating = selected.requiredRating
    }
    pendingTaxiCalls[player] = call
    triggerClientEvent(player, "taxi:incomingCall", player, call.id, call.spotId, TaxiConfig.Ride.callLifetime, call.vehicleRating, call.requiredRating)
end)

addEvent("taxi:respondToTaxiCall", true)
addEventHandler("taxi:respondToTaxiCall", resourceRoot, function(callId, accepted)
    local player = getRemotePlayer()
    if not player then return end
    local call = pendingTaxiCalls[player]
    if not call or tonumber(callId) ~= call.id then return end
    if not isCallValid(player, call) then
        pendingTaxiCalls[player] = nil
        notifyCallEnded(player, "taxi:callExpired", "Çağrının süresi doldu.")
        return
    end
    pendingTaxiCalls[player] = nil
    if accepted ~= true then
        notifyCallEnded(player, "taxi:callCancelled", "Çağrı reddedildi.")
        return
    end
    activeTaxiRides[player] = {
        state = "pickup",
        callId = call.id,
        spotId = call.spotId,
        vehicle = call.vehicle,
        acceptedTick = getTickCount(),
        vehicleRating = call.vehicleRating,
        requiredRating = call.requiredRating
    }
    triggerClientEvent(player, "taxi:callAccepted", player, call.id, call.spotId, call.vehicleRating, call.requiredRating)
end)

addEvent("taxi:requestBoardCustomer", true)
addEventHandler("taxi:requestBoardCustomer", resourceRoot, function(spotId, callId)
    local player = getRemotePlayer()
    if not player then return end
    local ride = activeTaxiRides[player]
    if not ride or ride.state ~= "pickup" or ride.spotId ~= tonumber(spotId) or ride.callId ~= tonumber(callId) then
        return
    end
    local vehicle = getDriverTaxiVehicle(player, ride.vehicle)
    if not vehicle then
        clearTaxiState(player, "Taksi bağlantısı kesildi.")
        return
    end
    local spot = getSpot(ride.spotId)
    if not spot then
        clearTaxiState(player, "Müşteri bilgisi bulunamadı.")
        return
    end
    local vx, vy, vz = getElementPosition(vehicle)
    if getDistanceBetweenPoints3D(vx, vy, vz, spot.x, spot.y, spot.z) > TaxiConfig.Ride.pickupRadius then
        return
    end
    if getVehicleSpeedKmh(vehicle) > TaxiConfig.Ride.pickupMaxSpeed then
        triggerClientEvent(player, "taxi:pickupDenied", player, "Müşteriyi almak için yavaşla.")
        return
    end
    if hasPassengerOccupant(vehicle) then
        triggerClientEvent(player, "taxi:pickupDenied", player, "Müşteri almak için araçta başka yolcu olmamalı.")
        return
    end
    local seat = findEmptyPassengerSeat(vehicle)
    if not seat then
        triggerClientEvent(player, "taxi:pickupDenied", player, "Müşteri için boş koltuk yok.")
        return
    end
    local classData, destination = getCustomerData(spot)
    ride.state = "destination"
    ride.destIndex = spot.destIdx
    ride.startedTick = getTickCount()
    ride.startPosition = { x = vx, y = vy, z = vz }
    ride.lastPosition = { x = vx, y = vy, z = vz }
    ride.travelDistance = 0
    ride.invalidSegments = 0
    ride.serviceMultiplier = 1.0
    ride.basePayMultiplier = classData.payMultiplier
    ride.straightDistance = getDistanceBetweenPoints3D(vx, vy, vz, destination.x, destination.y, destination.z)
    ride.lastSpeedPenaltyTick = ride.startedTick
    triggerClientEvent(player, "taxi:syncBoardingAndStartRide", player, ride.spotId, seat, ride.callId, ride.vehicleRating, ride.requiredRating)
end)

addEvent("taxi:cancelRide", true)
addEventHandler("taxi:cancelRide", resourceRoot, function()
    local player = getRemotePlayer()
    if not player then return end
    pendingTaxiCalls[player] = nil
    activeTaxiRides[player] = nil
end)

addEvent("taxi:completeRide", true)
addEventHandler("taxi:completeRide", resourceRoot, function(destIndex, callId)
    local player = getRemotePlayer()
    if not player then return end
    local ride = activeTaxiRides[player]
    if not ride or ride.state ~= "destination" or ride.destIndex ~= tonumber(destIndex) or ride.callId ~= tonumber(callId) then
        return
    end
    local vehicle = getDriverTaxiVehicle(player, ride.vehicle)
    if not vehicle then
        clearTaxiState(player, "Taksi bağlantısı kesildi.")
        return
    end
    local destination = TaxiConfig.Destinations[ride.destIndex]
    if not destination then
        clearTaxiState(player, "Hedef bilgisi bulunamadı.")
        return
    end
    sampleRideDistance(ride)
    local vx, vy, vz = getElementPosition(vehicle)
    local distanceToDestination = getDistanceBetweenPoints3D(vx, vy, vz, destination.x, destination.y, destination.z)
    if distanceToDestination > TaxiConfig.Ride.deliveryRadius or getVehicleSpeedKmh(vehicle) > TaxiConfig.Ride.deliveryMaxSpeed then
        triggerClientEvent(player, "taxi:rideCompletionFailed", player, "Yeşil park alanında tamamen durmalısın.")
        return
    end
    local elapsedSeconds = (getTickCount() - ride.startedTick) / 1000
    local maximumAverageMetersPerSecond = TaxiConfig.Ride.maximumAverageSpeed / 3.6
    local minimumSeconds = math.max(TaxiConfig.Ride.minimumDuration, ride.straightDistance / maximumAverageMetersPerSecond)
    local minimumDistance = math.max(35.0, ride.straightDistance * TaxiConfig.Ride.minimumRouteProgress)
    if elapsedSeconds < minimumSeconds or ride.travelDistance < minimumDistance or ride.invalidSegments > 1 then
        activeTaxiRides[player] = nil
        triggerClientEvent(player, "taxi:rideCompletionFailed", player, "Yolculuk sunucuda doğrulanamadı.", true)
        return
    end
    local maximumPaidDistance = math.max(150.0, ride.straightDistance * TaxiConfig.Ride.maximumRouteMultiplier)
    local paidDistance = math.min(ride.travelDistance, maximumPaidDistance)
    local fastDeliveryMetersPerSecond = TaxiConfig.Ride.fastDeliveryTargetSpeed / 3.6
    local targetSeconds = math.max(TaxiConfig.Ride.minimumDuration, ride.straightDistance / fastDeliveryMetersPerSecond)
    local speedBonus = elapsedSeconds <= targetSeconds and TaxiConfig.Ride.fastDeliveryBonus or 1.0
    local finalMultiplier = clamp(ride.basePayMultiplier * ride.serviceMultiplier * speedBonus, 0.5, 5.0)
    local rawFare = TaxiConfig.Pricing.baseFare + paidDistance * TaxiConfig.Pricing.perMeterRate
    local totalFare = math.floor(clamp(rawFare * finalMultiplier, TaxiConfig.Pricing.minFare, TaxiConfig.Pricing.maxFare))
    local currentMoney = tonumber(getPlayerMoney(player)) or 0
    local updatedMoney = math.max(0, math.floor(currentMoney)) + totalFare
    setElementData(player, "character:money", updatedMoney, "broadcast", "deny")
    setElementData(player, "char:money", updatedMoney, "broadcast", "deny")
    setPlayerMoney(player, updatedMoney)
    if exports.gzl_characters and exports.gzl_characters.saveCharacter then
        exports.gzl_characters:saveCharacter(player)
    end
    activeTaxiRides[player] = nil
    triggerClientEvent(player, "taxi:rideCompleted", player, {
        amount = totalFare,
        multiplier = finalMultiplier,
        distance = math.floor(paidDistance),
        duration = math.floor(elapsedSeconds)
    })
end)

local function monitorTaxiStates()
    local now = getTickCount()
    for player, call in pairs(pendingTaxiCalls) do
        if now > call.expiresTick or not isCallValid(player, call) then
            pendingTaxiCalls[player] = nil
            notifyCallEnded(player, "taxi:callExpired", "Çağrının süresi doldu.")
        end
    end
    for player, ride in pairs(activeTaxiRides) do
        local vehicle = getDriverTaxiVehicle(player, ride.vehicle)
        if not vehicle then
            clearTaxiState(player, "Taksi bağlantısı kesildi.")
        elseif ride.state == "pickup" then
            if now - ride.acceptedTick > TaxiConfig.Ride.pickupTimeout then
                clearTaxiState(player, "Müşteri daha fazla beklemedi.")
            end
        elseif ride.state == "destination" then
            sampleRideDistance(ride)
            if getVehicleSpeedKmh(vehicle) > TaxiConfig.Ride.maximumComfortSpeed and now - ride.lastSpeedPenaltyTick >= TaxiConfig.Ride.speedPenaltyInterval then
                ride.lastSpeedPenaltyTick = now
                applyServicePenalty(ride, TaxiConfig.Ride.speedPenalty)
                triggerClientEvent(player, "taxi:ridePenalty", player, TaxiConfig.Ride.speedPenalty)
            end
        end
    end
end

addEventHandler("onVehicleDamage", root, function(attacker, weapon, loss)
    local damage = tonumber(loss) or 0
    if damage <= 0 then return end
    for player, ride in pairs(activeTaxiRides) do
        if ride.state == "destination" and ride.vehicle == source then
            applyServicePenalty(ride, TaxiConfig.Ride.collisionPenalty)
            triggerClientEvent(player, "taxi:ridePenalty", player, TaxiConfig.Ride.collisionPenalty)
        end
    end
end)

addEventHandler("onVehicleExit", root, function(player, seat)
    if seat == 0 then
        clearTaxiState(player, "Taksiden indiğin için yolculuk iptal edildi.")
    end
end)

addEventHandler("onVehicleExplode", root, function()
    local affectedPlayers = {}
    for player, call in pairs(pendingTaxiCalls) do
        if call.vehicle == source then
            table.insert(affectedPlayers, player)
        end
    end
    for player, ride in pairs(activeTaxiRides) do
        if ride.vehicle == source then
            table.insert(affectedPlayers, player)
        end
    end
    for _, player in ipairs(affectedPlayers) do
        clearTaxiState(player, "Araç hasar gördüğü için yolculuk iptal edildi.")
    end
end)

addEventHandler("onElementDestroy", root, function()
    if getElementType(source) ~= "vehicle" then return end
    local affectedPlayers = {}
    for player, call in pairs(pendingTaxiCalls) do
        if call.vehicle == source then
            table.insert(affectedPlayers, player)
        end
    end
    for player, ride in pairs(activeTaxiRides) do
        if ride.vehicle == source then
            table.insert(affectedPlayers, player)
        end
    end
    for _, player in ipairs(affectedPlayers) do
        clearTaxiState(player, "Araç artık kullanılamıyor.")
    end
    trustedTaxiRatings[source] = nil
end)

addEventHandler("onPlayerQuit", root, function()
    pendingTaxiCalls[source] = nil
    activeTaxiRides[source] = nil
    callRequestTicks[source] = nil
end)

addEventHandler("onPlayerWasted", root, function()
    clearTaxiState(source, "Öldüğün için yolculuk iptal edildi.")
end)

addEventHandler("onResourceStart", resourceRoot, function()
    spotsById = {}
    for _, spot in ipairs(TaxiConfig.CustomerSpawns) do
        spotsById[spot.id] = spot
    end
    if isTimer(rideMonitorTimer) then
        killTimer(rideMonitorTimer)
    end
    rideMonitorTimer = setTimer(monitorTaxiStates, TaxiConfig.Ride.sampleInterval, 0)
end)

addEventHandler("onResourceStop", resourceRoot, function()
    if isTimer(rideMonitorTimer) then
        killTimer(rideMonitorTimer)
    end
    rideMonitorTimer = nil
    activeTaxiRides = {}
    pendingTaxiCalls = {}
    callRequestTicks = {}
    trustedTaxiRatings = {}
end)