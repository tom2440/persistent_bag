-----------------For support, scripts, and more----------------
--------------- https://discord.gg/wasabiscripts  -------------
---------------------------------------------------------------
ESX = exports["es_extended"]:getSharedObject()

local registeredStashes = {}
local ox_inventory = exports.ox_inventory


local function GenerateText(num) -- Thnx Linden
	local str
	repeat str = {}
		for i = 1, num do str[i] = string.char(math.random(65, 90)) end
		str = table.concat(str)
	until str ~= 'POL' and str ~= 'EMS'
	return str
end

local function GenerateSerial(text) -- Thnx Again
	if text and text:len() > 3 then
		return text
	end
	return ('%s%s%s'):format(math.random(100000,999999), text == nil and GenerateText(3) or text, math.random(100000,999999))
end

RegisterServerEvent('persistent_bag:openBackpack')
AddEventHandler('persistent_bag:openBackpack', function(identifier)
	if not registeredStashes[identifier] then
        ox_inventory:RegisterStash('bag_'..identifier, 'Sac', Config.BackpackStorage.slots, Config.BackpackStorage.weight, false)
        registeredStashes[identifier] = true
    end
end)

lib.callback.register('persistent_bag:getNewIdentifier', function(source, slot)
	local newId = GenerateSerial()
	ox_inventory:SetMetadata(source, slot, {identifier = newId})
	ox_inventory:RegisterStash('bag_'..newId, 'Sac', Config.BackpackStorage.slots, Config.BackpackStorage.weight, false)
	registeredStashes[newId] = true
	return newId
end)

-- Nouvel événement pour supprimer le sac de l'inventaire
RegisterServerEvent('persistent_bag:removeBagFromInventory')
AddEventHandler('persistent_bag:removeBagFromInventory', function(slot)
    local source = source
    ox_inventory:RemoveItem(source, 'duffle2', 1, nil, slot)
end)

-- Nouvel événement pour ajouter le sac à l'inventaire lors du ramassage
RegisterServerEvent('persistent_bag:addBagToInventory')
AddEventHandler('persistent_bag:addBagToInventory', function(identifier)
    local source = source
    ox_inventory:AddItem(source, 'duffle2', 1, {identifier = identifier})
end)

-- Définir un prix fixe pour le sac à dos
-- Vous pouvez ajuster cette valeur selon le prix réel dans votre serveur
local function GetItemPrice(itemName)
    if itemName == 'duffle2' then
        return Config.BagPrice or 500 -- Utilise Config.BagPrice s'il est défini, sinon 500
    end
    
    -- Prix par défaut pour d'autres items
    return 500
end

-- Commande admin pour récupérer un sac perdu
RegisterCommand('recuperersac', function(source, args, rawCommand)
    local xPlayer = ESX.GetPlayerFromId(source)
    
    -- Vérifier si le joueur est admin
    if xPlayer.getGroup() == 'admin' or xPlayer.getGroup() == 'superadmin' then
        local targetId = tonumber(args[1])
        
        if not targetId then
            TriggerClientEvent('chat:addMessage', source, {
                color = {255, 0, 0},
                multiline = true,
                args = {"ADMIN", "Utilisez la commande ainsi: /recuperersac [ID du joueur]"}
            })
            return
        end
        
        local targetPlayer = ESX.GetPlayerFromId(targetId)
        
        if not targetPlayer then
            TriggerClientEvent('chat:addMessage', source, {
                color = {255, 0, 0},
                multiline = true,
                args = {"ADMIN", "Joueur non trouvé!"}
            })
            return
        end
        
        -- Donner un nouveau sac au joueur avec un nouvel identifiant
        local newId = GenerateSerial()
        local success = ox_inventory:AddItem(targetId, 'duffle2', 1, {identifier = newId})
        
        if success then
            ox_inventory:RegisterStash('bag_'..newId, 'Sac', Config.BackpackStorage.slots, Config.BackpackStorage.weight, false)
            registeredStashes[newId] = true
            
            TriggerClientEvent('chat:addMessage', source, {
                color = {0, 255, 0},
                multiline = true,
                args = {"ADMIN", "Sac à dos donné au joueur ID " .. targetId}
            })
            
            TriggerClientEvent('chat:addMessage', targetId, {
                color = {0, 255, 0},
                multiline = true,
                args = {"SYSTÈME", "Un administrateur vous a donné un nouveau sac à dos. Utilisez PAGE DOWN pour le poser."}
            })
        else
            TriggerClientEvent('chat:addMessage', source, {
                color = {255, 0, 0},
                multiline = true,
                args = {"ADMIN", "Impossible de donner un sac à dos au joueur ID " .. targetId}
            })
        end
    else
        TriggerClientEvent('chat:addMessage', source, {
            color = {255, 0, 0},
            multiline = true,
            args = {"SYSTÈME", "Vous n'avez pas les permissions nécessaires pour utiliser cette commande."}
        })
    end
end, false)

CreateThread(function()
	while GetResourceState('ox_inventory') ~= 'started' do Wait(500) end
	
	local swapHook = ox_inventory:registerHook('swapItems', function(payload)
		local start, destination, move_type = payload.fromInventory, payload.toInventory, payload.toType
		local count_bagpacks = ox_inventory:GetItem(payload.source, 'duffle2', nil, true)
	
		-- Empêcher de mettre un sac à dos dans un autre sac à dos
		if string.find(destination, 'bag_') then
			TriggerClientEvent('ox_lib:notify', payload.source, {type = 'error', title = Strings.action_incomplete, description = Strings.backpack_in_backpack}) 
			return false
		end
		
		-- Limiter à un seul sac dans l'inventaire
		if Config.OneBagInInventory then
			if (count_bagpacks > 0 and move_type == 'player' and destination ~= start) then
				TriggerClientEvent('ox_lib:notify', payload.source, {type = 'error', title = Strings.action_incomplete, description = Strings.one_backpack_only}) 
				return false
			end
		end
		
		return true
	end, {
		print = false,
		itemFilter = {
			duffle2 = true,
		},
	})
	
	local createHook
	if Config.OneBagInInventory then
		createHook = exports.ox_inventory:registerHook('createItem', function(payload)
			local count_bagpacks = ox_inventory:GetItem(payload.inventoryId, 'duffle2', nil, true)
			local playerItems = ox_inventory:GetInventoryItems(payload.inventoryId)
	
	
			if count_bagpacks > 0 then
				local slot = nil
	
				for i,k in pairs(playerItems) do
					if k.name == 'duffle2' then
						slot = k.slot
						break
					end
				end
	
				Citizen.CreateThread(function()
					local inventoryId = payload.inventoryId
					local dontRemove = slot
					Citizen.Wait(1000)
	
					for i,k in pairs(ox_inventory:GetInventoryItems(inventoryId)) do
						if k.name == 'duffle2' and dontRemove ~= nil and k.slot ~= dontRemove then
							local success = ox_inventory:RemoveItem(inventoryId, 'duffle2', 1, nil, k.slot)
							if success then
								-- CORRECTION: Rembourser le joueur quand on supprime automatiquement un deuxième sac
                                local xPlayer = ESX.GetPlayerFromId(inventoryId)
                                if xPlayer then
                                    local bagPrice = GetItemPrice('duffle2')
                                    xPlayer.addMoney(bagPrice)
                                    TriggerClientEvent('ox_lib:notify', inventoryId, {
                                        type = 'info', 
                                        title = 'Remboursement', 
                                        description = 'Vous avez été remboursé de $' .. bagPrice .. ' pour le sac à dos.'
                                    })
                                end
                                
								TriggerClientEvent('ox_lib:notify', inventoryId, {type = 'error', title = Strings.action_incomplete, description = Strings.one_backpack_only}) 
							end
							break
						end
					end
				end)
			end
		end, {
			print = false,
			itemFilter = {
				duffle2 = true
			}
		})
	end
	
	AddEventHandler('onResourceStop', function(resourceName)
        if resourceName ~= GetCurrentResourceName() then return end
        
		ox_inventory:removeHooks(swapHook)
		if Config.OneBagInInventory then
			ox_inventory:removeHooks(createHook)
		end
	end)
end)


-- Événement pour créer un ID et ouvrir le sac
RegisterServerEvent('persistent_bag:createAndOpenBackpack')
AddEventHandler('persistent_bag:createAndOpenBackpack', function(slot)
    local source = source
    
    -- Générer un nouvel identifiant
    local newId = GenerateSerial()
    
    -- Mettre à jour les métadonnées du slot
    ox_inventory:SetMetadata(source, slot, {identifier = newId})
    
    -- Enregistrer le stash
    ox_inventory:RegisterStash('bag_'..newId, 'Sac', Config.BackpackStorage.slots, Config.BackpackStorage.weight, false)
    registeredStashes[newId] = true
    
    -- Ouvrir l'inventaire pour le joueur
    TriggerClientEvent('ox_inventory:openInventory', source, 'stash', 'bag_'..newId)
end)