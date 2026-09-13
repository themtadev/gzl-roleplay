
Environment = {}
Environment.__index = Environment

local isEnabled = false
local updateTimer = nil

local currentSunDir = {0.0, 0.707, 0.707}
local currentSunColor = {1.0, 0.95, 0.88}
local currentAmbientColor = {0.38, 0.40, 0.45}

local CURVES = {
    {
        time = 0.0, -- Midnight
        skyTop = {6, 10, 20},
        skyBot = {14, 18, 30},
        sunCore = {0, 0, 0},
        sunCorona = {0, 0, 0},
        sunSize = 0.0,
        moonSize = 2.8,
        ambientWorld = {22, 26, 36},
        ambientDynamic = {30, 34, 46},
        dirColor = {24, 28, 42},
        illumination = 0.30,
        shadowStrength = 65,
        poleShadow = 45,
        spriteBrightness = 1.65,
        spriteSize = 0.85,
        lightsOnGround = 1.30,
        fogDist = 85.0,
        farClip = 1100.0,
        waterColor = {10, 16, 26, 200}
    },
    {
        time = 4.5, -- Late Night / Pre-dawn
        skyTop = {8, 12, 24},
        skyBot = {18, 22, 36},
        sunCore = {0, 0, 0},
        sunCorona = {0, 0, 0},
        sunSize = 0.0,
        moonSize = 2.4,
        ambientWorld = {24, 28, 38},
        ambientDynamic = {32, 36, 48},
        dirColor = {26, 30, 44},
        illumination = 0.32,
        shadowStrength = 70,
        poleShadow = 50,
        spriteBrightness = 1.60,
        spriteSize = 0.85,
        lightsOnGround = 1.25,
        fogDist = 80.0,
        farClip = 1100.0,
        waterColor = {12, 18, 28, 200}
    },
    {
        time = 5.6, -- Astronomical Dawn
        skyTop = {25, 40, 75},
        skyBot = {85, 55, 60},
        sunCore = {180, 90, 40},
        sunCorona = {140, 60, 30},
        sunSize = 0.8,
        moonSize = 1.2,
        ambientWorld = {42, 48, 62},
        ambientDynamic = {50, 56, 72},
        dirColor = {110, 75, 55},
        illumination = 0.55,
        shadowStrength = 95,
        poleShadow = 75,
        spriteBrightness = 1.35,
        spriteSize = 0.80,
        lightsOnGround = 1.00,
        fogDist = 75.0,
        farClip = 1200.0,
        waterColor = {18, 28, 42, 210}
    },
    {
        time = 6.6, -- Sunrise (Cool environment + restrained warm directional)
        skyTop = {45, 80, 140},
        skyBot = {180, 130, 95},
        sunCore = {255, 185, 110},
        sunCorona = {255, 140, 65},
        sunSize = 1.6,
        moonSize = 0.0,
        ambientWorld = {68, 76, 94},
        ambientDynamic = {78, 86, 106},
        dirColor = {200, 150, 105},
        illumination = 0.95,
        shadowStrength = 135,
        poleShadow = 100,
        spriteBrightness = 0.85,
        spriteSize = 0.70,
        lightsOnGround = 0.70,
        fogDist = 95.0,
        farClip = 1300.0,
        waterColor = {28, 45, 65, 215}
    },
    {
        time = 8.5, -- Morning (Crisp natural daylight clearing)
        skyTop = {65, 120, 195},
        skyBot = {160, 185, 215},
        sunCore = {255, 240, 215},
        sunCorona = {255, 220, 180},
        sunSize = 1.8,
        moonSize = 0.0,
        ambientWorld = {95, 102, 114},
        ambientDynamic = {105, 112, 126},
        dirColor = {225, 215, 195},
        illumination = 1.15,
        shadowStrength = 150,
        poleShadow = 120,
        spriteBrightness = 0.55,
        spriteSize = 0.60,
        lightsOnGround = 0.45,
        fogDist = 125.0,
        farClip = 1400.0,
        waterColor = {35, 60, 85, 220}
    },
    {
        time = 12.0, -- Midday (Neutral daylight, clean whites, controlled highlights)
        skyTop = {60, 125, 210},
        skyBot = {165, 198, 225},
        sunCore = {255, 252, 245},
        sunCorona = {255, 246, 230},
        sunSize = 2.0,
        moonSize = 0.0,
        ambientWorld = {112, 116, 126},
        ambientDynamic = {122, 128, 138},
        dirColor = {240, 236, 228},
        illumination = 1.25,
        shadowStrength = 155,
        poleShadow = 130,
        spriteBrightness = 0.40,
        spriteSize = 0.55,
        lightsOnGround = 0.30,
        fogDist = 135.0,
        farClip = 1500.0,
        waterColor = {40, 70, 95, 225}
    },
    {
        time = 15.5, -- Afternoon
        skyTop = {62, 122, 202},
        skyBot = {170, 192, 218},
        sunCore = {255, 248, 235},
        sunCorona = {255, 238, 210},
        sunSize = 1.9,
        moonSize = 0.0,
        ambientWorld = {108, 112, 122},
        ambientDynamic = {118, 124, 134},
        dirColor = {235, 228, 212},
        illumination = 1.20,
        shadowStrength = 152,
        poleShadow = 125,
        spriteBrightness = 0.45,
        spriteSize = 0.58,
        lightsOnGround = 0.35,
        fogDist = 130.0,
        farClip = 1450.0,
        waterColor = {38, 66, 90, 220}
    },
    {
        time = 17.5, -- Golden Hour Start
        skyTop = {50, 95, 170},
        skyBot = {205, 155, 105},
        sunCore = {255, 210, 130},
        sunCorona = {255, 170, 80},
        sunSize = 1.8,
        moonSize = 0.0,
        ambientWorld = {85, 88, 102},
        ambientDynamic = {95, 98, 114},
        dirColor = {230, 175, 115},
        illumination = 1.15,
        shadowStrength = 150,
        poleShadow = 120,
        spriteBrightness = 0.65,
        spriteSize = 0.65,
        lightsOnGround = 0.55,
        fogDist = 115.0,
        farClip = 1380.0,
        waterColor = {35, 58, 80, 215}
    },
    {
        time = 18.7, -- Golden Hour Peak (Warm directional WITHOUT turning scene orange)
        skyTop = {38, 68, 135},
        skyBot = {215, 135, 75},
        sunCore = {255, 175, 85},
        sunCorona = {255, 125, 45},
        sunSize = 1.6,
        moonSize = 0.4,
        ambientWorld = {66, 68, 85}, -- Ambient stays cool-slate so shadows are never orange
        ambientDynamic = {76, 78, 98},
        dirColor = {225, 145, 80},   -- Warmth is strictly directional on sun facets
        illumination = 1.05,
        shadowStrength = 145,
        poleShadow = 110,
        spriteBrightness = 0.95,
        spriteSize = 0.72,
        lightsOnGround = 0.85,
        fogDist = 100.0,
        farClip = 1300.0,
        waterColor = {28, 48, 70, 215}
    },
    {
        time = 19.8, -- Blue Hour / Dusk (Decreasing directional, cool twilight ambient)
        skyTop = {18, 30, 68},
        skyBot = {65, 48, 75},
        sunCore = {120, 50, 20},
        sunCorona = {90, 35, 15},
        sunSize = 0.6,
        moonSize = 1.8,
        ambientWorld = {38, 42, 58},
        ambientDynamic = {46, 50, 68},
        dirColor = {75, 60, 75},
        illumination = 0.45,
        shadowStrength = 85,
        poleShadow = 65,
        spriteBrightness = 1.45,
        spriteSize = 0.82,
        lightsOnGround = 1.15,
        fogDist = 85.0,
        farClip = 1200.0,
        waterColor = {18, 28, 45, 205}
    },
    {
        time = 21.2, -- Night Settling
        skyTop = {8, 14, 28},
        skyBot = {20, 24, 40},
        sunCore = {0, 0, 0},
        sunCorona = {0, 0, 0},
        sunSize = 0.0,
        moonSize = 2.6,
        ambientWorld = {26, 30, 42},
        ambientDynamic = {34, 38, 52},
        dirColor = {30, 36, 52},
        illumination = 0.35,
        shadowStrength = 70,
        poleShadow = 50,
        spriteBrightness = 1.65,
        spriteSize = 0.85,
        lightsOnGround = 1.30,
        fogDist = 85.0,
        farClip = 1150.0,
        waterColor = {12, 18, 30, 200}
    },
    {
        time = 23.0, -- Deep Night
        skyTop = {6, 10, 22},
        skyBot = {14, 18, 32},
        sunCore = {0, 0, 0},
        sunCorona = {0, 0, 0},
        sunSize = 0.0,
        moonSize = 2.8,
        ambientWorld = {22, 26, 36},
        ambientDynamic = {30, 34, 46},
        dirColor = {24, 28, 42},
        illumination = 0.30,
        shadowStrength = 65,
        poleShadow = 45,
        spriteBrightness = 1.65,
        spriteSize = 0.85,
        lightsOnGround = 1.30,
        fogDist = 85.0,
        farClip = 1100.0,
        waterColor = {10, 16, 26, 200}
    }
}

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function lerpColor(c1, c2, t)
    return {
        math.floor(lerp(c1[1], c2[1], t) + 0.5),
        math.floor(lerp(c1[2], c2[2], t) + 0.5),
        math.floor(lerp(c1[3], c2[3], t) + 0.5)
    }
end

local function smoothstep(t)
    return t * t * (3.0 - 2.0 * t)
end

local function calculateSunDirection(t)
    local solarHour = (t - 6.0) % 24.0
    local solarAngle = (solarHour / 12.0) * math.pi

    local elevation = math.sin(solarAngle)
    local azimuth = math.cos(solarAngle)

    local x = azimuth
    local y = 0.35
    local z = math.max(elevation, -0.2)

    local len = math.sqrt(x*x + y*y + z*z)
    if len > 0.001 then
        return {x / len, y / len, z / len}
    end
    return {0.0, 0.707, 0.707}
end

function Environment.init()
    pcall(setVolumetricShadowsEnabled, true)
    pcall(setBlurLevel, 0)
    pcall(setHeatHaze, 0)
    pcall(setOcclusionsEnabled, true)
    pcall(setCloudsEnabled, true)
end

function Environment.start()
    if isEnabled then return end
    isEnabled = true

    Environment.init()
    Environment.update(true)

    updateTimer = setTimer(Environment.update, 60, 0)
end

function Environment.stop()
    if not isEnabled then return end
    isEnabled = false

    if isTimer(updateTimer) then
        killTimer(updateTimer)
        updateTimer = nil
    end

    Environment.reset()
end

function Environment.reset()
    pcall(resetWorldProperties, true, true, true, false, false, false, false)
    pcall(resetSkyGradient)
    pcall(setBlurLevel, 36)
    pcall(setVolumetricShadowsEnabled, false)
end

function Environment.update(force)
    if not isEnabled and not force then return end

    local hour, minute = getTime()
    local continuousTime = hour + (minute / 60.0)

    local k1 = CURVES[#CURVES]
    local k2 = CURVES[1]
    local n = #CURVES

    for i = 1, n do
        local nextIndex = (i % n) + 1
        local t1 = CURVES[i].time
        local t2 = CURVES[nextIndex].time

        if t2 > t1 then
            if continuousTime >= t1 and continuousTime < t2 then
                k1 = CURVES[i]
                k2 = CURVES[nextIndex]
                break
            end
        else
            if continuousTime >= t1 or continuousTime < t2 then
                k1 = CURVES[i]
                k2 = CURVES[nextIndex]
                break
            end
        end
    end

    local t1 = k1.time
    local t2 = k2.time
    local span = t2 - t1
    if span <= 0 then span = span + 24.0 end

    local progress = continuousTime - t1
    if progress < 0 then progress = progress + 24.0 end

    local frac = smoothstep(math.max(0.0, math.min(1.0, progress / span)))

    local skyTop = lerpColor(k1.skyTop, k2.skyTop, frac)
    local skyBot = lerpColor(k1.skyBot, k2.skyBot, frac)
    local sunCore = lerpColor(k1.sunCore, k2.sunCore, frac)
    local sunCorona = lerpColor(k1.sunCorona, k2.sunCorona, frac)
    local sunSize = lerp(k1.sunSize, k2.sunSize, frac)
    local moonSize = lerp(k1.moonSize, k2.moonSize, frac)

    local ambW = lerpColor(k1.ambientWorld, k2.ambientWorld, frac)
    local ambD = lerpColor(k1.ambientDynamic, k2.ambientDynamic, frac)
    local dirCol = lerpColor(k1.dirColor, k2.dirColor, frac)
    local illum = lerp(k1.illumination, k2.illumination, frac)

    local shadowStr = math.floor(lerp(k1.shadowStrength, k2.shadowStrength, frac) + 0.5)
    local poleShadow = math.floor(lerp(k1.poleShadow, k2.poleShadow, frac) + 0.5)
    local sprBright = lerp(k1.spriteBrightness, k2.spriteBrightness, frac)
    local sprSize = lerp(k1.spriteSize, k2.spriteSize, frac)
    local lgtGround = lerp(k1.lightsOnGround, k2.lightsOnGround, frac)

    local fogDist = lerp(k1.fogDist, k2.fogDist, frac)
    local farClip = lerp(k1.farClip, k2.farClip, frac)
    local waterCol = lerpColor(k1.waterColor, k2.waterColor, frac)

    local weatherId = getWeather()
    local rainLvl = getRainLevel() or 0.0
    local isRainWeather = (weatherId == 8 or weatherId == 16 or rainLvl > 0.05)

    if isRainWeather then
        illum = illum * 0.45
        dirCol = lerpColor(dirCol, {70, 75, 85}, 0.65)
        ambW = lerpColor(ambW, {60, 65, 75}, 0.45)
        ambD = lerpColor(ambD, {70, 75, 85}, 0.45)
        skyTop = lerpColor(skyTop, {50, 55, 65}, 0.70)
        skyBot = lerpColor(skyBot, {85, 90, 100}, 0.70)
        fogDist = math.min(fogDist, 60.0)
    end

    local intFactor = Interior and Interior.getFactor() or 0.0
    if intFactor > 0.01 then
        illum = lerp(illum, 0.20, intFactor)
        ambW = lerpColor(ambW, {80, 82, 88}, intFactor * 0.5)
        ambD = lerpColor(ambD, {90, 92, 98}, intFactor * 0.5)
    end

    setSkyGradient(skyTop[1], skyTop[2], skyTop[3], skyBot[1], skyBot[2], skyBot[3])
    setSunColor(sunCore[1], sunCore[2], sunCore[3], sunCorona[1], sunCorona[2], sunCorona[3])
    setSunSize(sunSize)
    setMoonSize(moonSize)

    setWorldProperty("AmbientColor", ambW[1], ambW[2], ambW[3])
    setWorldProperty("AmbientObjColor", ambD[1], ambD[2], ambD[3])
    setWorldProperty("DirectionalColor", dirCol[1], dirCol[2], dirCol[3])
    setWorldProperty("Illumination", illum)
    setWorldProperty("ShadowStrength", shadowStr)
    setWorldProperty("PoleShadowStrength", poleShadow)
    setWorldProperty("SpriteBrightness", sprBright)
    setWorldProperty("SpriteSize", sprSize)
    setWorldProperty("LightsOnGround", lgtGround)

    setFogDistance(fogDist)
    setFarClipDistance(farClip)
    setWaterColor(waterCol[1], waterCol[2], waterCol[3], 210)

    currentSunDir = calculateSunDirection(continuousTime)
    currentSunColor = {dirCol[1] / 255.0, dirCol[2] / 255.0, dirCol[3] / 255.0}
    currentAmbientColor = {ambW[1] / 255.0, ambW[2] / 255.0, ambW[3] / 255.0}
end

function Environment.getSunDirection()
    return currentSunDir
end

function Environment.getSunColor()
    return currentSunColor
end

function Environment.getAmbientColor()
    return currentAmbientColor
end