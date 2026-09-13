local buckets, logTimes = {}, {}
local authorityKeys = {
    "loggedin", "loggedin_character", "account:id", "account:username", "account:admin",
    "character:id", "char:id", "character:admin", "admin_level", "admin", "admin:level",
    "character:money", "char:money", "character:bank", "char:bank"
}
local function protectPlayer(player)
    for _, key in ipairs(authorityKeys) do
        setElementData(player, key, getElementData(player, key, false), "broadcast", "deny")
    end
end
addEventHandler("onPlayerJoin", root, function() protectPlayer(source) end)
addEventHandler("onResourceStart", resourceRoot, function()
    for _, player in ipairs(getElementsByType("player")) do protectPlayer(player) end
end)
local function report(player, reason)
    if not isElement(player) then return end
    local now = getTickCount()
    local last = logTimes[player]
    if last and now >= last and now - last < 5000 then return end
    logTimes[player] = now
    outputServerLog("[GZL-AC] " .. getPlayerName(player):gsub("[%c]", "") .. " | " .. reason)
end

local function validValue(value, depth, budget, seen)
    budget.n = budget.n + 1
    if budget.n > 512 then return false end
    local kind = type(value)
    if kind == "number" then return value == value and value ~= math.huge and value ~= -math.huge end
    if kind == "string" then
        budget.bytes = budget.bytes + #value
        return #value <= 32768 and budget.bytes <= 65536
    end
    if kind == "table" then
        if depth > 5 or seen[value] then return false end
        seen[value] = true
        for key, item in pairs(value) do
            if not validValue(key, depth + 1, budget, seen) or not validValue(item, depth + 1, budget, seen) then return false end
        end
        seen[value] = nil
    end
    return true
end

function allowEvent(player, name, ...)
    if not isElement(player) or getElementType(player) ~= "player" or type(name) ~= "string" then return false end
    local now = getTickCount()
    local bucket = buckets[player]
    if not bucket or now < bucket.tick or now - bucket.tick >= 1000 then
        bucket = {tick = now, count = 0, events = {}}
        buckets[player] = bucket
    end
    bucket.count = bucket.count + 1
    bucket.events[name] = (bucket.events[name] or 0) + 1
    local maximum = name:find("auth:", 1, true) == 1 and 2 or 20
    if bucket.count > 80 or bucket.events[name] > maximum then
        report(player, "blocked event rate: " .. name)
        return false
    end
    local budget, seen = {n = 0, bytes = 0}, {}
    for i = 1, select("#", ...) do
        if not validValue(select(i, ...), 0, budget, seen) then
            report(player, "blocked invalid payload: " .. name)
            return false
        end
    end
    return true
end

addEventHandler("onPlayerTriggerEventThreshold", root, function()
    report(source, "engine event threshold exceeded")
end)
addEventHandler("onPlayerTriggerInvalidEvent", root, function()
    report(source, "invalid remote event attempted")
end)
addEventHandler("onPlayerChangesProtectedData", root, function()
    report(source, "engine rejected protected element data change")
end)
addEventHandler("onPlayerTeleport", root, function()
    report(source, "unexpected movement; review required (no automatic ban)")
end)

local projectileWeapons = {[16] = 16, [17] = 17, [18] = 18, [19] = 35, [20] = 36, [39] = 39}
local projectileRates = {}
addEventHandler("onPlayerProjectileCreation", root, function(projectileType, x, y, z)
    local now = getTickCount()
    local rate = projectileRates[source]
    if not rate or now < rate.tick or now - rate.tick >= 1000 then
        rate = {tick = now, count = 0}
        projectileRates[source] = rate
    end
    rate.count = rate.count + 1
    if rate.count > 30 then
        cancelEvent()
        report(source, "blocked projectile flood")
        return
    end
    if getPedOccupiedVehicle(source) then return end
    local weapon = projectileWeapons[projectileType]
    if not weapon then
        cancelEvent()
        report(source, "blocked on-foot vehicle projectile")
        return
    end
    if getPedWeapon(source, getSlotFromWeapon(weapon)) ~= weapon then
        report(source, "projectile weapon mismatch: " .. tostring(weapon))
    end
end)

addEventHandler("onPlayerWeaponFire", root, function(weapon)
    if getPedWeapon(source, getSlotFromWeapon(weapon)) ~= weapon then
        report(source, "bullet weapon mismatch: " .. tostring(weapon))
    end
end)
addEventHandler("onPlayerQuit", root, function()
    buckets[source], logTimes[source] = nil, nil
    projectileRates[source] = nil
end)