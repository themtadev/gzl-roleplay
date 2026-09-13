g_CustomCommands = {}

local function registerRPCommand(name, handler)
    g_CustomCommands[name:lower()] = handler
    addCommandHandler(name, handler, false, false)
end

local function handleMe(player, cmd, ...)
    local message = table.concat({...}, " ")
    if not message or message == "" then
        triggerClientEvent(player, "chat:addMessage", player, {
            type = "HATA",
            typeColor = "#ef4444",
            header = "KULLANIM",
            content = "/me [eylem]"
        })
        return
    end

    local name = getCharacterName(player)
    local sx, sy, sz = getElementPosition(player)
    local sDim = getElementDimension(player)
    local sInt = getElementInterior(player)

    for _, target in ipairs(getElementsByType("player")) do
        if getElementDimension(target) == sDim and getElementInterior(target) == sInt then
            local tx, ty, tz = getElementPosition(target)
            if getDistanceBetweenPoints3D(sx, sy, sz, tx, ty, tz) <= 20.0 then
                triggerClientEvent(target, "chat:addMessage", target, {
                    type = "ME",
                    typeColor = "#8e44ad",
                    header = name,
                    content = message
                })
                triggerClientEvent(target, "chat:onPlayer3DText", player, player, message, "me")
            end
        end
    end
end
registerRPCommand("me", handleMe)

local function handleDo(player, cmd, ...)
    local message = table.concat({...}, " ")
    if not message or message == "" then
        triggerClientEvent(player, "chat:addMessage", player, {
            type = "HATA",
            typeColor = "#ef4444",
            header = "KULLANIM",
            content = "/do [durum]"
        })
        return
    end

    local name = getCharacterName(player)
    local sx, sy, sz = getElementPosition(player)
    local sDim = getElementDimension(player)
    local sInt = getElementInterior(player)

    for _, target in ipairs(getElementsByType("player")) do
        if getElementDimension(target) == sDim and getElementInterior(target) == sInt then
            local tx, ty, tz = getElementPosition(target)
            if getDistanceBetweenPoints3D(sx, sy, sz, tx, ty, tz) <= 20.0 then
                triggerClientEvent(target, "chat:addMessage", target, {
                    type = "DO",
                    typeColor = "#16a085",
                    header = name,
                    content = message
                })
                triggerClientEvent(target, "chat:onPlayer3DText", player, player, message, "do")
            end
        end
    end
end
registerRPCommand("do", handleDo)

local function handleDice(player, cmd)
    local name = getCharacterName(player)
    local sx, sy, sz = getElementPosition(player)
    local sDim = getElementDimension(player)
    local sInt = getElementInterior(player)

    setPedAnimation(player, "CASINO", "dealone", 1300, false, false, false, false)

    local diceResult = math.random(1, 6)
    local diceText = "[ZAR: " .. tostring(diceResult) .. "]"

    for _, target in ipairs(getElementsByType("player")) do
        if getElementDimension(target) == sDim and getElementInterior(target) == sInt then
            local tx, ty, tz = getElementPosition(target)
            if getDistanceBetweenPoints3D(sx, sy, sz, tx, ty, tz) <= 20.0 then
                triggerClientEvent(target, "chat:addMessage", target, {
                    type = "ZAR",
                    typeColor = "#ca8a04",
                    header = name,
                    content = "Zar attı ve [" .. tostring(diceResult) .. "] geldi."
                })
                triggerClientEvent(target, "chat:onPlayer3DText", player, player, diceText, "dice")
            end
        end
    end
end
registerRPCommand("zarat", handleDice)
registerRPCommand("zar", handleDice)

local function handleB(player, cmd, ...)
    local message = table.concat({...}, " ")
    if not message or message == "" then
        triggerClientEvent(player, "chat:addMessage", player, {
            type = "HATA",
            typeColor = "#ef4444",
            header = "KULLANIM",
            content = "/b [mesaj]"
        })
        return
    end

    local name = getCharacterName(player)
    local sx, sy, sz = getElementPosition(player)
    local sDim = getElementDimension(player)
    local sInt = getElementInterior(player)

    for _, target in ipairs(getElementsByType("player")) do
        if getElementDimension(target) == sDim and getElementInterior(target) == sInt then
            local tx, ty, tz = getElementPosition(target)
            if getDistanceBetweenPoints3D(sx, sy, sz, tx, ty, tz) <= 20.0 then
                triggerClientEvent(target, "chat:addMessage", target, {
                    type = "OOC",
                    typeColor = "#64748b",
                    header = name,
                    content = message
                })
            end
        end
    end
end
registerRPCommand("b", handleB)

local function handleOoc(player, cmd, ...)
    local message = table.concat({...}, " ")
    if not message or message == "" then
        triggerClientEvent(player, "chat:addMessage", player, {
            type = "HATA",
            typeColor = "#ef4444",
            header = "KULLANIM",
            content = "/ooc [mesaj]"
        })
        return
    end

    local name = getCharacterName(player)
    triggerClientEvent(root, "chat:addMessage", root, {
        type = "GLOBAL",
        typeColor = "#ea580c",
        header = name,
        content = message
    })
end
registerRPCommand("ooc", handleOoc)

local function handleShout(player, cmd, ...)
    local message = table.concat({...}, " ")
    if not message or message == "" then
        triggerClientEvent(player, "chat:addMessage", player, {
            type = "HATA",
            typeColor = "#ef4444",
            header = "KULLANIM",
            content = "/s [mesaj]"
        })
        return
    end

    local name = getCharacterName(player)
    local sx, sy, sz = getElementPosition(player)
    local sDim = getElementDimension(player)
    local sInt = getElementInterior(player)

    for _, target in ipairs(getElementsByType("player")) do
        if getElementDimension(target) == sDim and getElementInterior(target) == sInt then
            local tx, ty, tz = getElementPosition(target)
            if getDistanceBetweenPoints3D(sx, sy, sz, tx, ty, tz) <= 40.0 then
                triggerClientEvent(target, "chat:addMessage", target, {
                    type = "BAĞIRMA",
                    typeColor = "#dc2626",
                    header = name,
                    content = message .. "!"
                })
            end
        end
    end
end
registerRPCommand("s", handleShout)

local function handleWhisper(player, cmd, targetStr, ...)
    local message = table.concat({...}, " ")
    if not targetStr or not message or message == "" then
        triggerClientEvent(player, "chat:addMessage", player, {
            type = "HATA",
            typeColor = "#ef4444",
            header = "KULLANIM",
            content = "/w [oyuncu_id/isim] [mesaj]"
        })
        return
    end

    local targetPlayer = findPlayer(targetStr)
    if not targetPlayer then
        triggerClientEvent(player, "chat:addMessage", player, {
            type = "HATA",
            typeColor = "#ef4444",
            header = "SİSTEM",
            content = "Oyuncu bulunamadı!"
        })
        return
    end

    local sx, sy, sz = getElementPosition(player)
    local tx, ty, tz = getElementPosition(targetPlayer)
    if getDistanceBetweenPoints3D(sx, sy, sz, tx, ty, tz) > 4.0 or getElementDimension(player) ~= getElementDimension(targetPlayer) or getElementInterior(player) ~= getElementInterior(targetPlayer) then
        triggerClientEvent(player, "chat:addMessage", player, {
            type = "HATA",
            typeColor = "#ef4444",
            header = "SİSTEM",
            content = "Oyuncuya yeterince yakın değilsiniz!"
        })
        return
    end

    local senderName = getCharacterName(player)
    local targetName = getCharacterName(targetPlayer)

    triggerClientEvent(player, "chat:addMessage", player, {
        type = "FISILTI",
        typeColor = "#0d9488",
        header = targetName .. " kişisine fısıldadınız",
        content = message
    })
    triggerClientEvent(targetPlayer, "chat:addMessage", targetPlayer, {
        type = "FISILTI",
        typeColor = "#0d9488",
        header = senderName .. " size fısıldar",
        content = message
    })
end
registerRPCommand("w", handleWhisper)

local function handlePm(player, cmd, targetStr, ...)
    local message = table.concat({...}, " ")
    if not targetStr or not message or message == "" then
        triggerClientEvent(player, "chat:addMessage", player, {
            type = "HATA",
            typeColor = "#ef4444",
            header = "KULLANIM",
            content = "/pm [oyuncu_id/isim] [mesaj]"
        })
        return
    end

    local targetPlayer = findPlayer(targetStr)
    if not targetPlayer then
        triggerClientEvent(player, "chat:addMessage", player, {
            type = "HATA",
            typeColor = "#ef4444",
            header = "SİSTEM",
            content = "Oyuncu bulunamadı!"
        })
        return
    end

    local senderName = getCharacterName(player)
    local targetName = getCharacterName(targetPlayer)

    triggerClientEvent(player, "chat:addMessage", player, {
        type = "PM",
        typeColor = "#d97706",
        header = "[PM -> " .. targetName .. "]",
        content = message
    })
    triggerClientEvent(targetPlayer, "chat:addMessage", targetPlayer, {
        type = "PM",
        typeColor = "#d97706",
        header = "[PM <- " .. senderName .. "]",
        content = message
    })
end
registerRPCommand("pm", handlePm)

local function handleClear(player)
    triggerClientEvent(player, "chat:client:ClearChat", player)
end
registerRPCommand("clear", handleClear)

local function handlePsa(player, cmd, ...)
    if not isChatAdmin(player) then
        triggerClientEvent(player, "chat:addMessage", player, {
            type = "HATA",
            typeColor = "#ef4444",
            header = "YETKİ",
            content = "Bu komutu kullanmak için yetkiniz yok!"
        })
        return
    end

    local message = table.concat({...}, " ")
    if not message or message == "" then
        triggerClientEvent(player, "chat:addMessage", player, {
            type = "HATA",
            typeColor = "#ef4444",
            header = "KULLANIM",
            content = "/psa [mesaj]"
        })
        return
    end

    message = string.sub(sanitizeText(message), 1, 250)
    if message == "" then return end

    triggerClientEvent(root, "chat:addMessage", root, {
        type = "DUYURU",
        typeColor = "#e11d48",
        header = "YÖNETİM DUYURUSU",
        content = message
    })
end
registerRPCommand("psa", handlePsa)
registerRPCommand("duyuru", handlePsa)

local function handleGiveItem(player, cmd, arg1, arg2, arg3)
    if not isChatAdmin(player) then
        triggerClientEvent(player, "chat:addMessage", player, {
            type = "HATA",
            typeColor = "#ef4444",
            header = "YETKİ",
            content = "Bu komutu kullanmak için yetkiniz yok!"
        })
        return
    end

    if not arg1 then
        triggerClientEvent(player, "chat:addMessage", player, {
            type = "HATA",
            typeColor = "#ef4444",
            header = "KULLANIM",
            content = "/giveitem [eşya_adı] [adet] VEYA /giveitem [oyuncu] [eşya_adı] [adet]"
        })
        return
    end

    local targetPlayer = player
    local itemName = nil
    local count = 1

    if arg3 then
        targetPlayer = findPlayer(arg1)
        if not targetPlayer then
            triggerClientEvent(player, "chat:addMessage", player, {
                type = "HATA",
                typeColor = "#ef4444",
                header = "SİSTEM",
                content = "Oyuncu bulunamadı!"
            })
            return
        end
        itemName = tostring(arg2):lower()
        count = tonumber(arg3) or 1
    elseif arg2 then
        local maybeTarget = findPlayer(arg1)
        if maybeTarget and not tonumber(arg2) then
            targetPlayer = maybeTarget
            itemName = tostring(arg2):lower()
            count = 1
        else
            targetPlayer = player
            itemName = tostring(arg1):lower()
            count = tonumber(arg2) or 1
        end
    else
        targetPlayer = player
        itemName = tostring(arg1):lower()
        count = 1
    end

    if count < 1 then count = 1 end

    local invResource = getResourceFromName("gzl_inventory")
    if not invResource or getResourceState(invResource) ~= "running" or not exports.gzl_inventory or not exports.gzl_inventory.addItem then
        triggerClientEvent(player, "chat:addMessage", player, {
            type = "HATA",
            typeColor = "#ef4444",
            header = "SİSTEM",
            content = "Envanter sistemi aktif değil!"
        })
        return
    end

    local success = exports.gzl_inventory:addItem(targetPlayer, itemName, count)
    if success then
        local targetName = getCharacterName(targetPlayer)
        triggerClientEvent(player, "chat:addMessage", player, {
            type = "ENVANTER",
            typeColor = "#10b981",
            header = "EŞYA VERİLDİ",
            content = targetName .. " kişisine " .. count .. "x " .. itemName .. " verildi."
        })
        if targetPlayer ~= player then
            triggerClientEvent(targetPlayer, "chat:addMessage", targetPlayer, {
                type = "ENVANTER",
                typeColor = "#10b981",
                header = "EŞYA ALINDI",
                content = "Envanterinize " .. count .. "x " .. itemName .. " eklendi."
            })
        end
    else
        triggerClientEvent(player, "chat:addMessage", player, {
            type = "HATA",
            typeColor = "#ef4444",
            header = "SİSTEM",
            content = "Eşya verilemedi! Envanter dolu veya eşya adı geçersiz (" .. itemName .. ")."
        })
    end
end
registerRPCommand("giveitem", handleGiveItem)