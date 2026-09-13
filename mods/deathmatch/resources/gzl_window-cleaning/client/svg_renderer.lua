local svgCache = {}

local function getSVGKey(kind, w, h, r, p1, p2)
    return string.format("%s_%d_%d_%d_%s_%s", kind, math.floor(w), math.floor(h), math.floor(r), tostring(p1), tostring(p2))
end

function drawGlassPanel(x, y, w, h, r, bgAlpha)
    if w <= 0 or h <= 0 then return end
    r = math.max(4, r or 12)
    bgAlpha = bgAlpha or 0.94
    local key = getSVGKey("glass", w, h, r, math.floor(bgAlpha * 100), 0)
    local svg = svgCache[key]
    if not svg then
        local strokeW = 1.0
        local innerW = math.max(1, w - strokeW)
        local innerH = math.max(1, h - strokeW)
        local svgData = string.format([[
            <svg width="%d" height="%d" viewBox="0 0 %d %d" fill="none" xmlns="http://www.w3.org/2000/svg">
                <defs>
                    <linearGradient id="g_bg" x1="0%%" y1="0%%" x2="0%%" y2="100%%">
                        <stop offset="0%%" stop-color="#0f172a" stop-opacity="%.2f"/>
                        <stop offset="100%%" stop-color="#020617" stop-opacity="%.2f"/>
                    </linearGradient>
                    <linearGradient id="g_bdr" x1="0%%" y1="0%%" x2="0%%" y2="100%%">
                        <stop offset="0%%" stop-color="#38bdf8" stop-opacity="0.30"/>
                        <stop offset="100%%" stop-color="#ffffff" stop-opacity="0.05"/>
                    </linearGradient>
                </defs>
                <rect x="%.2f" y="%.2f" width="%.2f" height="%.2f" rx="%.1f" ry="%.1f" fill="url(#g_bg)" stroke="url(#g_bdr)" stroke-width="%.2f"/>
            </svg>
        ]], w, h, w, h, bgAlpha, math.min(1.0, bgAlpha + 0.04), strokeW/2, strokeW/2, innerW, innerH, r, r, strokeW)
        svg = svgCreate(w, h, svgData)
        svgCache[key] = svg
    end
    if isElement(svg) then
        dxDrawImage(x, y, w, h, svg, 0, 0, 0, tocolor(255, 255, 255, 255))
    end
end

function drawRoundedRectangle(x, y, w, h, r, color)
    if w <= 0 or h <= 0 then return end
    r = math.max(2, r or 6)
    local key = getSVGKey("round", w, h, r, 0, 0)
    local svg = svgCache[key]
    if not svg then
        local svgData = string.format([[
            <svg width="%d" height="%d" viewBox="0 0 %d %d" fill="none" xmlns="http://www.w3.org/2000/svg">
                <rect x="0" y="0" width="%d" height="%d" rx="%.1f" ry="%.1f" fill="#ffffff"/>
            </svg>
        ]], w, h, w, h, w, h, r, r)
        svg = svgCreate(w, h, svgData)
        svgCache[key] = svg
    end
    if isElement(svg) then
        dxDrawImage(x, y, w, h, svg, 0, 0, 0, color)
    end
end

function drawCircle(cx, cy, r, color)
    if r <= 0 then return end
    local diam = math.floor(r * 2)
    local key = getSVGKey("circle", diam, diam, r, 0, 0)
    local svg = svgCache[key]
    if not svg then
        local svgData = string.format([[
            <svg width="%d" height="%d" viewBox="0 0 %d %d" fill="none" xmlns="http://www.w3.org/2000/svg">
                <circle cx="%.1f" cy="%.1f" r="%.1f" fill="#ffffff"/>
            </svg>
        ]], diam, diam, diam, diam, r, r, r)
        svg = svgCreate(diam, diam, svgData)
        svgCache[key] = svg
    end
    if isElement(svg) then
        dxDrawImage(cx - r, cy - r, diam, diam, svg, 0, 0, 0, color)
    end
end

function drawProgressBar(x, y, w, h, r, progress, fillColor, bgColor)
    progress = math.max(0, math.min(1, progress or 0))
    bgColor = bgColor or tocolor(30, 41, 59, 200)
    fillColor = fillColor or tocolor(56, 189, 248, 255)
    drawRoundedRectangle(x, y, w, h, r, bgColor)
    if progress > 0.01 then
        local fillW = math.max(r * 2, w * progress)
        drawRoundedRectangle(x, y, fillW, h, r, fillColor)
    end
end

function isCursorWithin(x, y, w, h)
    if not isCursorShowing() then return false end
    local cx, cy = getCursorPosition()
    if not cx or not cy then return false end
    local sw, sh = guiGetScreenSize()
    cx, cy = cx * sw, cy * sh
    return (cx >= x and cx <= x + w and cy >= y and cy <= y + h)
end