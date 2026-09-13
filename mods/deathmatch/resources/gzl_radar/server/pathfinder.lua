local floor = math.floor

local function getAreaID(x, y)
    return floor((y + 3000) / 750) * 8 + floor((x + 3000) / 750)
end

local function getNodeByID(nodeID)
    if not vehicleNodes then return nil end
    local areaID = floor(nodeID / 65536)
    if not vehicleNodes[areaID] then return nil end
    return vehicleNodes[areaID][nodeID]
end

local function findClosestNode(x, y)
    if not vehicleNodes then return nil end
    local areaID = getAreaID(x, y)
    local minDist = nil
    local minNode = nil

    if vehicleNodes[areaID] then
        for id, node in pairs(vehicleNodes[areaID]) do
            local dx = x - node.x
            local dy = y - node.y
            local distSq = dx * dx + dy * dy
            if not minDist or distSq < minDist then
                minDist = distSq
                minNode = node
            end
        end
    end

    if not minNode then
        for aID = 0, 63 do
            if vehicleNodes[aID] then
                for id, node in pairs(vehicleNodes[aID]) do
                    local dx = x - node.x
                    local dy = y - node.y
                    local distSq = dx * dx + dy * dy
                    if not minDist or distSq < minDist then
                        minDist = distSq
                        minNode = node
                    end
                end
            end
        end
    end

    return minNode
end

function calculateRoadRoute(startX, startY, targetX, targetY)
    if not vehicleNodes then return nil end

    local startNode = findClosestNode(startX, startY)
    local targetNode = findClosestNode(targetX, targetY)
    if not startNode or not targetNode then return nil end
    if startNode.id == targetNode.id then
        return { {x = startNode.x, y = startNode.y}, {x = targetNode.x, y = targetNode.y} }
    end

    local g = { [startNode] = 0 }
    local parent = {}
    local openheap = MinHeap.new()

    local function h(node)
        local dx = node.x - targetNode.x
        local dy = node.y - targetNode.y
        local dz = (node.z or 0) - (targetNode.z or 0)
        return dx * dx + dy * dy + dz * dz
    end

    local nodeMT = {
        __lt = function(a, b)
            return (g[a] or 0) + h(a) < (g[b] or 0) + h(b)
        end,
        __le = function(a, b)
            return (g[a] or 0) + h(a) <= (g[b] or 0) + h(b)
        end
    }

    setmetatable(startNode, nodeMT)
    openheap:insertvalue(startNode)

    local current = nil
    local iterations = 0
    local maxIterations = 6000

    while not openheap:empty() and iterations < maxIterations do
        iterations = iterations + 1
        current = openheap:deleteindex(0)

        if current.id == targetNode.id then
            break
        end

        if current.neighbours then
            for neighbourID, distance in pairs(current.neighbours) do
                local successor = getNodeByID(neighbourID)
                if successor then
                    local successor_g = (g[current] or 0) + distance * distance
                    if not g[successor] or g[successor] > successor_g then
                        setmetatable(successor, nodeMT)
                        g[successor] = successor_g
                        openheap:insertvalue(successor)
                        parent[successor] = current
                    end
                end
            end
        end
    end

    if current and current.id == targetNode.id then
        local path = {}
        local curr = current
        while curr do
            table.insert(path, 1, {x = curr.x, y = curr.y})
            curr = parent[curr]
        end
        return path
    end

    return nil
end

local playerLastRouteReq = {}

addEvent("gzl_radar:requestRoute", true)
addEventHandler("gzl_radar:requestRoute", root, function(startX, startY, targetX, targetY)
    local player = client or source
    if not isElement(player) then return end

    local now = getTickCount()
    if playerLastRouteReq[player] and (now - playerLastRouteReq[player] < 350) then
        return
    end
    playerLastRouteReq[player] = now

    startX = tonumber(startX)
    startY = tonumber(startY)
    targetX = tonumber(targetX)
    targetY = tonumber(targetY)
    if not startX or not startY or not targetX or not targetY then return end

    local route = calculateRoadRoute(startX, startY, targetX, targetY)
    triggerClientEvent(player, "gzl_radar:receiveRoute", resourceRoot, route)
end)

addEventHandler("onPlayerQuit", root, function()
    playerLastRouteReq[source] = nil
end)

addEvent("gzl_radar:quitGame", true)
addEventHandler("gzl_radar:quitGame", root, function()
    local player = client or source
    if isElement(player) then
        kickPlayer(player, "Sunucudan başarıyla ayrıldınız.")
    end
end)