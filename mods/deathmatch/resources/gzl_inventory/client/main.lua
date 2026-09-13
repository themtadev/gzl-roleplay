addEvent("ox_inventory:syncInventory", true)
addEvent("ox_inventory:refreshSlots", true)
addEvent("ox_inventory:nuiReady", true)
addEvent("ox_inventory:onNuiCallback", true)

local sw, sh = guiGetScreenSize()
local invBrowser = nil
local invGuiBrowser = nil
local isBrowserReady = false
local isInventoryOpen = false
local leftInventory = nil
local rightInventory = nil
local hotbarTimer = nil
local hotbarRequested = false

local isRenderingPaused = false
local restoreResumeTimer = nil
local isWindowMinimized = false

local function pauseBrowserRendering()
    if invBrowser and isElement(invBrowser) and not isRenderingPaused then
        isRenderingPaused = true
        setBrowserRenderingPaused(invBrowser, true)
    end
end

local function wakeBrowserRendering()
    if isWindowMinimized or (isMTAWindowFocused and not isMTAWindowFocused()) then return end
    if isTimer(restoreResumeTimer) then return end
    if invBrowser and isElement(invBrowser) and isRenderingPaused then
        isRenderingPaused = false
        setBrowserRenderingPaused(invBrowser, false)
    end
end

local function sendNuiMessage(action, data)
    if not isBrowserReady or not invBrowser or not isElement(invBrowser) then return end
    if isInventoryOpen then
        wakeBrowserRendering(500)
    end
    local payload = { action = action, data = data }
    local success, jsonStr = pcall(toJSON, payload, true)
    if not success or not jsonStr then return end

    if jsonStr:sub(1, 1) == "[" and jsonStr:sub(-1) == "]" then
        jsonStr = jsonStr:sub(2, -2)
    end
    executeBrowserJavascript(invBrowser, string.format("if(window.sendNuiMessage){window.sendNuiMessage(%s);}", jsonStr))
end

local function closeHotbar()
    hotbarRequested = false
    if isTimer(hotbarTimer) then killTimer(hotbarTimer) end
    hotbarTimer = nil
    sendNuiMessage("toggleHotbar", false)
    if not isInventoryOpen then
        if invGuiBrowser and isElement(invGuiBrowser) then guiSetVisible(invGuiBrowser, false) end

        if isBrowserReady then pauseBrowserRendering() end
    end
end

local function showPendingHotbar()
    if not hotbarRequested or isInventoryOpen or not isBrowserReady or not leftInventory then return end
    if isTimer(hotbarTimer) then return end
    wakeBrowserRendering()
    sendNuiMessage("setupInventory", { leftInventory = leftInventory, rightInventory = rightInventory })
    sendNuiMessage("toggleHotbar", true)
    guiSetVisible(invGuiBrowser, true)
    guiBringToFront(invGuiBrowser)

    hotbarTimer = setTimer(closeHotbar, 3000, 1)
end

local function onInventoryUIReady()
    if isBrowserReady then return end
    isBrowserReady = true
    sendNuiMessage("init", {
        locale = { ui_use = "Kullan", ui_give = "Ver", ui_close = "Kapat", ui_drop = "Dünya", ui_usefulcontrols = "Kullanışlı Tuşlar" },
        items = ItemsList or {}, leftInventory = leftInventory, imagepath = "images"
    })
    if isInventoryOpen then
        wakeBrowserRendering()
        guiSetVisible(invGuiBrowser, true)
        guiBringToFront(invGuiBrowser)
        focusBrowser(invBrowser)
        if leftInventory then
            sendNuiMessage("setupInventory", { leftInventory = leftInventory, rightInventory = rightInventory })
            sendNuiMessage("setInventoryVisible", true)
        end
    elseif hotbarRequested then
        showPendingHotbar()
    else
        guiSetVisible(invGuiBrowser, false)
        pauseBrowserRendering()
    end
end

local function sameValue(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for key, value in pairs(a) do
        if not sameValue(value, b[key]) then return false end
    end
    for key in pairs(b) do
        if a[key] == nil then return false end
    end
    return true
end

local function getInventorySlotDeltas(oldInv, newInv, invType)
    if not oldInv or not newInv or oldInv.id ~= newInv.id
        or oldInv.type ~= newInv.type or oldInv.slots ~= newInv.slots
        or oldInv.maxWeight ~= newInv.maxWeight or oldInv.label ~= newInv.label
        or not sameValue(oldInv.groups, newInv.groups) then return nil end
    local deltas = {}
    local maxSlots = math.max(oldInv.slots or 40, newInv.slots or 40)
    local diffCount = 0

    local oldItems = oldInv.items or {}
    local newItems = newInv.items or {}

    for slot = 1, maxSlots do
        local oldItem = oldItems[slot] or oldItems[tostring(slot)]
        local newItem = newItems[slot] or newItems[tostring(slot)]
        local changed = not sameValue(oldItem, newItem)

        if changed then
            diffCount = diffCount + 1
            if newItem then
                table.insert(deltas, {
                    inventory = invType,
                    item = newItem
                })
            else
                table.insert(deltas, {
                    inventory = invType,
                    item = { slot = slot }
                })
            end
        end
    end

    return deltas, diffCount
end

local function initInventoryBrowser()
    if invGuiBrowser and isElement(invGuiBrowser) then return end

    invGuiBrowser = guiCreateBrowser(0, 0, sw, sh, true, true, false)
    if not invGuiBrowser then return end
    isBrowserReady = false
    isRenderingPaused = false

    guiSetVisible(invGuiBrowser, false)
    pcall(guiSetInputMode, "allow_binds")

    invBrowser = guiGetBrowser(invGuiBrowser)
    if invBrowser and isElement(invBrowser) then
        addEventHandler("onClientBrowserCreated", invBrowser, function()

            loadBrowserURL(source, "http://mta/local/web/build/index.html")
        end)

    end
end

local function isPlayerInGame()
    return (getElementData(localPlayer, "character:id") or getElementData(localPlayer, "char:id") or getElementData(localPlayer, "loggedin_character")) and not isMainMenuActive()
end

local function isUIProgressBarActive()
    local ok, active = pcall(function()
        return exports.gzl_ui and exports.gzl_ui:isProgressBarActive()
    end)
    return ok and active == true
end

local function showUINotification(nType, msg)
    pcall(function()
        if exports.gzl_ui and exports.gzl_ui.showNotification then
            exports.gzl_ui:showNotification(nType, msg)
        end
    end)
end

local function showUIToast(msg, toastType, duration)
    pcall(function()
        if exports.gzl_ui and exports.gzl_ui.showToast then
            exports.gzl_ui:showToast(msg, toastType, duration)
        end
    end)
end

local function startUIProgressBar(options)
    local ok, res = pcall(function()
        return exports.gzl_ui and exports.gzl_ui:startProgressBar(options)
    end)
    return ok and res == true
end

local isListenersAttached = false

local function onInventoryKey(button, press)
    if isInventoryOpen then
        wakeBrowserRendering()

        if press and button == "escape" then
            cancelEvent()
            toggleInventory(false)
        end
    end
end

local function attachInventoryListeners()
    if isListenersAttached then return end
    isListenersAttached = true
    addEventHandler("onClientKey", root, onInventoryKey)
end

local function detachInventoryListeners()
    if not isListenersAttached then return end
    isListenersAttached = false
    removeEventHandler("onClientKey", root, onInventoryKey)
end

function toggleInventory(state)
    local willOpen = (state == nil and not isInventoryOpen) or (state == true)
    if willOpen and isUIProgressBarActive() then
        showUINotification("error", "Şu anda envanterinizi açamazsınız")
        return
    end

    if not isPlayerInGame() then
        closeHotbar()
        if isInventoryOpen then
            isInventoryOpen = false
            setElementData(localPlayer, "ox_inventory:isOpen", false, false)
            showCursor(false)
            detachInventoryListeners()
            if invGuiBrowser and isElement(invGuiBrowser) then guiSetVisible(invGuiBrowser, false) end
            if invBrowser and isElement(invBrowser) then
                if isBrowserReady then pauseBrowserRendering() end
                focusBrowser(nil)
            end
        end
        return
    end

    if state == nil then
        isInventoryOpen = not isInventoryOpen
    else
        isInventoryOpen = state
    end

    if not invGuiBrowser or not isElement(invGuiBrowser) then
        initInventoryBrowser()
    end

    closeHotbar()

    if isInventoryOpen then
        setElementData(localPlayer, "ox_inventory:isOpen", true, false)
        if invGuiBrowser and isElement(invGuiBrowser) then
            guiSetVisible(invGuiBrowser, true)
            guiBringToFront(invGuiBrowser)
        end
        if invBrowser and isElement(invBrowser) then
            wakeBrowserRendering()
            focusBrowser(invBrowser)
        end
        showCursor(true)

        attachInventoryListeners()

        triggerServerEvent("ox_inventory:requestInventory", resourceRoot)

        if leftInventory then
            sendNuiMessage("setupInventory", {
                leftInventory = leftInventory,
                rightInventory = rightInventory
            })
            sendNuiMessage("setInventoryVisible", true)
        end
    else
        setElementData(localPlayer, "ox_inventory:isOpen", false, false)
        setElementData(localPlayer, "ox_inventory:lastClosedTick", getTickCount(), false)
        showCursor(false)
        pcall(guiSetInputMode, "allow_binds")

        detachInventoryListeners()

        sendNuiMessage("closeInventory", {})
        sendNuiMessage("setInventoryVisible", false)

        if invGuiBrowser and isElement(invGuiBrowser) then
            guiSetVisible(invGuiBrowser, false)
        end
        if invBrowser and isElement(invBrowser) then
            if isBrowserReady then pauseBrowserRendering() end
            focusBrowser(nil)
        end
    end
end

function isInventoryOpenState()
    return isInventoryOpen == true
end
isInventoryOpenFunc = isInventoryOpenState

function toggleHotbarDisplay()
    if not isPlayerInGame() or isInventoryOpen then return end
    if hotbarRequested then closeHotbar() return end
    hotbarRequested = true
    initInventoryBrowser()

    triggerServerEvent("ox_inventory:requestInventory", resourceRoot)
    showPendingHotbar()
end

addEventHandler("ox_inventory:syncInventory", root, function(leftData, rightData)
    if not isPlayerInGame() or type(leftData) ~= "table" then return end
    local oldLeft = leftInventory
    local oldRight = rightInventory

    leftInventory = leftData
    rightInventory = rightData

    if not isBrowserReady then return end
    if hotbarRequested and not isTimer(hotbarTimer) then
        showPendingHotbar()
        return
    end

    if not isInventoryOpen and not isTimer(hotbarTimer) then return end
    if isInventoryOpen then sendNuiMessage("setInventoryVisible", true) end

    local canDelta = false
    local changedItems = {}

    if oldLeft and leftData and oldLeft.id == leftData.id and oldRight and rightData and oldRight.id == rightData.id then
        local leftDeltas, leftDiffCount = getInventorySlotDeltas(oldLeft, leftData, "player")
        local rightDeltas, rightDiffCount = getInventorySlotDeltas(oldRight, rightData, rightData.type or "drop")

        if leftDeltas and rightDeltas then
            local totalDiff = leftDiffCount + rightDiffCount
            if totalDiff == 0 then
                if leftData.weight ~= oldLeft.weight then
                    sendNuiMessage("refreshSlots", {
                        items = {},
                        weightData = { inventoryId = leftData.id, maxWeight = leftData.maxWeight }
                    })
                end
                return
            elseif totalDiff <= 12 then
                canDelta = true
                for _, d in ipairs(leftDeltas) do table.insert(changedItems, d) end
                for _, d in ipairs(rightDeltas) do table.insert(changedItems, d) end
            end
        end
    end

    if canDelta and #changedItems > 0 then
        sendNuiMessage("refreshSlots", {
            items = changedItems,
            weightData = { inventoryId = leftData.id, maxWeight = leftData.maxWeight }
        })
    else
        sendNuiMessage("setupInventory", {
            leftInventory = leftData,
            rightInventory = rightData
        })
    end
end)

addEventHandler("ox_inventory:refreshSlots", root, function(payload)
    if type(payload) ~= "table" or not isPlayerInGame() then return end

    local updates = payload.items
    if type(updates) == "table" then
        if updates.item then updates = { updates } end
        for _, update in pairs(updates) do
            if type(update) == "table" and type(update.item) == "table" then
                local target = (not update.inventory or update.inventory == "player") and leftInventory or rightInventory
                local slot = tonumber(update.item.slot)
                if target and slot and slot >= 1 and slot <= (target.slots or 40) then
                    target.items = target.items or {}
                    target.items[tostring(slot)] = nil
                    target.items[slot] = update.item.name and update.item or nil
                end
            end
        end
    end
    for _, field in ipairs({ "weightData", "slotsData" }) do
        local data = payload[field]
        if type(data) == "table" then
            local target = leftInventory and data.inventoryId == leftInventory.id and leftInventory
                or rightInventory and data.inventoryId == rightInventory.id and rightInventory
            if target then
                if field == "weightData" then target.maxWeight = data.maxWeight
                else target.slots = data.slots end
            end
        end
    end
    if isInventoryOpen or isTimer(hotbarTimer) then sendNuiMessage("refreshSlots", payload) end
end)

local UI_ITEM_HANDLERS = {
    ["phone"] = {
        isOpen = function()
            if exports.gzl_phone and exports.gzl_phone.isPhoneOpenState then
                return exports.gzl_phone:isPhoneOpenState()
            elseif exports.high_phone and exports.high_phone.isPhoneOpenState then
                return exports.high_phone:isPhoneOpenState()
            end
            return false
        end,
        toggle = function(forceState)
            if exports.gzl_phone and exports.gzl_phone.togglePhone then
                exports.gzl_phone:togglePhone(forceState)
                return true
            elseif exports.high_phone and exports.high_phone.togglePhone then
                exports.high_phone:togglePhone(forceState)
                return true
            end
            return false
        end,
        close = function()
            if exports.gzl_phone and exports.gzl_phone.togglePhone then
                exports.gzl_phone:togglePhone(false)
                return true
            elseif exports.high_phone and exports.high_phone.togglePhone then
                exports.high_phone:togglePhone(false)
                return true
            end
            return false
        end
    },
    ["radio"] = {
        isOpen = function()
            return exports.gzl_radio and exports.gzl_radio.isRadioOpen and exports.gzl_radio:isRadioOpen()
        end,
        toggle = function(forceState)
            if exports.gzl_radio and exports.gzl_radio.toggleRadio then
                exports.gzl_radio:toggleRadio(forceState)
                return true
            end
            return false
        end,
        close = function()
            if exports.gzl_radio and exports.gzl_radio.toggleRadio then
                exports.gzl_radio:toggleRadio(false)
                return true
            end
            return false
        end
    }
}
UI_ITEM_HANDLERS["classic_phone"] = UI_ITEM_HANDLERS["phone"]
UI_ITEM_HANDLERS["smartphone"] = UI_ITEM_HANDLERS["phone"]
UI_ITEM_HANDLERS["iphone"] = UI_ITEM_HANDLERS["phone"]
UI_ITEM_HANDLERS["black_phone"] = UI_ITEM_HANDLERS["phone"]
UI_ITEM_HANDLERS["blue_phone"] = UI_ITEM_HANDLERS["phone"]
UI_ITEM_HANDLERS["gold_phone"] = UI_ITEM_HANDLERS["phone"]
UI_ITEM_HANDLERS["green_phone"] = UI_ITEM_HANDLERS["phone"]

UI_ITEM_HANDLERS["highradio"] = UI_ITEM_HANDLERS["radio"]
UI_ITEM_HANDLERS["lowradio"] = UI_ITEM_HANDLERS["radio"]
UI_ITEM_HANDLERS["radioscanner"] = UI_ITEM_HANDLERS["radio"]

local function getInventoryItemInSlot(slot)
    if not leftInventory or not leftInventory.items then return nil end
    local numSlot = tonumber(slot)
    if not numSlot then return nil end
    if leftInventory.items[numSlot] then
        return leftInventory.items[numSlot]
    end
    if leftInventory.items[tostring(numSlot)] then
        return leftInventory.items[tostring(numSlot)]
    end
    for _, itm in pairs(leftInventory.items) do
        if itm and tonumber(itm.slot) == numSlot then
            return itm
        end
    end
    return nil
end

local function handleUIItemSlotPress(slot)
    local itm = getInventoryItemInSlot(slot)
    if not itm or not itm.name then return false end
    local handler = UI_ITEM_HANDLERS[itm.name:lower()]
    if not handler then return false end

    if handler.isOpen and handler.isOpen() then
        if handler.close then
            handler.close()
        elseif handler.toggle then
            handler.toggle(false)
        end
        return true
    else
        for otherName, otherH in pairs(UI_ITEM_HANDLERS) do
            if otherH ~= handler and type(otherH) == "table" and otherH.isOpen and otherH.isOpen() then
                if otherH.close then
                    otherH.close()
                elseif otherH.toggle then
                    otherH.toggle(false)
                end
            end
        end
        if handler.toggle then
            handler.toggle(true)
        end
        return true
    end
end

local ITEM_ACTIONS = {
    ["bandage"] = {
        label = "Bandaj",
        text = "Bandaj kullanılıyor...",
        duration = 2500,
        animation = { block = "GANGS", anim = "smk_loop" },
        freeze = false
    },
    ["medikit"] = {
        label = "İlk Yardım Kiti",
        text = "İlk yardım kiti uygulanıyor...",
        duration = 4000,
        animation = { block = "GANGS", anim = "smk_loop" },
        freeze = true
    },
    ["firstaid"] = {
        label = "İlk Yardım Çantası",
        text = "İlk yardım uygulanıyor...",
        duration = 3500,
        animation = { block = "GANGS", anim = "smk_loop" },
        freeze = true
    },
    ["armour"] = {
        label = "Çelik Yelek",
        text = "Çelik yelek giyiliyor...",
        duration = 3500,
        animation = { block = "CLOTHES", anim = "CLO_Buy" },
        freeze = false
    },
    ["bodyarmour"] = {
        label = "Çelik Yelek",
        text = "Çelik yelek giyiliyor...",
        duration = 3500,
        animation = { block = "CLOTHES", anim = "CLO_Buy" },
        freeze = false
    },
    ["heavyarmour"] = {
        label = "Ağır Zırh",
        text = "Ağır çelik yelek giyiliyor...",
        duration = 4500,
        animation = { block = "CLOTHES", anim = "CLO_Buy" },
        freeze = false
    },
    ["repairkit"] = {
        label = "Tamir Kiti",
        text = "Araç tamir ediliyor...",
        duration = 5000,
        animation = { block = "CAR", anim = "Fixn_Car_Loop" },
        freeze = true,
        condition = function()
            local veh = getPedOccupiedVehicle(localPlayer)
            if not veh then
                local px, py, pz = getElementPosition(localPlayer)
                for _, v in ipairs(getElementsByType("vehicle")) do
                    local vx, vy, vz = getElementPosition(v)
                    if getDistanceBetweenPoints3D(px, py, pz, vx, vy, vz) <= 4.0 then
                        veh = v
                        break
                    end
                end
            end
            if not veh then
                if exports.gzl_ui and exports.gzl_ui.showNotification then
                    exports.gzl_ui:showNotification("error", "Yakında tamir edilecek araç bulunamadı!")
                end
                return false
            end
            return true
        end
    },
    ["lockpick"] = {
        label = "Maymuncuk",
        text = "Kilit kurcalanıyor...",
        duration = 3500,
        animation = { block = "BOMBER", anim = "BOM_Plant" },
        freeze = true,
        condition = function()
            local px, py, pz = getElementPosition(localPlayer)
            local found = false
            for _, v in ipairs(getElementsByType("vehicle")) do
                local vx, vy, vz = getElementPosition(v)
                if getDistanceBetweenPoints3D(px, py, pz, vx, vy, vz) <= 4.0 then
                    found = true
                    break
                end
            end
            if not found then
                if exports.gzl_ui and exports.gzl_ui.showNotification then
                    exports.gzl_ui:showNotification("error", "Yakında kilitlenecek/açılacak araç yok!")
                end
                return false
            end
            return true
        end
    },
    ["cigaret"] = {
        label = "Sigara",
        text = "Sigara yakılıyor...",
        duration = 3000,
        animation = { block = "SMOKING", anim = "M_smkstnd_loop" },
        freeze = false
    },
    ["cigarette"] = {
        label = "Sigara",
        text = "Sigara yakılıyor...",
        duration = 3000,
        animation = { block = "SMOKING", anim = "M_smkstnd_loop" },
        freeze = false
    },
    ["water"] = {
        label = "Su",
        text = "Su içiliyor...",
        duration = 2000,
        animation = { block = "VENDING", anim = "vend_drink2_p" },
        freeze = false
    },
    ["cola"] = {
        label = "Kola",
        text = "Kola içiliyor...",
        duration = 2000,
        animation = { block = "VENDING", anim = "vend_drink2_p" },
        freeze = false
    },
    ["coffee"] = {
        label = "Kahve",
        text = "Kahve içiliyor...",
        duration = 2000,
        animation = { block = "VENDING", anim = "vend_drink2_p" },
        freeze = false
    },
    ["sprunk"] = {
        label = "Sprunk",
        text = "Sprunk içiliyor...",
        duration = 2000,
        animation = { block = "VENDING", anim = "vend_drink2_p" },
        freeze = false
    },
    ["sprite"] = {
        label = "Sprite",
        text = "Sprite içiliyor...",
        duration = 2000,
        animation = { block = "VENDING", anim = "vend_drink2_p" },
        freeze = false
    },
    ["orange_juice"] = {
        label = "Portakal Suyu",
        text = "Portakal suyu içiliyor...",
        duration = 2000,
        animation = { block = "VENDING", anim = "vend_drink2_p" },
        freeze = false
    },
    ["milkshake"] = {
        label = "Milkshake",
        text = "Milkshake içiliyor...",
        duration = 2000,
        animation = { block = "VENDING", anim = "vend_drink2_p" },
        freeze = false
    },
    ["icetea"] = {
        label = "Soğuk Çay",
        text = "Soğuk çay içiliyor...",
        duration = 2000,
        animation = { block = "VENDING", anim = "vend_drink2_p" },
        freeze = false
    },
    ["energy_drink"] = {
        label = "Enerji İçeceği",
        text = "Enerji içeceği içiliyor...",
        duration = 2000,
        animation = { block = "VENDING", anim = "vend_drink2_p" },
        freeze = false
    },
    ["coconut_drink"] = {
        label = "Hindistan Cevizi İçeceği",
        text = "Hindistan cevizi içeceği içiliyor...",
        duration = 2000,
        animation = { block = "VENDING", anim = "vend_drink2_p" },
        freeze = false
    },
    ["lemonade"] = {
        label = "Limonata",
        text = "Limonata içiliyor...",
        duration = 2000,
        animation = { block = "VENDING", anim = "vend_drink2_p" },
        freeze = false
    },
    ["beer"] = {
        label = "Bira",
        text = "Bira içiliyor...",
        duration = 2500,
        animation = { block = "VENDING", anim = "vend_drink2_p" },
        freeze = false
    },
    ["wine"] = {
        label = "Şarap",
        text = "Şarap içiliyor...",
        duration = 2500,
        animation = { block = "VENDING", anim = "vend_drink2_p" },
        freeze = false
    },
    ["burger"] = {
        label = "Hamburger",
        text = "Hamburger yeniyor...",
        duration = 2500,
        animation = { block = "FOOD", anim = "EAT_Burger" },
        freeze = false
    },
    ["hamburger"] = {
        label = "Hamburger",
        text = "Hamburger yeniyor...",
        duration = 2500,
        animation = { block = "FOOD", anim = "EAT_Burger" },
        freeze = false
    },
    ["sandwich"] = {
        label = "Sandviç",
        text = "Sandviç yeniyor...",
        duration = 2500,
        animation = { block = "FOOD", anim = "EAT_Burger" },
        freeze = false
    },
    ["bread"] = {
        label = "Ekmek",
        text = "Ekmek yeniyor...",
        duration = 2000,
        animation = { block = "FOOD", anim = "EAT_Burger" },
        freeze = false
    },
    ["taco"] = {
        label = "Taco",
        text = "Taco yeniyor...",
        duration = 2500,
        animation = { block = "FOOD", anim = "EAT_Burger" },
        freeze = false
    },
    ["fries"] = {
        label = "Patates Kızartması",
        text = "Patates kızartması yeniyor...",
        duration = 2000,
        animation = { block = "FOOD", anim = "EAT_Burger" },
        freeze = false
    },
    ["chocolate"] = {
        label = "Çikolata",
        text = "Çikolata yeniyor...",
        duration = 2000,
        animation = { block = "FOOD", anim = "EAT_Burger" },
        freeze = false
    },
    ["donut"] = {
        label = "Donut",
        text = "Donut yeniyor...",
        duration = 2000,
        animation = { block = "FOOD", anim = "EAT_Burger" },
        freeze = false
    },
    ["pizza"] = {
        label = "Pizza",
        text = "Pizza yeniyor...",
        duration = 2500,
        animation = { block = "FOOD", anim = "EAT_Burger" },
        freeze = false
    },
    ["apple"] = {
        label = "Elma",
        text = "Elma yeniyor...",
        duration = 2000,
        animation = { block = "FOOD", anim = "EAT_Burger" },
        freeze = false
    },
    ["chips"] = {
        label = "Cips",
        text = "Cips yeniyor...",
        duration = 2000,
        animation = { block = "FOOD", anim = "EAT_Burger" },
        freeze = false
    }
}

local activeItemUseTimer = nil
local pendingUseItem = nil

local function clearActiveItemUse()
    if isTimer(activeItemUseTimer) then
        killTimer(activeItemUseTimer)
        activeItemUseTimer = nil
    end
    pendingUseItem = nil
end

addEvent("progressbar:onCancel", true)
addEventHandler("progressbar:onCancel", localPlayer, function(reason)
    clearActiveItemUse()
    if reason == "user_cancel" then
        showUIToast("Eylem iptal edildi.", "warning", 2000)
    end
end)

addEvent("progressbar:onFinish", true)
addEventHandler("progressbar:onFinish", localPlayer, function()
    if pendingUseItem then
        local targetSlot = pendingUseItem.slot
        local targetCount = pendingUseItem.count
        clearActiveItemUse()
        triggerServerEvent("ox_inventory:useItem", localPlayer, targetSlot, targetCount)
    end
end)

addEventHandler("onClientPlayerWasted", localPlayer, function()
    clearActiveItemUse()
    toggleInventory(false)
    closeHotbar()
end)

local function performUseItem(slot, count)
    slot = tonumber(slot)
    if not slot then return end
    count = tonumber(count) or 1

    if isUIProgressBarActive() then
        showUINotification("error", "Şu anda başka bir eylem yapıyorsunuz!")
        return
    end

    if handleUIItemSlotPress(slot) then
        toggleInventory(false)
        return
    end

    local itm = getInventoryItemInSlot(slot)
    if not itm or not itm.name then
        triggerServerEvent("ox_inventory:useItem", localPlayer, slot, count)
        return
    end
    local itemName = itm.name:lower()

    local cfg = ITEM_ACTIONS[itemName]
    if not cfg and ItemsList and ItemsList[itemName] and ItemsList[itemName].client and ItemsList[itemName].client.usetime then
        local def = ItemsList[itemName]
        cfg = {
            label = def.label or itemName,
            text = (def.label or itm.label or itemName) .. " kullanılıyor...",
            duration = tonumber(def.client.usetime) or 2500,
            freeze = false
        }
    end

    if cfg then
        if cfg.condition and type(cfg.condition) == "function" then
            if not cfg.condition() then
                return
            end
        end

        toggleInventory(false)
        clearActiveItemUse()

        local duration = cfg.duration or 2500
        local started = startUIProgressBar({
            text = cfg.text or ((itm.label or cfg.label or itemName) .. " kullanılıyor..."),
            duration = duration,
            freeze = cfg.freeze == true,
            animation = cfg.animation,
            canCancel = true
        })
        if not started then
            showUINotification("error", "Eşya kullanım işlemi başlatılamadı.")
            return
        end

        pendingUseItem = { slot = slot, count = count }
        activeItemUseTimer = setTimer(function(targetSlot, targetCount)
            activeItemUseTimer = nil
            if pendingUseItem then
                pendingUseItem = nil
                triggerServerEvent("ox_inventory:useItem", localPlayer, targetSlot, targetCount)
            end
        end, duration, 1, slot, count)

        return
    end

    triggerServerEvent("ox_inventory:useItem", localPlayer, slot, count)
end

addEventHandler("ox_inventory:onNuiCallback", root, function(eventName, payloadJson)
    if isInventoryOpen or isTimer(hotbarTimer) then wakeBrowserRendering() end
    local data = nil
    if type(payloadJson) == "string" then
        local success, parsed = pcall(fromJSON, payloadJson)
        if success and parsed ~= nil then
            data = parsed
        else
            data = tonumber(payloadJson) or payloadJson
        end
    else
        data = payloadJson
    end

    if eventName == "uiLoaded" then
        onInventoryUIReady()
    elseif eventName == "closeInventory" or eventName == "exit" then
        toggleInventory(false)
    elseif eventName == "useItem" then
        local slot = nil
        local count = 1
        if type(data) == "number" then
            slot = data
        elseif type(data) == "table" then
            slot = data.slot or (data.item and data.item.slot) or data[1]
            count = tonumber(data.count) or 1
        elseif type(data) == "string" then
            slot = tonumber(data)
        end
        if not slot and tonumber(payloadJson) then
            slot = tonumber(payloadJson)
        end
        if slot then
            performUseItem(slot, count)
        end
    elseif eventName == "giveItem" then
        local slot = nil
        local count = 1
        if type(data) == "table" then
            slot = data.slot or (data.item and data.item.slot) or (type(data.fromSlot) == "table" and data.fromSlot.slot) or data.fromSlot
            count = tonumber(data.count) or 1
        elseif type(data) == "number" then
            slot = data
        end
        if not slot and tonumber(payloadJson) then
            slot = tonumber(payloadJson)
        end
        if slot then
            triggerServerEvent("ox_inventory:giveItem", localPlayer, slot, count)
        end
    elseif eventName == "swapItems" then
        if type(data) == "table" then
            local fromSlot = type(data.fromSlot) == "table" and data.fromSlot.slot or data.fromSlot or data.from
            local toSlot = type(data.toSlot) == "table" and data.toSlot.slot or data.toSlot or data.to
            local fromType = data.fromType or (data.fromInventory and data.fromInventory.type) or "player"
            local toType = data.toType or (data.toInventory and data.toInventory.type) or "player"
            local count = tonumber(data.count) or 0

            if fromSlot and toSlot then
                triggerServerEvent("ox_inventory:swapItems", localPlayer, fromSlot, toSlot, fromType, toType, count)
            end
        end
    elseif eventName == "dropItem" then
        local slot = nil
        local count = 1
        if type(data) == "table" then
            slot = data.slot or (data.item and data.item.slot) or (type(data.fromSlot) == "table" and data.fromSlot.slot) or data.fromSlot
            count = tonumber(data.count) or 1
        elseif type(data) == "number" then
            slot = data
        end
        if not slot and tonumber(payloadJson) then
            slot = tonumber(payloadJson)
        end
        if slot then
            triggerServerEvent("ox_inventory:dropItem", localPlayer, slot, count)
        end
    end
end)


local function isResRunning(name)
    local res = getResourceFromName(name)
    return res and getResourceState(res) == "running"
end

local function isAnyInputActive()
    if isChatBoxInputActive and isChatBoxInputActive() then return true end
    if isConsoleActive and isConsoleActive() then return true end
    if isCursorShowing and isCursorShowing() then return true end
    if guiGetInputEnabled and guiGetInputEnabled() then return true end
    if isResRunning("gzl_core") and exports.gzl_core.isPlayerTyping and exports.gzl_core:isPlayerTyping() then return true end
    if isResRunning("gzl_ui") and exports.gzl_ui.getActiveEditBox and exports.gzl_ui:getActiveEditBox() then return true end
    if isResRunning("gzl_chat") and exports.gzl_chat.isChatInputOpen and exports.gzl_chat:isChatInputOpen() then return true end
    if isResRunning("gzl_atm") and exports.gzl_atm.isATMOpen and exports.gzl_atm:isATMOpen() then return true end
    if isResRunning("gzl_phone") and exports.gzl_phone.isPhoneOpenState and exports.gzl_phone:isPhoneOpenState() then
        if exports.gzl_phone.isKeypadTypingActive and exports.gzl_phone:isKeypadTypingActive() then return true end
    end
    if isResRunning("high_phone") and exports.high_phone.getActiveEditBox and exports.high_phone:getActiveEditBox() then return true end
    if isResRunning("high_phone") and exports.high_phone.isKeypadTypingActive and exports.high_phone:isKeypadTypingActive() then return true end
    if isResRunning("cylex_phone") and exports.cylex_phone.isPhoneOpenState and exports.cylex_phone:isPhoneOpenState() then return true end
    if isResRunning("gzl_pd") and exports.gzl_pd.isPDTabletOpen and exports.gzl_pd:isPDTabletOpen() then return true end
    return false
end

bindKey("f2", "down", function()
    if isPlayerInGame() and (isInventoryOpen or not isAnyInputActive()) then
        if not isInventoryOpen and isUIProgressBarActive() then
            showUINotification("error", "Şu anda envanterinizi açamazsınız")
            return
        end
        toggleInventory()
    end
end)

bindKey("i", "down", function()
    if isPlayerInGame() and (isInventoryOpen or not isAnyInputActive()) then
        if isUIProgressBarActive() then
            showUINotification("error", "Şu anda envanterinizi açamazsınız")
            return
        end
        toggleInventory()
    end
end)

bindKey("tab", "down", function()
    if isPlayerInGame() and not isAnyInputActive() then
        if not isInventoryOpen then
            toggleHotbarDisplay()
        end
    end
end)

for i = 1, 5 do
    bindKey(tostring(i), "down", function()
        if isPlayerInGame() and not isInventoryOpen and not isAnyInputActive() then
            performUseItem(i, 1)
        end
    end)
end

local function resetInventorySession()
    toggleInventory(false)
    closeHotbar()
    clearActiveItemUse()
    leftInventory, rightInventory = nil, nil
end

addEvent("auth:showLoginScreen", true)
addEventHandler("auth:showLoginScreen", root, resetInventorySession)

addEvent("char:receiveList", true)
addEventHandler("char:receiveList", root, resetInventorySession)

addEventHandler("onClientElementDataChange", localPlayer, function(dataName)
    if dataName == "character:id" or dataName == "char:id" or dataName == "loggedin_character" then
        resetInventorySession()
        if isPlayerInGame() then
            triggerServerEvent("ox_inventory:requestInventory", resourceRoot)
        end
    end
end)

addEventHandler("onClientResourceStart", resourceRoot, function()
    initInventoryBrowser()
    if isPlayerInGame() then
        triggerServerEvent("ox_inventory:requestInventory", resourceRoot)
    end
end)

addEventHandler("onClientMinimize", root, function()
    isWindowMinimized = true
    if isTimer(restoreResumeTimer) then
        killTimer(restoreResumeTimer)
        restoreResumeTimer = nil
    end
    if invBrowser and isElement(invBrowser) then
        isRenderingPaused = true
        setBrowserRenderingPaused(invBrowser, true)
    end
end)

addEventHandler("onClientRestore", root, function()
    sw, sh = guiGetScreenSize()
    isWindowMinimized = false
    if isTimer(restoreResumeTimer) then
        killTimer(restoreResumeTimer)
        restoreResumeTimer = nil
    end
    restoreResumeTimer = setTimer(function()
        restoreResumeTimer = nil
        if isWindowMinimized then return end
        if isInventoryOpen and invBrowser and isElement(invBrowser) then
            isRenderingPaused = false
            setBrowserRenderingPaused(invBrowser, false)
        end
    end, 500, 1)
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    hotbarRequested = false
    clearActiveItemUse()
    setElementData(localPlayer, "ox_inventory:isOpen", false, false)
    if isTimer(hotbarTimer) then
        killTimer(hotbarTimer)
        hotbarTimer = nil
    end
    if isTimer(restoreResumeTimer) then
        killTimer(restoreResumeTimer)
        restoreResumeTimer = nil
    end
    detachInventoryListeners()
    if isInventoryOpen then
        isInventoryOpen = false
        showCursor(false)
        focusBrowser(nil)
    end
    if invGuiBrowser and isElement(invGuiBrowser) then
        destroyElement(invGuiBrowser)
        invGuiBrowser = nil
        invBrowser = nil
    end
end)