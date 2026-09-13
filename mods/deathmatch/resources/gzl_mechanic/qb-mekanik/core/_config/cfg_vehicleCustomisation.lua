
maxVehiclePerformanceUpgrades = 3

vehicleBaseRepairCost = 40
vehicleRepairCostMultiplier = 1

NPCx = 3.0
DefaultVehiclePrice = 5000
npcMechanic = false

vehiclePrice = 0
function calcPrice(price, npcMechanicData, vehiclePriceData, currency)

        return 0

end

function format_int(number)
    local i, j, minus, int, fraction = tostring(number):find('([-]?)(%d+)([.]?%d*)')
    int = int:reverse():gsub("(%d%d%d)", "%1,")
    return minus .. int:reverse():gsub("^,", "") .. fraction
end

Locations = {
    {
        ['mechanic'] = 'mekanik1',
        ["coords"] = {x = -620.3824, y= -1643.7532, z = 25.8250, h = 133.3493, r = 1.0},
    },
    {
        ['mechanic'] = 'mekanik1',
        ["coords"] = {x = -1895.6365, y= 205.9189, z = 84.2290, h = 273.84, r = 1.0},
    },
    {
        ['mechanic'] = 'mekanik2',
        ["coords"] = {x = 753.9327, y=  124.8933, z = 78.5780, h = 273.84, r = 1.0},
    },
    {
        ['mechanic'] = 'police',
        ["coords"] = {x = 461.6485, y=  -1018.9556, z = 28.0901, h = 322.3004, r = 1.0},
    },
    {
        ['mechanic'] = 'mekanik4',
        ["coords"] = {x = -838.4617, y=  159.9533, z = 67.5309, h = 322.3004, r = 1.0},
    },
    {
        ['mechanic'] = 'mekanik5',
        ["coords"] = {x = -1565.6274, y = -237.1812, z = 49.4779, h = 325.1413, r = 1.0},
    },
    {
        ['mechanic'] = 'mekanik6',
        ["coords"] = {x = -332.8023, y=  -137.3220, z = 39.0096, h = 273.84, r = 1.0},
    },
    {
        ['mechanic'] = 'mekanik6',
        ["coords"] = {x = 730.6498, y=  -1089.0505, z = 22.1690, h = 260.8629, r = 1.0},
    },
    {
        ['mechanic'] = 'mekanik7',
        ["coords"] = {x = -462.2982, y=  193.8164, z = 75.2398, h = 173.4725, r = 1.0},
    },
    {
        ['mechanic'] = 'mekanik8',
        ["coords"] = {x = -1897.6395, y=  -331.5761, z = 49.2364, h = 233.2961, r = 1.0},
    },
    {
        ['mechanic'] = 'mekanik9',
        ["coords"] = {x = 977.5084, y=  -2253.4126, z = 30.5769, h = 172.3968, r = 1.0},
    },
    {
        ['mechanic'] = 'mekanik10',
        ["coords"] = {x = -1537.4042, y=  -85.5817, z =  54.1283, h = 178.7242, r = 1.0},
    },
}

addonCarPrice = {

    ["n2futo"] = 0,
    ["blis2gpr"] = 0,
    ["z32"] = 0,
    ["jackgpr"] = 0,
    ["oraclestd"] = 0,
    ["crowdrunner"] = 0,
    ["vamos"] = 0,
    ["ruiner6str"] = 0,
    ["comet3"] = 0,
    ["fugitive3"] = 0,
    ["gtr"] = 0,
    ["jester3"] = 0,
    ["schwarzer2"] = 0,
    ["verlierergt"] = 0,
    ["ziongtc"] = 0,
    ["r255"] = 0,
    ["sentigpr"] = 0,
    ["kanjo"] = 0,
    ["club"] = 0,
    ["blistata"] = 0,
    ["buffalot"] = 0,
    ["hustler"] = 0,
    ["gauntlet6str"] = 0,
    ["slamvan3"] = 0,
    ["er34"] = 0,
    ["gb200"] = 0,
    ["rh82"] = 0,
    ["sentinel6str2"] = 0,
    ["sultanrsv8"] = 0,
    ["nebula"] = 0,
    ["tornado7"] = 0,

    ["glendale2"] = 0,
    ["sanctus"] = 0,
    ["yosemite3"] = 0,
    ["veto2"] = 0,

}

vehicleCustomisationPrices =
{
    repair = {price = 0},
    cosmetics = {
        price = 0.02
    },
    boya = {
        price = 0.005
    },
    performance =
    {
        prices =
        {
            0,
            0.03,
            0.04,
            0.05,
            0.06,
            0.07
        }
    },
    turbo =
    {
        price = 0.0
    },
    wheels =
    {
        price = 0.0
    },
    customwheels =
    {
        price = 0.0
    },
    jantlarmoke =
    {
        price = 0.0
    },
    camfilmi =
    {
        price = 0.0
    },
    neonlarside =
    {
        price = 0.0
    },
    neonrengi =
    {
        price = 0.0
    },
    xenon =
    {
        price = 0.0
    },
    xenonrengi =
    {
        price = 0.0
    },
    kaplamalar =
    {
        price = 0.0
    }
}
vehicleCustomisation =
{
    {
        category = "Kanatlar",
        id = 0
    },
    {
        category = "Ön Tampon",
        id = 1
    },
    {
        category = "Arka Tampon",
        id = 2
    },
    {
        category = "Yan Etekler",
        id = 3
    },
    {
        category = "Egsoz",
        id = 4
    },
    {
        category = "Kafes",
        id = 5
    },
    {
        category = "Izgara",
        id = 6
    },
    {
        category = "Ön Kaput",
        id = 7
    },
    {
        category = "Sol Çamurluk",
        id = 8
    },
    {
        category = "Sağ Çamurluk",
        id = 9
    },
    {
        category = "Çatı",
        id = 10
    },
    {
        category = "Vanity Plates",
        id = 25
    },
    {
        category = "Trim A",
        id = 27
    },
    {
        category = "Peluş Oyuncak",
        id = 28
    },
    {
        category = "Gösterge Paneli",
        id = 29
    },
    {
        category = "Göstergeler",
        id = 30
    },
    {
        category = "Kapı Hoparlörleri",
        id = 31
    },
    {
        category = "Koltuklar",
        id = 32
    },
    {
        category = "Direksiyon",
        id = 33
    },
    {
        category = "Vites Kolu",
        id = 34
    },
    {
        category = "Plaka",
        id = 35
    },
    {
        category = "Hoparlörler",
        id = 36
    },
    {
        category = "Bagaj",
        id = 37
    },
    {
        category = "Hidrolik",
        id = 38
    },
    {
        category = "Motor bloğu",
        id = 39
    },
    {
        category = "Hava Filtresi",
        id = 40
    },
    {
        category = "Motor Bloğu Desteği",
        id = 41
    },
    {
        category = "Far Kaplaması",
        id = 42
    },
    {
        category = "Off Road Far",
        id = 43
    },
    {
        category = "Trim B",
        id = 44
    },
    {
        category = "Yakıt Tankı",
        id = 45
    },
    {
        category = "Camlar",
        id = 46
    },
    {
        category = "Kaplamalar",
        id = 48
    },
    {
        category = "Kornalar",
        id = 14,
        hornNames =
        {
            {name = "Tır Kornası", id = 0},
            {name = "Polis Kornası", id = 1},
            {name = "Palyaço Kornası", id = 2},
            {name = "Müzikal Korna 1", id = 3},
            {name = "Müzikal Korna 2", id = 4},
            {name = "Müzikal Korna 3", id = 5},
            {name = "Müzikal Korna 4", id = 6},
            {name = "Müzikal Korna 5", id = 7},
            {name = "Üzgün ​​Trombon", id = 8},
            {name = "Klasik Korna 1", id = 9},
            {name = "Klasik Korna 2", id = 10},
            {name = "Klasik Korna 3", id = 11},
            {name = "Klasik Korna 4", id = 12},
            {name = "Klasik Korna 5", id = 13},
            {name = "Klasik Korna 6", id = 14},
            {name = "Klasik Korna 7", id = 15},
            {name = "skala - Do", id = 16},
            {name = "skala - Re", id = 17},
            {name = "skala - Mi", id = 18},
            {name = "skala - Fa", id = 19},
            {name = "skala - Sol", id = 20},
            {name = "skala - La", id = 21},
            {name = "skala - Ti", id = 22},
            {name = "skala - Do", id = 23},
            {name = "Caz Korna 1", id = 24},
            {name = "Caz Korna 2", id = 25},
            {name = "Caz Korna 3", id = 26},
            {name = "Caz Korna [Döngü]", id = 27},
            {name = "Star Spangled Banner 1", id = 28},
            {name = "Star Spangled Banner 2", id = 29},
            {name = "Star Spangled Banner 3", id = 30},
            {name = "Star Spangled Banner 4", id = 31},
            {name = "Classical Horn 8 Loop", id = 32},
            {name = "Classical Horn 9 Loop", id = 33},
            {name = "Classical Horn 10 Loop", id = 34},
            {name = "Classical Horn 8", id = 35},
            {name = "Classical Horn 9", id = 36},
            {name = "Classical Horn 10", id = 37},
            {name = "Cenaze [Döngü]", id = 38},
            {name = "Cenaze", id = 39},
            {name = "Ürpertici [Döngü]", id = 40},
            {name = "Ürpertici", id = 41},
            {name = "San Andreas [Döngü]", id = 42},
            {name = "San Andreas", id = 43},
            {name = "Liberty City [Döngü]", id = 44},
            {name = "Liberty City", id = 45},
            {name = "Festival 1 [Döngü]", id = 46},
            {name = "Festival 1", id = 47},
            {name = "Festival 2 [Döngü]", id = 48},
            {name = "Festival 2", id = 49},
            {name = "Festival 3 [Döngü]", id = 50},
            {name = "Festival 3", id = 51}
        }
    },
    {
        category = "Motor Geliştirmesi",
        id = 11
    },
    {
        category = "Fren Geliştirmesi",
        id = 12
    },
    {
        category = "Vites Kutusu Geliştirmesi",
        id = 13
    },
    {
        category = "Süspansiyon Geliştirmesi",
        id = 15
    },
    {
        category = "Zırh Geliştirmesi",
        id = 16
    },
    {
        category = "Turbo Geliştirmesi",
        id = 18
    }
}

vehicleCamFilmiOptions =
{
    {
        name = "Cam Filmini Sök",
        id = 0
    },
    {
        name = "Koyu",
        id = 1
    },
    {
        name = "Normal",
        id = 2
    },
    {
        name = "Açık",
        id = 3
    }
}

vehicleWheelOptions =
{
    {
        category = "Özel Lastik",
        id = -1,
        wheelID = 23
    },
    {
        category = "Lastik Dumanı",
        id = 20,
        wheelID = 23
    },
    {
        category = "Spor",
        id = 0,
        wheelID = 23
    },
    {
        category = "Muscle",
        id = 1,
        wheelID = 23
    },
    {
        category = "Lowrider",
        id = 2,
        wheelID = 23
    },
    {
        category = "SUV",
        id = 3,
        wheelID = 23
    },
    {
        category = "Offroad",
        id = 4,
        wheelID = 23
    },
    {
        category = "Tuner",
        id = 5,
        wheelID = 23
    },
    {
        category = "Motor",
        id = 6,
        wheelID = 23
    },
    {
        category = "Kaliteli",
        id = 7,
        wheelID = 23
    }
}

vehicleTyreSmokeOptions =
{
    {name = "Beyaz Duman", r = 254, g = 254, b = 254},
    {name = "Siyah Duman", r = 1, g = 1, b = 1},
    {name = "Mavi Duman", r = 0, g = 150, b = 255},
    {name = "Sarı Duman", r = 255, g = 255, b = 50},
    {name = "Turuncu Duman", r = 255, g = 153, b = 51},
    {name = "Kırmızı Duman", r = 255, g = 10, b = 10},
    {name = "Yeşil Duman", r = 10, g = 255, b = 10},
    {name = "Mor Duman", r = 153, g = 10, b = 153},
    {name = "Pempe Duman", r = 255, g = 102, b = 178},
    {name = "Gri Duman", r = 128, g = 128, b = 128}
}

vehicleBoyaCategories =
{
    {
        category = "Ana Renk",
        id = 0
    },
    {
        category = "İkincil Renk",
        id = 1
    },
    {
        category = "Sedef",
        id = 2
    },
    {
        category = "Jant Rengi",
        id = 3
    },
    {
        category = "Gösterge Rengi",
        id = 4
    },
    {
        category = "İç Döşeme Rengi",
        id = 5
    }
}

vehicleBoyaOptions =
{

    {
        category = "Metalik",
        id = 1,
        colours =
        {
            {name = "Black", id = 0},
            {name = "Carbon Black", id = 147},
            {name = "Graphite", id = 1},
            {name = "Anhracite Black", id = 11},
            {name = "Black Steel", id = 11},
            {name = "Dark Steel", id = 3},
            {name = "Silver", id = 4},
            {name = "Bluish Silver", id = 5},
            {name = "Rolled Steel", id = 6},
            {name = "Shadow Silver", id = 7},
            {name = "Stone Silver", id = 8},
            {name = "Midnight Silver", id = 9},
            {name = "Cast Iron Silver", id = 10},
            {name = "Kırmızı", id = 27},
            {name = "Torino Kırmızı", id = 28},
            {name = "Formula Kırmızı", id = 29},
            {name = "Lava Kırmızı", id = 150},
            {name = "Blaze Kırmızı", id = 30},
            {name = "Grace Kırmızı", id = 31},
            {name = "Garnet Kırmızı", id = 32},
            {name = "Sunset Kırmızı", id = 33},
            {name = "Cabernet Kırmızı", id = 34},
            {name = "Wine Kırmızı", id = 143},
            {name = "Candy Kırmızı", id = 35},
            {name = "Hot Pempe", id = 135},
            {name = "Pfsiter Pempe", id = 137},
            {name = "Salmon Pempe", id = 136},
            {name = "Sunrise Turuncu", id = 36},
            {name = "Turuncu", id = 38},
            {name = "Bright Turuncu", id = 138},
            {name = "Gold", id = 99},
            {name = "Bronze", id = 90},
            {name = "Sarı", id = 88},
            {name = "Race Sarı", id = 89},
            {name = "Dew Sarı", id = 91},
            {name = "Dark Yeşil", id = 49},
            {name = "Racing Yeşil", id = 50},
            {name = "Sea Yeşil", id = 51},
            {name = "Olive Yeşil", id = 52},
            {name = "Bright Yeşil", id = 53},
            {name = "Gasoline Yeşil", id = 54},
            {name = "Lime Yeşil", id = 92},
            {name = "Midnight Mavi", id = 141},
            {name = "Galaxy Mavi", id = 61},
            {name = "Dark Mavi", id = 62},
            {name = "Saxon Mavi", id = 63},
            {name = "Mavi", id = 64},
            {name = "Mariner Mavi", id = 65},
            {name = "Harbor Mavi", id = 66},
            {name = "Diamond Mavi", id = 67},
            {name = "Surf Mavi", id = 68},
            {name = "Nautical Mavi", id = 69},
            {name = "Racing Mavi", id = 73},
            {name = "Ultra Mavi", id = 70},
            {name = "Light Mavi", id = 74},
            {name = "Chocolate Brown", id = 96},
            {name = "Bison Brown", id = 101},
            {name = "Creeen Brown", id = 95},
            {name = "Feltzer Brown", id = 94},
            {name = "Maple Brown", id = 97},
            {name = "Beechwood Brown", id = 103},
            {name = "Sienna Brown", id = 104},
            {name = "Saddle Brown", id = 98},
            {name = "Moss Brown", id = 100},
            {name = "Woodbeech Brown", id = 102},
            {name = "Straw Brown", id = 99},
            {name = "Sandy Brown", id = 105},
            {name = "Bleached Brown", id = 106},
            {name = "Schafter Mor", id = 71},
            {name = "Spinnaker Mor", id = 72},
            {name = "Midnight Mor", id = 142},
            {name = "Bright Mor", id = 145},
            {name = "Cream", id = 107},
            {name = "Ice Beyaz", id = 111},
            {name = "Frost Beyaz", id = 112}
        }
    },
    {
        category = "Mat",
        id = 2,
        colours =
        {
            {name = "Black", id = 12},
            {name = "Gray", id = 13},
            {name = "Light Gray", id = 14},
            {name = "Ice Beyaz", id = 131},
            {name = "Mavi", id = 83},
            {name = "Dark Mavi", id = 82},
            {name = "Midnight Mavi", id = 84},
            {name = "Midnight Mor", id = 149},
            {name = "Schafter Mor", id = 148},
            {name = "Kırmızı", id = 39},
            {name = "Dark Kırmızı", id = 40},
            {name = "Turuncu", id = 41},
            {name = "Sarı", id = 42},
            {name = "Lime Yeşil", id = 55},
            {name = "Yeşil", id = 128},
            {name = "Forest Yeşil", id = 151},
            {name = "Foliage Yeşil", id = 155},
            {name = "Olive Darb", id = 152},
            {name = "Dark Earth", id = 153},
            {name = "Desert Tan", id = 154}
        }
    },
    {
        category = "Metal",
        id = 3,
        colours =
        {
            {name = "Brushed Steel", id = 117},
            {name = "Brushed Black Steel", id = 118},
            {name = "Brushed Aluminium", id = 119},
            {name = "Pure Gold", id = 158},
            {name = "Brushed Gold", id = 159},
            {name = "Chrome", id = 120}
        }
    }
}

vehicleNeonOptions =
{
    category = "Neonlar",
    neonTypes =
    {
        {name = "Ön Neon", id = 2},
        {name = "Arka Neon", id = 3},
        {name = "Sol Neon", id = 0},
        {name = "Sağ Neon", id = 1}
    },
    neonColours =
    {
        {name = "Beyaz", r = 222, g = 222, b = 255},
        {name = "Mavi", r = 2, g = 21, b = 255},
        {name = "Electric Mavi", r = 3, g = 83, b = 255},
        {name = "Mint Yeşil", r = 0, g = 255, b = 140},
        {name = "Lime Yeşil", r = 94, g = 255, b = 1},
        {name = "Sarı", r = 255, g = 255, b = 0},
        {name = "Altın Shower", r = 255, g = 150, b = 0},
        {name = "Turuncu", r = 255, g = 62, b = 0},
        {name = "Kırmızı", r = 255, g = 1, b = 1},
        {name = "Pony Pempe", r = 255, g = 50, b = 100},
        {name = "Hot Pempe", r = 255, g = 5, b = 190},
        {name = "Mor", r = 35, g = 1, b = 255},
        {name = "Siyah Işık", r = 15, g = 3, b = 255}
    }
}

vehicleXenonOptions =
{
    xenonColours =
    {
        {name = "Stock", id = 255},
        {name = "Beyaz", id = 0},
        {name = "Mavi", id = 1},
        {name = "Electric Mavi", id = 2},
        {name = "Mint Yeşil", id = 3},
        {name = "Lime Yeşil", id = 4},
        {name = "Sarı", id = 5},
        {name = "Altın Shower", id = 6},
        {name = "Turuncu", id = 7},
        {name = "Kırmızı", id = 8},
        {name = "Pony Pempe", id = 9},
        {name = "Hot Pempe", id = 10},
        {name = "Mor", id = 11},
        {name = "Siyah Işık", id = 12}
    }
}