LiftServer = {}

local activeLifts = {}

function LiftServer.createLift(jobId, liftCfg)
    if not liftCfg then return nil end
    local s = liftCfg.startPos
    local obj = createObject(liftCfg.model, s.x, s.y, s.z, liftCfg.rot.x, liftCfg.rot.y, liftCfg.rot.z)
    if not isElement(obj) then return nil end

    activeLifts[jobId] = {
        element = obj,
        cfg = liftCfg,
        currentZ = s.z,
        state = "idle",
        timer = nil
    }
    return obj
end

function LiftServer.destroyLift(jobId)
    local data = activeLifts[jobId]
    if data then
        if isTimer(data.timer) then killTimer(data.timer) end
        if isElement(data.element) then destroyElement(data.element) end
        activeLifts[jobId] = nil
    end
end

function LiftServer.handleMove(player, jobId, direction)
    local data = activeLifts[jobId]
    if not data or not isElement(data.element) then return end

    if isTimer(data.timer) then
        killTimer(data.timer)
        data.timer = nil
    end

    data.state = direction
    if direction == "stop" then return end

    data.timer = setTimer(function()
        if not isElement(data.element) then return end
        local x, y, z = getElementPosition(data.element)
        local step = data.cfg.speed or 0.12
        local newZ = (data.state == "up") and (z + step) or (z - step)

        if newZ > data.cfg.maxZ then
            newZ = data.cfg.maxZ
            data.state = "stop"
            if isTimer(data.timer) then killTimer(data.timer) end
        elseif newZ < data.cfg.minZ then
            newZ = data.cfg.minZ
            data.state = "stop"
            if isTimer(data.timer) then killTimer(data.timer) end
        end

        setElementPosition(data.element, x, y, newZ)
    end, 50, 0)
end