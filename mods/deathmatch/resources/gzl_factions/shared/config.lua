FactionConfig = {}

FactionConfig.DatabasePath = ":/database.db"

FactionConfig.DefaultFactions = {
    [1] = {
        id = 1,
        name = "Los Santos Police Department",
        short_name = "LSPD",
        faction_type = "police",
        vault_balance = 250000,
        max_members = 50,
        color = { 56, 189, 248 }, -- #38bdf8
        ranks = {
            [1] = { name = "Stajyer Memur (Cadet)", salary = 1200 },
            [2] = { name = "Memur I (Officer I)", salary = 1800 },
            [3] = { name = "Memur II (Officer II)", salary = 2400 },
            [4] = { name = "Kıdemli Memur (Senior Officer)", salary = 3000 },
            [5] = { name = "Çavuş (Sergeant)", salary = 3800 },
            [6] = { name = "Teğmen (Lieutenant)", salary = 4600 },
            [7] = { name = "Kaptan (Captain)", salary = 5500 },
            [8] = { name = "Emniyet Müdürü (Chief of Police)", salary = 7000 }
        }
    },
    [2] = {
        id = 2,
        name = "Los Santos Medical Services",
        short_name = "EMS",
        faction_type = "ems",
        vault_balance = 200000,
        max_members = 40,
        color = { 239, 68, 68 }, -- #ef4444
        ranks = {
            [1] = { name = "Stajyer Paramedik", salary = 1100 },
            [2] = { name = "Paramedik", salary = 1700 },
            [3] = { name = "Kıdemli Paramedik", salary = 2300 },
            [4] = { name = "Doktor", salary = 3200 },
            [5] = { name = "Uzman Cerrah", salary = 4200 },
            [6] = { name = "Başhekim", salary = 6000 }
        }
    },
    [3] = {
        id = 3,
        name = "San Andreas Government",
        short_name = "GOV",
        faction_type = "gov",
        vault_balance = 1000000,
        max_members = 30,
        color = { 245, 158, 11 }, -- #f59e0b
        ranks = {
            [1] = { name = "Stajyer Memur", salary = 1000 },
            [2] = { name = "Halkla İlişkiler Sorumlusu", salary = 1800 },
            [3] = { name = "Müsteşar", salary = 3000 },
            [4] = { name = "Belediye Başkanı", salary = 5000 },
            [5] = { name = "Vali", salary = 8000 }
        }
    }
}

FactionConfig.MinVaultWithdrawRank = 4
FactionConfig.MinInviteRank = 4
FactionConfig.MinKickRank = 5
FactionConfig.MinSetRankRank = 5

FactionConfig.PanelKey = "F6"
FactionConfig.CommandAliases = { "fpanel", "faction", "birlik" }

FactionConfig.TypeThemes = {
    police = {
        title = "Kolluk Kuvvetleri",
        dept = "Los Santos Polis Teşkilatı",
        color = { 56, 189, 248 }, -- #38bdf8
        hex = "#38bdf8",
        icon = "badge",
        channel = "155.0",
        channelName = "LSPD Taktik Ana Frekansı (155.0 MHz)",
        encryption = "MIL-SPEC Şifreli Telsiz Ağı",
        emergencyFreq = "911.0"
    },
    ems = {
        title = "Acil Tıp & Sağlık Servisi",
        dept = "Los Santos Medikal Servisleri",
        color = { 239, 68, 68 }, -- #ef4444
        hex = "#ef4444",
        icon = "heart",
        channel = "112.0",
        channelName = "EMS Acil Müdahale Frekansı (112.0 MHz)",
        encryption = "Tıbbi Triyaj Şifreli Frekansı",
        emergencyFreq = "911.0"
    },
    gov = {
        title = "Devlet & Hükümet İdaresi",
        dept = "San Andreas Eyalet Yönetimi",
        color = { 245, 158, 11 }, -- #f59e0b
        hex = "#f59e0b",
        icon = "shield",
        channel = "100.0",
        channelName = "Eyalet Protokol Frekansı (100.0 MHz)",
        encryption = "Hükümet Kriptolu İletişim Protokolü",
        emergencyFreq = "911.0"
    },
    gang = {
        title = "Suç & Sokak Örgütü",
        dept = "Sokak Yapılanması",
        color = { 168, 85, 247 }, -- #a855f7
        hex = "#a855f7",
        icon = "cube",
        channel = nil,
        channelName = "Özel Kapalı Telsiz Kanalı",
        encryption = "Analog Karasal Yayın",
        emergencyFreq = nil
    },
    mafia = {
        title = "Yeraltı Teşkilatı",
        dept = "Özel Sendika & Aile",
        color = { 236, 72, 153 }, -- #ec4899
        hex = "#ec4899",
        icon = "shield",
        channel = nil,
        channelName = "Kriptolu Özel Kanal",
        encryption = "Gizli Frekans Atlama",
        emergencyFreq = nil
    },
    default = {
        title = "Özel Teşkilat / Birlik",
        dept = "Birlik Birimi",
        color = { 45, 212, 191 }, -- #2dd4bf
        hex = "#2dd4bf",
        icon = "shield",
        channel = nil,
        channelName = "Operasyonel Telsiz Kanalı",
        encryption = "Dahili Telsiz Ağı",
        emergencyFreq = nil
    }
}

function FactionConfig.getTypeTheme(fType)
    fType = string.lower(tostring(fType or "default"))
    return FactionConfig.TypeThemes[fType] or FactionConfig.TypeThemes.default
end

local function getMaxRank(factionId)
    local fId = tonumber(factionId)
    local f = (Factions and Factions[fId]) or (FactionConfig.DefaultFactions and FactionConfig.DefaultFactions[fId])
    if not f or not f.ranks then return 5 end
    local maxR = 0
    for rId in pairs(f.ranks) do
        local n = tonumber(rId)
        if n and n > maxR then maxR = n end
    end
    return (maxR > 0) and maxR or 5
end
FactionConfig.getMaxRank = getMaxRank

function FactionConfig.canManageMembers(factionId, rankId)
    local rId = tonumber(rankId) or 0
    local maxR = getMaxRank(factionId)
    if rId >= maxR then return true end
    if maxR <= 5 then
        return rId >= 4
    end
    return rId >= (FactionConfig.MinKickRank or 5)
end

function FactionConfig.canInviteMembers(factionId, rankId)
    local rId = tonumber(rankId) or 0
    local maxR = getMaxRank(factionId)
    if rId >= maxR then return true end
    if maxR <= 5 then
        return rId >= 3
    end
    return rId >= (FactionConfig.MinInviteRank or 4)
end

function FactionConfig.canWithdrawVault(factionId, rankId)
    local rId = tonumber(rankId) or 0
    local maxR = getMaxRank(factionId)
    if rId >= maxR then return true end
    if maxR <= 5 then
        return rId >= 4
    end
    return rId >= (FactionConfig.MinVaultWithdrawRank or 4)
end
