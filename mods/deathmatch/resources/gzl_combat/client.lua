local C = CombatConfig
local enabled, active, aiming = C.enabled, false, false
local supported = {}
for _, id in ipairs(C.weapons) do supported[id] = true end
local yaw, pitch, shoulder = 0, 0, 1
local hudWasVisible, oldWalkMode, oldSprintEnabled
local bloom = 0
local cameraPreset,cameraDistance=2,C.distance
local defaultKeys = {
    forwards = {"w", "arrow_u"},
    backwards = {"s", "arrow_d"},
    left = {"a", "arrow_l"},
    right = {"d", "arrow_r"},
    fire = {"mouse1", "lctrl", "rctrl"},
    aim_weapon = {"mouse2"},
    sprint = {"lshift", "rshift", "space"}
}

local function held(control)
    local def = defaultKeys[control]
    if def then
        for _, k in ipairs(def) do
            if getKeyState(k) then return true end
        end
    end
    local bound = getBoundKeys(control)
    if type(bound) == "table" then
        for key in pairs(bound) do
            if getKeyState(string.lower(tostring(key))) then return true end
        end
    end
    return false
end
local function running(name)
    local r = getResourceFromName(name)
    return r and getResourceState(r) == "running"
end
local function blocked()
    return isCursorShowing() or isChatBoxInputActive() or isConsoleActive()
        or isMainMenuActive() or guiGetInputEnabled()
        or (running("gzl_core") and exports.gzl_core:isPlayerTyping())
end
local function firstPerson()
    return running("gzl_firstperson") and exports.gzl_firstperson:isFirstPersonActive()
end
local function captureAngles()
    local x, y, z, tx, ty, tz = getCameraMatrix()
    yaw = math.deg(math.atan2(-(tx - x), ty - y))
    pitch = math.deg(math.atan2(tz - z, math.sqrt((tx-x)^2 + (ty-y)^2)))
end
local function release()
    GZLRoll.stop()
    if not active then return end
    active, aiming = false, false
    setPedControlState(localPlayer, "aim_weapon", false)
    setPedControlState(localPlayer, "walk", false)
    setPedControlState(localPlayer, "sprint", false)
    setPedControlState(localPlayer, "forwards", false)
    setPedControlState(localPlayer, "backwards", false)
    setPedControlState(localPlayer, "left", false)
    setPedControlState(localPlayer, "right", false)
    toggleControl("sprint", oldSprintEnabled)
    toggleControl("forwards", true)
    toggleControl("backwards", true)
    toggleControl("left", true)
    toggleControl("right", true)
    setPlayerHudComponentVisible("crosshair", hudWasVisible)
    if oldWalkMode ~= nil and running("gzl_core") then
        exports.gzl_core:setWalkByDefaultActive(oldWalkMode)
    end
    oldWalkMode = nil

    if not firstPerson() and not getCameraTarget() then setCameraTarget(localPlayer) end
end
function setCombatEnabled(state)
    enabled = state == true
    if not enabled then release() end
    return true
end
function isCombatActive() return active end
addCommandHandler("combat", function()
    setCombatEnabled(not enabled)
    outputChatBox("[GZL] Combat: " .. (enabled and "ACIK" or "KAPALI"), 100, 230, 180)
end)
bindKey("q", "down", function()
    if active and not blocked() then shoulder = -shoulder end
end)
function cycleCombatCamera()
    if blocked() then return true end
    if not enabled or not supported[getPedWeapon(localPlayer)] or isPedInVehicle(localPlayer) then return false end
    if firstPerson() then
        exports.gzl_firstperson:setFirstPersonActive(false)
        cameraPreset=1
        cameraDistance=C.cameraDistances[1]
        return true
    end
    if not active then return false end
    if cameraPreset==#C.cameraDistances and running("gzl_firstperson") then
        release()
        exports.gzl_firstperson:setFirstPersonActive(true)
        return true
    end
    cameraPreset=cameraPreset%#C.cameraDistances+1
    outputChatBox("[GZL] Kamera: "..({"Yakin","Orta","Uzak"})[cameraPreset],100,230,180)
    return true
end
bindKey("v","down",function()

    if not running("gzl_firstperson") then cycleCombatCamera() end
end)

addEventHandler("onClientKey",root,function(key,pressed)
    if key~="space" or not pressed or not active or blocked() or not held("aim_weapon") then return end
    if not isControlEnabled("jump") or not isControlEnabled("aim_weapon") then return end
    cancelEvent()
    local right=(held("right") and 1 or 0)-(held("left") and 1 or 0)
    local forward=(held("forwards") and 1 or 0)-(held("backwards") and 1 or 0)
    GZLRoll.start(yaw,right,forward)
end)

addEventHandler("onClientCursorMove", root, function(_, _, ax, ay)
    if not active or aiming or blocked() then return end
    local w, h = guiGetScreenSize()
    yaw = (yaw - (ax - w/2) * C.sensitivity) % 360
    pitch = math.max(-55, math.min(65, pitch - (ay - h/2) * C.sensitivity))
end)

local function orbit()
    local x, y, z = getElementPosition(localPlayer)
    z = z + C.height
    local a, p = math.rad(yaw), math.rad(pitch)
    local fx, fy, fz = -math.sin(a)*math.cos(p), math.cos(a)*math.cos(p), math.sin(p)
    local cx = x - fx*cameraDistance + math.cos(a)*C.shoulder*shoulder
    local cy = y - fy*cameraDistance + math.sin(a)*C.shoulder*shoulder
    local cz = z - fz*cameraDistance
    local hit, hx, hy, hz = processLineOfSight(x,y,z,cx,cy,cz,true,true,false,true,true,false,false,false,localPlayer)
    if hit then
        local dx, dy, dz = cx-x, cy-y, cz-z
        local length = math.sqrt(dx*dx+dy*dy+dz*dz)
        cx, cy, cz = hx-dx/length*0.2, hy-dy/length*0.2, hz-dz/length*0.2
    end
    setCameraMatrix(cx,cy,cz,cx+fx*100,cy+fy*100,cz+fz*100,0,C.fov)
end

local function handleOrbitMovement(dt)
    if isPedReloadingWeapon(localPlayer) or getPedAnimation(localPlayer) or getPedContactElement(localPlayer) then
        return
    end

    local isForward = held("forwards")
    local isBackward = held("backwards")
    local isLeft = held("left")
    local isRight = held("right")
    local isSprint = (oldSprintEnabled == true) and (held("sprint") or getKeyState("lshift") or getKeyState("rshift"))

    local moveY = (isForward and 1 or 0) - (isBackward and 1 or 0)
    local moveX = (isLeft and 1 or 0) - (isRight and 1 or 0)
    local isMoving = (moveX ~= 0 or moveY ~= 0)

    if isMoving and isPedOnGround(localPlayer) then
        local targetRot = yaw
        if moveY == 1 then
            if moveX == 1 then targetRot = yaw + 45
            elseif moveX == -1 then targetRot = yaw - 45
            else targetRot = yaw end
        elseif moveY == -1 then
            if moveX == 1 then targetRot = yaw + 135
            elseif moveX == -1 then targetRot = yaw - 135
            else targetRot = yaw + 180 end
        elseif moveX == 1 then targetRot = yaw + 90
        elseif moveX == -1 then targetRot = yaw - 90 end

        targetRot = targetRot % 360
        local _, _, currentRot = getElementRotation(localPlayer)
        local diff = (targetRot - currentRot + 180) % 360 - 180
        local maxTurn = (C.circleTurnRate or 1080) * (dt / 1000)
        local newRot = math.abs(diff) <= maxTurn and targetRot or ((currentRot + (diff > 0 and maxTurn or -maxTurn)) % 360)

        setElementRotation(localPlayer, 0, 0, newRot, "default", true)
        setPedControlState(localPlayer, "forwards", true)
        setPedControlState(localPlayer, "sprint", isSprint)
        setPedControlState(localPlayer, "walk", false)
    elseif not isMoving then
        setPedControlState(localPlayer, "forwards", false)
        setPedControlState(localPlayer, "sprint", false)
        setPedControlState(localPlayer, "walk", false)
    end
end

addEventHandler("onClientPreRender", root, function(dt)
    cameraDistance=cameraDistance+(C.cameraDistances[cameraPreset]-cameraDistance)*(1-math.exp(-C.cameraZoomResponse*math.min(dt,50)/1000))
    local valid = enabled and supported[getPedWeapon(localPlayer)] and not blocked()
        and not isPedDead(localPlayer) and not isPedInVehicle(localPlayer)
        and not isElementInWater(localPlayer) and not isElementFrozen(localPlayer)
        and not isPedWearingJetpack(localPlayer) and not firstPerson()
    if not valid then release() return end
    if not active then
        if getCameraTarget() ~= localPlayer then return end
        captureAngles()
        hudWasVisible = isPlayerHudComponentVisible("crosshair")
        oldSprintEnabled = isControlEnabled("sprint")
        if running("gzl_core") then
            oldWalkMode = exports.gzl_core:isWalkByDefaultActive()
            exports.gzl_core:setWalkByDefaultActive(false)
        end
        active = true
        toggleControl("sprint", false)
        toggleControl("forwards", false)
        toggleControl("backwards", false)
        toggleControl("left", false)
        toggleControl("right", false)
        setPlayerHudComponentVisible("crosshair", false)
    end
    if GZLRoll.update() then
        aiming=false
        return
    end
    local wantsAim = (isControlEnabled("fire") and held("fire")) or
        (isControlEnabled("aim_weapon") and held("aim_weapon"))
    if wantsAim then
        if not aiming then
            setPedControlState(localPlayer, "forwards", false)
            setPedControlState(localPlayer, "sprint", false)
            setElementRotation(localPlayer, 0, 0, yaw, "default", true)
            setCameraTarget(localPlayer)
            setPedCameraRotation(localPlayer, (-yaw) % 360)
            toggleControl("forwards", true)
            toggleControl("backwards", true)
            toggleControl("left", true)
            toggleControl("right", true)
        end
        aiming = true
        setPedControlState(localPlayer, "aim_weapon", true)
        captureAngles()
        setElementRotation(localPlayer, 0, 0, yaw, "default", true)
    else
        if aiming then
            captureAngles()
            setPedControlState(localPlayer, "aim_weapon", false)
            toggleControl("forwards", false)
            toggleControl("backwards", false)
            toggleControl("left", false)
            toggleControl("right", false)
            toggleControl("sprint", false)
        end
        aiming = false
        orbit()
        handleOrbitMovement(math.min(dt, 50))
    end
    bloom = math.max(0,bloom-dt*0.018)
end, true, "low-10")

addEventHandler("onClientPlayerWeaponFire", localPlayer, function()
    if active then bloom = math.min(14,bloom+3) end
end)
addEventHandler("onClientRender", root, function()
    if not active or not aiming or blocked() then return end
    local tx,ty,tz = getPedTargetEnd(localPlayer)
    if not tx then return end
    local x,y = getScreenFromWorldPosition(tx,ty,tz)
    if not x then return end
    local gap, size = 5+bloom, 5
    local c = C.crosshairColor
    local color = tocolor(c[1],c[2],c[3],230)
    dxDrawLine(x-gap-size,y,x-gap,y,color,2)
    dxDrawLine(x+gap,y,x+gap+size,y,color,2)
    dxDrawLine(x,y-gap-size,x,y-gap,color,2)
    dxDrawLine(x,y+gap,x,y+gap+size,color,2)
    dxDrawRectangle(x-1,y-1,2,2,color)
end)
addEventHandler("onClientResourceStop", resourceRoot, release)
addEventHandler("onClientPlayerWasted", localPlayer, release)