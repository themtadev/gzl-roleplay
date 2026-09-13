function openMarket(shopType)
    toggleMarketUI(true, shopType or "market")
end

function closeMarket()
    toggleMarketUI(false)
end

addCommandHandler("market", function(cmd, shopType)
    if isMarketOpen() then
        closeMarket()
    else
        openMarket(shopType or "market")
    end
end)