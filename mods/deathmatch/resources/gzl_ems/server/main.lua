local function trustedAdminLevel(player)
    local auth = getResourceFromName("gzl_auth")
    if not isElement(player) or not auth or getResourceState(auth) ~= "running" then return 0 end
    return exports.gzl_auth:getAdminLevel(player)
end

local distressCooldowns = {}

local function isPlayerAuthorizedForRevive(player)
    if not isElement(player) then return false end

    if trustedAdminLevel(player) > 0 then return true end

    local job = getElementData(player, "char:job") or getElementData(player, "job") or ""
    if Config.EMSJobNames[job] then
        return true
    end

    if exports.gzl_factions and exports.gzl_factions.isPlayerOnDuty then
        local s, onDuty = pcall(function() return exports.gzl_factions:isPlayerOnDuty(player, "ems") end)
        if s and onDuty then return true end
    end

    return false
end

function getRemainingDeathTime(player)
    if not isElement(player) or not getElementData(player, "ems:isDead") then return 0 end
    local deathTick = getElementData(player, "ems:deathTick")
    if not deathTick then
        local storedRem = tonumber(getElementData(player, "character:death_time_remaining"))
        return storedRem or (Config.BleedoutTime or 180)
    end
    local elapsed = (getTickCount() - deathTick) / 1000
    local total = Config.BleedoutTime or 180
    return math.max(0, math.ceil(total - elapsed))
end

function restorePlayerComa(player, remainingSec)
    if not isElement(player) or getElementType(player) ~= "player" then return false end
    remainingSec = tonumber(remainingSec)
    if remainingSec == nil or remainingSec < 0 then
        remainingSec = Config.BleedoutTime or 180
    end

    local total = Config.BleedoutTime or 180
    local elapsedSec = math.max(0, total - remainingSec)

    setElementData(player, "ems:isDead", true, true)
    setElementData(player, "character:is_dead", 1)
    setElementData(player, "character:death_time_remaining", remainingSec)
    setElementData(player, "ems:deathTick", getTickCount() - (elapsedSec * 1000), true)

    setElementFrozen(player, true)
    setPedAnimation(player, Config.DeathAnim.block, Config.DeathAnim.anim, -1, true, false, false, true)
    setElementHealth(player, 100)

    triggerClientEvent(player, "gzl_ems:onClientEnterComa", player, remainingSec)
    return true
end

function revivePlayer(player)
    if not isElement(player) or getElementType(player) ~= "player" then return false end

    setElementData(player, "ems:isDead", false, true)
    setElementData(player, "character:is_dead", 0)
    setElementData(player, "character:death_time_remaining", 0)
    setElementData(player, "isCuffed", false, true)
    setElementData(player, "cuffed", false, true)
    setElementFrozen(player, false)
    setPedAnimation(player, false)
    setElementHealth(player, 100)

    local charId = getElementData(player, "character:id") or getElementData(player, "char:id")
    if charId and exports.gzl_characters and exports.gzl_characters.getCharacterDB then
        local db = exports.gzl_characters:getCharacterDB()
        if db then
            dbExec(db, "UPDATE characters SET is_dead = 0, death_time_remaining = 0 WHERE id = ?", charId)
        end
    end

    if exports.gzl_logs and exports.gzl_logs.logSystem then
        pcall(function() exports.gzl_logs:logSystem("EMS", "INFO", string.format("%s hayata döndürüldü (revive)", getPlayerName(player))) end)
    end

    triggerClientEvent(player, "gzl_ems:onClientRevived", player)
    outputChatBox("#34d399[GZL EMS]#ffffff Başarıyla hayata döndürüldünüz!", player, 255, 255, 255, true)
    return true
end

function isPlayerInComa(player)
    if not isElement(player) then return false end
    return getElementData(player, "ems:isDead") == true
end

addEventHandler("onPlayerWasted", root, function()
    local player = source
    if not isElement(player) then return end

    if not getElementData(player, "loggedin_character") then return end

    local px, py, pz = getElementPosition(player)
    local _, _, prot = getElementRotation(player)
    local skin = getElementModel(player)
    local pint = getElementInterior(player)
    local pdim = getElementDimension(player)

    local charId = getElementData(player, "character:id") or getElementData(player, "char:id")
    if charId and exports.gzl_characters and exports.gzl_characters.getCharacterDB then
        local db = exports.gzl_characters:getCharacterDB()
        if db then
            dbExec(db, "UPDATE characters SET is_dead = 1, death_time_remaining = ? WHERE id = ?", Config.BleedoutTime or 180, charId)
        end
    end

    setTimer(function()
        if not isElement(player) then return end

        spawnPlayer(player, px, py, pz, prot, skin, pint, pdim)
        setCameraTarget(player, player)
        setElementHealth(player, 100)
        setElementFrozen(player, true)
        setPedAnimation(player, Config.DeathAnim.block, Config.DeathAnim.anim, -1, true, false, false, true)

        setElementData(player, "ems:isDead", true, true)
        setElementData(player, "character:is_dead", 1)
        setElementData(player, "character:death_time_remaining", Config.BleedoutTime or 180)
        setElementData(player, "ems:deathTick", getTickCount(), true)

        triggerClientEvent(player, "gzl_ems:onClientEnterComa", player, Config.BleedoutTime)
    end, 50, 1)
end)

addEvent("gzl_ems:sendDistress", true)
addEventHandler("gzl_ems:sendDistress", root, function()
    local player = client or source
    if not isElement(player) then return end

    if not getElementData(player, "ems:isDead") then
        return
    end

    local now = getTickCount()
    local lastTime = distressCooldowns[player] or 0
    local cooldownMs = (Config.DistressCooldown or 45) * 1000

    if (now - lastTime) < cooldownMs then
        local remSec = math.ceil((cooldownMs - (now - lastTime)) / 1000)
        outputChatBox(string.format("#ef4444[EMS]#ffffff Tekrar acil sinyal gönderebilmek için #f59e0b%d#ffffff saniye bekleyin.", remSec), player, 255, 255, 255, true)
        return
    end

    distressCooldowns[player] = now

    local px, py, pz = getElementPosition(player)
    local pName = getPlayerName(player):gsub("#%x%x%x%x%x%x", "")

    local sentCount = 0
    for _, target in ipairs(getElementsByType("player")) do
        if isElement(target) and getElementData(target, "loggedin_character") then
            local job = getElementData(target, "char:job") or getElementData(target, "job") or ""
            local isEmergency = Config.EMSJobNames[job] or Config.PoliceJobNames[job]

            if isEmergency then
                outputChatBox(string.format("#ef4444[911 ACİL ÇAĞRI]#ffffff Yaralı Vatandaş: #38bdf8%s#ffffff! Konum GPS haritanıza işlendi.", pName), target, 255, 255, 255, true)
                triggerClientEvent(target, "gzl_ems:createDistressBlip", target, px, py, pz, pName)
                sentCount = sentCount + 1
            else

                triggerClientEvent(target, "gzl_ems:createDistressBlip", target, px, py, pz, pName)
            end
        end
    end

    outputChatBox("#34d399[EMS SİNYALİ]#ffffff Acil çağrınız telsiz merkezine ve devriye ekiplerine ulaştırıldı.", player, 255, 255, 255, true)
end)

addEvent("gzl_ems:requestHospitalRespawn", true)
addEventHandler("gzl_ems:requestHospitalRespawn", root, function()
    local player = client or source
    if not isElement(player) then return end

    if not getElementData(player, "ems:isDead") then return end

    local deathTick = getElementData(player, "ems:deathTick") or 0
    local elapsedSec = (getTickCount() - deathTick) / 1000

    if elapsedSec < (Config.BleedoutTime - 2) then
        outputChatBox("#ef4444[EMS]#ffffff Henüz bilincinizi tamamen kaybetmediniz, bekleyin.", player, 255, 255, 255, true)
        return
    end

    local spawn = Config.HospitalSpawn
    setElementPosition(player, spawn.x, spawn.y, spawn.z)
    setElementRotation(player, 0, 0, spawn.rot)
    setElementInterior(player, spawn.interior or 0)
    setElementDimension(player, spawn.dimension or 0)
    setCameraTarget(player, player)

    setElementFrozen(player, false)
    setPedAnimation(player, false)
    setElementHealth(player, 100)
    setElementData(player, "ems:isDead", false, true)
    setElementData(player, "character:is_dead", 0)
    setElementData(player, "character:death_time_remaining", 0)
    setElementData(player, "isCuffed", false, true)
    setElementData(player, "cuffed", false, true)

    local charId = getElementData(player, "character:id") or getElementData(player, "char:id")
    if charId and exports.gzl_characters and exports.gzl_characters.getCharacterDB then
        local db = exports.gzl_characters:getCharacterDB()
        if db then
            dbExec(db, "UPDATE characters SET is_dead = 0, death_time_remaining = 0 WHERE id = ?", charId)
        end
    end

    local bill = Config.HospitalBill or 150
    local curMoney = tonumber(getElementData(player, "character:money") or getElementData(player, "char:money") or getPlayerMoney(player)) or 0
    local taken = math.min(curMoney, bill)
    if taken > 0 then
        local newMoney = math.max(0, curMoney - taken)
        setPlayerMoney(player, newMoney)
        setElementData(player, "character:money", newMoney, "broadcast", "deny")
        setElementData(player, "char:money", newMoney, "broadcast", "deny")
        if exports.gzl_characters and exports.gzl_characters.saveCharacter then
            exports.gzl_characters:saveCharacter(player)
        end
        if exports.gzl_logs and exports.gzl_logs.logMoney then
            pcall(function() exports.gzl_logs:logMoney(player, "HOSPITAL", taken, "hospital_bill", "Hastane acil tedavi faturası") end)
        end
    end

    triggerClientEvent(player, "gzl_ems:onClientRevived", player)
    outputChatBox(string.format("#38bdf8[HASTANE]#ffffff %s acil servisinde hayata döndürüldünüz. Tedavi faturası: #ef4444$%d#ffffff.", spawn.name, taken), player, 255, 255, 255, true)
end)

local function handleReviveCommand(player, cmd, targetArg)
    if not isPlayerAuthorizedForRevive(player) then
        outputChatBox("#ef4444[YETKİ]#ffffff Bu komutu kullanmak için yetkili veya doktor olmalısınız.", player, 255, 255, 255, true)
        return
    end

    local targetPlayer = nil

    if targetArg and targetArg ~= "" then
        local num = tonumber(targetArg)
        for _, p in ipairs(getElementsByType("player")) do
            local charId = tonumber(getElementData(p, "character:id") or getElementData(p, "char:id") or getElementData(p, "id"))
            if charId and charId == num then
                targetPlayer = p
                break
            elseif string.find(string.lower(getPlayerName(p)), string.lower(targetArg), 1, true) then
                targetPlayer = p
                break
            end
        end
        if not targetPlayer then
            outputChatBox("#ef4444[HATA]#ffffff Belirtilen oyuncu bulunamadı.", player, 255, 255, 255, true)
            return
        end
    else

        if getElementData(player, "ems:isDead") then

            targetPlayer = player
        else

            local px, py, pz = getElementPosition(player)
            local closestPlayer = nil
            local closestDist = 5.0

            for _, p in ipairs(getElementsByType("player")) do
                if p ~= player and getElementData(p, "ems:isDead") then
                    local tx, ty, tz = getElementPosition(p)
                    local dist = getDistanceBetweenPoints3D(px, py, pz, tx, ty, tz)
                    if dist <= closestDist then
                        closestDist = dist
                        closestPlayer = p
                    end
                end
            end

            if closestPlayer then
                targetPlayer = closestPlayer
            else
                outputChatBox("#38bdf8[KULLANIM]#ffffff /" .. cmd .. " [id / isim] (veya yaralı oyuncunun yanına yaklaşın).", player, 255, 255, 255, true)
                return
            end
        end
    end

    if not getElementData(targetPlayer, "ems:isDead") then
        outputChatBox("#f59e0b[BİLGİ]#ffffff Bu oyuncu zaten yaralı/koma durumunda değil.", player, 255, 255, 255, true)
        return
    end

    revivePlayer(targetPlayer)
    if targetPlayer == player then
        outputChatBox("#34d399[EMS]#ffffff Kendinizi başarıyla ayağa kaldırdınız.", player, 255, 255, 255, true)
    else
        outputChatBox(string.format("#34d399[EMS]#ffffff #38bdf8%s#ffffff adlı yaralıyı başarıyla canlandırdınız.", getPlayerName(targetPlayer)), player, 255, 255, 255, true)
    end
end

addCommandHandler("revive", handleReviveCommand)
addCommandHandler("iyilestir", handleReviveCommand)
addCommandHandler("iyileştir", handleReviveCommand)
addCommandHandler("tedavi", handleReviveCommand)
addCommandHandler("ilkyardim", handleReviveCommand)

addEventHandler("onPlayerQuit", root, function()
    distressCooldowns[source] = nil
end)

addEventHandler("onResourceStart", resourceRoot, function()
    for _, p in ipairs(getElementsByType("player")) do
        if getElementData(p, "loggedin_character") then
            if getElementData(p, "ems:isDead") == true or getElementData(p, "character:is_dead") == 1 then
                local rem = getRemainingDeathTime(p)
                restorePlayerComa(p, rem)
            end
        end
    end
end)