function openPlayerMarket(player, shopType)
    if not isElement(player) then return end
    triggerClientEvent(player, "gzl_market:open", player, shopType or "market")
end

addEventHandler("onResourceStart", resourceRoot, function()
    outputServerLog("[GZL Market] DX market sistemi başarıyla yüklendi.")
end)