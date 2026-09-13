function startAllResources(invokerPlayer, onComplete)
    if sourceResource and sourceResource ~= getThisResource() then return false end
    return executeStartupSequence(invokerPlayer, onComplete)
end

function stopAllResources(invokerPlayer, onComplete)
    if sourceResource and sourceResource ~= getThisResource() then return false end
    return executeShutdownSequence(invokerPlayer, onComplete)
end

function restartAllResources(invokerPlayer, onComplete)
    if sourceResource and sourceResource ~= getThisResource() then return false end
    return executeRestartSequence(invokerPlayer, onComplete)
end

function isResourceLoaded(resourceName)
    if not resourceName or type(resourceName) ~= "string" then return false end
    local res = getResourceFromName(resourceName)
    if not res then return false end
    return getResourceState(res) == "running"
end

function getLauncherStatus()
    return {
        isBusy = LauncherState.isBusy,
        currentAction = LauncherState.currentAction,
        progress = LauncherState.progress,
        total = LauncherState.total,
        lastStartTime = LauncherState.lastStartTime,
        lastDurationMs = LauncherState.lastDurationMs
    }
end

function getResourceQueue()
    return buildStartupQueue()
end

function reloadLauncherConfig(invokerPlayer)
    if sourceResource and sourceResource ~= getThisResource() then return false end
    logMessage("Yapilandirma yenileniyor...", invokerPlayer, "info")
    return true
end