
polis = false
plyVeh = 0

local Vehicles = {}
local PlayerData = {}
local location = Locations[1]
local admin = false
local basildi = false

thombursa = exports['thombursa']:GetCoreObject()

RegisterNetEvent('jezzy-base:araclarim')
AddEventHandler('jezzy-base:araclarim', function(a, b)
    PlayerData = thombursa.Functions.GetPlayerData()
    Vehicles = a
    playerLoaded = true
end)

RegisterNetEvent('thombursa:Client:OnJobUpdate')
AddEventHandler('thombursa:Client:OnJobUpdate', function(job)
    PlayerData.job = job
end)

isPlyInBennys = false

local plyFirstJoin = false

local nearDefault = false
local nearImport = false
local nearTuner = false

local bennyLocationTuner = vector3(-213.78, -1335.8, 30.58)
local bennyLocationImport = vector3(-213.78, -1335.8, 30.58)
local bennyLocation = vector3(-213.78, -1335.8, 30.58)

local bennyHeading = 319.73135375977

local originalCategory = nil
local originalMod = nil
local originalPrimaryColour = nil
local originalSecondaryColour = nil
local originalPearlescentColour = nil
local originalWheelColour = nil
local originalDashColour = nil
local originalInterColour = nil
local originalWindowTint = nil
local originalWheelCategory = nil
local originalWheel = nil
local originalWheelType = nil
local originalCustomWheels = nil
local originalNeonLightState = nil
local originalNeonLightSide = nil
local originalNeonColourR = nil
local originalNeonColourG = nil
local originalNeonColourB = nil
local originalXenonColour = nil
local originalOldLivery = nil

local attemptingPurchase = false
local isPurchaseSuccessful = false

exports("inMechanicMenu", function()
    return isPlyInBennys
end)

local function isNear(pos1, pos2, distMustBe)
    local diff = pos2 - pos1
	local dist = (diff.x * diff.x) + (diff.y * diff.y)

	return (dist < (distMustBe * distMustBe))
end

local function saveVehicle()
    TriggerServerEvent('updateVehicle', thombursa.Functions.GetVehicleProperties(GetVehiclePedIsIn(PlayerPedId())))
end

function AttemptPurchase(type, upgradeLevel)
    if upgradeLevel ~= nil then
        upgradeLevel = upgradeLevel + 2
    end
    TriggerServerEvent("np-bennys:attemptPurchase", admin, type, npcMechanic, location["mechanic"], vehiclePrice, polis, upgradeLevel)

    attemptingPurchase = true

    while attemptingPurchase do
        Citizen.Wait(1)
    end

    if not isPurchaseSuccessful then
        PlaySoundFrontend(-1, "ERROR", "HUD_FRONTEND_DEFAULT_SOUNDSET", 1)
    end

    return isPurchaseSuccessful
end

local reapirProgress = false
function RepairVehicle()
    reapirProgress = true
    thombursa.Functions.Progressbar("repair", "Araç Tamir Ediliyor!", 10000, false, false, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    }, {}, {}, {}, function()
        local plyPed = PlayerPedId()
        local fuel = GetVehicleFuelLevel(plyVeh)
        SetVehicleFixed(plyVeh)
        SetVehicleDirtLevel(plyVeh, 0.0)
        setOldFuel(plyVeh, fuel)

        reapirProgress = false
    end, function()
        reapirProgress = false
    end)
end

function GetCurrentMod(id)
    local plyPed = PlayerPedId()
    local mod = GetVehicleMod(plyVeh, id)
    local modName = GetLabelText(GetModTextLabel(plyVeh, id, mod))

    return mod, modName
end

function GetCurrentWheel()
    local plyPed = PlayerPedId()
    local wheel = GetVehicleMod(plyVeh, 23)
    local wheelName = GetLabelText(GetModTextLabel(plyVeh, 23, wheel))
    local wheelType = GetVehicleWheelType(plyVeh)

    return wheel, wheelName, wheelType
end

function GetCurrentCustomWheelState()
    local plyPed = PlayerPedId()
    local state = GetVehicleModVariation(plyVeh, 23)

    if state then
        return 1
    else
        return 0
    end
end

function GetOriginalWheel()
    return originalWheel
end

function GetOriginalCustomWheel()
    return originalCustomWheels
end

function GetCurrentWindowTint()
    local plyPed = PlayerPedId()

    return GetVehicleWindowTint(plyVeh)
end

function GetCurrentVehicleWheelSmokeColour()
    local plyPed = PlayerPedId()
    local r, g, b = GetVehicleTyreSmokeColor(plyVeh)

    return r, g, b
end

function GetCurrentNeonState(id)
    local plyPed = PlayerPedId()
    local isEnabled = IsVehicleNeonLightEnabled(plyVeh, id)

    if isEnabled then
        return 1
    else
        return 0
    end
end

function GetCurrentNeonColour()
    local plyPed = PlayerPedId()
    local r, g, b = GetVehicleNeonLightsColour(plyVeh)

    return r, g, b
end

function GetCurrentXenonState()
    local plyPed = PlayerPedId()
    local isEnabled = IsToggleModOn(plyVeh, 22)

    if isEnabled then
        return 1
    else
        return 0
    end
end

function GetCurrentXenonColour()
    local plyPed = PlayerPedId()

    return GetVehicleHeadlightsColour(plyVeh)
end

function GetCurrentTurboState()
    local plyPed = PlayerPedId()
    local isEnabled = IsToggleModOn(plyVeh, 18)

    if isEnabled then
        return 1
    else
        return 0
    end
end

function GetCurrentExtraState(extra)
    local plyPed = PlayerPedId()
    return IsVehicleExtraTurnedOn(plyVeh, extra)
end

function CheckValidMods(category, id, wheelType)
    local plyPed = PlayerPedId()
    local tempMod = GetVehicleMod(plyVeh, id)
    local tempWheel = GetVehicleMod(plyVeh, 23)
    local tempWheelType = GetVehicleWheelType(plyVeh)
    local tempWheelCustom = GetVehicleModVariation(plyVeh, 23)
    local validMods = {}
    local amountValidMods = 0
    local hornNames = {}

    if wheelType ~= nil then
        SetVehicleWheelType(plyVeh, wheelType)
    end

    if id == 14 then
        for k, v in pairs(vehicleCustomisation) do
            if vehicleCustomisation[k].category == category then
                hornNames = vehicleCustomisation[k].hornNames

                break
            end
        end
    end

    local modAmount = GetNumVehicleMods(plyVeh, id)
    for i = 1, modAmount do
        local label = GetModTextLabel(plyVeh, id, (i - 1))
        local modName = GetLabelText(label)

        if modName == "NULL" then
            if id == 14 then
                if i <= #hornNames then
                    modName = hornNames[i].name
                else
                    modName = "Horn " .. i
                end
            else
                modName = category .. " " .. i
            end
        end
        validMods[i] =
        {
            id = (i - 1),
            name = modName
        }

        amountValidMods = amountValidMods + 1
    end

    if modAmount > 0 then
        table.insert(validMods, 1, {
            id = -1,
            name = "Stock " .. category
        })
    end

    if wheelType ~= nil then
        SetVehicleWheelType(plyVeh, tempWheelType)
        SetVehicleMod(plyVeh, 23, tempWheel, tempWheelCustom)
    end

    return validMods, amountValidMods
end

function RestoreOriginalMod()
    local plyPed = PlayerPedId()

    SetVehicleMod(plyVeh, originalCategory, originalMod)
    SetVehicleDoorsShut(plyVeh, true)

    originalCategory = nil
    originalMod = nil
end

function RestoreOriginalWindowTint()
    local plyPed = PlayerPedId()

    SetVehicleWindowTint(plyVeh, originalWindowTint)

    originalWindowTint = nil
end

function RestoreOriginalColours()
    local plyPed = PlayerPedId()

    SetVehicleColours(plyVeh, originalPrimaryColour, originalSecondaryColour)
    SetVehicleExtraColours(plyVeh, originalPearlescentColour, originalWheelColour)
    SetVehicleDashboardColour(plyVeh, originalDashColour)
    SetVehicleInteriorColour(plyVeh, originalInterColour)

    originalPrimaryColour = nil
    originalSecondaryColour = nil
    originalPearlescentColour = nil
    originalWheelColour = nil
    originalDashColour = nil
    originalInterColour = nil
end

function RestoreOriginalWheels()
    local plyPed = PlayerPedId()
    local doesHaveCustomWheels = GetVehicleModVariation(plyVeh, 23)

    SetVehicleWheelType(plyVeh, originalWheelType)

    if originalWheelCategory ~= nil then
        SetVehicleMod(plyVeh, originalWheelCategory, originalWheel, originalCustomWheels)

        if GetVehicleClass(plyVeh) == 8 then
            SetVehicleMod(plyVeh, 24, originalWheel, originalCustomWheels)
        end

        originalWheelType = nil
        originalWheelCategory = nil
        originalWheel = nil
        originalCustomWheels = nil
    end
end

function RestoreOriginalNeonStates()
    local plyPed = PlayerPedId()

    SetVehicleNeonLightEnabled(plyVeh, originalNeonLightSide, originalNeonLightState)

    originalNeonLightState = nil
    originalNeonLightSide = nil
end

function RestoreOriginalNeonColours()
    local plyPed = PlayerPedId()

    SetVehicleNeonLightsColour(plyVeh, originalNeonColourR, originalNeonColourG, originalNeonColourB)

    originalNeonColourR = nil
    originalNeonColourG = nil
    originalNeonColourB = nil
end

function RestoreOriginalXenonColour()
    local plyPed = PlayerPedId()

    SetVehicleHeadlightsColour(plyVeh, originalXenonColour)
    SetVehicleLights(plyVeh, 0)

    originalXenonColour = nil
end

function RestoreOldLivery()
    local plyPed = PlayerPedId()
    SetVehicleLivery(plyVeh, originalOldLivery)
end

function PreviewMod(categoryID, modID)
    local plyPed = PlayerPedId()

    if originalMod == nil and originalCategory == nil then
        originalCategory = categoryID
        originalMod = GetVehicleMod(plyVeh, categoryID)
    end

    if categoryID == 39 or categoryID == 40 or categoryID == 41 then
        SetVehicleDoorOpen(plyVeh, 4, false, true)
    elseif categoryID == 37 or categoryID == 38 then
        SetVehicleDoorOpen(plyVeh, 5, false, true)
    end

    SetVehicleMod(plyVeh, categoryID, modID)
end

function PreviewWindowTint(windowTintID)
    local plyPed = PlayerPedId()

    if originalWindowTint == nil then
        originalWindowTint = GetVehicleWindowTint(plyVeh)
    end

    SetVehicleWindowTint(plyVeh, windowTintID)
end

function PreviewColour(paintType, paintCategory, paintID)
    local plyPed = PlayerPedId()
    SetVehicleModKit(plyVeh, 0)

    if originalDashColour == nil and originalInterColour == nil and originalPrimaryColour == nil and originalSecondaryColour == nil and originalPearlescentColour == nil and originalWheelColour == nil then
        originalPrimaryColour, originalSecondaryColour = GetVehicleColours(plyVeh)
        originalPearlescentColour, originalWheelColour = GetVehicleExtraColours(plyVeh)
        originalDashColour = GetVehicleDashboardColour(plyVeh)
        originalInterColour = GetVehicleInteriorColour(plyVeh)
    end
    if paintType == 0 then
        if paintCategory == 1 then
            SetVehicleColours(plyVeh, paintID, originalSecondaryColour)

        else
            SetVehicleColours(plyVeh, paintID, originalSecondaryColour)
        end
    elseif paintType == 1 then
        SetVehicleColours(plyVeh, originalPrimaryColour, paintID)
    elseif paintType == 2 then
        SetVehicleExtraColours(plyVeh, paintID, originalWheelColour)
    elseif paintType == 3 then
        SetVehicleExtraColours(plyVeh, originalPearlescentColour, paintID)
    elseif paintType == 4 then
        SetVehicleDashboardColour(plyVeh, paintID)
    elseif paintType == 5 then
        SetVehicleInteriorColour(plyVeh, paintID)
    end
end

function PreviewWheel(categoryID, wheelID, wheelType)
    local plyPed = PlayerPedId()
    local doesHaveCustomWheels = GetVehicleModVariation(plyVeh, 23)

    if originalWheelCategory == nil and originalWheel == nil and originalWheelType == nil and originalCustomWheels == nil then
        originalWheelCategory = categoryID
        originalWheelType = GetVehicleWheelType(plyVeh)
        originalWheel = GetVehicleMod(plyVeh, 23)
        originalCustomWheels = GetVehicleModVariation(plyVeh, 23)
    end

    SetVehicleWheelType(plyVeh, wheelType)
    SetVehicleMod(plyVeh, categoryID, wheelID, doesHaveCustomWheels)

    if GetVehicleClass(plyVeh) == 8 then
        SetVehicleMod(plyVeh, 24, wheelID, doesHaveCustomWheels)
    end
end

function PreviewNeon(side, enabled)
    local plyPed = PlayerPedId()

    if originalNeonLightState == nil and originalNeonLightSide == nil then
        if IsVehicleNeonLightEnabled(plyVeh, side) then
            originalNeonLightState = 1
        else
            originalNeonLightState = 0
        end

        originalNeonLightSide = side
    end

    SetVehicleNeonLightEnabled(plyVeh, side, enabled)
end

function PreviewNeonColour(r, g, b)
    local plyPed = PlayerPedId()

    if originalNeonColourR == nil and originalNeonColourG == nil and originalNeonColourB == nil then
        originalNeonColourR, originalNeonColourG, originalNeonColourB = GetVehicleNeonLightsColour(plyVeh)
    end

    SetVehicleNeonLightsColour(plyVeh, r, g, b)
end

function PreviewXenonColour(colour)
    local plyPed = PlayerPedId()

    if originalXenonColour == nil then
        originalXenonColour = GetVehicleHeadlightsColour(plyVeh)
    end

    SetVehicleLights(plyVeh, 2)
    SetVehicleHeadlightsColour(plyVeh, colour)
end

function PreviewOldLivery(liv)
    local plyPed = PlayerPedId()
    if originalOldLivery == nil then
        originalOldLivery = GetVehicleLivery(plyVeh)
    end
    SetVehicleLivery(plyVeh, tonumber(liv))
end

function ApplyMod(categoryID, modID)
    local plyPed = PlayerPedId()

    if categoryID == 18 then
        ToggleVehicleMod(plyVeh, categoryID, modID)
    elseif categoryID == 11 or categoryID == 12 or categoryID== 13 or categoryID == 15 or categoryID == 16 then
        originalCategory = categoryID
        originalMod = modID

        SetVehicleMod(plyVeh, categoryID, modID)
    else
        originalCategory = categoryID
        originalMod = modID
        if categoryID == 24 then
            SetVehicleLivery(plyVeh, modID)
        else
            SetVehicleMod(plyVeh, categoryID, modID)
        end
    end
end

function ApplyExtra(extraID)
    local plyPed = PlayerPedId()
    local isEnabled = IsVehicleExtraTurnedOn(plyVeh, extraID)
    local fuel = GetVehicleFuelLevel(plyVeh)
    if isEnabled == 1 then
        SetVehicleExtra(plyVeh, tonumber(extraID), 1)
    else
        SetVehicleExtra(plyVeh, tonumber(extraID), 0)
    end
    setOldFuel(plyVeh, fuel)
end

function ApplyPlate(index)
    SetVehicleNumberPlateTextIndex(plyVeh, index)
end

function setOldFuel(plyVeh, fuel)
    SetVehicleFuelLevel(plyVeh, fuel+0.0)
    DecorSetFloat(plyVeh, "_FUEL_LEVEL", fuel+0.0)
end

function ApplyWindowTint(windowTintID)
    local plyPed = PlayerPedId()
    originalWindowTint = windowTintID

    SetVehicleWindowTint(plyVeh, windowTintID)
end

function ApplyColour(paintType, paintCategory, paintID)
    local plyPed = PlayerPedId()
    local vehPrimaryColour, vehSecondaryColour = GetVehicleColours(plyVeh)
    local vehPearlescentColour, vehWheelColour = GetVehicleExtraColours(plyVeh)

    if paintType == 0 then
        if paintCategory == 1 then
            SetVehicleColours(plyVeh, paintID, vehSecondaryColour)
            SetVehicleExtraColours(plyVeh, paintID, vehWheelColour)
            originalPrimaryColour = paintID
            originalPearlescentColour = paintID
        else
            SetVehicleColours(plyVeh, paintID, vehSecondaryColour)
            originalPrimaryColour = paintID
        end
    elseif paintType == 1 then
        SetVehicleColours(plyVeh, vehPrimaryColour, paintID)
        originalSecondaryColour = paintID
    elseif paintType == 2 then
        SetVehicleExtraColours(plyVeh, paintID, vehWheelColour)
        originalPearlescentColour = paintID
    elseif paintType == 3 then
        SetVehicleExtraColours(plyVeh, vehPearlescentColour, paintID)
        originalWheelColour = paintID
    elseif paintType == 4 then
        SetVehicleDashboardColour(plyVeh, paintID)
        originalDashColour = paintID
    elseif paintType == 5 then
        SetVehicleInteriorColour(plyVeh, paintID)
        originalInterColour = paintID
    end
end

function ApplyWheel(categoryID, wheelID, wheelType)
    local plyPed = PlayerPedId()
    local doesHaveCustomWheels = GetVehicleModVariation(plyVeh, 23)

    originalWheelCategory = categoryID
    originalWheel = wheelID
    originalWheelType = wheelType

    SetVehicleWheelType(plyVeh, wheelType)
    SetVehicleMod(plyVeh, categoryID, wheelID, doesHaveCustomWheels)

    if GetVehicleClass(plyVeh) == 8 then
        SetVehicleMod(plyVeh, 24, wheelID, doesHaveCustomWheels)
    end
end

function ApplyCustomWheel(state)
    local plyPed = PlayerPedId()

    SetVehicleMod(plyVeh, 23, GetVehicleMod(plyVeh, 23), state)

    if GetVehicleClass(plyVeh) == 8 then
        SetVehicleMod(plyVeh, 24, GetVehicleMod(plyVeh, 24), state)
    end
end

function ApplyNeon(side, enabled)
    local plyPed = PlayerPedId()

    originalNeonLightState = enabled
    originalNeonLightSide = side

    SetVehicleNeonLightEnabled(plyVeh, side, enabled)
end

function ApplyNeonColour(r, g, b)
    local plyPed = PlayerPedId()

    originalNeonColourR = r
    originalNeonColourG = g
    originalNeonColourB = b

    SetVehicleNeonLightsColour(plyVeh, r, g, b)
end

function ApplyXenonLights(category, state)
    local plyPed = PlayerPedId()

    ToggleVehicleMod(plyVeh, category, state)
end

function ApplyXenonColour(colour)
    local plyPed = PlayerPedId()

    originalXenonColour = colour

    SetVehicleHeadlightsColour(plyVeh, colour)
end

function ApplyOldLivery(liv)
    local plyPed = PlayerPedId()

    originalOldLivery = liv

    SetVehicleLivery(plyVeh, liv)
end

function ApplyTyreSmoke(r, g, b)
    local plyPed = PlayerPedId()

    ToggleVehicleMod(plyVeh, 20, true)
    SetVehicleTyreSmokeColor(plyVeh, r, g, b)
end

function ExitBennys()
    local plyPed = PlayerPedId()

    saveVehicle()

    DisplayMenuContainer(false)

    FreezeEntityPosition(plyVeh, false)
    SetEntityCollision(plyVeh, true, true)

    SetTimeout(100, function()
        DestroyMenus()
    end)

    isPlyInBennys = false
end

RegisterNetEvent('jezzy-mekanik-admin', function()
	local plyPed = PlayerPedId()
    plyVeh = GetVehiclePedIsIn(plyPed, false)
    enterLocation(true, true)
end)

RegisterNetEvent('jezzy-mekanik:polisjob', function()
	local plyPed = PlayerPedId()
    plyVeh = GetVehiclePedIsIn(plyPed, false)
     enterLocation(true, false)
end)

function enterLocation(forceOpen, adminn)
    if not reapirProgress then
        polis = forceOpen
        admin = adminn
        local plyPed = PlayerPedId()
        thombursa.Functions.TriggerCallback('jezzy-base:mekanik-sayi', function(AktifMekanik)
            npcMechanic = AktifMekanik == 0 and true or false
            if PlayerData.job == nil then PlayerData = thombursa.Functions.GetPlayerData() end
            if forceOpen or PlayerData.job.name == location.mechanic then
                vehiclePrice = DefaultVehiclePrice
                for i = 1, #Vehicles do
                    if GetEntityModel(plyVeh) == Vehicles[i].hash then
                        vehiclePrice = Vehicles[i].price
                        break
                    end
                end
                openShitMenu()
                SetTimeout(100, function()
                    if GetVehicleBodyHealth(plyVeh) < 1000.0 then
                        DisplayMenu(true, "repairMenu")
                    else
                        DisplayMenu(true, "mainMenu")
                    end
                end)
                isPlyInBennys = true
            elseif npcMechanic then
                openShitMenu()
                DisplayMenu(true, "repairMenu")
                isPlyInBennys = true
            end
        end)
    end
end

function openShitMenu()
    local plyPed = PlayerPedId()
    local isMotorcycle = false
    SetVehicleModKit(plyVeh, 0)
    FreezeEntityPosition(plyVeh, true)
    if GetVehicleClass(plyVeh) == 8 then
        isMotorcycle = true
    else
        isMotorcycle = false
    end
    InitiateMenus(isMotorcycle, GetVehicleBodyHealth(plyVeh), location["text"])
    DisplayMenuContainer(true)
    PlaySoundFrontend(-1, "OK", "HUD_FRONTEND_DEFAULT_SOUNDSET", 1)
end

function disableControls()
    DisableControlAction(1, 71, true)
    DisableControlAction(1, 72, true)
    DisableControlAction(1, 34, true)
    DisableControlAction(1, 35, true)
    DisableControlAction(1, 172, true)
    DisableControlAction(1, 173, true)
    DisableControlAction(1, 177, true)
    DisableControlAction(1, 176, true)

    if IsDisabledControlJustReleased(1, 172) then
        MenuScrollFunctionality("up")
        PlaySoundFrontend(-1, "NAV_UP_DOWN", "HUD_FRONTEND_DEFAULT_SOUNDSET", 1)
    end

    if IsDisabledControlJustReleased(1, 173) then
        MenuScrollFunctionality("down")
        PlaySoundFrontend(-1, "NAV_UP_DOWN", "HUD_FRONTEND_DEFAULT_SOUNDSET", 1)
    end

    if IsDisabledControlJustReleased(1, 176) then
        MenuManager(true)
        PlaySoundFrontend(-1, "OK", "HUD_FRONTEND_DEFAULT_SOUNDSET", 1)
    end

    if IsDisabledControlJustReleased(1, 177) then
        MenuManager(false)
        PlaySoundFrontend(-1, "NO", "HUD_FRONTEND_DEFAULT_SOUNDSET", 1)
    end
end

CreateThread(function()
    local inRange = false
    local shown = false
    while true do
        inRange = false
        local time = 1000
        if isPlyInBennys then
            time = 1
            disableControls()
        end

        for k,v in pairs(Locations) do
            local dist = #(GetEntityCoords(PlayerPedId()) - vector3(v["coords"].x, v["coords"].y, v["coords"].z))
            if dist < 15.0 then
                location = Locations[k]
            end
        end

        local pd = location.mechanic == 'police' or false
        local dist = #(GetEntityCoords(PlayerPedId()) - vector3(location["coords"].x, location["coords"].y, location["coords"].z))
        if dist < 5.0 then
            inRange = true
            time = 3
            if IsControlJustPressed(0, 38) and not isPlyInBennys  then
                if pd then
                    local job = thombursa.Functions.GetPlayerData().job.name
                    if job == 'police' then
                        TriggerEvent('jezzy-mekanik:polisjob')

                    end                    else
                    TriggerEvent('mechanicMenu')
                end
            end
        end

        if inRange and not shown then
        	shown = true
            exports["thombursa"]:DrawText("E - Mekanik")
        elseif not inRange and shown then
        	shown = false
            exports["thombursa"]:HideText()
        end

        Wait(time)
    end
end)

RegisterNetEvent("mechanicMenu", function()
    local plyPed = PlayerPedId()
    local job = thombursa.Functions.GetPlayerData().job.name
    if job == location.mechanic then
        if IsPedInAnyVehicle(plyPed, false) and not isPlyInBennys  then
            for k, loc in pairs(Locations) do
                local distance = #(GetEntityCoords(plyPed) - vector3(loc["coords"].x, loc["coords"].y, loc["coords"].z))
                if distance < 10 then
                    plyVeh = GetVehiclePedIsIn(plyPed, false)
                    if GetPedInVehicleSeat(plyVeh, -1) == plyPed then
                        location = loc
                        enterLocation(false, false)
                    end
                end
            end
        end
    end
end)

RegisterNetEvent("np-bennys:purchaseSuccessful")
AddEventHandler("np-bennys:purchaseSuccessful", function()
    isPurchaseSuccessful = true
    attemptingPurchase = false
end)

RegisterNetEvent("np-bennys:purchaseFailed")
AddEventHandler("np-bennys:purchaseFailed", function()
    isPurchaseSuccessful = false
    attemptingPurchase = false
end)

local resetData = false
local mods = {11, 12, 13, 15, 16, 18}
local modsData = {
    ["11"] = 0,
    ["12"] = 0,
    ["13"] = 0,
    ["15"] = 0,
    ["16"] = 0,
    ["18"] = 0
}

function resetModData()
    modsData = {
        ["11"] = 0,
        ["12"] = 0,
        ["13"] = 0,
        ["15"] = 0,
        ["16"] = 0,
        ["18"] = 0
    }
end