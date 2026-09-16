Config = {}
Config.ServerName = "GZL Roleplay"
Config.Currency = "$"
Config.OpenKey = "F1"
Config.Command = "telefon"
-- Optional compatible YouTube search proxy owned/configured by this server.
-- The old Cylex proxy requires credentials that are not included in this resource.
Config.MusicSearchProxy = ""
Config.PhoneVerifiedPrice = 10000
Config.SwiperGoldPrice = 1000
Config.PhoneSubscriptionDays = 30

Config.ItemRequired = false
Config.PhoneItem = "phone"

Config.DiscordWebhook = "" -- Discord Webhook URL'nizi buraya girin (örn: "https://discord.com/api/webhooks/...")

Config.AirdropDistance = 5.0
Config.MaxRecipients = 10
Config.MailLimit = 100
Config.MailFormat = "@gzl.com"
Config.MailStackingTime = 24

Config.SyncedFlashlight = true
Config.SyncedSounds = true
Config.SyncedSoundDistance = 10

Config.MoneyRequestCooldown = 5000
Config.TransferCooldown = 5000
Config.DarkGroupInviteCodeLength = 8
Config.DarkMessageLimit = 50
Config.MessageLimit = 50

Config.TwitterResetTimer = 30
Config.TweetLimit = 30
Config.TwitterRanks = {
    ["default"] = { label = "", icon = "", iconColor = "#fff", admin = false },
    ["verified"] = { label = "Onaylı", icon = "fas fa-badge-check", iconColor = "#38bdf8", admin = false },
    ["admin"] = { label = "Yönetici", icon = "fas fa-shield-alt", iconColor = "#f43f5e", admin = true }
}

Config.AdsLimit = 30
Config.ContactCallsLimit = 20
Config.CallsLimit = 30

Config.JobContacts = {
    ["police"] = {
        name = "Polis Departmanı (LSPD)",
        number = "911",
        photo = "./media/icons/police.png",
        preAdded = true,
        callable = true,
        attachments = false
    },
    ["ambulance"] = {
        name = "Acil Tıp Merkezi (EMS)",
        number = "112",
        photo = "./media/icons/ambulance.png",
        preAdded = true,
        callable = true,
        attachments = false
    },
    ["mechanic"] = {
        name = "Los Santos Customs (Mekanik)",
        number = "333",
        photo = "./media/icons/wrench.png",
        preAdded = true,
        callable = true,
        attachments = false
    },
    ["taxi"] = {
        name = "Downtown Cab Co. (Taksi)",
        number = "444",
        photo = "./media/icons/taxicar.png",
        preAdded = true,
        callable = true,
        attachments = false
    }
}

Config.AdsCategories = {
    [1] = {
        label = "Bireysel",
        job = "default",
        jobGrade = 0,
        color = "",
        info = { title = "Tüm İlanlar", description = "Genel ve bireysel tüm ilanlar" },
        allowPosting = true
    },
    [2] = {
        label = "Polis",
        job = {"police", "lspd"},
        jobGrade = 0,
        icon = "media/icons/policecar.png",
        color = "#0494c3",
        info = { title = "LSPD Duyuruları", description = "Resmi emniyet duyuruları ve uyarılar" }
    },
    [3] = {
        label = "EMS",
        job = {"ambulance", "ems"},
        jobGrade = 0,
        icon = "media/icons/emscar.png",
        color = "#d92323",
        info = { title = "EMS Duyuruları", description = "Sağlık ve ilk yardım duyuruları" }
    },
    [4] = {
        label = "Taksi",
        job = "taxi",
        jobGrade = 0,
        icon = "media/icons/taxicar.png",
        color = "#eba313",
        info = { title = "Taksi Hizmetleri", description = "Ulaşım ve taksi çağrıları" }
    },
    [5] = {
        label = "Mekanik",
        job = {"mechanic", "lsc"},
        jobGrade = 0,
        icon = "media/icons/servicecar.png",
        color = "#525252",
        info = { title = "Tamir & Modifiye", description = "Araç tamir, çekici ve modifiye servisleri" }
    }
}
