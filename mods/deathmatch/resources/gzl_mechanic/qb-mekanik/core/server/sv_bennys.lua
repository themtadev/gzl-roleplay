thombursa = exports['thombursa']:GetCoreObject()

local geldimiaq = false
Citizen.CreateThread(function()
    while not geldimiaq do
        Citizen.Wait(1000)
        if thombursa ~= nil then
            if not geldimiaq then
                if not Vehicles then
                    local vehicles = {}
                    local result = thombursa.Shared.Vehicles
                    for k,v in pairs(result) do
                        table.insert(vehicles, {
                            model = v['model'],
                            price = v['price'],
                        })
                    end

                    Vehicles = vehicles
                    TriggerClientEvent('emin-base:araclarim', -1, vehicles)
                    geldimiaq = true
                end
            end
        end
    end
end)

thombursa.Commands.Add('mekanik', 'yarramı ye ayu', {}, true, function(source, args)
    TriggerClientEvent('jezzy-mekanik-admin', source)
end, 'god')

RegisterServerEvent('np-bennys:attemptPurchase')
AddEventHandler('np-bennys:attemptPurchase', function(admin, type, npcMechanic, mechanic, vehPrice, polis, upgradeLevel)
	if not admin then
		local xPlayer = thombursa.Functions.GetPlayer(source)
		local price = 0
		local buy = false

		if price == 0 or price ==  0.0 then
			TriggerClientEvent("thombursa:Notify", source, "Parça Satın Alındı", 500, 'success')
			buy = true
		else
			if polis then
				buy = true
				TriggerClientEvent("thombursa:Notify", source, "Parça Satın Alındı", 500, 'success')
			elseif type == "repair" then
				if xPlayer.Functions.RemoveMoney('bank', price) then
					buy = true
					addmoney('mechanic', price)
					TriggerClientEvent("thombursa:Notify", source,"Aracın "..price.."$ Karşılığında Tamir Edilmeye başlandı!", 'inform', 2000)
				else
					TriggerClientEvent("thombursa:Notify", source, "Banka Hesabında Yeterli Paran Yok!", 'error', 2000)
				end
			elseif npcMechanic then
				if xPlayer.Functions.RemoveMoney('bank', price) then
					buy = true
					addmoney('mechanic', price / 100 * 15)
					TriggerClientEvent("thombursa:Notify", source, price.."$ Karşılığında Satın Alındı", 'success', 2000)
				else
					TriggerClientEvent("thombursa:Notify", source, "Banka Hesabında Yeterli Paran Yok!", 'error', 2000)
				end
			else
				if removeJobMoney('mechanic', price) then
					buy = true
					TriggerClientEvent("thombursa:Notify", source, price.."$ Karşılığında Satın Alındı", 'success', 2000)
				else
					TriggerClientEvent("thombursa:Notify", source, "Mekanik kasasında Yeterli Para Yok", 'error', 2000)
				end
			end
		end

		if buy then
			TriggerClientEvent("np-bennys:purchaseSuccessful", source)
		else
			TriggerClientEvent("np-bennys:purchaseFailed", source)
		end
	else
		TriggerClientEvent("np-bennys:purchaseSuccessful", source)
	end
end)

RegisterServerEvent('updateVehicle')
AddEventHandler('updateVehicle', function(props)
	exports.oxmysql:execute('UPDATE player_vehicles SET mods = @mods WHERE plate = @plate', {
		['@plate'] = props.plate,
		['@mods'] = json.encode(props)
	})
end)

function addmoney(job, miktar)
	exports.oxmysql:execute('SELECT para FROM jezzy_society WHERE job = @job', {
		['@job'] = job
	}, function(result)
        if result[1] ~= nil then
			local yeniMiktar = thombursa.Shared.Round(result[1].para + miktar)
			exports.oxmysql:execute("UPDATE `jezzy_society` SET `para` = '"..yeniMiktar.."' WHERE `job` = '"..job.."'")
		end
	end)
end

function removeJobMoney(job, price)
	exports.oxmysql:execute('SELECT para FROM jezzy_society WHERE job = @job', {
		['@job'] = job
	}, function(result)
        if result[1] ~= nil then
			local yeniMiktar = thombursa.Shared.Round(result[1].para - miktar)
			if yeniMiktar > 0 then
				return true
			end
		end
		return false
	end)
end