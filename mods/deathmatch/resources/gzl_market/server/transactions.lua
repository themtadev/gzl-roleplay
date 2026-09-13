local purchaseCooldowns = {}
local shopCatalogs = {}

for shopType, shopData in pairs(ShopsData) do
    local catalog = {}
    for _, category in ipairs(shopData.categories or {}) do
        for _, item in ipairs(category.items or {}) do
            catalog[item.id] = item
        end
    end
    shopCatalogs[shopType] = catalog
end

local function sendError(player, message)
    triggerClientEvent(player, "gzl_market:purchaseError", player, { message = message })
end

local function getPaymentBalance(player, method, total)
    if method == "cash" then
        local cash = tonumber(getElementData(player, "character:money") or getElementData(player, "char:money")) or getPlayerMoney(player) or 0
        if cash >= total then return "cash", cash end
        return nil, cash
    end

    local bank = tonumber(getElementData(player, "character:bank") or getElementData(player, "char:bank_money") or getElementData(player, "char:bank")) or 0
    if bank >= total then return "bank", bank end
    local cash = tonumber(getElementData(player, "character:money") or getElementData(player, "char:money")) or getPlayerMoney(player) or 0
    if cash >= total then return "cash", cash end
    return nil, math.max(bank, cash)
end

local function deductBalance(player, balanceType, balance, total)
    local newBalance = balance - total
    if balanceType == "bank" then
        setElementData(player, "character:bank", newBalance, "broadcast", "deny")
        setElementData(player, "char:bank_money", newBalance)
        setElementData(player, "char:bank", newBalance, "broadcast", "deny")
    else
        setElementData(player, "character:money", newBalance, "broadcast", "deny")
        setElementData(player, "char:money", newBalance, "broadcast", "deny")
        setPlayerMoney(player, newBalance)
    end
    if exports.gzl_characters and exports.gzl_characters.saveCharacter then
        exports.gzl_characters:saveCharacter(player)
    end
end

local function hasInventoryExports()
    local resource = getResourceFromName("gzl_inventory")
    if not resource or getResourceState(resource) ~= "running" then return false end
    return exports.gzl_inventory and type(exports.gzl_inventory.addItem) == "function" and type(exports.gzl_inventory.removeItem) == "function"
end

local function grantInventoryItems(player, requested, order)
    if not hasInventoryExports() then
        for _, id in ipairs(order) do
            local current = tonumber(getElementData(player, "item:" .. id)) or 0
            setElementData(player, "item:" .. id, current + requested[id])
        end
        return true
    end

    local granted = {}
    for _, id in ipairs(order) do
        local quantity = requested[id]
        if not exports.gzl_inventory:addItem(player, id, quantity) then
            for _, grantedId in ipairs(granted) do
                exports.gzl_inventory:removeItem(player, grantedId, requested[grantedId])
            end
            return false
        end
        granted[#granted + 1] = id
    end
    return true
end

local function grantWeapons(player, requested, order)
    for _, id in ipairs(order) do
        local weaponId = nil
        if id == "WEAPON_GLOCK" or id == "WEAPON_COMBATPISTOL" or id == "WEAPON_HEAVYPISTOL" then
            weaponId = 22
        elseif id == "WEAPON_PUMPSHOTGUN" then
            weaponId = 25
        elseif id == "WEAPON_SAWNOFFSHOTGUN" then
            weaponId = 26
        end
        if weaponId then
            giveWeapon(player, weaponId, 30 * requested[id], false)
        end
    end
end

addEvent("gzl_market:serverPurchase", true)
addEventHandler("gzl_market:serverPurchase", root, function(payload)
    if client then
        local ac = getResourceFromName("gzl_anticheat")
        if not ac or getResourceState(ac) ~= "running" or not exports.gzl_anticheat:allowEvent(client, "gzl_market:serverPurchase", payload) then return end
    end
    if not client or client ~= source or getElementType(client) ~= "player" then return end
    local player = client
    if type(payload) ~= "table" then return end

    local now = getTickCount()
    if purchaseCooldowns[player] and now - purchaseCooldowns[player] < 650 then
        sendError(player, "Lütfen tekrar denemeden önce bekleyin.")
        return
    end
    purchaseCooldowns[player] = now

    local shopType = payload.shopType
    local method = payload.method
    local items = payload.items
    if type(shopType) ~= "string" or not ShopsData[shopType] or not shopCatalogs[shopType] then
        sendError(player, "Geçersiz mağaza türü!")
        return
    end
    if type(method) ~= "string" or not Config.PaymentMethods[method] then
        sendError(player, "Geçersiz ödeme yöntemi!")
        return
    end
    if type(items) ~= "table" or #items < 1 or #items > 64 then
        sendError(player, "Sepet içeriği geçersiz!")
        return
    end

    local catalog = shopCatalogs[shopType]
    local requested = {}
    local order = {}
    local calculatedTotal = 0
    local totalItemsCount = 0

    for _, cartItem in ipairs(items) do
        if type(cartItem) ~= "table" or type(cartItem.id) ~= "string" or type(cartItem.quantity) ~= "number" then
            sendError(player, "Geçersiz ürün verisi!")
            return
        end
        local id = cartItem.id
        local quantity = cartItem.quantity
        if quantity ~= math.floor(quantity) or quantity < 1 or quantity > 99 then
            sendError(player, "Geçersiz ürün adedi!")
            return
        end
        local item = catalog[id]
        if not item or type(item.price) ~= "number" or item.price < 0 then
            sendError(player, "Geçersiz ürün tespit edildi!")
            return
        end
        if requested[id] then
            requested[id] = requested[id] + quantity
            if requested[id] > 99 then
                sendError(player, "Bir ürün için adet sınırı aşıldı!")
                return
            end
        else
            requested[id] = quantity
            order[#order + 1] = id
        end
    end

    for _, id in ipairs(order) do
        local quantity = requested[id]
        calculatedTotal = calculatedTotal + catalog[id].price * quantity
        totalItemsCount = totalItemsCount + quantity
    end

    if calculatedTotal <= 0 or calculatedTotal > 10000000 or totalItemsCount > 512 then
        sendError(player, "Sepet toplamı geçersiz!")
        return
    end

    local balanceType, balance = getPaymentBalance(player, method, calculatedTotal)
    if not balanceType then
        sendError(player, "Yetersiz bakiye!")
        return
    end
    if not grantInventoryItems(player, requested, order) then
        sendError(player, "Envanterinizde yeterli alan yok!")
        return
    end

    deductBalance(player, balanceType, balance, calculatedTotal)
    grantWeapons(player, requested, order)
    triggerClientEvent(player, "gzl_market:purchaseSuccess", player, {
        totalCost = calculatedTotal,
        method = balanceType == "cash" and "Nakit" or "Banka Kartı",
        count = totalItemsCount
    })
end)

addEventHandler("onPlayerQuit", root, function()
    purchaseCooldowns[source] = nil
end)