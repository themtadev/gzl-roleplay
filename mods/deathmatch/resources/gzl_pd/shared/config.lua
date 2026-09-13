
PDConfig = {}

PDConfig.DevMode = false
PDConfig.AllowedFactions = { [1] = true, ["lspd"] = true, ["police"] = true }

PDConfig.Tokens = {
    tabletWidth = 1020,
    tabletHeight = 640,
    sidebarWidth = 220,
    headerHeight = 56,
    cardRadius = 8,
    baseSpacing = 10
}

PDConfig.TenCodes = {
    { code = "10-8", label = "Göreve Başla (Devriyede)", status = "available", color = {52, 199, 89} },
    { code = "10-7", label = "Görev Dışı (Mola / Karargah)", status = "offline", color = {142, 142, 147} },
    { code = "10-6", label = "Meşgul / İntikal Halinde", status = "busy", color = {255, 159, 10} },
    { code = "10-99", label = "ACİL DURUM / MEMUR YARDIM İSTİYOR!", status = "emergency", color = {255, 69, 58} }
}

PDConfig.PenalCode = {
    { id = 1, category = "TRAFİK", title = "Aşırı Hız ve Tehlikeli Sürüş", fine = 1500, jail = 0 },
    { id = 2, category = "TRAFİK", title = "Kırmızı Işık & Ters Yön İhlali", fine = 800, jail = 0 },
    { id = 3, category = "TRAFİK", title = "Dur İhtarına Uymamak (Kaçış)", fine = 5000, jail = 15 },
    { id = 4, category = "ASAYİŞ", title = "Polise Mukavemet / Hakaret", fine = 7500, jail = 20 },
    { id = 5, category = "ASAYİŞ", title = "Ruhsatsız Silah Bulundurma", fine = 12000, jail = 30 },
    { id = 6, category = "AĞIR SUÇ", title = "Gasp / Silahlı Soygun", fine = 25000, jail = 45 },
    { id = 7, category = "AĞIR SUÇ", title = "Kamu Görevlisine / Memura Saldırı", fine = 35000, jail = 60 },
    { id = 8, category = "AĞIR SUÇ", title = "Kasten Adam Öldürme", fine = 50000, jail = 90 }
}

function PDConfig.canAccess(player)
    if not isElement(player) or getElementType(player) ~= "player" then return false end
    if PDConfig.DevMode then return true end

    if not getElementData(player, "loggedin_character") then return false end

    if exports and exports.gzl_factions and exports.gzl_factions.isPlayerOnDuty then
        local success, onDuty = pcall(function() return exports.gzl_factions:isPlayerOnDuty(player, "police") end)
        if success and onDuty then return true end
    end

    local faction = tonumber(getElementData(player, "character:faction") or getElementData(player, "faction"))
    local dutyPolice = getElementData(player, "duty:police")
    local dutyGeneral = getElementData(player, "duty")
    local isOnDuty = (dutyPolice == true or dutyPolice == 1 or dutyGeneral == "police" or dutyGeneral == 1 or dutyGeneral == true)

    if faction and PDConfig.AllowedFactions[faction] and isOnDuty then
        return true
    end

    return false
end

function isContraband(itemName)
    if not itemName then return false, nil end
    itemName = string.lower(tostring(itemName))
    if string.find(itemName, "weapon_") or string.find(itemName, "ammo_") or string.find(itemName, "ammo%-") or string.find(itemName, "ammo") then
        return true, "SİLAH / MÜHİMMAT"
    end
    if itemName == "black_money" then
        return true, "KARA PARA"
    end
    if string.find(itemName, "lockpick") then
        return true, "MAYMUNCUK / HIRSIZLIK ALETİ"
    end
    if string.find(itemName, "c4") or string.find(itemName, "drill") or string.find(itemName, "blowtorch") then
        return true, "SOYGUN EKİPMANI"
    end
    local drugKeywords = {"weed", "meth", "coke", "cocaine", "joint", "baggy", "drug", "heroin", "marijuana", "esrar", "kenevir"}
    for _, dk in ipairs(drugKeywords) do
        if string.find(itemName, dk) then
            return true, "UYUŞTURUCU / MADDE"
        end
    end
    return false, nil
end