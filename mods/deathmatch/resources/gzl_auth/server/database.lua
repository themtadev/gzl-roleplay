DBConnection = nil

addEventHandler("onResourceStart", resourceRoot, function()
    DBConnection = dbConnect("sqlite", ":/database.db")
    if DBConnection then
        outputServerLog("[GZL Auth] Veritabanı bağlantısı başarıyla kuruldu.")

        local query = [[
            CREATE TABLE IF NOT EXISTS accounts (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                username TEXT UNIQUE NOT NULL,
                password TEXT NOT NULL,
                serial TEXT NOT NULL,
                ip TEXT NOT NULL,
                admin_level INTEGER DEFAULT 0,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                last_login DATETIME DEFAULT CURRENT_TIMESTAMP
            )
        ]]
        dbExec(DBConnection, query)
    else
        outputServerLog("[GZL Auth] HATA: Veritabanı bağlantısı kurulamadı!")
    end
end)

function getDatabase()
    return DBConnection
end