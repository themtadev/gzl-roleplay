local plateShaders = {}
local plateTextures = {}

local shaderRaw = [[
    texture gTexture;
    technique PlateRep {
        pass P0 {
            Texture[0] = gTexture;
        }
    }
]]

local function redrawPlateRenderTarget(plateText, rt)
    if not isElement(rt) then return end
    dxSetRenderTarget(rt, true)
    dxDrawRectangle(0, 0, 512, 128, tocolor(24, 24, 27, 255))
    dxDrawRectangle(4, 4, 504, 120, tocolor(250, 250, 250, 255))

    dxDrawRectangle(4, 4, 68, 120, tocolor(0, 51, 153, 255))
    dxDrawText("TR", 4, 62, 72, 120, tocolor(255, 255, 255, 255), 2.2, "default-bold", "center", "center")

    dxDrawText(plateText, 80, 4, 508, 124, tocolor(15, 23, 42, 255), 3.4, "default-bold", "center", "center")
    dxSetRenderTarget()
end

local function createPlateRenderTarget(plateText)
    if not plateText or plateText == "" then
        plateText = "16 GZL 16"
    end

    if plateTextures[plateText] and isElement(plateTextures[plateText]) then
        return plateTextures[plateText]
    end

    local rt = dxCreateRenderTarget(512, 128, false)
    if not rt then return nil end

    redrawPlateRenderTarget(plateText, rt)

    plateTextures[plateText] = rt
    return rt
end

local targetTextureNames = {
    "pelak",
    "*plate*",
    "plateback*",
    "custom_car_plate",
    "nomer*",
    "licence*",
    "license*"
}

local function applyPlateToVehicle(veh)
    if not isElement(veh) then return end

    local plateText = getElementData(veh, "taxi:plate") or getElementData(veh, "veh:plate") or getVehiclePlateText(veh)
    if not plateText or plateText == "" then return end

    local rt = createPlateRenderTarget(plateText)
    if not rt then return end

    if not plateShaders[veh] or not isElement(plateShaders[veh]) then
        plateShaders[veh] = dxCreateShader(shaderRaw)
    end

    local sh = plateShaders[veh]
    if sh then
        dxSetShaderValue(sh, "gTexture", rt)
        for _, texName in ipairs(targetTextureNames) do
            engineApplyShaderToWorldTexture(sh, texName, veh)
        end
    end
end

local function removePlateFromVehicle(veh)
    if plateShaders[veh] then
        if isElement(plateShaders[veh]) then
            destroyElement(plateShaders[veh])
        end
        plateShaders[veh] = nil
    end
end

addEventHandler("onClientElementStreamIn", root, function()
    if getElementType(source) == "vehicle" then
        applyPlateToVehicle(source)
    end
end)

addEventHandler("onClientElementStreamOut", root, function()
    if getElementType(source) == "vehicle" then
        removePlateFromVehicle(source)
    end
end)

addEventHandler("onClientElementDestroy", root, function()
    if getElementType(source) == "vehicle" then
        removePlateFromVehicle(source)
    end
end)

addEventHandler("onClientElementDataChange", root, function(key, oldVal, newVal)
    if getElementType(source) == "vehicle" then
        if key == "veh:plate" or key == "taxi:plate" then
            applyPlateToVehicle(source)
        end
    end
end)

addEventHandler("onClientResourceStart", resourceRoot, function()
    for _, v in ipairs(getElementsByType("vehicle")) do
        if isElementStreamedIn(v) then
            applyPlateToVehicle(v)
        end
    end
end)

addEventHandler("onClientRestore", root, function(didClearRenderTargets)
    if didClearRenderTargets then
        setTimer(function()
            for plateText, rt in pairs(plateTextures) do
                if isElement(rt) then
                    redrawPlateRenderTarget(plateText, rt)
                end
            end
            for _, v in ipairs(getElementsByType("vehicle")) do
                if isElementStreamedIn(v) then
                    applyPlateToVehicle(v)
                end
            end
        end, 100, 1)
    end
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    for v, sh in pairs(plateShaders) do
        if isElement(sh) then
            destroyElement(sh)
        end
    end
    for _, rt in pairs(plateTextures) do
        if isElement(rt) then
            destroyElement(rt)
        end
    end
    plateShaders = {}
    plateTextures = {}
end)