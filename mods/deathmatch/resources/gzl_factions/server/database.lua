FactionDB = nil

function getFactionDB()
    return FactionDB
end

addEventHandler("onResourceStart", resourceRoot, function()
    FactionDB = dbConnect("sqlite", FactionConfig.DatabasePath or ":/database.db")
    if FactionDB then
        dbExec(FactionDB, [[
            CREATE TABLE IF NOT EXISTS factions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT UNIQUE NOT NULL,
                short_name TEXT NOT NULL,
                faction_type TEXT NOT NULL,
                vault_balance INTEGER DEFAULT 0,
                max_members INTEGER DEFAULT 50,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP
            )
        ]])

        dbExec(FactionDB, [[
            CREATE TABLE IF NOT EXISTS faction_ranks (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                faction_id INTEGER NOT NULL,
                rank_id INTEGER NOT NULL,
                name TEXT NOT NULL,
                salary INTEGER DEFAULT 500,
                permissions TEXT DEFAULT '{}',
                FOREIGN KEY (faction_id) REFERENCES factions(id) ON DELETE CASCADE,
                UNIQUE(faction_id, rank_id)
            )
        ]])

        dbExec(FactionDB, [[
            CREATE TABLE IF NOT EXISTS faction_members (
                character_id INTEGER PRIMARY KEY,
                faction_id INTEGER NOT NULL,
                character_name TEXT,
                rank_id INTEGER DEFAULT 1,
                duty_status INTEGER DEFAULT 0,
                joined_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (faction_id) REFERENCES factions(id) ON DELETE CASCADE
            )
        ]])

        dbExec(FactionDB, [[
            CREATE TABLE IF NOT EXISTS faction_vault_logs (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                faction_id INTEGER NOT NULL,
                character_id INTEGER,
                character_name TEXT NOT NULL,
                action_type TEXT NOT NULL,
                amount INTEGER NOT NULL,
                reason TEXT,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (faction_id) REFERENCES factions(id) ON DELETE CASCADE
            )
        ]])

        dbQuery(function(qh)
            local cols = dbPoll(qh, 0)
            local hasCharName = false
            if cols then
                for _, col in ipairs(cols) do
                    if col.name == "character_name" then
                        hasCharName = true
                        break
                    end
                end
            end
            if not hasCharName then
                dbExec(FactionDB, "ALTER TABLE faction_members ADD COLUMN character_name TEXT")
            end
        end, FactionDB, "PRAGMA table_info(faction_members)")

        dbQuery(function(qh)
            local result = dbPoll(qh, 0)
            if not result or #result == 0 then
                outputServerLog("[gzl_factions] Boş veritabanı tespit edildi, varsayılan birlikler ekleniyor...")
                for fId, fData in pairs(FactionConfig.DefaultFactions or {}) do
                    dbExec(FactionDB, "INSERT OR IGNORE INTO factions (id, name, short_name, faction_type, vault_balance, max_members) VALUES (?, ?, ?, ?, ?, ?)",
                        fId, fData.name, fData.short_name, fData.faction_type, fData.vault_balance or 0, fData.max_members or 50)

                    for rId, rData in pairs(fData.ranks or {}) do
                        dbExec(FactionDB, "INSERT OR IGNORE INTO faction_ranks (faction_id, rank_id, name, salary) VALUES (?, ?, ?, ?)",
                            fId, rId, rData.name, rData.salary or 500)
                    end
                end
            end
            if loadAllFactionsFromDB then
                loadAllFactionsFromDB()
            end
        end, FactionDB, "SELECT id FROM factions LIMIT 1")

        outputServerLog("[gzl_factions] Birlik veritabanı tabloları başarıyla hazırlandı.")
    else
        outputServerLog("[gzl_factions] HATA: SQLite veritabanına bağlanılamadı!")
    end
end)

function addFactionVaultLog(factionId, charId, charName, actionType, amount, reason)
    local db = getFactionDB()
    if not db then return end
    dbExec(db, "INSERT INTO faction_vault_logs (faction_id, character_id, character_name, action_type, amount, reason) VALUES (?, ?, ?, ?, ?, ?)",
        tonumber(factionId), tonumber(charId) or 0, tostring(charName or "Bilinmeyen"), tostring(actionType or "unknown"), math.floor(tonumber(amount) or 0), tostring(reason or ""))
end

function getFactionVaultLogs(factionId, limit, callback)
    local db = getFactionDB()
    if not db or not callback then return end
    limit = math.min(50, math.max(1, tonumber(limit) or 20))
    dbQuery(function(qh)
        local rows = dbPoll(qh, 0) or {}
        callback(rows)
    end, db, "SELECT * FROM faction_vault_logs WHERE faction_id = ? ORDER BY id DESC LIMIT ?", tonumber(factionId), limit)
end
