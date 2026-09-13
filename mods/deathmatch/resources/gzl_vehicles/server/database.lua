VehDB = nil

addEventHandler("onResourceStart", resourceRoot, function()
    VehDB = dbConnect("sqlite", ":/database.db")
    if VehDB then
        local q = [[
            CREATE TABLE IF NOT EXISTS vehicles (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                owner_id INTEGER NOT NULL,
                owner_name TEXT NOT NULL,
                model INTEGER NOT NULL,
                plate TEXT UNIQUE NOT NULL,
                color1 INTEGER DEFAULT 0,
                color2 INTEGER DEFAULT 0,
                pos_x REAL DEFAULT 2206.3,
                pos_y REAL DEFAULT -2198.9,
                pos_z REAL DEFAULT 13.3,
                rot_z REAL DEFAULT 314.0,
                interior INTEGER DEFAULT 0,
                dimension INTEGER DEFAULT 0,
                health REAL DEFAULT 1000.0,
                fuel REAL DEFAULT 100.0,
                locked INTEGER DEFAULT 0,
                in_garage INTEGER DEFAULT 0,
                upgrades TEXT DEFAULT '',
                headlights TEXT DEFAULT '',
                neon TEXT DEFAULT '',
                trunk_items TEXT DEFAULT '[]',
                glovebox_items TEXT DEFAULT '[]',
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                last_active DATETIME DEFAULT CURRENT_TIMESTAMP
            )
        ]]
        dbExec(VehDB, q)
        local checkQ = dbQuery(VehDB, "PRAGMA table_info(vehicles)")
        local cols = dbPoll(checkQ, -1)
        if cols then
            local hasCol = {}
            for _, col in ipairs(cols) do
                hasCol[col.name] = true
            end
            if not hasCol["upgrades"] then
                dbExec(VehDB, "ALTER TABLE vehicles ADD COLUMN upgrades TEXT DEFAULT ''")
            end
            if not hasCol["headlights"] then
                dbExec(VehDB, "ALTER TABLE vehicles ADD COLUMN headlights TEXT DEFAULT ''")
            end
            if not hasCol["neon"] then
                dbExec(VehDB, "ALTER TABLE vehicles ADD COLUMN neon TEXT DEFAULT ''")
            end
            if not hasCol["trunk_items"] then
                dbExec(VehDB, "ALTER TABLE vehicles ADD COLUMN trunk_items TEXT DEFAULT '[]'")
            end
            if not hasCol["glovebox_items"] then
                dbExec(VehDB, "ALTER TABLE vehicles ADD COLUMN glovebox_items TEXT DEFAULT '[]'")
            end
        end
    end
end)

function getVehicleDB()
    return VehDB
end