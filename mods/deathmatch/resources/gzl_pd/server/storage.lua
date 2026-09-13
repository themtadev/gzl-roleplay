
PDStorage = {}
PDStorage.connection = nil

function PDStorage.init()
    PDStorage.connection = dbConnect("sqlite", "pd_records.db", "", "", "share=1;log=1")

    if PDStorage.connection then

        dbExec(PDStorage.connection, [[
            CREATE TABLE IF NOT EXISTS pd_records (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                target_name TEXT NOT NULL,
                officer_name TEXT NOT NULL,
                crime_title TEXT NOT NULL,
                fine_amount INTEGER DEFAULT 0,
                jail_time INTEGER DEFAULT 0,
                timestamp INTEGER NOT NULL
            )
        ]])

        dbExec(PDStorage.connection, [[
            CREATE TABLE IF NOT EXISTS pd_wanted_citizens (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                target_name TEXT NOT NULL UNIQUE,
                wanted_level INTEGER DEFAULT 1,
                reason TEXT NOT NULL,
                officer_name TEXT NOT NULL,
                timestamp INTEGER NOT NULL
            )
        ]])

        dbExec(PDStorage.connection, [[
            CREATE TABLE IF NOT EXISTS pd_wanted_vehicles (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                plate TEXT NOT NULL UNIQUE,
                model_name TEXT NOT NULL,
                reason TEXT NOT NULL,
                officer_name TEXT NOT NULL,
                timestamp INTEGER NOT NULL
            )
        ]])

        dbExec(PDStorage.connection, [[
            CREATE TABLE IF NOT EXISTS pd_apb_bulletins (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                title TEXT NOT NULL,
                description TEXT NOT NULL,
                officer_name TEXT NOT NULL,
                timestamp INTEGER NOT NULL
            )
        ]])
        outputServerLog("[GZL PD System] Database storage initialized successfully.")
    else
        outputServerLog("[GZL PD System ERROR] Failed to connect to PD database!")
    end
end

function PDStorage.addRecord(targetName, officerName, crimeTitle, fineAmount, jailTime, callback)
    if not PDStorage.connection then return end
    local ts = getRealTime().timestamp

    dbQuery(function(qh)
        local results, numRows, lastInsertID = dbPoll(qh, 0)
        local success = (results ~= nil and lastInsertID and lastInsertID > 0)
        if callback then callback(success) end
    end, PDStorage.connection,
        "INSERT INTO pd_records (target_name, officer_name, crime_title, fine_amount, jail_time, timestamp) VALUES (?, ?, ?, ?, ?, ?)",
        tostring(targetName), tostring(officerName), tostring(crimeTitle), tonumber(fineAmount) or 0, tonumber(jailTime) or 0, ts
    )
end

function PDStorage.getRecords(targetName, callback)
    if not PDStorage.connection then if callback then callback({}) end return end

    dbQuery(function(qh)
        local results = dbPoll(qh, 0)
        if callback then callback(results or {}) end
    end, PDStorage.connection,
        "SELECT * FROM pd_records WHERE target_name LIKE ? ORDER BY timestamp DESC LIMIT 30",
        "%" .. tostring(targetName) .. "%"
    )
end

function PDStorage.setWantedCitizen(targetName, wantedLevel, reason, officerName, callback)
    if not PDStorage.connection then return end
    local ts = getRealTime().timestamp

    if wantedLevel <= 0 then

        dbExec(PDStorage.connection, "DELETE FROM pd_wanted_citizens WHERE target_name = ?", tostring(targetName))
        if callback then callback(true) end
    else
        dbQuery(function(qh)
            local results = dbPoll(qh, 0)
            if results and #results > 0 then
                dbExec(PDStorage.connection, "UPDATE pd_wanted_citizens SET wanted_level = ?, reason = ?, officer_name = ?, timestamp = ? WHERE target_name = ?",
                    tonumber(wantedLevel), tostring(reason), tostring(officerName), ts, tostring(targetName))
            else
                dbExec(PDStorage.connection, "INSERT INTO pd_wanted_citizens (target_name, wanted_level, reason, officer_name, timestamp) VALUES (?, ?, ?, ?, ?)",
                    tostring(targetName), tonumber(wantedLevel), tostring(reason), tostring(officerName), ts)
            end
            if callback then callback(true) end
        end, PDStorage.connection, "SELECT id FROM pd_wanted_citizens WHERE target_name = ?", tostring(targetName))
    end
end

function PDStorage.getAllWantedCitizens(callback)
    if not PDStorage.connection then if callback then callback({}) end return end

    dbQuery(function(qh)
        local results = dbPoll(qh, 0)
        if callback then callback(results or {}) end
    end, PDStorage.connection, "SELECT * FROM pd_wanted_citizens ORDER BY wanted_level DESC")
end

function PDStorage.setWantedVehicle(plate, modelName, reason, officerName, isRemove, callback)
    if not PDStorage.connection then return end
    local cleanPlate = string.upper(tostring(plate)):gsub("%s+", "")
    local ts = getRealTime().timestamp

    if isRemove then
        dbExec(PDStorage.connection, "DELETE FROM pd_wanted_vehicles WHERE plate = ?", cleanPlate)
        if callback then callback(true) end
    else
        dbExec(PDStorage.connection, "INSERT OR REPLACE INTO pd_wanted_vehicles (plate, model_name, reason, officer_name, timestamp) VALUES (?, ?, ?, ?, ?)",
            cleanPlate, tostring(modelName), tostring(reason), tostring(officerName), ts)
        if callback then callback(true) end
    end
end

function PDStorage.getAllWantedVehicles(callback)
    if not PDStorage.connection then if callback then callback({}) end return end

    dbQuery(function(qh)
        local results = dbPoll(qh, 0)
        if callback then callback(results or {}) end
    end, PDStorage.connection, "SELECT * FROM pd_wanted_vehicles ORDER BY timestamp DESC")
end

function PDStorage.addBulletin(title, description, officerName, callback)
    if not PDStorage.connection then return end
    local ts = getRealTime().timestamp

    dbExec(PDStorage.connection, "INSERT INTO pd_apb_bulletins (title, description, officer_name, timestamp) VALUES (?, ?, ?, ?)",
        tostring(title), tostring(description), tostring(officerName), ts)
    if callback then callback(true) end
end

function PDStorage.getBulletins(callback)
    if not PDStorage.connection then if callback then callback({}) end return end

    dbQuery(function(qh)
        local results = dbPoll(qh, 0)
        if callback then callback(results or {}) end
    end, PDStorage.connection, "SELECT * FROM pd_apb_bulletins ORDER BY timestamp DESC LIMIT 15")
end