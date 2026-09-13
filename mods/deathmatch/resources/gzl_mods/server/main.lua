addEvent("gzl_mods:requestReload", true)
addEventHandler("gzl_mods:requestReload", root, function()
    if client and hasObjectPermissionTo(client, "general.adminpanel", false) then
        triggerClientEvent(root, "gzl_mods:clientReload", root)
    end
end)

addCommandHandler("serverreloadmods", function(player, cmd)
    if not player or hasObjectPermissionTo(player, "general.adminpanel", false) then
        triggerClientEvent(root, "gzl_mods:clientReload", root)
        if player then
            outputChatBox("[GZL-MODS] Tum istemciler icin modlar yenilendi.", player, 100, 200, 255)
        else
            outputServerLog("[GZL-MODS] Tum istemciler icin modlar yenilendi.")
        end
    end
end)

addCommandHandler("reloadmods", function(player, cmd)
    triggerClientEvent(player or root, "gzl_mods:clientReload", root)
    if player then
        outputChatBox("[GZL-MODS] Modlar yeniden yukleniyor...", player, 100, 200, 255)
    end
end)

function reloadModLoader()
    triggerClientEvent(root, "gzl_mods:clientReload", root)
    return true
end