
Pipeline = {}
Pipeline.__index = Pipeline

local screenW, screenH = guiGetScreenSize()
local isRunning = false

local screenSource = nil
local tonemapShader = nil

local rtBloomW = math.max(128, math.floor(screenW / 4))
local rtBloomH = math.max(72, math.floor(screenH / 4))
local rtBloomExtract = nil
local rtBloomBlur = nil
local bloomExtractShader = nil
local bloomBlurShader = nil

local rtAOW = math.max(128, math.floor(screenW / 2))
local rtAOH = math.max(72, math.floor(screenH / 2))
local rtAO = nil
local aoShader = nil
local isDepthSupported = false

local TUNING = {
    exposure = 1.00,
    contrast = 1.08,
    saturation = 1.04,
    vibrance = 0.08,
    bloomThreshold = 0.82,
    bloomIntensity = 0.30,
    aoRadius = 0.85,
    aoIntensity = 0.48,
    sharpenStrength = 0.20,
    shadowToe = 0.015
}

local currentExposure = 1.00
local targetExposure = 1.00

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function checkDepthBufferSupport()
    local status = dxGetStatus()
    local format = status.DepthBufferFormat
    local using = status.UsingDepthBuffer == true
    isDepthSupported = using and (format ~= false and format ~= "unknown" and format ~= nil)
    return isDepthSupported
end

function Pipeline.init()
    checkDepthBufferSupport()
end

function Pipeline.start()
    if isRunning then Pipeline.stop() end
    isRunning = true

    Pipeline.createResources()
    addEventHandler("onClientRender", root, Pipeline.onRender, true, "high+1000")
end

function Pipeline.stop()
    if not isRunning then return end
    isRunning = false

    removeEventHandler("onClientRender", root, Pipeline.onRender)
    Pipeline.destroyResources()
end

function Pipeline.createResources()
    local status = dxGetStatus()
    local freeVRAM = status.VideoMemoryFreeForMTA or 512

    if not screenSource or not isElement(screenSource) then
        screenSource = dxCreateScreenSource(screenW, screenH)
    end

    if not tonemapShader or not isElement(tonemapShader) then
        if fileExists("shaders/tonemap.fx") then
            tonemapShader = dxCreateShader("shaders/tonemap.fx")
            if tonemapShader then
                dxSetShaderValue(tonemapShader, "gScreenSize", screenW, screenH)
            end
        end
    end

    if freeVRAM > 32 then
        if not rtBloomExtract or not isElement(rtBloomExtract) then
            rtBloomExtract = dxCreateRenderTarget(rtBloomW, rtBloomH, false)
        end
        if not rtBloomBlur or not isElement(rtBloomBlur) then
            rtBloomBlur = dxCreateRenderTarget(rtBloomW, rtBloomH, false)
        end

        if not bloomExtractShader or not isElement(bloomExtractShader) then
            if fileExists("shaders/bloom_extract.fx") then
                bloomExtractShader = dxCreateShader("shaders/bloom_extract.fx")
            end
        end

        if not bloomBlurShader or not isElement(bloomBlurShader) then
            if fileExists("shaders/bloom_blur.fx") then
                bloomBlurShader = dxCreateShader("shaders/bloom_blur.fx")
                if bloomBlurShader then
                    dxSetShaderValue(bloomBlurShader, "gTexelSize", 1.0 / rtBloomW, 1.0 / rtBloomH)
                end
            end
        end
    end

    if isDepthSupported and freeVRAM > 64 then
        if not rtAO or not isElement(rtAO) then
            rtAO = dxCreateRenderTarget(rtAOW, rtAOH, false)
        end
        if not aoShader or not isElement(aoShader) then
            if fileExists("shaders/contact_ao.fx") then
                aoShader = dxCreateShader("shaders/contact_ao.fx")
                if aoShader then
                    dxSetShaderValue(aoShader, "gScreenSize", rtAOW, rtAOH)
                end
            end
        end
    end
end

function Pipeline.destroyResources()
    if isElement(screenSource) then destroyElement(screenSource); screenSource = nil end
    if isElement(tonemapShader) then destroyElement(tonemapShader); tonemapShader = nil end
    if isElement(rtBloomExtract) then destroyElement(rtBloomExtract); rtBloomExtract = nil end
    if isElement(rtBloomBlur) then destroyElement(rtBloomBlur); rtBloomBlur = nil end
    if isElement(bloomExtractShader) then destroyElement(bloomExtractShader); bloomExtractShader = nil end
    if isElement(bloomBlurShader) then destroyElement(bloomBlurShader); bloomBlurShader = nil end
    if isElement(rtAO) then destroyElement(rtAO); rtAO = nil end
    if isElement(aoShader) then destroyElement(aoShader); aoShader = nil end
end

function Pipeline.onRender()
    if not isRunning or not screenSource or not tonemapShader then return end

    local interiorFactor = Interior and Interior.update() or 0.0

    local hour, minute = getTime()
    local continuousHour = hour + (minute / 60.0)

    if continuousHour >= 10.0 and continuousHour <= 15.0 then
        targetExposure = TUNING.exposure * 0.96 -- Midday sun slightly compressed
    elseif continuousHour >= 18.0 and continuousHour <= 19.5 then
        targetExposure = TUNING.exposure * 1.04 -- Golden hour
    elseif continuousHour >= 21.0 or continuousHour <= 5.0 then
        targetExposure = TUNING.exposure * 1.15 -- Night readable exposure
    else
        targetExposure = TUNING.exposure
    end

    if interiorFactor > 0.01 then
        targetExposure = lerp(targetExposure, TUNING.exposure * 0.92, interiorFactor)
    end

    currentExposure = currentExposure + (targetExposure - currentExposure) * 0.05

    dxUpdateScreenSource(screenSource, true)

    local hasBloom = false
    if rtBloomExtract and rtBloomBlur and bloomExtractShader and bloomBlurShader then
        dxSetRenderTarget(rtBloomExtract, true)
        dxSetShaderValue(bloomExtractShader, "gScreenSource", screenSource)
        dxSetShaderValue(bloomExtractShader, "gBloomThreshold", TUNING.bloomThreshold + interiorFactor * 0.05)
        dxDrawImage(0, 0, rtBloomW, rtBloomH, bloomExtractShader)

        dxSetRenderTarget(rtBloomBlur, true)
        dxSetShaderValue(bloomBlurShader, "gBlurSource", rtBloomExtract)
        dxSetShaderValue(bloomBlurShader, "gDirection", 1.0, 0.0)
        dxDrawImage(0, 0, rtBloomW, rtBloomH, bloomBlurShader)

        dxSetRenderTarget(rtBloomExtract, true)
        dxSetShaderValue(bloomBlurShader, "gBlurSource", rtBloomBlur)
        dxSetShaderValue(bloomBlurShader, "gDirection", 0.0, 1.0)
        dxDrawImage(0, 0, rtBloomW, rtBloomH, bloomBlurShader)

        hasBloom = true
    end

    local hasAO = false
    if isDepthSupported and rtAO and aoShader then
        dxSetRenderTarget(rtAO, true)
        dxSetShaderValue(aoShader, "gAORadius", TUNING.aoRadius)
        dxSetShaderValue(aoShader, "gAOIntensity", TUNING.aoIntensity)
        dxSetShaderValue(aoShader, "gInteriorFactor", interiorFactor)
        dxDrawImage(0, 0, rtAOW, rtAOH, aoShader)
        hasAO = true
    end

    dxSetRenderTarget()

    dxSetShaderValue(tonemapShader, "gScreenSource", screenSource)
    dxSetShaderValue(tonemapShader, "gExposure", currentExposure)
    dxSetShaderValue(tonemapShader, "gContrast", TUNING.contrast)
    dxSetShaderValue(tonemapShader, "gSaturation", TUNING.saturation)
    dxSetShaderValue(tonemapShader, "gVibrance", TUNING.vibrance)
    dxSetShaderValue(tonemapShader, "gShadowToe", TUNING.shadowToe)
    dxSetShaderValue(tonemapShader, "gInteriorFactor", interiorFactor)

    if hasBloom then
        dxSetShaderValue(tonemapShader, "gBloomEnabled", 1.0)
        dxSetShaderValue(tonemapShader, "gBloomTexture", rtBloomExtract)
        dxSetShaderValue(tonemapShader, "gBloomIntensity", TUNING.bloomIntensity * (1.0 - interiorFactor * 0.2))
    else
        dxSetShaderValue(tonemapShader, "gBloomEnabled", 0.0)
    end

    if hasAO then
        dxSetShaderValue(tonemapShader, "gAOEnabled", 1.0)
        dxSetShaderValue(tonemapShader, "gAOTexture", rtAO)
        dxSetShaderValue(tonemapShader, "gAOIntensity", TUNING.aoIntensity)
    else
        dxSetShaderValue(tonemapShader, "gAOEnabled", 0.0)
    end

    dxSetShaderValue(tonemapShader, "gSharpenEnabled", 1.0)
    dxSetShaderValue(tonemapShader, "gSharpenStrength", TUNING.sharpenStrength)

    dxDrawImage(0, 0, screenW, screenH, tonemapShader, 0, 0, 0, tocolor(255, 255, 255, 255), false)
end