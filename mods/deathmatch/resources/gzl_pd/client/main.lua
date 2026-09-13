
PDClient = {
    isOpen = false,
    activeTab = "dashboard",
    activeInput = nil,
    citizenInput = "",
    vehicleInput = "",

    officer = { name = "Memur", status = "10-8", rank = "Memur" },
    myStatus = "10-8",

    officers = {},
    bulletins = {},
    wantedCount = 0,
    boloCount = 0,

    searchedCitizenName = nil,
    citizenRecords = {},
    citizenWarrant = nil,

    searchedPlate = nil,
    vehicleBolo = nil,
    allWantedVehicles = {},

    scrollOffset = 0,
    maxScroll = 0,
    clickDebounce = false,
    panicAlert = nil,
    panicBlip = nil
}

addEvent("pd:openTablet", true)
addEventHandler("pd:openTablet", root, function(officerData)
    if type(officerData) == "table" then
        PDClient.officer = officerData
        PDClient.myStatus = officerData.status or "10-8"
    end
    PDClient.open()
end)

function PDClient.open()
    PDClient.isOpen = true
    showCursor(true)
    PDGeometry.updateMetrics()
    triggerServerEvent("pd:requestDashboardData", localPlayer)
end

function PDClient.close()
    PDClient.isOpen = false
    showCursor(false)
    PDClient.activeInput = nil
end

function isPDTabletOpen()
    return PDClient.isOpen == true
end

bindKey("F6", "down", function()
    if PDClient.isOpen then
        PDClient.close()
    else
        executeCommandHandler("pd")
    end
end)

addEvent("pd:receiveDashboardData", true)
addEventHandler("pd:receiveDashboardData", root, function(data)
    if type(data) == "table" then
        PDClient.officers = data.officers or {}
        PDClient.bulletins = data.bulletins or {}
        PDClient.wantedCount = data.wantedCount or 0
        PDClient.boloCount = data.boloCount or 0
    end
end)

addEvent("pd:receiveCitizenData", true)
addEventHandler("pd:receiveCitizenData", root, function(targetName, records, warrant)
    PDClient.searchedCitizenName = targetName
    PDClient.citizenRecords = records or {}
    PDClient.citizenWarrant = warrant
    PDClient.scrollOffset = 0
end)

addEvent("pd:receiveVehicleData", true)
addEventHandler("pd:receiveVehicleData", root, function(plate, bolo, allBolo)
    PDClient.searchedPlate = plate
    PDClient.vehicleBolo = bolo
    PDClient.allWantedVehicles = allBolo or {}
    PDClient.scrollOffset = 0
end)

addEvent("pd:onOfficerStatusUpdate", true)
addEventHandler("pd:onOfficerStatusUpdate", root, function(offName, newStatus)
    for _, off in ipairs(PDClient.officers) do
        if off.name == offName then
            off.status = newStatus
            break
        end
    end
end)

addEvent("pd:onPanicAlert", true)
addEventHandler("pd:onPanicAlert", root, function(offName, x, y, z)
    PDClient.panicAlert = {
        officerName = offName,
        startTick = getTickCount()
    }
    playSoundFrontEnd(12)

    if isElement(PDClient.panicBlip) then destroyElement(PDClient.panicBlip) end
    PDClient.panicBlip = createBlip(x, y, z, 0, 3, 255, 0, 0, 255)
    setTimer(function()
        if isElement(PDClient.panicBlip) then destroyElement(PDClient.panicBlip) end
    end, 30000, 1)
end)

addEvent("pd:onActionAck", true)
addEventHandler("pd:onActionAck", root, function(actionType, success, message)
    if success then
        outputChatBox("[LSPD MDC] " .. tostring(message), 34, 197, 94)
        if actionType == "issueFine" or actionType == "setWanted" then
            if PDClient.searchedCitizenName then
                triggerServerEvent("pd:searchCitizen", localPlayer, PDClient.searchedCitizenName)
            end
        elseif actionType == "setBolo" then
            if PDClient.searchedPlate then
                triggerServerEvent("pd:searchVehicle", localPlayer, PDClient.searchedPlate)
            end
        end
    else
        outputChatBox("[LSPD Hata] " .. tostring(message), 239, 68, 68)
    end
end)

function PDClient.handle10CodeClick(code)
    PDClient.myStatus = code
    PDClient.officer.status = code
    triggerServerEvent("pd:setStatus", localPlayer, code)
    if code == "10-99" then
        triggerServerEvent("pd:triggerPanicButton", localPlayer)
    end
end

function PDClient.triggerPanic()
    PDClient.handle10CodeClick("10-99")
end

function PDClient.searchCitizen()
    if string.len(PDClient.citizenInput) >= 2 then
        triggerServerEvent("pd:searchCitizen", localPlayer, PDClient.citizenInput)
    end
end

function PDClient.toggleWantedCitizen()
    if not PDClient.searchedCitizenName then return end
    if PDClient.citizenWarrant then

        triggerServerEvent("pd:setWantedStatus", localPlayer, PDClient.searchedCitizenName, 0, "")
    else

        triggerServerEvent("pd:setWantedStatus", localPlayer, PDClient.searchedCitizenName, 2, "Polis Tarafından Aranıyor")
    end
end

function PDClient.searchVehicle()
    if string.len(PDClient.vehicleInput) >= 2 then
        triggerServerEvent("pd:searchVehicle", localPlayer, PDClient.vehicleInput)
    end
end

function PDClient.toggleVehicleBolo()
    if not PDClient.searchedPlate then return end
    local isRemove = (PDClient.vehicleBolo ~= nil)
    triggerServerEvent("pd:setVehicleBolo", localPlayer, PDClient.searchedPlate, "Bilinmiyor", "Şüpheli / Çalıntı İhbarı", isRemove)
end

function PDClient.applyPenalFine(penal)
    if not PDClient.searchedCitizenName or PDClient.searchedCitizenName == "" then
        outputChatBox("[LSPD] Lütfen önce 'Vatandaş & Sicil' sekmesinden bir isim sorgulayın!", 239, 68, 68)
        return
    end
    triggerServerEvent("pd:issueFine", localPlayer, PDClient.searchedCitizenName, penal.title, penal.fine, penal.jail)
end

addEventHandler("onClientCharacter", root, function(char)
    if not PDClient.isOpen or not PDClient.activeInput then return end
    if PDClient.activeInput == "citizen" then
        if string.len(PDClient.citizenInput) < 32 then
            PDClient.citizenInput = PDClient.citizenInput .. char
        end
    elseif PDClient.activeInput == "vehicle" then
        if string.len(PDClient.vehicleInput) < 16 then
            PDClient.vehicleInput = string.upper(PDClient.vehicleInput .. char)
        end
    end
end)

addEventHandler("onClientKey", root, function(btn, press)
    if not PDClient.isOpen or not press then return end

    if btn == "backspace" and PDClient.activeInput then
        if PDClient.activeInput == "citizen" and string.len(PDClient.citizenInput) > 0 then
            PDClient.citizenInput = string.sub(PDClient.citizenInput, 1, -2)
        elseif PDClient.activeInput == "vehicle" and string.len(PDClient.vehicleInput) > 0 then
            PDClient.vehicleInput = string.sub(PDClient.vehicleInput, 1, -2)
        end
    elseif btn == "enter" and PDClient.activeInput then
        if PDClient.activeInput == "citizen" then
            PDClient.searchCitizen()
        elseif PDClient.activeInput == "vehicle" then
            PDClient.searchVehicle()
        end
    elseif btn == "mouse_wheel_down" then
        PDClient.scrollOffset = math.min(PDClient.maxScroll, PDClient.scrollOffset + 35)
    elseif btn == "mouse_wheel_up" then
        PDClient.scrollOffset = math.max(0, PDClient.scrollOffset - 35)
    elseif btn == "escape" then
        PDClient.close()
        cancelEvent()
    end
end)

addEventHandler("onClientClick", root, function(button, state)
    if button ~= "left" or state ~= "down" or not PDClient.isOpen then return end
    local hd = PDGeometry.tablet.header
    if PDGeometry.isCursorIn(hd.x + hd.w - 36, hd.y + 16, 24, 24) then
        PDClient.close()
    end
end)