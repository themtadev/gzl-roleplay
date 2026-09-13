Config = {}

Config.MenuKey = "page_up"
Config.Command = "txadmin"
Config.CommandAlias = "tx"

Config.AdminSerials = {}

Config.TeleportLocations = {
    { name = "Hedef (GPS)", type = "waypoint" },
    { name = "Koordinat Gir", type = "custom" },
    { name = "Legion Meydanı", x = 1481.0, y = -1771.5, z = 18.8 },
    { name = "Havalimanı LS", x = 1680.0, y = -2280.0, z = 13.5 },
    { name = "Polis Departmanı", x = 1554.0, y = -1675.0, z = 16.2 },
    { name = "Vinewood", x = 1450.0, y = -780.0, z = 95.0 },
    { name = "Grove Street", x = 2490.0, y = -1670.0, z = 13.3 },
    { name = "Sandy Shores", x = 200.0, y = 1860.0, z = 17.6 },
    { name = "Paleto Bay", x = -150.0, y = 2600.0, z = 62.0 },
    { name = "Chiliad Dağı", x = -2300.0, y = -1640.0, z = 483.0 }
}

Config.Vehicles = {
    { name = "Model Gir", action = "custom" },
    { name = "Sultan", model = 560, action = "spawn" },
    { name = "Infernus", model = 411, action = "spawn" },
    { name = "Elegy", model = 562, action = "spawn" },
    { name = "NRG-500", model = 522, action = "spawn" },
    { name = "Buffalo", model = 402, action = "spawn" },
    { name = "Turismo", model = 451, action = "spawn" },
    { name = "Sanchez", model = 468, action = "spawn" },
    { name = "Polis Aracı", model = 596, action = "spawn" },
    { name = "Ambulans", model = 416, action = "spawn" },
    { name = "Tamir Et", action = "fix" },
    { name = "Aracı Sil", action = "delete" },
    { name = "Modifiye Et", action = "upgrade" },
    { name = "Hızlandır", action = "boost" },
    { name = "Temizle", action = "clean" }
}

Config.Weathers = {
    { id = 0, name = "Güneşli" },
    { id = 1, name = "Açık" },
    { id = 8, name = "Yağmurlu" },
    { id = 9, name = "Sisli" },
    { id = 19, name = "Fırtına" }
}

function isAdmin(player)
    player = player or localPlayer
    if not isElement(player) then return false end
    if localPlayer then
        return (tonumber(getElementData(player, "account:admin")) or 0) > 0
    end
    local auth = getResourceFromName("gzl_auth")
    return auth and getResourceState(auth) == "running" and exports.gzl_auth:getAdminLevel(player) > 0 or false
end