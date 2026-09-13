CylexHold = {}

local heldPeds = {}
local actionState
local movementState
local actionControls = { "fire", "aim_weapon", "action", "next_weapon", "previous_weapon" }
local movementControls = { "forwards", "backwards", "left", "right", "jump", "sprint", "walk", "crouch" }
local pose = {
    bones = {
        [22] = { -28.11, -50.04, -0.58 },
        [23] = { -104.52, -13.94, -0.19 },
        [24] = { -20.23, -55.98, -162.75 },
        [25] = { 22.46, 3.28, -1.22 },
        [5] = { 17.14, 1.38, -0.72 }
    },
    priority = 30,
    blendTime = 350
}

local function layersAvailable()
    local resource = getResourceFromName("gzl_animations")
    return resource and getResourceState(resource) == "running"
end

local function apply(ped)
    if layersAvailable() then
        exports.gzl_animations:setPedAnimationLayer(ped, "cylex_phone:hold", pose)
    end
end

function CylexHold.set(ped, state)
    if not isElement(ped) then heldPeds[ped] = nil return end
    state = state == true and not isPedDead(ped) and not isPedInVehicle(ped)
    if state then
        if heldPeds[ped] then return end
        heldPeds[ped] = true
        local block = getPedAnimation(ped)
        if block == "cylex_phone.hold_phone" then setPedAnimation(ped, false) end
        apply(ped)
    else
        heldPeds[ped] = nil
        if layersAvailable() then exports.gzl_animations:clearPedAnimationLayer(ped, "cylex_phone:hold", 220) end
    end
end

local function restoreControls(saved)
    if saved then for control, enabled in pairs(saved) do toggleControl(control, enabled) end end
end

local function blockControls(controls)
    local saved = {}
    for _, control in ipairs(controls) do
        saved[control] = isControlEnabled(control)
        toggleControl(control, false)
        setPedControlState(localPlayer, control, false)
    end
    return saved
end

function CylexHold.setInput(open, typing)
    if open and not actionState then actionState = blockControls(actionControls) end
    if not open then restoreControls(actionState) actionState = nil end
    if open and typing then
        if not movementState then movementState = blockControls(movementControls) end
    else
        restoreControls(movementState)
        movementState = nil
    end
end

addEventHandler("onClientElementDataChange", root, function(key)
    if key == "cylex_phone:holding" and source ~= localPlayer and getElementType(source) == "player" and isElementStreamedIn(source) then
        CylexHold.set(source, getElementData(source, key) == true)
    end
end)

addEventHandler("onClientElementStreamIn", root, function()
    if getElementType(source) == "player" and getElementData(source, "cylex_phone:holding") then CylexHold.set(source, true) end
end)

addEventHandler("onClientElementStreamOut", root, function() heldPeds[source] = nil end)
addEventHandler("onClientElementDestroy", root, function() heldPeds[source] = nil end)

addEventHandler("onClientResourceStart", root, function(started)
    if started == getThisResource() then
        for _, ped in ipairs(getElementsByType("player", root, true)) do
            if ped ~= localPlayer and getElementData(ped, "cylex_phone:holding") then CylexHold.set(ped, true) end
        end
    elseif started == getResourceFromName("gzl_animations") then
        for ped in pairs(heldPeds) do if isElement(ped) then apply(ped) end end
    end
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    CylexCamera.stop()
    CylexHold.setInput(false, false)
    for ped in pairs(heldPeds) do CylexHold.set(ped, false) end
end)