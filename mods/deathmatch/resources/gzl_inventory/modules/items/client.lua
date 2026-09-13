if not lib then return end

local Items = require 'modules.items.shared'

local function displayMetadata(metadata, value)
	local data = metadata
	if type(metadata) == 'string' and value then data = { [metadata] = value } end
	SendNUIMessage({
		action = 'displayMetadata',
		data = data
	})
end
exports('displayMetadata', displayMetadata)

local function getItem(_, name)
	if name then
		name = name:lower()

		if name:sub(0, 7) == 'weapon_' then
			name = name:upper()
		end

		return Items[name]
	end

	return Items
end

setmetatable(Items , {
	__call = getItem
})

local function Item(name, cb)
	local item = Items[name]
	if item then
		if not item.client?.export and not item.client?.event then
			item.effect = cb
		end
	end
end

local ox_inventory = exports[shared.resource]

Item('phone', function(data, slot)
	if exports.gzl_phone and exports.gzl_phone.togglePhone then
		exports.gzl_phone:togglePhone()
	elseif exports.high_phone and exports.high_phone.togglePhone then
		exports.high_phone:togglePhone()
	else
		triggerEvent("gzl_phone:togglePhone", localPlayer)
		triggerEvent("high_phone:togglePhone", localPlayer)
	end
end)

Item('clothing', function(data, slot)
	local metadata = slot.metadata

	if not metadata.drawable then return print('Clothing is missing drawable in metadata') end
	if not metadata.texture then return print('Clothing is missing texture in metadata') end

	if metadata.prop then
		if not SetPedPreloadPropData(cache.ped, metadata.prop, metadata.drawable, metadata.texture) then
			return print('Clothing has invalid prop for this ped')
		end
	elseif metadata.component then
		if not IsPedComponentVariationValid(cache.ped, metadata.component, metadata.drawable, metadata.texture) then
			return print('Clothing has invalid component for this ped')
		end
	else
		return print('Clothing is missing prop/component id in metadata')
	end

	ox_inventory:useItem(data, function(data)
		if data then
			metadata = data.metadata

			if metadata.prop then
				local prop = GetPedPropIndex(cache.ped, metadata.prop)
				local texture = GetPedPropTextureIndex(cache.ped, metadata.prop)

				if metadata.drawable == prop and metadata.texture == texture then
					return ClearPedProp(cache.ped, metadata.prop)
				end

				SetPedPropIndex(cache.ped, metadata.prop, metadata.drawable, metadata.texture, false);
			elseif metadata.component then
				local drawable = GetPedDrawableVariation(cache.ped, metadata.component)
				local texture = GetPedTextureVariation(cache.ped, metadata.component)

				if metadata.drawable == drawable and metadata.texture == texture then
					return
				end

				SetPedComponentVariation(cache.ped, metadata.component, metadata.drawable, metadata.texture, 0);
			end
		end
	end)
end)

exports('Items', function(item) return getItem(nil, item) end)
exports('ItemList', function(item) return getItem(nil, item) end)

return Items