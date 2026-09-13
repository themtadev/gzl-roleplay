local function useExport(resource, export)
	return function(...)
		return exports[resource][export](nil, ...)
	end
end

local ItemList = {}
local isServer = IsDuplicityVersion()

local function newItem(data)
	data.weight = data.weight or 0

	if data.close == nil then
		data.close = true
	end

	if data.stack == nil then
		data.stack = true
	end

	local clientData, serverData = data.client, data.server

	if not data.consume and (clientData and (clientData.status or clientData.usetime or clientData.export) or serverData?.export) then
		data.consume = 1
	end

	if isServer then
		data.client = nil

		if serverData?.export then
			data.cb = useExport(string.strsplit('.', serverData.export))
		end

		if not data.durability then
			if data.degrade or (data.consume and data.consume ~= 0 and data.consume < 1) then
				data.durability = true
			end
		end
	else
		data.server = nil
		data.count = 0

		if clientData?.export then
			data.export = useExport(string.strsplit('.', clientData.export))
		end

		if clientData?.image then
			clientData.image = clientData.image:match('^[%w]+://') and clientData.image or ('%s/%s'):format(client.imagepath, clientData.image)
		end
	end

	ItemList[data.name] = data
end

for type, data in pairs(data('weapons')) do
	for k, v in pairs(data) do
		v.name = k
		v.close = type == 'Ammo' and true or false

		if type == 'Weapons' then

			v.model = v.model or k
			v.hash = joaat(v.model)
			v.stack = v.throwable and true or false
			v.durability = v.durability or 0.05
			v.weapon = true
		else
			v.stack = true
		end

		v[type == 'Ammo' and 'ammo' or type == 'Components' and 'component' or type == 'Tints' and 'tint' or 'weapon'] = true

		if isServer then v.client = nil else
			v.count = 0
			v.server = nil
			local clientData = v.client

			if clientData?.image then
				clientData.image = clientData.image:match('^[%w]+://') and ('url(%s)'):format(clientData.image) or ('url(%s/%s)'):format(client.imagepath, clientData.image)
			end
		end

		ItemList[k] = v
	end
end

for k, v in pairs(data 'items') do
	v.name = k
	newItem(v)
end

ItemList.cash = ItemList.money

return ItemList