--[[
    GZL Atmosphere - Material Response Layer
    Vehicle automotive clearcoat and supermarket interior fixture highlight control.
    Strict license plate protection, distance culling, zero road tampering.
]]--

Materials = {}
Materials.__index = Materials

local isEnabled = false
local vehicleShader = nil
local interiorFixtureShader = nil
local updateTimer = nil

-- Vehicle body textures (protecting license plates and badges)
local VEHICLE_BODY_PATTERNS = {
    "*body*",
    "*paint*",
    "*chassis*"
}

-- Supermarket custom interior fixture textures (controls tile & shelf highlight blowout)
local INTERIOR_FIXTURE_PATTERNS = {
    "drkpoly*",
    "dirtouter*",
    "8bars*"
}

function Materials.init()
    -- Initialized on demand
end

function Materials.start()
    if isEnabled then return end
    isEnabled = true

    -- 1. Vehicle Clearcoat Shader (subtle Fresnel & directional highlight, no fake chrome)
    if fileExists("shaders/vehicle_material.fx") then
        vehicleShader = dxCreateShader("shaders/vehicle_material.fx", 1, 85.0, false, "vehicle")
        if vehicleShader then
            for _, pattern in ipairs(VEHICLE_BODY_PATTERNS) do
                engineApplyShaderToWorldTexture(vehicleShader, pattern)
            end
        end
    end

    -- 2. Supermarket Fixture Tone Shader (prevents tile/shelf overexposure in 24-7)
    if fileExists("shaders/vehicle_material.fx") then
        interiorFixtureShader = dxCreateShader("shaders/vehicle_material.fx", 2, 45.0, false, "world,object")
        if interiorFixtureShader then
            dxSetShaderValue(interiorFixtureShader, "gClearcoatStrength", 0.12)
            for _, pattern in ipairs(INTERIOR_FIXTURE_PATTERNS) do
                engineApplyShaderToWorldTexture(interiorFixtureShader, pattern)
            end
        end
    end

    Materials.updateUniforms()
    updateTimer = setTimer(Materials.updateUniforms, 60, 0)
end

function Materials.stop()
    if not isEnabled then return end
    isEnabled = false

    if isTimer(updateTimer) then
        killTimer(updateTimer)
        updateTimer = nil
    end

    if vehicleShader and isElement(vehicleShader) then
        for _, pattern in ipairs(VEHICLE_BODY_PATTERNS) do
            engineRemoveShaderFromWorldTexture(vehicleShader, pattern)
        end
        destroyElement(vehicleShader)
        vehicleShader = nil
    end

    if interiorFixtureShader and isElement(interiorFixtureShader) then
        for _, pattern in ipairs(INTERIOR_FIXTURE_PATTERNS) do
            engineRemoveShaderFromWorldTexture(interiorFixtureShader, pattern)
        end
        destroyElement(interiorFixtureShader)
        interiorFixtureShader = nil
    end
end

function Materials.updateUniforms()
    if not isEnabled then return end

    local sunDir = Environment and Environment.getSunDirection() or {0.0, 0.707, 0.707}
    local sunCol = Environment and Environment.getSunColor() or {1.0, 0.95, 0.88}
    local ambCol = Environment and Environment.getAmbientColor() or {0.38, 0.40, 0.45}

    if vehicleShader and isElement(vehicleShader) then
        dxSetShaderValue(vehicleShader, "gSunDir", sunDir[1], sunDir[2], sunDir[3])
        dxSetShaderValue(vehicleShader, "gSunColor", sunCol[1], sunCol[2], sunCol[3])
        dxSetShaderValue(vehicleShader, "gAmbientColor", ambCol[1], ambCol[2], ambCol[3])
    end

    if interiorFixtureShader and isElement(interiorFixtureShader) then
        local intFactor = Interior and Interior.getFactor() or 0.0
        dxSetShaderValue(interiorFixtureShader, "gClearcoatStrength", 0.08 + intFactor * 0.08)
        dxSetShaderValue(interiorFixtureShader, "gSunDir", 0.0, 0.0, 1.0)
        dxSetShaderValue(interiorFixtureShader, "gSunColor", 0.95, 0.96, 1.0)
        dxSetShaderValue(interiorFixtureShader, "gAmbientColor", 0.45, 0.46, 0.50)
    end
end
