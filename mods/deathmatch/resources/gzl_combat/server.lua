local saved = {}
local rollPlayers = {}
addEvent("gzl_combat:rollStart",true)
addEventHandler("gzl_combat:rollStart",root,function(anim)
    if not client or source~=client or (anim~="crouch_roll_l" and anim~="crouch_roll_r") then return end
    local now=getTickCount()
    if rollPlayers[client] and now-rollPlayers[client]<CombatConfig.rollCooldown then return end
    if isPedDead(client) or isPedInVehicle(client) or isElementFrozen(client) then return end
    local supported=false
    for _,weapon in ipairs(CombatConfig.weapons) do if getPedWeapon(client)==weapon then supported=true break end end
    if not supported then return end
    rollPlayers[client]=now
    triggerClientEvent(root,"gzl_combat:rollVisual",client,anim)
end)
addEvent("gzl_combat:rollEnd",true)
addEventHandler("gzl_combat:rollEnd",root,function()
    if not client or source~=client or not rollPlayers[client] then return end
    if getTickCount()-rollPlayers[client]>CombatConfig.rollDuration+1000 then return end
    triggerClientEvent(root,"gzl_combat:rollVisual",client,false)
end)
addEventHandler("onPlayerQuit",root,function() rollPlayers[source]=nil end)
local flags = {
    {0x000010, true, "move_and_aim"},
    {0x000020, true, "move_and_shoot"},
    {0x000008, true, "aim_free"},
    {0x000800, false, "type_dual"},
}

local function readFlag(weapon, skill, mask)
    local value = getWeaponProperty(weapon, skill, "flags")
    if type(value) ~= "number" then return nil end
    return bitAnd(value, mask) ~= 0
end

local function setFlag(weapon, skill, mask, wanted)
    local current = readFlag(weapon, skill, mask)
    if current == nil then return false end
    if current == wanted then return true end

    setWeaponProperty(weapon, skill, "flags", mask)
    return readFlag(weapon, skill, mask) == wanted
end

addEventHandler("onResourceStart", resourceRoot, function()
    for _, weapon in ipairs(CombatConfig.weapons) do
        for _, skill in ipairs({"poor", "std", "pro"}) do
            for _, flag in ipairs(flags) do
                local mask, wanted, name = unpack(flag)
                local old = readFlag(weapon, skill, mask)
                if old == nil or not setFlag(weapon, skill, mask, wanted) then
                    outputDebugString("[gzl_combat] Flag verification failed: " .. weapon .. "/" .. skill .. "/" .. name, 2)
                elseif old ~= wanted then
                    saved[#saved + 1] = {weapon, skill, mask, old, wanted}
                end
            end
        end
    end
end)

addEventHandler("onResourceStop", resourceRoot, function()
    for _, entry in ipairs(saved) do

        if readFlag(entry[1], entry[2], entry[3]) == entry[5] then
            if not setFlag(entry[1], entry[2], entry[3], entry[4]) then
                outputDebugString("[gzl_combat] Flag restore failed: " .. entry[1] .. "/" .. entry[2], 2)
            end
        end
    end
    saved = {}
end)