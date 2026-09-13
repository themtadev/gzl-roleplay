Config = {}

Config.Debug = false
Config.DefaultShoeDecks = 6
Config.ReshuffleThreshold = 52
Config.BettingDuration = 15
Config.InsuranceDuration = 7
Config.TurnDuration = 15
Config.ResultDuration = 6
Config.DealingCardDelay = 600

Config.Rules = {
    blackjackPayout = 1.5,
    regularPayout = 1.0,
    insurancePayout = 2.0,
    dealerStandOnSoft17 = true,
    allowDoubleDown = true,
    allowSplit = true,
    allowInsurance = true,
    allowSurrender = true,
    maxSplitHands = 2
}

Config.ChipValues = { 10, 50, 100, 500, 1000, 5000 }

Config.SeatOffsets = {
    [1] = { x = 0.96,  y = -0.68, z = 0.65, rot = 330, name = "Koltuk 1 (Sağ Dış)" },
    [2] = { x = 0.36,  y = -0.84, z = 0.65, rot = 350, name = "Koltuk 2 (Sağ İç)" },
    [3] = { x = -0.36, y = -0.84, z = 0.65, rot = 10,  name = "Koltuk 3 (Sol İç)" },
    [4] = { x = -0.96, y = -0.68, z = 0.65, rot = 30,  name = "Koltuk 4 (Sol Dış)" },
}

Config.DealerOffset = {
    x = 0.0, y = 0.90, z = 0.0, rot = 180
}

Config.CardOffsets = {
    dealer = { x = 0.0, y = 0.28, z = 0.948, rot = 180 },
    seats = {
        [1] = { x = 0.46,  y = -0.02, z = 0.948, rot = 325 },
        [2] = { x = 0.16,  y = -0.10, z = 0.948, rot = 345 },
        [3] = { x = -0.16, y = -0.10, z = 0.948, rot = 15 },
        [4] = { x = -0.46, y = -0.02, z = 0.948, rot = 35 },
    }
}

Config.CameraOffsets = {
    seats = {
        [1] = { camX = 0.82,  camY = -0.68, camZ = 1.38, targetX = 0.18,  targetY = 0.12, targetZ = 0.94, fov = 68 },
        [2] = { camX = 0.30,  camY = -0.84, camZ = 1.38, targetX = 0.06,  targetY = 0.12, targetZ = 0.94, fov = 68 },
        [3] = { camX = -0.30, camY = -0.84, camZ = 1.38, targetX = -0.06, targetY = 0.12, targetZ = 0.94, fov = 68 },
        [4] = { camX = -0.82, camY = -0.68, camZ = 1.38, targetX = -0.18, targetY = 0.12, targetZ = 0.94, fov = 68 },
    },
    default = {
        camX = 0.0, camY = -0.84, camZ = 1.38,
        targetX = 0.0, targetY = 0.12, targetZ = 0.94,
        fov = 68
    }
}

Config.DefaultTables = {
    {
        id = "blackjack_table_main",
        name = "Diamond Blackjack Masası",
        pos = { x = 2049.41, y = 1029.74, z = 16.80 },
        rot = 274.68,
        interior = 0,
        dimension = 0,
        minBet = 10,
        maxBet = 5000,
        dealerGender = "male",
        dealerName = "Kurpiyer Jack"
    }
}

Config.Models = {
    tableBaseID = 2187,
    dealerBaseID = 171,
    femaleDealerBaseID = 172
}