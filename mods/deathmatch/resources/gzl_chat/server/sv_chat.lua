addEvent("chat:init", true)
addEvent("chat:messageEntered", true)
addEvent("chat:commandEntered", true)
addEvent("chat:addTemplate", true)
addEvent("chat:addMessage", true)
addEvent("chat:addSuggestion", true)
addEvent("chat:removeSuggestion", true)
addEvent("chat:server:ClearChat", true)

function getCharacterName(player)
    if not isElement(player) then return "Bilinmeyen" end
    local charName = getElementData(player, "char:name") or getElementData(player, "character:name")
    if charName and charName ~= "" then
        return tostring(charName):gsub("_", " ")
    end
    return getPlayerName(player):gsub("#%x%x%x%x%x%x", "")
end

function findPlayer(target)
    if not target then return false end
    if isElement(target) and getElementType(target) == "player" then return target end

    local targetStr = tostring(target):lower()
    local targetId = tonumber(target)

    for _, player in ipairs(getElementsByType("player")) do
        if targetId then
            local pid = getElementData(player, "playerid") or getElementData(player, "char:id") or getElementData(player, "id")
            if pid and tonumber(pid) == targetId then
                return player
            end
        end

        local pName = getPlayerName(player):gsub("#%x%x%x%x%x%x", ""):lower()
        local cName = (getElementData(player, "char:name") or ""):lower():gsub("_", " ")

        if pName:find(targetStr, 1, true) or (cName ~= "" and cName:find(targetStr, 1, true)) then
            return player
        end
    end
    return false
end

local defaultSuggestions = {
    { name = "/me", help = "Karakterinizin yaptığı fiziksel eylemi belirtir.", params = { { name = "eylem", help = "Örn: cebinden anahtarı çıkarır" } } },
    { name = "/do", help = "Karakterinizin veya ortamın durumunu belirtir.", params = { { name = "durum", help = "Örn: kapının kilitli olduğu görülür" } } },
    { name = "/b", help = "Yerel OOC (Rol dışı) konuşma.", params = { { name = "mesaj", help = "Rol dışı konuşma metni" } } },
    { name = "/ooc", help = "Genel OOC sohbet kanalı.", params = { { name = "mesaj", help = "Mesajınız" } } },
    { name = "/s", help = "Bağırarak konuşma (Geniş mesafe).", params = { { name = "mesaj", help = "Bağırmak istediğiniz metin" } } },
    { name = "/w", help = "Yanınızdaki kişiye fısıldar.", params = { { name = "oyuncu", help = "ID veya İsim" }, { name = "mesaj", help = "Fısıldanacak metin" } } },
    { name = "/pm", help = "Belirtilen oyuncuya özel mesaj gönderir.", params = { { name = "oyuncu", help = "ID veya İsim" }, { name = "mesaj", help = "Mesajınız" } } },
    { name = "/clear", help = "Sohbet pencerenizi temizler.", params = {} },
    { name = "/cleardebug", help = "Ekrandaki hata ve debug yazılarını temizler.", params = {} },
    { name = "/zarat", help = "Rastgele zar atar (1-6) ve animasyon oynatır.", params = {} },
    { name = "/otur", help = "Oturma animasyonu başlatır/kapatır. (Stiller: 1-10)", params = { { name = "stil", help = "1-10 arası oturma tarzı (opsiyonel)" } } },
    { name = "/elkaldir", help = "Tek el işaret / el kaldırma. (Kısayol: X tuşu)", params = {} },
    { name = "/teslim", help = "İki el havada teslim olma modu. (Kısayol: Shift+X)", params = {} },
    { name = "/sit", help = "Oturma animasyonu başlatır/kapatır. (Stiller: 1-10)", params = { { name = "stil", help = "1-10 arası oturma tarzı" } } },
    { name = "/oturliste", help = "Tüm oturma tarzlarını listeler.", params = {} },
    { name = "/psa", help = "Sunucu genel duyurusu (Yetkili).", params = { { name = "mesaj", help = "Duyuru metni" } } },
    { name = "/inventory", help = "Envanteri açar veya kapatır.", params = {} },
    { name = "/hud", help = "HUD ayarlarını açar.", params = {} },
    { name = "/giveveh", help = "Oyuncuya araç verir (Yetkili).", params = { { name = "oyuncu", help = "ID / İsim" }, { name = "model", help = "Örn: 411" } } },
    { name = "/tp", help = "Oyuncuya veya koordinata ışınlan.", params = { { name = "hedef", help = "ID / İsim veya X, Y, Z" } } },
    { name = "/goto", help = "Oyuncuya veya koordinata ışınlan.", params = { { name = "hedef", help = "ID / İsim veya X, Y, Z" } } },
    { name = "/getpos", help = "Mevcut pozisyonu gösterir ve panoya kopyalar.", params = {} },
    { name = "/gp", help = "Mevcut pozisyonu gösterir ve panoya kopyalar.", params = {} },
    { name = "/veh", help = "Araç çıkartır (ID veya isim ile).", params = { { name = "model", help = "Örn: 411 veya sultan" }, { name = "renk1", help = "Opsiyonel" } } },
    { name = "/dv", help = "Bindiğiniz veya yakındaki aracı siler.", params = {} },
    { name = "/fix", help = "Aracı tamir eder ve hasarını sıfırlar.", params = {} },
    { name = "/fly", help = "Uçma / NoClip modunu açar veya kapatır.", params = {} },
    { name = "/heal", help = "Can, zırh, açlık ve susuzluğu doldurur.", params = { { name = "oyuncu", help = "Opsiyonel ID/İsim" } } },
    { name = "/god", help = "Ölümsüzlük modunu açar veya kapatır.", params = {} },
    { name = "/skin", help = "Karakterinizin kıyafet/skin modelini değiştirir.", params = { { name = "id", help = "Skin ID (0-312)" } } },
    { name = "/givemoney", help = "Karaktere para ekler.", params = { { name = "miktar", help = "Para tutarı" }, { name = "oyuncu", help = "Opsiyonel ID/İsim" } } },
    { name = "/giveitem", help = "Karaktere eşya verir.", params = { { name = "eşya", help = "Eşya adı (örn: radio, water)" }, { name = "adet", help = "Opsiyonel adet" }, { name = "oyuncu", help = "Opsiyonel ID/İsim" } } },
    { name = "/settime", help = "Oyun saatini değiştirir.", params = { { name = "saat", help = "0-23" }, { name = "dakika", help = "0-59" } } },
    { name = "/setweather", help = "Hava durumunu değiştirir.", params = { { name = "id", help = "Hava ID (0-20)" } } }
}

addEventHandler("chat:init", root, function()
    local p = client or source
    if not isElement(p) then return end
    triggerClientEvent(p, "chat:addSuggestions", p, defaultSuggestions)
end)

local function isPlayerLoggedIn(player)
    return (getElementData(player, "char:id") or getElementData(player, "loggedin_character") or getElementData(player, "character:id")) and true or false
end

addEventHandler("chat:messageEntered", root, function(author, color, message)
    local sender = client or source
    if not isElement(sender) or not isPlayerLoggedIn(sender) or not message or message == "" then return end

    local name = getCharacterName(sender)
    local sx, sy, sz = getElementPosition(sender)
    local sDim = getElementDimension(sender)
    local sInt = getElementInterior(sender)

    local maxDistance = 20.0

    for _, target in ipairs(getElementsByType("player")) do
        if getElementDimension(target) == sDim and getElementInterior(target) == sInt then
            local tx, ty, tz = getElementPosition(target)
            local dist = getDistanceBetweenPoints3D(sx, sy, sz, tx, ty, tz)

            if dist <= maxDistance then
                local textColor = "#FFFFFF"
                if dist > 14.0 then
                    textColor = "#B0B0B0"
                elseif dist > 7.0 then
                    textColor = "#E0E0E0"
                end

                triggerClientEvent(target, "chat:addMessage", target, {
                    type = "SAY",
                    typeColor = "#2563eb",
                    header = name,
                    content = message,
                    textColor = textColor
                })
            end
        end
    end
end)

addEventHandler("chat:commandEntered", root, function(cmdName, argsStr, fullCmd, argsTable)
    local sender = client or source
    if not isElement(sender) or not isPlayerLoggedIn(sender) or not cmdName then return end

    local cmdLower = cmdName:lower()
    if g_CustomCommands and g_CustomCommands[cmdLower] then
        g_CustomCommands[cmdLower](sender, cmdLower, unpack(argsTable or {}))
        return
    end

    local executed = false
    pcall(function()
        executed = executeCommandHandler(cmdName, sender, argsStr or "")
    end)

    if not executed and argsTable and #argsTable > 0 then
        pcall(function()
            executed = executeCommandHandler(cmdName, sender, unpack(argsTable))
        end)
    end

    if not executed then
        triggerClientEvent(sender, "chat:addMessage", sender, {
            type = "HATA",
            typeColor = "#ef4444",
            header = "SİSTEM",
            content = "Bilinmeyen komut: /" .. tostring(cmdName)
        })
    end
end)

function addMessage(target, messageData)
    if target == root or target == nil then
        triggerClientEvent(root, "chat:addMessage", root, messageData)
    elseif isElement(target) and getElementType(target) == "player" then
        triggerClientEvent(target, "chat:addMessage", target, messageData)
    end
end

function addSuggestion(target, name, help, params)
    if target == root or target == nil then
        triggerClientEvent(root, "chat:addSuggestion", root, name, help, params)
    elseif isElement(target) and getElementType(target) == "player" then
        triggerClientEvent(target, "chat:addSuggestion", target, name, help, params)
    end
end

function clearChat(target)
    if target == root or target == nil then
        triggerClientEvent(root, "chat:client:ClearChat", root)
    elseif isElement(target) and getElementType(target) == "player" then
        triggerClientEvent(target, "chat:client:ClearChat", target)
    end
end