LauncherState = {
    isBusy = false,
    currentAction = "idle",
    progress = 0,
    total = 0,
    lastStartTime = 0,
    lastDurationMs = 0,
    failedResources = {},
    loadedResources = {}
}

function logMessage(text, player, msgType)
    local prefix = "[GZL LAUNCHER]"

    outputServerLog(prefix .. " " .. text)

    if player and isElement(player) and getElementType(player) == "player" then
        local r, g, b = 200, 200, 200
        if msgType == "success" then
            r, g, b = 46, 204, 113
        elseif msgType == "error" then
            r, g, b = 231, 76, 60
        elseif msgType == "warning" then
            r, g, b = 241, 196, 15
        elseif msgType == "info" then
            r, g, b = 52, 152, 219
        end
        outputChatBox(prefix .. " #FFFFFF" .. text, player, r, g, b, true)
    end
end

function buildStartupQueue()
    local queue = {}
    if not Config.Phases then return queue end

    for _, phase in ipairs(Config.Phases) do
        if phase.resources then
            for _, res in ipairs(phase.resources) do
                table.insert(queue, {
                    name = res.name,
                    desc = res.desc or "",
                    phaseId = phase.id,
                    phaseName = phase.name,
                    optional = res.optional or false
                })
            end
        end
    end

    return queue
end

function buildShutdownQueue()
    local startupQueue = buildStartupQueue()
    local shutdownQueue = {}

    for i = #startupQueue, 1, -1 do
        local item = startupQueue[i]
        if not Config.ProtectedResources[item.name] then
            table.insert(shutdownQueue, item)
        end
    end

    return shutdownQueue
end

function executeStartupSequence(invokerPlayer, onComplete)
    if LauncherState.isBusy then
        logMessage("Launcher su an mesgul! (Mevcut islem: " .. LauncherState.currentAction .. ")", invokerPlayer, "warning")
        return false
    end

    checkLauncherACL()

    local queue = buildStartupQueue()
    if #queue == 0 then
        logMessage("Baslatilacak kaynak kuyrugu bos!", invokerPlayer, "warning")
        return false
    end

    LauncherState.isBusy = true
    LauncherState.currentAction = "starting"
    LauncherState.progress = 0
    LauncherState.total = #queue
    LauncherState.failedResources = {}
    LauncherState.loadedResources = {}

    local startTick = getTickCount()
    LauncherState.lastStartTime = startTick

    outputServerLog("================================================================================")
    outputServerLog("  [GZL LAUNCHER] GZL Roleplay Sistemleri Baslatiliyor...")
    outputServerLog("  Toplam Asama: " .. tostring(#Config.Phases) .. " | Toplam Script: " .. tostring(#queue) .. " | Gecikme: " .. tostring(Config.StepDelayMs) .. "ms")
    outputServerLog("================================================================================")

    if invokerPlayer then
        logMessage("Sistem baslatma sekansi baslatildi (" .. tostring(#queue) .. " script)...", invokerPlayer, "info")
    end

    local lastPhaseId = -1

    local function processNextItem(index)
        if index > #queue then

            local totalDurationMs = getTickCount() - startTick
            LauncherState.lastDurationMs = totalDurationMs
            LauncherState.isBusy = false
            LauncherState.currentAction = "idle"

            local successCount = #LauncherState.loadedResources
            local failCount = #LauncherState.failedResources

            outputServerLog("================================================================================")
            outputServerLog(string.format("  [GZL LAUNCHER] Tamamlandi! Basarili: %d | Hatali: %d | Sure: %.2f sn", successCount, failCount, totalDurationMs / 1000))
            outputServerLog("================================================================================")

            if invokerPlayer then
                logMessage(string.format("Tum scriptler yuklendi (#2ecc71%d basarili#FFFFFF, #e74c3c%d hatali#FFFFFF) - %.2f sn", successCount, failCount, totalDurationMs / 1000), invokerPlayer, "success")
            end

            if onComplete and type(onComplete) == "function" then
                onComplete(true, successCount, failCount)
            end
            return
        end

        local item = queue[index]
        LauncherState.progress = index

        if item.phaseId ~= lastPhaseId then
            lastPhaseId = item.phaseId
            outputServerLog(string.format(">> [ASAMA %d: %s]", item.phaseId, item.phaseName))
        end

        local res = getResourceFromName(item.name)
        if not res then
            if item.optional then
                outputServerLog(string.format("   [OPSIYONEL/ATLANDI] %-18s (Bulunamadi - Opsiyonel)", item.name))
            else
                outputServerLog(string.format("   [HATA - BULUNAMADI] %-18s (Resource klasorunde bulunamadi!)", item.name))
                table.insert(LauncherState.failedResources, { name = item.name, reason = "Bulunamadı" })
            end
        else
            local currentState = getResourceState(res)
            if currentState == "running" then
                outputServerLog(string.format("   [ZATEN ACIK]        %-18s (%s)", item.name, item.desc))
                table.insert(LauncherState.loadedResources, item.name)
            else
                local t0 = getTickCount()
                local started = startResource(res)
                local elapsed = getTickCount() - t0

                if started then
                    outputServerLog(string.format("   [OK]                %-18s (%s) [%d ms]", item.name, item.desc, elapsed))
                    table.insert(LauncherState.loadedResources, item.name)
                else
                    outputServerLog(string.format("   [HATA - BASLATILAMADI] %-18s (Start hatasi!)", item.name))
                    table.insert(LauncherState.failedResources, { name = item.name, reason = "Başlatılamadı" })
                end
            end
        end

        setTimer(function()
            processNextItem(index + 1)
        end, Config.StepDelayMs, 1)
    end

    processNextItem(1)
    return true
end

function executeShutdownSequence(invokerPlayer, onComplete)
    if LauncherState.isBusy then
        logMessage("Launcher su an mesgul! (Mevcut islem: " .. LauncherState.currentAction .. ")", invokerPlayer, "warning")
        return false
    end

    local queue = buildShutdownQueue()
    if #queue == 0 then
        logMessage("Durdurulacak kaynak bulunamadi!", invokerPlayer, "warning")
        return false
    end

    LauncherState.isBusy = true
    LauncherState.currentAction = "stopping"
    LauncherState.progress = 0
    LauncherState.total = #queue

    local startTick = getTickCount()

    outputServerLog("================================================================================")
    outputServerLog("  [GZL LAUNCHER] Scriptler Guvenle Durduruluyor (Ters Sira)...")
    outputServerLog("================================================================================")

    if invokerPlayer then
        logMessage("Sistem durdurma sekansi baslatildi...", invokerPlayer, "warning")
    end

    local function processNextStop(index)
        if index > #queue then
            local totalDurationMs = getTickCount() - startTick
            LauncherState.isBusy = false
            LauncherState.currentAction = "idle"

            outputServerLog("================================================================================")
            outputServerLog(string.format("  [GZL LAUNCHER] Tum scriptler durduruldu (Sure: %.2f sn)", totalDurationMs / 1000))
            outputServerLog("================================================================================")

            if invokerPlayer then
                logMessage("Tum yonetilen scriptler basariyla durduruldu.", invokerPlayer, "success")
            end

            if onComplete and type(onComplete) == "function" then
                onComplete(true)
            end
            return
        end

        local item = queue[index]
        LauncherState.progress = index

        local res = getResourceFromName(item.name)
        if res and getResourceState(res) == "running" then
            stopResource(res)
            outputServerLog(string.format("   [DURDURULDU]        %-18s", item.name))
        end

        setTimer(function()
            processNextStop(index + 1)
        end, math.floor(Config.StepDelayMs * 0.7), 1)
    end

    processNextStop(1)
    return true
end

function executeRestartSequence(invokerPlayer, onComplete)
    if LauncherState.isBusy then
        logMessage("Launcher su an mesgul! (Mevcut islem: " .. LauncherState.currentAction .. ")", invokerPlayer, "warning")
        return false
    end

    logMessage("Yeniden baslatma dongusu baslatiliyor: Once durdurulacak, sonra sirayla baslatilacak...", invokerPlayer, "info")

    executeShutdownSequence(invokerPlayer, function(stopSuccess)
        if stopSuccess then
            setTimer(function()
                executeStartupSequence(invokerPlayer, onComplete)
            end, 500, 1)
        end
    end)
    return true
end

function showStatusSummary(player)
    local isConsole = not (player and isElement(player) and getElementType(player) == "player")

    local function out(text)
        if isConsole then
            outputServerLog(text)
        else
            outputChatBox(text, player, 255, 255, 255, true)
        end
    end

    out("================================================================================")
    out("  [GZL LAUNCHER] Sunucu Script Durum Ozeti")
    out("================================================================================")

    local totalCount = 0
    local runningCount = 0
    local stoppedCount = 0
    local missingCount = 0

    for _, phase in ipairs(Config.Phases) do
        out(string.format("#3498db>> ASAMA %d: %s#FFFFFF (%s)", phase.id, phase.name, phase.description or ""))

        if phase.resources then
            for _, resItem in ipairs(phase.resources) do
                totalCount = totalCount + 1
                local res = getResourceFromName(resItem.name)

                if not res then
                    missingCount = missingCount + 1
                    if resItem.optional then
                        out(string.format("   #7f8c8d[BULUNAMADI - OPT]  %-20s - %s#FFFFFF", resItem.name, resItem.desc or ""))
                    else
                        out(string.format("   #e74c3c[BULUNAMADI]        %-20s - %s#FFFFFF", resItem.name, resItem.desc or ""))
                    end
                else
                    local state = getResourceState(res)
                    if state == "running" then
                        runningCount = runningCount + 1
                        out(string.format("   #2ecc71[CALISIYOR]         %-20s#FFFFFF - %s", resItem.name, resItem.desc or ""))
                    else
                        stoppedCount = stoppedCount + 1
                        out(string.format("   #f1c40f[KAPALI (%s)]       %-20s#FFFFFF - %s", state, resItem.name, resItem.desc or ""))
                    end
                end
            end
        end
    end

    out("--------------------------------------------------------------------------------")
    out(string.format("  Toplam: %d | #2ecc71Calisan: %d#FFFFFF | #f1c40fKapali: %d#FFFFFF | #e74c3cEksik: %d#FFFFFF", totalCount, runningCount, stoppedCount, missingCount))
    out("================================================================================")
end

addEventHandler("onResourceStart", resourceRoot, function()
    if Config.AutoStartOnResourceStart then
        setTimer(function()
            executeStartupSequence()
        end, Config.InitialBootDelayMs or 300, 1)
    end
end)