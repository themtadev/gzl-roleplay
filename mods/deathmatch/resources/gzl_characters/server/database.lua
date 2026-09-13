CharDB = nil

addEventHandler("onResourceStart", resourceRoot, function()
    CharDB = dbConnect("sqlite", ":/database.db")
    if CharDB then
        local query = [[
            CREATE TABLE IF NOT EXISTS characters (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                account_id INTEGER NOT NULL,
                name TEXT UNIQUE NOT NULL,
                gender INTEGER DEFAULT 1,
                age INTEGER DEFAULT 24,
                skin INTEGER DEFAULT 0,
                money INTEGER DEFAULT 2500,
                bank_money INTEGER DEFAULT 10000,
                health REAL DEFAULT 100,
                armor REAL DEFAULT 0,
                hunger REAL DEFAULT 100,
                thirst REAL DEFAULT 100,
                pos_x REAL DEFAULT 1481.0,
                pos_y REAL DEFAULT -1771.5,
                pos_z REAL DEFAULT 18.7,
                rot_z REAL DEFAULT 0,
                interior INTEGER DEFAULT 0,
                dimension INTEGER DEFAULT 0,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                last_active DATETIME DEFAULT CURRENT_TIMESTAMP,
                customization TEXT DEFAULT '{}',
                is_dead INTEGER DEFAULT 0,
                death_time_remaining INTEGER DEFAULT 0,
                FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE
            )
        ]]
        dbExec(CharDB, query)

        dbQuery(function(qh)
            local cols = dbPoll(qh, 0)
            local hasCustom = false
            local hasIsDead = false
            local hasDeathTime = false
            if cols then
                for _, col in ipairs(cols) do
                    if col.name == "customization" then
                        hasCustom = true
                    elseif col.name == "is_dead" then
                        hasIsDead = true
                    elseif col.name == "death_time_remaining" then
                        hasDeathTime = true
                    end
                end
            end
            if not hasCustom then
                dbExec(CharDB, "ALTER TABLE characters ADD COLUMN customization TEXT DEFAULT '{}'")
            end
            if not hasIsDead then
                dbExec(CharDB, "ALTER TABLE characters ADD COLUMN is_dead INTEGER DEFAULT 0")
            end
            if not hasDeathTime then
                dbExec(CharDB, "ALTER TABLE characters ADD COLUMN death_time_remaining INTEGER DEFAULT 0")
            end
        end, CharDB, "PRAGMA table_info(characters)")
    end
end)

function getCharacterDB()
    return CharDB
end