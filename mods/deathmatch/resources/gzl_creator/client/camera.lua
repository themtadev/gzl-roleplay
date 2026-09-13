
local activeCamera = false
local currentView = "full"
local pedElement = nil
local pedRotation = 180
local baseHeading = 180
local isMouseDown = false
local lastMouseX = 0

local camStart = nil
local camTarget = nil
local camInterpolateStart = 0
local camDuration = 700

local viewPresets = {
    full = {
        dist = 3.0,
        camShift = 0.50,
        targetShift = 0.10,
        czOffset = 0.74,
        tzOffset = 0.64,
    },
    head = {
        dist = 1.15,
        camShift = 0.22,
        targetShift = 0.05,
        czOffset = 0.80,
        tzOffset = 0.78,
    },
    body = {
        dist = 1.85,
        camShift = 0.32,
        targetShift = 0.08,
        czOffset = 0.55,
        tzOffset = 0.45,
    },
    feet = {
        dist = 1.85,
        camShift = 0.30,
        targetShift = 0.08,
        czOffset = -0.25,
        tzOffset = -0.45,
    },
}

function setStudioPed(ped)
    pedElement = ped
    if isElement(pedElement) then
        setElementRotation(pedElement, 0, 0, pedRotation)
    end
end

function getStudioPed()
    return pedElement
end

local function calculateCameraMatrix(viewName)
    local preset = viewPresets[viewName] or viewPresets.full
    if not isElement(pedElement) then
        return { cx = 835.0, cy = -2063.2, cz = 13.6, tx = 835.5, ty = -2060.0, tz = 13.5 }
    end

    local px, py, pz = getElementPosition(pedElement)
    local rad = math.rad(baseHeading)
    local frontX = -math.sin(rad)
    local frontY = math.cos(rad)
    local rightX = math.cos(rad)
    local rightY = math.sin(rad)

    local cx = px + frontX * preset.dist + rightX * preset.camShift
    local cy = py + frontY * preset.dist + rightY * preset.camShift
    local cz = pz + preset.czOffset

    local tx = px - rightX * preset.targetShift
    local ty = py - rightY * preset.targetShift
    local tz = pz + preset.tzOffset

    local hit, hitX, hitY, hitZ = processLineOfSight(tx, ty, tz, cx, cy, cz, true, false, false, true, false, false, false, false, pedElement)
    if hit then
        local dirX = hitX - tx
        local dirY = hitY - ty
        local dirZ = hitZ - tz
        local hitDist = math.sqrt(dirX * dirX + dirY * dirY + dirZ * dirZ)
        if hitDist > 0.4 then
            local factor = (hitDist - 0.15) / hitDist
            cx = tx + dirX * factor
            cy = ty + dirY * factor
            cz = tz + dirZ * factor
        end
    end

    return { cx = cx, cy = cy, cz = cz, tx = tx, ty = ty, tz = tz }
end

function startStudioCamera(ped)
    pedElement = ped
    activeCamera = true
    showCursor(true)

    if isElement(pedElement) then
        local _, _, pRot = getElementRotation(pedElement)
        pedRotation = pRot
        baseHeading = pRot
    else
        pedRotation = 180
        baseHeading = 180
    end

    setCameraView("full", true)
    addEventHandler("onClientPreRender", root, renderStudioCamera)
    addEventHandler("onClientClick", root, handleCameraClick)
end

function stopStudioCamera()
    activeCamera = false
    isMouseDown = false
    showCursor(false)
    removeEventHandler("onClientPreRender", root, renderStudioCamera)
    removeEventHandler("onClientClick", root, handleCameraClick)
    setCameraTarget(localPlayer)
    setCameraInterior(getElementInterior(localPlayer))
end

function setCameraView(viewName, instant)
    currentView = viewName
    local targetPreset = calculateCameraMatrix(viewName)

    local int = isElement(pedElement) and getElementInterior(pedElement) or getElementInterior(localPlayer)
    setCameraInterior(int)

    if instant or not activeCamera then
        setCameraMatrix(targetPreset.cx, targetPreset.cy, targetPreset.cz, targetPreset.tx, targetPreset.ty, targetPreset.tz)
        camStart = targetPreset
        camTarget = targetPreset
        camInterpolateStart = 0
    else
        local cx, cy, cz, tx, ty, tz = getCameraMatrix()
        camStart = { cx = cx, cy = cy, cz = cz, tx = tx, ty = ty, tz = tz }
        camTarget = targetPreset
        camInterpolateStart = getTickCount()
    end
end

function renderStudioCamera()
    if not activeCamera then return end

    if camStart and camTarget and camInterpolateStart > 0 then
        local now = getTickCount()
        local progress = (now - camInterpolateStart) / camDuration
        if progress > 1 then progress = 1 end
        local eased = getEasingValue(progress, "InOutQuad")

        local cx = camStart.cx + (camTarget.cx - camStart.cx) * eased
        local cy = camStart.cy + (camTarget.cy - camStart.cy) * eased
        local cz = camStart.cz + (camTarget.cz - camStart.cz) * eased
        local tx = camStart.tx + (camTarget.tx - camStart.tx) * eased
        local ty = camStart.ty + (camTarget.ty - camStart.ty) * eased
        local tz = camStart.tz + (camTarget.tz - camStart.tz) * eased
        setCameraMatrix(cx, cy, cz, tx, ty, tz)

        if progress >= 1 then
            camInterpolateStart = 0
            camStart = camTarget
        end
    end

    if isMouseDown and isElement(pedElement) then
        local cx, cy = getCursorPosition()
        if cx then
            local screenW, screenH = guiGetScreenSize()
            local mouseX = cx * screenW
            local deltaX = mouseX - lastMouseX
            lastMouseX = mouseX
            pedRotation = (pedRotation - deltaX * 0.85) % 360
            setElementRotation(pedElement, 0, 0, pedRotation)
        end
    end
end

function handleCameraClick(button, state, absoluteX, absoluteY)
    if button == "left" then
        if state == "down" then

            if not (isCreatorStudioUIAt and isCreatorStudioUIAt(absoluteX,absoluteY)) then
                isMouseDown = true
                lastMouseX = absoluteX
            end
        else
            isMouseDown = false
        end
    end
end

function setPedDirectRotation(deg)
    pedRotation = deg % 360
    if isElement(pedElement) then
        setElementRotation(pedElement, 0, 0, pedRotation)
    end
end

function getPedCurrentRotation()
    return pedRotation
end