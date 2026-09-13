Config = {}

Config.MechanicName = "Benny's Original Motor Works"
Config.BlipID = 27
Config.WorkshopCenter = { x = 2279.7, y = -1999.6, z = 14.5 }

Config.Stations = {
    main = {
        name = "Benny's Original Motor Works",
        x = 2276.71,
        y = -1995.61,
        z = 13.50,
        radius = 4.2,
        type = "cylinder",
        color = { 245, 166, 35, 0 },
        allowTypes = { "Automobile", "Monster Truck", "Bike" }
    }
}

Config.LiftHeight = {
    down = 14.37,
    up = 16.85,
    duration = 3500
}

Config.BennyNPC = {
    model = 50,
    x = 2283.50,
    y = -2007.80,
    z = 19.66,
    rot = 135.0,
    name = "Benny (Atölye Sahibi)",
    subtext = "Benny's Original Motor Works"
}

Config.Prices = {
    repairEngine = 450,
    repairBody = 350,
    repairTires = 200,
    serviceOil = 150,
    fullOverhaul = 1000,
    paintPrimary = 500,
    paintSecondary = 350,
    headlights = 750,
    hydraulics = 2500,
    nitro10x = 1500,
    wheels = 1200,
    neon = 1800,
    suspension = 800,
    customPlate = 1000,
    upgrade = 850,
    removeUpgrade = 0,
}

Config.Wheels = {
    { id = 1073, name = "Shadow", price = 1200 },
    { id = 1074, name = "Mega", price = 1200 },
    { id = 1075, name = "Rimshine", price = 1250 },
    { id = 1076, name = "Wires (Lowrider)", price = 1500 },
    { id = 1077, name = "Classic", price = 1100 },
    { id = 1078, name = "Twist", price = 1300 },
    { id = 1079, name = "Cutter", price = 1350 },
    { id = 1080, name = "Switch", price = 1400 },
    { id = 1081, name = "Grove", price = 1200 },
    { id = 1082, name = "Import", price = 1450 },
    { id = 1083, name = "Dollar (Bling)", price = 1600 },
    { id = 1084, name = "Trance", price = 1400 },
    { id = 1085, name = "Atomic", price = 1500 },
    { id = 1096, name = "Ahab", price = 1250 },
    { id = 1097, name = "Virtual", price = 1300 },
    { id = 1098, name = "Access", price = 1350 },
    { id = 1025, name = "Offroad HD", price = 1550 },
}

Config.ColorPresets = {
    { name = "Buz Beyazı", r = 245, g = 245, b = 245 },
    { name = "Mat Gece Siyahı", r = 18, g = 18, b = 20 },
    { name = "Nardo Gri", r = 108, g = 112, b = 118 },
    { name = "Benny's Kırmızı", r = 190, g = 20, b = 20 },
    { name = "Gece Mavisi", r = 15, g = 45, b = 110 },
    { name = "Miami Turkuaz", r = 0, g = 200, b = 200 },
    { name = "Zümrüt Yeşil", r = 20, g = 140, b = 50 },
    { name = "Limon Sarı", r = 240, g = 200, b = 10 },
    { name = "Güneş Turuncu", r = 240, g = 100, b = 10 },
    { name = "Kraliyet Moru", r = 110, g = 20, b = 160 },
    { name = "Fuşya Pembe", r = 230, g = 40, b = 130 },
    { name = "Şampanya Altın", r = 210, g = 175, b = 110 }
}

Config.HeadlightColors = {
    { name = "Standart Halojen", r = 255, g = 255, b = 255 },
    { name = "Buz Mavisi (8000K)", r = 70, g = 160, b = 255 },
    { name = "Koyu Safir Mavi", r = 0, g = 60, b = 255 },
    { name = "Toksik Yeşil", r = 20, g = 255, b = 70 },
    { name = "Kan Kırmızısı", r = 255, g = 25, b = 25 },
    { name = "Neon Pembe", r = 255, g = 20, b = 180 },
    { name = "Amber Sarısı", r = 255, g = 180, b = 0 },
    { name = "Ultraviyole Mor", r = 170, g = 0, b = 255 },
    { name = "Turkuaz Cyan", r = 0, g = 255, b = 240 }
}

Config.NeonColors = {
    { name = "Yok / Kapat", r = 0, g = 0, b = 0, enabled = false },
    { name = "Buz Mavisi", r = 0, g = 150, b = 255, enabled = true },
    { name = "Neon Kırmızı", r = 255, g = 25, b = 25, enabled = true },
    { name = "Zümrüt Yeşili", r = 25, g = 255, b = 75, enabled = true },
    { name = "Elektrik Moru", r = 185, g = 25, b = 255, enabled = true },
    { name = "Sıcak Pembe", r = 255, g = 40, b = 160, enabled = true },
    { name = "Siber Sarı", r = 255, g = 220, b = 0, enabled = true },
    { name = "Saf Beyaz", r = 255, g = 255, b = 255, enabled = true },
    { name = "Aqua Turkuaz", r = 0, g = 255, b = 210, enabled = true }
}

Config.SuspensionLevels = {
    { name = "Fabrika Çıkışı (Standart)", offset = 0.0 },
    { name = "Spor Yay (-3 cm)", offset = -0.06 },
    { name = "Yarış & Pist (-6 cm)", offset = -0.12 },
    { name = "Dip Basık / Stance (-10 cm)", offset = -0.18 },
    { name = "Offroad Yükseltme (+5 cm)", offset = 0.10 }
}