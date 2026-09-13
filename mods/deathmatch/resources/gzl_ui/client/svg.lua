local svgCache = {}

local function createGlassPanelSVG(w, h, r)
    local strokeW = 1.0
    local innerW = w - strokeW
    local innerH = h - strokeW

    local svgData = string.format([[
        <svg width="%d" height="%d" viewBox="0 0 %d %d" fill="none" xmlns="http://www.w3.org/2000/svg">
            <defs>
                <linearGradient id="panelBg" x1="0%%" y1="0%%" x2="0%%" y2="100%%">
                    <stop offset="0%%" stop-color="#121620" stop-opacity="0.94"/>
                    <stop offset="100%%" stop-color="#0b0f17" stop-opacity="0.98"/>
                </linearGradient>
                <linearGradient id="panelBorder" x1="0%%" y1="0%%" x2="0%%" y2="100%%">
                    <stop offset="0%%" stop-color="#ffffff" stop-opacity="0.14"/>
                    <stop offset="50%%" stop-color="#ffffff" stop-opacity="0.04"/>
                    <stop offset="100%%" stop-color="#ffffff" stop-opacity="0.02"/>
                </linearGradient>
            </defs>
            <rect x="%.2f" y="%.2f" width="%.2f" height="%.2f" rx="%.1f" ry="%.1f" fill="url(#panelBg)" stroke="url(#panelBorder)" stroke-width="%.2f"/>
        </svg>
    ]], w, h, w, h, strokeW/2, strokeW/2, innerW, innerH, r, r, strokeW)

    return svgCreate(w, h, svgData)
end

local function createLiquidButtonSVG(w, h, r, theme, state)
    local strokeW = 1.0
    local innerW = w - strokeW
    local innerH = h - strokeW

    local c1, c2
    if theme == "green" or theme == "mint" then
        if state == "hover" then
            c1, c2 = "#10b981", "#059669"
        else
            c1, c2 = "#2dd4bf", "#0d9488"
        end
    elseif theme == "danger" or theme == "red" then
        if state == "hover" then
            c1, c2 = "#f43f5e", "#e11d48"
        else
            c1, c2 = "#e11d48", "#be123c"
        end
    else
        if state == "hover" then
            c1, c2 = "#38bdf8", "#0284c7"
        else
            c1, c2 = "#0284c7", "#0369a1"
        end
    end

    local svgData = string.format([[
        <svg width="%d" height="%d" viewBox="0 0 %d %d" fill="none" xmlns="http://www.w3.org/2000/svg">
            <defs>
                <linearGradient id="btnBg" x1="0%%" y1="0%%" x2="0%%" y2="100%%">
                    <stop offset="0%%" stop-color="%s" stop-opacity="1"/>
                    <stop offset="100%%" stop-color="%s" stop-opacity="1"/>
                </linearGradient>
                <linearGradient id="btnBorder" x1="0%%" y1="0%%" x2="0%%" y2="100%%">
                    <stop offset="0%%" stop-color="#ffffff" stop-opacity="0.35"/>
                    <stop offset="100%%" stop-color="#ffffff" stop-opacity="0.08"/>
                </linearGradient>
            </defs>
            <rect x="%.2f" y="%.2f" width="%.2f" height="%.2f" rx="%.1f" ry="%.1f" fill="url(#btnBg)" stroke="url(#btnBorder)" stroke-width="%.2f"/>
        </svg>
    ]], w, h, w, h, c1, c2, strokeW/2, strokeW/2, innerW, innerH, r, r, strokeW)

    return svgCreate(w, h, svgData)
end

local function createEditBoxSVG(w, h, r, state)
    local strokeW = 1.0
    local innerW = w - strokeW
    local innerH = h - strokeW

    local sColor, sOpacity
    local bg1, bg2 = "#121620", "#0b0f17"

    if state == "active" then
        sColor, sOpacity = "#38bdf8", "0.75"
        bg1, bg2 = "#162030", "#0f1624"
    elseif state == "hover" then
        sColor, sOpacity = "#ffffff", "0.18"
    else
        sColor, sOpacity = "#ffffff", "0.08"
    end

    local svgData = string.format([[
        <svg width="%d" height="%d" viewBox="0 0 %d %d" fill="none" xmlns="http://www.w3.org/2000/svg">
            <defs>
                <linearGradient id="inputBg" x1="0%%" y1="0%%" x2="0%%" y2="100%%">
                    <stop offset="0%%" stop-color="%s" stop-opacity="0.94"/>
                    <stop offset="100%%" stop-color="%s" stop-opacity="0.98"/>
                </linearGradient>
            </defs>
            <rect x="%.2f" y="%.2f" width="%.2f" height="%.2f" rx="%.1f" ry="%.1f" fill="url(#inputBg)" stroke="%s" stroke-opacity="%s" stroke-width="%.2f"/>
        </svg>
    ]], w, h, w, h, bg1, bg2, strokeW/2, strokeW/2, innerW, innerH, r, r, sColor, sOpacity, strokeW)

    return svgCreate(w, h, svgData)
end

local function createDiagonalTabBarSVG(w, h, r, activeTab)
    local strokeW = 1.0
    local innerW = w - strokeW
    local innerH = h - strokeW
    local midX = w * 0.5
    local dx = math.floor(h * 0.42)
    local topX = midX + dx / 2
    local botX = midX - dx / 2

    local activeSnippet = ""
    if activeTab == "login" then
        activeSnippet = string.format([[
            <path d="M %.2f 0.5 L %.2f 0.5 L %.2f %.2f L %.2f %.2f A %.2f %.2f 0 0 1 0.5 %.2f L 0.5 %.2f A %.2f %.2f 0 0 1 %.2f 0.5 Z" fill="url(#tabActiveBg)" stroke="url(#tabActiveBorder)" stroke-width="1.0"/>
        ]], 0.5 + r, topX, botX, h - 0.5, 0.5 + r, h - 0.5, r, r, h - 0.5 - r, 0.5 + r, r, r, 0.5 + r)
    else
        activeSnippet = string.format([[
            <path d="M %.2f 0.5 L %.2f 0.5 A %.2f %.2f 0 0 1 %.2f %.2f L %.2f %.2f A %.2f %.2f 0 0 1 %.2f %.2f L %.2f %.2f Z" fill="url(#tabActiveBg)" stroke="url(#tabActiveBorder)" stroke-width="1.0"/>
        ]], topX, w - 0.5 - r, r, r, w - 0.5, 0.5 + r, w - 0.5, h - 0.5 - r, r, r, w - 0.5 - r, h - 0.5, botX, h - 0.5, topX + 1)
    end

    local svgData = string.format([[
        <svg width="%d" height="%d" viewBox="0 0 %d %d" fill="none" xmlns="http://www.w3.org/2000/svg">
            <defs>
                <linearGradient id="tabBarBg" x1="0%%" y1="0%%" x2="0%%" y2="100%%">
                    <stop offset="0%%" stop-color="#121620" stop-opacity="0.95"/>
                    <stop offset="100%%" stop-color="#0b0f17" stop-opacity="0.98"/>
                </linearGradient>
                <linearGradient id="tabBarBorder" x1="0%%" y1="0%%" x2="0%%" y2="100%%">
                    <stop offset="0%%" stop-color="#ffffff" stop-opacity="0.12"/>
                    <stop offset="100%%" stop-color="#ffffff" stop-opacity="0.02"/>
                </linearGradient>
                <linearGradient id="tabActiveBg" x1="0%%" y1="0%%" x2="0%%" y2="100%%">
                    <stop offset="0%%" stop-color="#38bdf8" stop-opacity="1"/>
                    <stop offset="100%%" stop-color="#0284c7" stop-opacity="1"/>
                </linearGradient>
                <linearGradient id="tabActiveBorder" x1="0%%" y1="0%%" x2="0%%" y2="100%%">
                    <stop offset="0%%" stop-color="#ffffff" stop-opacity="0.45"/>
                    <stop offset="100%%" stop-color="#ffffff" stop-opacity="0.10"/>
                </linearGradient>
            </defs>
            <rect x="0.5" y="0.5" width="%.2f" height="%.2f" rx="%.1f" ry="%.1f" fill="url(#tabBarBg)" stroke="url(#tabBarBorder)" stroke-width="1.0"/>
            %s
        </svg>
    ]], w, h, w, h, innerW, innerH, r, r, activeSnippet)

    return svgCreate(w, h, svgData)
end

local function createNotificationCardSVG(w, h, r, nType)
    local strokeW = 1.0
    local innerW = w - strokeW
    local innerH = h - strokeW

    local accentColor = "#38bdf8"
    if nType == "success" then
        accentColor = "#10b981"
    elseif nType == "error" then
        accentColor = "#f43f5e"
    elseif nType == "warning" then
        accentColor = "#f59e0b"
    end

    local svgData = string.format([[
        <svg width="%d" height="%d" viewBox="0 0 %d %d" fill="none" xmlns="http://www.w3.org/2000/svg">
            <defs>
                <linearGradient id="cardBg" x1="0%%" y1="0%%" x2="100%%" y2="100%%">
                    <stop offset="0%%" stop-color="#131b27" stop-opacity="0.98"/>
                    <stop offset="55%%" stop-color="#0d131d" stop-opacity="0.99"/>
                    <stop offset="100%%" stop-color="#090d14" stop-opacity="0.99"/>
                </linearGradient>
                <linearGradient id="accentWash" x1="0%%" y1="0%%" x2="72%%" y2="0%%">
                    <stop offset="0%%" stop-color="%s" stop-opacity="0.12"/>
                    <stop offset="100%%" stop-color="%s" stop-opacity="0"/>
                </linearGradient>
                <linearGradient id="cardBorder" x1="0%%" y1="0%%" x2="100%%" y2="100%%">
                    <stop offset="0%%" stop-color="#ffffff" stop-opacity="0.18"/>
                    <stop offset="45%%" stop-color="#ffffff" stop-opacity="0.08"/>
                    <stop offset="100%%" stop-color="#ffffff" stop-opacity="0.04"/>
                </linearGradient>
            </defs>
            <rect x="0.5" y="0.5" width="%.2f" height="%.2f" rx="%.1f" ry="%.1f" fill="url(#cardBg)" stroke="url(#cardBorder)" stroke-width="1.0"/>
            <rect x="0.5" y="0.5" width="%.2f" height="%.2f" rx="%.1f" ry="%.1f" fill="url(#accentWash)"/>
            <rect x="0" y="16" width="3" height="%.2f" rx="1.5" fill="%s"/>
            <path d="M %.2f 1 H %.2f" stroke="#ffffff" stroke-opacity="0.12" stroke-linecap="round"/>
        </svg>
    ]], w, h, w, h, accentColor, accentColor, innerW, innerH, r, r, innerW, innerH, r, r, math.max(1, h - 32), accentColor, r, w - r)

    return svgCreate(w, h, svgData)
end

local function createBasicFillSVG(w, h, r)
    w = math.max(1, math.floor(w))
    h = math.max(1, math.floor(h))
    local scale = (w <= 80 or h <= 80) and 4 or (w <= 512 and 2 or 1)
    if (w * scale > 4096) or (h * scale > 4096) then
        scale = 1
    end
    local sw = math.min(4096, math.max(1, math.floor(w * scale)))
    local sh = math.min(4096, math.max(1, math.floor(h * scale)))
    local sr = math.min(r * scale, math.min(sw, sh) * 0.5)
    local svgData = string.format([[
        <svg width="%d" height="%d" viewBox="0 0 %d %d" fill="none" xmlns="http://www.w3.org/2000/svg">
            <rect width="%d" height="%d" rx="%.1f" ry="%.1f" fill="white"/>
        </svg>
    ]], sw, sh, sw, sh, sw, sh, sr, sr)
    return svgCreate(sw, sh, svgData)
end

local function createCircleSVG(sd)
    sd = math.min(4096, math.max(1, math.floor(sd)))
    local center = sd * 0.5
    local r = math.max(1, (sd * 0.5) - 0.5)
    local svgData = string.format([[
        <svg width="%d" height="%d" viewBox="0 0 %d %d" fill="none" xmlns="http://www.w3.org/2000/svg">
            <circle cx="%.2f" cy="%.2f" r="%.2f" fill="white"/>
        </svg>
    ]], sd, sd, sd, sd, center, center, r)
    return svgCreate(sd, sd, svgData)
end

function drawCircle(cx, cy, radius, color, postGUI)
    if not radius or radius <= 0 then return end
    local diameter = math.max(2, math.floor(radius * 2 + 0.5))
    local scale = (diameter <= 64) and 4 or (diameter <= 256 and 2 or 1)
    if diameter * scale > 4096 then
        scale = 1
    end
    local sd = math.min(4096, math.max(1, diameter * scale))
    local key = "circle_" .. sd
    if not svgCache[key] or not isElement(svgCache[key]) then
        svgCache[key] = createCircleSVG(sd)
    end
    local drawX = math.floor(cx - diameter * 0.5)
    local drawY = math.floor(cy - diameter * 0.5)
    if svgCache[key] then
        dxDrawImage(drawX, drawY, diameter, diameter, svgCache[key], 0, 0, 0, color or tocolor(255, 255, 255, 255), postGUI or false)
    else
        dxDrawRectangle(drawX, drawY, diameter, diameter, color or tocolor(255, 255, 255, 255), postGUI or false)
    end
end

function drawRoundedRectangle(x, y, w, h, radius, color, postGUI)
    w, h = math.max(1, math.floor(w)), math.max(1, math.floor(h))
    radius = radius or 8

    if w >= 2048 or h >= 2048 then
        dxDrawRectangle(x, y, w, h, color or tocolor(255, 255, 255, 255), postGUI or false)
        return
    end

    if h <= 6 and w > h and radius >= h * 0.4 then
        local key = "thin_pill_64x8"
        if not svgCache[key] or not isElement(svgCache[key]) then
            svgCache[key] = createBasicFillSVG(64, 8, 4)
        end
        if svgCache[key] then
            dxDrawImage(x, y, w, h, svgCache[key], 0, 0, 0, color or tocolor(255, 255, 255, 255), postGUI or false)
        end
        return
    end

    local isCircle = (math.abs(w - h) <= 1) and (radius >= (math.min(w, h) / 2 - 1))
    if isCircle then
        drawCircle(x + w * 0.5, y + h * 0.5, math.min(w, h) * 0.5, color, postGUI)
        return
    end

    local key = "rect_" .. w .. "x" .. h .. "_r_" .. math.floor(radius)
    if not svgCache[key] or not isElement(svgCache[key]) then
        svgCache[key] = createBasicFillSVG(w, h, radius)
    end
    if svgCache[key] then
        dxDrawImage(x, y, w, h, svgCache[key], 0, 0, 0, color or tocolor(255, 255, 255, 255), postGUI or false)
    else
        dxDrawRectangle(x, y, w, h, color or tocolor(255, 255, 255, 255), postGUI or false)
    end
end

function drawGlassPanel(x, y, w, h, radius, colorOrPostGUI, postGUI)
    x, y, w, h = math.floor(x), math.floor(y), math.max(1, math.floor(w)), math.max(1, math.floor(h))
    radius = math.max(2, math.floor(radius or 12))
    local imgColor = tocolor(255, 255, 255, 255)
    local isPostGUI = false
    if type(colorOrPostGUI) == "number" then
        imgColor = colorOrPostGUI
        isPostGUI = (postGUI == true)
    elseif type(colorOrPostGUI) == "boolean" then
        isPostGUI = colorOrPostGUI
    end
    local key = "glass_" .. w .. "x" .. h .. "_r_" .. radius
    if not svgCache[key] or not isElement(svgCache[key]) then
        svgCache[key] = createGlassPanelSVG(w, h, radius)
    end
    if svgCache[key] then
        dxDrawImage(x, y, w, h, svgCache[key], 0, 0, 0, imgColor, isPostGUI)
    end
end

function drawLiquidButtonSVG(x, y, w, h, radius, theme, state, postGUI)
    x, y, w, h = math.floor(x), math.floor(y), math.max(1, math.floor(w)), math.max(1, math.floor(h))
    radius = math.max(2, math.floor(radius or 10))
    theme = theme or "blue"
    state = state or "normal"
    local isPostGUI = (postGUI == true)
    local key = "btn_" .. w .. "x" .. h .. "_r_" .. radius .. "_" .. theme .. "_" .. state
    if not svgCache[key] or not isElement(svgCache[key]) then
        svgCache[key] = createLiquidButtonSVG(w, h, radius, theme, state)
    end
    if svgCache[key] then
        dxDrawImage(x, y, w, h, svgCache[key], 0, 0, 0, tocolor(255, 255, 255, 255), isPostGUI)
    end
end

function drawEditBoxSVG(x, y, w, h, radius, state, postGUI)
    x, y, w, h = math.floor(x), math.floor(y), math.max(1, math.floor(w)), math.max(1, math.floor(h))
    radius = math.max(2, math.floor(radius or 10))
    state = state or "normal"
    local isPostGUI = (postGUI == true)
    local key = "editbox_" .. w .. "x" .. h .. "_r_" .. radius .. "_" .. state
    if not svgCache[key] or not isElement(svgCache[key]) then
        svgCache[key] = createEditBoxSVG(w, h, radius, state)
    end
    if svgCache[key] then
        dxDrawImage(x, y, w, h, svgCache[key], 0, 0, 0, tocolor(255, 255, 255, 255), isPostGUI)
    end
end

function drawDiagonalTabBarSVG(x, y, w, h, radius, activeTab, postGUI)
    x, y, w, h = math.floor(x), math.floor(y), math.max(1, math.floor(w)), math.max(1, math.floor(h))
    radius = math.max(2, math.floor(radius or 10))
    activeTab = activeTab or "login"
    local isPostGUI = (postGUI == true)
    local key = "tabbar_" .. w .. "x" .. h .. "_r_" .. radius .. "_" .. activeTab
    if not svgCache[key] or not isElement(svgCache[key]) then
        svgCache[key] = createDiagonalTabBarSVG(w, h, radius, activeTab)
    end
    if svgCache[key] then
        dxDrawImage(x, y, w, h, svgCache[key], 0, 0, 0, tocolor(255, 255, 255, 255), isPostGUI)
    end
end

function drawNotificationCardSVG(x, y, w, h, radius, nType, postGUI, alpha)
    x, y, w, h = math.floor(x), math.floor(y), math.max(1, math.floor(w)), math.max(1, math.floor(h))
    radius = math.max(2, math.floor(radius or 10))
    nType = nType or "info"
    if nType ~= "info" and nType ~= "success" and nType ~= "error" and nType ~= "warning" then
        nType = "info"
    end
    alpha = math.max(0, math.min(255, math.floor(tonumber(alpha) or 255)))
    local isPostGUI = (postGUI == true)
    local key = "notif_" .. w .. "x" .. h .. "_r_" .. radius .. "_" .. nType
    if not svgCache[key] or not isElement(svgCache[key]) then
        svgCache[key] = createNotificationCardSVG(w, h, radius, nType)
    end
    if svgCache[key] then
        dxDrawImage(x, y, w, h, svgCache[key], 0, 0, 0, tocolor(255, 255, 255, alpha), isPostGUI)
    end
end

function drawRoundedBorder(x, y, w, h, radius, borderW, color, postGUI)
    drawRoundedRectangle(x, y, w, h, radius, color, postGUI)
end

local iconPaths = {
    ["user"] = '<path d="M12 12c2.7 0 4.8-2.1 4.8-4.8S14.7 2.4 12 2.4 7.2 4.5 7.2 7.2 9.3 12 12 12zm0 2.4c-3.2 0-9.6 1.6-9.6 4.8v2.4h19.2v-2.4c0-3.2-6.4-4.8-9.6-4.8z" fill="white"/>',
    ["lock"] = '<path d="M18 8h-1V6c0-2.76-2.24-5-5-5S7 3.24 7 6v2H6c-1.1 0-2 .9-2 2v10c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2V10c0-1.1-.9-2-2-2zm-6 9c-1.1 0-2-.9-2-2s.9-2 2-2 2 .9 2 2-.9 2-2 2zm3.1-9H8.9V6c0-1.71 1.39-3.1 3.1-3.1 1.71 0 3.1 1.39 3.1 3.1v2z" fill="white"/>',
    ["shield"] = '<path d="M12 1L3 5v6c0 5.55 3.84 10.74 9 12 5.16-1.26 9-6.45 9-12V5l-9-4zm-2 16l-4-4 1.41-1.41L10 14.17l6.59-6.59L18 9l-8 8z" fill="white"/>',
    ["key"] = '<path d="M12.65 10C11.83 7.67 9.61 6 7 6c-3.31 0-6 2.69-6 6s2.69 6 6 6c2.61 0 4.83-1.67 5.65-4H17v4h4v-4h2v-4H12.65zM7 14c-1.1 0-2-.9-2-2s.9-2 2-2 2 .9 2 2-.9 2-2 2z" fill="white"/>',
    ["badge"] = '<path d="M12 2L4 5v6.09c0 5.05 3.41 9.76 8 10.91 4.59-1.15 8-5.86 8-10.91V5l-8-3zm0 4c1.66 0 3 1.34 3 3s-1.34 3-3 3-3-1.34-3-3 1.34-3 3-3zm0 14.9c-2.5-.93-4.7-3.16-5.54-5.9 1.4-1.23 3.32-2 5.54-2s4.14.77 5.54 2c-.84 2.74-3.04 4.97-5.54 5.9z" fill="white"/>',
    ["check"] = '<path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41z" fill="white"/>',
    ["cross"] = '<path d="M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z" fill="white"/>',
    ["info"] = '<path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-6h2v6zm0-8h-2V7h2v2z" fill="white"/>',
    ["alert"] = '<path d="M1 21h22L12 2 1 21zm12-3h-2v-2h2v2zm0-4h-2v-4h2v4z" fill="white"/>',
    ["bell"] = '<path d="M12 22c1.1 0 2-.9 2-2h-4c0 1.1.9 2 2 2zm6-6v-5c0-3.07-1.63-5.64-4.5-6.32V4c0-.83-.67-1.5-1.5-1.5s-1.5.67-1.5 1.5v.68C7.64 5.36 6 7.92 6 11v5l-2 2v1h16v-1l-2-2z" fill="white"/>',
    ["logout"] = '<path d="M17 7l-1.41 1.41L18.17 11H8v2h10.17l-2.58 2.58L17 17l5-5zM4 5h8V3H4c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h8v-2H4V5z" fill="white"/>',
    ["arrow-left"] = '<path d="M20 11H7.83l5.59-5.59L12 4l-8 8 8 8 1.41-1.41L7.83 13H20v-2z" fill="white"/>',
    ["wallet"] = '<path d="M21 18v1c0 1.1-.9 2-2 2H5c-1.11 0-2-.9-2-2V5c0-1.1.89-2 2-2h14c1.1 0 2 .9 2 2v1h-9c-1.11 0-2 .9-2 2v8c0 1.1.89 2 2 2h9zm-9-2h10V8H12v8zm4-2.5c-.83 0-1.5-.67-1.5-1.5s.67-1.5 1.5-1.5 1.5.67 1.5 1.5-.67 1.5-1.5 1.5z" fill="white"/>',
    ["bank"] = '<path d="M4 10v7h3v-7H4zm6 0v7h3v-7h-3zM2 22h19v-3H2v3zm14-12v7h3v-7h-3zm-4.5-9L2 6v2h19V6l-9.5-5z" fill="white"/>',
    ["heart"] = '<path d="M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z" fill="white"/>',
    ["food"] = '<path d="M18.06 22.99h1.66c.84 0 1.53-.64 1.63-1.48L23 5.05h-5V1h-1.97v4.05h-4.97l.3 2.34c1.71.47 3.31 1.32 4.27 2.26 1.44 1.42 2.43 2.89 2.43 5.29v8.05zM1 21.99V21h15.03v.99c0 .55-.45 1-1 1H2c-.55 0-1-.45-1-1zm15.03-7c0-8-15.03-8-15.03 0h15.03zM1.02 17h15v2h-15z" fill="white"/>',
    ["water"] = '<path d="M12 2.69l5.66 5.66a8 8 0 1 1-11.31 0z" fill="white"/>',
    ["mic"] = '<path d="M12 14c1.66 0 3-1.34 3-3V5c0-1.66-1.34-3-3-3S9 3.34 9 5v6c0 1.66 1.34 3 3 3zm5.91-3c-.49 0-.9.36-.98.85C16.52 14.2 14.47 16 12 16s-4.52-1.8-4.93-4.15c-.08-.49-.49-.85-.98-.85-.61 0-1.09.54-1 1.14.49 3 2.89 5.35 5.91 5.78V20c0 .55.45 1 1 1s1-.45 1-1v-2.08c3.02-.43 5.42-2.78 5.91-5.78.1-.6-.39-1.14-1-1.14z" fill="white"/>',
    ["clock"] = '<path d="M11.99 2C6.47 2 2 6.48 2 12s4.47 10 9.99 10C17.52 22 22 17.52 22 12S17.52 2 11.99 2zM12 20c-4.42 0-8-3.58-8-8s3.58-8 8-8 8 3.58 8 8-3.58 8-8 8zm.5-13H11v6l5.25 3.15.75-1.23-4.5-2.67z" fill="white"/>',
    ["car"] = '<path d="M18.92 6.01C18.72 5.42 18.16 5 17.5 5h-11c-.66 0-1.21.42-1.42 1.01L3 12v8c0 .55.45 1 1 1h1c.55 0 1-.45 1-1v-1h12v1c0 .55.45 1 1 1h1c.55 0 1-.45 1-1v-8l-2.08-5.99zM6.5 16c-.83 0-1.5-.67-1.5-1.5S5.67 13 6.5 13s1.5.67 1.5 1.5S7.33 16 6.5 16zm11 0c-.83 0-1.5-.67-1.5-1.5s.67-1.5 1.5-1.5 1.5.67 1.5 1.5-.67 1.5-1.5 1.5zM5 11l1.5-4.5h11L19 11H5z" fill="white"/>',
    ["wrench"] = '<path d="M22.7 19l-9.1-9.1c.9-2.3.4-5-1.5-6.9-2-2-5-2.4-7.4-1.3L9 6 6 9 1.6 4.7C.4 7.1.9 10.1 2.9 12.1c1.9 1.9 4.6 2.4 6.9 1.5l9.1 9.1c.4.4 1 .4 1.4 0l2.3-2.3c.5-.4.5-1.1.1-1.4z" fill="white"/>',
    ["garage"] = '<path d="M19 4H5a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V6a2 2 0 0 0-2-2zm-1 14H6v-2h12v2zm0-4H6v-2h12v2zm0-4H6V8h12v2z" fill="white"/>',
    ["monitor"] = '<rect x="2" y="3" width="20" height="14" rx="2" stroke="white" stroke-width="1.8" fill="none"/><path d="M8 21h8M12 17v4" stroke="white" stroke-width="1.8" stroke-linecap="round"/>',
    ["signal"] = '<rect x="3" y="15" width="3.5" height="6" rx="1" fill="white"/><rect x="9" y="10" width="3.5" height="11" rx="1" fill="white"/><rect x="15" y="4" width="3.5" height="17" rx="1" fill="white"/>',
    ["bag"] = '<path d="M19 6h-3V5c0-1.66-1.34-3-3-3s-3 1.34-3 3v1H5c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2zm-7-2c.55 0 1 .45 1 1v1h-2V5c0-.55.45-1 1-1zm7 16H5V8h14v12zm-7-9c-1.66 0-3 1.34-3 3s1.34 3 3 3 3-1.34 3-3-1.34-3-3-3z" fill="white"/>',
    ["cube"] = '<path d="M21 16.5l-9 5.2-9-5.2V7.5L12 2.3l9 5.2v9zM12 4.1L5.3 8 12 11.9 18.7 8 12 4.1zm-7 5.2v6.4l6 3.5v-6.4L5 9.3zm14 0l-6 3.5v6.4l6-3.5V9.3z" fill="white"/>',
    ["hand"] = '<path d="M13 24a11 11 0 0 1-7.78-3.22l-4.93-4.93 1.41-1.41 4.52 4.52V5a1.5 1.5 0 0 1 3 0v7a.5.5 0 0 0 1 0V3a1.5 1.5 0 0 1 3 0v9a.5.5 0 0 0 1 0V4a1.5 1.5 0 0 1 3 0v8a.5.5 0 0 0 1 0v-6a1.5 1.5 0 0 1 3 0v11a11 11 0 0 1-11 11z" fill="white"/>',
    ["swap"] = '<path d="M6.99 11L3 15l3.99 4v-3H14v-2H6.99v-3zM21 9l-3.99-4v3H10v2h7.01v3L21 9z" fill="white"/>'
}

function drawIconSVG(name, x, y, size, color, postGUI)
    size = math.max(8, math.floor(size or 18))
    local key = "icon_" .. name .. "_" .. size
    if not svgCache[key] or not isElement(svgCache[key]) then
        local pathXml = iconPaths[name] or iconPaths["user"]
        local svgData = string.format([[
            <svg width="%d" height="%d" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                %s
            </svg>
        ]], size, size, pathXml)
        svgCache[key] = svgCreate(size, size, svgData)
    end
    if svgCache[key] then
        dxDrawImage(x, y, size, size, svgCache[key], 0, 0, 0, color or tocolor(255, 255, 255, 255), postGUI or false)
    end
end

addEventHandler("onClientResourceStop", resourceRoot, function()
    for _, element in pairs(svgCache) do
        if isElement(element) then
            destroyElement(element)
        end
    end
    svgCache = {}
end)