local screenW, screenH = guiGetScreenSize()
local baseW, baseH = 1920, 1080
local scale = math.min(screenW / baseW, screenH / baseH)
scale = math.max(0.75, math.min(1.2, scale))

local radioVisible = false
local animProgress = 0
local targetProgress = 0
local animSpeed = 0.08
local radioTexture = nil
local activeTab = "members"
local activeInput = nil
local inCreateMode = false
local passwordMode = false
local isConnected = false
local currentFrequency = "00.0"
local inputFrequency = "00.0"
local inputPassword = ""
local createFrequency = ""
local createPassword = ""
local isFavorite = false
local favoriteChannels = {}
local channelMembers = {}
local talkingMembers = {}
local memberScroll = 0
local channelScroll = 0
local floatMinimized = false
local currentVolume = (RadioConfig and RadioConfig.DefaultVolume) or 50
local lastRequestTick = 0
local reqCounter = 0
local pendingRequests = {}
local svgIcons = {}

local devW = math.floor(390 * scale)
local devH = math.floor(devW * (761 / 419))
local devX = screenW - devW - math.floor(35 * scale)

local scrX = devX + math.floor(devW * (118 / 419))
local scrY = 0
local scrW = math.floor(devW * (215 / 419))
local scrH = math.floor(devH * (420 / 761))

local fontCache = {}
local svgCache = {}

local function getSafeFont(weight, size)
    local scaledSize = math.max(7, math.floor(size * scale))
    local key = weight .. "_" .. scaledSize
    if fontCache[key] then
        return fontCache[key]
    end
    if exports.gzl_ui and exports.gzl_ui.getFont then
        local font = exports.gzl_ui:getFont(weight, scaledSize)
        if font then
            fontCache[key] = font
            return font
        end
    end
    fontCache[key] = "default-bold"
    return "default-bold"
end

local function getCircleSVG(diameter)
    local key = "c_" .. diameter
    if not svgCache[key] or not isElement(svgCache[key]) then
        local r = diameter * 0.5
        local svgData = string.format([[<svg width="%d" height="%d" viewBox="0 0 %d %d" fill="none" xmlns="http://www.w3.org/2000/svg"><circle cx="%.1f" cy="%.1f" r="%.1f" fill="#FFFFFF"/></svg>]], diameter, diameter, diameter, diameter, r, r, r)
        svgCache[key] = svgCreate(diameter, diameter, svgData)
    end
    return svgCache[key]
end

local function getRoundedRectSVG(w, h, radius)
    local key = "r_" .. w .. "_" .. h .. "_" .. radius
    if not svgCache[key] or not isElement(svgCache[key]) then
        local svgData = string.format([[<svg width="%d" height="%d" viewBox="0 0 %d %d" fill="none" xmlns="http://www.w3.org/2000/svg"><rect width="%d" height="%d" rx="%d" ry="%d" fill="#FFFFFF"/></svg>]], w, h, w, h, w, h, radius, radius)
        svgCache[key] = svgCreate(w, h, svgData)
    end
    return svgCache[key]
end

local function getGlassPanelSVG(w, h, radius)
    local key = "g_" .. w .. "_" .. h .. "_" .. radius
    if not svgCache[key] or not isElement(svgCache[key]) then
        local strokeW = 1.0
        local innerW = w - strokeW
        local innerH = h - strokeW
        local svgData = string.format([[<svg width="%d" height="%d" viewBox="0 0 %d %d" fill="none" xmlns="http://www.w3.org/2000/svg"><defs><linearGradient id="pBg" x1="0%%" y1="0%%" x2="0%%" y2="100%%"><stop offset="0%%" stop-color="#121620" stop-opacity="0.94"/><stop offset="100%%" stop-color="#0b0f17" stop-opacity="0.98"/></linearGradient><linearGradient id="pBrd" x1="0%%" y1="0%%" x2="0%%" y2="100%%"><stop offset="0%%" stop-color="#ffffff" stop-opacity="0.14"/><stop offset="50%%" stop-color="#ffffff" stop-opacity="0.04"/><stop offset="100%%" stop-color="#ffffff" stop-opacity="0.02"/></linearGradient></defs><rect x="%.2f" y="%.2f" width="%.2f" height="%.2f" rx="%.1f" ry="%.1f" fill="url(#pBg)" stroke="url(#pBrd)" stroke-width="%.2f"/></svg>]], w, h, w, h, strokeW/2, strokeW/2, innerW, innerH, radius, radius, strokeW)
        svgCache[key] = svgCreate(w, h, svgData)
    end
    return svgCache[key]
end

local function drawCircle(cx, cy, radius, color, postGUI)
    if not radius or radius <= 0 then return end
    local d = math.max(2, math.floor(radius * 2 + 0.5))
    local svg = getCircleSVG(d)
    local drawX = math.floor(cx - d * 0.5)
    local drawY = math.floor(cy - d * 0.5)
    if svg then
        dxDrawImage(drawX, drawY, d, d, svg, 0, 0, 0, color or tocolor(255, 255, 255, 255), postGUI or false)
    else
        dxDrawRectangle(drawX, drawY, d, d, color or tocolor(255, 255, 255, 255), postGUI or false)
    end
end

local function drawRoundedRectangle(x, y, w, h, radius, color, postGUI)
    w, h = math.max(1, math.floor(w)), math.max(1, math.floor(h))
    radius = math.max(0, math.min(math.floor(radius or 4), math.floor(w * 0.5), math.floor(h * 0.5)))
    if radius <= 0 then
        dxDrawRectangle(x, y, w, h, color or tocolor(255, 255, 255, 255), postGUI or false)
        return
    end
    local svg = getRoundedRectSVG(w, h, radius)
    if svg then
        dxDrawImage(x, y, w, h, svg, 0, 0, 0, color or tocolor(255, 255, 255, 255), postGUI or false)
    else
        dxDrawRectangle(x, y, w, h, color or tocolor(255, 255, 255, 255), postGUI or false)
    end
end

local function drawGlassPanel(x, y, w, h, radius, postGUI)
    w, h = math.max(1, math.floor(w)), math.max(1, math.floor(h))
    radius = math.max(2, math.floor(radius or 10))
    local svg = getGlassPanelSVG(w, h, radius)
    if svg then
        dxDrawImage(x, y, w, h, svg, 0, 0, 0, tocolor(255, 255, 255, 255), postGUI or false)
    else
        drawRoundedRectangle(x, y, w, h, radius, tocolor(15, 20, 30, 240), postGUI)
    end
end

local function drawRoundedBorder(x, y, w, h, radius, color, thickness, postGUI)
    local th = thickness or 1
    dxDrawRectangle(x, y, w, th, color, postGUI)
    dxDrawRectangle(x, y + h - th, w, th, color, postGUI)
    dxDrawRectangle(x, y, th, h, color, postGUI)
    dxDrawRectangle(x + w - th, y, th, h, color, postGUI)
end

local function isMouseIn(x, y, w, h)
    if not isCursorShowing() then return false end
    local cx, cy = getCursorPosition()
    if not cx or not cy then return false end
    cx, cy = cx * screenW, cy * screenH
    return cx >= x and cx <= x + w and cy >= y and cy <= y + h
end

local function showToast(message, toastType)
    if exports.gzl_ui and exports.gzl_ui.showToast then
        exports.gzl_ui:showToast(tostring(message), toastType or "info", 3000)
        return
    end
    outputChatBox("#38bdf8[TELSİZ] #ffffff" .. tostring(message), 255, 255, 255, true)
end

local function loadTextures()
    if not radioTexture or not isElement(radioTexture) then
        if fileExists("html/public/telsiz-bg.png") then
            radioTexture = dxCreateTexture("html/public/telsiz-bg.png", "argb", true, "clamp")
        end
    end
end

local function startRadioAnim()
    if isPedInVehicle(localPlayer) then return end
    setPedAnimation(localPlayer, "ped", "phone_talk", -1, true, false, false, false)
end

local function stopRadioAnim()
    setPedAnimation(localPlayer, false)
end

local function sendServerRequest(action, data, callback)
    local now = getTickCount()
    if now - lastRequestTick < (RadioConfig and RadioConfig.RequestCooldown or 150) then
        showToast("Biraz yavaşlayın.", "warning")
        return
    end
    lastRequestTick = now
    reqCounter = reqCounter + 1
    local reqId = reqCounter
    if callback then
        pendingRequests[reqId] = callback
    end
    triggerServerEvent("gzl_radio:request", resourceRoot, reqId, action, data or {})
end

function openRadioInterface()
    if radioVisible then return end
    loadTextures()
    radioVisible = true
    targetProgress = 1
    showCursor(true, true)
    pcall(guiSetInputMode, "no_binds_when_editing")
    startRadioAnim()
    sendServerRequest("bootstrap", {}, function(res)
        if res and res.ok then
            if res.frequency then
                isConnected = true
                currentFrequency = tostring(res.frequency)
                inputFrequency = currentFrequency
                isFavorite = res.favorite == true
                channelMembers = res.members or {}
            end
            favoriteChannels = res.favorites or {}
        end
    end)
end

function closeRadioInterface()
    if not radioVisible then return end
    targetProgress = 0
    activeInput = nil
    showCursor(false)
    pcall(guiSetInputMode, "allow_binds")
    stopRadioAnim()
end

function toggleRadio(state)
    if state == nil then state = not radioVisible end
    if state then
        openRadioInterface()
    else
        closeRadioInterface()
    end
    return radioVisible
end

function isRadioOpen()
    return radioVisible == true
end

local function triggerConnect()
    local freq = inputFrequency:match("^%s*(.-)%s*$")
    if not freq or freq == "" or freq == "00.0" then
        showToast("Geçerli bir frekans girin.", "warning")
        return
    end
    if passwordMode then
        local pass = inputPassword:match("^%s*(.-)%s*$")
        if not pass or pass == "" then
            showToast("Kanal şifresini girin.", "warning")
            return
        end
        sendServerRequest("password", { frequency = currentFrequency, password = pass }, function(res)
            if res and res.ok then
                isConnected = true
                passwordMode = false
                inputPassword = ""
                isFavorite = res.favorite == true
                favoriteChannels = res.favorites or favoriteChannels
                channelMembers = res.members or {}
                setElementData(localPlayer, "radio:channel", currentFrequency, false)
                showToast(res.message or "Telsiz bağlantısı kuruldu.", "success")
            else
                inputPassword = ""
                showToast(res and res.message or "Şifre yanlış.", "error")
            end
        end)
    else
        sendServerRequest("connect", { frequency = freq }, function(res)
            if res and res.ok then
                if res.status == "password" then
                    passwordMode = true
                    currentFrequency = tostring(res.frequency)
                    inputPassword = ""
                    activeInput = "password"
                    showToast("Bu kanal şifreli. Şifreyi girin.", "info")
                else
                    isConnected = true
                    currentFrequency = tostring(res.frequency)
                    inputFrequency = currentFrequency
                    isFavorite = res.favorite == true
                    favoriteChannels = res.favorites or favoriteChannels
                    channelMembers = res.members or {}
                    setElementData(localPlayer, "radio:channel", currentFrequency, false)
                    showToast(res.message or "Telsiz bağlantısı kuruldu.", "success")
                end
            else
                showToast(res and res.message or "Bağlantı kurulamadı.", "error")
            end
        end)
    end
end

local function triggerDisconnect()
    sendServerRequest("disconnect", {}, function(res)
        if res and res.ok then
            isConnected = false
            currentFrequency = "00.0"
            inputFrequency = "00.0"
            inputPassword = ""
            passwordMode = false
            isFavorite = false
            channelMembers = {}
            talkingMembers = {}
            setElementData(localPlayer, "radio:channel", false, false)
            showToast("Telsiz bağlantısı kesildi.", "info")
        else
            showToast(res and res.message or "Bağlantı kesilemedi.", "error")
        end
    end)
end

local function triggerCreateChannel()
    local freq = createFrequency:match("^%s*(.-)%s*$")
    local pass = createPassword:match("^%s*(.-)%s*$")
    if not freq or freq == "" then
        showToast("Geçerli bir frekans girin.", "warning")
        return
    end
    sendServerRequest("createChannel", { frequency = freq, password = pass ~= "" and pass or nil }, function(res)
        if res and res.ok then
            isConnected = true
            currentFrequency = tostring(res.frequency)
            inputFrequency = currentFrequency
            createFrequency = ""
            createPassword = ""
            inCreateMode = false
            activeTab = "members"
            isFavorite = res.favorite == true
            favoriteChannels = res.favorites or favoriteChannels
            channelMembers = res.members or {}
            setElementData(localPlayer, "radio:channel", currentFrequency, false)
            showToast("Kanal başarıyla oluşturuldu.", "success")
        else
            showToast(res and res.message or "Kanal oluşturulamadı.", "error")
        end
    end)
end

local function triggerFavoriteToggle(targetFreq)
    local freq = targetFreq or currentFrequency
    if not freq or freq == "00.0" then return end
    sendServerRequest("favorite", { frequency = freq }, function(res)
        if res and res.ok then
            if res.frequency == currentFrequency then
                isFavorite = res.favorite == true
            end
            favoriteChannels = res.favorites or favoriteChannels
            showToast(res.message or "Favoriler güncellendi.", "info")
        end
    end)
end

local function triggerVolume(increase)
    local newVol = math.max(0, math.min(100, currentVolume + (increase and 10 or -10)))
    currentVolume = newVol
    playSoundFrontEnd(41)
    showToast("Telsiz Sesi: %" .. currentVolume, "info")
end

local function renderRadioDevice()
    if animProgress <= 0.005 and targetProgress == 0 then
        if radioVisible then
            radioVisible = false
        end
        return
    end

    local offY = screenH + math.floor(30 * scale)
    local openY = screenH - devH + math.floor(45 * scale)
    local curDevY = interpolateBetween(offY, 0, 0, openY, 0, 0, animProgress, "OutQuad")
    local curScrY = curDevY + math.floor(devH * (236 / 761))

    if radioTexture and isElement(radioTexture) then
        dxDrawImage(devX, curDevY, devW, devH, radioTexture, 0, 0, 0, tocolor(255, 255, 255, 255))
    end

    drawRoundedRectangle(scrX, curScrY, scrW, scrH, math.floor(10 * scale), tocolor(15, 19, 26, 252))
    drawRoundedBorder(scrX, curScrY, scrW, scrH, math.floor(10 * scale), tocolor(255, 255, 255, 22), 1)

    local timeT = getRealTime()
    local clockStr = string.format("%02d:%02d", timeT.hour, timeT.minute)
    dxDrawText(clockStr, scrX + math.floor(12 * scale), curScrY + math.floor(7 * scale), 0, 0, tocolor(240, 245, 255, 220), 1, getSafeFont("medium", 10), "left", "top")

    local sigX = scrX + scrW - math.floor(46 * scale)
    local sigY = curScrY + math.floor(10 * scale)
    for i = 1, 4 do
        local barH = math.floor((2 + i * 2.2) * scale)
        local barColor = isConnected and tocolor(74, 222, 128, 220) or tocolor(148, 163, 184, 120)
        drawRoundedRectangle(sigX + (i - 1) * math.floor(4 * scale), sigY + math.floor(9 * scale) - barH, math.floor(2.5 * scale), barH, 1, barColor)
    end

    local batX = scrX + scrW - math.floor(24 * scale)
    local batY = curScrY + math.floor(10 * scale)
    drawRoundedRectangle(batX, batY, math.floor(14 * scale), math.floor(8 * scale), 2, tocolor(255, 255, 255, 80))
    drawRoundedRectangle(batX + math.floor(2 * scale), batY + math.floor(2 * scale), math.floor(8 * scale), math.floor(4 * scale), 1, tocolor(74, 222, 128, 220))
    drawRoundedRectangle(batX + math.floor(14 * scale), batY + math.floor(2.5 * scale), math.floor(1.5 * scale), math.floor(3 * scale), 1, tocolor(255, 255, 255, 80))

    local barX = scrX + math.floor(10 * scale)
    local barY = curScrY + math.floor(26 * scale)
    local barW = scrW - math.floor(20 * scale)
    local barH = math.floor(26 * scale)
    drawRoundedRectangle(barX, barY, barW, barH, math.floor(13 * scale), tocolor(214, 235, 255, 20))

    local tabW = math.floor((barW - math.floor(4 * scale)) / 2)
    local tab1X = barX + math.floor(2 * scale)
    local tab2X = tab1X + tabW
    local tabY = barY + math.floor(2 * scale)
    local tabH = barH - math.floor(4 * scale)

    if activeTab == "channels" then
        drawRoundedRectangle(tab1X, tabY, tabW, tabH, math.floor(11 * scale), tocolor(190, 220, 255, 240))
        dxDrawText("Channels", tab1X, tabY, tab1X + tabW, tabY + tabH, tocolor(15, 20, 30, 240), 1, getSafeFont("bold", 10), "center", "center")
        dxDrawText("Members", tab2X, tabY, tab2X + tabW, tabY + tabH, tocolor(190, 220, 255, 180), 1, getSafeFont("medium", 10), "center", "center")
    else
        drawRoundedRectangle(tab2X, tabY, tabW, tabH, math.floor(11 * scale), tocolor(190, 220, 255, 240))
        dxDrawText("Channels", tab1X, tabY, tab1X + tabW, tabY + tabH, tocolor(190, 220, 255, 180), 1, getSafeFont("medium", 10), "center", "center")
        dxDrawText("Members", tab2X, tabY, tab2X + tabW, tabY + tabH, tocolor(15, 20, 30, 240), 1, getSafeFont("bold", 10), "center", "center")
    end

    if activeTab == "members" then
        local cardX = scrX + math.floor(10 * scale)
        local cardY = curScrY + math.floor(58 * scale)
        local cardW = scrW - math.floor(20 * scale)
        local cardH = math.floor(124 * scale)

        drawRoundedRectangle(cardX, cardY, cardW, cardH, math.floor(8 * scale), tocolor(22, 27, 36, 220))
        drawRoundedBorder(cardX, cardY, cardW, cardH, math.floor(8 * scale), tocolor(255, 255, 255, 15), 1)

        if passwordMode then
            local backX = cardX + math.floor(8 * scale)
            local backY = cardY + math.floor(8 * scale)
            local backSize = math.floor(20 * scale)
            local backHov = isMouseIn(backX, backY, backSize, backSize)
            drawRoundedRectangle(backX, backY, backSize, backSize, math.floor(4 * scale), backHov and tocolor(56, 189, 248, 80) or tocolor(255, 255, 255, 20))
            dxDrawText("<", backX, backY, backX + backSize, backY + backSize, tocolor(240, 245, 255, 220), 1, getSafeFont("bold", 11), "center", "center")
        end

        local favX = cardX + cardW - math.floor(48 * scale)
        local favY = cardY + math.floor(8 * scale)
        local favSize = math.floor(20 * scale)
        local favHov = isMouseIn(favX, favY, favSize, favSize)
        drawRoundedRectangle(favX, favY, favSize, favSize, math.floor(4 * scale), favHov and tocolor(250, 204, 21, 60) or tocolor(255, 255, 255, 14))
        local starColor = isFavorite and tocolor(250, 204, 21, 240) or tocolor(148, 163, 184, 160)
        dxDrawText("★", favX, favY, favX + favSize, favY + favSize, starColor, 1, getSafeFont("bold", 12), "center", "center")

        local conX = cardX + cardW - math.floor(24 * scale)
        local conY = cardY + math.floor(8 * scale)
        local conSize = math.floor(20 * scale)
        drawRoundedRectangle(conX, conY, conSize, conSize, math.floor(4 * scale), tocolor(255, 255, 255, 14))
        local cableColor = isConnected and tocolor(74, 222, 128, 240) or tocolor(148, 163, 184, 120)
        dxDrawText("●", conX, conY, conX + conSize, conY + conSize, cableColor, 1, getSafeFont("bold", 9), "center", "center")

        local labelTitle = passwordMode and "Radio Password;" or "Radio Channel;"
        dxDrawText(labelTitle, cardX + math.floor(10 * scale), cardY + math.floor(32 * scale), 0, 0, tocolor(240, 245, 255, 230), 1, getSafeFont("bold", 10), "left", "top")

        local inpX = cardX + math.floor(8 * scale)
        local inpY = cardY + math.floor(48 * scale)
        local inpW = cardW - math.floor(16 * scale)
        local inpH = math.floor(38 * scale)
        local isFocus = (passwordMode and activeInput == "password") or (not passwordMode and activeInput == "frequency")

        drawRoundedRectangle(inpX, inpY, inpW, inpH, math.floor(6 * scale), tocolor(12, 15, 20, 240))
        drawRoundedBorder(inpX, inpY, inpW, inpH, math.floor(6 * scale), isFocus and tocolor(56, 189, 248, 200) or tocolor(255, 255, 255, 22), 1)

        local dispText = ""
        local placeholder = passwordMode and "Password.." or "00.0"
        if passwordMode then
            if #inputPassword > 0 then
                dispText = string.rep("•", #inputPassword)
            else
                dispText = isFocus and "" or placeholder
            end
        else
            if #inputFrequency > 0 then
                dispText = inputFrequency
            else
                dispText = isFocus and "" or placeholder
            end
        end

        local textColor = (#dispText > 0 and dispText ~= placeholder) and tocolor(190, 220, 255, 240) or tocolor(148, 163, 184, 100)
        if isFocus and (getTickCount() % 1000 < 500) then
            dispText = dispText .. "|"
        end
        dxDrawText(dispText, inpX, inpY + math.floor(4 * scale), inpX + inpW, inpY + inpH - math.floor(12 * scale), textColor, 1, getSafeFont("bold", 13), "center", "center")
        local subLabel = passwordMode and "Password" or "Frequency"
        dxDrawText(subLabel, inpX, inpY + inpH - math.floor(12 * scale), inpX + inpW, inpY + inpH - math.floor(2 * scale), tocolor(190, 220, 255, 90), 1, getSafeFont("regular", 8), "center", "center")

        local btnX = cardX + math.floor(8 * scale)
        local btnY = cardY + math.floor(92 * scale)
        local btnW = cardW - math.floor(16 * scale)
        local btnH = math.floor(24 * scale)
        local btnHov = isMouseIn(btnX, btnY, btnW, btnH)

        if isConnected and not passwordMode then
            local redColor = btnHov and tocolor(244, 63, 94, 255) or tocolor(225, 29, 72, 230)
            drawRoundedRectangle(btnX, btnY, btnW, btnH, math.floor(5 * scale), redColor)
            dxDrawText("Disconnected", btnX, btnY, btnX + btnW, btnY + btnH, tocolor(255, 255, 255, 240), 1, getSafeFont("bold", 10), "center", "center")
        else
            local greenColor = btnHov and tocolor(52, 211, 153, 255) or tocolor(16, 185, 129, 230)
            drawRoundedRectangle(btnX, btnY, btnW, btnH, math.floor(5 * scale), greenColor)
            dxDrawText("Connect", btnX, btnY, btnX + btnW, btnY + btnH, tocolor(255, 255, 255, 240), 1, getSafeFont("bold", 10), "center", "center")
        end

        local mCardX = scrX + math.floor(10 * scale)
        local mCardY = curScrY + math.floor(188 * scale)
        local mCardW = scrW - math.floor(20 * scale)
        local mCardH = scrH - math.floor(196 * scale)

        drawRoundedRectangle(mCardX, mCardY, mCardW, mCardH, math.floor(8 * scale), tocolor(22, 27, 36, 220))
        drawRoundedBorder(mCardX, mCardY, mCardW, mCardH, math.floor(8 * scale), tocolor(255, 255, 255, 15), 1)

        local mhzLabel = isConnected and (currentFrequency .. "Mhz") or "00.0Mhz"
        dxDrawText(mhzLabel, mCardX + math.floor(8 * scale), mCardY + math.floor(6 * scale), 0, 0, tocolor(190, 220, 255, 240), 1, getSafeFont("bold", 10), "left", "top")
        dxDrawText("Member List", mCardX + math.floor(75 * scale), mCardY + math.floor(7 * scale), 0, 0, tocolor(148, 163, 184, 140), 1, getSafeFont("medium", 9), "left", "top")

        local listY = mCardY + math.floor(26 * scale)
        local listH = mCardH - math.floor(32 * scale)
        local rowH = math.floor(22 * scale)
        local rowGap = math.floor(3 * scale)
        local maxVisible = math.floor(listH / (rowH + rowGap))

        if #channelMembers == 0 then
            dxDrawText(isConnected and "Kanalda kimse yok." or "Aktif frekans yok.", mCardX, listY, mCardX + mCardW, listY + listH, tocolor(148, 163, 184, 120), 1, getSafeFont("regular", 9), "center", "center")
        else
            local startIdx = memberScroll + 1
            local endIdx = math.min(#channelMembers, startIdx + maxVisible - 1)
            local curRowY = listY

            for i = startIdx, endIdx do
                local member = channelMembers[i]
                if member then
                    local isTalking = talkingMembers[tostring(member.id)] == true
                    local rowX = mCardX + math.floor(6 * scale)
                    local rowW = mCardW - math.floor(12 * scale)
                    local rowBg = isTalking and tocolor(16, 185, 129, 70) or tocolor(14, 18, 25, 200)

                    drawRoundedRectangle(rowX, curRowY, rowW, rowH, math.floor(4 * scale), rowBg)
                    drawRoundedBorder(rowX, curRowY, rowW, rowH, math.floor(4 * scale), isTalking and tocolor(52, 211, 153, 180) or tocolor(255, 255, 255, 10), 1)

                    dxDrawText(member.name or "Bilinmiyor", rowX + math.floor(6 * scale), curRowY, rowX + rowW - math.floor(24 * scale), curRowY + rowH, tocolor(240, 245, 255, 230), 1, getSafeFont("medium", 9), "left", "center", true)

                    local micDotX = rowX + rowW - math.floor(14 * scale)
                    local micDotY = curRowY + math.floor(rowH / 2)
                    local micColor = isTalking and tocolor(52, 211, 153, 255) or tocolor(148, 163, 184, 90)
                    drawCircle(micDotX, micDotY, math.floor(3.5 * scale), micColor)

                    curRowY = curRowY + rowH + rowGap
                end
            end
        end
    else
        local cCardX = scrX + math.floor(10 * scale)
        local cCardY = curScrY + math.floor(58 * scale)
        local cCardW = scrW - math.floor(20 * scale)
        local cCardH = scrH - math.floor(66 * scale)

        drawRoundedRectangle(cCardX, cCardY, cCardW, cCardH, math.floor(8 * scale), tocolor(22, 27, 36, 220))
        drawRoundedBorder(cCardX, cCardY, cCardW, cCardH, math.floor(8 * scale), tocolor(255, 255, 255, 15), 1)

        dxDrawText("Channels", cCardX + math.floor(8 * scale), cCardY + math.floor(6 * scale), 0, 0, tocolor(240, 245, 255, 240), 1, getSafeFont("bold", 11), "left", "top")
        dxDrawText(inCreateMode and "Kanal Kur" or "Kanal Listesi", cCardX + math.floor(8 * scale), cCardY + math.floor(20 * scale), 0, 0, tocolor(148, 163, 184, 140), 1, getSafeFont("regular", 8), "left", "top")

        local togBtnX = cCardX + cCardW - math.floor(70 * scale)
        local togBtnY = cCardY + math.floor(8 * scale)
        local togBtnW = math.floor(62 * scale)
        local togBtnH = math.floor(20 * scale)
        local togBtnHov = isMouseIn(togBtnX, togBtnY, togBtnW, togBtnH)
        local togBg = inCreateMode and tocolor(56, 189, 248, 200) or (togBtnHov and tocolor(74, 222, 128, 180) or tocolor(74, 222, 128, 40))
        local togTextCol = inCreateMode and tocolor(15, 23, 42, 255) or (togBtnHov and tocolor(15, 23, 42, 255) or tocolor(74, 222, 128, 240))

        drawRoundedRectangle(togBtnX, togBtnY, togBtnW, togBtnH, math.floor(4 * scale), togBg)
        dxDrawText(inCreateMode and "Listeye Dön" or "Kanal Aç", togBtnX, togBtnY, togBtnX + togBtnW, togBtnY + togBtnH, togTextCol, 1, getSafeFont("bold", 8), "center", "center")

        local contentY = cCardY + math.floor(34 * scale)
        local contentH = cCardH - math.floor(40 * scale)

        if inCreateMode then
            dxDrawText("Frekans:", cCardX + math.floor(10 * scale), contentY + math.floor(10 * scale), 0, 0, tocolor(190, 220, 255, 220), 1, getSafeFont("medium", 9), "left", "top")
            local fInpX = cCardX + math.floor(10 * scale)
            local fInpY = contentY + math.floor(26 * scale)
            local fInpW = cCardW - math.floor(20 * scale)
            local fInpH = math.floor(28 * scale)
            local fFocus = (activeInput == "createFreq")

            drawRoundedRectangle(fInpX, fInpY, fInpW, fInpH, math.floor(5 * scale), tocolor(12, 15, 20, 240))
            drawRoundedBorder(fInpX, fInpY, fInpW, fInpH, math.floor(5 * scale), fFocus and tocolor(56, 189, 248, 200) or tocolor(255, 255, 255, 20), 1)
            local fText = #createFrequency > 0 and createFrequency or (fFocus and "" or "00.0")
            if fFocus and (getTickCount() % 1000 < 500) then fText = fText .. "|" end
            dxDrawText(fText, fInpX + math.floor(8 * scale), fInpY, fInpX + fInpW - math.floor(8 * scale), fInpY + fInpH, tocolor(240, 245, 255, 230), 1, getSafeFont("bold", 10), "left", "center")

            dxDrawText("Kanal Şifresi (Opsiyonel):", cCardX + math.floor(10 * scale), contentY + math.floor(64 * scale), 0, 0, tocolor(190, 220, 255, 220), 1, getSafeFont("medium", 9), "left", "top")
            local pInpX = cCardX + math.floor(10 * scale)
            local pInpY = contentY + math.floor(80 * scale)
            local pInpW = cCardW - math.floor(20 * scale)
            local pInpH = math.floor(28 * scale)
            local pFocus = (activeInput == "createPass")

            drawRoundedRectangle(pInpX, pInpY, pInpW, pInpH, math.floor(5 * scale), tocolor(12, 15, 20, 240))
            drawRoundedBorder(pInpX, pInpY, pInpW, pInpH, math.floor(5 * scale), pFocus and tocolor(56, 189, 248, 200) or tocolor(255, 255, 255, 20), 1)
            local pText = #createPassword > 0 and createPassword or (pFocus and "" or "Şifre...")
            if pFocus and (getTickCount() % 1000 < 500) then pText = pText .. "|" end
            dxDrawText(pText, pInpX + math.floor(8 * scale), pInpY, pInpX + pInpW - math.floor(8 * scale), pInpY + pInpH, tocolor(240, 245, 255, 230), 1, getSafeFont("bold", 10), "left", "center")

            local crtBtnX = cCardX + math.floor(10 * scale)
            local crtBtnY = contentY + math.floor(124 * scale)
            local crtBtnW = cCardW - math.floor(20 * scale)
            local crtBtnH = math.floor(28 * scale)
            local crtHov = isMouseIn(crtBtnX, crtBtnY, crtBtnW, crtBtnH)

            drawRoundedRectangle(crtBtnX, crtBtnY, crtBtnW, crtBtnH, math.floor(6 * scale), crtHov and tocolor(52, 211, 153, 255) or tocolor(16, 185, 129, 230))
            dxDrawText("Kanalı Oluştur", crtBtnX, crtBtnY, crtBtnX + crtBtnW, crtBtnY + crtBtnH, tocolor(255, 255, 255, 240), 1, getSafeFont("bold", 10), "center", "center")
        else
            if #favoriteChannels == 0 then
                dxDrawText("Kayıtlı favori kanalınız yok.\nAna ekranda ★ butonuna\nbasarak kanal ekleyin.", cCardX, contentY, cCardX + cCardW, contentY + contentH, tocolor(148, 163, 184, 140), 1, getSafeFont("regular", 9), "center", "center")
            else
                local cRowH = math.floor(28 * scale)
                local cRowGap = math.floor(4 * scale)
                local maxVisibleC = math.floor(contentH / (cRowH + cRowGap))
                local startIdxC = channelScroll + 1
                local endIdxC = math.min(#favoriteChannels, startIdxC + maxVisibleC - 1)
                local curCRowY = contentY + math.floor(4 * scale)

                for i = startIdxC, endIdxC do
                    local freqStr = tostring(favoriteChannels[i])
                    local rowX = cCardX + math.floor(6 * scale)
                    local rowW = cCardW - math.floor(12 * scale)

                    drawRoundedRectangle(rowX, curCRowY, rowW, cRowH, math.floor(5 * scale), tocolor(14, 18, 25, 220))
                    drawRoundedBorder(rowX, curCRowY, rowW, cRowH, math.floor(5 * scale), tocolor(255, 255, 255, 12), 1)

                    dxDrawText(freqStr .. " Mhz", rowX + math.floor(8 * scale), curCRowY, rowX + rowW - math.floor(50 * scale), curCRowY + cRowH, tocolor(240, 245, 255, 240), 1, getSafeFont("bold", 10), "left", "center")

                    local starBtnX = rowX + rowW - math.floor(46 * scale)
                    local starBtnY = curCRowY + math.floor(4 * scale)
                    local starBtnS = math.floor(20 * scale)
                    local starHov = isMouseIn(starBtnX, starBtnY, starBtnS, starBtnS)
                    drawRoundedRectangle(starBtnX, starBtnY, starBtnS, starBtnS, math.floor(3 * scale), starHov and tocolor(250, 204, 21, 60) or tocolor(255, 255, 255, 12))
                    dxDrawText("★", starBtnX, starBtnY, starBtnX + starBtnS, starBtnY + starBtnS, tocolor(250, 204, 21, 240), 1, getSafeFont("bold", 10), "center", "center")

                    local qkBtnX = rowX + rowW - math.floor(22 * scale)
                    local qkBtnY = curCRowY + math.floor(4 * scale)
                    local qkBtnS = math.floor(20 * scale)
                    local qkHov = isMouseIn(qkBtnX, qkBtnY, qkBtnS, qkBtnS)
                    drawRoundedRectangle(qkBtnX, qkBtnY, qkBtnS, qkBtnS, math.floor(3 * scale), qkHov and tocolor(52, 211, 153, 240) or tocolor(16, 185, 129, 180))
                    dxDrawText("▶", qkBtnX, qkBtnY, qkBtnX + qkBtnS, qkBtnY + qkBtnS, tocolor(255, 255, 255, 240), 1, getSafeFont("bold", 8), "center", "center")

                    curCRowY = curCRowY + cRowH + cRowGap
                end
            end
        end
    end

    local volUpX = devX + math.floor(devW * (71 / 419))
    local volUpY = curDevY + math.floor(devH * (498 / 761))
    local volDownX = devX + math.floor(devW * (71 / 419))
    local volDownY = curDevY + math.floor(devH * (538 / 761))
    local volBtnS = math.floor(28 * scale)

    if isMouseIn(volUpX, volUpY, volBtnS, volBtnS) then
        drawRoundedRectangle(volUpX, volUpY, volBtnS, volBtnS, math.floor(4 * scale), tocolor(56, 189, 248, 50))
    end
    if isMouseIn(volDownX, volDownY, volBtnS, volDownY) then
        drawRoundedRectangle(volDownX, volDownY, volBtnS, volBtnS, math.floor(4 * scale), tocolor(56, 189, 248, 50))
    end
end

local function renderFloatingWidget()
    if not isConnected or animProgress > 0.05 then return end

    local floatW = math.floor(240 * scale)
    local floatX = math.floor((screenW - floatW) / 2)
    local floatY = math.floor(15 * scale)
    local headerH = math.floor(32 * scale)

    local visibleMembers = #channelMembers
    local bodyH = (floatMinimized or visibleMembers == 0) and 0 or (visibleMembers * math.floor(22 * scale) + math.floor(8 * scale))
    local totalH = headerH + bodyH

    drawGlassPanel(floatX, floatY, floatW, totalH, math.floor(8 * scale))
    drawRoundedBorder(floatX, floatY, floatW, totalH, math.floor(8 * scale), tocolor(255, 255, 255, 18), 1)

    drawCircle(floatX + math.floor(14 * scale), floatY + math.floor(headerH / 2), math.floor(4 * scale), tocolor(52, 211, 153, 240))
    local titleText = "Telsiz: " .. tostring(currentFrequency) .. " Mhz"
    dxDrawText(titleText, floatX + math.floor(24 * scale), floatY, floatX + floatW - math.floor(55 * scale), floatY + headerH, tocolor(240, 245, 255, 230), 1, getSafeFont("bold", 9), "left", "center", true)

    local badgeX = floatX + floatW - math.floor(48 * scale)
    local badgeY = floatY + math.floor(6 * scale)
    local badgeW = math.floor(22 * scale)
    local badgeH = math.floor(20 * scale)
    drawRoundedRectangle(badgeX, badgeY, badgeW, badgeH, math.floor(4 * scale), tocolor(16, 185, 129, 40))
    dxDrawText(tostring(visibleMembers), badgeX, badgeY, badgeX + badgeW, badgeY + badgeH, tocolor(52, 211, 153, 240), 1, getSafeFont("bold", 9), "center", "center")

    local togX = floatX + floatW - math.floor(22 * scale)
    local togY = floatY + math.floor(6 * scale)
    local togS = math.floor(18 * scale)
    dxDrawText(floatMinimized and "+" or "−", togX, togY, togX + togS, togY + togS, tocolor(148, 163, 184, 180), 1, getSafeFont("bold", 10), "center", "center")

    if not floatMinimized and visibleMembers > 0 then
        local curRowY = floatY + headerH + math.floor(4 * scale)
        local rowH = math.floor(20 * scale)

        for _, member in ipairs(channelMembers) do
            local isTalking = talkingMembers[tostring(member.id)] == true
            local rowX = floatX + math.floor(8 * scale)
            local rowW = floatW - math.floor(16 * scale)
            local rowBg = isTalking and tocolor(16, 185, 129, 60) or tocolor(255, 255, 255, 8)

            drawRoundedRectangle(rowX, curRowY, rowW, rowH, math.floor(4 * scale), rowBg)
            local mName = tostring(member.name or "Bilinmiyor"):gsub("_", " ")
            dxDrawText(mName, rowX + math.floor(6 * scale), curRowY, rowX + rowW - math.floor(20 * scale), curRowY + rowH, tocolor(240, 245, 255, 220), 1, getSafeFont("medium", 8.5), "left", "center", true)

            local micColor = isTalking and tocolor(52, 211, 153, 255) or tocolor(148, 163, 184, 90)
            drawCircle(rowX + rowW - math.floor(10 * scale), curRowY + math.floor(rowH / 2), math.floor(3 * scale), micColor)

            curRowY = curRowY + rowH + math.floor(2 * scale)
        end
    end
end

addEventHandler("onClientRender", root, function()
    if animProgress ~= targetProgress then
        animProgress = animProgress + (targetProgress - animProgress) * animSpeed
        if math.abs(targetProgress - animProgress) < 0.005 then
            animProgress = targetProgress
        end
    end

    if animProgress > 0.005 or targetProgress > 0 then
        renderRadioDevice()
    end
    if isConnected and animProgress <= 0.05 then
        renderFloatingWidget()
    end
end)

addEventHandler("onClientClick", root, function(button, state)
    if state ~= "down" or button ~= "left" then return end

    if isConnected and animProgress <= 0.05 then
        local floatW = math.floor(240 * scale)
        local floatX = math.floor((screenW - floatW) / 2)
        local floatY = math.floor(15 * scale)
        local headerH = math.floor(32 * scale)
        if isMouseIn(floatX + floatW - math.floor(26 * scale), floatY + math.floor(4 * scale), math.floor(24 * scale), math.floor(24 * scale)) then
            floatMinimized = not floatMinimized
            playSoundFrontEnd(41)
            return
        end
    end

    if animProgress < 0.5 then return end

    local offY = screenH + math.floor(30 * scale)
    local openY = screenH - devH + math.floor(45 * scale)
    local curDevY = interpolateBetween(offY, 0, 0, openY, 0, 0, animProgress, "OutQuad")
    local curScrY = curDevY + math.floor(devH * (236 / 761))

    local volUpX = devX + math.floor(devW * (71 / 419))
    local volUpY = curDevY + math.floor(devH * (498 / 761))
    local volDownX = devX + math.floor(devW * (71 / 419))
    local volDownY = curDevY + math.floor(devH * (538 / 761))
    local volBtnS = math.floor(28 * scale)

    if isMouseIn(volUpX, volUpY, volBtnS, volBtnS) then
        triggerVolume(true)
        return
    elseif isMouseIn(volDownX, volDownY, volBtnS, volBtnS) then
        triggerVolume(false)
        return
    end

    local barX = scrX + math.floor(10 * scale)
    local barY = curScrY + math.floor(26 * scale)
    local barW = scrW - math.floor(20 * scale)
    local barH = math.floor(26 * scale)
    local tabW = math.floor((barW - math.floor(4 * scale)) / 2)
    local tab1X = barX + math.floor(2 * scale)
    local tab2X = tab1X + tabW
    local tabY = barY + math.floor(2 * scale)
    local tabH = barH - math.floor(4 * scale)

    if isMouseIn(tab1X, tabY, tabW, tabH) then
        activeTab = "channels"
        activeInput = nil
        playSoundFrontEnd(41)
        return
    elseif isMouseIn(tab2X, tabY, tabW, tabH) then
        activeTab = "members"
        activeInput = nil
        playSoundFrontEnd(41)
        return
    end

    if activeTab == "members" then
        local cardX = scrX + math.floor(10 * scale)
        local cardY = curScrY + math.floor(58 * scale)
        local cardW = scrW - math.floor(20 * scale)

        if passwordMode then
            local backX = cardX + math.floor(8 * scale)
            local backY = cardY + math.floor(8 * scale)
            local backSize = math.floor(20 * scale)
            if isMouseIn(backX, backY, backSize, backSize) then
                passwordMode = false
                inputPassword = ""
                activeInput = nil
                playSoundFrontEnd(41)
                return
            end
        end

        local favX = cardX + cardW - math.floor(48 * scale)
        local favY = cardY + math.floor(8 * scale)
        local favSize = math.floor(20 * scale)
        if isMouseIn(favX, favY, favSize, favSize) then
            triggerFavoriteToggle()
            playSoundFrontEnd(41)
            return
        end

        local inpX = cardX + math.floor(8 * scale)
        local inpY = cardY + math.floor(48 * scale)
        local inpW = cardW - math.floor(16 * scale)
        local inpH = math.floor(38 * scale)
        if isMouseIn(inpX, inpY, inpW, inpH) then
            activeInput = passwordMode and "password" or "frequency"
            if not passwordMode and inputFrequency == "00.0" then
                inputFrequency = ""
            end
            playSoundFrontEnd(41)
            return
        end

        local btnX = cardX + math.floor(8 * scale)
        local btnY = cardY + math.floor(90 * scale)
        local btnW = cardW - math.floor(16 * scale)
        local btnH = math.floor(30 * scale)
        if isMouseIn(btnX, btnY, btnW, btnH) then
            playSoundFrontEnd(41)
            if isConnected and not passwordMode then
                triggerDisconnect()
            else
                triggerConnect()
            end
            return
        end

    else
        local cCardX = scrX + math.floor(10 * scale)
        local cCardY = curScrY + math.floor(58 * scale)
        local cCardW = scrW - math.floor(20 * scale)

        local togBtnX = cCardX + cCardW - math.floor(70 * scale)
        local togBtnY = cCardY + math.floor(8 * scale)
        local togBtnW = math.floor(62 * scale)
        local togBtnH = math.floor(20 * scale)
        if isMouseIn(togBtnX, togBtnY, togBtnW, togBtnH) then
            inCreateMode = not inCreateMode
            activeInput = nil
            playSoundFrontEnd(41)
            return
        end

        local contentY = cCardY + math.floor(34 * scale)
        local contentH = (curScrY + scrH - math.floor(66 * scale)) - math.floor(40 * scale)

        if inCreateMode then
            local fInpX = cCardX + math.floor(10 * scale)
            local fInpY = contentY + math.floor(26 * scale)
            local fInpW = cCardW - math.floor(20 * scale)
            local fInpH = math.floor(28 * scale)
            if isMouseIn(fInpX, fInpY, fInpW, fInpH) then
                activeInput = "createFreq"
                playSoundFrontEnd(41)
                return
            end

            local pInpX = cCardX + math.floor(10 * scale)
            local pInpY = contentY + math.floor(80 * scale)
            local pInpW = cCardW - math.floor(20 * scale)
            local pInpH = math.floor(28 * scale)
            if isMouseIn(pInpX, pInpY, pInpW, pInpH) then
                activeInput = "createPass"
                playSoundFrontEnd(41)
                return
            end

            local crtBtnX = cCardX + math.floor(10 * scale)
            local crtBtnY = contentY + math.floor(124 * scale)
            local crtBtnW = cCardW - math.floor(20 * scale)
            local crtBtnH = math.floor(28 * scale)
            if isMouseIn(crtBtnX, crtBtnY, crtBtnW, crtBtnH) then
                playSoundFrontEnd(41)
                triggerCreateChannel()
                return
            end
        else
            if #favoriteChannels > 0 then
                local cRowH = math.floor(28 * scale)
                local cRowGap = math.floor(4 * scale)
                local maxVisibleC = math.floor(contentH / (cRowH + cRowGap))
                local startIdxC = channelScroll + 1
                local endIdxC = math.min(#favoriteChannels, startIdxC + maxVisibleC - 1)
                local curCRowY = contentY + math.floor(4 * scale)

                for i = startIdxC, endIdxC do
                    local freqStr = tostring(favoriteChannels[i])
                    local rowX = cCardX + math.floor(6 * scale)
                    local rowW = cCardW - math.floor(12 * scale)

                    local starBtnX = rowX + rowW - math.floor(46 * scale)
                    local starBtnY = curCRowY + math.floor(4 * scale)
                    local starBtnS = math.floor(20 * scale)
                    if isMouseIn(starBtnX, starBtnY, starBtnS, starBtnS) then
                        playSoundFrontEnd(41)
                        triggerFavoriteToggle(freqStr)
                        return
                    end

                    local qkBtnX = rowX + rowW - math.floor(22 * scale)
                    local qkBtnY = curCRowY + math.floor(4 * scale)
                    local qkBtnS = math.floor(20 * scale)
                    if isMouseIn(qkBtnX, qkBtnY, qkBtnS, qkBtnS) then
                        playSoundFrontEnd(41)
                        inputFrequency = freqStr
                        activeTab = "members"
                        passwordMode = false
                        triggerConnect()
                        return
                    end

                    curCRowY = curCRowY + cRowH + cRowGap
                end
            end
        end
    end

    activeInput = nil
end)

addEventHandler("onClientCharacter", root, function(char)
    if animProgress < 0.5 or not activeInput then return end

    if activeInput == "frequency" then
        if char:match("[%d%.]") and #inputFrequency < 6 then
            inputFrequency = inputFrequency .. char
            playSoundFrontEnd(41)
        end
    elseif activeInput == "password" then
        if #inputPassword < 32 then
            inputPassword = inputPassword .. char
            playSoundFrontEnd(41)
        end
    elseif activeInput == "createFreq" then
        if char:match("[%d%.]") and #createFrequency < 6 then
            createFrequency = createFrequency .. char
            playSoundFrontEnd(41)
        end
    elseif activeInput == "createPass" then
        if #createPassword < 32 then
            createPassword = createPassword .. char
            playSoundFrontEnd(41)
        end
    end
end)

addEventHandler("onClientKey", root, function(button, pressed)
    if not pressed then return end

    if radioVisible and button == "escape" then
        cancelEvent()
        closeRadioInterface()
        return
    end

    if animProgress < 0.5 then return end

    if button == "backspace" then
        if activeInput == "frequency" then
            if #inputFrequency > 0 then
                inputFrequency = inputFrequency:sub(1, -2)
                playSoundFrontEnd(41)
            end
        elseif activeInput == "password" then
            if #inputPassword > 0 then
                inputPassword = inputPassword:sub(1, -2)
                playSoundFrontEnd(41)
            end
        elseif activeInput == "createFreq" then
            if #createFrequency > 0 then
                createFrequency = createFrequency:sub(1, -2)
                playSoundFrontEnd(41)
            end
        elseif activeInput == "createPass" then
            if #createPassword > 0 then
                createPassword = createPassword:sub(1, -2)
                playSoundFrontEnd(41)
            end
        end
    elseif button == "enter" or button == "num_enter" then
        if activeTab == "members" then
            triggerConnect()
        elseif activeTab == "channels" and inCreateMode then
            triggerCreateChannel()
        end
    elseif button == "mouse_wheel_up" then
        if activeTab == "members" then
            memberScroll = math.max(0, memberScroll - 1)
        else
            channelScroll = math.max(0, channelScroll - 1)
        end
    elseif button == "mouse_wheel_down" then
        if activeTab == "members" then
            local maxScroll = math.max(0, #channelMembers - 5)
            memberScroll = math.min(maxScroll, memberScroll + 1)
        else
            local maxScroll = math.max(0, #favoriteChannels - 5)
            channelScroll = math.min(maxScroll, channelScroll + 1)
        end
    end
end)

addEvent("gzl_radio:response", true)
addEventHandler("gzl_radio:response", resourceRoot, function(requestId, data)
    if type(data) ~= "table" then return end
    local cb = pendingRequests[requestId]
    if cb then
        pendingRequests[requestId] = nil
        cb(data)
    elseif data.message then
        showToast(data.message, data.ok and "success" or "error")
    end
end)

addEvent("gzl_radio:state", true)
addEventHandler("gzl_radio:state", resourceRoot, function(data)
    if type(data) ~= "table" then return end
    if data.frequency then
        currentFrequency = tostring(data.frequency)
    end
    if data.members then
        channelMembers = data.members
    end
end)

addEvent("gzl_radio:talking", true)
addEventHandler("gzl_radio:talking", resourceRoot, function(memberId, talking)
    talkingMembers[tostring(memberId)] = (talking == true)
end)

addEvent("gzl_radio:notify", true)
addEventHandler("gzl_radio:notify", resourceRoot, function(message, notificationType)
    showToast(message, notificationType)
end)

addEvent("gzl_radio:forceKick", true)
addEventHandler("gzl_radio:forceKick", resourceRoot, function()
    isConnected = false
    currentFrequency = "00.0"
    inputFrequency = "00.0"
    inputPassword = ""
    passwordMode = false
    isFavorite = false
    channelMembers = {}
    talkingMembers = {}
    setElementData(localPlayer, "radio:channel", false, false)
    closeRadioInterface()
    showToast("Telsiz bağlantınız zorla kesildi.", "error")
end)

addEvent("gzl_radio:open", true)
addEventHandler("gzl_radio:open", resourceRoot, function()
    openRadioInterface()
end)

addEvent("gzl_radio:toggle", true)
addEventHandler("gzl_radio:toggle", root, function(forceState)
    toggleRadio(forceState)
end)

local isRadioPTT = false

local function handleRadioPTT(key, keyState)
    if not isConnected then return end
    if isChatBoxInputActive() or isConsoleActive() then return end

    if keyState == "down" then
        if not isRadioPTT then
            isRadioPTT = true
            playSoundFrontEnd(41)
            triggerServerEvent("gzl_radio:setTalking", resourceRoot, true)
        end
    else
        if isRadioPTT then
            isRadioPTT = false
            playSoundFrontEnd(42)
            triggerServerEvent("gzl_radio:setTalking", resourceRoot, false)
        end
    end
end

local activeTalkingPeds = {}

addEventHandler("onClientElementDataChange", root, function(dataName, oldValue)
    if dataName == "radio:talking" and getElementType(source) == "player" then
        if getElementData(source, "radio:talking") then
            activeTalkingPeds[source] = true
        else
            activeTalkingPeds[source] = nil
        end
    end
end)

addEventHandler("onClientPlayerQuit", root, function()
    activeTalkingPeds[source] = nil
end)

addEventHandler("onClientPedsProcessed", root, function()
    if not next(activeTalkingPeds) then return end
    for ped in pairs(activeTalkingPeds) do
        if isElement(ped) and isElementStreamedIn(ped) and not isPedInVehicle(ped) then
            setElementBoneRotation(ped, 23, 75, -55, 30)
            setElementBoneRotation(ped, 24, 0, 110, -25)
            setElementBoneRotation(ped, 25, 0, 0, 10)
            updateElementRpHAnim(ped)
        elseif not isElement(ped) then
            activeTalkingPeds[ped] = nil
        end
    end
end)

addEventHandler("onClientPlayerWasted", localPlayer, function()
    if isRadioPTT then
        isRadioPTT = false
        triggerServerEvent("gzl_radio:setTalking", resourceRoot, false)
    end
end)

addEventHandler("onClientPlayerVoiceStart", localPlayer, function()
    if isConnected then
        local myId = tostring(getElementData(localPlayer, "character:id") or getElementData(localPlayer, "char:id") or getPlayerSerial(localPlayer))
        talkingMembers[myId] = true
    end
end)

addEventHandler("onClientPlayerVoiceStop", localPlayer, function()
    if isConnected then
        local myId = tostring(getElementData(localPlayer, "character:id") or getElementData(localPlayer, "char:id") or getPlayerSerial(localPlayer))
        talkingMembers[myId] = false
    end
end)

addEventHandler("onClientResourceStart", resourceRoot, function()
    loadTextures()
    bindKey("lalt", "both", handleRadioPTT)
    for _, ped in ipairs(getElementsByType("player")) do
        if getElementData(ped, "radio:talking") then
            activeTalkingPeds[ped] = true
        end
    end
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    unbindKey("lalt", "both", handleRadioPTT)
    if isRadioPTT then
        triggerServerEvent("gzl_radio:setTalking", resourceRoot, false)
    end
    if radioVisible then
        showCursor(false)
        pcall(guiSetInputMode, "allow_binds")
        stopRadioAnim()
    end
    if radioTexture and isElement(radioTexture) then
        destroyElement(radioTexture)
        radioTexture = nil
    end
    for _, svg in pairs(svgCache) do
        if isElement(svg) then destroyElement(svg) end
    end
    svgCache = {}
    fontCache = {}
end)