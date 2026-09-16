local cameraActive = false
local angle = 0.5
local camRadius = 180
local targetX, targetY, targetZ = 1480.0, -1650.0, 30.0

local function updateCamera()
    if cameraActive then
        angle = angle + 0.0006
        local camX = targetX + math.sin(angle) * camRadius
        local camY = targetY + math.cos(angle) * camRadius
        local camZ = 75.0 + math.sin(angle * 0.5) * 10

        setCameraMatrix(camX, camY, camZ, targetX, targetY, targetZ + 15.0)
    end
end

function startAuthCamera()
    cameraActive = true

    setPlayerHudComponentVisible("all", false)
    setPlayerHudComponentVisible("radar", false)
    setPlayerHudComponentVisible("area_name", false)
    setPlayerHudComponentVisible("radio", false)

    setTime(20, 45)
    setWeather(0)
    setMinuteDuration(600000)

    fadeCamera(true, 1.2)
    addEventHandler("onClientRender", root, updateCamera)
end

function stopAuthCamera()
    if cameraActive then
        cameraActive = false
        removeEventHandler("onClientRender", root, updateCamera)

        setPlayerHudComponentVisible("all", false)
        setPlayerHudComponentVisible("crosshair", true)
        setMinuteDuration(1000)

        setCameraTarget(localPlayer)
        setCameraInterior(getElementInterior(localPlayer))
    end
end

-- Stop the render loop even if an optional login UI export failed.
addEvent("char:spawnSuccess", true)
addEventHandler("char:spawnSuccess", root, stopAuthCamera)