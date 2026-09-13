local floor = math.floor

local function getAreaID(x, y)
	return math.floor((y + 3000)/750)*8 + math.floor((x + 3000)/750)
end

local function getNodeByID(db, nodeID)
	local areaID = floor(nodeID / 65536)
	return db[areaID][nodeID]
end