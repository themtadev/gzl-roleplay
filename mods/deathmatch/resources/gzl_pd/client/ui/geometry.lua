
PDGeometry = {}

PDGeometry.screenW = 1920
PDGeometry.screenH = 1080
PDGeometry.scale = 1.0

PDGeometry.tablet = {
    x = 0, y = 0, w = 1020, h = 640,
    header = { x = 0, y = 0, w = 1020, h = 56 },
    sidebar = { x = 0, y = 0, w = 220, h = 584 },
    content = { x = 0, y = 0, w = 800, h = 584 }
}

function PDGeometry.updateMetrics()
    local sw, sh = guiGetScreenSize()
    PDGeometry.screenW = sw
    PDGeometry.screenH = sh

    local scale = math.max(0.75, math.min(1.15, sh / 1080))
    PDGeometry.scale = scale

    local tw = math.floor(PDConfig.Tokens.tabletWidth * scale)
    local th = math.floor(PDConfig.Tokens.tabletHeight * scale)
    local tx = math.floor((sw - tw) / 2)
    local ty = math.floor((sh - th) / 2)

    local headH = math.floor(PDConfig.Tokens.headerHeight * scale)
    local sideW = math.floor(PDConfig.Tokens.sidebarWidth * scale)
    local bodyH = th - headH
    local contentW = tw - sideW

    PDGeometry.tablet = {
        x = tx, y = ty, w = tw, h = th,
        header = { x = tx, y = ty, w = tw, h = headH },
        sidebar = { x = tx, y = ty + headH, w = sideW, h = bodyH },
        content = { x = tx + sideW, y = ty + headH, w = contentW, h = bodyH }
    }
end

function PDGeometry.isCursorIn(x, y, w, h)
    if not isCursorShowing() then return false end
    local cx, cy = getCursorPosition()
    cx, cy = cx * PDGeometry.screenW, cy * PDGeometry.screenH
    return (cx >= x and cx <= x + w and cy >= y and cy <= y + h)
end