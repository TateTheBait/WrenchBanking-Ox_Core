local file = ('imports/%s.lua'):format(IsDuplicityVersion() and 'server' or 'client')
local import = LoadResourceFile('ox_core', file)
local chunk = assert(load(import, ('@@ox_core/%s'):format(file)))
chunk()



local getbank = function (src)
	local charid = Ox.GetPlayer(src).charId
	local currentbank = MySQL.query.await('SELECT `bank` FROM `characters` WHERE `charid` = ?', {
		charid
	})
	
	return currentbank[1]["bank"]
end

local deposit = function(src, amt)
	local charid = Ox.GetPlayer(src).charId
	if exports.ox_inventory:GetItemCount(src, "cash") >= amt and amt >= 1 then
		local currentbank = getbank(src)
		MySQL.update.await('UPDATE characters SET bank = ? WHERE charId = ?', {
			currentbank + amt, charid
		})
		exports.ox_inventory:RemoveItem(src, "cash", amt)
		TriggerClientEvent('ox_lib:notify', src, {
			type = 'success',
			description = 'You have successfully deposited $'.. amt
		})
	else
		TriggerClientEvent('ox_lib:notify', src, {
			type = 'error',
			description = 'Invalid amount'
		})
	end
end

local withdraw = function(src, amt)
	local charid = Ox.GetPlayer(src).charId
	local currentbank = getbank(src)
	if currentbank >= amt and amt >= 1 then
		MySQL.update.await('UPDATE characters SET bank = ? WHERE charId = ?', {
			currentbank - amt, charid
		})
		exports.ox_inventory:AddItem(src, "cash", amt)
		TriggerClientEvent('ox_lib:notify', src, {
			type = 'success',
			description = 'You have successfully withdrawn $'.. amt
		})
	else
		TriggerClientEvent('ox_lib:notify', src, {
			type = 'error',
			description = 'Invalid amount'
		})
	end
end



local transfer = function (src, target, amt)
	local charid = Ox.GetPlayer(src).charId
	local targid = Ox.GetPlayer(target)


	if targid and charid then
		if not amt or amt <= 0 then
			TriggerClientEvent('ox_lib:notify', src, {
				type = 'error',
				description = 'Invalid amount'
			})
		elseif target == src then
			TriggerClientEvent('ox_lib:notify', src, {
				type = 'error',
				description = 'You cannot transfer money to yourself'
			})
		end
		local currentbank = getbank(src)
		local otherbank = getbank(targid)

		if amt <= currentbank then
			MySQL.update.await('UPDATE characters SET bank = ? WHERE charId = ?', {
				otherbank + amt, targid
			})
			MySQL.update.await('UPDATE characters SET bank = ? WHERE charId = ?', {
				currentbank - amt, charid
			})
			TriggerClientEvent('ox_lib:notify', src, {
				type = 'success',
				description = 'You have successfully transferred $'.. amt
			})
			TriggerClientEvent('ox_lib:notify', target, {
				type = 'success',
				description = 'You just received $'.. amt ..' via bank transfer'
			})
		else
			TriggerClientEvent('ox_lib:notify', src, {
				type = 'error',
				description = 'You don\'t have enough money for this transfer'
			})
		end
	else
		TriggerClientEvent('ox_lib:notify', src, {
			type = 'error',
			description = 'Recipient not found'
		})
	end
end


lib.callback.register('orp_banking:getBalance', function(src)
	local balance = getbank(src)
	return balance
end)



RegisterNetEvent('orp_banking:deposit', function(data)
	local amount = tonumber(data.amount)
	deposit(data.src, amount)
	
	local newbal = getbank(data.src)
	TriggerClientEvent('orp_banking:update', data.src, newbal)
end)

RegisterNetEvent('orp_banking:withdraw', function(data)
	local amount = tonumber(data.amount)
	withdraw(data.src, amount)
	
	local newbal = getbank(data.src)
	TriggerClientEvent('orp_banking:update', data.src, newbal)
end)

RegisterNetEvent('orp_banking:transfer', function(data)
	local amount = tonumber(data.amount)
	local target = data.target

	transfer(data.src, target, amount)
	
	local newbal = getbank(data.src)
	TriggerClientEvent('orp_banking:update', data.src, newbal)
end)
