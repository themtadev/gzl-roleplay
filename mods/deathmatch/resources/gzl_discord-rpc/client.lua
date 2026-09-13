local APP_ID = "1540284970529202246"
local ASSET_LOGO = "logo"

local SERVER_NAME = "GZL Roleplay"
local DISCORD_INVITE = "https://discord.gg/gzl"
local SERVER_CONNECT_URL = "mtasa://127.0.0.1:22003"

local lastActivityTime = getTickCount()
local AFK_TIMEOUT = 3 * 60 * 1000

local function updateActivity()
    lastActivityTime = getTickCount()
end
addEventHandler("onClientCursorMove", root, updateActivity)
addEventHandler("onClientKey", root, updateActivity)
addEventHandler("onClientClick", root, updateActivity)

local function updateDiscordRPC()
    local isLogged = getElementData(localPlayer, "loggedin_character") or getElementData(localPlayer, "character:id")
    local totalPlayers = #getElementsByType("player")
    local isAFK = (getTickCount() - lastActivityTime) > AFK_TIMEOUT

    local details = SERVER_NAME
    local state = "Sunucuya Bağlanıyor..."
    local largeText = SERVER_NAME .. " (" .. totalPlayers .. " Oyuncu)"

    if not isLogged then

        details = SERVER_NAME .. " | " .. totalPlayers .. " Oyuncu"
        state = "Karakter Seçim Ekranında"
    else

        local charName = getElementData(localPlayer, "char:name") or getElementData(localPlayer, "character:name") or getPlayerName(localPlayer)

        charName = tostring(charName):gsub("_", " ")

        details = charName .. " (" .. totalPlayers .. " Oyuncu)"

        if isAFK then

            state = "💤 Boşta (AFK)"
        else
            local x, y, z = getElementPosition(localPlayer)
            local zone = getZoneName(x, y, z, false)
            local city = getZoneName(x, y, z, true)

            if zone == city then
                state = "📍 " .. zone
            else
                state = "📍 " .. zone .. ", " .. city
            end
        end
    end

    if setDiscordRichPresence then
        setDiscordRichPresence(
            details,
            state,
            ASSET_LOGO,
            largeText,
            "",
            ""
        )
    end

    if setDiscordRichPresenceButtons then
        setDiscordRichPresenceButtons(
            1, "Sunucuya Bağlan", SERVER_CONNECT_URL,
            2, "Discord Sunucumuz", DISCORD_INVITE
        )
    end
end

addEventHandler("onClientResourceStart", resourceRoot, function()
    if not setDiscordApplicationID or not setDiscordRichPresence then
        return
    end

    setDiscordApplicationID(APP_ID)
    if setDiscordRichPresenceStartTime then
        setDiscordRichPresenceStartTime(getRealTime().timestamp)
    end

    updateDiscordRPC()

    setTimer(updateDiscordRPC, 5000, 0)
end)