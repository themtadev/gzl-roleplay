local studioPed = nil
local isStudioActive = false
local pedRotation = 180
local isDraggingPed = false
local lastDragX = 0

local hudComponents = {"all", "radar", "area_name", "vehicle_name", "breath", "clock", "money", "health", "armour", "weapon", "ammo"}

local function applyStudioAnimation(gender)
    if isElement(studioPed) then
        setTimer(function()
            if isElement(studioPed) then
                if gender == 2 then
                    setPedAnimation(studioPed, "ped", "woman_lean_loop", -1, true, false, false, false)
                else
                    setPedAnimation(studioPed, "dealer", "dealer_idle", -1, true, false, false, false)
                end
            end
        end, 60, 1)
    end
end

function startCharacterStudio(initialSkin, gender, customizationRaw)
    if isStudioActive then
        if initialSkin then
            updateStudioPedSkin(initialSkin, gender, customizationRaw)
        else
            hideStudioPed()
        end
        return
    end
    isStudioActive = true

    local cfg = CharConfig.Studio

    setTime(cfg.time[1], cfg.time[2])
    setMinuteDuration(60000)
    setWeather(cfg.weather)

    for _, comp in ipairs(hudComponents) do
        setPlayerHudComponentVisible(comp, false)
    end

    fadeCamera(true, 1.0)
    setCameraInterior(cfg.ped.interior)
    setElementInterior(localPlayer, cfg.ped.interior)
    setCameraMatrix(cfg.camera.cx, cfg.camera.cy, cfg.camera.cz, cfg.camera.tx, cfg.camera.ty, cfg.camera.tz)

    if initialSkin then
        updateStudioPedSkin(initialSkin, gender, customizationRaw)
    else
        hideStudioPed()
    end
end

function updateStudioPedSkin(skinId, gender, customizationRaw)
    local cfg = CharConfig.Studio
    local customData = nil
    if type(customizationRaw) == "string" and customizationRaw ~= "" and customizationRaw ~= "{}" then
        customData = fromJSON(customizationRaw)
    elseif type(customizationRaw) == "table" then
        customData = customizationRaw
    end

    if customData and type(customData) == "table" and customData[1] and type(customData[1]) == "table" then
        customData = customData[1]
    end

    local modelToSet = tonumber(skinId) or 0
    if customData and type(customData) == "table" then
        modelToSet = (gender == 2 or customData.gender == "female") and 171 or 170
    end

    if not isElement(studioPed) then
        pedRotation = cfg.ped.rot
        studioPed = createPed(modelToSet, cfg.ped.x, cfg.ped.y, cfg.ped.z, pedRotation)
        if isElement(studioPed) then
            setElementInterior(studioPed, cfg.ped.interior)
            setElementDimension(studioPed, getElementDimension(localPlayer))
            setElementFrozen(studioPed, true)
            applyStudioAnimation(gender)
        end
    else
        setElementModel(studioPed, modelToSet)
        setElementPosition(studioPed, cfg.ped.x, cfg.ped.y, cfg.ped.z)
        applyStudioAnimation(gender)
    end

    if isElement(studioPed) then
        if customData and type(customData) == "table" and exports.gzl_creator and exports.gzl_creator.applyCharacterCustomization then
            exports.gzl_creator:applyCharacterCustomization(studioPed, customData)
        elseif exports.gzl_creator and exports.gzl_creator.resetPedShaders then
            exports.gzl_creator:resetPedShaders(studioPed)
        end
    end
end

function hideStudioPed()
    if isElement(studioPed) then
        if exports.gzl_creator and exports.gzl_creator.resetPedShaders then
            exports.gzl_creator:resetPedShaders(studioPed)
        end
        destroyElement(studioPed)
        studioPed = nil
    end
end

function stopCharacterStudio()
    isStudioActive = false
    isDraggingPed = false
    -- Restore the world before optional shader cleanup can fail.
    setCameraTarget(localPlayer)
    setCameraInterior(getElementInterior(localPlayer))
    hideStudioPed()
end

addEventHandler("onClientClick", root, function(button, state, absX, absY)
    if not isStudioActive or not isElement(studioPed) then return end
    if button == "left" then
        if state == "down" then
            local sw, sh = guiGetScreenSize()
            if absX > (sw * 0.35) and absX < (sw * 0.85) then
                isDraggingPed = true
                lastDragX = absX
            end
        else
            isDraggingPed = false
        end
    end
end)

addEventHandler("onClientCursorMove", root, function(cx, cy, absX, absY)
    if not isStudioActive or not isDraggingPed or not isElement(studioPed) then return end
    local deltaX = absX - lastDragX
    lastDragX = absX
    pedRotation = (pedRotation - deltaX * 0.75) % 360
    setElementRotation(studioPed, 0, 0, pedRotation)
end)