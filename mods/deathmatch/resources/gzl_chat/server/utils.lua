function starts_with(str, start)
    return str:sub(1, #start) == start
end

function stringsplit(inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local t = {}
    local i = 1
    for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
        t[i] = str
        i = i + 1
    end
    return t
end

function isChatAdmin(player)
    if not isElement(player) or getElementType(player) ~= "player" then return false end
    if exports.gzl_core and exports.gzl_core.isAdmin then
        return exports.gzl_core:isAdmin(player)
    end
    local acc = getPlayerAccount(player)
    if acc and not isGuestAccount(acc) then
        local accName = getAccountName(acc)
        for _, grpName in ipairs({"Admin", "SuperModerator", "Moderator"}) do
            local grp = aclGetGroup(grpName)
            if grp and isObjectInACLGroup("user." .. accName, grp) then
                return true
            end
        end
    end
    local adminLevel = tonumber(getElementData(player, "character:admin") or getElementData(player, "admin_level"))
    return adminLevel and adminLevel > 0
end

function sanitizeText(str)
    if type(str) ~= "string" then return "" end
    return str:gsub("<[^>]*>", ""):gsub("[%c]", "")
end