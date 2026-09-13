local floor = math.floor

local function ensureVehicleNodes()
	if vehicleNodes then return true end
	local file = fileOpen("vehiclenodes.lua", true)
	if not file then return false end
	local contents = fileRead(file, fileGetSize(file))
	fileClose(file)
	if not contents then return false end
	local loader = loadstring(contents, "@gps/vehiclenodes.lua")
	if not loader then return false end
	local success = pcall(loader)
	if not success then vehicleNodes = nil end
	return success and type(vehicleNodes) == "table"
end



local function getAreaID(x, y)
	return floor((y + 3000)/750)*8 + floor((x + 3000)/750)
end

local function getNodeByID(db, nodeID)
	local areaID = floor(nodeID / 65536)
	return db[areaID] and db[areaID][nodeID]
end

local function findNodeClosestToPoint(db, x, y, z)
	local areaID = getAreaID(x, y)
	if not db[areaID] then return nil end
	local minDist, minNode
	local nodeX, nodeY, dist
	for id,node in pairs(db[areaID]) do
		nodeX, nodeY = node.x, node.y
		dist = (x - nodeX)*(x - nodeX) + (y - nodeY)*(y - nodeY)
		if not minDist or dist < minDist then
			minDist = dist
			minNode = node
		end
	end
	return minNode
end

local function calculatePath(db, nodeFrom, nodeTo)
	if not nodeFrom or not nodeTo then return false end
	local next = next

	local g = { [nodeFrom] = 0 }
	local hcache = {}
	local parent = {}
	local openheap = MinHeap.new()

	local function h(node)
		if hcache[node] then
			return hcache[node]
		end
		local x, y, z = node.x - nodeTo.x, node.y - nodeTo.y, node.z - nodeTo.z
		hcache[node] = x*x + y*y + z*z
		return hcache[node]
	end
	local nodeMT = {
		__lt = function(a, b)
			return g[a] + h(a) <  g[b] + h(b)
		end,
		__le = function(a, b)
			if not g[a] or not g[b] then
				outputConsole(debug.traceback())
			end
			return g[a] + h(a) <= g[b] + h(b)
		end
	}
	setmetatable(nodeFrom, nodeMT)
	openheap:insertvalue(nodeFrom)

	local current
	while not openheap:empty() do
		current = openheap:deleteindex(0)
		if current == nodeTo then
			break
		end

		for id,distance in pairs(current.neighbours) do
			local successor = getNodeByID(db, id)
			local successor_g = g[current] + distance*distance
			if not g[successor] or g[successor] > successor_g then
				setmetatable(successor, nodeMT)

				g[successor] = successor_g
				openheap:insertvalue(successor)
				parent[successor] = current
			end
		end
	end

	for node in pairs(g) do setmetatable(node, nil) end
	if current == nodeTo then
		local path = {}
		repeat
			table.insert(path, 1, current)
			current = parent[current]
		until not current
		return path
	else
		return false
	end
end

function calculatePathByCoords(x1, y1, z1, x2, y2, z2)
	if not tonumber(x1) or not tonumber(y1) or not tonumber(x2) or not tonumber(y2) then
		return false
	end
	if not ensureVehicleNodes() then return false end
	return calculatePath(vehicleNodes, findNodeClosestToPoint(vehicleNodes, tonumber(x1), tonumber(y1), tonumber(z1)),
	findNodeClosestToPoint(vehicleNodes, tonumber(x2), tonumber(y2), tonumber(z2)))
end

function calculatePathByNodeIDs(node1, node2)
	if not tonumber(node1) or not tonumber(node2) then
		return false
	end
	if not ensureVehicleNodes() then return false end
	node1 = getNodeByID(vehicleNodes, tonumber(node1))
	node2 = getNodeByID(vehicleNodes, tonumber(node2))
	if node1 and node2 then
		return calculatePath(vehicleNodes, node1, node2)
	else
		return false
	end
end

local clientRateLimits = {}

local rpcDispatch = {
	calculatePathByCoords = calculatePathByCoords,
	calculatePathByNodeIDs = calculatePathByNodeIDs
}

local function isRateLimited(player)
	local now = getTickCount()
	local rate = clientRateLimits[player]
	if not rate or now - rate.tick >= 1000 then
		clientRateLimits[player] = { tick = now, count = 1 }
		return false
	end
	rate.count = rate.count + 1
	return rate.count > 10
end

addEvent('onServerCall', true)
addEventHandler('onServerCall', root,
	function(fnName, ...)
		if not client or isRateLimited(client) then return end
		local fn = rpcDispatch[fnName]
		if fn then
			fn(...)
		end
	end
)

addEvent('onServerCallback', true)
addEventHandler('onServerCallback', root,
	function(crID, fnName, ...)
		if not client or type(crID) ~= "number" or isRateLimited(client) then return end
		local fn = rpcDispatch[fnName]
		if fn then
			triggerClientEvent(client, 'onServerCallbackReply', resourceRoot, crID, fn(...))
		end
	end
)

addEventHandler('onPlayerQuit', root, function()
	clientRateLimits[source] = nil
end)