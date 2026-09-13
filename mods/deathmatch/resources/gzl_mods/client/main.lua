local loadedModels = {}
local vehicleCache = {}
local weaponCache = {}
local plateShader = nil
local plateTexture = nil

local specialAliases = {
    ["rcraider"] = 465,
    ["rcbaron"] = 464,
    ["rcgoblin"] = 501,
    ["rctiger"] = 564,
    ["rcbandit"] = 441,
    ["rccam"] = 594,
    ["copcarla"] = 596,
    ["copcarsf"] = 597,
    ["copcarvg"] = 598,
    ["copcarru"] = 599,
    ["fbiranch"] = 490,
    ["hotrina"] = 502,
    ["hotrinb"] = 503,
    ["bloodra"] = 504,
    ["bagboxa"] = 606,
    ["bagboxb"] = 607,
    ["pagani"] = 411,
    ["huayra"] = 411,
    ["paganihuayra"] = 411
}

local function initializeLookupCaches()
    for id = 400, 611 do
        local vName = getVehicleNameFromModel(id)
        if vName and vName ~= "" then
            local clean = string.lower(string.gsub(vName, "[%s%-_]", ""))
            vehicleCache[clean] = id
            vehicleCache[string.lower(vName)] = id
        end
    end

    for id = 1, 46 do
        local wName = getWeaponNameFromID(id)
        if wName and wName ~= "" then
            local clean = string.lower(string.gsub(wName, "[%s%-_]", ""))
            weaponCache[clean] = id
            weaponCache[string.lower(wName)] = id
        end
    end
end

initializeLookupCaches()

local function setupLicensePlateShader()
    if plateShader then
        return
    end

    if not fileExists("files/plate.fx") or not fileExists("files/plate_tr.png") then
        return
    end

    plateShader = dxCreateShader("files/plate.fx", 0, 0, false, "vehicle")
    if not plateShader then
        plateShader = dxCreateShader("files/plate.fx")
    end

    plateTexture = dxCreateTexture("files/plate_tr.png")

    if plateShader and plateTexture then
        dxSetShaderValue(plateShader, "gTexture", plateTexture)
        engineApplyShaderToWorldTexture(plateShader, "pelak")
        engineApplyShaderToWorldTexture(plateShader, "plateback*")
        engineApplyShaderToWorldTexture(plateShader, "custom_plate*")
        engineApplyShaderToWorldTexture(plateShader, "nUM*")
        engineApplyShaderToWorldTexture(plateShader, "carplate*")
        engineApplyShaderToWorldTexture(plateShader, "license_frame*")
    end
end

local function destroyLicensePlateShader()
    if plateShader then
        engineRemoveShaderFromWorldTexture(plateShader, "pelak")
        engineRemoveShaderFromWorldTexture(plateShader, "plateback*")
        engineRemoveShaderFromWorldTexture(plateShader, "custom_plate*")
        engineRemoveShaderFromWorldTexture(plateShader, "nUM*")
        engineRemoveShaderFromWorldTexture(plateShader, "carplate*")
        engineRemoveShaderFromWorldTexture(plateShader, "license_frame*")
        destroyElement(plateShader)
        plateShader = nil
    end

    if plateTexture then
        destroyElement(plateTexture)
        plateTexture = nil
    end
end

local function resolveModelId(modItem)
    if not modItem or not modItem.model then
        return nil
    end

    local numId = tonumber(modItem.model)
    if numId then
        return numId
    end

    local strName = tostring(modItem.model)
    local directId = getVehicleModelFromName(strName)
    if directId then
        return directId
    end

    local clean = string.lower(string.gsub(strName, "[%s%-_]", ""))
    if specialAliases[clean] then
        return specialAliases[clean]
    end

    if vehicleCache[clean] then
        return vehicleCache[clean]
    end

    local directWeapon = getWeaponIDFromName(strName)
    if directWeapon then
        return directWeapon
    end

    if weaponCache[clean] then
        return weaponCache[clean]
    end

    return nil
end

local function applySingleMod(modItem)
    local modelId = resolveModelId(modItem)
    if not modelId then
        outputChatBox("[GZL-MODS] Gecersiz model: " .. tostring(modItem.model), 255, 100, 100)
        return false
    end

    if modItem.col and fileExists(modItem.col) then
        local colElement = engineLoadCOL(modItem.col)
        if colElement then
            engineReplaceCOL(colElement, modelId)
        end
    end

    if modItem.txd and fileExists(modItem.txd) then
        local txdElement = engineLoadTXD(modItem.txd, true)
        if txdElement then
            engineImportTXD(txdElement, modelId)
        else
            outputChatBox("[GZL-MODS] TXD yuklenemedi: " .. tostring(modItem.txd), 255, 100, 100)
        end
    end

    if modItem.dff and fileExists(modItem.dff) then
        local dffElement = engineLoadDFF(modItem.dff, modelId)
        if not dffElement then
            dffElement = engineLoadDFF(modItem.dff, 0)
        end
        if not dffElement then
            dffElement = engineLoadDFF(modItem.dff)
        end

        if dffElement then
            local alpha = Config.EnableAlphaTransparency or false
            local replaced = engineReplaceModel(dffElement, modelId, alpha)
            if replaced then
                loadedModels[modelId] = true
                outputChatBox(string.format("#38bdf8[GZL-MODS]#ffffff Basariyla yuklendi: #34d399%s #ffffff(ID: #38bdf8%d#ffffff)", tostring(modItem.name or modItem.model), modelId), 255, 255, 255, true)
                return true
            else
                outputChatBox("[GZL-MODS] engineReplaceModel basarisiz: ID " .. tostring(modelId), 255, 100, 100)
            end
        else
            outputChatBox("[GZL-MODS] engineLoadDFF basarisiz: " .. tostring(modItem.dff), 255, 100, 100)
        end
    else
        outputChatBox("[GZL-MODS] DFF bulunamadi: " .. tostring(modItem.dff), 255, 100, 100)
    end

    return false
end

local function restoreAllMods()
    for modelId in pairs(loadedModels) do
        engineRestoreModel(modelId)
        engineRestoreCOL(modelId)
    end
    loadedModels = {}
end

local function startModQueue()
    setupLicensePlateShader()

    if not Config or not Config.Mods then
        return
    end

    for _, item in ipairs(Config.Mods) do
        applySingleMod(item)
    end
end

local function reloadAllMods()
    destroyLicensePlateShader()
    restoreAllMods()
    startModQueue()
end

addEventHandler("onClientResourceStart", resourceRoot, function()
    startModQueue()
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    destroyLicensePlateShader()
    restoreAllMods()
end)

addEvent("gzl_mods:clientReload", true)
addEventHandler("gzl_mods:clientReload", root, function()
    reloadAllMods()
end)

addCommandHandler("reloadmods", function()
    reloadAllMods()
    outputChatBox("[GZL-MODS] Mod listesi yeniden isleniyor...", 100, 200, 255)
end)