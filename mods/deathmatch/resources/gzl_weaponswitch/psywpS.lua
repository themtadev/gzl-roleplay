function psyweaponswitch(prevSlot, newSlot)
    if not isElement(source) or getElementType(source) ~= "player" then return end
    local weaponType = getPedWeapon(source)
    if weaponType then
        triggerClientEvent(source, "psy:wp", source, "add")
    end
end
addEventHandler("onPlayerWeaponSwitch", root, psyweaponswitch)