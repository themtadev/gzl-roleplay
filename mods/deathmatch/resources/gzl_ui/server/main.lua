function showNotification(player, title, message, nType, duration)
    if isElement(player) then
        triggerClientEvent(player, "ui:showNotification", player, title, message, nType, duration)
    elseif player == root or player == nil then
        triggerClientEvent(root, "ui:showNotification", root, title, message, nType, duration)
    end
end

function showToast(player, message, toastType, duration)
    showNotification(player, nil, message, toastType, duration)
end

function startProgressBar(player, options)
    if isElement(player) then
        triggerClientEvent(player, "ui:startProgressBar", player, options)
    elseif player == root or player == nil then
        triggerClientEvent(root, "ui:startProgressBar", root, options)
    end
end

function cancelProgressBar(player, reason)
    if isElement(player) then
        triggerClientEvent(player, "ui:cancelProgressBar", player, reason)
    elseif player == root or player == nil then
        triggerClientEvent(root, "ui:cancelProgressBar", root, reason)
    end
end

addEvent("progressbar:serverCancel", true)
addEventHandler("progressbar:serverCancel", root, function(reason)
end)

addEvent("progressbar:serverFinish", true)
addEventHandler("progressbar:serverFinish", root, function(text)
end)