local playerSpawnedVehicles = {}

local function logAdminAction(player, command, target, details)
    if exports.gzl_logs and exports.gzl_logs.logAdmin then
        pcall(exports.gzl_logs.logAdmin, exports.gzl_logs, player, command, target, details)
    end
end

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

function handleSpawnVehicle(player, cmd, modelInput, col1, col2)
    if not isElement(player) then return end
    if not isAdmin(player) then
        outputChatBox("#ef4444[GZL-ADMIN]#ffffff Bu komutu kullanmak için yönetici yetkiniz bulunmamaktadır!", player, 255, 255, 255, true)
        return
    end

    if not modelInput or modelInput == "" then
        outputChatBox("#38bdf8[GZL-ADMIN]#ffffff Kullanım: #e2e8f0/veh <model_id / isim> [renk1] [renk2]", player, 255, 255, 255, true)
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

    if isElement(playerSpawnedVehicles[player]) then
        destroyElement(playerSpawnedVehicles[player])
        playerSpawnedVehicles[player] = nil
    end

    local x, y, z = getElementPosition(player)
    local _, _, rz = getElementRotation(player)
    local int = getElementInterior(player)
    local dim = getElementDimension(player)

    local veh = createVehicle(modelId, x, y, z + 0.2, 0, 0, rz)
    if not isElement(veh) then
        outputChatBox("#ef4444[GZL-ADMIN]#ffffff Araç oluşturulamadı!", player, 255, 255, 255, true)
        return
    end

    setElementInterior(veh, int)
    setElementDimension(veh, dim)
    warpPedIntoVehicle(player, veh, 0)

    if col1 and tonumber(col1) then
        setVehicleColor(veh, tonumber(col1), tonumber(col2 or col1), 0, 0)
    end

    playerSpawnedVehicles[player] = veh
    local vehName = getVehicleNameFromModel(modelId) or "Araç"
    outputChatBox(string.format("#38bdf8[GZL-ADMIN]#ffffff Araç çıkarıldı: #34d399%s #ffffff(ID: #38bdf8%d#ffffff)", vehName, modelId), player, 255, 255, 255, true)
    logAdminAction(player, "veh", nil, string.format("Çıkarılan Araç: %s (Model: %d)", vehName, modelId))
end
addCommandHandler("veh", handleSpawnVehicle)
addCommandHandler("car", handleSpawnVehicle)

function handleDeleteVehicle(player, cmd)
    if not isElement(player) then return end
    if not isAdmin(player) then
        outputChatBox("#ef4444[GZL-ADMIN]#ffffff Bu komutu kullanmak için yönetici yetkiniz bulunmamaktadır!", player, 255, 255, 255, true)
        return
    end

    local veh = getPedOccupiedVehicle(player)

    if not isElement(veh) then
        local px, py, pz = getElementPosition(player)
        local closestDist = 6.0
        for _, v in ipairs(getElementsByType("vehicle")) do
            local vx, vy, vz = getElementPosition(v)
            local dist = getDistanceBetweenPoints3D(px, py, pz, vx, vy, vz)
            if dist < closestDist then
                closestDist = dist
                veh = v
            end
        end
    end

    if isElement(veh) then
        for p, spawnedV in pairs(playerSpawnedVehicles) do
            if spawnedV == veh then
                playerSpawnedVehicles[p] = nil
                break
            end
        end
        local mId = getElementModel(veh)
        destroyElement(veh)
        outputChatBox("#38bdf8[GZL-ADMIN]#ffffff Araç başarıyla silindi.", player, 255, 255, 255, true)
        logAdminAction(player, "dv", nil, string.format("Araç silindi (Model: %s)", tostring(mId)))
    else
        outputChatBox("#ef4444[GZL-ADMIN]#ffffff Yakınınızda veya bindiğiniz bir araç bulunamadı!", player, 255, 255, 255, true)
    end
end
addCommandHandler("dv", handleDeleteVehicle)
addCommandHandler("delveh", handleDeleteVehicle)

function handleFixVehicle(player, cmd)
    if not isElement(player) then return end
    if not isAdmin(player) then
        outputChatBox("#ef4444[GZL-ADMIN]#ffffff Bu komutu kullanmak için yönetici yetkiniz bulunmamaktadır!", player, 255, 255, 255, true)
        return
    end

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

    if isElement(veh) then
        fixVehicle(veh)
        setElementHealth(veh, 1000)
        outputChatBox("#38bdf8[GZL-ADMIN]#ffffff Araç tamir edildi ve hasarı sıfırlandı.", player, 255, 255, 255, true)
        logAdminAction(player, "fix", nil, "Araç tamir edildi (HP: 1000)")
    else
        outputChatBox("#ef4444[GZL-ADMIN]#ffffff Tamir edilecek bir araç bulunamadı!", player, 255, 255, 255, true)
    end
end
addCommandHandler("fix", handleFixVehicle)
addCommandHandler("repair", handleFixVehicle)
addCommandHandler("tamir", handleFixVehicle)

function handleHeal(player, cmd, targetQuery)
    if not isElement(player) then return end
    if not isAdmin(player) then
        outputChatBox("#ef4444[GZL-ADMIN]#ffffff Bu komutu kullanmak için yönetici yetkiniz bulunmamaktadır!", player, 255, 255, 255, true)
        return
    end

    local target = targetQuery and findTargetPlayer(targetQuery) or player

    if not isElement(target) then
        outputChatBox("#ef4444[GZL-ADMIN]#ffffff Oyuncu bulunamadı!", player, 255, 255, 255, true)
        return
    end

    if isPedDead(target) then
        local x, y, z = getElementPosition(target)
        local skin = getElementModel(target)
        local int = getElementInterior(target)
        local dim = getElementDimension(target)
        spawnPlayer(target, x, y, z, 0, skin, int, dim)
        setCameraTarget(target, target)
    end

    if getResourceFromName("gzl_ems") and getResourceState(getResourceFromName("gzl_ems")) == "running" then
        if exports.gzl_ems and exports.gzl_ems.isPlayerInComa and exports.gzl_ems:isPlayerInComa(target) then
            exports.gzl_ems:revivePlayer(target)
        end
    end

    setElementHealth(target, 100)
    setPedArmor(target, 100)
    setElementData(target, "character:hunger", 100)
    setElementData(target, "character:thirst", 100)

    outputChatBox("#38bdf8[GZL-ADMIN]#ffffff #34d399" .. getPlayerName(target) .. "#ffffff oyuncusunun canı ve zırhı dolduruldu.", player, 255, 255, 255, true)
    logAdminAction(player, "heal", target, "Can ve zırh dolduruldu (100 HP, 100 Armor)")
end
addCommandHandler("heal", handleHeal)
addCommandHandler("can", handleHeal)

function handleSetSkin(player, cmd, skinInput, targetQuery)
    if not isElement(player) then return end
    if not isAdmin(player) then
        outputChatBox("#ef4444[GZL-ADMIN]#ffffff Bu komutu kullanmak için yönetici yetkiniz bulunmamaktadır!", player, 255, 255, 255, true)
        return
    end

    local skinId = tonumber(skinInput)
    if not skinId or skinId < 0 or skinId > 312 then
        outputChatBox("#38bdf8[GZL-ADMIN]#ffffff Kullanım: #e2e8f0/skin <skin_id> [oyuncu_id]", player, 255, 255, 255, true)
        return
    end

    local target = targetQuery and findTargetPlayer(targetQuery) or player
    if isElement(target) then
        setElementModel(target, skinId)
        setElementData(target, "character:skin", skinId)
        outputChatBox(string.format("#38bdf8[GZL-ADMIN]#ffffff #34d399%s #ffffffadlı oyuncunun skini #38bdf8%d #ffffffolarak ayarlandı.", getPlayerName(target), skinId), player, 255, 255, 255, true)
        logAdminAction(player, "skin", target, string.format("Skin değiştirildi: %d", skinId))
    end
end
addCommandHandler("skin", handleSetSkin)
addCommandHandler("setskin", handleSetSkin)

function handleGiveMoney(player, cmd, amountInput, targetQuery)
    if not isElement(player) then return end
    if not isAdmin(player) then
        outputChatBox("#ef4444[GZL-ADMIN]#ffffff Bu komutu kullanmak için yönetici yetkiniz bulunmamaktadır!", player, 255, 255, 255, true)
        return
    end

    local amount = tonumber(amountInput)
    if not amount then
        outputChatBox("#38bdf8[GZL-ADMIN]#ffffff Kullanım: #e2e8f0/givemoney <miktar> [oyuncu_id]", player, 255, 255, 255, true)
        return
    end

    local target = targetQuery and findTargetPlayer(targetQuery) or player
    if isElement(target) then
        local currentMoney = getElementData(target, "character:money") or getPlayerMoney(target) or 0
        local newMoney = currentMoney + amount
        setElementData(target, "character:money", newMoney, "broadcast", "deny")
        setElementData(target, "char:money", newMoney, "broadcast", "deny")
        setPlayerMoney(target, newMoney)
        if exports.gzl_characters and exports.gzl_characters.saveCharacter then
            exports.gzl_characters:saveCharacter(target)
        end

        outputChatBox(string.format("#38bdf8[GZL-ADMIN]#ffffff #34d399%s #ffffffoyuncusuna #34d399$%s #ffffffpara verildi. Yeni Bakiye: #38bdf8$%s", getPlayerName(target), tostring(amount), tostring(newMoney)), player, 255, 255, 255, true)
        logAdminAction(player, "givemoney", target, string.format("Verilen Para: $%d (Yeni: $%d)", amount, newMoney))
    end
end
addCommandHandler("givemoney", handleGiveMoney)
addCommandHandler("parave", handleGiveMoney)

function handleSetMoney(player, cmd, amountInput, targetQuery)
    if not isElement(player) then return end
    if not isAdmin(player) then
        outputChatBox("#ef4444[GZL-ADMIN]#ffffff Bu komutu kullanmak için yönetici yetkiniz bulunmamaktadır!", player, 255, 255, 255, true)
        return
    end

    local amount = tonumber(amountInput)
    if not amount then
        outputChatBox("#38bdf8[GZL-ADMIN]#ffffff Kullanım: #e2e8f0/setmoney <miktar> [oyuncu_id]", player, 255, 255, 255, true)
        return
    end

    local target = targetQuery and findTargetPlayer(targetQuery) or player
    if isElement(target) then
        local newMoney = math.max(0, math.floor(amount))
        setElementData(target, "character:money", newMoney, "broadcast", "deny")
        setElementData(target, "char:money", newMoney, "broadcast", "deny")
        setPlayerMoney(target, newMoney)
        if exports.gzl_characters and exports.gzl_characters.saveCharacter then
            exports.gzl_characters:saveCharacter(target)
        end

        outputChatBox(string.format("#38bdf8[GZL-ADMIN]#ffffff #34d399%s #ffffffoyuncusunun parası #38bdf8$%s #ffffffolarak ayarlandı.", getPlayerName(target), tostring(newMoney)), player, 255, 255, 255, true)
        logAdminAction(player, "setmoney", target, string.format("Ayarlanan Para: $%d", newMoney))
    end
end
addCommandHandler("setmoney", handleSetMoney)
addCommandHandler("paraayar", handleSetMoney)

function handleGiveBank(player, cmd, amountInput, targetQuery)
    if not isElement(player) then return end
    if not isAdmin(player) then
        outputChatBox("#ef4444[GZL-ADMIN]#ffffff Bu komutu kullanmak için yönetici yetkiniz bulunmamaktadır!", player, 255, 255, 255, true)
        return
    end

    local amount = tonumber(amountInput)
    if not amount then
        outputChatBox("#38bdf8[GZL-ADMIN]#ffffff Kullanım: #e2e8f0/givebank <miktar> [oyuncu_id]", player, 255, 255, 255, true)
        return
    end

    local target = targetQuery and findTargetPlayer(targetQuery) or player
    if isElement(target) then
        local curBank = tonumber(getElementData(target, "character:bank") or getElementData(target, "char:bank_money") or getElementData(target, "char:bank")) or 0
        local newBank = math.max(0, math.floor(curBank + amount))
        setElementData(target, "character:bank", newBank, "broadcast", "deny")
        setElementData(target, "char:bank_money", newBank)
        setElementData(target, "char:bank", newBank, "broadcast", "deny")
        if exports.gzl_characters and exports.gzl_characters.saveCharacter then
            exports.gzl_characters:saveCharacter(target)
        end

        outputChatBox(string.format("#38bdf8[GZL-ADMIN]#ffffff #34d399%s #ffffffoyuncusuna #34d399$%s #ffffffbanka parası verildi. Yeni Bakiye: #38bdf8$%s", getPlayerName(target), tostring(amount), tostring(newBank)), player, 255, 255, 255, true)
        logAdminAction(player, "givebank", target, string.format("Verilen Banka Parası: $%d (Yeni: $%d)", amount, newBank))
    end
end
addCommandHandler("givebank", handleGiveBank)

function handleSetBank(player, cmd, amountInput, targetQuery)
    if not isElement(player) then return end
    if not isAdmin(player) then
        outputChatBox("#ef4444[GZL-ADMIN]#ffffff Bu komutu kullanmak için yönetici yetkiniz bulunmamaktadır!", player, 255, 255, 255, true)
        return
    end

    local amount = tonumber(amountInput)
    if not amount then
        outputChatBox("#38bdf8[GZL-ADMIN]#ffffff Kullanım: #e2e8f0/setbank <miktar> [oyuncu_id]", player, 255, 255, 255, true)
        return
    end

    local target = targetQuery and findTargetPlayer(targetQuery) or player
    if isElement(target) then
        local newBank = math.max(0, math.floor(amount))
        setElementData(target, "character:bank", newBank, "broadcast", "deny")
        setElementData(target, "char:bank_money", newBank)
        setElementData(target, "char:bank", newBank, "broadcast", "deny")
        if exports.gzl_characters and exports.gzl_characters.saveCharacter then
            exports.gzl_characters:saveCharacter(target)
        end

        outputChatBox(string.format("#38bdf8[GZL-ADMIN]#ffffff #34d399%s #ffffffoyuncusunun banka parası #38bdf8$%s #ffffffolarak ayarlandı.", getPlayerName(target), tostring(newBank)), player, 255, 255, 255, true)
        logAdminAction(player, "setbank", target, string.format("Ayarlanan Banka Parası: $%d", newBank))
    end
end
addCommandHandler("setbank", handleSetBank)

function handleSetTime(player, cmd, hourInput, minInput)
    if not isElement(player) then return end
    if not isAdmin(player) then
        outputChatBox("#ef4444[GZL-ADMIN]#ffffff Bu komutu kullanmak için yönetici yetkiniz bulunmamaktadır!", player, 255, 255, 255, true)
        return
    end

    local hour = tonumber(hourInput) or 12
    local min = tonumber(minInput) or 0
    setTime(hour, min)
    outputChatBox(string.format("#38bdf8[GZL-ADMIN]#ffffff Saat ayarlandı: #38bdf8%02d:%02d", hour, min), player, 255, 255, 255, true)
end
addCommandHandler("settime", handleSetTime)
addCommandHandler("saat", handleSetTime)

function handleSetWeather(player, cmd, weatherInput)
    if not isElement(player) then return end
    if not isAdmin(player) then
        outputChatBox("#ef4444[GZL-ADMIN]#ffffff Bu komutu kullanmak için yönetici yetkiniz bulunmamaktadır!", player, 255, 255, 255, true)
        return
    end

    local weatherId = tonumber(weatherInput) or 0
    setWeather(weatherId)
    outputChatBox(string.format("#38bdf8[GZL-ADMIN]#ffffff Hava durumu ayarlandı: #38bdf8ID %d", weatherId), player, 255, 255, 255, true)
end
addCommandHandler("setweather", handleSetWeather)
addCommandHandler("hava", handleSetWeather)

function handleSetDimension(player, cmd, dimInput, targetInput)
    if not isElement(player) then return end
    if not isAdmin(player) then
        outputChatBox("#ef4444[GZL-ADMIN]#ffffff Bu komutu kullanmak için yönetici yetkiniz bulunmamaktadır!", player, 255, 255, 255, true)
        return
    end

    local dim = tonumber(dimInput)
    if not dim or dim < 0 or dim > 65535 then
        outputChatBox("#ef4444[GZL-ADMIN]#ffffff Kullanım: /" .. cmd .. " <dimension (0-65535)> [oyuncu_id]", player, 255, 255, 255, true)
        return
    end

    local target = player
    if targetInput then
        target = findTargetPlayer(targetInput)
        if not target then
            outputChatBox("#ef4444[GZL-ADMIN]#ffffff Oyuncu bulunamadı: " .. tostring(targetInput), player, 255, 255, 255, true)
            return
        end
    end

    setElementDimension(target, dim)
    if isPedInVehicle(target) then
        setElementDimension(getPedOccupiedVehicle(target), dim)
    end
    outputChatBox(string.format("#38bdf8[GZL-ADMIN]#ffffff #34d399%s #ffffffdimension'ı #38bdf8%d #ffffffolarak ayarlandı.", getPlayerName(target), dim), player, 255, 255, 255, true)
end
addCommandHandler("setdim", handleSetDimension)
addCommandHandler("dim", handleSetDimension)

function handleSetInterior(player, cmd, intInput, targetInput)
    if not isElement(player) then return end
    if not isAdmin(player) then
        outputChatBox("#ef4444[GZL-ADMIN]#ffffff Bu komutu kullanmak için yönetici yetkiniz bulunmamaktadır!", player, 255, 255, 255, true)
        return
    end

    local interiorId = tonumber(intInput)
    if not interiorId or interiorId < 0 or interiorId > 255 then
        outputChatBox("#ef4444[GZL-ADMIN]#ffffff Kullanım: /" .. cmd .. " <interior (0-255)> [oyuncu_id]", player, 255, 255, 255, true)
        return
    end

    local target = player
    if targetInput then
        target = findTargetPlayer(targetInput)
        if not target then
            outputChatBox("#ef4444[GZL-ADMIN]#ffffff Oyuncu bulunamadı: " .. tostring(targetInput), player, 255, 255, 255, true)
            return
        end
    end

    setElementInterior(target, interiorId)
    if isPedInVehicle(target) then
        setElementInterior(getPedOccupiedVehicle(target), interiorId)
    end
    outputChatBox(string.format("#38bdf8[GZL-ADMIN]#ffffff #34d399%s #ffffffinterior'ı #38bdf8%d #ffffffolarak ayarlandı.", getPlayerName(target), interiorId), player, 255, 255, 255, true)
end
addCommandHandler("setint", handleSetInterior)
addCommandHandler("int", handleSetInterior)

function handleRestartResource(player, cmd, resName)
    if not isElement(player) or not isAdmin(player) then return end
    resName = resName or "gzl_mods"
    if exports.gzl_auth:getAdminLevel(player) < 5 or resName ~= "gzl_mods" then return end
    local res = getResourceFromName(resName)
    if not res then
        outputChatBox("#ef4444[GZL-ADMIN]#ffffff Kaynak bulunamadi: " .. tostring(resName), player, 255, 255, 255, true)
        return
    end
    if not restartResource(res) then return end
    outputChatBox(string.format("#38bdf8[GZL-ADMIN]#ffffff Kaynak yeniden baslatildi: #34d399%s", resName), player, 255, 255, 255, true)
    logAdminAction(player, "restartres", nil, "Yeniden başlatılan kaynak: " .. tostring(resName))
end
addCommandHandler("restartres", handleRestartResource)
addCommandHandler("resrestart", handleRestartResource)
addCommandHandler("restartmods", function(player) handleRestartResource(player, "restartmods", "gzl_mods") end)

addEventHandler("onPlayerQuit", root, function()
    local ply = source
    if isElement(playerSpawnedVehicles[ply]) then
        destroyElement(playerSpawnedVehicles[ply])
        playerSpawnedVehicles[ply] = nil
    end
end)

setTimer(function()
    local modRes = getResourceFromName("gzl_mods")
    if modRes and getResourceState(modRes) == "running" then
        restartResource(modRes)
    end
end, 1000, 1)