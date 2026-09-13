local actors = {}
local processing = false
local processLayers

local function validPed(ped)
    if not isElement(ped) then return false end
    local kind = getElementType(ped)
    return kind == "player" or kind == "ped"
end

local function restore(ped, actor)
    if not validPed(ped) or getPedAnimation(ped) then return end
    for bone, rotation in pairs(actor.base) do
        if rotation[4] then setElementBoneRotation(ped, bone, rotation[1], rotation[2], rotation[3]) end
    end
    updateElementRpHAnim(ped)
end

local function discard(ped)
    local actor = actors[ped]
    if not actor then return end
    restore(ped, actor)
    actors[ped] = nil
    if processing and not next(actors) then
        removeEventHandler("onClientPedsProcessed", root, processLayers)
        processing = false
    end
end

local function blendAngle(from, target, weight)
    return from + ((target - from + 180) % 360 - 180) * weight
end

local function weightAt(layer, now)
    local progress = math.min(1, math.max(0, (now - layer.started) / layer.duration))
    local eased = progress * progress * (3 - 2 * progress)
    return layer.from + (layer.target - layer.from) * eased, progress
end

function setPedAnimationLayer(ped, name, definition)
    if not validPed(ped) or type(name) ~= "string" or #name > 64 or type(definition) ~= "table" or type(definition.bones) ~= "table" then return false end
    local bones = {}
    local count = 0
    for bone, rotation in pairs(definition.bones) do
        if type(bone) ~= "number" or bone < 1 or bone > 54 or bone % 1 ~= 0 or type(rotation) ~= "table" then return false end
        for i = 1, 3 do
            local value = rotation[i]
            if type(value) ~= "number" or value ~= value or math.abs(value) > 3600 then return false end
        end
        bones[bone] = { rotation[1], rotation[2], rotation[3] }
        count = count + 1
    end
    if count == 0 then return false end
    local actor = actors[ped]
    if not actor then actor = { layers = {}, base = {} } actors[ped] = actor end
    local now = getTickCount()
    local owner = sourceResource or getThisResource()
    local oldWeight = 0
    for index, layer in ipairs(actor.layers) do
        if layer.name == name and layer.owner == owner then
            oldWeight = weightAt(layer, now)
            table.remove(actor.layers, index)
            break
        end
    end
    local layer = { name = name, owner = owner, bones = bones, priority = tonumber(definition.priority) or 0, started = now, duration = math.max(1, math.min(3000, tonumber(definition.blendTime) or 300)), from = oldWeight, target = math.max(0, math.min(1, tonumber(definition.weight) or 1)) }
    actor.layers[#actor.layers + 1] = layer
    table.sort(actor.layers, function(a, b) return a.priority < b.priority end)
    for bone in pairs(bones) do if not actor.base[bone] then actor.base[bone] = { 0, 0, 0 } end end
    if not processing then
        addEventHandler("onClientPedsProcessed", root, processLayers, true, "low")
        processing = true
    end
    return true
end

function clearPedAnimationLayer(ped, name, blendTime)
    local actor = actors[ped]
    if not actor then return false end
    local owner = sourceResource or getThisResource()
    local now = getTickCount()
    for _, layer in ipairs(actor.layers) do
        if layer.name == name and layer.owner == owner then
            layer.from = weightAt(layer, now)
            layer.target = 0
            layer.started = now
            layer.duration = math.max(1, math.min(3000, tonumber(blendTime) or 200))
            return true
        end
    end
    return false
end

function hasPedAnimationLayers(ped)
    return actors[ped] ~= nil
end

processLayers = function()
    local now = getTickCount()
    for ped, actor in pairs(actors) do
        if not validPed(ped) or not isElementStreamedIn(ped) then
            discard(ped)
        else
            for index = #actor.layers, 1, -1 do
                local layer = actor.layers[index]
                local weight, progress = weightAt(layer, now)
                layer.weight = weight
                if layer.target == 0 and progress == 1 then table.remove(actor.layers, index) end
            end
            if #actor.layers == 0 then
                discard(ped)
            elseif not isPedDead(ped) and not isPedInVehicle(ped) and not isElementInWater(ped) and isElementOnScreen(ped) and not getPedAnimation(ped) then
                for bone, rotation in pairs(actor.base) do
                    local x, y, z = getElementBoneRotation(ped, bone)
                    if x then rotation[1], rotation[2], rotation[3], rotation[4] = x, y, z, true end
                end
                for _, layer in ipairs(actor.layers) do
                    if layer.weight > 0 then
                        for bone, rotation in pairs(layer.bones) do
                            local x, y, z = getElementBoneRotation(ped, bone)
                            if x then setElementBoneRotation(ped, bone, blendAngle(x, rotation[1], layer.weight), blendAngle(y, rotation[2], layer.weight), blendAngle(z, rotation[3], layer.weight)) end
                        end
                    end
                end
                updateElementRpHAnim(ped)
            end
        end
    end
end

addEventHandler("onClientElementDestroy", root, function() discard(source) end)
addEventHandler("onClientElementStreamOut", root, function() discard(source) end)
addEventHandler("onClientResourceStop", root, function(stopped)
    for ped, actor in pairs(actors) do
        for index = #actor.layers, 1, -1 do
            if actor.layers[index].owner == stopped or stopped == getThisResource() then table.remove(actor.layers, index) end
        end
        if #actor.layers == 0 then discard(ped) end
    end
end)