TaxiDB = nil
TaxiPlateCache = {}

local function normalizeTaxiPlate(plate)
    local value = string.upper(tostring(plate or ""))
    value = string.gsub(value, "%s+", " ")
    return value
end

local function ensureTaxiDatabase()
    if not TaxiDB then
        TaxiDB = dbConnect("sqlite", ":/database.db")
    end
    if TaxiDB then
        dbExec(TaxiDB, "CREATE TABLE IF NOT EXISTS taxi_plates (id INTEGER PRIMARY KEY AUTOINCREMENT, plate_text TEXT UNIQUE NOT NULL, owner_char_id INTEGER NOT NULL, vehicle_model INTEGER, created_at DATETIME DEFAULT CURRENT_TIMESTAMP)")
    end
    return TaxiDB
end

local function loadTaxiPlateCache()
    local db = ensureTaxiDatabase()
    if not db then return end
    dbQuery(function(queryHandle)
        local rows = dbPoll(queryHandle, 0)
        if not rows then return end
        TaxiPlateCache = {}
        for _, row in ipairs(rows) do
            TaxiPlateCache[normalizeTaxiPlate(row.plate_text)] = true
        end
    end, db, "SELECT plate_text FROM taxi_plates")
end

function getTaxiDB()
    return ensureTaxiDatabase()
end

function isTaxiPlateRegistered(plate)
    return TaxiPlateCache[normalizeTaxiPlate(plate)] == true
end

function registerTaxiPlate(plate)
    TaxiPlateCache[normalizeTaxiPlate(plate)] = true
end

function unregisterTaxiPlate(plate)
    TaxiPlateCache[normalizeTaxiPlate(plate)] = nil
end

addEventHandler("onResourceStart", resourceRoot, function()
    loadTaxiPlateCache()
end)