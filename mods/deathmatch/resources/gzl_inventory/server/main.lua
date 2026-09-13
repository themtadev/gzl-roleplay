local equippedWeaponItems = setmetatable({}, {__mode = "k"})
local playerInventories = {}
local Items = {}

local function notifyPlayer(player, msg, nType)
    if not isElement(player) or not msg then return end
    local cleanMsg = tostring(msg):gsub("#%x%x%x%x%x%x", "")
    pcall(function()
        if exports.gzl_ui and exports.gzl_ui.showToast then
            exports.gzl_ui:showToast(player, cleanMsg, nType or "info")
        elseif exports.gzl_ui and exports.gzl_ui.showNotification then
            exports.gzl_ui:showNotification(player, nil, cleanMsg, nType or "info")
        else
            outputChatBox(msg, player, 255, 255, 255, true)
        end
    end)
end

local function loadItemsDatabase()
    Items = ItemsList or {}
    outputDebugString("[OX_INVENTORY] Loaded " .. tostring(table.count(Items)) .. " items from data/items.lua")
end

function table.count(t)
    local c = 0
    for _ in pairs(t or {}) do c = c + 1 end
    return c
end

function getItemsList()
    return ItemsList or {}
end

local function getPlayerAccountName(player)
    local account = getPlayerAccount(player)
    if account and not isGuestAccount(account) then
        return getAccountName(account)
    end
    return getPlayerSerial(player)
end

local WORLD_DROPS_FILE = "data/world_drops.json"
local MAX_DROP_RADIUS = 3.5
local worldDrops = {}

local ItemDropModels = {
    ['water'] = 1484,
    ['cola'] = 1546,
    ['beer'] = 1486,
    ['burger'] = 2880,
    ['sandwich'] = 2880,
    ['pizza'] = 2702,
    ['cash'] = 1212,
    ['black_money'] = 1212,
    ['phone'] = 330,
    ['radio'] = 330,
    ['medkit'] = 1578,
    ['bandage'] = 1578,
    ['repairkit'] = 1271,
    ['carkey'] = 1271,
    ['id_card'] = 1271,
    ['driving_license'] = 1271,
    ['weapon_pistol'] = 346,
    ['weapon_glock'] = 346,
    ['weapon_colt45'] = 346,
    ['weapon_silenced'] = 347,
    ['weapon_deagle'] = 348,
    ['weapon_shotgun'] = 349,
    ['weapon_combatshotgun'] = 351,
    ['weapon_smg'] = 353,
    ['weapon_ak47'] = 355,
    ['weapon_m4'] = 356,
    ['weapon_sniper'] = 358,
    ['_default'] = 2912
}

local function getItemDropModel(itemName)
    return ItemDropModels[itemName] or ItemDropModels['_default'] or 2912
end

local function createDropObject(drop)
    if not drop then return end
    if drop.element and isElement(drop.element) then
        destroyElement(drop.element)
        drop.element = nil
    end

    local primaryItem = nil
    for _, itm in pairs(drop.items or {}) do
        if itm and itm.name then
            primaryItem = itm.name
            break
        end
    end

    if not primaryItem then return end

    local modelId = getItemDropModel(primaryItem)
    local obj = createObject(modelId, drop.x, drop.y, drop.z - 0.85, 0, 0, math.random(0, 360))
    if obj then
        setElementDimension(obj, drop.dimension or 0)
        setElementInterior(obj, drop.interior or 0)
        setElementCollisionsEnabled(obj, false)
        drop.element = obj
    end
end

local function saveWorldDrops()
    local serializable = {}
    for id, drop in pairs(worldDrops) do
        if drop and drop.items and table.count(drop.items) > 0 then
            serializable[tostring(id)] = {
                id = drop.id,
                x = drop.x,
                y = drop.y,
                z = drop.z,
                dimension = drop.dimension or 0,
                interior = drop.interior or 0,
                items = drop.items
            }
        end
    end

    local jsonStr = toJSON(serializable, false)
    if not jsonStr or #jsonStr == 0 then return end

    local tempFile = WORLD_DROPS_FILE .. ".tmp"
    local bakFile = WORLD_DROPS_FILE .. ".bak"

    if fileExists(tempFile) then fileDelete(tempFile) end
    local tf = fileCreate(tempFile)
    if tf then
        local bytesWritten = fileWrite(tf, jsonStr)
        fileClose(tf)
        if bytesWritten and bytesWritten >= #jsonStr then
            if fileExists(WORLD_DROPS_FILE) then
                if fileExists(bakFile) then fileDelete(bakFile) end
                fileCopy(WORLD_DROPS_FILE, bakFile, true)
                fileDelete(WORLD_DROPS_FILE)
            end
            if not fileRename(tempFile, WORLD_DROPS_FILE) then
                if not fileCopy(tempFile, WORLD_DROPS_FILE, true) then
                    if fileExists(bakFile) and not fileExists(WORLD_DROPS_FILE) then
                        fileCopy(bakFile, WORLD_DROPS_FILE, true)
                    end
                else
                    fileDelete(tempFile)
                end
            end
        else
            if fileExists(tempFile) then fileDelete(tempFile) end
        end
    end
end

local function loadWorldDrops()
    for _, drop in pairs(worldDrops) do
        if drop.element and isElement(drop.element) then
            destroyElement(drop.element)
        end
    end
    worldDrops = {}

    if not fileExists(WORLD_DROPS_FILE) and fileExists(WORLD_DROPS_FILE .. ".bak") then
        fileCopy(WORLD_DROPS_FILE .. ".bak", WORLD_DROPS_FILE, true)
    end

    if fileExists(WORLD_DROPS_FILE) then
        local f = fileOpen(WORLD_DROPS_FILE)
        if f then
            local size = fileGetSize(f)
            local content = size > 0 and fileRead(f, size) or ""
            fileClose(f)
            if content and #content > 0 then
                local data = fromJSON(content)
                if data and type(data) == "table" then
                    for k, v in pairs(data) do
                        local id = tonumber(v.id or k)
                        if id and v.items and type(v.items) == "table" then
                            local cleanItems = {}
                            for sk, sitem in pairs(v.items) do
                                local slotNum = tonumber(sitem.slot or sk)
                                if slotNum and sitem.name then
                                    cleanItems[slotNum] = sitem
                                end
                            end
                            worldDrops[id] = {
                                id = id,
                                x = tonumber(v.x) or 0,
                                y = tonumber(v.y) or 0,
                                z = tonumber(v.z) or 0,
                                dimension = tonumber(v.dimension) or 0,
                                interior = tonumber(v.interior) or 0,
                                items = cleanItems
                            }
                            createDropObject(worldDrops[id])
                        end
                    end
                end
            end
        end
    end
    outputDebugString("[OX_INVENTORY] Loaded " .. tostring(table.count(worldDrops)) .. " 3D world drops.")
end

local function getNearestDropForPlayer(player)
    if not isElement(player) then return nil end
    local px, py, pz = getElementPosition(player)
    local pDim = getElementDimension(player)
    local pInt = getElementInterior(player)

    local nearestDrop = nil
    local minDist = MAX_DROP_RADIUS

    for id, drop in pairs(worldDrops) do
        if drop and drop.dimension == pDim and drop.interior == pInt then
            local dist = getDistanceBetweenPoints3D(px, py, pz, drop.x, drop.y, drop.z)
            if dist < minDist then
                minDist = dist
                nearestDrop = drop
            end
        end
    end
    return nearestDrop
end

local function calculateTotalWeight(inv)
    if not inv or not inv.items then return 0 end
    local total = 0
    for _, itm in pairs(inv.items) do
        if itm and itm.name and itm.count then
            local def = Items[itm.name] or {}
            local itemWeight = itm.weight or def.weight or 100
            total = total + (itemWeight * itm.count)
        end
    end
    return total
end

local function formatInventoryItems(items, totalSlots)
    local formatted = {}
    for slot = 1, (totalSlots or 40) do
        local itm = items and (items[slot] or items[tostring(slot)])
        if not itm and items then
            for _, val in pairs(items) do
                if val and tonumber(val.slot) == slot then
                    itm = val
                    break
                end
            end
        end
        if itm and itm.name then
            local def = Items[itm.name] or {}
            formatted[slot] = {
                slot = slot,
                name = itm.name,
                count = tonumber(itm.count) or 1,
                label = itm.label or (itm.metadata and itm.metadata.label) or def.label or itm.name,
                weight = itm.weight or def.weight or 100,
                stack = (def.stack ~= false),
                close = (def.close ~= false),
                description = itm.description or def.description or "",
                metadata = itm.metadata or {}
            }
        end
    end
    return formatted
end

local function getWorldDropsDataForPlayer(player)
    local drop = getNearestDropForPlayer(player)
    if not drop then
        return {
            id = "drop",
            label = "Dünya",
            type = "drop",
            slots = 40,
            weight = 0,
            maxWeight = 100000,
            items = {}
        }
    end

    local totalWeight = 0
    local formattedItems = {}
    for slot = 1, 40 do
        local itm = drop.items and drop.items[slot]
        if itm and itm.name and itm.count and tonumber(itm.count) > 0 then
            local def = Items[itm.name] or {}
            local itemWeight = itm.weight or def.weight or 100
            totalWeight = totalWeight + (itemWeight * itm.count)
            formattedItems[slot] = {
                slot = slot,
                name = itm.name,
                count = tonumber(itm.count) or 1,
                label = itm.label or (itm.metadata and itm.metadata.label) or def.label or itm.name,
                weight = itemWeight,
                stack = (def.stack ~= false),
                close = (def.close ~= false),
                description = itm.description or def.description or "",
                metadata = itm.metadata or {}
            }
        else
            if drop.items then drop.items[slot] = nil end
        end
    end

    return {
        id = tostring(drop.id),
        label = "Dünya",
        type = "drop",
        slots = 40,
        weight = totalWeight,
        maxWeight = 100000,
        items = formattedItems
    }
end

function syncWorldDropsForNearby(x, y, z, dim, int)
    saveWorldDrops()
    for _, p in ipairs(getElementsByType("player")) do
        if playerInventories[p] then
            local px, py, pz = getElementPosition(p)
            local pDim = getElementDimension(p)
            local pInt = getElementInterior(p)
            if pDim == (dim or 0) and pInt == (int or 0) then
                local dist = getDistanceBetweenPoints3D(px, py, pz, x, y, z)
                if dist <= (MAX_DROP_RADIUS * 2.5) then
                    syncPlayerInventory(p)
                end
            end
        end
    end
end

local function getVehicleItemsTable(veh, dataType)
    if not isElement(veh) then return {} end
    local raw = getElementData(veh, "veh:" .. dataType)
    if type(raw) == "table" then return raw end
    if type(raw) == "string" and raw ~= "" then
        local decoded = fromJSON(raw)
        if decoded and type(decoded) == "table" then return decoded end
    end
    return {}
end

local function setVehicleItemsTable(veh, dataType, items)
    if not isElement(veh) then return end
    setElementData(veh, "veh:" .. dataType, items, false)
    local vehId = getElementData(veh, "veh:id")
    if vehId and exports.gzl_vehicles and exports.gzl_vehicles.getVehicleDB then
        local db = exports.gzl_vehicles:getVehicleDB()
        if db then
            local field = (dataType == "trunk_items") and "trunk_items" or "glovebox_items"
            dbExec(db, "UPDATE vehicles SET " .. field .. " = ? WHERE id = ?", toJSON(items, false), vehId)
        end
    end
end

local function getTargetVehicleForPlayer(player)
    if not isElement(player) then return nil, nil end
    local occVeh = getPedOccupiedVehicle(player)
    if occVeh and isElement(occVeh) then
        return occVeh, "glovebox"
    end

    local px, py, pz = getElementPosition(player)
    for _, veh in ipairs(getElementsByType("vehicle")) do
        local vx, vy, vz = getElementPosition(veh)
        if getDistanceBetweenPoints3D(px, py, pz, vx, vy, vz) <= 4.0 then
            local isLocked = isVehicleLocked(veh)
            if not isLocked then
                return veh, "trunk"
            end
        end
    end
    return nil, nil
end

function syncPlayerInventory(player)
    if not isElement(player) then return end
    local inv = playerInventories[player]
    if not inv then return end

    inv.weight = calculateTotalWeight(inv)

    local leftData = {
        id = inv.id,
        label = inv.label or getPlayerName(player),
        type = "player",
        slots = inv.slots or 40,
        weight = inv.weight,
        maxWeight = inv.maxWeight or 30000,
        items = formatInventoryItems(inv.items, inv.slots or 40)
    }

    local targetVeh, vehType = getTargetVehicleForPlayer(player)
    local rightData = nil

    if targetVeh and vehType == "glovebox" then
        local items = getVehicleItemsTable(targetVeh, "glovebox_items")
        local totalWeight = 0
        local formattedItems = {}
        for slot = 1, 10 do
            local itm = items[slot]
            if itm and itm.name and itm.count and tonumber(itm.count) > 0 then
                local def = Items[itm.name] or {}
                local itemWeight = itm.weight or def.weight or 100
                totalWeight = totalWeight + (itemWeight * itm.count)
                formattedItems[slot] = {
                    slot = slot,
                    name = itm.name,
                    count = tonumber(itm.count) or 1,
                    label = itm.label or (itm.metadata and itm.metadata.label) or def.label or itm.name,
                    weight = itemWeight,
                    stack = (def.stack ~= false),
                    close = (def.close ~= false),
                    description = itm.description or def.description or "",
                    metadata = itm.metadata or {}
                }
            end
        end
        local plate = getElementData(targetVeh, "veh:plate") or "Araç"
        rightData = {
            id = "glovebox_" .. tostring(getElementData(targetVeh, "veh:id") or "0"),
            label = "Torpido (" .. plate .. ")",
            type = "glovebox",
            slots = 10,
            weight = totalWeight,
            maxWeight = 10000,
            items = formattedItems
        }
    elseif targetVeh and vehType == "trunk" then
        local items = getVehicleItemsTable(targetVeh, "trunk_items")
        local totalWeight = 0
        local formattedItems = {}
        for slot = 1, 40 do
            local itm = items[slot]
            if itm and itm.name and itm.count and tonumber(itm.count) > 0 then
                local def = Items[itm.name] or {}
                local itemWeight = itm.weight or def.weight or 100
                totalWeight = totalWeight + (itemWeight * itm.count)
                formattedItems[slot] = {
                    slot = slot,
                    name = itm.name,
                    count = tonumber(itm.count) or 1,
                    label = itm.label or (itm.metadata and itm.metadata.label) or def.label or itm.name,
                    weight = itemWeight,
                    stack = (def.stack ~= false),
                    close = (def.close ~= false),
                    description = itm.description or def.description or "",
                    metadata = itm.metadata or {}
                }
            end
        end
        local plate = getElementData(targetVeh, "veh:plate") or "Araç"
        rightData = {
            id = "trunk_" .. tostring(getElementData(targetVeh, "veh:id") or "0"),
            label = "Bagaj (" .. plate .. ")",
            type = "trunk",
            slots = 40,
            weight = totalWeight,
            maxWeight = 80000,
            items = formattedItems
        }
    else
        rightData = getWorldDropsDataForPlayer(player)
    end

    triggerClientEvent(player, "ox_inventory:syncInventory", resourceRoot, leftData, rightData)
end

local PLAYER_INVENTORIES_FILE = "data/player_inventories.json"
local savedPlayerInventories = {}

local function saveAllPlayerInventoriesToFile()
    local jsonStr = toJSON(savedPlayerInventories, false)
    if not jsonStr or #jsonStr == 0 then return end

    local tempFile = PLAYER_INVENTORIES_FILE .. ".tmp"
    local bakFile = PLAYER_INVENTORIES_FILE .. ".bak"

    if fileExists(tempFile) then fileDelete(tempFile) end
    local tf = fileCreate(tempFile)
    if tf then
        local bytesWritten = fileWrite(tf, jsonStr)
        fileClose(tf)
        if bytesWritten and bytesWritten >= #jsonStr then
            if fileExists(PLAYER_INVENTORIES_FILE) then
                if fileExists(bakFile) then fileDelete(bakFile) end
                fileCopy(PLAYER_INVENTORIES_FILE, bakFile, true)
                fileDelete(PLAYER_INVENTORIES_FILE)
            end
            if not fileRename(tempFile, PLAYER_INVENTORIES_FILE) then
                if not fileCopy(tempFile, PLAYER_INVENTORIES_FILE, true) then
                    if fileExists(bakFile) and not fileExists(PLAYER_INVENTORIES_FILE) then
                        fileCopy(bakFile, PLAYER_INVENTORIES_FILE, true)
                    end
                else
                    fileDelete(tempFile)
                end
            end
        else
            if fileExists(tempFile) then fileDelete(tempFile) end
        end
    end
end

local function loadAllPlayerInventoriesFromFile()
    savedPlayerInventories = {}
    local filePath = PLAYER_INVENTORIES_FILE
    if not fileExists(filePath) and fileExists(filePath .. ".bak") then
        fileCopy(filePath .. ".bak", filePath, true)
    end
    if fileExists(filePath) then
        local f = fileOpen(filePath)
        if f then
            local size = fileGetSize(f)
            local content = size > 0 and fileRead(f, size) or ""
            fileClose(f)
            if content and #content > 0 then
                local data = fromJSON(content)
                if data and type(data) == "table" then
                    savedPlayerInventories = data
                end
            end
        end
    end
    outputDebugString("[OX_INVENTORY] Loaded " .. tostring(table.count(savedPlayerInventories)) .. " player inventories from file.")
end

function unloadPlayerInventory(player)
    if isElement(player) then
        savePlayerInventory(player)
        playerInventories[player] = nil
    end
end

local function getAuthoritativeCharId(player)
    if not isElement(player) or getElementType(player) ~= "player" then return nil end
    if exports.gzl_characters and exports.gzl_characters.getAuthoritativeCharacterID then
        local authId = exports.gzl_characters:getAuthoritativeCharacterID(player)
        return authId and tonumber(authId) or nil
    end
    if not getElementData(player, "loggedin_character") then
        return nil
    end
    local rawId = getElementData(player, "character:id") or getElementData(player, "char:id")
    return tonumber(rawId)
end

local function isPlayerAuthorized(player)
    if not isElement(player) or getElementType(player) ~= "player" then return false end
    local authId = getAuthoritativeCharId(player)
    if not authId then return false end
    local inv = playerInventories[player]
    if not inv or inv.id ~= ("char_" .. tostring(authId)) then return false end
    return true
end

local function getPlayerInventoryKey(player)
    if not isElement(player) then return nil end
    local charId = getAuthoritativeCharId(player)
    if charId then
        return "char_" .. tostring(charId)
    end
    return nil
end

local function syncPlayerCashItem(player, explicitCash)
    if not isElement(player) then return end
    local inv = playerInventories[player]
    if not inv or not inv.items then return end

    local currentCash = explicitCash
    if currentCash == nil then
        currentCash = tonumber(getElementData(player, "character:money") or getElementData(player, "char:money") or getPlayerMoney(player)) or 0
    end
    currentCash = math.max(0, math.floor(tonumber(currentCash) or 0))

    local foundSlot = nil
    for s = 1, (inv.slots or 40) do
        local itm = inv.items[s]
        if itm and itm.name == "cash" then
            if not foundSlot then
                foundSlot = s
            else
                inv.items[s] = nil
            end
        end
    end

    if currentCash > 0 then
        if foundSlot then
            if inv.items[foundSlot].count == currentCash then
                return
            end
            inv.items[foundSlot].count = currentCash
        else
            local targetSlot = nil
            if not inv.items[5] then
                targetSlot = 5
            else
                for s = 1, (inv.slots or 40) do
                    if not inv.items[s] then
                        targetSlot = s
                        break
                    end
                end
            end
            if targetSlot then
                inv.items[targetSlot] = {
                    slot = targetSlot,
                    name = "cash",
                    count = currentCash,
                    metadata = { label = "Nakit Para" }
                }
            end
        end
    else
        if foundSlot then
            inv.items[foundSlot] = nil
        else
            return
        end
    end
end

function loadPlayerInventory(player, doSync)
    if not isElement(player) then return end
    local key = getPlayerInventoryKey(player)
    if not key then return end

    local playerName = getElementData(player, "character:name") or getPlayerName(player)
    local saved = savedPlayerInventories[key]

    local items = {}
    if saved and saved.items and type(saved.items) == "table" then
        for k, itm in pairs(saved.items) do
            local slotNum = tonumber(itm.slot or k)
            if slotNum and itm.name then
                items[slotNum] = {
                    slot = slotNum,
                    name = itm.name,
                    count = tonumber(itm.count) or 1,
                    metadata = itm.metadata or {},
                    label = itm.label
                }
            end
        end
    else
        local playerCash = tonumber(getElementData(player, "character:money") or getElementData(player, "char:money") or getPlayerMoney(player)) or 2500
        items = {
            [1] = { slot = 1, name = "id_card", count = 1, metadata = { label = "Kimlik Kartı" } },
            [2] = { slot = 2, name = "phone", count = 1, metadata = { label = "Akıllı Telefon" } },
            [3] = { slot = 3, name = "burger", count = 1, metadata = { label = "Hamburger" } },
            [4] = { slot = 4, name = "water", count = 3, metadata = { label = "Su" } },
            [5] = { slot = 5, name = "cash", count = playerCash, metadata = { label = "Nakit Para" } }
        }
        savedPlayerInventories[key] = {
            id = key,
            label = playerName,
            items = items
        }
        saveAllPlayerInventoriesToFile()
    end

    playerInventories[player] = {
        id = key,
        label = playerName,
        type = "player",
        slots = 40,
        maxWeight = 30000,
        weight = 0,
        items = items
    }

    syncPlayerCashItem(player)

    if doSync ~= false then
        syncPlayerInventory(player)
    end
end

function savePlayerInventory(player)
    if not isElement(player) then return end
    local inv = playerInventories[player]
    if not inv or not inv.items then return end

    local key = getPlayerInventoryKey(player)
    if not key then return end

    local cleanItems = {}
    for slot = 1, (inv.slots or 40) do
        local itm = inv.items[slot] or inv.items[tostring(slot)]
        if not itm then
            for _, val in pairs(inv.items) do
                if val and tonumber(val.slot) == slot then
                    itm = val
                    break
                end
            end
        end
        if itm and itm.name and itm.count and tonumber(itm.count) > 0 then
            cleanItems[tostring(slot)] = {
                slot = slot,
                name = itm.name,
                count = tonumber(itm.count) or 1,
                metadata = itm.metadata or {},
                label = itm.label
            }
        end
    end

    savedPlayerInventories[key] = {
        id = key,
        label = inv.label or getPlayerName(player),
        items = cleanItems
    }

    saveAllPlayerInventoriesToFile()
end

function addItem(player, itemName, count, metadata)
    if not isElement(player) or not itemName then return false end
    count = tonumber(count) or 1
    local inv = playerInventories[player]
    if not inv or not inv.items then return false end
    if count ~= count or count < 1 or count > 100000000 or count ~= math.floor(count) then return false end
    local canInsert = false
    local stackable = not Items[itemName] or Items[itemName].stack ~= false
    for slot = 1, inv.slots do
        local existing = inv.items[slot]
        if not existing or (stackable and existing.name == itemName) then
            canInsert = true
            break
        end
    end
    if not canInsert then return false end

    if itemName == "cash" then
        local cur = tonumber(getElementData(player, "character:money") or getPlayerMoney(player)) or 0
        local updated = cur + count
        setElementData(player, "character:money", updated, "broadcast", "deny")
        setElementData(player, "char:money", updated, "broadcast", "deny")
        setPlayerMoney(player, updated)
        if exports.gzl_characters and exports.gzl_characters.saveCharacter then
            exports.gzl_characters:saveCharacter(player)
        end
    end

    local def = Items[itemName] or {}
    local isStackable = (def.stack ~= false)

    if isStackable then
        for s = 1, inv.slots do
            local itm = inv.items[s]
            if itm and itm.name == itemName then
                itm.count = itm.count + count
                savePlayerInventory(player)
                syncPlayerInventory(player)
                return true
            end
        end
    end

    for s = 1, inv.slots do
        if not inv.items[s] then
            inv.items[s] = {
                slot = s,
                name = itemName,
                count = count,
                metadata = metadata or {}
            }
            savePlayerInventory(player)
            syncPlayerInventory(player)
            if exports.gzl_logs and exports.gzl_logs.logItem then
                pcall(function() exports.gzl_logs:logItem(player, "add", itemName, count, nil, "Envantere eklendi") end)
            end
            return true
        end
    end

    return false
end

function removeItem(player, itemName, count)
    if not isElement(player) or not itemName then return false end
    count = tonumber(count) or 1
    if count <= 0 then return false end
    local inv = playerInventories[player]
    if not inv or not inv.items then return false end

    if not hasItem(player, itemName, count) then
        return false
    end

    local needed = count
    for s = 1, inv.slots do
        local itm = inv.items[s]
        if itm and itm.name == itemName then
            local itmCount = itm.count or 1
            if itmCount > needed then
                itm.count = itmCount - needed
                needed = 0
                break
            else
                needed = needed - itmCount
                inv.items[s] = nil
                if needed <= 0 then
                    break
                end
            end
        end
    end

    if itemName == "cash" then
        local cur = tonumber(getElementData(player, "character:money") or getPlayerMoney(player)) or 0
        local updated = math.max(0, cur - count)
        setElementData(player, "character:money", updated, "broadcast", "deny")
        setElementData(player, "char:money", updated, "broadcast", "deny")
        setPlayerMoney(player, updated)
        if exports.gzl_characters and exports.gzl_characters.saveCharacter then
            exports.gzl_characters:saveCharacter(player)
        end
    end

    savePlayerInventory(player)
    syncPlayerInventory(player)
    if exports.gzl_logs and exports.gzl_logs.logItem then
        pcall(function() exports.gzl_logs:logItem(player, "remove", itemName, count, nil, "Envanterden eksildi") end)
    end
    return true
end

function hasItem(player, itemName, count)
    count = tonumber(count) or 1
    local inv = playerInventories[player]
    if not inv then return false end

    local total = 0
    for _, itm in pairs(inv.items) do
        if itm and itm.name == itemName then
            total = total + (itm.count or 1)
        end
    end
    return total >= count
end

function getItemCount(player, itemName)
    local inv = playerInventories[player]
    if not inv then return 0 end
    local total = 0
    for _, itm in pairs(inv.items) do
        if itm and itm.name == itemName then
            total = total + (itm.count or 1)
        end
    end
    return total
end

function getPlayerItems(player)
    if not isElement(player) then return {} end
    local inv = playerInventories[player]
    if not inv or not inv.items then return {} end
    return inv.items
end

local weaponIds = {
    ["weapon_glock"] = 22,
    ["weapon_colt45"] = 22,
    ["weapon_pistol"] = 22,
    ["weapon_combatpistol"] = 22,
    ["weapon_appistol"] = 22,
    ["weapon_pistol50"] = 24,
    ["weapon_deagle"] = 24,
    ["weapon_revolver"] = 24,
    ["weapon_snspistol"] = 22,
    ["weapon_heavypistol"] = 24,
    ["weapon_microsmg"] = 28,
    ["weapon_smg"] = 29,
    ["weapon_mp5"] = 29,
    ["weapon_assaultsmg"] = 29,
    ["weapon_combatpdw"] = 29,
    ["weapon_pumpshotgun"] = 25,
    ["weapon_sawnoffshotgun"] = 26,
    ["weapon_assaultshotgun"] = 27,
    ["weapon_bullpupshotgun"] = 25,
    ["weapon_assaultrifle"] = 30,
    ["weapon_ak47"] = 30,
    ["weapon_carbinerifle"] = 31,
    ["weapon_m4"] = 31,
    ["weapon_advancedrifle"] = 31,
    ["weapon_sniperrifle"] = 34,
    ["weapon_heavysniper"] = 34,
    ["weapon_bat"] = 5,
    ["weapon_knife"] = 4,
    ["weapon_golfclub"] = 2,
    ["weapon_crowbar"] = 6,
    ["weapon_flashlight"] = 0
}

addEvent("ox_inventory:requestInventory", true)
addEventHandler("ox_inventory:requestInventory", root, function()
    if client then
        local ac = getResourceFromName("gzl_anticheat")
        if not ac or getResourceState(ac) ~= "running" or not exports.gzl_anticheat:allowEvent(client, "ox_inventory:requestInventory") then return end
    end
    local player = (client and isElement(client) and getElementType(client) == "player" and client) or (source and isElement(source) and getElementType(source) == "player" and source)
    if not player or not isElement(player) then return end
    local authId = getAuthoritativeCharId(player)
    if not authId then return end

    local expectedKey = "char_" .. tostring(authId)
    local inv = playerInventories[player]
    if not inv or inv.id ~= expectedKey then
        loadPlayerInventory(player, true)
    else
        syncPlayerCashItem(player)
        syncPlayerInventory(player)
    end
end)

addEvent("ox_inventory:useItem", true)
addEventHandler("ox_inventory:useItem", root, function(slot, count)
    local checkedSlot, checkedCount = tonumber(slot), tonumber(count or 1)
    if not checkedSlot or checkedSlot ~= checkedSlot or checkedSlot < 1 or checkedSlot > 10000 or checkedSlot ~= math.floor(checkedSlot) then return end
    if not checkedCount or checkedCount ~= checkedCount or checkedCount < 1 or checkedCount > 100000000 or checkedCount ~= math.floor(checkedCount) then return end
    if client then
        local ac = getResourceFromName("gzl_anticheat")
        if not ac or getResourceState(ac) ~= "running" or not exports.gzl_anticheat:allowEvent(client, "ox_inventory:useItem", slot, count) then return end
    end
    local player = (client and isElement(client) and getElementType(client) == "player" and client) or (source and isElement(source) and getElementType(source) == "player" and source)
    if not isPlayerAuthorized(player) then
        if isElement(player) then loadPlayerInventory(player, true) end
        return
    end
    local inv = playerInventories[player]
    if not inv or not inv.items then return end

    slot = tonumber(slot)
    if not slot then return end
    count = tonumber(count) or 1
    if count < 1 then count = 1 end

    local itm = inv.items[slot] or inv.items[tostring(slot)]
    if not itm then
        for _, val in pairs(inv.items) do
            if val and tonumber(val.slot) == slot then
                itm = val
                break
            end
        end
    end
    if not itm then return end

    local def = Items[itm.name] or {}
    local actualCount = math.min(count, itm.count or 1)
    local used = false
    local itemName = itm.name:lower()

    local FOOD_ITEMS = {
        ["burger"] = 35,
        ["hamburger"] = 35,
        ["sandwich"] = 30,
        ["bread"] = 25,
        ["taco"] = 35,
        ["fries"] = 25,
        ["chocolate"] = 20,
        ["donut"] = 25,
        ["pizza"] = 40,
        ["testburger"] = 35,
        ["apple"] = 20,
        ["chips"] = 20
    }

    local DRINK_ITEMS = {
        ["water"] = 40,
        ["cola"] = 40,
        ["coffee"] = 35,
        ["sprunk"] = 40,
        ["sprite"] = 40,
        ["orange_juice"] = 40,
        ["milkshake"] = 45,
        ["icetea"] = 40,
        ["energy_drink"] = 45,
        ["coconut_drink"] = 45,
        ["lemonade"] = 40,
        ["beer"] = 30,
        ["wine"] = 30
    }

    if FOOD_ITEMS[itemName] or (def and def.client and (def.client.type == "food" or (def.client.status and def.client.status.hunger))) then
        local currentHunger = tonumber(getElementData(player, "char:hunger")) or tonumber(getElementData(player, "character:hunger")) or tonumber(getElementData(player, "hunger")) or 100
        local hungerAdd = actualCount * (FOOD_ITEMS[itemName] or (def.client and def.client.status and def.client.status.hunger) or 35)
        local newHunger = math.min(100, currentHunger + hungerAdd)
        setElementData(player, "char:hunger", newHunger)
        setElementData(player, "character:hunger", newHunger)
        setElementData(player, "hunger", newHunger)
        local hp = getElementHealth(player)
        local healAmount = actualCount * 15
        setElementHealth(player, math.min(100, hp + healAmount))
        notifyPlayer(player, (itm.label or def.label or "Yiyecek") .. (actualCount > 1 and (" (" .. actualCount .. "x)") or "") .. " tükettiniz.", "success")
        used = true

    elseif DRINK_ITEMS[itemName] or (def and def.client and (def.client.type == "drink" or (def.client.status and def.client.status.thirst))) then
        local currentThirst = tonumber(getElementData(player, "char:thirst")) or tonumber(getElementData(player, "character:thirst")) or tonumber(getElementData(player, "thirst")) or 100
        local thirstAdd = actualCount * (DRINK_ITEMS[itemName] or (def.client and def.client.status and def.client.status.thirst) or 40)
        local newThirst = math.min(100, currentThirst + thirstAdd)
        setElementData(player, "char:thirst", newThirst)
        setElementData(player, "character:thirst", newThirst)
        setElementData(player, "thirst", newThirst)
        local hp = getElementHealth(player)
        local healAmount = actualCount * 5
        setElementHealth(player, math.min(100, hp + healAmount))
        notifyPlayer(player, (itm.label or def.label or "İçecek") .. (actualCount > 1 and (" (" .. actualCount .. "x)") or "") .. " tükettiniz.", "success")
        used = true

    elseif itemName == "bandage" then
        local hp = getElementHealth(player)
        local healAmount = actualCount * 40
        setElementHealth(player, math.min(100, hp + healAmount))
        notifyPlayer(player, "Bandaj uygulandı." .. (actualCount > 1 and (" (" .. actualCount .. "x)") or "") .. " (+" .. healAmount .. " Can)", "success")
        used = true

    elseif itemName == "medikit" or itemName == "firstaid" then
        local hp = getElementHealth(player)
        local healAmount = actualCount * 80
        setElementHealth(player, math.min(100, hp + healAmount))
        notifyPlayer(player, "İlk yardım kiti uygulandı." .. (actualCount > 1 and (" (" .. actualCount .. "x)") or "") .. " (+" .. healAmount .. " Can)", "success")
        used = true

    elseif itemName == "armor" or itemName == "armour" or itemName == "bodyarmour" or itemName == "heavyarmour" then
        setPedArmor(player, 100)
        actualCount = 1
        notifyPlayer(player, "Çelik yelek giyildi. (%100 Zırh)", "success")
        used = true

    elseif itemName == "repairkit" then
        local veh = getPedOccupiedVehicle(player)
        if not veh then
            local px, py, pz = getElementPosition(player)
            for _, v in ipairs(getElementsByType("vehicle")) do
                local vx, vy, vz = getElementPosition(v)
                if getDistanceBetweenPoints3D(px, py, pz, vx, vy, vz) <= 4.0 then
                    veh = v
                    break
                end
            end
        end
        if veh then
            fixVehicle(veh)
            setPedAnimation(player, "CAR", "Fixn_Car_Loop", 3500, false, false, false, false)
            notifyPlayer(player, "Araç başarıyla tamir edildi.", "success")
            actualCount = 1
            used = true
        else
            notifyPlayer(player, "Yakında tamir edilecek araç bulunamadı!", "error")
        end

    elseif itemName == "lockpick" then
        local px, py, pz = getElementPosition(player)
        local unlocked = false
        for _, v in ipairs(getElementsByType("vehicle")) do
            local vx, vy, vz = getElementPosition(v)
            if getDistanceBetweenPoints3D(px, py, pz, vx, vy, vz) <= 4.0 then
                setVehicleLocked(v, false)
                setPedAnimation(player, "BOMBER", "BOM_Plant", 2500, false, false, false, false)
                notifyPlayer(player, "Aracın kilidi açıldı.", "success")
                unlocked = true
                actualCount = 1
                used = true
                break
            end
        end
        if not unlocked then
            notifyPlayer(player, "Yakında kilitlenecek/açılacak araç yok!", "error")
        end

    elseif itemName == "carkey" then
        local px, py, pz = getElementPosition(player)
        local pDim = getElementDimension(player)
        local pInt = getElementInterior(player)
        local toggled = false
        local keyPlate = itm.metadata and (itm.metadata.plate or itm.metadata.Plate)
        local keyVehId = itm.metadata and (itm.metadata.vehid or itm.metadata.vehicle_id or itm.metadata.dbid)
        local charId = getElementData(player, "character:id") or getElementData(player, "char:id")

        for _, v in ipairs(getElementsByType("vehicle")) do
            if getElementDimension(v) == pDim and getElementInterior(v) == pInt then
                local vx, vy, vz = getElementPosition(v)
                if getDistanceBetweenPoints3D(px, py, pz, vx, vy, vz) <= 5.0 then
                    local vPlate = getElementData(v, "veh:plate") or getElementData(v, "plate") or getVehiclePlateText(v)
                    local vOwner = getElementData(v, "veh:owner") or getElementData(v, "owner")
                    local vId = getElementData(v, "veh:id") or getElementData(v, "dbid")

                    local isMatch = false
                    if keyPlate and vPlate and string.upper(tostring(keyPlate)) == string.upper(tostring(vPlate)) then
                        isMatch = true
                    elseif keyVehId and vId and tonumber(keyVehId) == tonumber(vId) then
                        isMatch = true
                    elseif not keyPlate and not keyVehId then
                        if vOwner and charId and tonumber(vOwner) == tonumber(charId) then
                            isMatch = true
                        end
                    end

                    if isMatch then
                        local locked = isVehicleLocked(v)
                        local newState = not locked
                        setVehicleLocked(v, newState)
                        setElementData(v, "veh:locked", newState)
                        if exports.gzl_vehicles and exports.gzl_vehicles.saveVehicleToDB then
                            exports.gzl_vehicles:saveVehicleToDB(v)
                        end
                        notifyPlayer(player, newState and "Araç kilitlendi." or "Araç kilitleri açıldı.", newState and "warning" or "success")
                        toggled = true
                        break
                    end
                end
            end
        end
        if not toggled then
            notifyPlayer(player, "Bu anahtara uyan yakında bir araç bulunamadı.", "error")
        end

    elseif itemName == "phone" or itemName == "classic_phone" or itemName == "smartphone" or itemName == "iphone" or itemName == "black_phone" or itemName == "blue_phone" or itemName == "gold_phone" or itemName == "green_phone" then
        triggerClientEvent(player, "gzl_phone:togglePhone", player)
        triggerClientEvent(player, "high_phone:togglePhone", player)

    elseif itemName == "painkillers" then
        local hp = getElementHealth(player)
        local healAmount = actualCount * 30
        setElementHealth(player, math.min(100, hp + healAmount))
        notifyPlayer(player, "Ağrı kesici aldınız." .. (actualCount > 1 and (" (" .. actualCount .. "x)") or "") .. " (+" .. healAmount .. " Can)", "success")
        used = true

    elseif itemName == "aspirin" then
        local hp = getElementHealth(player)
        local healAmount = actualCount * 20
        setElementHealth(player, math.min(100, hp + healAmount))
        notifyPlayer(player, "Aspirin aldınız." .. (actualCount > 1 and (" (" .. actualCount .. "x)") or "") .. " (+" .. healAmount .. " Can)", "success")
        used = true

    elseif itemName == "coughsyrup" then
        local hp = getElementHealth(player)
        setElementHealth(player, math.min(100, hp + 15 * actualCount))
        local currentThirst = tonumber(getElementData(player, "char:thirst")) or 100
        local newThirst = math.min(100, currentThirst + 15 * actualCount)
        setElementData(player, "char:thirst", newThirst)
        setElementData(player, "character:thirst", newThirst)
        notifyPlayer(player, "Öksürük şurubu içtiniz. Boğazınız rahatladı.", "success")
        used = true

    elseif itemName == "vitamins" or itemName == "energy_booster" then
        local hp = getElementHealth(player)
        setElementHealth(player, math.min(100, hp + 15 * actualCount))
        local curH = tonumber(getElementData(player, "char:hunger")) or 100
        local curT = tonumber(getElementData(player, "char:thirst")) or 100
        setElementData(player, "char:hunger", math.min(100, curH + 15 * actualCount))
        setElementData(player, "character:hunger", math.min(100, curH + 15 * actualCount))
        setElementData(player, "char:thirst", math.min(100, curT + 20 * actualCount))
        setElementData(player, "character:thirst", math.min(100, curT + 20 * actualCount))
        notifyPlayer(player, "Takviye gıda aldınız, enerjiniz yükseldi.", "success")
        used = true

    elseif itemName == "defibrillator" then
        local px, py, pz = getElementPosition(player)
        local revived = false
        for _, p in ipairs(getElementsByType("player")) do
            if p ~= player and getElementData(p, "ems:isDead") then
                local tx, ty, tz = getElementPosition(p)
                if getDistanceBetweenPoints3D(px, py, pz, tx, ty, tz) <= 4.0 then
                    setPedAnimation(player, "BOMBER", "BOM_Plant", 3000, false, false, false, false)
                    setElementHealth(p, 50)
                    setElementData(p, "ems:isDead", false, true)
                    triggerClientEvent(p, "gzl_ems:onClientRevived", p)
                    notifyPlayer(player, "Şok cihazını uygulayarak " .. getPlayerName(p) .. " adlı hastanın kalbini yeniden çalıştırdınız!", "success")
                    notifyPlayer(p, getPlayerName(player) .. " elektroşok cihazıyla sizi hayata döndürdü!", "success")
                    revived = true
                    actualCount = 1
                    used = true
                    break
                end
            end
        end
        if not revived then
            notifyPlayer(player, "Yakınınızda elektroşok uygulanacak komada yaralı bir oyuncu bulunamadı!", "error")
        end

    elseif string.lower(tostring(itemName)) == "ammo-9" or string.lower(tostring(itemName)) == "ammo_9" then
        local wId = getPedWeapon(player)
        local validPistols = { [22] = true, [23] = true, [24] = true, [28] = true, [29] = true, [32] = true }
        if wId and validPistols[wId] then
            local rounds = actualCount * 50
            giveWeapon(player, wId, rounds, false)
            notifyPlayer(player, "Silahınıza " .. rounds .. " adet 9mm mermi yüklendi.", "success")
            used = true
        else
            notifyPlayer(player, "9mm mermiyi doldurmak için elinize uyumlu bir tabanca veya hafif makineli silah almalısınız.", "error")
        end

    elseif string.lower(tostring(itemName)) == "ammo-shotgun" or string.lower(tostring(itemName)) == "ammo_shotgun" then
        local wId = getPedWeapon(player)
        local validShotguns = { [25] = true, [26] = true, [27] = true }
        if wId and validShotguns[wId] then
            local rounds = actualCount * 25
            giveWeapon(player, wId, rounds, false)
            notifyPlayer(player, "Tüfeğinize " .. rounds .. " adet pompalı fişeği yüklendi.", "success")
            used = true
        else
            notifyPlayer(player, "Pompalı fişeklerini doldurmak için elinize bir pompalı tüfek almalısınız.", "error")
        end

    elseif string.lower(tostring(itemName)) == "ammo-smg" or string.lower(tostring(itemName)) == "ammo_smg" then
        local wId = getPedWeapon(player)
        local validSMGs = { [28] = true, [29] = true, [32] = true }
        if wId and validSMGs[wId] then
            local rounds = actualCount * 50
            giveWeapon(player, wId, rounds, false)
            notifyPlayer(player, "Silahınıza " .. rounds .. " adet SMG mermisi yüklendi.", "success")
            used = true
        else
            notifyPlayer(player, "SMG mermisini doldurmak için elinize bir hafif makineli silah almalısınız.", "error")
        end

    elseif itemName == "id_card" or itemName == "identification" or itemName == "driving_license" then
        notifyPlayer(player, "Adı Soyadı: " .. getPlayerName(player) .. " | Hesap: " .. getPlayerAccountName(player), "info")

    elseif itemName == "radio" or itemName == "highradio" or itemName == "lowradio" or itemName == "radioscanner" then
        local radioResource = getResourceFromName("gzl_radio")
        if radioResource and getResourceState(radioResource) == "running" then
            if exports.gzl_radio and exports.gzl_radio.toggleRadio then
                exports.gzl_radio:toggleRadio(player)
            elseif exports.gzl_radio and exports.gzl_radio.openRadio then
                exports.gzl_radio:openRadio(player)
            end
        else
            notifyPlayer(player, "Telsiz sistemi aktif değil.", "error")
        end

    elseif itemName == "cigaret" or itemName == "cigarette" then
        setPedAnimation(player, "SMOKING", "M_smkstnd_loop", 4000, false, false, false, false)
        notifyPlayer(player, "Sigara içtiniz.", "info")
        actualCount = 1
        used = true

    elseif weaponIds[string.lower(tostring(itemName))] or weaponIds[itemName] then
        local wId = weaponIds[string.lower(tostring(itemName))] or weaponIds[itemName]
        if wId > 0 then
            local currentWeapon = getPedWeapon(player)
            local weaponSlot = getSlotFromWeapon(wId)
            local equipped = equippedWeaponItems[player]
            if not equipped then equipped = {}; equippedWeaponItems[player] = equipped end
            local previous = equipped[weaponSlot]
            if previous and previous.item ~= itm and getPedWeapon(player, weaponSlot) == previous.weapon then
                previous.item.metadata = previous.item.metadata or {}
                previous.item.metadata.ammo = getPedTotalAmmo(player, weaponSlot)
            end
            itm.metadata = itm.metadata or {}
            if getPedWeapon(player, weaponSlot) == wId then
                itm.metadata.ammo = getPedTotalAmmo(player, weaponSlot)
            end
            if currentWeapon == wId then
                equipped[weaponSlot] = nil
                takeWeapon(player, wId)
                savePlayerInventory(player)
                notifyPlayer(player, "Silahı kılıfına koydunuz.", "info")
            else
                local ammo = tonumber(itm.metadata.ammo) or 100
                ammo = math.max(0, math.min(100000, math.floor(ammo)))
                itm.metadata.ammo = ammo
                takeWeapon(player, wId)
                giveWeapon(player, wId, ammo, true)
                equipped[weaponSlot] = {weapon = wId, item = itm}
                savePlayerInventory(player)
                setPedWeaponSlot(player, getSlotFromWeapon(wId))
                notifyPlayer(player, "Silah kuşandınız.", "info")
            end
        end
    end

    if used then
        if itm.count > actualCount then
            itm.count = itm.count - actualCount
        else
            inv.items[slot] = nil
            inv.items[tostring(slot)] = nil
            for k, val in pairs(inv.items) do
                if val and tonumber(val.slot) == slot then
                    inv.items[k] = nil
                end
            end
        end
        savePlayerInventory(player)
        syncPlayerInventory(player)
    end
end)

addEvent("ox_inventory:giveItem", true)
addEventHandler("ox_inventory:giveItem", root, function(slot, count)
    local checkedSlot, checkedCount = tonumber(slot), tonumber(count or 1)
    if not checkedSlot or checkedSlot ~= checkedSlot or checkedSlot < 1 or checkedSlot > 10000 or checkedSlot ~= math.floor(checkedSlot) then return end
    if not checkedCount or checkedCount ~= checkedCount or checkedCount < 1 or checkedCount > 100000000 or checkedCount ~= math.floor(checkedCount) then return end
    if client then
        local ac = getResourceFromName("gzl_anticheat")
        if not ac or getResourceState(ac) ~= "running" or not exports.gzl_anticheat:allowEvent(client, "ox_inventory:giveItem", slot, count) then return end
    end
    local player = (client and isElement(client) and getElementType(client) == "player" and client) or (source and isElement(source) and getElementType(source) == "player" and source)
    if not isPlayerAuthorized(player) then
        if isElement(player) then loadPlayerInventory(player, true) end
        return
    end
    local inv = playerInventories[player]
    if not inv or not inv.items then return end

    slot = tonumber(slot)
    if not slot then return end
    count = tonumber(count) or 1
    if count < 1 then count = 1 end

    local itm = inv.items[slot] or inv.items[tostring(slot)]
    if not itm then
        for _, val in pairs(inv.items) do
            if val and tonumber(val.slot) == slot then
                itm = val
                break
            end
        end
    end
    if not itm then return end

    local giveCount = math.min(count, itm.count or 1)

    local px, py, pz = getElementPosition(player)
    local pDim = getElementDimension(player)
    local pInt = getElementInterior(player)
    local targetPlayer = nil
    local minDist = 3.5

    for _, p in ipairs(getElementsByType("player")) do
        if p ~= player and isElement(p) and getElementDimension(p) == pDim and getElementInterior(p) == pInt then
            local pLogged = getElementData(p, "character:id") or getElementData(p, "char:id") or getElementData(p, "loggedin") or getElementData(p, "loggedin_character")
            if pLogged then
                local tx, ty, tz = getElementPosition(p)
                local dist = getDistanceBetweenPoints3D(px, py, pz, tx, ty, tz)
                if dist < minDist then
                    minDist = dist
                    targetPlayer = p
                end
            end
        end
    end

    if not targetPlayer then
        outputChatBox("#ef4444[ENVANTER] #ffffffYakınınızda eşyayı verebileceğiniz bir oyuncu yok!", player, 255, 255, 255, true)
        return
    end

    local added = addItem(targetPlayer, itm.name, giveCount, itm.metadata)
    if added then
        if itm.count > giveCount then
            itm.count = itm.count - giveCount
        else
            inv.items[slot] = nil
            inv.items[tostring(slot)] = nil
        end
        if itm.name == "cash" then
            local pCur = tonumber(getElementData(player, "character:money") or getPlayerMoney(player)) or 0
            local pNew = math.max(0, pCur - giveCount)
            setElementData(player, "character:money", pNew, "broadcast", "deny")
            setElementData(player, "char:money", pNew, "broadcast", "deny")
            setPlayerMoney(player, pNew)
            if exports.gzl_characters and exports.gzl_characters.saveCharacter then
                exports.gzl_characters:saveCharacter(player)
            end
        end
        savePlayerInventory(player)
        syncPlayerInventory(player)
        outputChatBox("#38bdf8[ENVANTER] #ffffff" .. (itm.label or itm.name) .. " (" .. giveCount .. "x) " .. getPlayerName(targetPlayer) .. " adlı oyuncuya verildi.", player, 255, 255, 255, true)
        outputChatBox("#38bdf8[ENVANTER] #ffffff" .. getPlayerName(player) .. " size " .. (itm.label or itm.name) .. " (" .. giveCount .. "x) verdi.", targetPlayer, 255, 255, 255, true)
        if exports.gzl_logs and exports.gzl_logs.logItem then
            pcall(function() exports.gzl_logs:logItem(player, "give", itm.name, giveCount, targetPlayer, "Eşya transferi") end)
        end
        if itm.name == "cash" and exports.gzl_logs and exports.gzl_logs.logMoney then
            pcall(function() exports.gzl_logs:logMoney(player, targetPlayer, giveCount, "cash_trade", "Elden para verildi") end)
        end
    else
        outputChatBox("#ef4444[ENVANTER] #ffffffHedef oyuncunun envanteri dolu!", player, 255, 255, 255, true)
    end
end)

addEvent("ox_inventory:swapItems", true)
addEventHandler("ox_inventory:swapItems", root, function(fromSlot, toSlot, fromType, toType, count)
    if client then
        local ac = getResourceFromName("gzl_anticheat")
        if not ac or getResourceState(ac) ~= "running" or not exports.gzl_anticheat:allowEvent(client, "ox_inventory:swapItems", fromSlot, toSlot, fromType, toType, count) then return end
    end
    local player = (client and isElement(client) and getElementType(client) == "player" and client) or (source and isElement(source) and getElementType(source) == "player" and source)
    if not isPlayerAuthorized(player) then
        if isElement(player) then loadPlayerInventory(player, true) end
        return
    end
    local inv = playerInventories[player]
    if not inv or not inv.items then return end

    fromSlot = tonumber(fromSlot)
    toSlot = tonumber(toSlot)
    count = tonumber(count) or 0
    fromType = tostring(fromType or "player")
    toType = tostring(toType or "player")

    local limits = {player = inv.slots or 40, drop = 40, trunk = 40, glovebox = 10}
    if not limits[fromType] or not limits[toType] then return end
    if not fromSlot or fromSlot ~= fromSlot or fromSlot < 1 or fromSlot > limits[fromType] or fromSlot ~= math.floor(fromSlot) then return end
    if not toSlot or toSlot ~= toSlot or toSlot < 1 or toSlot > limits[toType] or toSlot ~= math.floor(toSlot) then return end
    if count ~= count or count < 0 or count > 100000000 or count ~= math.floor(count) then return end
    if fromType == toType and fromSlot == toSlot then return end

    if fromType == "player" and toType == "player" then
        local itemA = inv.items[fromSlot] or inv.items[tostring(fromSlot)]
        if not itemA then return end
        local itemB = inv.items[toSlot] or inv.items[tostring(toSlot)]

        if count > 0 and count < itemA.count then
            if not itemB then
                itemA.count = itemA.count - count
                inv.items[toSlot] = {
                    slot = toSlot,
                    name = itemA.name,
                    count = count,
                    metadata = itemA.metadata or {}
                }
            elseif itemB.name == itemA.name then
                itemA.count = itemA.count - count
                itemB.count = itemB.count + count
            end
        else
            if not itemB then
                itemA.slot = toSlot
                inv.items[toSlot] = itemA
                inv.items[fromSlot] = nil
            elseif itemB.name == itemA.name then
                itemB.count = itemB.count + itemA.count
                inv.items[fromSlot] = nil
            else
                itemA.slot = toSlot
                itemB.slot = fromSlot
                inv.items[toSlot] = itemA
                inv.items[fromSlot] = itemB
            end
        end
        savePlayerInventory(player)
        syncPlayerInventory(player)

    elseif fromType == "player" and toType == "drop" then
        local itemA = inv.items[fromSlot]
        if not itemA then return end
        local dropCount = (count > 0 and count < itemA.count) and count or itemA.count

        local drop = getNearestDropForPlayer(player)
        if not drop then
            local px, py, pz = getElementPosition(player)
            local pDim = getElementDimension(player)
            local pInt = getElementInterior(player)
            local newId = 1
            while worldDrops[newId] do newId = newId + 1 end
            drop = {
                id = newId,
                x = px,
                y = py,
                z = pz,
                dimension = pDim,
                interior = pInt,
                items = {}
            }
            worldDrops[newId] = drop
        end

        local itemB = drop.items[toSlot]
        if not itemB then
            drop.items[toSlot] = {
                slot = toSlot,
                name = itemA.name,
                count = dropCount,
                metadata = itemA.metadata or {}
            }
        elseif itemB.name == itemA.name then
            itemB.count = itemB.count + dropCount
        else
            local freeSlot = nil
            for s = 1, 40 do
                if not drop.items[s] then
                    freeSlot = s
                    break
                end
            end
            if freeSlot then
                drop.items[freeSlot] = {
                    slot = freeSlot,
                    name = itemA.name,
                    count = dropCount,
                    metadata = itemA.metadata or {}
                }
            else
                outputChatBox("#ef4444[DÜNYA] #ffffffDünya envanteri dolu!", player, 255, 255, 255, true)
                return
            end
        end

        if itemA.count > dropCount then
            itemA.count = itemA.count - dropCount
        else
            inv.items[fromSlot] = nil
        end

        if itemA.name == "cash" then
            local pCur = tonumber(getElementData(player, "character:money") or getPlayerMoney(player)) or 0
            local pNew = math.max(0, pCur - dropCount)
            setElementData(player, "character:money", pNew, "broadcast", "deny")
            setElementData(player, "char:money", pNew, "broadcast", "deny")
            setPlayerMoney(player, pNew)
            if exports.gzl_characters and exports.gzl_characters.saveCharacter then
                exports.gzl_characters:saveCharacter(player)
            end
        end

        createDropObject(drop)
        savePlayerInventory(player)
        syncPlayerInventory(player)
        syncWorldDropsForNearby(drop.x, drop.y, drop.z, drop.dimension, drop.interior)
        local itemLabel = itemA.label or (itemA.metadata and itemA.metadata.label) or itemA.name
        outputChatBox("#38bdf8[ENVANTER] #ffffff" .. itemLabel .. " (" .. dropCount .. "x) yere bırakıldı.", player, 255, 255, 255, true)
        if exports.gzl_logs and exports.gzl_logs.logItem then
            pcall(function() exports.gzl_logs:logItem(player, "drop", itemA.name, dropCount, nil, "Yere eşya bırakıldı") end)
        end

    elseif fromType == "drop" and toType == "player" then
        local drop = getNearestDropForPlayer(player)
        if not drop or not drop.items then return end

        local itemA = drop.items[fromSlot]
        if not itemA then return end
        local takeCount = (count > 0 and count < itemA.count) and count or itemA.count
        local itemB = inv.items[toSlot]

        if not itemB then
            inv.items[toSlot] = {
                slot = toSlot,
                name = itemA.name,
                count = takeCount,
                metadata = itemA.metadata or {}
            }
        elseif itemB.name == itemA.name then
            itemB.count = itemB.count + takeCount
        else
            local freeSlot = nil
            for s = 1, (inv.slots or 40) do
                if not inv.items[s] then
                    freeSlot = s
                    break
                end
            end
            if freeSlot then
                inv.items[freeSlot] = {
                    slot = freeSlot,
                    name = itemA.name,
                    count = takeCount,
                    metadata = itemA.metadata or {}
                }
            else
                outputChatBox("#ef4444[ENVANTER] #ffffffEnvanteriniz dolu!", player, 255, 255, 255, true)
                return
            end
        end

        if itemA.count > takeCount then
            itemA.count = itemA.count - takeCount
        else
            drop.items[fromSlot] = nil
        end

        if itemA.name == "cash" then
            local pCur = tonumber(getElementData(player, "character:money") or getPlayerMoney(player)) or 0
            local pNew = pCur + takeCount
            setElementData(player, "character:money", pNew, "broadcast", "deny")
            setElementData(player, "char:money", pNew, "broadcast", "deny")
            setPlayerMoney(player, pNew)
            if exports.gzl_characters and exports.gzl_characters.saveCharacter then
                exports.gzl_characters:saveCharacter(player)
            end
        end

        local dx, dy, dz, dim, int = drop.x, drop.y, drop.z, drop.dimension, drop.interior

        if table.count(drop.items) == 0 then
            if drop.element and isElement(drop.element) then
                destroyElement(drop.element)
            end
            worldDrops[drop.id] = nil
        else
            createDropObject(drop)
        end

        savePlayerInventory(player)
        syncPlayerInventory(player)
        syncWorldDropsForNearby(dx, dy, dz, dim, int)
        local itemLabel = itemA.label or (itemA.metadata and itemA.metadata.label) or itemA.name
        outputChatBox("#38bdf8[ENVANTER] #ffffff" .. itemLabel .. " (" .. takeCount .. "x) yerden alındı.", player, 255, 255, 255, true)
        if exports.gzl_logs and exports.gzl_logs.logItem then
            pcall(function() exports.gzl_logs:logItem(player, "pickup", itemA.name, takeCount, nil, "Yerden eşya alındı") end)
        end

    elseif fromType == "drop" and toType == "drop" then
        local drop = getNearestDropForPlayer(player)
        if not drop or not drop.items then return end

        local itemA = drop.items[fromSlot]
        if not itemA then return end
        local itemB = drop.items[toSlot]

        if count > 0 and count < itemA.count then
            if not itemB then
                itemA.count = itemA.count - count
                drop.items[toSlot] = {
                    slot = toSlot,
                    name = itemA.name,
                    count = count,
                    metadata = itemA.metadata or {}
                }
            elseif itemB.name == itemA.name then
                itemA.count = itemA.count - count
                itemB.count = itemB.count + count
            end
        else
            if not itemB then
                itemA.slot = toSlot
                drop.items[toSlot] = itemA
                drop.items[fromSlot] = nil
            elseif itemB.name == itemA.name then
                itemB.count = itemB.count + itemA.count
                drop.items[fromSlot] = nil
            else
                itemA.slot = toSlot
                itemB.slot = fromSlot
                drop.items[toSlot] = itemA
                drop.items[fromSlot] = itemB
            end
        end
        syncWorldDropsForNearby(drop.x, drop.y, drop.z, drop.dimension, drop.interior)

    elseif fromType == "player" and (toType == "trunk" or toType == "glovebox") then
        local targetVeh, vehType = getTargetVehicleForPlayer(player)
        if not targetVeh then return end
        local fieldName = (toType == "trunk") and "trunk_items" or "glovebox_items"
        local vehItems = getVehicleItemsTable(targetVeh, fieldName)

        local itemA = inv.items[fromSlot]
        if not itemA then return end
        local transferCount = (count > 0 and count < itemA.count) and count or itemA.count
        local itemB = vehItems[toSlot]

        if not itemB then
            vehItems[toSlot] = {
                slot = toSlot,
                name = itemA.name,
                count = transferCount,
                metadata = itemA.metadata or {}
            }
        elseif itemB.name == itemA.name then
            itemB.count = itemB.count + transferCount
        else
            local maxSlots = (toType == "trunk") and 40 or 10
            local freeSlot = nil
            for s = 1, maxSlots do
                if not vehItems[s] then
                    freeSlot = s
                    break
                end
            end
            if freeSlot then
                vehItems[freeSlot] = {
                    slot = freeSlot,
                    name = itemA.name,
                    count = transferCount,
                    metadata = itemA.metadata or {}
                }
            else
                outputChatBox("#ef4444[ARAÇ] #ffffffAraç deposu dolu!", player, 255, 255, 255, true)
                return
            end
        end

        if itemA.count > transferCount then
            itemA.count = itemA.count - transferCount
        else
            inv.items[fromSlot] = nil
        end

        if itemA.name == "cash" then
            local pCur = tonumber(getElementData(player, "character:money") or getPlayerMoney(player)) or 0
            local pNew = math.max(0, pCur - transferCount)
            setElementData(player, "character:money", pNew, "broadcast", "deny")
            setElementData(player, "char:money", pNew, "broadcast", "deny")
            setPlayerMoney(player, pNew)
            if exports.gzl_characters and exports.gzl_characters.saveCharacter then
                exports.gzl_characters:saveCharacter(player)
            end
        end

        setVehicleItemsTable(targetVeh, fieldName, vehItems)
        savePlayerInventory(player)
        syncPlayerInventory(player)

    elseif (fromType == "trunk" or fromType == "glovebox") and toType == "player" then
        local targetVeh, vehType = getTargetVehicleForPlayer(player)
        if not targetVeh then return end
        local fieldName = (fromType == "trunk") and "trunk_items" or "glovebox_items"
        local vehItems = getVehicleItemsTable(targetVeh, fieldName)

        local itemA = vehItems[fromSlot]
        if not itemA then return end
        local takeCount = (count > 0 and count < itemA.count) and count or itemA.count
        local itemB = inv.items[toSlot]

        if not itemB then
            inv.items[toSlot] = {
                slot = toSlot,
                name = itemA.name,
                count = takeCount,
                metadata = itemA.metadata or {}
            }
        elseif itemB.name == itemA.name then
            itemB.count = itemB.count + takeCount
        else
            local freeSlot = nil
            for s = 1, (inv.slots or 40) do
                if not inv.items[s] then
                    freeSlot = s
                    break
                end
            end
            if freeSlot then
                inv.items[freeSlot] = {
                    slot = freeSlot,
                    name = itemA.name,
                    count = takeCount,
                    metadata = itemA.metadata or {}
                }
            else
                outputChatBox("#ef4444[ENVANTER] #ffffffEnvanteriniz dolu!", player, 255, 255, 255, true)
                return
            end
        end

        if itemA.count > takeCount then
            itemA.count = itemA.count - takeCount
        else
            vehItems[fromSlot] = nil
        end

        if itemA.name == "cash" then
            local pCur = tonumber(getElementData(player, "character:money") or getPlayerMoney(player)) or 0
            local pNew = pCur + takeCount
            setElementData(player, "character:money", pNew, "broadcast", "deny")
            setElementData(player, "char:money", pNew, "broadcast", "deny")
            setPlayerMoney(player, pNew)
            if exports.gzl_characters and exports.gzl_characters.saveCharacter then
                exports.gzl_characters:saveCharacter(player)
            end
        end

        setVehicleItemsTable(targetVeh, fieldName, vehItems)
        savePlayerInventory(player)
        syncPlayerInventory(player)

    elseif (fromType == "trunk" and toType == "trunk") or (fromType == "glovebox" and toType == "glovebox") then
        local targetVeh, vehType = getTargetVehicleForPlayer(player)
        if not targetVeh then return end
        local fieldName = (fromType == "trunk") and "trunk_items" or "glovebox_items"
        local vehItems = getVehicleItemsTable(targetVeh, fieldName)

        local itemA = vehItems[fromSlot]
        if not itemA then return end
        local itemB = vehItems[toSlot]

        if count > 0 and count < itemA.count then
            if not itemB then
                itemA.count = itemA.count - count
                vehItems[toSlot] = {
                    slot = toSlot,
                    name = itemA.name,
                    count = count,
                    metadata = itemA.metadata or {}
                }
            elseif itemB.name == itemA.name then
                itemA.count = itemA.count - count
                itemB.count = itemB.count + count
            end
        else
            if not itemB then
                itemA.slot = toSlot
                vehItems[toSlot] = itemA
                vehItems[fromSlot] = nil
            elseif itemB.name == itemA.name then
                itemB.count = itemB.count + itemA.count
                vehItems[fromSlot] = nil
            else
                itemA.slot = toSlot
                itemB.slot = fromSlot
                vehItems[toSlot] = itemA
                vehItems[fromSlot] = itemB
            end
        end
        setVehicleItemsTable(targetVeh, fieldName, vehItems)
        syncPlayerInventory(player)
    end
end)

addEvent("ox_inventory:dropItem", true)
addEventHandler("ox_inventory:dropItem", root, function(slot, count)
    local checkedSlot, checkedCount = tonumber(slot), tonumber(count or 1)
    if not checkedSlot or checkedSlot ~= checkedSlot or checkedSlot < 1 or checkedSlot > 10000 or checkedSlot ~= math.floor(checkedSlot) then return end
    if not checkedCount or checkedCount ~= checkedCount or checkedCount < 1 or checkedCount > 100000000 or checkedCount ~= math.floor(checkedCount) then return end
    if client then
        local ac = getResourceFromName("gzl_anticheat")
        if not ac or getResourceState(ac) ~= "running" or not exports.gzl_anticheat:allowEvent(client, "ox_inventory:dropItem", slot, count) then return end
    end
    local player = (client and isElement(client) and getElementType(client) == "player" and client) or (source and isElement(source) and getElementType(source) == "player" and source)
    if not isPlayerAuthorized(player) then
        if isElement(player) then loadPlayerInventory(player, true) end
        return
    end
    local inv = playerInventories[player]
    if not inv or not inv.items then return end

    slot = tonumber(slot)
    if not slot then return end
    count = tonumber(count) or 1
    if count < 1 then count = 1 end

    local itm = inv.items[slot] or inv.items[tostring(slot)]
    if not itm then
        for _, val in pairs(inv.items) do
            if val and tonumber(val.slot) == slot then
                itm = val
                break
            end
        end
    end
    if not itm then return end

    local dropCount = math.min(count, itm.count or 1)
    local itemLabel = itm.label or (itm.metadata and itm.metadata.label) or itm.name

    local drop = getNearestDropForPlayer(player)
    if not drop then
        local px, py, pz = getElementPosition(player)
        local pDim = getElementDimension(player)
        local pInt = getElementInterior(player)
        local newId = 1
        while worldDrops[newId] do newId = newId + 1 end
        drop = {
            id = newId,
            x = px,
            y = py,
            z = pz,
            dimension = pDim,
            interior = pInt,
            items = {}
        }
        worldDrops[newId] = drop
    end

    local targetSlot = nil
    for s = 1, 40 do
        if drop.items[s] and drop.items[s].name == itm.name then
            targetSlot = s
            break
        end
    end
    if not targetSlot then
        for s = 1, 40 do
            if not drop.items[s] then
                targetSlot = s
                break
            end
        end
    end

    if not targetSlot then
        outputChatBox("#ef4444[DÜNYA] #ffffffDünya envanteri dolu!", player, 255, 255, 255, true)
        return
    end

    if drop.items[targetSlot] then
        drop.items[targetSlot].count = drop.items[targetSlot].count + dropCount
    else
        drop.items[targetSlot] = {
            slot = targetSlot,
            name = itm.name,
            count = dropCount,
            metadata = itm.metadata or {}
        }
    end

    if itm.count > dropCount then
        itm.count = itm.count - dropCount
    else
        inv.items[slot] = nil
        inv.items[tostring(slot)] = nil
    end

    if itm.name == "cash" then
        local pCur = tonumber(getElementData(player, "character:money") or getPlayerMoney(player)) or 0
        local pNew = math.max(0, pCur - dropCount)
        setElementData(player, "character:money", pNew, "broadcast", "deny")
        setElementData(player, "char:money", pNew, "broadcast", "deny")
        setPlayerMoney(player, pNew)
        if exports.gzl_characters and exports.gzl_characters.saveCharacter then
            exports.gzl_characters:saveCharacter(player)
        end
    end

    createDropObject(drop)
    outputChatBox("#38bdf8[ENVANTER] #ffffff" .. itemLabel .. " (" .. dropCount .. "x) yere bırakıldı.", player, 255, 255, 255, true)
    if exports.gzl_logs and exports.gzl_logs.logItem then
        pcall(function() exports.gzl_logs:logItem(player, "drop", itm.name, dropCount, nil, "Yere eşya bırakıldı") end)
    end
    savePlayerInventory(player)
    syncPlayerInventory(player)
    syncWorldDropsForNearby(drop.x, drop.y, drop.z, drop.dimension, drop.interior)
end)

addEventHandler("onPlayerLogin", root, function()
    loadPlayerInventory(source, true)
end)

addEventHandler("onPlayerQuit", root, function()
    savePlayerInventory(source)
    playerInventories[source] = nil
end)

addEventHandler("onElementDataChange", root, function(dataName, oldValue)
    if source and isElement(source) and getElementType(source) == "player" then
        if dataName == "character:id" or dataName == "char:id" then
            local authId = getAuthoritativeCharId(source)
            local newId = tonumber(getElementData(source, dataName))
            if authId and newId and newId ~= authId then
                setElementData(source, dataName, authId)
            end
        elseif dataName == "character:money" or dataName == "char:money" then
            if playerInventories[source] then
                local newCash = tonumber(getElementData(source, dataName)) or 0
                syncPlayerCashItem(source, newCash)
                savePlayerInventory(source)
                syncPlayerInventory(source)
            end
        end
    end
end)

addEvent("char:spawnSuccess", false)
addEventHandler("char:spawnSuccess", root, function()
    local player = source
    if isElement(player) and getElementType(player) == "player" then
        loadPlayerInventory(player, true)
    end
end)

addEventHandler("onResourceStart", resourceRoot, function()
    loadItemsDatabase()
    loadAllPlayerInventoriesFromFile()
    loadWorldDrops()
    for _, p in ipairs(getElementsByType("player")) do
        loadPlayerInventory(p, false)
    end
end)

addEventHandler("onResourceStop", resourceRoot, function()
    saveWorldDrops()
    for _, p in ipairs(getElementsByType("player")) do
        savePlayerInventory(p)
    end
    saveAllPlayerInventoriesToFile()
end)