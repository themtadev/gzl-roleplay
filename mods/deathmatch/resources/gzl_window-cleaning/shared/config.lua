Config = {}

Config.DepotLocation = {
    marker = { x = 1798.50, y = -1705.20, z = 13.50 },
    ped = { x = 1798.50, y = -1705.20, z = 13.50, rot = 90.0, skin = 260 },
    vehicleSpawn = { x = 1805.20, y = -1709.50, z = 13.50, rot = 90.0 },
    vehicleReturn = { x = 1805.20, y = -1709.50, z = 13.50, radius = 5.0 }
}

Config.JobVehicleModel = 552
Config.WorkerSkin = 260

Config.MaxGroupMembers = 4
Config.CleanRequirement = 0.95

Config.Economy = {
    basePayPerWindow = 350,
    completionBonus = 1200,
    groupMultiplierPerMember = 0.15
}

Config.Buildings = {
    {
        id = "idlewood_plaza",
        name = "Idlewood İş Merkezi & Plaza",
        description = "Fotoğraftaki 3 katlı plazanın zemin vitrinleri ve üst kat camlarının temizliği.",
        difficulty = "Orta",
        vehicleParking = { x = 1939.50, y = -1792.00, z = 13.39, radius = 6.0 },
        hasLift = true,
        lift = {
            model = 3095,
            startPos = { x = 1939.50, y = -1781.50, z = 14.00 },
            minZ = 13.80,
            maxZ = 26.50,
            speed = 0.12,
            rot = { x = 0, y = 0, z = 0 }
        },
        windows = {
            { id = 1, x = 1928.50, y = -1780.20, z = 14.50, rx = 0, ry = 0, rz = 0, floor = 1 },
            { id = 2, x = 1934.80, y = -1780.20, z = 14.50, rx = 0, ry = 0, rz = 0, floor = 1 },
            { id = 3, x = 1944.50, y = -1780.20, z = 14.50, rx = 0, ry = 0, rz = 0, floor = 1 },
            { id = 4, x = 1951.20, y = -1780.20, z = 14.50, rx = 0, ry = 0, rz = 0, floor = 1 },
            { id = 5, x = 1928.50, y = -1780.20, z = 19.80, rx = 0, ry = 0, rz = 0, floor = 2 },
            { id = 6, x = 1935.50, y = -1780.20, z = 19.80, rx = 0, ry = 0, rz = 0, floor = 2 },
            { id = 7, x = 1943.50, y = -1780.20, z = 19.80, rx = 0, ry = 0, rz = 0, floor = 2 },
            { id = 8, x = 1950.50, y = -1780.20, z = 19.80, rx = 0, ry = 0, rz = 0, floor = 2 },
            { id = 9, x = 1928.50, y = -1780.20, z = 25.40, rx = 0, ry = 0, rz = 0, floor = 3 },
            { id = 10, x = 1935.50, y = -1780.20, z = 25.40, rx = 0, ry = 0, rz = 0, floor = 3 },
            { id = 11, x = 1943.50, y = -1780.20, z = 25.40, rx = 0, ry = 0, rz = 0, floor = 3 },
            { id = 12, x = 1950.50, y = -1780.20, z = 25.40, rx = 0, ry = 0, rz = 0, floor = 3 }
        }
    },
    {
        id = "downtown_tower",
        name = "Los Santos Finans Merkezi",
        description = "Gökdelenin dış cephe pencereleri yüksek irtifada temizlik gerektirir.",
        difficulty = "Zor",
        vehicleParking = { x = 1544.12, y = -1675.32, z = 13.56, radius = 5.0 },
        hasLift = true,
        lift = {
            model = 3095,
            startPos = { x = 1538.50, y = -1668.00, z = 14.50 },
            minZ = 14.50,
            maxZ = 75.00,
            speed = 0.12,
            rot = { x = 0, y = 0, z = 90 }
        },
        windows = {
            { id = 1, x = 1538.50, y = -1666.50, z = 16.50, rx = 0, ry = 0, rz = 90, floor = 1 },
            { id = 2, x = 1538.50, y = -1669.50, z = 16.50, rx = 0, ry = 0, rz = 90, floor = 1 },
            { id = 3, x = 1538.50, y = -1666.50, z = 28.50, rx = 0, ry = 0, rz = 90, floor = 2 },
            { id = 4, x = 1538.50, y = -1669.50, z = 28.50, rx = 0, ry = 0, rz = 90, floor = 2 },
            { id = 5, x = 1538.50, y = -1666.50, z = 42.50, rx = 0, ry = 0, rz = 90, floor = 3 },
            { id = 6, x = 1538.50, y = -1669.50, z = 42.50, rx = 0, ry = 0, rz = 90, floor = 3 },
            { id = 7, x = 1538.50, y = -1666.50, z = 58.50, rx = 0, ry = 0, rz = 90, floor = 4 },
            { id = 8, x = 1538.50, y = -1669.50, z = 58.50, rx = 0, ry = 0, rz = 90, floor = 4 }
        }
    },
    {
        id = "market_station",
        name = "Market İş Merkezi",
        description = "İşlek caddede bulunan cam kaplamalı binanın rutin temizlik görevi.",
        difficulty = "Kolay",
        vehicleParking = { x = 824.15, y = -1356.40, z = 13.50, radius = 5.0 },
        hasLift = false,
        windows = {
            { id = 1, x = 818.20, y = -1348.60, z = 14.10, rx = 0, ry = 0, rz = 0, floor = 1 },
            { id = 2, x = 822.20, y = -1348.60, z = 14.10, rx = 0, ry = 0, rz = 0, floor = 1 },
            { id = 3, x = 826.20, y = -1348.60, z = 14.10, rx = 0, ry = 0, rz = 0, floor = 1 },
            { id = 4, x = 830.20, y = -1348.60, z = 14.10, rx = 0, ry = 0, rz = 0, floor = 1 }
        }
    }
}