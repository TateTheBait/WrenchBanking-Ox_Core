local file = ('imports/%s.lua'):format(IsDuplicityVersion() and 'server' or 'client')
local import = LoadResourceFile('ox_core', file)
local chunk = assert(load(import, ('@@ox_core/%s'):format(file)))
chunk()



local getbank = function (src)
	local charid = Ox.GetPlayer(src).charId
	local accid = MySQL.query.await('SELECT `accountId` FROM `accounts_access` WHERE `charId` = ?', {
		charid
	})

	local currentbank = MySQL.query.await('SELECT `balance` FROM `accounts` WHERE `id` = ?', {
		accid[1]["accountId"]
	})
	return currentbank[1]["balance"]
end

local getaccid = function(src)
	local charid =  Ox.GetPlayer(src).charId
	local id = MySQL.query.await('SELECT `accountId` FROM `accounts_access` WHERE `charId` = ?', {
		charid
	})
	return id[1]["accountId"]
end



local deposit = function(src, amt)
	if exports.ox_inventory:GetItemCount(src, "cash") >= amt and amt >= 1 then
		local currentbank = getbank(src)
		local accid = getaccid(src)
		
		MySQL.update.await('UPDATE accounts SET balance = ? WHERE id = ?', {
			currentbank + amt, accid
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
	local accid = getaccid(src)
	local currentbank = getbank(src)
	if currentbank >= amt and amt >= 1 then
		MySQL.update.await('UPDATE accounts SET balance = ? WHERE id = ?', {
			currentbank - amt, accid
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
	local accid = getaccid(src)
	local taccid = getaccid(target)
	if accid and taccid then
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
		local otherbank = getbank(target)

		if amt <= currentbank then
			MySQL.update.await('UPDATE accounts SET balance = ? WHERE id = ?', {
				otherbank + amt, taccid
			})
			MySQL.update.await('UPDATE accounts SET balance = ? WHERE id = ?', {
				currentbank - amt, accid
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
