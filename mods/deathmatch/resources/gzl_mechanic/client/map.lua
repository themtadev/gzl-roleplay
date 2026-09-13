local allocatedModels = {}
local createdObjects = {}
local mapBlip = nil
local liftObjectElement = nil

function getLiftObject()
    return liftObjectElement
end

local function getModelLODDistance(modelName)
    if modelName == "bext" then
        return 220.0
    elseif modelName == "bshell" then
        return 130.0
    elseif modelName == "lr_pillars" or modelName == "lr_mezzanin" or modelName == "lr_office" then
        return 110.0
    else
        return 75.0
    end
end

local doubleSidedModels = {
    ["lr_grafitib"] = true,
    ["lr_grafside"] = true,
    ["lr_banners1"] = true,
    ["lr_banners2"] = true,
    ["lr_banners3"] = true,
    ["lr_banners4"] = true,
}

local noCollisionModels = {
    ["llframe"] = true,
    ["framewov"] = true,
    ["lamps_von"] = true,
    ["lr_banners1"] = true,
    ["lr_banners2"] = true,
    ["lr_banners3"] = true,
    ["lr_banners4"] = true,
    ["lr_grafitib"] = true,
    ["lr_grafside"] = true,
}

local function loadBennysMap()
    outputDebugString("[Benny's] Harita ve modeller yukleniyor...")

    for _, rem in ipairs(MapData.RemovedObjects) do
        removeWorldModel(rem.model, rem.radius, rem.x, rem.y, rem.z)
        if rem.lod then
            removeWorldModel(rem.lod, rem.radius, rem.x, rem.y, rem.z)
        end
    end

    local txdBennys = engineLoadTXD("models/bennys.txd", true)
    local txdBennys2 = engineLoadTXD("models/bennys2.txd", true)

    if not txdBennys or not txdBennys2 then
        outputDebugString("[Benny's] HATA: TXD dosyalari yuklenemedi!", 1)
        return
    end

    for modelName, info in pairs(MapData.CustomModels) do
        local modelId = engineRequestModel("object")
        if modelId then
            allocatedModels[modelName] = modelId

            if string.find(info.txd, "bennys2", 1, true) then
                engineImportTXD(txdBennys2, modelId)
            else
                engineImportTXD(txdBennys, modelId)
            end

            if fileExists(info.col) then
                local col = engineLoadCOL(info.col)
                if col then
                    engineReplaceCOL(col, modelId)
                end
            end

            if fileExists(info.dff) then
                local dff = engineLoadDFF(info.dff)
                if dff then
                    engineReplaceModel(dff, modelId)
                end
            end

            local lodDist = getModelLODDistance(modelName)
            engineSetModelLODDistance(modelId, lodDist)
        else
            outputDebugString("[Benny's] HATA: " .. tostring(modelName) .. " icin model ID tahsis edilemedi!", 2)
        end
    end

    local placedCount = 0
    for _, entry in ipairs(MapData.PlacedObjects) do
        local modelId = allocatedModels[entry.model]
        if modelId then
            local obj = createObject(modelId, entry.x, entry.y, entry.z, entry.rx, entry.ry, entry.rz)
            if obj then

                local isDoubleSided = doubleSidedModels[entry.model] or false
                setElementDoubleSided(obj, isDoubleSided)

                if noCollisionModels[entry.model] then
                    setElementCollisionsEnabled(obj, false)
                end

                table.insert(createdObjects, obj)
                placedCount = placedCount + 1

                if entry.model == "lr_carlift" then
                    liftObjectElement = obj
                    setElementData(obj, "bennys:isLift", true)
                end
            end
        end
    end

    mapBlip = createBlip(Config.WorkshopCenter.x, Config.WorkshopCenter.y, Config.WorkshopCenter.z, Config.BlipID, 2, 255, 0, 0, 255, 0, 450)
    if mapBlip then
        setElementData(mapBlip, "blipName", Config.MechanicName)
    end

    outputDebugString("[Benny's] Basariyla " .. tostring(placedCount) .. " harita parcasi yerlestirildi!")
end

local function unloadBennysMap()
    if mapBlip and isElement(mapBlip) then
        destroyElement(mapBlip)
        mapBlip = nil
    end

    for _, obj in ipairs(createdObjects) do
        if isElement(obj) then
            destroyElement(obj)
        end
    end
    createdObjects = {}
    liftObjectElement = nil

    for modelName, modelId in pairs(allocatedModels) do
        engineFreeModel(modelId)
    end
    allocatedModels = {}
end

addEventHandler("onClientResourceStart", resourceRoot, loadBennysMap)
addEventHandler("onClientResourceStop", resourceRoot, unloadBennysMap)