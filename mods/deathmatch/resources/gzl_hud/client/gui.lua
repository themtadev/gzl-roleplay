local screenW, screenH = guiGetScreenSize()
local guiBrowserElem = nil
local hudBrowser = nil
local isBrowserReady = false
local isVisible = false
local isSettingsOpen = false
local isBrowserPaused = false
local backgroundRefreshPending = false
local isWindowMinimized = false

local function deferBackgroundUpdate()
    if isWindowMinimized or not isMTAWindowFocused() then
        backgroundRefreshPending = true
        return true
    end
    return false
end
local seatbeltState = false
local currentVoiceIndex = 2

local gtaHudComponents = {
    "all", "ammo", "armour", "breath", "clock", "health", "money", "weapon", "wanted", "area_name", "vehicle_name", "radar"
}

local lastStatus = {
    hp = -1,
    armour = -1,
    oxygen = -1,
    hunger = -1,
    thirst = -1,
    stress = -1,
    speed = -1,
    rpm = -1,
    fuel = -1,
    gear = -1,
    vehHealth = -1,
    lightsOn = nil,
    engineOn = nil,
    seatbelt = nil,
    heading = -1,
    inVeh = false
}
local lastSession = {
    time = "",
    money = -1,
    bank = -1,
    zone = "",
    job = ""
}
local lastVoice = {
    talking = nil,
    level = -1
}

local cachedPlayerStatus = {
    health = 100,
    armor = 0,
    hunger = 100,
    thirst = 100,
    stamina = 100,
    stress = 0,
    oxygen = 100,
    inVehicle = false,
    vehicleSeat = nil,
    seatbelt = false,
    lowBeam = false,
    highBeam = false,
    engineOn = false,
    speed = 0,
    rpm = 0,
    fuel = 85,
    mechanic = 100,
    engine = 100,
    nitro = 0,
    gear = 1,
    highGear = 6,
    maxSpeed = 260,
    steer = 0,
    heading = 0,
    vehicleHudContext = false
}

local statusMessageWrapper = {
    action = "UPDATE_PLAYER_STATUS",
    data = cachedPlayerStatus
}

local cachedSessionData = {
    time = "",
    date = "",
    dateAlt = "",
    streetLabel = "",
    playerId = 1,
    playerName = "",
    playerCount = 1,
    cash = 0,
    bank = 0,
    blackMoney = 0,
    jobLabel = "",
    jobGrade = "Rank 1"
}

local sessionMessageWrapper = {
    action = "UPDATE_HUD_SESSION",
    data = cachedSessionData
}

local cachedPlayerCount = #getElementsByType("player")
addEventHandler("onClientPlayerJoin", root, function()
    cachedPlayerCount = cachedPlayerCount + 1
end)
addEventHandler("onClientPlayerQuit", root, function()
    cachedPlayerCount = math.max(1, cachedPlayerCount - 1)
end)

local function sendNuiMessage(data)
    if not isBrowserReady or not hudBrowser or not isElement(hudBrowser) then return end
    local success, jsonStr = pcall(toJSON, data, true)
    if not success or not jsonStr then return end
    jsonStr = jsonStr:match("^%s*(.-)%s*$") or jsonStr
    if jsonStr:sub(1, 1) == "[" and jsonStr:sub(-1) == "]" then
        jsonStr = jsonStr:sub(2, -2):match("^%s*(.-)%s*$") or jsonStr:sub(2, -2)
    end
    executeBrowserJavascript(hudBrowser, string.format("if(window.sendNuiMessage){window.sendNuiMessage(%s);}else{window.postMessage(%s,'*');}", jsonStr, jsonStr))
end

local isBigmapOpen = false

local function isAnyMapActive()
    if isPlayerMapVisible() or isMainMenuActive() then return true end
    if isBigmapOpen then return true end
    if exports.gzl_radar and exports.gzl_radar.isPauseMenuOpen and exports.gzl_radar:isPauseMenuOpen() then return true end
    return false
end

local restoreResumeTimer = nil

local function updateBrowserPauseState()
    if deferBackgroundUpdate() then return end
    if isTimer(restoreResumeTimer) then return end
    if not isBrowserReady or not hudBrowser or not isElement(hudBrowser) then return end
    local shouldPause = (not isVisible) or isAnyMapActive()
    if isSettingsOpen then
        shouldPause = false
    end
    if shouldPause ~= isBrowserPaused then
        isBrowserPaused = shouldPause
        setBrowserRenderingPaused(hudBrowser, shouldPause)
    end
end

addEventHandler("onClientMinimize", root, function()
    isWindowMinimized = true
    backgroundRefreshPending = true
    if isTimer(restoreResumeTimer) then
        killTimer(restoreResumeTimer)
        restoreResumeTimer = nil
    end
    if hudBrowser and isElement(hudBrowser) then
        isBrowserPaused = true
        setBrowserRenderingPaused(hudBrowser, true)
    end
end)

addEventHandler("onClientRestore", root, function()
    screenW, screenH = guiGetScreenSize()
    isWindowMinimized = false
    backgroundRefreshPending = true
    if isTimer(restoreResumeTimer) then
        killTimer(restoreResumeTimer)
        restoreResumeTimer = nil
    end
    restoreResumeTimer = setTimer(function()
        restoreResumeTimer = nil
        if isWindowMinimized then return end
        if hudBrowser and isElement(hudBrowser) and isBrowserReady then
            local shouldPause = (not isVisible) or isAnyMapActive()
            if isSettingsOpen then
                shouldPause = false
            end
            isBrowserPaused = shouldPause
            setBrowserRenderingPaused(hudBrowser, shouldPause)
        end
    end, 500, 1)
end)

addEventHandler("onClientKey", root, function(button, press)
    if (button == "F11" or button == "escape" or button == "m") and press then
        setTimer(updateBrowserPauseState, 60, 1)
    end
end)

local function disableGTAHud()
    for _, comp in ipairs(gtaHudComponents) do
        setPlayerHudComponentVisible(comp, false)
    end
end

local turkishLocales = {
    topbar_server_name_default = "GZL ROLEPLAY",
    topbar_server_role_default = "Vatandaş",
    topbar_job_unemployed = "İşsiz",
    topbar_player_name_fallback = "Oyuncu",
    topbar_label_id = "ID",
    topbar_label_name = "İsim",
    topbar_label_player_job = "Oyuncu Mesleği",
    topbar_label_player_id = "OYUNCU ID",
    topbar_label_player_job_caps = "OYUNCU MESLEĞİ",
    topbar_label_bank = "BANKA",
    topbar_label_black_money = "Kara Para",
    topbar_label_cash = "NAKİT",
    topbar_weapon_name_placeholder = "-",
    topbar_label_cash_money = "Cüzdan Bakiyesi",
    topbar_label_bank_money = "Banka Bakiyesi",
    status_label_stress = "Stres",
    status_label_voice = "Ses",
    status_label_health = "Can",
    status_label_armor = "Zırh",
    status_label_hunger = "Açlık",
    status_label_thirst = "Susuzluk",
    status_label_oxygen = "Oksijen",
    speedo_aria_label = "Hız Göstergesi",
    speedo_fuel_label = "YAKIT",
    speedo_gear_indicator = "Vites Göstergesi",
    speedo_gear_neutral = "Boşta",
    speedo_unit_mph_long = "mil/saat",
    speedo_unit_kmh_long = "km/saat",
    speedo_rpm_percent_suffix = "% Devir",
    speedo_heading_north = "K",
    speedo_rpm_percent_label = "% Devir",
    speedo_boat_transmission_auto = "Otomatik",
    layout_action_hide = "Gizle",
    layout_action_show = "Göster",
    layout_action_hide_panel_bg = "Panel Arkaplanını Gizle",
    layout_action_show_panel_bg = "Panel Arkaplanını Göster",
    layout_action_resize = "Boyutlandır",
    layout_toolbar_reset = "Sıfırla",
    layout_toolbar_export = "Dışa Aktar",
    layout_toolbar_save = "Kaydet",
    layout_theme_title = "Tema İçe / Dışa Aktar",
    layout_theme_desc = "HUD tema JSON kodunuzu paylaşın veya uygulayın.",
    layout_theme_add_placeholder = "Tema JSON kodunu buraya yapıştırın...",
    layout_theme_copy = "JSON Kopyala",
    layout_theme_add_json = "JSON Ekle",
    layout_theme_add = "Ekle",
    layout_theme_close = "Kapat",
    layout_theme_paste_prompt = "JSON yapıştırın ve Ekle butonuna basın.",
    layout_theme_copied = "Tema JSON kopyalandı.",
    layout_theme_copy_manual = "Pano kullanılamıyor, manuel kopyalayın.",
    layout_theme_copy_failed = "Kopyalama başarısız, manuel kopyalayın.",
    layout_theme_invalid_json = "Geçersiz JSON formatı.",
    layout_theme_applied = "Tema başarıyla uygulandı.",
    controlpanel_preview_street = "Downtown Los Santos",
    controlpanel_preview_date = "20.08.2026",
    controlpanel_preview_time = "20:30",
    controlpanel_close = "Kapat",
    controlpanel_hud = "HUD",
    controlpanel_settings = "AYARLARI",
    controlpanel_tab_general = "Genel",
    controlpanel_tab_coloring = "Renkler",
    controlpanel_tab_speedometer = "Hız Göstergesi",
    controlpanel_tab_status = "Durum Barları",
    controlpanel_tab_position = "Konumlandırma",
    controlpanel_reset_changes = "Sıfırla",
    controlpanel_save_changes = "Değişiklikleri Kaydet",
    controlpanel_display_options = "Görünüm Seçenekleri",
    controlpanel_enable = "Açık",
    controlpanel_disable = "Kapalı",
    controlpanel_circle = "Daire",
    controlpanel_square = "Kare",
    controlpanel_time_game = "Oyun",
    controlpanel_time_real = "Gerçek",
    controlpanel_speedo_type_prefix = "Gösterge Stili",
    controlpanel_status_type = "Durum Barı Tasarımı",
    controlpanel_status_presentation = "Durum Barları Sunumu",
    controlpanel_status_presentation_general = "Genel (İkonlu)",
    controlpanel_status_presentation_modern = "Minimal Çizgisel",
    controlpanel_status_presentation_classic = "Klasik Dairesel",
    controlpanel_status_type_prefix = "Tasarım",
    controlpanel_status_coloring = "Durum Barları Renkleri",
    controlpanel_header_general_title = "Genel Ayarlar",
    controlpanel_header_general_sub = "Temel HUD davranışı, birimler ve düzen tercihlerini yapılandırın.",
    controlpanel_header_coloring_title = "Renk Ayarları",
    controlpanel_header_coloring_sub = "HUD arayüzü ve durum barlarının tema renklerini özelleştirin.",
    controlpanel_header_speedometer_title = "Hız Göstergesi Ayarları",
    controlpanel_header_speedometer_sub = "Hız göstergesi tipi, kadran teması ve uyarı seslerini ayarlayın.",
    controlpanel_header_status_title = "Durum Barları Ayarları",
    controlpanel_header_status_sub = "Can, zırh, açlık, susuzluk ve stres barlarının görünümünü seçin.",
    controlpanel_header_position_title = "Konumlandırma & Düzen",
    controlpanel_header_position_sub = "HUD öğelerini ve mini haritayı ekranda istediğiniz yere taşıyın.",
    controlpanel_display_compass_title = "Pusulayı Göster",
    controlpanel_display_compass_desc = "Ekranın üst kısmında yön ve derece pusulasını gösterir.",
    controlpanel_display_speed_title = "Hız Birimi",
    controlpanel_display_speed_desc = "Hız göstergesinde kullanılan hız birimi (KM/H veya MPH).",
    controlpanel_display_minimap_title = "Yaya İken Mini Harita",
    controlpanel_display_minimap_desc = "Araçta değilken yaya halinde mini haritayı gösterir veya gizler.",
    controlpanel_display_minimap_frame_title = "Harita Çerçevesi",
    controlpanel_display_minimap_frame_desc = "Mini haritanın etrafındaki çerçeve kenarlığını gösterir veya gizler.",
    controlpanel_display_cinematic_title = "Sinematik Barlar",
    controlpanel_display_cinematic_desc = "Ekranın üst ve altında sinematik siyah film barları oluşturur.",
    controlpanel_display_seatbelt_title = "Kemer Uyarı Sesi",
    controlpanel_display_seatbelt_desc = "Araçta emniyet kemeri takılı değilken uyarı sesini açar veya kapatır.",
    controlpanel_display_streamer_mode_title = "Yayıncı Modu",
    controlpanel_display_streamer_mode_desc = "Yayın yaparken sağ üstteki hassas oyuncu ve bakiye bilgilerini gizler.",
    controlpanel_display_status_pct_title = "Durum Yüzdeleri",
    controlpanel_display_status_pct_desc = "Durum barlarının altında sayısal yüzde değerlerini gösterir.",
    controlpanel_map_style_title = "Harita Şekli",
    controlpanel_map_style_desc = "Mini harita çerçeve şeklini seçin (Daire veya Kare).",
    controlpanel_topbar_style_title = "Üst Bilgi Çubuğu Stili",
    controlpanel_topbar_style_desc = "Sağ üst köşedeki oyuncu ve sunucu bilgi çubuğu tasarımı (Stil 1-7).",
    controlpanel_progbar_style_title = "İlerleme Çubuğu Stili",
    controlpanel_progbar_style_desc = "Eylemlerde ekrana gelen ilerleme barı tasarımı (6 farklı stil).",
    controlpanel_time_source_title = "Saat Kaynağı",
    controlpanel_time_source_desc = "Üst bilgi çubuğundaki saat için zaman kaynağını seçin (Oyun / Gerçek).",
    controlpanel_status_color_heart = "Can",
    controlpanel_status_color_armor = "Zırh",
    controlpanel_status_color_hunger = "Açlık",
    controlpanel_status_color_water = "Susuzluk",
    controlpanel_status_color_oxygen = "Oksijen",
    controlpanel_status_color_stress = "Stres",
    controlpanel_compass_theme_color = "Pusula Teması",
    controlpanel_topbar_bg_theme_color = "Üst Çubuk Arkaplanı",
    controlpanel_topbar_fg_theme_color = "Üst Çubuk Metin & İkonlar",
    controlpanel_voice_active_color = "Ses (Aktif)",
    controlpanel_progbar_fill_color = "İlerleme Barı Dolgusu",
    controlpanel_progbar_track_color = "İlerleme Barı Arkaplanı",
    progbar_loading_label = "Yükleniyor",
    progbar_wait_label = "Lütfen Bekleyin",
    progbar_cancelled_label = "İptal Edildi",
    music_ui_play_action = "Çal",
    music_ui_unknown_artist = "Bilinmeyen Sanatçı",
    music_ui_remove_from_favorites = "Favorilerden Çıkar",
    music_ui_remove_from_playlist = "Listeden Kaldır",
    music_ui_track_fallback = "Parça",
    music_ui_track_youtube = "YouTube",
    music_ui_now_playing = "Şimdi Çalıyor",
    music_ui_add_to_favorites = "Favorilere Ekle",
    music_ui_song_position = "Şarkı Süresi",
    music_ui_prev_song = "Önceki Şarkı",
    music_ui_pause = "Duraklat",
    music_ui_next_song = "Sonraki Şarkı",
    music_ui_vehicle_dock = "Araç Teybi",
    music_ui_title = "Müzik Çalar",
    music_ui_search_placeholder = "YouTube veya YouTube Music linki yapıştırın...",
    music_ui_search_aria = "Çalınacak YouTube linki",
    music_ui_close_menu = "Müzik Menüsünü Kapat",
    music_ui_sections_aria = "Müzik Bölümleri",
    music_ui_tab_music = "Müzik",
    music_ui_tab_playlist = "Çalma Listeleri",
    music_ui_tab_favorites = "Favoriler",
    music_ui_favorites_title = "Favorilerim",
    music_ui_favorites_subtitle = "Kaydettiğiniz parçalar",
    music_ui_add_music = "Müzik Ekle",
    music_ui_edit = "Düzenle",
    music_ui_play_all_favorites = "Favorileri Sırayla Çal",
    music_ui_empty_favorites = "Henüz favori parça yok. Müzik sekmesinden kalp butonuna basarak ekleyebilirsiniz.",
    music_ui_create_playlist = "Çalma Listesi Oluştur",
    music_ui_empty_playlists = "Henüz çalma listesi yok. Yukarıdan yeni bir liste oluşturabilirsiniz.",
    music_ui_playlist_label = "Çalma Listesi",
    music_ui_tracks_suffix = "Parça",
    music_ui_back_to_playlist_list = "Listelere Geri Dön",
    music_ui_playlist_tracks_subtitle = "Bu listedeki parçalar",
    music_ui_add_music_to_list = "Listeye Müzik Ekle",
    music_ui_edit_playlist = "Listeyi Düzenle",
    music_ui_play_playlist_in_order = "Listeyi Sırayla Çal",
    music_ui_empty_playlist_detail = "Bu çalma listesi boş. + butonuna basarak YouTube linki ekleyin.",
    music_ui_add_music_hint_favorites = "YouTube linki yapıştırın. Favorilerinize eklenecektir.",
    music_ui_add_music_hint_playlist = "YouTube linki yapıştırın; bu çalma listesine eklenecektir.",
    music_ui_youtube_url_placeholder = "https://www.youtube.com/watch?v=...",
    music_ui_youtube_url_aria = "YouTube video bağlantısı",
    music_ui_add_link_to_favorites = "Bağlantıyı Favorilere Ekle",
    music_ui_add_link_to_playlist = "Bağlantıyı Listeye Ekle",
    music_ui_valid_youtube_required = "Geçerli bir YouTube bağlantısı gereklidir",
    music_ui_only_youtube_hint = "Bu panel yalnızca YouTube ve YouTube Music bağlantılarını destekler.",
    music_ui_no_name_search_hint = "İsimle arama yerine doğrudan paylaşım linki yapıştırın.",
    music_ui_cancel = "İptal",
    music_ui_add_to_playlist = "Listeye Ekle",
    music_ui_edit_playlist_title = "Çalma Listesini Düzenle",
    music_ui_edit_playlist_subtitle = "Liste adını ve kapak görseli URL'sini güncelleyin",
    music_ui_create_playlist_subtitle = "Yeni bir liste adı ve kapak görseli belirleyin",
    music_ui_playlist_name_placeholder = "Çalma listesi adı...",
    music_ui_playlist_name_aria = "Çalma listesi adı",
    music_ui_confirm_url = "Bağlantıyı Onayla",
    music_ui_cover_url_placeholder = "Kapak görseli PNG/JPG URL (https://...)",
    music_ui_playlist_cover_url_aria = "Kapak görseli URL",
    music_ui_confirm_image = "Görseli Onayla",
    music_ui_save_changes = "Değişiklikleri Kaydet",
    music_ui_create_playlist_action = "Liste Oluştur",
    music_ui_save = "Kaydet",
    music_ui_volume_level = "Ses Düzeyi",
    carcontrol_ui_close = "Kapat",
    carcontrol_ui_nav_default_text = "Geri Dön",
    carcontrol_ui_nav_default_subtext = "Hedef Seçin",
    notify_stack_live_label = "Bildirimler",
    notify_stack_examples_label = "Bildirim Örnekleri",
    notify_demo_info_description = "Bilgilendirme örneği — işlem başarıyla tamamlandı.",
    notify_demo_success_description = "Başarılı — ayarlarınız kaydedildi.",
    notify_demo_warning_description = "Uyarı — lütfen devam etmeden önce kontrol edin."
}

local defaultSettings = {
    compassVisible = false,
    showMiniMapOnFoot = true,
    showMinimapFrame = true,
    modernMinimapShape = "circle",
    speedUnit = "kmh",
    activeStatus = 4,
    activeSpeedo = 5,
    activeTopBar = 2,
    statusPresentation = "general",
    progbarVariant = 1,
    cinematicBars = false,
    streamerMode = false,
    statusPercent = true,
    timeMode = "real"
}
local savedSettings = {}

local function loadSavedSettings()
    if fileExists("@hud_settings.json") then
        local file = fileOpen("@hud_settings.json")
        if file then
            local size = fileGetSize(file)
            local content = (size > 0) and fileRead(file, size) or ""
            fileClose(file)
            if content and content ~= "" then
                local parsed = fromJSON(content)
                if type(parsed) == "table" then
                    for k, v in pairs(defaultSettings) do
                        if parsed[k] == nil then
                            parsed[k] = v
                        end
                    end
                    savedSettings = parsed
                    return
                end
            end
        end
    end
    savedSettings = {}
    for k, v in pairs(defaultSettings) do
        savedSettings[k] = v
    end
end

local function saveSettingsToFile()
    if fileExists("@hud_settings.json") then
        fileDelete("@hud_settings.json")
    end
    local file = fileCreate("@hud_settings.json")
    if file then
        local jsonStr = toJSON(savedSettings)
        fileWrite(file, jsonStr)
        fileClose(file)
    end
end

local function pushVoiceState(isActive)
    if deferBackgroundUpdate() then return end
    if not isBrowserReady or not hudBrowser then return end
    local talking = isActive
    if talking == nil then
        talking = (getElementData(localPlayer, "voice:talking") == true) or (getElementData(localPlayer, "voice_talking") == true)
    end
    if lastVoice.talking ~= talking or lastVoice.level ~= currentVoiceIndex then
        lastVoice.talking = talking
        lastVoice.level = currentVoiceIndex
        sendNuiMessage({
            action = "updateVoice",
            data = {
                active = talking,
                level = currentVoiceIndex
            }
        })
    end
end

local cachedFuel = 85
local lastFuelCheck = 0

local function getPlayerNeeds()
    local rawHunger = tonumber(getElementData(localPlayer, "char:hunger") or getElementData(localPlayer, "character:hunger") or getElementData(localPlayer, "hunger")) or 100
    local rawThirst = tonumber(getElementData(localPlayer, "char:thirst") or getElementData(localPlayer, "character:thirst") or getElementData(localPlayer, "thirst")) or 100
    local rawStress = tonumber(getElementData(localPlayer, "char:stress") or getElementData(localPlayer, "character:stress") or getElementData(localPlayer, "stress")) or 0
    local rawOxygen = tonumber(getElementData(localPlayer, "char:oxygen") or getElementData(localPlayer, "oxygen"))
    if not rawOxygen then
        rawOxygen = math.floor(getPedOxygenLevel(localPlayer) / 10)
    end
    return math.max(0, math.min(100, math.floor(rawHunger))),
           math.max(0, math.min(100, math.floor(rawThirst))),
           math.max(0, math.min(100, math.floor(rawStress))),
           math.max(0, math.min(100, math.floor(rawOxygen)))
end

local function pushPlayerStatus(forceSend)
    if deferBackgroundUpdate() then return end
    if isSettingsOpen or not isVisible or not isBrowserReady or not hudBrowser or isPlayerMapVisible() or isMainMenuActive() then
        return
    end

    local hp = math.max(0, math.min(100, math.floor(getElementHealth(localPlayer))))
    local armour = math.max(0, math.min(100, math.floor(getPedArmor(localPlayer))))
    local hunger, thirst, stress, oxygen = getPlayerNeeds()

    local veh = getPedOccupiedVehicle(localPlayer)
    local inVeh = isElement(veh)

    local speed = 0
    local rpm = 0
    local gear = 1
    local vehHealth = 1000
    local lightsOn = false
    local engineOn = false

    if inVeh then
        local vx, vy, vz = getElementVelocity(veh)
        speed = math.floor(math.sqrt(vx * vx + vy * vy + vz * vz) * 180)
        rpm = math.min(100, math.floor((speed % 60) * 1.6 + 20))
        gear = getVehicleCurrentGear(veh) or 1
        vehHealth = math.floor(getElementHealth(veh))
        lightsOn = (getVehicleOverrideLights(veh) == 2)
        engineOn = getVehicleEngineState(veh)

        local now = getTickCount()
        if now - lastFuelCheck >= 2000 then
            cachedFuel = math.floor(tonumber(getElementData(veh, "veh:fuel")) or 85)
            lastFuelCheck = now
        end
    end

    local heading = lastStatus.heading
    if savedSettings.compassVisible then
        local _, _, camRot = getElementRotation(getCamera())
        heading = math.floor((360 - camRot) % 360)
    end

    local statusChanged = forceSend or
        lastStatus.hp ~= hp or
        lastStatus.armour ~= armour or
        lastStatus.oxygen ~= oxygen or
        lastStatus.hunger ~= hunger or
        lastStatus.thirst ~= thirst or
        lastStatus.stress ~= stress or
        lastStatus.inVeh ~= inVeh or
        (inVeh and (
            math.abs((lastStatus.speed or 0) - speed) >= 1 or
            math.abs((lastStatus.rpm or 0) - rpm) >= 3 or
            lastStatus.gear ~= gear or
            lastStatus.fuel ~= cachedFuel or
            lastStatus.vehHealth ~= vehHealth or
            lastStatus.lightsOn ~= lightsOn or
            lastStatus.engineOn ~= engineOn or
            lastStatus.seatbelt ~= seatbeltState
        )) or
        (savedSettings.compassVisible and (lastStatus.heading == -1 or math.abs((lastStatus.heading or 0) - heading) >= 3))

    if statusChanged then
        lastStatus.hp = hp
        lastStatus.armour = armour
        lastStatus.oxygen = oxygen
        lastStatus.hunger = hunger
        lastStatus.thirst = thirst
        lastStatus.stress = stress
        lastStatus.inVeh = inVeh
        lastStatus.speed = speed
        lastStatus.rpm = rpm
        lastStatus.gear = gear
        lastStatus.fuel = cachedFuel
        lastStatus.vehHealth = vehHealth
        lastStatus.lightsOn = lightsOn
        lastStatus.engineOn = engineOn
        lastStatus.seatbelt = seatbeltState
        if savedSettings.compassVisible or lastStatus.heading == -1 then
            lastStatus.heading = heading
        end

        local mechVal = inVeh and math.floor(vehHealth / 10) or 100

        cachedPlayerStatus.health = hp
        cachedPlayerStatus.armor = armour
        cachedPlayerStatus.hunger = hunger
        cachedPlayerStatus.thirst = thirst
        cachedPlayerStatus.stamina = oxygen
        cachedPlayerStatus.stress = stress
        cachedPlayerStatus.oxygen = oxygen
        cachedPlayerStatus.inVehicle = inVeh
        cachedPlayerStatus.vehicleSeat = inVeh and 0 or nil
        cachedPlayerStatus.seatbelt = inVeh and seatbeltState or false
        cachedPlayerStatus.lowBeam = inVeh and lightsOn or false
        cachedPlayerStatus.highBeam = false
        cachedPlayerStatus.engineOn = inVeh and engineOn or false
        cachedPlayerStatus.speed = inVeh and speed or 0
        cachedPlayerStatus.rpm = inVeh and rpm or 0
        cachedPlayerStatus.fuel = inVeh and cachedFuel or 85
        cachedPlayerStatus.mechanic = mechVal
        cachedPlayerStatus.engine = mechVal
        cachedPlayerStatus.nitro = 0
        cachedPlayerStatus.gear = inVeh and gear or 1
        cachedPlayerStatus.highGear = 6
        cachedPlayerStatus.maxSpeed = 260
        cachedPlayerStatus.steer = 0
        cachedPlayerStatus.heading = (lastStatus.heading >= 0) and lastStatus.heading or 0
        cachedPlayerStatus.vehicleHudContext = false

        sendNuiMessage(statusMessageWrapper)
    end
end

local function pushSessionData(forceSend)
    if deferBackgroundUpdate() then return end
    if isSettingsOpen or not isVisible or not isBrowserReady or not hudBrowser or isPlayerMapVisible() or isMainMenuActive() then
        return
    end

    local px, py, pz = getElementPosition(localPlayer)
    local zoneName = getZoneName(px, py, pz, false)
    local city = getZoneName(px, py, pz, true)
    local realTime = getRealTime()
    local months = {"01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12"}
    local dateStr = string.format("%02d.%s.%d", realTime.monthday, months[realTime.month + 1] or "05", realTime.year + 1900)
    local timeStr = string.format("%02d:%02d", realTime.hour, realTime.minute)

    local playerId = getElementData(localPlayer, "character:id") or getElementData(localPlayer, "char:id") or getElementData(localPlayer, "account:id") or 1
    local playerName = getElementData(localPlayer, "char:name") or getPlayerName(localPlayer)
    local jobName = getElementData(localPlayer, "char:job") or "Civilian - Freelancer"
    local money = getPlayerMoney(localPlayer) or 0
    local bank = getElementData(localPlayer, "char:bank_money") or getElementData(localPlayer, "char:bank") or getElementData(localPlayer, "character:bank") or 0

    if forceSend or lastSession.time ~= timeStr or lastSession.money ~= money or lastSession.bank ~= bank or lastSession.zone ~= zoneName or lastSession.job ~= jobName then
        lastSession.time = timeStr
        lastSession.money = money
        lastSession.bank = bank
        lastSession.zone = zoneName
        lastSession.job = jobName

        cachedSessionData.time = timeStr
        cachedSessionData.date = dateStr
        cachedSessionData.dateAlt = dateStr
        cachedSessionData.streetLabel = zoneName .. " / " .. city
        cachedSessionData.playerId = tonumber(playerId) or 1
        cachedSessionData.playerName = tostring(playerName)
        cachedSessionData.playerCount = cachedPlayerCount
        cachedSessionData.cash = tonumber(money) or 0
        cachedSessionData.bank = tonumber(bank) or 0
        cachedSessionData.blackMoney = 0
        cachedSessionData.jobLabel = tostring(jobName)
        cachedSessionData.jobGrade = "Rank 1"

        sendNuiMessage(sessionMessageWrapper)
    end
end

addEventHandler("onClientPreRender", root, function()
    if not backgroundRefreshPending or not isMTAWindowFocused() then return end
    if not isBrowserReady or not isElement(hudBrowser) or not isVisible
        or isSettingsOpen or isAnyMapActive() then return end
    backgroundRefreshPending = false
    lastVoice.talking = nil
    lastVoice.level = nil
    pushPlayerStatus(true)
    pushSessionData(true)
    pushVoiceState()
end)

local function initHudBrowser()
    if isElement(guiBrowserElem) then return end

    guiBrowserElem = guiCreateBrowser(0, 0, screenW, screenH, true, true, false)
    guiSetVisible(guiBrowserElem, false)
    hudBrowser = guiGetBrowser(guiBrowserElem)

    addEventHandler("onClientBrowserCreated", hudBrowser, function()
        loadBrowserURL(source, "http://mta/local/dist/index.html")
    end)

    addEventHandler("onClientBrowserDocumentReady", hudBrowser, function()
        isBrowserReady = true
        loadSavedSettings()

        sendNuiMessage({
            action = "loadHud",
            data = {
                locale = turkishLocales,
                localeStrings = turkishLocales,
                firstLoginDefaults = savedSettings,
                compassVisible = savedSettings.compassVisible,
                showMiniMapOnFoot = savedSettings.showMiniMapOnFoot,
                showMinimapFrame = savedSettings.showMinimapFrame,
                modernMinimapShape = savedSettings.modernMinimapShape,
                speedUnit = savedSettings.speedUnit,
                statusPresentation = savedSettings.statusPresentation,
                activeStatus = savedSettings.activeStatus,
                activeSpeedo = savedSettings.activeSpeedo,
                activeTopBar = savedSettings.activeTopBar,
                cinematicBars = savedSettings.cinematicBars,
                streamerMode = {
                    allowToggle = true,
                    default = savedSettings.streamerMode
                },
                statusPercent = savedSettings.statusPercent,
                topBar = {
                    show = true,
                    style = savedSettings.activeTopBar or 2,
                    name = "GZL"
                },
                timeDisplay = {
                    mode = savedSettings.timeMode or "real",
                    useAM = false
                }
            }
        })

        local radarRes = getResourceFromName("gzl_radar")
        if radarRes and getResourceState(radarRes) == "running" and exports.gzl_radar then
            if exports.gzl_radar.setRadarShape then
                pcall(function() exports.gzl_radar:setRadarShape(savedSettings.modernMinimapShape or "circle") end)
            end
            if exports.gzl_radar.setRadarVisibleOnFoot then
                pcall(function() exports.gzl_radar:setRadarVisibleOnFoot(savedSettings.showMiniMapOnFoot ~= false) end)
            end
            if exports.gzl_radar.setRadarBorderVisible then
                pcall(function() exports.gzl_radar:setRadarBorderVisible(savedSettings.showMinimapFrame ~= false) end)
            end
        end

        if isVisible then
            sendNuiMessage({ action = "showHud" })
        else
            sendNuiMessage({ action = "hideHud" })
        end

        if radarRes and getResourceState(radarRes) == "running" and exports.gzl_radar and exports.gzl_radar.setRadarVisible then
            pcall(function() exports.gzl_radar:setRadarVisible(isVisible) end)
        end

        pushVoiceState()
        updateBrowserPauseState()
        pushPlayerStatus(true)
        pushSessionData(true)
    end)
end

function setHUDVisible(state)
    isVisible = (state == true)
    disableGTAHud()
    if isVisible then
        sendNuiMessage({ action = "showHud" })
        pushPlayerStatus(true)
        pushSessionData(true)
    else
        sendNuiMessage({ action = "hideHud" })
    end
    local radarRes = getResourceFromName("gzl_radar")
    if radarRes and getResourceState(radarRes) == "running" and exports.gzl_radar and exports.gzl_radar.setRadarVisible then
        pcall(function() exports.gzl_radar:setRadarVisible(isVisible) end)
    end
    updateBrowserPauseState()
end

function isHUDVisible()
    return isVisible
end

function setVoiceRange(index)
    if index >= 1 and index <= 3 then
        currentVoiceIndex = index
        pushVoiceState()
    end
end

addEventHandler("onClientResourceStart", resourceRoot, function()
    disableGTAHud()
    initHudBrowser()
    if getElementData(localPlayer, "char:id") or getElementData(localPlayer, "loggedin_character") then
        setHUDVisible(true)
    end
end)

local function cleanupHud()
    if isTimer(restoreResumeTimer) then
        killTimer(restoreResumeTimer)
        restoreResumeTimer = nil
    end
    if isSettingsOpen then
        isSettingsOpen = false
        showCursor(false)
        focusBrowser(nil)
    end
    if isElement(guiBrowserElem) then
        destroyElement(guiBrowserElem)
        guiBrowserElem = nil
        hudBrowser = nil
    end
    isBrowserReady = false
end

addEventHandler("onClientResourceStop", resourceRoot, cleanupHud)
addEventHandler("onClientPlayerQuit", localPlayer, cleanupHud)

addEventHandler("onClientPlayerSpawn", localPlayer, function()
    disableGTAHud()
    if getElementData(localPlayer, "char:id") or getElementData(localPlayer, "character:id") or getElementData(localPlayer, "loggedin_character") then
        setHUDVisible(true)
        setTimer(function()
            pushPlayerStatus(true)
            pushSessionData(true)
        end, 100, 1)
    end
end)

addEvent("char:spawnSuccess", true)
addEventHandler("char:spawnSuccess", root, function()
    disableGTAHud()
    setHUDVisible(true)
    setTimer(function()
        pushPlayerStatus(true)
        pushSessionData(true)
    end, 100, 1)
end)

addEvent("auth:showLoginScreen", true)
addEventHandler("auth:showLoginScreen", root, function()
    if isSettingsOpen then
        toggleHudSettings(false)
    end
    setHUDVisible(false)
end)

addEvent("char:receiveList", true)
addEventHandler("char:receiveList", root, function()
    if isSettingsOpen then
        toggleHudSettings(false)
    end
    setHUDVisible(false)
end)

addEventHandler("onClientElementDataChange", localPlayer, function(dataName)
    if dataName == "char:thirst" or dataName == "character:thirst" or dataName == "thirst" or
       dataName == "char:hunger" or dataName == "character:hunger" or dataName == "hunger" or
       dataName == "char:stress" or dataName == "character:stress" or dataName == "stress" or
       dataName == "char:oxygen" or dataName == "oxygen" or
       dataName == "health" or dataName == "armor" or dataName == "armour" or dataName == "char:armor" then
        pushPlayerStatus(true)
    elseif dataName == "char:money" or dataName == "character:money" or
           dataName == "char:bank" or dataName == "char:bank_money" or dataName == "character:bank" or
           dataName == "char:job" or dataName == "char:name" then
        pushSessionData(true)
    elseif dataName == "voice:talking" or dataName == "voice_talking" then
        local newVal = (getElementData(localPlayer, dataName) == true)
        pushVoiceState(newVal)
    elseif dataName == "bigmap:isOpen" then
        isBigmapOpen = (getElementData(localPlayer, dataName) == true)
        updateBrowserPauseState()
    elseif dataName == "character:id" or dataName == "char:id" or dataName == "loggedin_character" then
        local isChar = (getElementData(localPlayer, "character:id") or getElementData(localPlayer, "char:id") or getElementData(localPlayer, "loggedin_character")) and true or false
        if not isChar then
            setHUDVisible(false)
            if isSettingsOpen then
                toggleHudSettings(false)
            end
        else
            setHUDVisible(true)
            pushPlayerStatus(true)
            pushSessionData(true)
        end
    end
end)

addEventHandler("onClientPlayerDamage", localPlayer, function()
    setTimer(function()
        pushPlayerStatus(true)
    end, 50, 1)
end)

addEventHandler("onClientPlayerVehicleEnter", localPlayer, function()
    seatbeltState = false
    pushPlayerStatus(true)
end)

addEventHandler("onClientPlayerVehicleExit", localPlayer, function()
    seatbeltState = false
    pushPlayerStatus(true)
end)

addEventHandler("onClientPlayerWasted", localPlayer, function()
    setTimer(function()
        pushPlayerStatus(true)
    end, 100, 1)
end)

addEventHandler("onClientResourceStop", root, function(res)
    if res == getThisResource() then return end
    local isChar = (getElementData(localPlayer, "character:id") or getElementData(localPlayer, "char:id") or getElementData(localPlayer, "loggedin_character")) and true or false
    if isChar then
        disableGTAHud()
        if not isVisible then
            setHUDVisible(true)
        end
    end
end)

addEventHandler("onClientResourceStart", root, function(res)
    if res == getThisResource() then return end
    local isChar = (getElementData(localPlayer, "character:id") or getElementData(localPlayer, "char:id") or getElementData(localPlayer, "loggedin_character")) and true or false
    if isChar then
        disableGTAHud()
        if not isVisible then
            setHUDVisible(true)
        end
    end
end)

bindKey("z", "down", function()
    if isCursorShowing() then return end
    if (exports.gzl_core and exports.gzl_core.isPlayerTyping and exports.gzl_core:isPlayerTyping()) or guiGetInputEnabled() or isChatBoxInputActive() or isConsoleActive() then return end
    if not isVisible then return end
    currentVoiceIndex = currentVoiceIndex + 1
    if currentVoiceIndex > 3 then
        currentVoiceIndex = 1
    end
    local names = {"Fısıltı", "Normal", "Bağırma"}
    pushVoiceState()
    if exports.gzl_ui and exports.gzl_ui.showNotification then
        exports.gzl_ui:showNotification("SES MENZİLİ", "Konuşma menzili: " .. names[currentVoiceIndex], "info", 1800)
    end
end)

bindKey("k", "down", function()
    if isCursorShowing() then return end
    if (exports.gzl_core and exports.gzl_core.isPlayerTyping and exports.gzl_core:isPlayerTyping()) or guiGetInputEnabled() or isChatBoxInputActive() or isConsoleActive() then return end
    local veh = getPedOccupiedVehicle(localPlayer)
    if veh and isVisible then
        seatbeltState = not seatbeltState
        if seatbeltState then
            if exports.gzl_ui and exports.gzl_ui.showNotification then
                exports.gzl_ui:showNotification("EMNİYET KEMERİ", "Kemer takıldı.", "success", 1800)
            end
            playSoundFrontEnd(40)
        else
            if exports.gzl_ui and exports.gzl_ui.showNotification then
                exports.gzl_ui:showNotification("EMNİYET KEMERİ", "Kemer çıkarıldı!", "warning", 1800)
            end
            playSoundFrontEnd(41)
        end
        pushPlayerStatus(true)
    end
end)

function toggleSettings(forceState)
    toggleHudSettings(forceState)
end

function toggleHudSettings(forceState)
    local hasCharacter = getElementData(localPlayer, "char:id") or getElementData(localPlayer, "character:id") or getElementData(localPlayer, "loggedin_character")
    if not hasCharacter and forceState ~= false then return end
    if not isBrowserReady or not hudBrowser then return end
    if forceState ~= nil then
        isSettingsOpen = (forceState == true)
    else
        isSettingsOpen = not isSettingsOpen
    end

    showCursor(isSettingsOpen)
    if isElement(guiBrowserElem) then
        guiSetVisible(guiBrowserElem, isSettingsOpen)
        if isSettingsOpen then
            guiBringToFront(guiBrowserElem)
            focusBrowser(hudBrowser)
        else
            focusBrowser(nil)
        end
    end

    if isSettingsOpen then
        sendNuiMessage({ action = "openHudMenu", tab = "general" })
    else
        sendNuiMessage({ action = "closeHudMenu" })
    end

    updateBrowserPauseState()
end

addCommandHandler("hud", function()
    toggleHudSettings()
end)

bindKey("escape", "down", function()
    if isSettingsOpen then
        cancelEvent()
        toggleHudSettings(false)
    end
end)

function getTopBarHeight()
    if not isVisible then return 20 end
    return 210
end

addEvent("gzl_hud:onNuiCallback", true)
addEventHandler("gzl_hud:onNuiCallback", root, function(endpoint, bodyJson)
    local data = {}
    if bodyJson and bodyJson ~= "" and bodyJson ~= "{}" then
        data = fromJSON(bodyJson) or {}
    end

    if endpoint == "closeHud" or endpoint == "closeHudMenu" then
        toggleHudSettings(false)
    elseif endpoint == "closeCarControl" then
        toggleHudSettings(false)
    elseif endpoint == "saveHudSettings" then
        for k, v in pairs(data) do
            savedSettings[k] = v
        end
        saveSettingsToFile()
        if exports.gzl_radar then
            if exports.gzl_radar.setRadarShape and data.modernMinimapShape then
                exports.gzl_radar:setRadarShape(data.modernMinimapShape)
            end
            if exports.gzl_radar.setRadarVisibleOnFoot and data.showMiniMapOnFoot ~= nil then
                exports.gzl_radar:setRadarVisibleOnFoot(data.showMiniMapOnFoot)
            end
            if exports.gzl_radar.setRadarBorderVisible and data.showMinimapFrame ~= nil then
                exports.gzl_radar:setRadarBorderVisible(data.showMinimapFrame)
            end
        end
    elseif endpoint == "setCompassVisible" then
        savedSettings.compassVisible = (data.enabled == true)
        saveSettingsToFile()
    elseif endpoint == "setMinimapShape" then
        savedSettings.modernMinimapShape = data.shape or "circle"
        saveSettingsToFile()
        if exports.gzl_radar and exports.gzl_radar.setRadarShape then
            exports.gzl_radar:setRadarShape(savedSettings.modernMinimapShape)
        end
    elseif endpoint == "setMinimapShowOnFoot" then
        savedSettings.showMiniMapOnFoot = (data.enabled == true)
        saveSettingsToFile()
        if exports.gzl_radar and exports.gzl_radar.setRadarVisibleOnFoot then
            exports.gzl_radar:setRadarVisibleOnFoot(savedSettings.showMiniMapOnFoot)
        end
    elseif endpoint == "setMinimapFrame" or endpoint == "showMinimapFrame" then
        savedSettings.showMinimapFrame = (data.enabled ~= false)
        saveSettingsToFile()
        if exports.gzl_radar and exports.gzl_radar.setRadarBorderVisible then
            exports.gzl_radar:setRadarBorderVisible(savedSettings.showMinimapFrame)
        end
    elseif endpoint == "setCinematicBars" then
        savedSettings.cinematicBars = (data.enabled == true)
        saveSettingsToFile()
    elseif endpoint == "setStreamerMode" then
        savedSettings.streamerMode = (data.enabled == true)
        saveSettingsToFile()
    elseif endpoint == "setStatusSlotPercentVisible" then
        savedSettings.statusPercent = (data.enabled ~= false)
        saveSettingsToFile()
    elseif endpoint == "setActiveTopBar" then
        savedSettings.activeTopBar = tonumber(data.style) or 2
        saveSettingsToFile()
    elseif endpoint == "setActiveSpeedo" then
        savedSettings.activeSpeedo = tonumber(data.style) or 5
        saveSettingsToFile()
    elseif endpoint == "setMinimapStatusVariant" then
        savedSettings.activeStatus = tonumber(data.variant) or 4
        saveSettingsToFile()
    elseif endpoint == "setMinimapHudPresentation" then
        savedSettings.statusPresentation = data.presentation or "general"
        saveSettingsToFile()
    elseif endpoint == "updateData" then
        if data.speedType then
            savedSettings.speedUnit = data.speedType
            saveSettingsToFile()
        end
    elseif endpoint == "setHudTimeMode" then
        if data.mode then
            savedSettings.timeMode = data.mode
            saveSettingsToFile()
        end
    elseif endpoint == "setGeneralMinimapLayout" then
        if exports.gzl_radar and exports.gzl_radar.setRadarLayout then
            exports.gzl_radar:setRadarLayout(data.x, data.y, data.scale)
        end
    end
end)

setTimer(function()
    if isSettingsOpen or not isVisible or not isBrowserReady or isPlayerMapVisible() or isMainMenuActive() then
        return
    end
    local veh = getPedOccupiedVehicle(localPlayer)
    if not veh then return end

    pushPlayerStatus(false)
end, 80, 0)

setTimer(function()
    if isSettingsOpen or not isVisible or not isBrowserReady or isPlayerMapVisible() or isMainMenuActive() then
        return
    end
    if isPedInVehicle(localPlayer) or not savedSettings.compassVisible then
        return
    end

    pushPlayerStatus(false)
end, 150, 0)

setTimer(function()
    if isSettingsOpen or not isVisible or not isBrowserReady or isPlayerMapVisible() or isMainMenuActive() then
        return
    end

    pushPlayerStatus(false)
end, 500, 0)

setTimer(function()
    pushSessionData(false)
end, 1000, 0)

setTimer(function()
    updateBrowserPauseState()
    local isChar = (getElementData(localPlayer, "character:id") or getElementData(localPlayer, "char:id") or getElementData(localPlayer, "loggedin_character")) and true or false
    if isChar and not isSettingsOpen and not isAnyMapActive() then
        if not isVisible and isBrowserReady then
            disableGTAHud()
            setHUDVisible(true)
        end
    end
end, 1000, 0)

addEventHandler("onClientRender", root, function()
    if not isVisible or not hudBrowser or not isBrowserReady or isSettingsOpen or isAnyMapActive() then
        return
    end
    dxDrawImage(0, 0, screenW, screenH, hudBrowser, 0, 0, 0, tocolor(255, 255, 255, 255), true)
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    if isTimer(restoreResumeTimer) then
        killTimer(restoreResumeTimer)
        restoreResumeTimer = nil
    end
end)