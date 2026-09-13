Transactions = {}

function Transactions.getPlayerData(player)
    if not isElement(player) then return 0, 0, 0 end

    local cash = tonumber(getElementData(player, "character:money") or getElementData(player, "char:money") or getPlayerMoney(player)) or 0
    local bank = tonumber(getElementData(player, "character:bank") or getElementData(player, "char:bank_money") or getElementData(player, "char:bank")) or 0

    cash = math.max(0, math.floor(cash))
    bank = math.max(0, math.floor(bank))

    return cash, bank, (cash + bank)
end

function Transactions.getPlayerMoney(player)
    local _, _, total = Transactions.getPlayerData(player)
    return total
end

function Transactions.takeMoney(player, amount, reason)
    if not isElement(player) then return false end
    amount = tonumber(amount)
    if not amount or amount <= 0 then return false end
    amount = math.floor(amount)

    local cash, bank, total = Transactions.getPlayerData(player)
    if total < amount then
        return false
    end

    local newCash = cash
    local newBank = bank

    if cash >= amount then
        newCash = cash - amount
    else
        local remainder = amount - cash
        newCash = 0
        newBank = bank - remainder
    end

    setElementData(player, "character:money", newCash, "broadcast", "deny")
    setElementData(player, "char:money", newCash, "broadcast", "deny")
    setPlayerMoney(player, newCash)

    setElementData(player, "character:bank", newBank, "broadcast", "deny")
    setElementData(player, "char:bank_money", newBank)
    setElementData(player, "char:bank", newBank, "broadcast", "deny")

    local cRes = getResourceFromName("gzl_characters")
    if cRes and getResourceState(cRes) == "running" then
        pcall(function()
            if exports.gzl_characters.setPlayerCash then
                exports.gzl_characters:setPlayerCash(player, newCash)
            end
            if exports.gzl_characters.setPlayerBank then
                exports.gzl_characters:setPlayerBank(player, newBank)
            end
            if exports.gzl_characters.saveCharacter then
                exports.gzl_characters:saveCharacter(player)
            end
        end)
    end

    if Config.Debug then
        outputServerLog(string.format("[BLACKJACK] Para Kesildi: %s | Tutar: -$%d | Kalan Nakit: $%d | Kalan Banka: $%d | Sebep: %s",
            getPlayerName(player), amount, newCash, newBank, tostring(reason)))
    end

    return true
end

function Transactions.giveMoney(player, amount, reason)
    if not isElement(player) then return false end
    amount = tonumber(amount)
    if not amount or amount <= 0 then return false end
    amount = math.floor(amount)

    local cash, _, _ = Transactions.getPlayerData(player)
    local newCash = cash + amount

    setElementData(player, "character:money", newCash, "broadcast", "deny")
    setElementData(player, "char:money", newCash, "broadcast", "deny")
    setPlayerMoney(player, newCash)

    local cRes = getResourceFromName("gzl_characters")
    if cRes and getResourceState(cRes) == "running" then
        pcall(function()
            if exports.gzl_characters.setPlayerCash then
                exports.gzl_characters:setPlayerCash(player, newCash)
            end
            if exports.gzl_characters.saveCharacter then
                exports.gzl_characters:saveCharacter(player)
            end
        end)
    end

    if Config.Debug then
        outputServerLog(string.format("[BLACKJACK] Para Verildi: %s | Tutar: +$%d | Yeni Nakit: $%d | Sebep: %s",
            getPlayerName(player), amount, newCash, tostring(reason)))
    end

    return true
end