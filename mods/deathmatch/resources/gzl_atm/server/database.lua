local ATM_DB = nil

addEventHandler("onResourceStart", resourceRoot, function()
    ATM_DB = dbConnect("sqlite", ":/database.db")
    if ATM_DB then
        local q = [[
            CREATE TABLE IF NOT EXISTS atm_transactions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                char_id INTEGER NOT NULL,
                char_name TEXT NOT NULL,
                type TEXT NOT NULL,
                amount INTEGER NOT NULL,
                balance_after INTEGER NOT NULL,
                note TEXT DEFAULT '',
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP
            )
        ]]
        dbExec(ATM_DB, q)
    end
end)

function getATMDB()
    return ATM_DB
end

function logATMTransaction(charId, charName, txType, amount, balanceAfter, note)
    if not ATM_DB or not charId then return end
    local q = [[
        INSERT INTO atm_transactions (char_id, char_name, type, amount, balance_after, note)
        VALUES (?, ?, ?, ?, ?, ?)
    ]]
    dbExec(ATM_DB, q, charId, tostring(charName or "Bilinmiyor"), tostring(txType), tonumber(amount) or 0, tonumber(balanceAfter) or 0, tostring(note or ""))
end