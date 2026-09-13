Config = {}

Config.ServerName = "GZL Roleplay"
Config.Developer = "thommy"
Config.Version = "1.0.0"

Config.DefaultSpawn = {
    x = 1481.0,
    y = -1771.5,
    z = 18.79,
    rot = 0.0,
    skin = 0,
    interior = 0,
    dimension = 0
}

Config.FadeInDuration = 1.5
Config.StartingMoney = 5000
Config.DefaultWalkEnabled = true

Config.AdminSerials = {}

function isAdmin(player)
    player = player or localPlayer
    if not isElement(player) then return false end
    if (tonumber(getElementData(player, "account:admin")) or 0) > 0 then
        return true
    end
    if localPlayer then
        return false
    end
    local auth = getResourceFromName("gzl_auth")
    if auth and getResourceState(auth) == "running" and exports.gzl_auth:getAdminLevel(player) > 0 then
        return true
    end
    local acc = getPlayerAccount(player)
    if acc and not isGuestAccount(acc) then
        local adminGroup = aclGetGroup("Admin")
        if adminGroup and isObjectInACLGroup("user." .. getAccountName(acc), adminGroup) then
            return true
        end
    end
    return false
end