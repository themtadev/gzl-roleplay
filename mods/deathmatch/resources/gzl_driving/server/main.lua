
local originalHandling = {}
local fivemActiveVehicles = {}

function applyFiveMPhysics(veh)
    if not isElement(veh) or getElementType(veh) ~= "vehicle" then
        return false
    end

    local vType = getVehicleType(veh)
    if vType ~= "Automobile" and vType ~= "Monster Truck" then
        return false
    end

    if not originalHandling[veh] then
        originalHandling[veh] = getVehicleHandling(veh)
    end

    local orig = originalHandling[veh]
    if not orig then return false end

    local newMass = math.max(1400.0, math.min(2200.0, orig.mass * 1.20))
    local newTurnMass = newMass * 2.2

    setVehicleHandling(veh, "mass", newMass)
    setVehicleHandling(veh, "turnMass", newTurnMass)
    setVehicleHandling(veh, "dragCoeff", 1.95)

    setVehicleHandling(veh, "centerOfMass", { orig.centerOfMass[1], orig.centerOfMass[2], -0.22 })

    setVehicleHandling(veh, "tractionMultiplier", 1.22)
    setVehicleHandling(veh, "tractionLoss", 0.90)
    setVehicleHandling(veh, "tractionBias", 0.49)

    setVehicleHandling(veh, "suspensionForce", 1.45)
    setVehicleHandling(veh, "suspensionDamping", 0.14)
    setVehicleHandling(veh, "suspensionHighSpdDamping", 0.0)
    setVehicleHandling(veh, "suspensionUpperLimit", 0.22)
    setVehicleHandling(veh, "suspensionLowerLimit", -0.14)
    setVehicleHandling(veh, "suspensionAntiRoll", 0.20)
    setVehicleHandling(veh, "suspensionBias", 0.50)

    setVehicleHandling(veh, "brakeDeceleration", 11.2)
    setVehicleHandling(veh, "brakeBias", 0.60)

    setVehicleHandling(veh, "steeringLock", 38.0)

    fivemActiveVehicles[veh] = true
    return true
end

function restoreVehiclePhysics(veh)
    if not isElement(veh) or not originalHandling[veh] then
        return false
    end

    local orig = originalHandling[veh]
    for prop, val in pairs(orig) do
        setVehicleHandling(veh, prop, val)
    end

    fivemActiveVehicles[veh] = nil
    return true
end

addCommandHandler("fivemphys", function(player, cmd)
    local veh = getPedOccupiedVehicle(player)
    if not veh then
        if exports.gzl_ui and exports.gzl_ui.showToast then
            exports.gzl_ui:showToast(player, "Bu komutu kullanmak için bir araçta olmalısın.", "error")
        else
            outputChatBox("#ff4757[FiveM]#ffffff Bu komutu kullanmak için bir araçta olmalısın.", player, 255, 255, 255, true)
        end
        return
    end

    if getVehicleController(veh) ~= player then
        if exports.gzl_ui and exports.gzl_ui.showToast then
            exports.gzl_ui:showToast(player, "Aracı sadece sürücü koltuğundayken modifiye edebilirsin.", "error")
        else
            outputChatBox("#ff4757[FiveM]#ffffff Aracı sadece sürücü koltuğundayken modifiye edebilirsin.", player, 255, 255, 255, true)
        end
        return
    end

    if fivemActiveVehicles[veh] then
        restoreVehiclePhysics(veh)
        if exports.gzl_ui and exports.gzl_ui.showToast then
            exports.gzl_ui:showToast(player, "Araç fiziği: Orijinal GTA moduna döndürüldü.", "info")
        else
            outputChatBox("#00f5a0[FiveM Fizik]#ffffff Araç fiziği: #eccc68GTA:SA Orijinal #ffffffmoduna döndürüldü.", player, 255, 255, 255, true)
        end
    else
        applyFiveMPhysics(veh)
        if exports.gzl_ui and exports.gzl_ui.showToast then
            exports.gzl_ui:showToast(player, "Araç fiziği: FiveM Gerçekçi Sürüş moduna geçirildi!", "success")
        else
            outputChatBox("#00f5a0[FiveM Fizik]#ffffff Araç fiziği: #2ed573FiveM Gerçekçi Sürüş #ffffffmoduna geçirildi!", player, 255, 255, 255, true)
        end
    end
end)

addCommandHandler("fivem", function(player, cmd)
    outputChatBox("#00f5a0======== [ FiveM Sürüş & Kamera Sistemi ] ========", player, 255, 255, 255, true)
    outputChatBox("#70a1ff/fivemcam #ffffff- Akıcı dinamik kamerayı aç / kapat", player, 255, 255, 255, true)
    outputChatBox("#70a1ff/fivemphys #ffffff- Mevcut araca FiveM kütle ve süspansiyon fiziği uygula / kaldır", player, 255, 255, 255, true)
    outputChatBox("#70a1ff/fivemair #ffffff- Havada araç yönlendirme ve takla kontrolünü aç / kapat", player, 255, 255, 255, true)
    outputChatBox("#70a1ff/fivemdrift #ffffff- Kontra & drift asistanını aç / kapat", player, 255, 255, 255, true)
    outputChatBox("#eccc68[V] Tuşu #ffffff- Kamera mesafesini değiştir (Yakın / Normal / Uzak)", player, 255, 255, 255, true)
    outputChatBox("#eccc68[C] Tuşu #ffffff- Dikiz / Arkaya bakış", player, 255, 255, 255, true)
    outputChatBox("#00f5a0================================================", player, 255, 255, 255, true)
end)

addEventHandler("onElementDestroy", root, function()
    if getElementType(source) == "vehicle" then
        originalHandling[source] = nil
        fivemActiveVehicles[source] = nil
    end
end)

addEventHandler("onResourceStop", resourceRoot, function()
    for veh, _ in pairs(fivemActiveVehicles) do
        if isElement(veh) then
            restoreVehiclePhysics(veh)
        end
    end
    originalHandling = {}
    fivemActiveVehicles = {}
end)