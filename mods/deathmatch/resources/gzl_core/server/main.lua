function spawnRoleplayPlayer(player)
    if not isElement(player) then return end

    local spawn = Config.DefaultSpawn
    local charSkin = getElementData(player, "character:skin") or spawn.skin

    spawnPlayer(player, spawn.x, spawn.y, spawn.z, spawn.rot, charSkin, spawn.interior, spawn.dimension)
    setCameraTarget(player, player)
    fadeCamera(player, true, Config.FadeInDuration)

    if not getElementData(player, "character:money") then
        setElementData(player, "character:money", Config.StartingMoney, "broadcast", "deny")
        setPlayerMoney(player, Config.StartingMoney)
    end
    setPedStat(player, 22, 1000)
end

addEventHandler("onPlayerWasted", root, function()
    local emsRes = getResourceFromName("gzl_ems")
    if emsRes and getResourceState(emsRes) == "running" then
        return
    end

    local player = source
    if getElementData(player, "loggedin_character") then
        setTimer(function()
            if isElement(player) and getElementData(player, "loggedin_character") then
                spawnRoleplayPlayer(player)
            end
        end, 4000, 1)
    end
end)

local function findTargetPlayer(query)
    if not query or query == "" then return nil end
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

    if numId then
        local all = getElementsByType("player")
        if all[numId] then
            return all[numId]
        end
    end

    return nil
end

function handleGetPos(player, cmd)
    if not isElement(player) then return end
    local x, y, z = getElementPosition(player)
    local _, _, rz = getElementRotation(player)
    local interior = getElementInterior(player)
    local dimension = getElementDimension(player)

    local simplePos = string.format("%.2f, %.2f, %.2f", x, y, z)
    local configTable = string.format("{ x = %.2f, y = %.2f, z = %.2f, rot = %.2f, interior = %d, dimension = %d }", x, y, z, rz, interior, dimension)

    outputChatBox("#38bdf8[GZL-POS]#ffffff Koordinat: #38bdf8" .. simplePos, player, 255, 255, 255, true)
    outputChatBox("#38bdf8[GZL-POS]#ffffff Rot: #e2e8f0" .. string.format("%.2f", rz) .. " #ffffff| Int: #e2e8f0" .. tostring(interior) .. " #ffffff| Dim: #e2e8f0" .. tostring(dimension), player, 255, 255, 255, true)
    outputConsole("[GZL-POS] " .. configTable, player)
end
addCommandHandler("getpos", handleGetPos)
addCommandHandler("gp", handleGetPos)
addCommandHandler("pos", handleGetPos)

function handleTeleport(player, cmd, ...)
    if not isElement(player) then return end
    if not isAdmin(player) then
        outputChatBox("#ef4444[GZL-TP]#ffffff Bu komutu kullanmak için yönetici yetkiniz bulunmamaktadır!", player, 255, 255, 255, true)
        return
    end
    local rawArgs = table.concat({...}, " ")
    rawArgs = string.gsub(rawArgs, "^%s*(.-)%s*$", "%1")

    if rawArgs == "" then
        outputChatBox("#38bdf8[GZL-TP]#ffffff Kullanım:", player, 255, 255, 255, true)
        outputChatBox("  #e2e8f0/tp <oyuncu_id / isim>#ffffff (Örn: /tp 1 veya /tp Ahmet)", player, 255, 255, 255, true)
        outputChatBox("  #e2e8f0/tp <x> <y> <z> [interior] [dimension]#ffffff (Örn: /tp 259, 198, 205 veya /tp 259 198 205)", player, 255, 255, 255, true)
        return
    end

    local numbers = {}
    for numStr in string.gmatch(rawArgs, "[-+]?%d+%.?%d*") do
        local n = tonumber(numStr)
        if n then
            table.insert(numbers, n)
        end
    end

    if #numbers >= 3 then
        local tx = numbers[1]
        local ty = numbers[2]
        local tz = numbers[3]
        local tint = numbers[4] or getElementInterior(player)
        local tdim = numbers[5] or getElementDimension(player)

        if isPedInVehicle(player) then
            local veh = getPedOccupiedVehicle(player)
            if isElement(veh) then
                setElementPosition(veh, tx, ty, tz + 0.5)
                setElementInterior(veh, tint)
                setElementDimension(veh, tdim)
            end
        else
            setElementPosition(player, tx, ty, tz)
        end

        setElementInterior(player, tint)
        setElementDimension(player, tdim)
        setCameraTarget(player, player)

        outputChatBox(string.format("#38bdf8[GZL-TP]#ffffff Konuma ışınlandınız: #34d399%.2f, %.2f, %.2f #ffffff(Int: %d, Dim: %d)", tx, ty, tz, tint, tdim), player, 255, 255, 255, true)
        return
    end

    local targetPlayer = findTargetPlayer(rawArgs)
    if not targetPlayer then
        outputChatBox("#ef4444[GZL-TP]#ffffff Belirtilen oyuncu bulunamadı: #e2e8f0" .. rawArgs, player, 255, 255, 255, true)
        return
    end

    if targetPlayer == player then
        outputChatBox("#ef4444[GZL-TP]#ffffff Kendinize ışınlanamazsınız!", player, 255, 255, 255, true)
        return
    end

    local tx, ty, tz = getElementPosition(targetPlayer)
    local tint = getElementInterior(targetPlayer)
    local tdim = getElementDimension(targetPlayer)

    if isPedInVehicle(player) then
        removePedFromVehicle(player)
    end

    setElementPosition(player, tx + 1.0, ty, tz)
    setElementInterior(player, tint)
    setElementDimension(player, tdim)
    setCameraTarget(player, player)

    local targetName = getPlayerName(targetPlayer)
    local targetCharId = getElementData(targetPlayer, "character:id") or getElementData(targetPlayer, "char:id") or "-"
    outputChatBox(string.format("#38bdf8[GZL-TP]#ffffff #34d399%s #ffffff(ID: #38bdf8%s#ffffff) adlı oyuncunun yanına ışınlandınız.", targetName, tostring(targetCharId)), player, 255, 255, 255, true)
end
addCommandHandler("tp", handleTeleport)
addCommandHandler("goto", handleTeleport)

addEventHandler("onResourceStart", resourceRoot, function()
    outputServerLog("[" .. Config.ServerName .. "] Çekirdek sistem (" .. Config.Developer .. ") başarıyla yüklendi.")
end)