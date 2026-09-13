addEvent("chat:server:ServerPSA", true)
addEventHandler("chat:server:ServerPSA", root, function(message)
    local player = client
    if not player or not isElement(player) or not isChatAdmin(player) then return end
    if type(message) ~= "string" then return end
    message = string.sub(sanitizeText(message), 1, 250)
    if message == "" then return end

    triggerClientEvent(root, "chat:addMessage", root, {
        template = '<div class="chat-message server"><b>[SUNUCU]</b> {0}</div>',
        args = { message }
    })
end)

addEvent("chat:server:ClearChat", true)
addEventHandler("chat:server:ClearChat", root, function(target)
    local player = client
    if not player or not isElement(player) or not isChatAdmin(player) then return end

    if target and isElement(target) and getElementType(target) == "player" then
        triggerClientEvent(target, "chat:client:ClearChat", target)
    else
        triggerClientEvent(root, "chat:client:ClearChat", root)
    end
end)