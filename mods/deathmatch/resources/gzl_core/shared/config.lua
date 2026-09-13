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
    if localPlayer then
        return (tonumber(getElementData(player, "account:admin")) or 0) > 0
    end
    local auth = getResourceFromName("gzl_auth")
    return auth and getResourceState(auth) == "running" and exports.gzl_auth:getAdminLevel(player) > 0 or false
end