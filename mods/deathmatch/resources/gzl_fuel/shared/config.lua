Config = {}

Config.FuelElementData = "veh:fuel"
Config.DefaultFuelPercent = 72
Config.InteractionDistance = 7.5
Config.FuelingDistance = 9.0
Config.FuelingTickMs = 650
Config.FuelingLitersPerTick = 0.8
Config.ConsumptionTickMs = 3000
Config.ConsumptionMultiplier = 2.25
Config.VehicleSaveIntervalMs = 30000
Config.StationSaveIntervalMs = 10000
Config.AttendantRange = 28
Config.AttendantPayPerLiter = 0.75
Config.MaxEmployees = 8
Config.MaxOwnedStations = 2
Config.BusinessSaleRate = 0.70
Config.MinFuelPrice = 3.50
Config.MaxFuelPrice = 15.00
Config.PriceStep = 0.05
Config.StockOrderStep = 250
Config.MaxStockOrder = 5000

Config.AllowedVehicleTypes = {
    ["Automobile"] = true,
    ["Bike"] = true,
    ["Monster Truck"] = true,
    ["Quad"] = true
}

Config.VehicleCapacity = {
    ["Automobile"] = 65,
    ["Bike"] = 18,
    ["Monster Truck"] = 110,
    ["Quad"] = 22
}

Config.VehicleConsumption = {
    ["Automobile"] = 11.5,
    ["Bike"] = 5.5,
    ["Monster Truck"] = 22,
    ["Quad"] = 8
}

Config.CapacityOverrides = {
    [403] = 140,
    [406] = 180,
    [407] = 110,
    [408] = 135,
    [414] = 100,
    [416] = 85,
    [428] = 105,
    [431] = 150,
    [437] = 150,
    [443] = 160,
    [455] = 140,
    [456] = 110,
    [498] = 105,
    [499] = 95,
    [514] = 150,
    [515] = 165,
    [524] = 150,
    [578] = 135,
    [609] = 95
}

Config.Stations = {
    {
        id = 1,
        name = "Idlewood Petrol",
        district = "Idlewood, Los Santos",
        x = 1941.41,
        y = -1776.23,
        z = 13.64,
        basePrice = 6.75,
        wholesalePrice = 4.10,
        purchasePrice = 185000,
        stock = 8500,
        maxStock = 12000
    },
    {
        id = 2,
        name = "Temple Energy",
        district = "Temple, Los Santos",
        x = 1004.71,
        y = -939.38,
        z = 42.18,
        basePrice = 6.95,
        wholesalePrice = 4.20,
        purchasePrice = 215000,
        stock = 9000,
        maxStock = 13000
    },
    {
        id = 3,
        name = "Flint County Fuel",
        district = "Flint County",
        x = -90.58,
        y = -1169.13,
        z = 2.42,
        basePrice = 6.45,
        wholesalePrice = 3.95,
        purchasePrice = 155000,
        stock = 7200,
        maxStock = 10000
    },
    {
        id = 4,
        name = "Dillimore Gas",
        district = "Dillimore, Red County",
        x = 655.50,
        y = -557.37,
        z = 16.50,
        basePrice = 6.60,
        wholesalePrice = 4.00,
        purchasePrice = 165000,
        stock = 7600,
        maxStock = 10500
    },
    {
        id = 5,
        name = "Montgomery Oil",
        district = "Montgomery, Red County",
        x = 1380.75,
        y = 457.52,
        z = 19.96,
        basePrice = 6.55,
        wholesalePrice = 3.90,
        purchasePrice = 175000,
        stock = 8000,
        maxStock = 11000
    },
    {
        id = 6,
        name = "Angel Pine Service",
        district = "Angel Pine, Whetstone",
        x = -2242.06,
        y = -2561.32,
        z = 31.92,
        basePrice = 6.35,
        wholesalePrice = 3.80,
        purchasePrice = 145000,
        stock = 6800,
        maxStock = 9500
    }
}

function getFuelStationConfig(stationId)
    stationId = tonumber(stationId)
    if not stationId then return nil end
    for _, station in ipairs(Config.Stations) do
        if station.id == stationId then
            return station
        end
    end
    return nil
end

function getFuelVehicleCapacity(vehicle)
    if not isElement(vehicle) or getElementType(vehicle) ~= "vehicle" then return 0 end
    local override = Config.CapacityOverrides[getElementModel(vehicle)]
    if override then return override end
    return Config.VehicleCapacity[getVehicleType(vehicle)] or 0
end