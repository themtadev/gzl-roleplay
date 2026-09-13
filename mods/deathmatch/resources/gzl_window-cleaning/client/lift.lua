LiftClient = {}

local activeLiftObject = nil
local liftConfig = nil
local isInLiftZone = false
local isControllingLift = false

function LiftClient.setLiftElement(element, config)
    activeLiftObject = element
    liftConfig = config
end

function LiftClient.clearLift()
    activeLiftObject = nil
    liftConfig = nil
    isControllingLift = false
end

function LiftClient.render()
    if not isElement(activeLiftObject) or not liftConfig then return end

    local px, py, pz = getElementPosition(localPlayer)
    local lx, ly, lz = getElementPosition(activeLiftObject)
    local dist = getDistanceBetweenPoints3D(px, py, pz, lx, ly, lz)

    if dist < 4.5 then
        isInLiftZone = true
        local sx, sy = getScreenFromWorldPosition(lx, ly, lz + 1.2)
        if sx and sy then
            local cardW = 240
            local cardH = isControllingLift and 76 or 44
            local cardX = sx - cardW / 2
            local cardY = sy - cardH / 2

            drawGlassPanel(cardX, cardY, cardW, cardH, 10, 0.92)
            if not isControllingLift then
                dxDrawText("İskele Kontrolü [ F / ENTER ]", cardX, cardY, cardX + cardW, cardY + cardH, tocolor(56, 189, 248, 255), 1.0, "default-bold", "center", "center")
            else
                dxDrawText("İSKELE KONTROL MODU", cardX, cardY + 8, cardX + cardW, cardY + 28, tocolor(34, 197, 94, 255), 1.0, "default-bold", "center", "center")
                dxDrawText("[ W / ▲ ] Yukarı  |  [ S / ▼ ] Aşağı\n[ F / ENTER ] Kontrolden Çık", cardX, cardY + 30, cardX + cardW, cardY + 70, tocolor(203, 213, 225, 255), 0.85, "default-bold", "center", "center")
            end
        end
    else
        isInLiftZone = false
        if isControllingLift then
            isControllingLift = false
        end
    end
end

addEventHandler("onClientKey", root, function(button, press)
    if not isElement(activeLiftObject) or not liftConfig then return end

    if press and (button == "f" or button == "enter") and isInLiftZone and not CleaningGame.isActive() and not LobbyUI.isOpen() then
        isControllingLift = not isControllingLift
        cancelEvent()
        return
    end

    if isControllingLift then
        if press then
            if button == "w" or button == "arrow_u" then
                triggerServerEvent("windowCleaning:moveLift", localPlayer, "up")
                cancelEvent()
            elseif button == "s" or button == "arrow_d" then
                triggerServerEvent("windowCleaning:moveLift", localPlayer, "down")
                cancelEvent()
            end
        else
            if button == "w" or button == "arrow_u" or button == "s" or button == "arrow_d" then
                triggerServerEvent("windowCleaning:moveLift", localPlayer, "stop")
            end
        end
    end
end)