LogsDB = nil

function getLogsDB()
    return LogsDB
end

addEventHandler("onResourceStart", resourceRoot, function()
    LogsDB = dbConnect("sqlite", LogsConfig.DatabasePath or ":/database.db")
    if LogsDB then
        dbExec(LogsDB, [[
            CREATE TABLE IF NOT EXISTS log_admin (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                player_id INTEGER,
                player_name TEXT,
                admin_level INTEGER,
                command TEXT NOT NULL,
                target_id INTEGER,
                target_name TEXT,
                details TEXT,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP
            )
        ]])

        dbExec(LogsDB, [[
            CREATE TABLE IF NOT EXISTS log_money (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                sender_id INTEGER,
                sender_name TEXT,
                receiver_id INTEGER,
                receiver_name TEXT,
                amount INTEGER NOT NULL,
                trans_type TEXT NOT NULL,
                reason TEXT,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP
            )
        ]])

        dbExec(LogsDB, [[
            CREATE TABLE IF NOT EXISTS log_items (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                player_id INTEGER,
                player_name TEXT,
                action TEXT NOT NULL,
                item_name TEXT NOT NULL,
                item_count INTEGER DEFAULT 1,
                target_id INTEGER,
                target_name TEXT,
                details TEXT,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP
            )
        ]])

        dbExec(LogsDB, [[
            CREATE TABLE IF NOT EXISTS log_combat (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                victim_id INTEGER,
                victim_name TEXT,
                killer_id INTEGER,
                killer_name TEXT,
                weapon_id INTEGER,
                weapon_name TEXT,
                bodypart INTEGER,
                distance REAL,
                is_combat_log INTEGER DEFAULT 0,
                details TEXT,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP
            )
        ]])

        dbExec(LogsDB, [[
            CREATE TABLE IF NOT EXISTS log_sessions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                account_id INTEGER,
                character_id INTEGER,
                player_name TEXT,
                serial TEXT,
                ip TEXT,
                event_type TEXT NOT NULL,
                details TEXT,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP
            )
        ]])

        dbExec(LogsDB, [[
            CREATE TABLE IF NOT EXISTS log_system (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                category TEXT NOT NULL,
                level TEXT DEFAULT 'INFO',
                message TEXT NOT NULL,
                source_resource TEXT,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP
            )
        ]])

        dbExec(LogsDB, "CREATE INDEX IF NOT EXISTS idx_log_admin_time ON log_admin(created_at)")
        dbExec(LogsDB, "CREATE INDEX IF NOT EXISTS idx_log_money_time ON log_money(created_at)")
        dbExec(LogsDB, "CREATE INDEX IF NOT EXISTS idx_log_items_time ON log_items(created_at)")
        dbExec(LogsDB, "CREATE INDEX IF NOT EXISTS idx_log_combat_time ON log_combat(created_at)")
        dbExec(LogsDB, "CREATE INDEX IF NOT EXISTS idx_log_sessions_time ON log_sessions(created_at)")

        outputServerLog("[gzl_logs] Merkezi SQLite denetim kaydı (audit trail) veritabanı başarıyla bağlandı.")
    else
        outputServerLog("[gzl_logs] HATA: SQLite veritabanına bağlanılamadı (" .. tostring(LogsConfig.DatabasePath) .. ")!")
    end
end)