
local hideShader = nil
local loadedTextures = {}
local pedShaders = {}
local pedHeadRenderTargets = {}

local function initShaders()
    if not isElement(hideShader) then
        hideShader = dxCreateShader("assets/shaders/alpha_hide.fx", 0, 0, false, "ped")
    end
    return isElement(hideShader)
end

local function getCachedTexture(texturePath)
    if not texturePath then return nil end
    if not loadedTextures[texturePath] then
        if fileExists(texturePath) then
            loadedTextures[texturePath] = dxCreateTexture(texturePath, "argb")
        else
            return nil
        end
    end
    return loadedTextures[texturePath]
end

function resetPedShaders(ped)
    if not isElement(ped) then return end
    if isElement(hideShader) then
        engineRemoveShaderFromWorldTexture(hideShader, "*", ped)
    end
    if pedShaders[ped] then
        for matName, shader in pairs(pedShaders[ped]) do
            if isElement(shader) then
                engineRemoveShaderFromWorldTexture(shader, "*", ped)
                destroyElement(shader)
            end
        end
        pedShaders[ped] = nil
    end
end

local function applyDirectTexture(ped, materialName, tex, tint)
    if not isElement(ped) or not materialName or not isElement(tex) then return false end
    initShaders()

    if not pedShaders[ped] then
        pedShaders[ped] = {}
    end

    local shader = pedShaders[ped][materialName]
    if not isElement(shader) then

        shader = dxCreateShader(tint and "assets/shaders/color_tint.fx" or "assets/shaders/texture_replace.fx", 0, 0, false, "ped")
        if shader then
            pedShaders[ped][materialName] = shader
        else
            outputConsole("[GZL-SHADER ERROR] Failed to create shader for: " .. tostring(materialName))
            return false
        end
    end

    dxSetShaderValue(shader, "gTexture", tex)
    if tint then dxSetShaderValue(shader,"gColor",tint[1],tint[2],tint[3],tint[4] or 1) end
    if isElement(hideShader) then engineRemoveShaderFromWorldTexture(hideShader, materialName, ped) end
    return engineApplyShaderToWorldTexture(shader, materialName, ped)
end

local function applyTexture(ped, materialName, texturePath, tint)
    if not isElement(ped) or not materialName or not texturePath then return false end
    local tex = getCachedTexture(texturePath)
    if not isElement(tex) then return false end
    return applyDirectTexture(ped, materialName, tex, tint)
end

local function hideMaterial(ped, materialName)
    if not isElement(ped) or not materialName then return end
    initShaders()
    if isElement(hideShader) then
        engineApplyShaderToWorldTexture(hideShader, materialName, ped)
    end
end

local function getCompositedHeadTexture(ped, gender, tone, faceData)
    if not isElement(ped) then return nil end
    faceData = faceData or {}
    local eyesIdx = tonumber(faceData.eyes) or 1
    local eyebrowIdx = tonumber(faceData.eyebrow) or 1
    local beardIdx = tonumber(faceData.beard) or 0
    local lipstickIdx = tonumber(faceData.lipstick) or 0

    local genderFolder = (gender == "female") and "female" or "male"
    local baseHeadPath = (gender == "female")
        and ("assets/textures/female/bodytextures/" .. tostring(tone) .. "/2.png")
        or ("assets/textures/male/bodytextures/" .. tostring(tone) .. "/4.png")

    local baseTex = getCachedTexture(baseHeadPath)
    local eyesTex = getCachedTexture("assets/textures/" .. genderFolder .. "/facetextures/eyes/" .. tostring(eyesIdx) .. ".png")
    local eyebrowTex = getCachedTexture("assets/textures/" .. genderFolder .. "/facetextures/eyebrow/" .. tostring(eyebrowIdx) .. ".png")

    local beardTex = nil
    if gender == "male" and beardIdx > 0 then
        beardTex = getCachedTexture("assets/textures/male/facetextures/beard/" .. tostring(beardIdx) .. ".png")
    end

    local lipstickTex = nil
    if gender == "female" and lipstickIdx > 0 then
        lipstickTex = getCachedTexture("assets/textures/female/facetextures/lipstick/" .. tostring(lipstickIdx) .. ".png")
    end

    local rt = pedHeadRenderTargets[ped]
    if not isElement(rt) then
        rt = dxCreateRenderTarget(512, 512, false)
        if not rt then
            return baseTex
        end
        pedHeadRenderTargets[ped] = rt
    end

    dxSetRenderTarget(rt, true)
    dxSetBlendMode("blend")
    if isElement(baseTex) then dxDrawImage(0, 0, 512, 512, baseTex) end
    if isElement(eyesTex) then dxDrawImage(0, 0, 512, 512, eyesTex) end
    if isElement(eyebrowTex) then dxDrawImage(0, 0, 512, 512, eyebrowTex) end
    if isElement(beardTex) then dxDrawImage(0, 0, 512, 512, beardTex) end
    if isElement(lipstickTex) then dxDrawImage(0, 0, 512, 512, lipstickTex) end
    dxSetRenderTarget()
    dxSetBlendMode("blend")

    return rt
end

function applyCharacterCustomization(ped, data)
    if not isElement(ped) or type(data) ~= "table" then return false end
    if data[1] and type(data[1]) == "table" then
        data = data[1]
    end
    initShaders()

    local gender = data.gender or "male"
    local genderFolder = gender == "female" and "female" or "male"
    local cfg = resolveCreatorConfig(data)
    if not applyCreatorOutfitModel(ped,data) then return false end
    if getCreatorOutfit(data) then
        data.accessories=data.accessories or {}
        for key,item in pairs(cfg.accessories) do if data.accessories[key]==nil then data.accessories[key]=item.default or false end end
    end

    resetPedShaders(ped)
    for _,material in ipairs(engineGetModelTextureNames(getElementModel(ped)) or {}) do hideMaterial(ped,material) end

    local hiddenParts = {}

    local torsoIdx = tonumber(data.torso or 1)
    local torsoItem = cfg.torso[torsoIdx] or cfg.torso[1]
    if torsoItem and torsoItem.hide_body then
        for _, part in ipairs(torsoItem.hide_body) do
            hiddenParts[part] = true
        end
    end

    local legsIdx = tonumber(data.legs or 1)
    local legsItem = cfg.legs[legsIdx] or cfg.legs[1]
    if legsItem and legsItem.hide_body then
        for _, part in ipairs(legsItem.hide_body) do
            hiddenParts[part] = true
        end
    end

    local shoesIdx = tonumber(data.shoes or 1)
    local shoesItem = cfg.shoes[shoesIdx] or cfg.shoes[1]
    if shoesItem and shoesItem.hide_feet then
        hiddenParts["body.feet"] = true
        if gender == "male" then hiddenParts["body.heel"] = true end
        if gender == "female" then hiddenParts["body.tornozelo"] = true end
    end

    local tone = tostring(data.skinTone or 1)
    local headTex = getCompositedHeadTexture(ped, gender, tone, data.face)
    if isElement(headTex) then
        applyDirectTexture(ped, "body.head", headTex)
    else
        if gender == "male" then
            applyTexture(ped, "body.head", "assets/textures/male/bodytextures/" .. tone .. "/4.png")
        else
            applyTexture(ped, "body.head", "assets/textures/female/bodytextures/" .. tone .. "/2.png")
        end
    end

    if gender == "male" then
        local bodyPath = "assets/textures/male/bodytextures/" .. tone .. "/"
        local t1 = bodyPath .. "1.png"
        local t2 = bodyPath .. "2.png"
        local t3 = bodyPath .. "3.png"

        if not hiddenParts["body.torso"] then applyTexture(ped, "body.torso", t1) end
        if not hiddenParts["body.meio"] then applyTexture(ped, "body.meio", t1) end
        if not hiddenParts["body.arm1"] then applyTexture(ped, "body.arm1", t1) end
        if not hiddenParts["body.arm2"] then applyTexture(ped, "body.arm2", t1) end
        if not hiddenParts["body.hands1"] then applyTexture(ped, "body.hands1", t1) end
        if not hiddenParts["body.hands2"] then applyTexture(ped, "body.hands2", t1) end
        if not hiddenParts["body.legs1"] then applyTexture(ped, "body.legs1", t2) end
        if not hiddenParts["body.legs2"] then applyTexture(ped, "body.legs2", t2) end
        if not hiddenParts["body.coxa"] then applyTexture(ped, "body.coxa", t2) end
        if not hiddenParts["body.feet"] then applyTexture(ped, "body.feet", t3) end
        if not hiddenParts["body.heel"] then applyTexture(ped, "body.heel", t3) end
        if not hiddenParts["body.cueca"] then applyTexture(ped, "body.cueca", "assets/textures/male/body.cueca/1.png") end
    else
        local bodyPath = "assets/textures/female/bodytextures/" .. tone .. "/"
        local t1 = bodyPath .. "1.png"
        local t3 = bodyPath .. "3.png"

        if not hiddenParts["body.torso"] then applyTexture(ped, "body.torso", t1) end
        if not hiddenParts["body.arm"] then applyTexture(ped, "body.arm", t1) end
        if not hiddenParts["body.hands"] then applyTexture(ped, "body.hands", t1) end
        if not hiddenParts["body.biquinicima"] then applyTexture(ped, "body.biquinicima", t1) end
        if not hiddenParts["body.legs"] then applyTexture(ped, "body.legs", t3) end
        if not hiddenParts["body.biquinibaixo"] then applyTexture(ped, "body.biquinibaixo", t3) end
        if not hiddenParts["body.tornozelo"] then applyTexture(ped, "body.tornozelo", t3) end
        if not hiddenParts["body.feet"] then applyTexture(ped, "body.feet", t3) end
    end

    for partName, _ in pairs(hiddenParts) do
        hideMaterial(ped, partName)
    end

    local hairIdx = tonumber(data.hair and data.hair.id)
    if hairIdx == nil then hairIdx = 1 end
    local hairItem = cfg.hairs[hairIdx]
    if hairItem and hairItem.tex then
        local hairVariantNum = tostring(data.hairVariant or (data.hair and data.hair.variant) or 1)
        local hairTexPath = "assets/textures/" .. genderFolder .. "/" .. hairItem.tex .. "/" .. hairVariantNum .. ".png"
        if not fileExists(hairTexPath) then
            hairTexPath = "assets/textures/" .. genderFolder .. "/" .. hairItem.tex .. "/1.png"
        end
        local color=CreatorConfig.HairColors[tonumber(data.hairColorIdx) or 1]
        applyTexture(ped, hairItem.tex, hairTexPath, color and color.color or (data.hair and data.hair.color))
    end

    if torsoItem and torsoItem.tex then
        local vNum = tostring(data.torsoVariant or 1)
        local torsoTexPath = "assets/textures/" .. genderFolder .. "/" .. torsoItem.tex .. "/" .. vNum .. ".png"
        if not fileExists(torsoTexPath) then
            torsoTexPath = "assets/textures/" .. genderFolder .. "/" .. torsoItem.tex .. "/1.png"
        end
        applyTexture(ped, torsoItem.tex, torsoTexPath)
    end

    if legsItem and legsItem.tex then
        local vNum = tostring(data.legsVariant or 1)
        local legsTexPath = "assets/textures/" .. genderFolder .. "/" .. legsItem.tex .. "/" .. vNum .. ".png"
        if not fileExists(legsTexPath) then
            legsTexPath = "assets/textures/" .. genderFolder .. "/" .. legsItem.tex .. "/1.png"
        end
        applyTexture(ped, legsItem.tex, legsTexPath)
    end

    if shoesItem and shoesItem.tex then
        local vNum = tostring(data.shoesVariant or 1)
        local shoesTexPath = "assets/textures/" .. genderFolder .. "/" .. shoesItem.tex .. "/" .. vNum .. ".png"
        if not fileExists(shoesTexPath) then
            shoesTexPath = "assets/textures/" .. genderFolder .. "/" .. shoesItem.tex .. "/1.png"
        end
        applyTexture(ped, shoesItem.tex, shoesTexPath)
    end

    local outfit=getCreatorOutfit(data)
    if outfit then
        for material,files in pairs(outfit.materials) do
            local variant=1
            for _,slot in ipairs({'torso','legs','shoes'}) do
                local item=cfg[slot][1]
                for _,name in ipairs(item.imported_materials or {}) do
                    if name==material then variant=tonumber(data[slot..'Variant']) or 1 end
                end
            end
            local visible=true
            for key,item in pairs(cfg.accessories) do
                for _,name in ipairs(item.imported_materials or {}) do
                    if name==material then
                        visible=data.accessories[key]==true
                        variant=tonumber(data.accessoryVariants and data.accessoryVariants[key]) or 1
                    end
                end
            end
            if visible then applyTexture(ped,material,files[variant] or files[1]) end
        end
    end

    if type(data.accessories) == "table" then
        for accKey, active in pairs(data.accessories) do
            if active and cfg.accessories[accKey] and cfg.accessories[accKey].tex then
                local accTexPath = "assets/textures/" .. genderFolder .. "/" .. cfg.accessories[accKey].tex .. "/1.png"
                applyTexture(ped, cfg.accessories[accKey].tex, accTexPath)
            end
        end
    end

    for key,item in pairs(cfg.accessories) do
        if item.hide_hair and data.accessories and data.accessories[key] then
            for _,hair in pairs(cfg.hairs) do if hair.tex then hideMaterial(ped,hair.tex) end end
        end
    end
    return true
end

addEventHandler("onClientResourceStart", resourceRoot, function()
    initShaders()
    local myData = getElementData(localPlayer, "char:customization")
    if myData then
        applyCharacterCustomization(localPlayer, myData)
    end
    for _, p in ipairs(getElementsByType("player")) do
        if p ~= localPlayer then
            local pData = getElementData(p, "char:customization")
            if pData then
                applyCharacterCustomization(p, pData)
            end
        end
    end
end)

addEventHandler("onClientElementStreamIn", root, function()
    if getElementType(source) == "player" or getElementType(source) == "ped" then
        removeFromRestoreQueue(source)
        local cdata = getElementData(source, "char:customization")
        if cdata then
            applyCharacterCustomization(source, cdata)
        end
    end
end)

local restoreQueue = {}
local restoreTimer = nil

local function clearRestoreQueue()
    if isTimer(restoreTimer) then
        killTimer(restoreTimer)
        restoreTimer = nil
    end
    restoreQueue = {}
end

local function removeFromRestoreQueue(elem)
    if #restoreQueue == 0 then return end
    for i = #restoreQueue, 1, -1 do
        if restoreQueue[i] == elem then
            table.remove(restoreQueue, i)
        end
    end
    if #restoreQueue == 0 and isTimer(restoreTimer) then
        killTimer(restoreTimer)
        restoreTimer = nil
    end
end

local function processRestoreQueue()
    while #restoreQueue > 0 do
        local p = table.remove(restoreQueue, 1)
        if isElement(p) and isElementStreamedIn(p) then
            local pData = getElementData(p, "char:customization")
            if pData then
                applyCharacterCustomization(p, pData)
                break
            end
        end
    end

    if #restoreQueue == 0 and isTimer(restoreTimer) then
        killTimer(restoreTimer)
        restoreTimer = nil
    end
end

addEventHandler("onClientElementStreamOut", root, function()
    removeFromRestoreQueue(source)
    if getElementType(source) == "player" or getElementType(source) == "ped" then
        resetPedShaders(source)
        if isElement(pedHeadRenderTargets[source]) then
            destroyElement(pedHeadRenderTargets[source])
            pedHeadRenderTargets[source] = nil
        end
    end
end)

addEventHandler("onClientElementDestroy", root, function()
    removeFromRestoreQueue(source)
    resetPedShaders(source)
    if isElement(pedHeadRenderTargets[source]) then
        destroyElement(pedHeadRenderTargets[source])
        pedHeadRenderTargets[source] = nil
    end
end)

addEventHandler("onClientPlayerQuit", root, function()
    removeFromRestoreQueue(source)
end)

addEventHandler("onClientElementDataChange", root, function(dataName)
    if dataName == "char:customization" then
        removeFromRestoreQueue(source)
        local cdata = getElementData(source, "char:customization")
        if cdata then
            applyCharacterCustomization(source, cdata)
        else
            resetPedShaders(source)
            if isElement(pedHeadRenderTargets[source]) then
                destroyElement(pedHeadRenderTargets[source])
                pedHeadRenderTargets[source] = nil
            end
        end
    end
end)

addEventHandler("onClientRestore", root, function()
    clearRestoreQueue()

    for ped, rt in pairs(pedHeadRenderTargets) do
        if isElement(rt) then destroyElement(rt) end
    end
    pedHeadRenderTargets = {}

    local myData = getElementData(localPlayer, "char:customization")
    if myData then
        applyCharacterCustomization(localPlayer, myData)
    end

    local seen = { [localPlayer] = true }
    for _, p in ipairs(getElementsByType("player")) do
        if not seen[p] and isElementStreamedIn(p) then
            seen[p] = true
            local pData = getElementData(p, "char:customization")
            if pData then
                table.insert(restoreQueue, p)
            end
        end
    end
    for _, p in ipairs(getElementsByType("ped")) do
        if not seen[p] and isElementStreamedIn(p) then
            seen[p] = true
            local pData = getElementData(p, "char:customization")
            if pData then
                table.insert(restoreQueue, p)
            end
        end
    end

    if #restoreQueue > 0 then
        restoreTimer = setTimer(processRestoreQueue, 50, 0)
    end
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    clearRestoreQueue()
    if isElement(hideShader) then destroyElement(hideShader) end
    for _, tex in pairs(loadedTextures) do
        if isElement(tex) then destroyElement(tex) end
    end
    for ped, list in pairs(pedShaders) do
        for _, shader in pairs(list) do
            if isElement(shader) then destroyElement(shader) end
        end
    end
    for ped, rt in pairs(pedHeadRenderTargets) do
        if isElement(rt) then destroyElement(rt) end
    end
    loadedTextures = {}
    pedShaders = {}
    pedHeadRenderTargets = {}
end)