local function syncPlayerNeeds(player, hunger, thirst)
    if not isElement(player) then return end
    hunger = math.max(0, math.min(100, hunger))
    thirst = math.max(0, math.min(100, thirst))

    setElementData(player, "char:hunger", hunger)
    setElementData(player, "character:hunger", hunger)
    setElementData(player, "hunger", hunger)

    setElementData(player, "char:thirst", thirst)
    setElementData(player, "character:thirst", thirst)
    setElementData(player, "thirst", thirst)
end

addEventHandler("onResourceStart", resourceRoot, function()
    for _, player in ipairs(getElementsByType("player")) do
        local isLogged = getElementData(player, "char:id") or getElementData(player, "character:id") or getElementData(player, "loggedin_character")
        if isLogged then
            local hunger = tonumber(getElementData(player, "char:hunger") or getElementData(player, "character:hunger") or getElementData(player, "hunger")) or 100
            local thirst = tonumber(getElementData(player, "char:thirst") or getElementData(player, "character:thirst") or getElementData(player, "thirst")) or 100
            syncPlayerNeeds(player, hunger, thirst)
        else
            if not getElementData(player, "char:hunger") then
                setElementData(player, "char:hunger", 100)
            end
            if not getElementData(player, "char:thirst") then
                setElementData(player, "char:thirst", 100)
            end
        end
    end
end)

addEventHandler("onPlayerJoin", root, function()
    setElementData(source, "char:hunger", 100)
    setElementData(source, "character:hunger", 100)
    setElementData(source, "hunger", 100)
    setElementData(source, "char:thirst", 100)
    setElementData(source, "character:thirst", 100)
    setElementData(source, "thirst", 100)
end)

setTimer(function()
    for _, player in ipairs(getElementsByType("player")) do
        local isLogged = getElementData(player, "char:id") or getElementData(player, "character:id") or getElementData(player, "loggedin_character")
        if isLogged then
            local hunger = tonumber(getElementData(player, "char:hunger") or getElementData(player, "character:hunger") or getElementData(player, "hunger")) or 100
            local thirst = tonumber(getElementData(player, "char:thirst") or getElementData(player, "character:thirst") or getElementData(player, "thirst")) or 100

            hunger = math.max(0, hunger - 0.25)
            thirst = math.max(0, thirst - 0.40)

            syncPlayerNeeds(player, hunger, thirst)

            if hunger <= 0 or thirst <= 0 then
                local hp = getElementHealth(player)
                if hp > 5 then
                    setElementHealth(player, math.max(1, hp - 2))
                end
            end
        end
    end
end, 30000, 0)