
local InstalledText = "Takıldı"
local purchasedText = "Satın Alındı"
local noMoney = "Yeterli Para Yok"

local currentMenuItemID = 0
local currentMenuItem = ""
local currentMenuItem2 = ""
local currentMenu = "mainMenu"

local currentCategory = 0

local currentBoyaCategory = 0
local currentBoyaType = 0

local currentWheelCategory = 0

local currentNeonSide = 0

local menuStructure = {}

local function roundNum(num, numDecimalPlaces)
    return tonumber(string.format("%." .. (numDecimalPlaces or 0) .. "f", num))
end

local function toggleMenuContainer(state)
    SendNUIMessage({
        toggleMenuContainer = true,
        state = state
    })
end

local function createMenu(menu, heading, subheading)
    SendNUIMessage({
        createMenu = true,
        menu = menu,
        heading = heading,
        subheading = subheading
    })
end

local function destroyMenus()
    SendNUIMessage({
        destroyMenus = true
    })
end

local function populateMenu(menu, id, item, item2)
    SendNUIMessage({
        populateMenu = true,
        menu = menu,
        id = id,
        item = item,
        item2 = item2
    })
end

local function finishPopulatingMenu(menu)
    SendNUIMessage({
        finishPopulatingMenu = true,
        menu = menu
    })
end

local function updateMenuHeading(menu)
    SendNUIMessage({
        updateMenuHeading = true,
        menu = menu
    })
end

local function updateMenuSubheading(menu)
    SendNUIMessage({
        updateMenuSubheading = true,
        menu = menu
    })
end

local function updateMenuStatus(text)
    SendNUIMessage({
        updateMenuStatus = true,
        statusText = text
    })
end

local function toggleMenu(state, menu)
    SendNUIMessage({
        toggleMenu = true,
        state = state,
        menu = menu
    })
end

local function updateItem2Text(menu, id, text)
    SendNUIMessage({
        updateItem2Text = true,
        menu = menu,
        id = id,
        item2 = text
    })
end

local function updateItem2TextOnly(menu, id, text)
    SendNUIMessage({
        updateItem2TextOnly = true,
        menu = menu,
        id = id,
        item2 = text
    })
end

local function scrollMenuFunctionality(direction, menu)
    SendNUIMessage({
        scrollMenuFunctionality = true,
        direction = direction,
        menu = menu
    })
end

local function playSoundEffect(soundEffect, volume)
    SendNUIMessage({
        playSoundEffect = true,
        soundEffect = soundEffect,
        volume = volume
    })
end

local function isMenuActive(menu)
    local menuActive = false
    if menu == "modMenu" then
        for k, v in pairs(vehicleCustomisation) do
            if (v.category:gsub("%s+", "") .. "Menu") == currentMenu then
                menuActive = true

                break
            else
                menuActive = false
            end
        end
    elseif menu == "BoyaMenu" then
        for k, v in pairs(vehicleBoyaOptions) do
            if (v.category:gsub("%s+", "") .. "Menu") == currentMenu then
                menuActive = true

                break
            else
                menuActive = false
            end
        end
    elseif menu == "JantlarMenu" then
        for k, v in pairs(vehicleWheelOptions) do
            if (v.category:gsub("%s+", "") .. "Menu") == currentMenu then
                menuActive = true

                break
            else
                menuActive = false
            end
        end
    elseif menu == "NeonlarSideMenu" then
        for k, v in pairs(vehicleNeonOptions.neonTypes) do
            if (v.name:gsub("%s+", "") .. "Menu") == currentMenu then
                menuActive = true

                break
            else
                menuActive = false
            end
        end
    end

    return menuActive
end

local function updateCurrentMenuItemID(id, item, item2)
    currentMenuItemID = id
    currentMenuItem = item
    currentMenuItem2 = item2
    if isMenuActive("modMenu") then
        if currentCategory ~= 18 then
            PreviewMod(currentCategory, currentMenuItemID)
        end
    elseif isMenuActive("BoyaMenu") then
        PreviewColour(currentBoyaCategory, currentBoyaType, currentMenuItemID)
    elseif isMenuActive("JantlarMenu") then
        if currentWheelCategory ~= -1 and currentWheelCategory ~= 20 then
            PreviewWheel(currentCategory, currentMenuItemID, currentWheelCategory)
        end
    elseif isMenuActive("NeonlarSideMenu") then
        PreviewNeon(currentNeonSide, currentMenuItemID)
    elseif currentMenu == "CamFilmiMenu" then
        PreviewWindowTint(currentMenuItemID)
    elseif currentMenu == "NeonRengiMenu" then
        local r = vehicleNeonOptions.neonColours[currentMenuItemID].r
        local g = vehicleNeonOptions.neonColours[currentMenuItemID].g
        local b = vehicleNeonOptions.neonColours[currentMenuItemID].b

        PreviewNeonColour(r, g, b)
    elseif currentMenu == "XenonRengiMenu" then
        PreviewXenonColour(currentMenuItemID)
    elseif currentMenu == "KaplamalarMenu" then
        PreviewOldLivery(currentMenuItemID)
    end
end

function GetPlatesName(index)
	if (index == 0) then
		return 'Beyaz Üzerine Mavi Yazı Tip 1'
	elseif (index == 1) then
		return 'Siyah Üzerine Sarı Yazı'
	elseif (index == 2) then
		return 'Mavi Üzerine Sarı Yazı'
	elseif (index == 3) then
		return 'Beyaz Üzerine Mavi Yazı Tip 2'
	elseif (index == 4) then
		return 'Beyaz Üzerine Mavi Yazı Tip 3'
	end
end

function InitiateMenus(isMotorcycle, vehicleHealth, title)
    local LiveryOk = false

    if vehicleHealth < 1000.0 then
        local repairCost = vehicleCustomisationPrices.repair.price

        TriggerServerEvent("np-bennys:updateRepairCost", repairCost)
        createMenu("repairMenu", title, "Aracı Tamir Et")
        populateMenu("repairMenu", -1, "Tamir Et", "$" .. repairCost)
        finishPopulatingMenu("repairMenu")
    end

    createMenu("mainMenu", title, "Modifiye Seçin")

    for k, v in ipairs(vehicleCustomisation) do
        local validMods, amountValidMods = CheckValidMods(v.category, v.id)
        if amountValidMods > 0 or v.id == 18 then
            populateMenu("mainMenu", v.id, v.category, "none")
        end
    end

    populateMenu("mainMenu", -1, "Boya", "none")

    if not isMotorcycle then
        populateMenu("mainMenu", -2, "Cam Filmi", "none")
        populateMenu("mainMenu", -3, "Neonlar", "none")
    end

    populateMenu("mainMenu", 22, "Xenon Farlar", "none")
    populateMenu("mainMenu", 23, "Jantlar", "none")

    populateMenu("mainMenu", 26, "Plaka", "none")

    local livCount = GetVehicleLiveryCount(plyVeh)
    if livCount > 0 then
        LiveryOk = true
        populateMenu("mainMenu", 24, "Kaplamalar", "none")
    end
    populateMenu("mainMenu", 25, "Araç Ekstraları", "none")

    finishPopulatingMenu("mainMenu")

    createMenu("PlakaMenu", "Plakalar", "Tip Seçin")
    for index = 0, 4, 1 do
        populateMenu("PlakaMenu", index, GetPlatesName(index), "Ücretsiz")
        local currentPlate = GetVehicleNumberPlateTextIndex(plyVeh)
        if currentPlate == index then
            updateItem2Text("PlakaMenu", index, InstalledText)
        end
    end
    finishPopulatingMenu("PlakaMenu")

    for k, v in ipairs(vehicleCustomisation) do
        local validMods, amountValidMods = CheckValidMods(v.category, v.id)
        local currentMod, currentModName = GetCurrentMod(v.id)

        if amountValidMods > 0 or v.id == 18 then
            if v.id == 11 or v.id == 12 or v.id == 13 or v.id == 15 or v.id == 16 then
                local tempNum = 0

                createMenu(v.category:gsub("%s+", "") .. "Menu", v.category, "Seviye Seçin")

                for m, n in pairs(validMods) do
                    tempNum = tempNum + 1

                    if maxVehiclePerformanceUpgrades == 0 then
                        populateMenu(v.category:gsub("%s+", "") .. "Menu", n.id, n.name, "$" .. calcPrice(vehicleCustomisationPrices.performance.prices[tempNum]))

                        if currentMod == n.id then
                            updateItem2Text(v.category:gsub("%s+", "") .. "Menu", n.id, InstalledText)
                        end
                    else
                        if tempNum <= (maxVehiclePerformanceUpgrades + 1) then
                            populateMenu(v.category:gsub("%s+", "") .. "Menu", n.id, n.name, "$" .. calcPrice(vehicleCustomisationPrices.performance.prices[tempNum]))

                            if currentMod == n.id then
                                updateItem2Text(v.category:gsub("%s+", "") .. "Menu", n.id, InstalledText)
                            end
                        end
                    end
                end

                finishPopulatingMenu(v.category:gsub("%s+", "") .. "Menu")
            elseif v.id == 18 then
                local currentTurboState = GetCurrentTurboState()
                createMenu(v.category:gsub("%s+", "") .. "Menu", v.category .. " Customisation", "Turbo Tak / Çıkar")

                populateMenu(v.category:gsub("%s+", "") .. "Menu", 0, "Pasif", "$0")
                populateMenu(v.category:gsub("%s+", "") .. "Menu", 1, "Aktif", "$" .. calcPrice(vehicleCustomisationPrices.turbo.price))

                updateItem2Text(v.category:gsub("%s+", "") .. "Menu", currentTurboState, InstalledText)

                finishPopulatingMenu(v.category:gsub("%s+", "") .. "Menu")
            else
                createMenu(v.category:gsub("%s+", "") .. "Menu", v.category .. " Customisation", "Choose a Mod")

                for m, n in pairs(validMods) do
                    populateMenu(v.category:gsub("%s+", "") .. "Menu", n.id, n.name, "$" .. calcPrice(vehicleCustomisationPrices.cosmetics.price))

                    if currentMod == n.id then
                        updateItem2Text(v.category:gsub("%s+", "") .. "Menu", n.id, InstalledText)
                    end
                end

                finishPopulatingMenu(v.category:gsub("%s+", "") .. "Menu")
            end
        end
    end

    createMenu("BoyaMenu", "Boya", "Renk Kategorisi Seçin")

    populateMenu("BoyaMenu", 0, "Ana Renk", "none")
    populateMenu("BoyaMenu", 1, "İkincil Renk", "none")
    populateMenu("BoyaMenu", 2, "Sedef", "none")
    populateMenu("BoyaMenu", 3, "Jant Rengi", "none")
    populateMenu("BoyaMenu", 4, "Gösterge Rengi", "none")
    populateMenu("BoyaMenu", 5, "İç Döşeme Rengi", "none")

    finishPopulatingMenu("BoyaMenu")

    createMenu("BoyaTypeMenu", "Boya Tipi", "Bir Boya Tipi Seçin")

    for k, v in ipairs(vehicleBoyaOptions) do
        populateMenu("BoyaTypeMenu", v.id, v.category, "none")
    end

    finishPopulatingMenu("BoyaTypeMenu")

    for k, v in ipairs(vehicleBoyaOptions) do
        createMenu(v.category .. "Menu", v.category .. " Colours", "Renk Seçin")

        for m, n in ipairs(v.colours) do
            populateMenu(v.category .. "Menu", n.id, n.name, "$" .. calcPrice(vehicleCustomisationPrices.boya.price))
        end

        finishPopulatingMenu(v.category .. "Menu")
    end

    createMenu("JantlarMenu", "Jantlar", "Kategori Seçin")

    for k, v in ipairs(vehicleWheelOptions) do
        if isMotorcycle then
            if v.id == -1 or v.id == 20 or v.id == 6 then
                populateMenu("JantlarMenu", v.id, v.category, "none")
            end
        else
            populateMenu("JantlarMenu", v.id, v.category, "none")
        end
    end

    finishPopulatingMenu("JantlarMenu")

    for k, v in ipairs(vehicleWheelOptions) do
        if v.id == -1 then
            local currentCustomWheelState = GetCurrentCustomWheelState()
            createMenu(v.category:gsub("%s+", "") .. "Menu", v.category, "Özel Lastikler Aktif/Pasif")

            populateMenu(v.category:gsub("%s+", "") .. "Menu", 0, "Pasif", "$0")
            populateMenu(v.category:gsub("%s+", "") .. "Menu", 1, "Aktif", "$" .. calcPrice(vehicleCustomisationPrices.customwheels.price))

            updateItem2Text(v.category:gsub("%s+", "") .. "Menu", currentCustomWheelState, InstalledText)

            finishPopulatingMenu(v.category:gsub("%s+", "") .. "Menu")
        elseif v.id ~= 20 then
            if isMotorcycle then
                if v.id == 6 then
                    local validMods, amountValidMods = CheckValidMods(v.category, v.wheelID, v.id)

                    createMenu(v.category .. "Menu", v.category .. " Wheels", "Jant Seç")

                    for m, n in pairs(validMods) do
                        populateMenu(v.category .. "Menu", n.id, n.name, "$" .. calcPrice(vehicleCustomisationPrices.wheels.price))
                    end

                    finishPopulatingMenu(v.category .. "Menu")
                end
            else
                local validMods, amountValidMods = CheckValidMods(v.category, v.wheelID, v.id)

                createMenu(v.category .. "Menu", v.category .. " Wheels", "Jant Seç")

                for m, n in pairs(validMods) do
                    populateMenu(v.category .. "Menu", n.id, n.name, "$" .. calcPrice(vehicleCustomisationPrices.wheels.price))
                end

                finishPopulatingMenu(v.category .. "Menu")
            end
        end
    end

    local currentWheelSmokeR, currentWheelSmokeG, currentWheelSmokeB = GetCurrentVehicleWheelSmokeColour()
    createMenu("LastikDumanıMenu", "Lastik Dumanı Rengi", "Renk Seçin")

    for k, v in ipairs(vehicleTyreSmokeOptions) do
        populateMenu("LastikDumanıMenu", k, v.name, "$" .. calcPrice(vehicleCustomisationPrices.jantlarmoke.price))

        if v.r == currentWheelSmokeR and v.g == currentWheelSmokeG and v.b == currentWheelSmokeB then
            updateItem2Text("LastikDumanıMenu", k, InstalledText)
        end
    end

    finishPopulatingMenu("LastikDumanıMenu")

    local currentWindowTint = GetCurrentWindowTint()
    createMenu("CamFilmiMenu", "Cam Filmi", "Cam Filmi Seçin")

    for k, v in ipairs(vehicleCamFilmiOptions) do
        populateMenu("CamFilmiMenu", v.id, v.name, "$" .. calcPrice(vehicleCustomisationPrices.camfilmi.price))

        if currentWindowTint == v.id then
            updateItem2Text("CamFilmiMenu", v.id, InstalledText)
        end
    end

    finishPopulatingMenu("CamFilmiMenu")

    if LiveryOk then
        local tempOldLivery = GetVehicleLivery(plyVeh)
        createMenu("KaplamalarMenu", "Kaplamalar", "Kaplama Seçin")
        for i=0, GetVehicleLiveryCount(plyVeh)-1 do
            populateMenu("KaplamalarMenu", i, "Kaplama", "$"..calcPrice(vehicleCustomisationPrices.kaplamalar.price))
            if tempOldLivery == i then
                updateItem2Text("KaplamalarMenu", i, InstalledText)
            end
        end
        finishPopulatingMenu("KaplamalarMenu")
    end

    createMenu("AraçEkstralarıMenu", "Araç Ekstraları", "Ekstra Aktif/Pasif")
    for i=1, 12 do
        if DoesExtraExist(plyVeh, i) then
            populateMenu("AraçEkstralarıMenu", i, "Extra "..tostring(i), "Aç/Kapat")
        else
            populateMenu("AraçEkstralarıMenu", i, "Ekstra Yok!", "NONE")
        end
    end
    finishPopulatingMenu("AraçEkstralarıMenu")

    createMenu("NeonlarMenu", "Neon Kastimizasyon", "Kategori Seçin")

    for k, v in ipairs(vehicleNeonOptions.neonTypes) do
        populateMenu("NeonlarMenu", v.id, v.name, "none")
    end

    populateMenu("NeonlarMenu", -1, "Neon Rengi", "none")
    finishPopulatingMenu("NeonlarMenu")

    for k, v in ipairs(vehicleNeonOptions.neonTypes) do
        local currentNeonState = GetCurrentNeonState(v.id)
        createMenu(v.name:gsub("%s+", "") .. "Menu", "Neon Kastimizasyon", "Noen / Aktif Pasif")

        populateMenu(v.name:gsub("%s+", "") .. "Menu", 0, "Disabled", "$0")
        populateMenu(v.name:gsub("%s+", "") .. "Menu", 1, "Enabled", "$" .. calcPrice(vehicleCustomisationPrices.neonlarside.price))

        updateItem2Text(v.name:gsub("%s+", "") .. "Menu", currentNeonState, InstalledText)

        finishPopulatingMenu(v.name:gsub("%s+", "") .. "Menu")
    end

    local currentNeonR, currentNeonG, currentNeonB = GetCurrentNeonColour()
    createMenu("NeonRengiMenu", "Neon Rengi", "Renk Seçin")

    for k, v in ipairs(vehicleNeonOptions.neonColours) do
        populateMenu("NeonRengiMenu", k, vehicleNeonOptions.neonColours[k].name, "$" .. calcPrice(vehicleCustomisationPrices.neonrengi.price))

        if currentNeonR == vehicleNeonOptions.neonColours[k].r and currentNeonG == vehicleNeonOptions.neonColours[k].g and currentNeonB == vehicleNeonOptions.neonColours[k].b then
            updateItem2Text("NeonRengiMenu", k, InstalledText)
        end
    end

    finishPopulatingMenu("NeonRengiMenu")

    createMenu("XenonFarlarMenu", "Xenon Farlar", "Kategori Seçin")

    populateMenu("XenonFarlarMenu", 0, "Xenon", "none")
    populateMenu("XenonFarlarMenu", 1, "Xenon Rengi", "none")

    finishPopulatingMenu("XenonFarlarMenu")

    local currentXenonState = GetCurrentXenonState()
    createMenu("XenonMenu", "Farlar", "Zenon Far Aktif/Pasif")

    populateMenu("XenonMenu", 0, "Xenon Far Pasif", "$0")
    populateMenu("XenonMenu", 1, "Xenon Far Aktif", "$" .. calcPrice(vehicleCustomisationPrices.xenon.price))

    updateItem2Text("XenonMenu", currentXenonState, InstalledText)

    finishPopulatingMenu("XenonMenu")

    local currentXenonColour = GetCurrentXenonColour()
    createMenu("XenonRengiMenu", "Xenon Far Rengi", "Renk Seçin")

    for k, v in ipairs(vehicleXenonOptions.xenonColours) do
        populateMenu("XenonRengiMenu", v.id, v.name, "$" .. calcPrice(vehicleCustomisationPrices.xenonrengi.price))

        if currentXenonColour == v.id then
            updateItem2Text("XenonRengiMenu", v.id, InstalledText)
        end
    end

    finishPopulatingMenu("XenonRengiMenu")
end

function DestroyMenus()
    destroyMenus()
end

function DisplayMenuContainer(state)
    toggleMenuContainer(state)
end

function DisplayMenu(state, menu)
    if state then
        currentMenu = menu
    end

    toggleMenu(state, menu)
    updateMenuHeading(menu)
    updateMenuSubheading(menu)
end

function MenuManager(state)
    if state then
        if currentMenuItem2 ~= InstalledText then
            if isMenuActive("modMenu") then
                if currentCategory == 18 then
                    if AttemptPurchase("turbo") then
                        ApplyMod(currentCategory, currentMenuItemID)
                        playSoundEffect("wrench", 0.4)
                        updateItem2Text(currentMenu, currentMenuItemID, InstalledText)
                        updateMenuStatus(purchasedText)
                    else
                        updateMenuStatus(noMoney)
                    end
                elseif currentCategory == 11 or currentCategory == 12 or currentCategory== 13 or currentCategory == 15 or currentCategory == 16 then
                    if AttemptPurchase("performance", currentMenuItemID) then
                        ApplyMod(currentCategory, currentMenuItemID)
                        playSoundEffect("wrench", 0.4)
                        updateItem2Text(currentMenu, currentMenuItemID, InstalledText)
                        updateMenuStatus(purchasedText)
                    else
                        updateMenuStatus(noMoney)
                    end
                elseif currentCategory == 26 then
                    ApplyPlate(currentMenuItemID)
                    playSoundEffect("wrench", 0.4)
                    updateItem2Text(currentMenu, currentMenuItemID, InstalledText)
                    updateMenuStatus(purchasedText)
                else
                    if AttemptPurchase("cosmetics") then
                        ApplyMod(currentCategory, currentMenuItemID)
                        playSoundEffect("wrench", 0.4)
                        updateItem2Text(currentMenu, currentMenuItemID, InstalledText)
                        updateMenuStatus(purchasedText)
                    else
                        updateMenuStatus(noMoney)
                    end
                end
            elseif isMenuActive("BoyaMenu") then
                if AttemptPurchase("boya") then
                    ApplyColour(currentBoyaCategory, currentBoyaType, currentMenuItemID)
                    playSoundEffect("boya", 1.0)
                    updateItem2Text(currentMenu, currentMenuItemID, InstalledText)
                    updateMenuStatus(purchasedText)
                else
                    updateMenuStatus(noMoney)
                end
            elseif isMenuActive("JantlarMenu") then
                if currentWheelCategory == 20 then
                    if AttemptPurchase("jantlarmoke") then
                        local r = vehicleTyreSmokeOptions[currentMenuItemID].r
                        local g = vehicleTyreSmokeOptions[currentMenuItemID].g
                        local b = vehicleTyreSmokeOptions[currentMenuItemID].b

                        ApplyTyreSmoke(r, g, b)
                        playSoundEffect("wrench", 0.4)
                        updateItem2Text(currentMenu, currentMenuItemID, InstalledText)
                        updateMenuStatus(purchasedText)
                    else
                        updateMenuStatus(noMoney)
                    end
                else
                    if currentWheelCategory == -1 then
                        local currentWheel = GetCurrentWheel()

                        if currentWheel == -1 then
                            updateMenuStatus("Stok Jantlara Özel Lastik Takamazsın!")
                        else
                            if AttemptPurchase("customwheels") then
                                ApplyCustomWheel(currentMenuItemID)
                                playSoundEffect("wrench", 0.4)
                                updateItem2Text(currentMenu, currentMenuItemID, InstalledText)
                                updateMenuStatus(purchasedText)
                            else
                                updateMenuStatus(noMoney)
                            end
                        end
                    else
                        local currentWheel = GetCurrentWheel()
                        local currentCustomWheelState = GetOriginalCustomWheel()

                        if currentCustomWheelState and currentWheel == -1 then
                            updateMenuStatus("Özel Lastik Takılı İken Stok Jant Takamazsın!")
                        else
                            if AttemptPurchase("wheels") then
                                ApplyWheel(currentCategory, currentMenuItemID, currentWheelCategory)
                                playSoundEffect("wrench", 0.4)
                                updateItem2Text(currentMenu, currentMenuItemID, InstalledText)
                                updateMenuStatus(purchasedText)
                            else
                                updateMenuStatus(noMoney)
                            end
                        end
                    end
                end
            elseif isMenuActive("NeonlarSideMenu") then
                if AttemptPurchase("neonlarside") then
                    ApplyNeon(currentNeonSide, currentMenuItemID)
                    playSoundEffect("wrench", 0.4)
                    updateItem2Text(currentMenu, currentMenuItemID, InstalledText)
                    updateMenuStatus(purchasedText)
                else
                    updateMenuStatus(noMoney)
                end
            else
                if currentMenu == "repairMenu" then
                    if AttemptPurchase("repair") then
                        currentMenu = "mainMenu"
                        RepairVehicle()
                        ExitBennys()
                        playSoundEffect("wrench", 0.4)
                    else
                        updateMenuStatus(noMoney)
                    end
                elseif currentMenu == "mainMenu" then
                    currentMenu = currentMenuItem:gsub("%s+", "") .. "Menu"
                    currentCategory = currentMenuItemID

                    toggleMenu(false, "mainMenu")
                    toggleMenu(true, currentMenu)
                    updateMenuHeading(currentMenu)
                    updateMenuSubheading(currentMenu)
                elseif currentMenu == "BoyaMenu" then
                    currentMenu = "BoyaTypeMenu"
                    currentBoyaCategory = currentMenuItemID

                    toggleMenu(false, "BoyaMenu")
                    toggleMenu(true, currentMenu)
                    updateMenuHeading(currentMenu)
                    updateMenuSubheading(currentMenu)
                elseif currentMenu == "BoyaTypeMenu" then
                    currentMenu = currentMenuItem:gsub("%s+", "") .. "Menu"
                    currentBoyaType = currentMenuItemID

                    toggleMenu(false, "BoyaTypeMenu")
                    toggleMenu(true, currentMenu)
                    updateMenuHeading(currentMenu)
                    updateMenuSubheading(currentMenu)
                elseif currentMenu == "JantlarMenu" then
                    local currentWheel, currentWheelName, currentWheelType = GetCurrentWheel()

                    currentMenu = currentMenuItem:gsub("%s+", "") .. "Menu"
                    currentWheelCategory = currentMenuItemID

                    if currentWheelType == currentWheelCategory then
                        updateItem2Text(currentMenu, currentWheel, InstalledText)
                    end

                    toggleMenu(false, "JantlarMenu")
                    toggleMenu(true, currentMenu)
                    updateMenuHeading(currentMenu)
                    updateMenuSubheading(currentMenu)
                elseif currentMenu == "NeonlarMenu" then
                    currentMenu = currentMenuItem:gsub("%s+", "") .. "Menu"
                    currentNeonSide = currentMenuItemID

                    toggleMenu(false, "NeonlarMenu")
                    toggleMenu(true, currentMenu)
                    updateMenuHeading(currentMenu)
                    updateMenuSubheading(currentMenu)
                elseif currentMenu == "XenonFarlarMenu" then
                    currentMenu = currentMenuItem:gsub("%s+", "") .. "Menu"

                    toggleMenu(false, "XenonFarlarMenu")
                    toggleMenu(true, currentMenu)
                    updateMenuHeading(currentMenu)
                    updateMenuSubheading(currentMenu)
                elseif currentMenu == "CamFilmiMenu" then
                    if AttemptPurchase("camfilmi") then
                        ApplyWindowTint(currentMenuItemID)
                        playSoundEffect("boya", 1.0)
                        updateItem2Text(currentMenu, currentMenuItemID, InstalledText)
                        updateMenuStatus(purchasedText)
                    else
                        updateMenuStatus(noMoney)
                    end
                elseif currentMenu == "NeonRengiMenu" then
                    if AttemptPurchase("neonrengi") then
                        local r = vehicleNeonOptions.neonColours[currentMenuItemID].r
                        local g = vehicleNeonOptions.neonColours[currentMenuItemID].g
                        local b = vehicleNeonOptions.neonColours[currentMenuItemID].b

                        ApplyNeonColour(r, g, b)
                        playSoundEffect("boya", 1.0)
                        updateItem2Text(currentMenu, currentMenuItemID, InstalledText)
                        updateMenuStatus(purchasedText)
                    else
                        updateMenuStatus(noMoney)
                    end
                elseif currentMenu == "XenonMenu" then
                    if AttemptPurchase("xenon") then
                        ApplyXenonLights(currentCategory, currentMenuItemID)
                        playSoundEffect("wrench", 0.4)
                        updateItem2Text(currentMenu, currentMenuItemID, InstalledText)
                        updateMenuStatus(purchasedText)
                    else
                        updateMenuStatus(noMoney)
                    end
                elseif currentMenu == "XenonRengiMenu" then
                    if AttemptPurchase("xenonrengi") then
                        ApplyXenonColour(currentMenuItemID)
                        playSoundEffect("boya", 1.0)
                        updateItem2Text(currentMenu, currentMenuItemID, InstalledText)
                        updateMenuStatus(purchasedText)
                    else
                        updateMenuStatus(noMoney)
                    end
                elseif currentMenu == "KaplamalarMenu" then
                    if AttemptPurchase("kaplamalar") then
                        ApplyOldLivery(currentMenuItemID)
                        playSoundEffect("wrench", 0.1)
                        updateItem2Text(currentMenu, currentMenuItemID, InstalledText)
                        updateMenuStatus(purchasedText)
                    else
                        updateMenuStatus(noMoney)
                    end
                elseif currentMenu == "AraçEkstralarıMenu" then
                    ApplyExtra(currentMenuItemID)
                    playSoundEffect("wrench", 0.1)
                    updateItem2TextOnly(currentMenu, currentMenuItemID, "Toggle")
                    updateMenuStatus(purchasedText)
                end
            end
        else
            if currentMenu == "AraçEkstralarıMenu" then
                ApplyExtra(currentMenuItemID)
                playSoundEffect("wrench", 0.1)
                updateItem2TextOnly(currentMenu, currentMenuItemID, "Toggle")
                updateMenuStatus(purchasedText)
            end
        end
    else
        updateMenuStatus("")

        if isMenuActive("modMenu") then
            toggleMenu(false, currentMenu)

            currentMenu = "mainMenu"

            if currentCategory ~= 18 then
                RestoreOriginalMod()
            end

            toggleMenu(true, currentMenu)
            updateMenuHeading(currentMenu)
            updateMenuSubheading(currentMenu)
        elseif isMenuActive("BoyaMenu") then
            toggleMenu(false, currentMenu)

            currentMenu = "BoyaTypeMenu"

            RestoreOriginalColours()

            toggleMenu(true, currentMenu)
            updateMenuHeading(currentMenu)
            updateMenuSubheading(currentMenu)
        elseif isMenuActive("JantlarMenu") then
            if currentWheelCategory ~= 20 and currentWheelCategory ~= -1 then
                local currentWheel = GetOriginalWheel()
                updateItem2Text(currentMenu, currentWheel, "$" .. calcPrice(vehicleCustomisationPrices.wheels.price))
                RestoreOriginalWheels()
            end

            toggleMenu(false, currentMenu)

            currentMenu = "JantlarMenu"

            toggleMenu(true, currentMenu)
            updateMenuHeading(currentMenu)
            updateMenuSubheading(currentMenu)
        elseif isMenuActive("NeonlarSideMenu") then
            toggleMenu(false, currentMenu)

            currentMenu = "NeonlarMenu"

            RestoreOriginalNeonStates()

            toggleMenu(true, currentMenu)
            updateMenuHeading(currentMenu)
            updateMenuSubheading(currentMenu)
        else
            if currentMenu == "mainMenu" or currentMenu == "repairMenu" then
                ExitBennys()
            elseif currentMenu == "BoyaMenu" or currentMenu == "CamFilmiMenu" or currentMenu == "JantlarMenu" or currentMenu == "NeonlarMenu" or currentMenu == "XenonFarlarMenu" or currentMenu == "KaplamalarMenu" or currentMenu == "AraçEkstralarıMenu" or currentMenu == "PlakaMenu" then
                toggleMenu(false, currentMenu)

                if currentMenu == "CamFilmiMenu" then
                    RestoreOriginalWindowTint()
                end

                if currentMenu == "KaplamalarMenu" then
                    RestoreOldLivery()
                end

                currentMenu = "mainMenu"

                toggleMenu(true, currentMenu)
                updateMenuHeading(currentMenu)
                updateMenuSubheading(currentMenu)
            elseif currentMenu == "BoyaTypeMenu" then
                toggleMenu(false, currentMenu)

                currentMenu = "BoyaMenu"

                toggleMenu(true, currentMenu)
                updateMenuHeading(currentMenu)
                updateMenuSubheading(currentMenu)
            elseif currentMenu == "NeonRengiMenu" then
                toggleMenu(false, currentMenu)

                currentMenu = "NeonlarMenu"

                RestoreOriginalNeonColours()

                toggleMenu(true, currentMenu)
                updateMenuHeading(currentMenu)
                updateMenuSubheading(currentMenu)
            elseif currentMenu == "XenonMenu" then
                toggleMenu(false, currentMenu)

                currentMenu = "XenonFarlarMenu"

                toggleMenu(true, currentMenu)
                updateMenuHeading(currentMenu)
                updateMenuSubheading(currentMenu)
            elseif currentMenu == "XenonRengiMenu" then
                toggleMenu(false, currentMenu)

                currentMenu = "XenonFarlarMenu"

                RestoreOriginalXenonColour()

                toggleMenu(true, currentMenu)
                updateMenuHeading(currentMenu)
                updateMenuSubheading(currentMenu)
            end
        end
    end
end

function MenuScrollFunctionality(direction)
    scrollMenuFunctionality(direction, currentMenu)
end

RegisterNUICallback("selectedItem", function(data, cb)
    updateCurrentMenuItemID(tonumber(data.id), data.item, data.item2)

    cb("ok")
end)

RegisterNUICallback("updateItem2", function(data, cb)
    currentMenuItem2 = data.item

    cb("ok")
end)