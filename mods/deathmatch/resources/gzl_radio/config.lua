RadioConfig = {
    ItemName = "radio",
    DefaultVolume = 50,
    MinimumFrequency = 0.1,
    MaximumFrequency = 999.9,
    MaximumPasswordLength = 32,
    ItemCheckInterval = 5000,
    RequestCooldown = 150,
    RestrictedChannels = {
        ["155.0"] = { police = true, lspd = true, bcso = true, ["1"] = true },
        ["112.0"] = { ambulance = true, ems = true, ["2"] = true },
        ["100.0"] = { gov = true, government = true, ["3"] = true },
        ["911.0"] = { police = true, lspd = true, bcso = true, ambulance = true, ems = true, ["1"] = true, ["2"] = true },
        ["1.0"] = { police = true, lspd = true, bcso = true, ["1"] = true },
        ["2.0"] = { police = true, lspd = true, bcso = true, ambulance = true, ems = true, ["1"] = true, ["2"] = true },
        ["3.0"] = { ambulance = true, ems = true, ["2"] = true },
        ["4.0"] = { police = true, lspd = true, bcso = true, ["1"] = true },
        ["5.0"] = { police = true, lspd = true, bcso = true, ["1"] = true }
    }
}