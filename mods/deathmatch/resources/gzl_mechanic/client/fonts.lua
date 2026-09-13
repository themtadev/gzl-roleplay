local fontCache = {}
local fontFiles = {
    ["regular"] = "assets/fonts/SFUIText-Regular.ttf",
    ["medium"] = "assets/fonts/SFUIText-Medium.ttf",
    ["semibold"] = "assets/fonts/SFUIText-Semibold.ttf",
    ["bold"] = "assets/fonts/SFUIText-Bold.ttf",
    ["heavy"] = "assets/fonts/SFUIText-Heavy.ttf"
}

function getMechanicFont(style, size)
    style = string.lower(style or "regular")
    size = math.max(7, math.floor(tonumber(size) or 11))
    local key = style .. "_" .. size
    if fontCache[key] and isElement(fontCache[key]) then
        return fontCache[key]
    end

    local path = fontFiles[style] or fontFiles["regular"]
    if fileExists(path) then
        local f = dxCreateFont(path, size, false, "cleartype")
        if f then
            fontCache[key] = f
            return f
        end
    end

    if exports.gzl_ui and exports.gzl_ui.getFont then
        local uiFont = exports.gzl_ui:getFont(style, size)
        if uiFont and uiFont ~= "default" and uiFont ~= "default-bold" then
            return uiFont
        end
    end

    return (style == "bold" or style == "heavy" or style == "semibold") and "default-bold" or "default"
end

addEventHandler("onClientResourceStop", resourceRoot, function()
    for _, f in pairs(fontCache) do
        if isElement(f) then
            destroyElement(f)
        end
    end
    fontCache = {}
end)