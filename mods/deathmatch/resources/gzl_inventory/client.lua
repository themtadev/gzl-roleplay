if not lib then return end

require 'modules.bridge.client'
require 'modules.interface.client'

local Utils = require 'modules.utils.client'
local Weapon = require 'modules.weapon.client'
local currentWeapon

thombursa = exports['thombursa']:GetCoreObject()

exports('getCurrentWeapon', function()
	return currentWeapon
end)

RegisterNetEvent('ox_inventory:disarm', function(noAnim)
	currentWeapon = Weapon.Disarm(currentWeapon, noAnim)
end)

RegisterNetEvent('ox_inventory:clearWeapons', function()
	Weapon.ClearAll(currentWeapon)
end)

local StashTarget

exports('setStashTarget', function(id, owner)
	StashTarget = id and {id=id, owner=owner}
end)

local invBusy = true

local invOpen = false
local plyState = LocalPlayer.state
local IsPedCuffed = IsPedCuffed
local playerPed = cache.ped

lib.onCache('ped', function(ped)
	playerPed = ped
	Utils.WeaponWheel()
end)

plyState:set('invBusy', true, false)
plyState:set('invHotkeys', false, false)

local function canOpenInventory()
	return PlayerData.loaded
	and not invBusy
	and not araniyor
	and not PlayerData.dead

	and invOpen ~= nil
	and (not currentWeapon or currentWeapon.timer == 0)
	and not IsPedCuffed(playerPed)
	and not IsPauseMenuActive()
	and not IsPedFatallyInjured(playerPed)
end

local function canOpenTarget(ped)
	return IsPedFatallyInjured(ped)
	or IsEntityPlayingAnim(ped, 'dead', 'dead_a', 3)
	or IsPedCuffed(ped)
	or IsEntityPlayingAnim(ped, 'mp_arresting', 'idle', 3)
	or IsEntityPlayingAnim(ped, 'missminuteman_1ig_2', 'handsup_base', 3)
	or IsEntityPlayingAnim(ped, 'missminuteman_1ig_2', 'handsup_enter', 3)
	or IsEntityPlayingAnim(ped, 'random@mugging3', 'handsup_standing_base', 3)
end

local defaultInventory = {
	type = 'newdrop',
	slots = shared.playerslots,
	weight = 0,
	maxWeight = shared.playerweight,
	items = {}
}

local currentInventory = defaultInventory

local function closeTrunk()
	if currentInventory?.type == 'trunk' then
		local coords = GetEntityCoords(playerPed, true)

		Utils.PlayAnimAdvanced(0, 'anim@heists@fleeca_bank@scope_out@return_case', 'trevor_action', coords.x, coords.y, coords.z, 0.0, 0.0, GetEntityHeading(playerPed), 2.0, 2.0, 1000, 49, 0.25)

		CreateThread(function()
			local entity = currentInventory.entity
			local door = currentInventory.door
			Wait(900)

			if type(door) == 'table' then
				for i = 1, #door do
					SetVehicleDoorShut(entity, door[i], false)
				end
			else
				SetVehicleDoorShut(entity, door, false)
			end
		end)
	end
end

local CraftingBenches = require 'modules.crafting.client'

function client.openInventory(inv, data)
	if exports["progressbar"]:bussy() == false then
		if inv == "player" then
			TriggerServerEvent('envanteractim-sv', data ,true)
		end
		if invOpen then
			if not inv and currentInventory.type == 'newdrop' then
				return client.closeInventory()
			end

			if IsNuiFocused() then
				if inv == 'container' and currentInventory.id == PlayerData.inventory[data].metadata.container then
					return client.closeInventory()
				end

				if currentInventory.type == 'drop' and (not data or currentInventory.id == (type(data) == 'table' and data.id or data)) then
					return client.closeInventory()
				end

				if inv ~= 'drop' and inv ~= 'container' then
					if (data?.id or data) == currentInventory?.id then
						return warn(("script tried to open inventory, but it is already open\n%s"):format(Citizen.InvokeNative(`FORMAT_STACK_TRACE` & 0xFFFFFFFF, nil, 0, Citizen.ResultAsString())))
					else
						return client.closeInventory()
					end
				end
			end
		elseif IsNuiFocused() then
			Wait(100)

			if IsNuiFocused() then
				warn('other scripts have nui focus and may cause issues (e.g. disable focus, prevent input, overlap inventory window)')
			end
		end

		if inv == 'dumpster' and cache.vehicle then
			return lib.notify({ id = 'inventory_right_access', type = 'error', description = locale('inventory_right_access') })
		end

		if canOpenInventory() then
			local left, right

			if inv == 'player' then
				local targetId, targetPed

				if not data then
					targetId, targetPed = Utils.GetClosestPlayer()
					data = targetId and GetPlayerServerId(targetId)
				else
					local serverId = type(data) == 'table' and data.id or data

					if serverId == cache.serverId then return end

					targetId = serverId and GetPlayerFromServerId(serverId)
					targetPed = targetId and GetPlayerPed(targetId)
				end

				local targetCoords = targetPed and GetEntityCoords(targetPed)

			end

			if inv == 'shop' and invOpen == false then
				if cache.vehicle then
					return lib.notify({ id = 'cannot_perform', type = 'error', description = locale('cannot_perform') })
				end

				left, right = lib.callback.await('ox_inventory:openShop', 200, data)
			elseif invOpen ~= nil then
				if inv == 'policeevidence' then
					local input = lib.inputDialog(locale('police_evidence'), {locale('locker_number')})

					if input then
						input = tonumber(input[1])
					else
						return lib.notify({ description = locale('locker_no_value'), type = 'error' })
					end

					if type(input) ~= 'number' then
						return lib.notify({ description = locale('locker_must_number'), type = 'error' })
					else
						data = input
					end
				end

				left, right = lib.callback.await('ox_inventory:actinmioc', false, inv, data)
			end

			if left then
				if not cache.vehicle then
					if inv == 'player' then
						Utils.PlayAnim(0, 'mp_common', 'givetake1_a', 8.0, 1.0, 2000, 50, 0.0, 0, 0, 0)
					elseif inv ~= 'trunk' then
						Utils.PlayAnim(0, 'pickup_object', 'putdown_low', 5.0, 1.5, 1000, 48, 0.0, 0, 0, 0)
					end
				end

				plyState.invOpen = true

				SetInterval(client.interval, 100)
				SetNuiFocus(true, true)
				SetNuiFocusKeepInput(true)
				closeTrunk()

				if client.screenblur then TriggerScreenblurFadeIn(0) end

				currentInventory = right or defaultInventory
				left.items = PlayerData.inventory
				left.groups = PlayerData.groups

				SendNUIMessage({
					action = 'setupInventory',
					data = {
						leftInventory = left,
						rightInventory = currentInventory
					}
				})

				if not currentInventory.coords and not inv == 'container' then
					currentInventory.coords = GetEntityCoords(playerPed)
				end

				return true
			else

				if left == false then return false end
				if invOpen == false then lib.notify({ id = 'inventory_right_access', type = 'error', description = locale('inventory_right_access') }) end
				if invOpen then client.closeInventory() end
			end
		elseif invBusy then lib.notify({ id = 'inventory_player_access', type = 'error', description = locale('inventory_player_access') }) end
	else
		TriggerEvent('thombursa:Notify', "Şuanda envanteri kullanamazsın!", "error")
	end
end

RegisterNetEvent('ox_inventory:actinmioc', client.openInventory)
exports('actinmioc', client.openInventory)

RegisterNetEvent('ox_inventory:forceOpenInventory', function(left, right)
	if source == '' then return end

	plyState.invOpen = true

	SetInterval(client.interval, 100)
	SetNuiFocus(true, true)
	SetNuiFocusKeepInput(true)
	closeTrunk()

	if client.screenblur then TriggerScreenblurFadeIn(0) end

	currentInventory = right or defaultInventory
	currentInventory.ignoreSecurityChecks = true
	left.items = PlayerData.inventory
	left.groups = PlayerData.groups

	SendNUIMessage({
		action = 'setupInventory',
		data = {
			leftInventory = left,
			rightInventory = currentInventory
		}
	})
end)

local Animations = data 'animations'
local Items = require 'modules.items.client'

lib.callback.register('ox_inventory:usingItem', function(data)
	local item = Items[data.name]

	if item and invBusy then
		if not item.client then return true end

		item = item.client
		plyState.invBusy = true

		if type(item.anim) == 'string' then
			item.anim = Animations.anim[item.anim]
		end

		if item.propTwo then
			item.prop = { item.prop, item.propTwo }
		end

		if item.prop then
			if item.prop[1] then
				for i = 1, #item.prop do
					if type(item.prop) == 'string' then
						item.prop = Animations.prop[item.prop[i]]
					end
				end
			elseif type(item.prop) == 'string' then
				item.prop = Animations.prop[item.prop]
			end
		end

		if not item.disable then
			item.disable = { combat = true }
		elseif item.disable.combat == nil then

			item.disable.combat = true
		end

		local success = (not item.usetime or lib.progressBar({
			duration = item.usetime,
			label = item.label or locale('using', data.metadata.label or data.label),
			useWhileDead = item.useWhileDead,
			canCancel = item.cancel,
			disable = item.disable,
			anim = item.anim or item.scenario,
			prop = item.prop
		})) and not PlayerData.dead

		if success then
			if item.notification then
				lib.notify({ description = item.notification })
			end

			if item.status then
				if client.setPlayerStatus then
					client.setPlayerStatus(item.status)
				end
			end

			return true
		end
	end
end)

local function canUseItem(isAmmo)
	local ped = cache.ped

	return (not isAmmo or currentWeapon)
	and PlayerData.loaded
	and not PlayerData.dead
	and not invBusy
	and not araniyor
	and not lib.progressActive()

	and not IsPedRagdoll(ped)
	and not IsPedFalling(ped)
end

local function useItem(data, cb)
	if invOpen and data.close then client.closeInventory() end
	local slotData, result = PlayerData.inventory[data.slot]

	if canUseItem(data.ammo and true) then
		if currentWeapon and currentWeapon?.timer > 100 then return end

		plyState.invBusy = true
		result = lib.callback.await('ox_inventory:useItem', 200, data.name, data.slot, slotData.metadata)

		if not result then
			Wait(500)
			plyState.invBusy = false
			return
		end
	end

	if cb then
		local success, response = pcall(cb, result and slotData)

		if not success and response then
			print(('^1An error occurred while calling item "%s" callback!\n^1SCRIPT ERROR: %s^0'):format(slotData.name, response))
		end
	end

	Wait(500)
	plyState.invBusy = false
end

AddEventHandler('ox_inventory:item', useItem)
exports('useItem', useItem)

local bekleamk = false

local function useSlot(slot)
	local item = PlayerData.inventory[slot]
	if not item then return end

	local data = Items[item.name]
	if not data then return end

	if canUseItem(data.ammo and true) then
		if data.component and not currentWeapon then
			return lib.notify({ id = 'weapon_hand_required', type = 'error', description = locale('weapon_hand_required') })
		end

		local durability = item.metadata.durability
		local consume = data.consume
		local label = item.metadata.label or item.label

		if durability and durability <= 100 then
			if durability <= 0 then
				if string.match(item.name, "WEAPON_") then
				else
					TriggerServerEvent('ox-base:event:removeItem', item.name, 1, item.slot)
				end
				return lib.notify({ type = 'error', description = locale('no_durability', label) })
			end
		end

		data.slot = slot

		if item.metadata.container then
			return client.openInventory('container', item.slot)
		elseif data.client then
			if invOpen and data.close then client.closeInventory() end

			if data.export then
				return data.export(data, {name = item.name, slot = item.slot, metadata = item.metadata})
			elseif data.client.event then
				return TriggerEvent(data.client.event, data, {name = item.name, slot = item.slot, metadata = item.metadata})
			end
		end

		if data.effect then
			data:effect({name = item.name, slot = item.slot, metadata = item.metadata})
		elseif data.weapon then
			if EnableWeaponWheel then return end

			if IsCinematicCamRendering() then SetCinematicModeActive(false) end

			if currentWeapon then
				local weaponSlot = currentWeapon.slot
				currentWeapon = Weapon.Disarm(currentWeapon)

				if weaponSlot == data.slot then return end
			end

			useItem(data, function(result)
				if result then
					currentWeapon = Weapon.Equip(item, data)

					if client.weaponanims then Wait(500) end
				end
			end)
		elseif currentWeapon then
			if data.ammo then

				eklenecekaq = GetMaxAmmoInClip(playerPed, currentWeapon.hash)
				if EnableWeaponWheel or currentWeapon.metadata.durability <= 0 then return end
				local maxAmmo = 250

				local currentAmmo = GetAmmoInPedWeapon(playerPed, currentWeapon.hash)

					useItem(data, function(data)

						if data then

							if data.name == currentWeapon.ammo then
								if bekleamk == false then

									local missingAmmo = 0
									local newAmmo = currentAmmo + eklenecekaq

									if newAmmo < maxAmmo then

											missingAmmo = maxAmmo - currentAmmo

											SetPedAmmo(playerPed, currentWeapon.hash, newAmmo)

											if not cache.vehicle then

											else

												RefillAmmoInstantly(playerPed)
											end

											currentWeapon.metadata.ammo = newAmmo
											TriggerServerEvent('ox_inventory:updateWeapon', 'load', currentWeapon.metadata.ammo)
											TriggerServerEvent('ox-base:event:removeItem', data.name, 1)
											bekleamk = true
											Wait(0)
											bekleamk = false
											if cache.vehicle then
												Wait(0)
												lib.disableControls:Remove(68)
											end
									else
										lib.notify({
											description = 'Silahın mermisi zaten dolu!',
											type = 'error'
										})
									end
								end
							else
								lib.notify({
									description = 'Bu silaha bu mermiyi takamazsın!',
									type = 'error'
								})
							end
						end
					end)

			elseif data.component then
				local components = data.client.component
				local componentType = data.type
				local weaponComponents = PlayerData.inventory[currentWeapon.slot].metadata.components

				for componentIndex = 1, #weaponComponents do
					if componentType == Items[weaponComponents[componentIndex]].type then

						return lib.notify({ id = 'component_has', type = 'error', description = locale('component_has', data.label) })
					end
				end
				for i = 1, #components do
					local component = components[i]

					if DoesWeaponTakeWeaponComponent(currentWeapon.hash, component) then
						if HasPedGotWeaponComponent(playerPed, currentWeapon.hash, component) then
							lib.notify({ id = 'component_has', type = 'error', description = locale('component_has', data.label) })
						else
							useItem(data, function(data)
								if data then
									GiveWeaponComponentToPed(playerPed, currentWeapon.hash, component)
									table.insert(PlayerData.inventory[currentWeapon.slot].metadata.components, data.name)
									TriggerServerEvent('ox_inventory:updateWeapon', 'component', tostring(data.slot), currentWeapon.slot)
								end
							end)
						end
						return
					end
				end
				lib.notify({ id = 'component_invalid', type = 'error', description = locale('component_invalid', data.label) })
			else
				useItem(data)
			end
		elseif not data.ammo and not data.component then
			useItem(data)
		end
	end
end
exports('useSlot', useSlot)

local function useButton(id, slot)
	if PlayerData.loaded and not invBusy and not lib.progressActive() then
		local item = PlayerData.inventory[slot]
		if not item then return end

		local data = Items[item.name]
		local buttons = data?.buttons

		if buttons and buttons[id]?.action then
			buttons[id].action(slot)
		end
	end
end

local function openNearbyInventory() client.openInventory('player') end

exports('openNearbyInventory', openNearbyInventory)

local currentInstance
local playerCoords
local table = lib.table
local Inventory = require 'modules.inventory.client'
local Shops = require 'modules.shops.client'

function OnPlayerData(key, val)
	if key ~= 'groups' and key ~= 'ped' and key ~= 'dead' then return end

	if key == 'groups' then
		Inventory.Stashes()
		Inventory.Evidence()
		Shops.refreshShops()
	elseif key == 'dead' and val then
		currentWeapon = Weapon.Disarm(currentWeapon)
		client.closeInventory()
	end

	Utils.WeaponWheel()
end

if not Utils or not Weapon or not Items or not Inventory then return end

local invHotkeys = false

local function registerCommands()

	local Vehicles = data 'vehicles'

	local function openGlovebox(vehicle)
		if not IsPedInAnyVehicle(playerPed, false) or not NetworkGetEntityIsNetworked(vehicle) then return end

		local vehicleHash = GetEntityModel(vehicle)
		local vehicleClass = GetVehicleClass(vehicle)
		local checkVehicle = Vehicles.Storage[vehicleHash]

		if (checkVehicle == 0 or checkVehicle == 2) or (not Vehicles.glovebox[vehicleClass] and not Vehicles.glovebox.models[vehicleHash]) then return end

		local isOpen = client.openInventory('glovebox', { id = 'glove'..GetVehicleNumberPlateText(vehicle), netid = NetworkGetNetworkIdFromEntity(vehicle) })

		if isOpen then
			currentInventory.entity = vehicle
		end
	end

	RegisterCommand("inv", function()
		if invOpen then
			return client.closeInventory()
		end

		if invBusy then
			return lib.notify({ id = 'inventory_player_access', type = 'error', description = locale('inventory_player_access') })
		end

		if not canOpenInventory() then
			return lib.notify({ id = 'inventory_player_access', type = 'error', description = locale('inventory_player_access') })
		end

		if StashTarget then
			return client.openInventory('stash', StashTarget)
		end

		if cache.vehicle then
			return openGlovebox(cache.vehicle)
		end

		local entity, entityType = Utils.Raycast(2|16)

		if not entity then
			if invOpen then
				return client.closeInventory()
			end

			if cache.vehicle then
				return openGlovebox(cache.vehicle)
			end

			local closest = lib.points.getClosestPoint()

			if closest and closest.currentDistance < 1.2 and (not closest.instance or closest.instance == currentInstance) then
				if closest.inv == 'crafting' then
					return client.openInventory('crafting', { id = closest.id, index = closest.index })
				elseif closest.inv ~= 'license' and closest.inv ~= 'policeevidence' then
					return client.openInventory(closest.inv or 'drop', { id = closest.invId, type = closest.type })
				end
			end

			return client.openInventory()
		end

		if not shared.target and entityType == 3 then
			local model = GetEntityModel(entity)

			if Inventory.Dumpsters[model] then
				return Inventory.OpenDumpster(entity)
			end
		end

		if entityType ~= 2 then
			if invOpen then
				return client.closeInventory()
			end

			if cache.vehicle then
				return openGlovebox(cache.vehicle)
			end

			local closest = lib.points.getClosestPoint()

			if closest and closest.currentDistance < 1.2 and (not closest.instance or closest.instance == currentInstance) then
				if closest.inv == 'crafting' then
					return client.openInventory('crafting', { id = closest.id, index = closest.index })
				elseif closest.inv ~= 'license' and closest.inv ~= 'policeevidence' then
					return client.openInventory(closest.inv or 'drop', { id = closest.invId, type = closest.type })
				end
			end

			return client.openInventory()
		end

		local position = GetEntityCoords(entity)

		if #(playerCoords - position) > 7 or GetVehiclePedIsEntering(playerPed) ~= 0 or not NetworkGetEntityIsNetworked(entity) then print(2) return end

		local vehicleHash = GetEntityModel(entity)
		local vehicleClass = GetVehicleClass(entity)
		local checkVehicle = Vehicles.Storage[vehicleHash]

		local netId = VehToNet(entity)
		local isTrailer = lib.callback.await('ox_inventory:isVehicleATrailer', false, netId)

		if (checkVehicle == 0 or checkVehicle == 1) or (not Vehicles.trunk[vehicleClass] and not Vehicles.trunk.models[vehicleHash]) then
			if invOpen then
				return client.closeInventory()
			end

			if cache.vehicle then
				return openGlovebox(cache.vehicle)
			end

			local closest = lib.points.getClosestPoint()

			if closest and closest.currentDistance < 1.2 and (not closest.instance or closest.instance == currentInstance) then
				if closest.inv == 'crafting' then
					return client.openInventory('crafting', { id = closest.id, index = closest.index })
				elseif closest.inv ~= 'license' and closest.inv ~= 'policeevidence' then
					return client.openInventory(closest.inv or 'drop', { id = closest.invId, type = closest.type })
				end
			end

			return client.openInventory()
		end

		if GetVehicleDoorLockStatus(entity) > 1 then
			if invOpen then
				return client.closeInventory()
			end

			if cache.vehicle then
				return openGlovebox(cache.vehicle)
			end

			local closest = lib.points.getClosestPoint()

			if closest and closest.currentDistance < 1.2 and (not closest.instance or closest.instance == currentInstance) then
				if closest.inv == 'crafting' then
					return client.openInventory('crafting', { id = closest.id, index = closest.index })
				elseif closest.inv ~= 'license' and closest.inv ~= 'policeevidence' then
					return client.openInventory(closest.inv or 'drop', { id = closest.invId, type = closest.type })
				end
			end
			lib.notify({ id = 'vehicle_locked', type = 'error', description = locale('vehicle_locked') })
			return client.openInventory()
		end

		local door, vehBone

		if checkVehicle == nil then
			if isTrailer then
				door, vehBone = 5, GetEntityBoneIndexByName(entity, 'wheel_rr')
			else
				door, vehBone = 5, GetEntityBoneIndexByName(entity, 'boot')
			end
		elseif checkVehicle == 3 then
			door, vehBone = 4, GetEntityBoneIndexByName(entity, 'bonnet')
		else
			if invOpen then
				return client.closeInventory()
			end

			if cache.vehicle then
				return openGlovebox(cache.vehicle)
			end

			local closest = lib.points.getClosestPoint()

			if closest and closest.currentDistance < 1.2 and (not closest.instance or closest.instance == currentInstance) then
				if closest.inv == 'crafting' then
					return client.openInventory('crafting', { id = closest.id, index = closest.index })
				elseif closest.inv ~= 'license' and closest.inv ~= 'policeevidence' then
					return client.openInventory(closest.inv or 'drop', { id = closest.invId, type = closest.type })
				end
			end

			return client.openInventory()
		end

		if vehBone == -1 then
			if vehicleClass == 12 then
				door = { 2, 3 }
			end

			vehBone = GetEntityBoneIndexByName(entity, Vehicles.trunk.boneIndex[vehicleHash] or 'platelight')
		end

		position = GetWorldPositionOfEntityBone(entity, vehBone)

		if #(playerCoords - position) < 3 and door then
			local plate = GetVehicleNumberPlateText(entity)
			local invId = 'trunk'..plate

			TaskTurnPedToFaceCoord(playerPed, position.x, position.y, position.z, 0)

			if not client.openInventory('trunk', { id = invId, netid = NetworkGetNetworkIdFromEntity(entity) }) then print(5) return end

			if type(door) == 'table' then
				for i = 1, #door do
					SetVehicleDoorOpen(entity, door[i], false, false)
				end
			else
				SetVehicleDoorOpen(entity, door, false, false)
			end

			Wait(200)

			Utils.PlayAnim(0, 'anim@heists@prison_heiststation@cop_reactions', 'cop_b_idle', 3.0, 3.0, -1, 49, 0.0, 0, 0, 0)
			currentInventory.entity = entity
			currentInventory.door = door

			repeat
				Wait(50)

				position = GetWorldPositionOfEntityBone(entity, vehBone)

				if #(GetEntityCoords(playerPed) - position) >= 3 or not DoesEntityExist(entity) then
					break
				end

				TaskTurnPedToFaceCoord(playerPed, position.x, position.y, position.z, 0)
			until currentInventory?.entity ~= entity or not invOpen

			if invOpen then client.closeInventory() end
		end

		if entityType == 2 then
			if invOpen then
				return client.closeInventory()
			end

			if cache.vehicle then
				return openGlovebox(cache.vehicle)
			end

			local closest = lib.points.getClosestPoint()

			if closest and closest.currentDistance < 1.2 and (not closest.instance or closest.instance == currentInstance) then
				if closest.inv == 'crafting' then
					return client.openInventory('crafting', { id = closest.id, index = closest.index })
				elseif closest.inv ~= 'license' and closest.inv ~= 'policeevidence' then
					return client.openInventory(closest.inv or 'drop', { id = closest.invId, type = closest.type })
				end
			end

			return client.openInventory()
		end
	end)

    RegisterKeyMapping('inv', 'İnventory', 'keyboard', 'F2')

	lib.addKeybind({
		name = 'hotbar',
		description = locale('disable_hotbar'),
		defaultKey = client.keys[3],
		onPressed = function()

			SendNUIMessage({ action = 'toggleHotbar' })
		end
	})

	for i = 1, 5 do
		lib.addKeybind({
			name = ('hotkey%s'):format(i),
			description = locale('use_hotbar', i),
			defaultKey = tostring(i),
			onPressed = function()
				if invOpen or IsNuiFocused() or not invHotkeys then return end
				useSlot(i)
			end
		})
	end

	registerCommands = nil
end

function client.closeInventory(server)
	if currentInventory ~= nil then
		if currentInventory.id ~= nil then
			TriggerServerEvent('envanteractim-sv', currentInventory.id, false)
		end
	end
	if not client.interval then return end

	if invOpen then
		invOpen = nil
		SetNuiFocus(false, false)
		SetNuiFocusKeepInput(false)
		TriggerScreenblurFadeOut(0)
		closeTrunk()
		SendNUIMessage({ action = 'closeInventory' })
		SetInterval(client.interval, 200)
		Wait(200)

		if invOpen ~= nil then return end

		if not server and currentInventory then
			TriggerServerEvent('ox_inventory:closeInventory')
		end

		currentInventory = nil
		plyState.invOpen = false
		defaultInventory.coords = nil
	end
end

RegisterNetEvent('ox_inventory:closeInventory', client.closeInventory)
exports('closeInventory', client.closeInventory)

local function updateInventory(data, weight)
	local changes = {}
	local itemCount = {}

	for i = 1, #data do
		local v = data[i]

		if not v.inventory or v.inventory == cache.serverId then
			v.inventory = 'player'
			local item = v.item

			if currentWeapon?.slot == item?.slot and item.metadata then
				currentWeapon.metadata = item.metadata
				TriggerEvent('ox_inventory:currentWeapon', currentWeapon)
			end

			local curItem = PlayerData.inventory[item.slot]

			if curItem?.name then
				itemCount[curItem.name] = (itemCount[curItem.name] or 0) - curItem.count
			end

			if item.count then
				itemCount[item.name] = (itemCount[item.name] or 0) + item.count
			end

			changes[item.slot] = item.count and item or false
			if not item.count then item.name = nil end
			PlayerData.inventory[item.slot] = item.name and item or nil
		end
	end

	SendNUIMessage({ action = 'refreshSlots', data = { items = data, itemCount = itemCount} })
	client.setPlayerData('weight', type(weight) == 'number' and weight or weight.left)

	for item, count in pairs(itemCount) do
		local data = Items[item]

		if count < 0 then
			if currentWeapon and not currentWeapon.throwable and currentWeapon.slot == data.slot then
				currentWeapon = Weapon.Disarm(currentWeapon)
			end

			data.count += count

			if shared.framework == 'esx' then
				TriggerEvent('esx:removeInventoryItem', data.name, data.count)
			else
				TriggerEvent('ox_inventory:itemCount', data.name, data.count)
			end

			if data.client?.remove then
				data.client.remove(data.count)
			end
		elseif count > 0 then
			data.count += count

			if shared.framework == 'esx' then
				TriggerEvent('esx:addInventoryItem', data.name, data.count)
			else
				TriggerEvent('ox_inventory:itemCount', data.name, data.count)
			end

			if data.client?.add then
				data.client.add(data.count)
			end
		end
	end

	client.setPlayerData('inventory', PlayerData.inventory)
	TriggerEvent('ox_inventory:updateInventory', changes)
end

RegisterNetEvent('ox_inventory:updateSlots', function(items, weights)
	if source ~= '' and next(items) then updateInventory(items, weights) end
end)

RegisterNetEvent('ox_inventory:inventoryReturned', function(data)
	if source == '' then return end
	if currentWeapon then currentWeapon = Weapon.Disarm(currentWeapon) end

	lib.notify({ description = locale('items_returned') })
	client.closeInventory()

	local num, items = 0, {}

	for _, slotData in pairs(data[1]) do
		num += 1
		items[num] = { item = slotData, inventory = cache.serverId }
	end

	updateInventory(items, { left = data[3] })
end)

RegisterNetEvent('ox_inventory:inventoryConfiscated', function(message)
	if source == '' then return end
	if message then lib.notify({ description = locale('items_confiscated') }) end
	if currentWeapon then currentWeapon = Weapon.Disarm(currentWeapon) end

	client.closeInventory()

	local num, items = 0, {}

	for slot in pairs(PlayerData.inventory) do
		num += 1
		items[num] = { item = { slot = slot }, inventory = cache.serverId }
	end

	updateInventory(items, { left = 0 })
end)

local function nearbyDrop(point)
	if not point.instance or point.instance == currentInstance then

	end
end

local function onEnterDrop(point)
	if not point.instance or point.instance == currentInstance and not point.entity then
		local model = point.model or client.dropmodel

		lib.requestModel(model)

		local entity = CreateObject(model, point.coords.x, point.coords.y, point.coords.z, false, true, true)

		SetModelAsNoLongerNeeded(model)
		PlaceObjectOnGroundProperly(entity)
		FreezeEntityPosition(entity, true)
		SetEntityCollision(entity, false, true)

		point.entity = entity
	end
end

local function onExitDrop(point)
	local entity = point.entity

	if entity then
		Utils.DeleteEntity(entity)
		point.entity = nil
	end
end

local function createDrop(dropId, data)
	local point = lib.points.new({
		coords = data.coords,
		distance = 16,
		invId = dropId,
		instance = data.instance,
		model = data.model
	})

	if point.model or client.dropprops then
		point.distance = 30
		point.onEnter = onEnterDrop
		point.onExit = onExitDrop
	else
		point.nearby = nearbyDrop
	end

	client.drops[dropId] = point
end

RegisterNetEvent('ox_inventory:createDrop', function(dropId, data, owner, slot)
	if client.drops then
		createDrop(dropId, data)
	end

	if owner == cache.serverId then
		if currentWeapon?.slot == slot then
			currentWeapon = Weapon.Disarm(currentWeapon)
		end

		if invOpen and #(GetEntityCoords(playerPed) - data.coords) <= 1 then
			if not cache.vehicle then
				client.openInventory('drop', dropId)
			else
				SendNUIMessage({
					action = 'setupInventory',
					data = { rightInventory = currentInventory }
				})
			end
		end
	end
end)

RegisterNetEvent('ox_inventory:removeDrop', function(dropId)
	if client.drops then
		local point = client.drops[dropId]

		if point then
			client.drops[dropId] = nil
			point:remove()

			if point.entity then Utils.DeleteEntity(point.entity) end
		end
	end
end)

local uiLoaded = false

local function setStateBagHandler(stateId)
	AddStateBagChangeHandler('invOpen', stateId, function(_, _, value)
		invOpen = value
	end)

	AddStateBagChangeHandler('invBusy', stateId, function(_, _, value)
		invBusy = value
	end)

	AddStateBagChangeHandler('instance', stateId, function(_, _, value)
		currentInstance = value

		for dropId, point in pairs(client.drops) do
			if point.instance then
				if point.instance ~= value then
					if point.entity then
						Utils.DeleteEntity(point.entity)
						point.entity = nil
					end

					point:remove()
				else

					createDrop(dropId, point)
				end
			end
		end
	end)

	AddStateBagChangeHandler('dead', stateId, function(_, _, value)
		Utils.WeaponWheel()
		PlayerData.dead = value
	end)

	AddStateBagChangeHandler('invHotkeys', stateId, function(_, _, value)
		invHotkeys = value
	end)

	setStateBagHandler = nil
end

lib.onCache('vehicle', function(vehicle)
	if invOpen and currentInventory.entity == cache.vehicle then
		return client.closeInventory()
	end
end)

RegisterNetEvent('ox_inventory:setPlayerInventory', function(currentDrops, inventory, weight, player)
	if source == '' then return end

	PlayerData = player
	PlayerData.id = cache.playerId
	PlayerData.source = cache.serverId

	setmetatable(PlayerData, {
		__index = function(self, key)
			if key == 'ped' then
				return PlayerPedId()
			end
		end
	})

	if setStateBagHandler then setStateBagHandler(('player:%s'):format(cache.serverId)) end

	local ItemData = table.create(0, #Items)

	for _, v in pairs(Items ) do
		local buttons = v.buttons and {} or nil

		if buttons then
			for i = 1, #v.buttons do
				buttons[i] = {label = v.buttons[i].label, group = v.buttons[i].group}
			end
		end

		ItemData[v.name] = {
			label = v.label,
			stack = v.stack,
			close = v.close,
			count = 0,
			description = v.description,
			buttons = buttons,
			ammoName = v.ammoname,
			image = v.client?.image
		}
	end

	for _, data in pairs(inventory) do
		local item = Items[data.name]

		if item then
			item.count += data.count
			ItemData[data.name].count += data.count
			local add = item.client?.add

			if add then
				add(item.count)
			end
		end
	end

	client.setPlayerData('inventory', inventory)
	client.setPlayerData('weight', weight)
	currentWeapon = nil
	Weapon.ClearAll()

	local uiLocales = {}
	local locales = lib.getLocales()

	for k, v in pairs(locales) do
		if k:find('^ui_')then
			uiLocales[k] = v
		end
	end

	uiLocales['$'] = locales['$']
	uiLocales.ammo_type = locales.ammo_type

	client.drops = currentDrops

	for dropId, data in pairs(currentDrops) do
		createDrop(dropId, data)
	end

	local hasTextUi = false
	local uiOptions = { icon = 'fa-id-card' }

	while not uiLoaded do Wait(50) end

	SendNUIMessage({
		action = 'init',
		data = {
			locale = uiLocales,
			items = ItemData,
			leftInventory = {
				id = cache.playerId,
				slots = shared.playerslots,
				items = PlayerData.inventory,
				maxWeight = shared.playerweight,
			},
			imagepath = client.imagepath
		}
	})

	PlayerData.loaded = true

	lib.notify({ description = locale('inventory_setup') })
	Shops.refreshShops()
	Inventory.Stashes()
	Inventory.Evidence()

	if registerCommands then registerCommands() end

	TriggerEvent('ox_inventory:updateInventory', PlayerData.inventory)

	client.interval = SetInterval(function()
		if invOpen == false then
			playerCoords = GetEntityCoords(playerPed)

			if currentWeapon and IsPedUsingActionMode(playerPed) then
				SetPedUsingActionMode(playerPed, false, -1, 'DEFAULT_ACTION')
			end

		elseif invOpen == true then
			if not canOpenInventory() then
				client.closeInventory()

			end
		end

		if EnableWeaponWheel then return end

		local weaponHash = GetSelectedPedWeapon(playerPed)

		if currentWeapon then
			if weaponHash ~= currentWeapon.hash and currentWeapon.timer then
				local weaponCount = Items[currentWeapon.name]?.count

				if weaponCount > 0 then
					SetCurrentPedWeapon(playerPed, currentWeapon.hash, true)
					SetAmmoInClip(playerPed, currentWeapon.hash, currentWeapon.metadata.ammo)
					SetPedCurrentWeaponVisible(playerPed, true, false, false, false)

					weaponHash = GetSelectedPedWeapon(playerPed)
				end

				if weaponHash ~= currentWeapon.hash then
					currentWeapon = Weapon.Disarm(currentWeapon, true)
				end
			end
		elseif client.weaponmismatch and not client.ignoreweapons[weaponHash] then
			local weaponType = GetWeapontypeGroup(weaponHash)

			if weaponType ~= 0 and weaponType ~= `GROUP_UNARMED` then
				Weapon.Disarm(currentWeapon, true)
			end
		end
	end, 500)

	local playerId = cache.playerId
	local EnableKeys = client.enablekeys
	local DisablePlayerVehicleRewards = DisablePlayerVehicleRewards
	local DisableAllControlActions = DisableAllControlActions
	local HideHudAndRadarThisFrame = HideHudAndRadarThisFrame
	local EnableControlAction = EnableControlAction
	local DisablePlayerFiring = DisablePlayerFiring
	local HudWeaponWheelIgnoreSelection = HudWeaponWheelIgnoreSelection
	local DisableControlAction = DisableControlAction
	local IsPedShooting = IsPedShooting
	local IsControlJustReleased = IsControlJustReleased

	client.tick = SetInterval(function()
		DisablePlayerVehicleRewards(playerId)

		if invOpen then
			DisableAllControlActions(0)
			HideHudAndRadarThisFrame()

			for i = 1, #EnableKeys do
				EnableControlAction(0, EnableKeys[i], true)
			end

			if currentInventory.type == 'newdrop' then
				EnableControlAction(0, 30, true)
				EnableControlAction(0, 31, true)
			end
		else

			if  IsPedCuffed(playerPed) then
				DisablePlayerFiring(playerId, true)
			end

			if not EnableWeaponWheel then
				HudWeaponWheelIgnoreSelection()
				DisableControlAction(0, 37, true)
			end

			if currentWeapon and IsPedInAnyVehicle(PlayerPedId()) then
				TriggerEvent('ox_inventory:disarm', true)
			end

			if currentWeapon and currentWeapon.timer then
				DisableControlAction(0, 80, true)
				DisableControlAction(0, 140, true)

				if currentWeapon.metadata.durability <= 0 then
					DisablePlayerFiring(playerId, true)
				elseif client.aimedfiring and not currentWeapon.melee and currentWeapon.group ~= `GROUP_PETROLCAN` and not IsPlayerFreeAiming(playerId) then
					DisablePlayerFiring(playerId, true)
				end

				local weaponAmmo = currentWeapon.metadata.ammo

				if not invBusy and currentWeapon.timer ~= 0 and currentWeapon.timer < GetGameTimer() then
					currentWeapon.timer = 0

					if weaponAmmo then
						TriggerServerEvent('ox_inventory:updateWeapon', 'ammo', weaponAmmo)
					elseif currentWeapon.metadata.durability then
						TriggerServerEvent('ox_inventory:updateWeapon', 'melee', currentWeapon.melee)
						currentWeapon.melee = 0
					end
				elseif weaponAmmo then
					if IsPedShooting(playerPed) then
						local currentAmmo
						local durabilityDrain = Items[currentWeapon.name].durability

						if currentWeapon.group == `GROUP_PETROLCAN` or currentWeapon.group == `GROUP_FIREEXTINGUISHER` then
							currentAmmo = weaponAmmo - durabilityDrain < 0 and 0 or weaponAmmo - durabilityDrain
							currentWeapon.metadata.durability = currentAmmo
							currentWeapon.metadata.ammo = (weaponAmmo < currentAmmo) and 0 or currentAmmo

							if currentAmmo <= 0 then
								SetPedInfiniteAmmo(playerPed, false, currentWeapon.hash)
							end
						else
							currentAmmo = GetAmmoInPedWeapon(playerPed, currentWeapon.hash)

							if currentAmmo < weaponAmmo then
								currentAmmo = (weaponAmmo < currentAmmo) and 0 or currentAmmo
								currentWeapon.metadata.ammo = currentAmmo

							end
						end

						if currentAmmo <= 0 then

							currentWeapon.timer = GetGameTimer() + 200
						else currentWeapon.timer = GetGameTimer() + 400 end
					end
				elseif currentWeapon.throwable then
					if not invBusy and IsControlPressed(0, 24) then
						invBusy = 1

						CreateThread(function()
							local weapon = currentWeapon

							while currentWeapon and (not IsPedWeaponReadyToShoot(cache.ped) or IsDisabledControlPressed(0, 24)) and GetSelectedPedWeapon(playerPed) == weapon.hash do
								Wait(0)
							end

							if GetSelectedPedWeapon(playerPed) == weapon.hash then Wait(700) end

							while IsPedPlantingBomb(playerPed) do Wait(0) end

							TriggerServerEvent('ox_inventory:updateWeapon', 'throw', nil, weapon.slot)

							plyState.invBusy = false
							currentWeapon = nil

							RemoveWeaponFromPed(playerPed, weapon.hash)
							TriggerEvent('ox_inventory:currentWeapon')
						end)
					end
				elseif currentWeapon.melee and IsControlJustReleased(0, 24) and IsPedPerformingMeleeAction(playerPed) then
					currentWeapon.melee += 1
					currentWeapon.timer = GetGameTimer() + 200
				end
			end
		end
	end)

	plyState:set('invBusy', false, false)
	plyState:set('invOpen', false, false)
	plyState:set('invHotkeys', true, false)
	collectgarbage('collect')
end)

AddEventHandler('onResourceStop', function(resourceName)
	if shared.resource == resourceName then
		client.onLogout()
	end
end)

RegisterNetEvent('ox_inventory:viewInventory', function(data)
	if data and invOpen == false then
		data.type = 'admin'
		plyState.invOpen = true
		currentInventory = data
		currentInventory.ignoreSecurityChecks = true

		SendNUIMessage({
			action = 'setupInventory',
			data = {
				rightInventory = currentInventory,
			}
		})
		SetNuiFocus(true, true)

		if client.screenblur then TriggerScreenblurFadeIn(0) end
	end
end)

RegisterNUICallback('uiLoaded', function(_, cb)
	uiLoaded = true
	cb(1)
end)

RegisterNUICallback('getItemData', function(itemName, cb)
	cb(Items[itemName])
end)

RegisterNUICallback('removeComponent', function(data, cb)
	cb(1)

	if not currentWeapon then
		return TriggerServerEvent('ox_inventory:updateWeapon', 'component', data)
	end

	if data.slot ~= currentWeapon.slot then
		return lib.notify({ id = 'weapon_hand_wrong', type = 'error', description = locale('weapon_hand_wrong') })
	end

	local itemSlot = PlayerData.inventory[currentWeapon.slot]

	for _, component in pairs(Items[data.component].client.component) do
		if HasPedGotWeaponComponent(playerPed, currentWeapon.hash, component) then
			for k, v in pairs(itemSlot.metadata.components) do
				if v == data.component then
					local success = lib.callback.await('ox_inventory:updateWeapon', false, 'component', k)

					if success then
						RemoveWeaponComponentFromPed(playerPed, currentWeapon.hash, component)
					end

					break
				end
			end
		end
	end
end)

RegisterNUICallback('removeAmmo', function(slot, cb)

end)

RegisterNUICallback('useItem', function(slot, cb)
	useSlot(slot )
	cb(1)
end)

RegisterNUICallback('giveItem', function(data, cb)
	cb(1)
	local target

	if client.giveplayerlist then
		local nearbyPlayers, n = lib.getNearbyPlayers(GetEntityCoords(playerPed), 2.0), 0

		if #nearbyPlayers == 0 then return end

		for i = 1, #nearbyPlayers do
			local option = nearbyPlayers[i]
			local ped = GetPlayerPed(option.id)

			if ped > 0 and IsEntityVisible(ped) then
				local playerName = GetPlayerName(option.id)
				option.id = GetPlayerServerId(option.id)
				option.label = ('[%s] %s'):format(option.id, playerName)
				n += 1
				nearbyPlayers[n] = option
			end
		end

		local p = promise.new()

		lib.registerMenu({
			id = 'ox_inventory:givePlayerList',
			title = 'Give item',
			options = nearbyPlayers,
			onClose = function() p:resolve() end,
		}, function(selected) p:resolve(selected and nearbyPlayers[selected].id) end)

		lib.showMenu('ox_inventory:givePlayerList')

		target = Citizen.Await(p)
	elseif cache.vehicle then
		local seats = GetVehicleMaxNumberOfPassengers(cache.vehicle) - 1

		if seats >= 0 then
			local passenger = GetPedInVehicleSeat(cache.vehicle, cache.seat - 2 * (cache.seat % 2) + 1)

			if passenger ~= 0 and IsEntityVisible(passenger) then
				target = GetPlayerServerId(NetworkGetPlayerIndexFromPed(passenger))
			end
		end
	else
		local entity = Utils.Raycast(12)

		if entity and IsPedAPlayer(entity) and IsEntityVisible(entity) and #(GetEntityCoords(playerPed, true) - GetEntityCoords(entity, true)) < 2.0 then
			target = GetPlayerServerId(NetworkGetPlayerIndexFromPed(entity))
			Utils.PlayAnim(0, 'mp_common', 'givetake1_a', 1.0, 1.0, 2000, 50, 0.0, 0, 0, 0)
		end
	end
    local found, player = GetClosestPlayerMenu()
	if found then
		if data.slot == currentWeapon?.slot then
			currentWeapon = Weapon.Disarm(currentWeapon)
		end

		TriggerServerEvent('ox_inventory:giveItem', data.slot, player, data.count)
	else
		thombursa.Functions.Notify("Yakında oyuncu yok", "error")
	end
end)

function GetClosestPlayerMenu()
	local player, distance = thombursa.Functions.GetClosestPlayer()
	if distance ~= -1 and distance <= 3.0 then
		return true, GetPlayerServerId(player)
	else
		return false
	end
end

RegisterNUICallback('useButton', function(data, cb)
	useButton(data.id, data.slot)
	cb(1)
end)

RegisterNUICallback('exit', function(_, cb)
	client.closeInventory()
	cb(1)
end)

RegisterCommand('f2fix', function()
	client.closeInventory()
end)

lib.callback.register('ox_inventory:startCrafting', function(id, recipe)
	recipe = CraftingBenches[id].items[recipe]

	return lib.progressCircle({
		label = locale('crafting_item', recipe.metadata?.label or Items[recipe.name].label),
		duration = recipe.duration or 3000,
		canCancel = true,
		disable = {
			move = true,
			combat = true,
		},
		anim = {
			dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@',
			clip = 'machinic_loop_mechandplayer',
		}
	})
end)

RegisterNUICallback('swapItems', function(data, cb)
	if data.toType == 'newdrop' then
		if cache.vehicle or IsPedFalling(playerPed) then return cb(false) end

		local coords = GetEntityCoords(playerPed)

		if IsEntityInWater(playerPed) then
			local destination = vec3(coords.x, coords.y, -200)
			local handle = StartShapeTestLosProbe(coords.x, coords.y, coords.z, destination.x, destination.y, destination.z, 511, cache.ped, 4)

			while true do
				Wait(0)
				local retval, hit, endCoords = GetShapeTestResult(handle)

				if retval ~= 1 then
					if not hit then return end

					data.coords = vec3(endCoords.x, endCoords.y, endCoords.z + 1.0)

					break
				end
			end
		else
			data.coords = coords
		end
    end

	if currentInstance then
		data.instance = currentInstance
	end

	if currentWeapon and data.fromType ~= data.toType then
		if (data.fromType == 'player' and data.fromSlot == currentWeapon.slot) or (data.toType == 'player' and data.toSlot == currentWeapon.slot) then
			currentWeapon = Weapon.Disarm(currentWeapon, true)
		end
	end

	local success, response, weaponSlot = lib.callback.await('ox_inventory:swapItems', false, data)

	cb(success or false)

	if success then
		if response then
			if weaponSlot and currentWeapon then
				currentWeapon.slot = weaponSlot
			end

			updateInventory(response.items, response.weight)
		end
	elseif response then
		if type(response) == 'table' then
			SendNUIMessage({ action = 'refreshSlots', data = { items = response } })
		else
			lib.notify({ type = 'error', description = locale(response) })
		end
	end
	if weaponSlot then
		currentWeapon = Weapon.Disarm(currentWeapon, true)
	end
end)

RegisterNUICallback('buyItem', function(data, cb)

	local response, data, message = lib.callback.await('ox_inventory:buyItem', 100, data)

	if data then
		updateInventory({
			{
				item = data[2],
				inventory = cache.serverId
			}
		}, data[4])

		if data[3] then
			SendNUIMessage({
				action = 'refreshSlots',
				data = {
					items = {
						{
							item = data[3],
							inventory = 'shop'
						}
					}
				}
			})
		end
	end

	if message then
		lib.notify(message)
	end

	cb(response)
end)

RegisterNUICallback('craftItem', function(data, cb)
	cb(true)

	local id, index = currentInventory.id, currentInventory.index

	for i = 1, data.count do
		local success, response = lib.callback.await('ox_inventory:craftItem', 200, id, index, data.fromSlot, data.toSlot)

		if not success then
			if response then lib.notify({ type = 'error', description = locale(response or 'cannot_perform') }) end
			break
		end
	end

	if not currentInventory or currentInventory.type ~= 'crafting' then
		client.openInventory('crafting', { id = id, index = index })
	end
end)

lib.callback.register('ox_inventory:getVehicleData', function(netid)
	local entity = NetworkGetEntityFromNetworkId(netid)

	if entity then
		return GetEntityModel(entity), GetVehicleClass(entity)
	end
end)

araniyor = false
RegisterNetEvent('envanteractim')
AddEventHandler('envanteractim', function(acik)
	araniyor = acik
end)

local time = 800
CreateThread(function()
    while true do
        if araniyor then
            time = 1
            local playerPed = PlayerPedId()
            DisablePlayerFiring(playerPed, true)
            SetPedCanPlayGestureAnims(playerPed, false)

            DisableControlAction(0, 24, true)
            DisableControlAction(0, 257, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 263, true)
            DisableControlAction(0, 56, true)

            DisableControlAction(0, 45, true)
            DisableControlAction(0, 22, true)
             DisableControlAction(0, 44, true)
            DisableControlAction(0, 37, true)

            DisableControlAction(0, 288,  true)
            DisableControlAction(0, 289, true)
            DisableControlAction(0, 170, true)
            DisableControlAction(0, 167, true)

            DisableControlAction(0, 31, true)
            DisableControlAction(0, 32, true)
            DisableControlAction(0, 34, true)
            DisableControlAction(0, 30, true)

            DisableControlAction(0, 0, true)
            DisableControlAction(0, 26, true)
            DisableControlAction(0, 73, true)
            DisableControlAction(2, 199, true)

            DisableControlAction(0, 59, true)
            DisableControlAction(0, 71, true)
            DisableControlAction(0, 72, true)

            DisableControlAction(0, 47, true)
            DisableControlAction(0, 264, true)
            DisableControlAction(0, 257, true)
            DisableControlAction(0, 140, true)
            DisableControlAction(0, 141, true)
            DisableControlAction(0, 142, true)
            DisableControlAction(0, 143, true)
            DisableControlAction(0, 75, true)
            DisableControlAction(0, 301, true)
            DisableControlAction(27, 75, true)
		else
			time = 500
        end
        Citizen.Wait(time)
    end
end)

exports('GetAraniyor', function()
	return araniyor
end)