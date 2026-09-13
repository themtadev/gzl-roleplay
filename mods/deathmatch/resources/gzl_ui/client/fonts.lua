local fontCache = {}
local fontPaths = {
    ["regular"] = "assets/fonts/SFUIText-Regular.ttf",
    ["regular-italic"] = "assets/fonts/SFUIText-RegularItalic.ttf",
    ["medium"] = "assets/fonts/SFUIText-Medium.ttf",
    ["medium-italic"] = "assets/fonts/SFUIText-MediumItalic.ttf",
    ["semibold"] = "assets/fonts/SFUIText-Semibold.ttf",
    ["semibold-italic"] = "assets/fonts/SFUIText-SemiboldItalic.ttf",
    ["bold"] = "assets/fonts/SFUIText-Bold.ttf",
    ["bold-italic"] = "assets/fonts/SFUIText-BoldItalic.ttf",
    ["heavy"] = "assets/fonts/SFUIText-Heavy.ttf",
    ["heavy-italic"] = "assets/fonts/SFUIText-HeavyItalic.ttf",
    ["light"] = "assets/fonts/SFUIText-Light.ttf",
    ["light-italic"] = "assets/fonts/SFUIText-LightItalic.ttf"
}

function getFont(style, size)
    style = string.lower(style or "regular")
    size = math.max(6, math.floor(tonumber(size) or 11))

    local key = style .. "_" .. size
    if fontCache[key] and isElement(fontCache[key]) then
        return fontCache[key]
    end

    local path = fontPaths[style] or fontPaths["regular"]
    if fileExists(path) then
        local createdFont = dxCreateFont(path, size, false, "cleartype")
        if createdFont then
            fontCache[key] = createdFont
            return createdFont
        end
    end

    return "default-bold"
end

addEventHandler("onClientResourceStop", resourceRoot, function()
    for _, font in pairs(fontCache) do
        if isElement(font) then
            destroyElement(font)
        end
    end
    fontCache = {}
end)