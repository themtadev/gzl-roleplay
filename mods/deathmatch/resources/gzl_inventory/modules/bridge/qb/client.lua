local onLogout, Weapon = ...
local thombursa = exports['thombursa']:GetCoreObject()
local Inventory = require 'modules.inventory.client'

RegisterNetEvent('thombursa:Client:OnPlayerUnload', onLogout)

RegisterNetEvent('thombursa:Player:SetPlayerData', function(data)
	if source == '' or not PlayerData.loaded then return end

	if (data.metadata.isdead or data.metadata.inlaststand) ~= PlayerData.dead then
		PlayerData.dead = data.metadata.isdead or data.metadata.inlaststand
		OnPlayerData('dead', PlayerData.dead)
	end

	local groups = PlayerData.groups

	if not groups[data.job.name] or not groups[data.gang.name] or groups[data.job.name] ~= data.job.grade.level or groups[data.gang.name] ~= data.gang.grade.level then
		PlayerData.groups = {
			[data.job.name] = data.job.grade.level,
			[data.gang.name] = data.gang.grade.level,
		}

		OnPlayerData('groups', PlayerData.groups)
	end
end)

RegisterNetEvent('police:client:GetCuffed', function()
	PlayerData.cuffed = not PlayerData.cuffed
	LocalPlayer.state:set('invBusy', PlayerData.cuffed, false)

	if not PlayerData.cuffed then return end

	Weapon.Disarm()
end)

function client.setPlayerStatus(values)
	for name, value in pairs(values) do

		if value > 100 or value < -100 then
			value = value * 0.0001
		end

		if name == "hunger" then
			TriggerServerEvent('consumables:server:addHunger', thombursa.Functions.GetPlayerData().metadata.hunger + value)
		elseif name == "thirst" then
			TriggerServerEvent('consumables:server:addThirst', thombursa.Functions.GetPlayerData().metadata.thirst + value)
		elseif name == "stress" then
			if value > 0 then
				TriggerServerEvent('hud:server:GainStress', value)
			end
		end
	end
end

local function hasItem(items, amount)
    amount = amount or 1

    local count = Inventory.Search('count', items)

    if type(items) == 'table' and type(count) == 'table' then
        for _, v in pairs(count) do
            if v < amount then
                return false
            end
        end

        return true
    end

    return count >= amount
end exports("hasItem",hasItem)

AddEventHandler(('__cfx_export_qb-inventory_HasItem'), function(setCB)
	setCB(hasItem)
end)