phoneDB = nil

function initPhoneDatabase()
    phoneDB = dbConnect("sqlite", "phone.db")
    if not phoneDB then
        outputServerLog("[cylex_phone] HATA: SQLite phone.db veritabani baglantisi kurulamadi!")
        return false
    end

    outputServerLog("[cylex_phone] SQLite phone.db baglantisi basariyla kuruldu.")

    dbExec(phoneDB, [[
        CREATE TABLE IF NOT EXISTS phone_users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            char_id INTEGER UNIQUE NOT NULL,
            phone_number TEXT UNIQUE NOT NULL,
            iban TEXT UNIQUE NOT NULL,
            twitter_account TEXT,
            mail_account TEXT,
            darkchat_user TEXT,
            settings TEXT,
            calls TEXT,
            notes TEXT,
            photos TEXT,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        )
    ]])

    dbExec(phoneDB, [[
        CREATE TABLE IF NOT EXISTS phone_contacts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            owner_number TEXT NOT NULL,
            number TEXT NOT NULL,
            name TEXT NOT NULL,
            photo TEXT,
            tag TEXT
        )
    ]])

    dbExec(phoneDB, [[
        CREATE TABLE IF NOT EXISTS phone_messages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            from_number TEXT NOT NULL,
            to_number TEXT NOT NULL,
            message TEXT NOT NULL,
            time INTEGER NOT NULL,
            is_read INTEGER DEFAULT 0,
            attachments TEXT,
            folder TEXT DEFAULT 'inbox',
            deleted_at INTEGER DEFAULT 0
        )
    ]])

    dbExec(phoneDB, [[
        CREATE TABLE IF NOT EXISTS phone_chats (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            owner_number TEXT NOT NULL,
            number TEXT NOT NULL,
            name TEXT,
            photo TEXT,
            muted INTEGER DEFAULT 0,
            is_pinned INTEGER DEFAULT 0,
            is_blocked INTEGER DEFAULT 0,
            folder TEXT DEFAULT 'inbox',
            last_message TEXT,
            last_time INTEGER DEFAULT 0
        )
    ]])

    local function addColumnIfNotExists(tableName, colName, colDef)
        local q = dbQuery(phoneDB, string.format("PRAGMA table_info(%s)", tableName))
        local rows = dbPoll(q, 1000) or {}
        local exists = false
        for _, r in ipairs(rows) do
            if r.name == colName then
                exists = true
                break
            end
        end
        if not exists then
            dbExec(phoneDB, string.format("ALTER TABLE %s ADD COLUMN %s %s", tableName, colName, colDef))
        end
    end
    addColumnIfNotExists("phone_messages", "folder", "TEXT DEFAULT 'inbox'")
    addColumnIfNotExists("phone_messages", "deleted_at", "INTEGER DEFAULT 0")
    addColumnIfNotExists("phone_messages", "read_time", "TEXT")
    addColumnIfNotExists("phone_chats", "muted", "INTEGER DEFAULT 0")
    addColumnIfNotExists("phone_chats", "is_pinned", "INTEGER DEFAULT 0")
    addColumnIfNotExists("phone_chats", "is_blocked", "INTEGER DEFAULT 0")
    addColumnIfNotExists("phone_chats", "folder", "TEXT DEFAULT 'inbox'")
    addColumnIfNotExists("phone_chats", "last_message", "TEXT")
    addColumnIfNotExists("phone_chats", "last_time", "INTEGER DEFAULT 0")
    addColumnIfNotExists("phone_chats", "is_read", "INTEGER DEFAULT 1")
    addColumnIfNotExists("phone_chats", "unread", "INTEGER DEFAULT 0")

    dbExec(phoneDB, "CREATE INDEX IF NOT EXISTS idx_phone_messages_from_to ON phone_messages (from_number, to_number, time);")
    dbExec(phoneDB, "CREATE INDEX IF NOT EXISTS idx_phone_messages_to_from ON phone_messages (to_number, from_number, time);")
    dbExec(phoneDB, "CREATE INDEX IF NOT EXISTS idx_phone_messages_folder ON phone_messages (folder);")
    dbExec(phoneDB, "CREATE INDEX IF NOT EXISTS idx_phone_chats_owner ON phone_chats (owner_number, last_time);")
    dbExec(phoneDB, "CREATE INDEX IF NOT EXISTS idx_phone_chats_owner_num ON phone_chats (owner_number, number);")
    dbExec(phoneDB, "CREATE INDEX IF NOT EXISTS idx_phone_contacts_owner ON phone_contacts (owner_number);")
    dbExec(phoneDB, "CREATE INDEX IF NOT EXISTS idx_phone_users_phone ON phone_users (phone_number);")
    dbExec(phoneDB, "CREATE INDEX IF NOT EXISTS idx_phone_users_char ON phone_users (char_id);")

    dbExec(phoneDB, [[
        CREATE TABLE IF NOT EXISTS phone_groups (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            owner_number TEXT NOT NULL,
            name TEXT NOT NULL,
            photo TEXT,
            members TEXT,
            moderators TEXT
        )
    ]])

    dbExec(phoneDB, [[
        CREATE TABLE IF NOT EXISTS phone_twitteraccounts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            email TEXT UNIQUE NOT NULL,
            name TEXT NOT NULL,
            username TEXT UNIQUE NOT NULL,
            password TEXT NOT NULL,
            avatar TEXT,
            rank TEXT DEFAULT 'default',
            settings TEXT
        )
    ]])

    dbExec(phoneDB, [[
        CREATE TABLE IF NOT EXISTS phone_tweets (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            author_email TEXT NOT NULL,
            author_name TEXT NOT NULL,
            author_avatar TEXT,
            content TEXT NOT NULL,
            image TEXT,
            time INTEGER NOT NULL,
            likes TEXT,
            reply_to INTEGER DEFAULT NULL
        )
    ]])

    dbExec(phoneDB, [[
        CREATE TABLE IF NOT EXISTS phone_mailaccounts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            address TEXT UNIQUE NOT NULL,
            name TEXT NOT NULL,
            password TEXT NOT NULL,
            photo TEXT
        )
    ]])

    dbExec(phoneDB, [[
        CREATE TABLE IF NOT EXISTS phone_mail (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            owner_address TEXT NOT NULL,
            sender_address TEXT NOT NULL,
            sender_name TEXT NOT NULL,
            sender_avatar TEXT,
            recipients TEXT NOT NULL,
            subject TEXT NOT NULL,
            content TEXT NOT NULL,
            time INTEGER NOT NULL,
            starred INTEGER DEFAULT 0,
            muted INTEGER DEFAULT 0,
            actions TEXT
        )
    ]])

    dbExec(phoneDB, [[
        CREATE TABLE IF NOT EXISTS phone_darkgroups (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            photo TEXT,
            code TEXT UNIQUE NOT NULL,
            creator TEXT NOT NULL,
            members TEXT,
            bans TEXT
        )
    ]])

    dbExec(phoneDB, [[
        CREATE TABLE IF NOT EXISTS phone_darkmessages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            group_id INTEGER NOT NULL,
            sender TEXT NOT NULL,
            message TEXT NOT NULL,
            time INTEGER NOT NULL
        )
    ]])

    dbExec(phoneDB, [[
        CREATE TABLE IF NOT EXISTS phone_ads (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            owner_number TEXT NOT NULL,
            author TEXT NOT NULL,
            title TEXT NOT NULL,
            content TEXT NOT NULL,
            image TEXT,
            data TEXT,
            time INTEGER NOT NULL
        )
    ]])

    dbExec(phoneDB, [[
        CREATE TABLE IF NOT EXISTS phone_transactions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            from_iban TEXT NOT NULL,
            to_iban TEXT NOT NULL,
            amount INTEGER NOT NULL,
            reason TEXT,
            time INTEGER NOT NULL
        )
    ]])

    dbExec(phoneDB, "CREATE INDEX IF NOT EXISTS idx_phone_tweets_time ON phone_tweets (time);")
    dbExec(phoneDB, "CREATE INDEX IF NOT EXISTS idx_phone_darkmessages_time ON phone_darkmessages (time);")
    dbExec(phoneDB, "CREATE INDEX IF NOT EXISTS idx_phone_ads_time ON phone_ads (time);")
    dbExec(phoneDB, "CREATE INDEX IF NOT EXISTS idx_phone_transactions_from ON phone_transactions (from_iban, time);")
    dbExec(phoneDB, "CREATE INDEX IF NOT EXISTS idx_phone_transactions_to ON phone_transactions (to_iban, time);")
    dbExec(phoneDB, "CREATE INDEX IF NOT EXISTS idx_phone_chats_folder ON phone_chats (owner_number, folder, is_pinned, last_time);")

    return true
end

addEventHandler("onResourceStart", resourceRoot, function()
    initPhoneDatabase()
end)

function getPhoneDB()
    return phoneDB
end