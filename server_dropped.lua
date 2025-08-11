-----------------For support, scripts, and more----------------
--------------- https://discord.gg/wasabiscripts  -------------
---------------------------------------------------------------

local droppedBags = {}
local ox_inventory = exports.ox_inventory
local ESX = exports["es_extended"]:getSharedObject()

-- Charger les sacs depuis la base de données
local function LoadDroppedBags()
    -- On nettoie la table des sacs avant le chargement
    droppedBags = {}
    
    -- On utilise Async pour s'assurer que l'opération est terminée avant de continuer
    MySQL.query('SELECT * FROM persistent_bags', {}, function(result)
        if result and #result > 0 then
            -- Compteur pour le suivi du chargement
            local loadedBags = 0
            
            -- Message de démarrage du chargement
            print('^2[persistent_bag]^7 Chargement de ' .. #result .. ' sacs posés depuis la BDD...')
            
            -- Pour chaque sac dans la base de données
            for _, bagData in ipairs(result) do
                -- Vérification des données (plus stricte)
                if bagData.bag_id and bagData.identifier and 
                   bagData.coords_x and bagData.coords_y and bagData.coords_z then
                    
                    -- Création du sac avec des coordonnées validées
                    local bag = {
                        bagId = bagData.bag_id,
                        identifier = bagData.identifier,
                        coords = vector3(
                            tonumber(bagData.coords_x) or 0.0,
                            tonumber(bagData.coords_y) or 0.0,
                            tonumber(bagData.coords_z) or 0.0
                        ),
                        heading = tonumber(bagData.heading) or 0.0
                    }
                    
                    -- Ajout du sac à la table des sacs
                    table.insert(droppedBags, bag)
                    loadedBags = loadedBags + 1
                    
                    -- Enregistrement du stash pour ce sac
                    ox_inventory:RegisterStash('bag_' .. bagData.identifier, 'Sac', 
                        Config.BackpackStorage.slots, 
                        Config.BackpackStorage.weight, 
                        false
                    )
                else
                    print('^1[persistent_bag]^7 Données invalides pour le sac ID: ' .. (bagData.id or 'unknown'))
                end
            end
            
            -- Notification du chargement terminé
            print('^2[persistent_bag]^7 ' .. loadedBags .. '/' .. #result .. ' sacs chargés avec succès.')
            
            -- Informer tous les joueurs connectés du chargement des sacs
            TriggerClientEvent('persistent_bag:receiveDroppedBags', -1)
        else
            droppedBags = {}
            print('^2[persistent_bag]^7 Aucun sac posé trouvé dans la BDD.')
        end
    end)
end

-- Créer la table dans la base de données si elle n'existe pas
CreateThread(function()
    MySQL.execute([[
        CREATE TABLE IF NOT EXISTS `persistent_bags` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `bag_id` varchar(100) NOT NULL,
            `identifier` varchar(100) NOT NULL,
            `coords_x` float NOT NULL,
            `coords_y` float NOT NULL,
            `coords_z` float NOT NULL,
            `heading` float NOT NULL,
            PRIMARY KEY (`id`),
            UNIQUE KEY `bag_id` (`bag_id`)
        )
    ]], {}, function()
        print('^2[persistent_bag]^7 Table de base de données vérifiée/créée.')
        LoadDroppedBags()
    end)
end)


-- Ajouter un sac à la base de données
local function AddBagToDB(data)
    if not data or not data.bagId or not data.identifier or not data.coords then
        print('^1[persistent_bag]^7 Données de sac invalides.')
        return false
    end

    -- Vérification des coordonnées pour éviter les valeurs NaN ou infinies
    if not (data.coords.x and data.coords.y and data.coords.z) or
       (math.abs(data.coords.x) > 10000 or math.abs(data.coords.y) > 10000 or math.abs(data.coords.z) > 10000) then
        print('^1[persistent_bag]^7 Coordonnées de sac invalides: ', 
              data.coords.x, data.coords.y, data.coords.z)
        return false
    end

    MySQL.execute([[
        INSERT INTO persistent_bags (bag_id, identifier, coords_x, coords_y, coords_z, heading)
        VALUES (@bag_id, @identifier, @coords_x, @coords_y, @coords_z, @heading)
        ON DUPLICATE KEY UPDATE
        identifier = @identifier, coords_x = @coords_x, coords_y = @coords_y, coords_z = @coords_z, heading = @heading
    ]], {
        ['@bag_id'] = data.bagId,
        ['@identifier'] = data.identifier,
        ['@coords_x'] = data.coords.x,
        ['@coords_y'] = data.coords.y,
        ['@coords_z'] = data.coords.z,
        ['@heading'] = data.heading
    }, function(rowsChanged)
        if rowsChanged and rowsChanged.affectedRows > 0 then
            print('^2[persistent_bag]^7 Sac ' .. data.bagId .. ' ajouté/mis à jour dans la BDD.')
        else
            print('^1[persistent_bag]^7 Erreur lors de l\'ajout du sac dans la BDD.')
        end
    end)

    return true
end

-- Supprimer un sac de la base de données
local function RemoveBagFromDB(bagId)
    if not bagId then return false end

    MySQL.execute('DELETE FROM persistent_bags WHERE bag_id = @bag_id', {
        ['@bag_id'] = bagId
    }, function(rowsChanged)
        if rowsChanged and rowsChanged.affectedRows > 0 then
            print('^2[persistent_bag]^7 Sac ' .. bagId .. ' supprimé de la BDD.')
        else
            print('^1[persistent_bag]^7 Sac non trouvé dans la BDD ou erreur lors de la suppression.')
        end
    end)

    return true
end

-- Ajouter un sac posé
RegisterServerEvent('persistent_bag:addDroppedBag')
AddEventHandler('persistent_bag:addDroppedBag', function(data)
    if not data or not data.bagId or not data.identifier then
        print('^1[persistent_bag]^7 Tentative d\'ajout de données invalides.')
        return
    end

    -- Vérifier que les coordonnées sont valides
    if not data.coords or not data.coords.x or not data.coords.y or not data.coords.z then
        print('^1[persistent_bag]^7 Coordonnées manquantes ou invalides pour le sac ' .. data.bagId)
        return
    end

    -- Ajouter à la liste des sacs en mémoire
    table.insert(droppedBags, {
        bagId = data.bagId,
        identifier = data.identifier,
        coords = data.coords,
        heading = data.heading or 0.0
    })

    -- Ajouter à la base de données
    AddBagToDB(data)

    -- Notifier tous les autres joueurs qu'un nouveau sac a été posé
    TriggerClientEvent('persistent_bag:createDroppedBagForAll', -1, data)
end)

-- Supprimer un sac posé
RegisterServerEvent('persistent_bag:removeDroppedBag')
AddEventHandler('persistent_bag:removeDroppedBag', function(bagId)
    if not bagId then return end
    
    local source = source
    local bagFound = false

    for i, bagData in ipairs(droppedBags) do
        if bagData.bagId == bagId then
            table.remove(droppedBags, i)
            RemoveBagFromDB(bagId)
            bagFound = true

            -- Notifier tous les autres joueurs que le sac a été ramassé
            TriggerClientEvent('persistent_bag:removeDroppedBagForAll', -1, bagId)
            break
        end
    end
    
    if not bagFound then
        print('^3[persistent_bag]^7 Tentative de suppression d\'un sac non trouvé: ' .. bagId .. ' par joueur ID: ' .. source)
    end
end)

-- Recharger tous les sacs (commande admin)
RegisterCommand('recharger_sacs', function(source, args, rawCommand)
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if xPlayer and (xPlayer.getGroup() == 'admin' or xPlayer.getGroup() == 'superadmin') then
        -- Recharger les sacs depuis la base de données
        LoadDroppedBags()
        
        TriggerClientEvent('chat:addMessage', source, {
            color = {0, 255, 0},
            multiline = true,
            args = {"ADMIN", "Rechargement des sacs terminé. Les joueurs doivent voir les sacs maintenant."}
        })
    else
        if source > 0 then -- Ne pas envoyer si c'est la console
            TriggerClientEvent('chat:addMessage', source, {
                color = {255, 0, 0},
                multiline = true,
                args = {"SYSTÈME", "Vous n'avez pas les permissions nécessaires."}
            })
        end
    end
end, false)

-- Récupérer tous les sacs posés au chargement du joueur
lib.callback.register('persistent_bag:getDroppedBags', function(source)
    return droppedBags
end)

-- Rafraîchir les sacs pour un joueur spécifique
RegisterServerEvent('persistent_bag:requestBagsRefresh')
AddEventHandler('persistent_bag:requestBagsRefresh', function()
    local source = source
    TriggerClientEvent('persistent_bag:receiveDroppedBags', source)
end)