
local isRunning = false

function startAtmosphere()
    if isRunning then return end
    isRunning = true

    Interior.init()
    Environment.start()
    Materials.start()
    Pipeline.start()
end

function stopAtmosphere()
    if not isRunning then return end
    isRunning = false

    Pipeline.stop()
    Materials.stop()
    Environment.stop()
    Interior.reset()
end

addEventHandler("onClientResourceStart", resourceRoot, function()
    startAtmosphere()
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    stopAtmosphere()
end)

function isAtmosphereEnabled()
    return isRunning
end

function getAtmosphereInteriorFactor()
    return Interior and Interior.getFactor() or 0.0
end