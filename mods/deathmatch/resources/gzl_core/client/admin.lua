local isFlyActive = false
local flySpeed = 1.2
local flyFastMultiplier = 3.5
local flySlowMultiplier = 0.3
local isGodActive = false

local function getCameraLookDirection()
    local cx, cy, cz, lx, ly, lz = getCameraMatrix()
    local dx = lx - cx
    local dy = ly - cy
    local dz = lz - cz
    local len = math.sqrt(dx * dx + dy * dy + dz * dz)
    if len > 0 then
        return dx / len, dy / len, dz / len
    end
    return 0, 1, 0
end

local function getCameraRightDirection()
    local fx, fy, _ = getCameraLookDirection()
    local rx = fy
    local ry = -fx
    local len = math.sqrt(rx * rx + ry * ry)
    if len > 0 then
        return rx / len, ry / len, 0
    end
    return 1, 0, 0
end

addEventHandler("onClientPreRender", root, function(dt)
    if not isFlyActive then return end

    local delta = dt / 1000
    local speed = flySpeed * 40 * delta

    if getKeyState("lshift") or getKeyState("rshift") then
        speed = speed * flyFastMultiplier
    elseif getKeyState("lalt") or getKeyState("ralt") then
        speed = speed * flySlowMultiplier
    end

    local fx, fy, fz = getCameraLookDirection()
    local rx, ry, _ = getCameraRightDirection()

    local moveX, moveY, moveZ = 0, 0, 0

    if getKeyState("w") then
        moveX = moveX + fx * speed
        moveY = moveY + fy * speed
        moveZ = moveZ + fz * speed
    end
    if getKeyState("s") then
        moveX = moveX - fx * speed
        moveY = moveY - fy * speed
        moveZ = moveZ - fz * speed
    end
    if getKeyState("d") then
        moveX = moveX + rx * speed
        moveY = moveY + ry * speed
    end
    if getKeyState("a") then
        moveX = moveX - rx * speed
        moveY = moveY - ry * speed
    end
    if getKeyState("space") then
        moveZ = moveZ + speed
    end
    if getKeyState("lctrl") or getKeyState("c") then
        moveZ = moveZ - speed
    end

    local targetElem = getPedOccupiedVehicle(localPlayer) or localPlayer
    local px, py, pz = getElementPosition(targetElem)

    setElementPosition(targetElem, px + moveX, py + moveY, pz + moveZ)
    setElementVelocity(targetElem, 0, 0, 0)
end)

function toggleFlyMode()
    if not isAdmin(localPlayer) then
        outputChatBox("#ef4444[GZL-ADMIN]#ffffff Bu komutu kullanmak için yetkiniz yok!", 255, 255, 255, true)
        return
    end
    isFlyActive = not isFlyActive
    local targetElem = getPedOccupiedVehicle(localPlayer) or localPlayer

    setElementCollisionsEnabled(targetElem, not isFlyActive)
    setElementFrozen(targetElem, isFlyActive)

    if isFlyActive then
        setElementVelocity(targetElem, 0, 0, 0)
        outputChatBox("#38bdf8[GZL-ADMIN]#ffffff Fly modu: #34d399AÇIK #ffffff(WASD: Hareket | Space: Yukarı | LCtrl: Aşağı | Shift: Hızlı)", 255, 255, 255, true)
    else
        local px, py, pz = getElementPosition(targetElem)
        setElementPosition(targetElem, px, py, pz)
        outputChatBox("#38bdf8[GZL-ADMIN]#ffffff Fly modu: #ef4444KAPALI", 255, 255, 255, true)
    end
end
addCommandHandler("fly", toggleFlyMode)
addCommandHandler("noclip", toggleFlyMode)

function toggleGodMode()
    if not isAdmin(localPlayer) then
        outputChatBox("#ef4444[GZL-ADMIN]#ffffff Bu komutu kullanmak için yetkiniz yok!", 255, 255, 255, true)
        return
    end
    isGodActive = not isGodActive
    outputChatBox("#38bdf8[GZL-ADMIN]#ffffff Ölümsüzlük: " .. (isGodActive and "#34d399AÇIK" or "#ef4444KAPALI"), 255, 255, 255, true)
end
addCommandHandler("god", toggleGodMode)
addCommandHandler("godmode", toggleGodMode)

addEventHandler("onClientPlayerDamage", localPlayer, function()
    if isGodActive or isFlyActive then
        cancelEvent()
    end
end)