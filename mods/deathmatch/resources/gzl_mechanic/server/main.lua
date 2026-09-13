local liftIsRaised = false

local function getPlayerMoneyAmount(player)
    if exports.gzl_characters and exports.gzl_characters.getPlayerCash then
        return exports.gzl_characters:getPlayerCash(player) or 0
    end
    return tonumber(getElementData(player, "character:money") or getPlayerMoney(player)) or 0
end

local serviceDebounce = {}

local function deductPlayerMoney(player, amount)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return false end
    if exports.gzl_characters and exports.gzl_characters.takePlayerCash then
        return exports.gzl_characters:takePlayerCash(player, amount) == true
    end
    local cur = getPlayerMoneyAmount(player)
    if cur < amount then return false end
    local newCash = cur - amount
    setElementData(player, "character:money", newCash, "broadcast", "deny")
    setElementData(player, "char:money", newCash, "broadcast", "deny")
    setPlayerMoney(player, newCash)
    if exports.gzl_characters and exports.gzl_characters.saveCharacter then
        exports.gzl_characters:saveCharacter(player)
    end
    return true
end

local function notifyPlayer(player, message, msgType)
    if exports.gzl_ui and exports.gzl_ui.showToast then
        exports.gzl_ui:showToast(player, message, msgType or "info")
    else
        outputChatBox("[Benny's] " .. message, player, 245, 166, 35)
    end
end

addEvent("mechanic:requestService", true)
addEventHandler("mechanic:requestService", root, function(veh, serviceType, data)
    local player = client or source
    if not isElement(player) or not isElement(veh) or getElementType(veh) ~= "vehicle" then return end
    if not getElementData(player, "loggedin_character") then return end

    local now = getTickCount()
    if serviceDebounce[player] and (now - serviceDebounce[player]) < 2000 then
        notifyPlayer(player, "Lütfen önceki işlemin tamamlanmasını bekleyin!", "warning")
        return
    end

    local px, py, pz = getElementPosition(player)
    if getDistanceBetweenPoints3D(px, py, pz, Config.WorkshopCenter.x, Config.WorkshopCenter.y, Config.WorkshopCenter.z) > 120.0 then
        notifyPlayer(player, "Bu islemi yalnizca Benny's Atolyesinde yapabilirsiniz!", "error")
        return
    end

    local vx, vy, vz = getElementPosition(veh)
    if getDistanceBetweenPoints3D(px, py, pz, vx, vy, vz) > 15.0 then
        notifyPlayer(player, "Araçtan çok uzaktasınız!", "error")
        return
    end

    local cost = nil
    if serviceType == "repairEngine" then cost = Config.Prices.repairEngine
    elseif serviceType == "repairBody" then cost = Config.Prices.repairBody
    elseif serviceType == "repairTires" then cost = Config.Prices.repairTires
    elseif serviceType == "serviceOil" then cost = Config.Prices.serviceOil
    elseif serviceType == "fullOverhaul" then cost = Config.Prices.fullOverhaul
    elseif serviceType == "paint" then
        if type(data) == "table" and data.paintType == "secondary" then
            cost = Config.Prices.paintSecondary or 350
        else
            cost = Config.Prices.paintPrimary or 500
        end
    elseif serviceType == "headlights" then cost = Config.Prices.headlights
    elseif serviceType == "upgrade" then cost = Config.Prices.upgrade or 850
    elseif serviceType == "removeUpgrade" then cost = Config.Prices.removeUpgrade or 0
    elseif serviceType == "wheels" then
        local wheelPrice = Config.Prices.wheels or 1200
        if type(data) == "table" and data.wheelId then
            for _, w in ipairs(Config.Wheels or {}) do
                if w.id == tonumber(data.wheelId) then
                    wheelPrice = w.price
                    break
                end
            end
        end
        cost = wheelPrice
    elseif serviceType == "hydraulics" then cost = Config.Prices.hydraulics
    elseif serviceType == "nitro" then cost = Config.Prices.nitro10x
    elseif serviceType == "neon" then cost = Config.Prices.neon
    elseif serviceType == "suspension" then cost = Config.Prices.suspension
    end

    if cost == nil or cost < 0 then
        notifyPlayer(player, "Geçersiz servis talebi!", "error")
        return
    end

    if cost > 0 then
        local currentCash = getPlayerMoneyAmount(player)
        if currentCash < cost then
            notifyPlayer(player, "Yetersiz bakiye! Bu islem icin $" .. cost .. " gerekiyor.", "error")
            return
        end

        local deducted = deductPlayerMoney(player, cost)
        if not deducted then
            notifyPlayer(player, "Ödeme tahsil edilemedi!", "error")
            return
        end
    end

    serviceDebounce[player] = now

    if serviceType == "repairEngine" then
        setElementHealth(veh, 1000)
        triggerClientEvent(root, "mechanic:clientPlayRepairSequence", player, veh, "repairEngine", 3500)
        notifyPlayer(player, "Motor ve mekanik aksam kusursuz sekilde onarildi! ($" .. cost .. ")", "success")

    elseif serviceType == "repairBody" then
        fixVehicle(veh)
        triggerClientEvent(root, "mechanic:clientPlayRepairSequence", player, veh, "repairBody", 3000)
        notifyPlayer(player, "Gövde ve kaporta hasarlari tamamen giderildi! ($" .. cost .. ")", "success")

    elseif serviceType == "repairTires" then
        setVehicleWheelStates(veh, 0, 0, 0, 0)
        triggerClientEvent(root, "mechanic:clientPlayRepairSequence", player, veh, "repairTires", 2500)
        notifyPlayer(player, "4 lastik yenilendi ve balans ayari yapildi! ($" .. cost .. ")", "success")

    elseif serviceType == "serviceOil" then
        local curH = getElementHealth(veh)
        setElementHealth(veh, math.min(1000, curH + 150))
        notifyPlayer(player, "Motor yagi, filtreler ve sivi bakimi tamamlandi! ($" .. cost .. ")", "success")

    elseif serviceType == "fullOverhaul" then
        fixVehicle(veh)
        setElementHealth(veh, 1000)
        setVehicleWheelStates(veh, 0, 0, 0, 0)
        triggerClientEvent(root, "mechanic:clientPlayRepairSequence", player, veh, "fullOverhaul", 4000)
        notifyPlayer(player, "Benny's Tam Paket Revizyon tamamlandi! Arac sifir kondisyona getirildi. ($" .. cost .. ")", "success")

    elseif serviceType == "paint" and data then
        setVehicleColor(veh, data.r1, data.g1, data.b1, data.r2, data.g2, data.b2)
        triggerClientEvent(root, "mechanic:clientPlayRepairSequence", player, veh, "paint", 3000)
        notifyPlayer(player, "Ozel firinli boya basariyla uygulandi! ($" .. cost .. ")", "success")

    elseif serviceType == "headlights" and data then
        if setVehicleHeadLightColor then
            setVehicleHeadLightColor(veh, data.r, data.g, data.b)
        end
        notifyPlayer(player, "Yuksek lümenli Xenon farlar monte edildi! ($" .. cost .. ")", "success")

    elseif serviceType == "upgrade" and data then
        addVehicleUpgrade(veh, data.upgradeId)
        notifyPlayer(player, tostring(data.name or "Parça") .. " araca başarıyla takıldı! ($" .. cost .. ")", "success")

    elseif serviceType == "removeUpgrade" and data then
        if data.upgradeId and tonumber(data.upgradeId) then
            removeVehicleUpgrade(veh, tonumber(data.upgradeId))
        end
        notifyPlayer(player, "Parça başarıyla söküldü.", "info")

    elseif serviceType == "wheels" and data then
        addVehicleUpgrade(veh, data.wheelId)
        notifyPlayer(player, "Secilen jant takimi basariyla takildi! ($" .. cost .. ")", "success")

    elseif serviceType == "hydraulics" then
        addVehicleUpgrade(veh, 1087)
        notifyPlayer(player, "Benny's Lowrider hidrolik pompasi monte edildi! Keyfini cikar. ($" .. cost .. ")", "success")

    elseif serviceType == "nitro" then
        addVehicleUpgrade(veh, 1010)
        notifyPlayer(player, "10x Nitro (NOS) tupu motora baglandi! ($" .. cost .. ")", "success")

    elseif serviceType == "neon" and data then
        setElementData(veh, "veh:neon", data)
        if data.enabled then
            notifyPlayer(player, "Arac alti neon aydinlatmasi aktif edildi! ($" .. cost .. ")", "success")
        else
            notifyPlayer(player, "Neon aydinlatmasi kapatildi.", "info")
        end

    elseif serviceType == "suspension" and data then

        local curHandling = getVehicleHandling(veh)
        if curHandling then
            local baseLower = curHandling["suspensionLowerLimit"] or -0.15
            setVehicleHandling(veh, "suspensionLowerLimit", baseLower + (data.offset or 0))
        end
        notifyPlayer(player, "Suspansiyon basiklik ayari yapildi! ($" .. cost .. ")", "success")
    end

    if exports.gzl_vehicles and exports.gzl_vehicles.saveVehicleToDB then
        exports.gzl_vehicles:saveVehicleToDB(veh)
    end
end)

addEvent("mechanic:toggleLift", true)
addEventHandler("mechanic:toggleLift", root, function(targetState)
    local player = client or source
    liftIsRaised = targetState
    triggerClientEvent(root, "mechanic:syncLiftState", resourceRoot, liftIsRaised)
    local stateText = liftIsRaised and "Lift yukariya kaldiriliyor..." or "Lift asagiya indiriliyor..."
    notifyPlayer(player, stateText, "info")
end)