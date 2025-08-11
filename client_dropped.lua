-----------------For support, scripts, and more----------------
--------------- https://discord.gg/wasabiscripts  -------------
---------------------------------------------------------------
--ESX = exports["es_extended"]:getSharedObject()

local droppedBags = {}
-- Définition du modèle de sac posé au sol
local ox_inventory = exports.ox_inventory

-- Fonction pour vérifier si le joueur est assez proche du sac
local function IsPlayerNearCoords(coords, distance)
    local playerCoords = GetEntityCoords(PlayerPedId())
    return #(playerCoords - coords) <= distance
end

-- Fonction pour déplacer le joueur vers une position
local function MoveToCoords(coords, callback)
    local timeout = 15000 -- 15 secondes max pour se déplacer
    local startTime = GetGameTimer()
    
    -- Destination à 0.5m du sac (pour l'animation)
    local playerCoords = GetEntityCoords(PlayerPedId())
    local direction = norm(coords - playerCoords)
    local targetCoords = coords - (direction * 0.5)
    
    -- Tâche: se déplacer vers le sac
    TaskGoStraightToCoord(PlayerPedId(), targetCoords.x, targetCoords.y, targetCoords.z, 1.0, timeout, GetEntityHeading(PlayerPedId()), 0.1)
    
    -- Vérifier périodiquement si on est arrivé à destination
    CreateThread(function()
        while true do
            Wait(100)
            
            -- Si le joueur est assez proche ou si le timeout est atteint
            if IsPlayerNearCoords(coords, 1.2) or (GetGameTimer() - startTime) > timeout then
                ClearPedTasks(PlayerPedId())
                
                -- Si on est proche, on exécute le callback
                if IsPlayerNearCoords(coords, 1.2) then
                    if callback then callback() end
                else
                    lib.notify({
                        title = Strings.action_incomplete,
                        description = Strings.too_far_from_bag,
                        type = 'error'
                    })
                end
                
                break
            end
        end
    end)
end

-- Fonction pour normaliser un vecteur
function norm(vector)
    local length = #vector
    if length == 0 then return vector end
    return vector / length
end

-- Créer un sac posé sur le sol
function CreateDroppedBag(data)
    -- Utiliser une méthode plus fiable pour charger le modèle
    local modelHash = GetHashKey(Config.Models.dropped)    
    -- S'assurer que le hash est un nombre positif
    if modelHash < 0 then
        modelHash = modelHash + 4294967296
    end
    
    -- Charger le modèle avec une attente plus longue et des vérifications
    if not HasModelLoaded(modelHash) then
        RequestModel(modelHash)
        
        -- Attendre que le modèle soit chargé avec un timeout de 5 secondes
        local timeout = GetGameTimer() + 5000
        while not HasModelLoaded(modelHash) and GetGameTimer() < timeout do
            Wait(100)
        end
        
        -- Vérifier si le modèle est bien chargé après l'attente
        if not HasModelLoaded(modelHash) then
            print("^1[persistent_bag]^7 Impossible de charger le modèle du sac posé")
            return
        end
    end
    
    local obj = CreateObject(modelHash, data.coords.x, data.coords.y, data.coords.z, false, false, false)
    SetModelAsNoLongerNeeded(modelHash)
    
    if not DoesEntityExist(obj) then
        print("^1[persistent_bag]^7 Échec de la création de l'objet du sac")
        return
    end
    
    PlaceObjectOnGroundProperly(obj)
    FreezeEntityPosition(obj, true)
    SetEntityHeading(obj, data.heading)
    
    droppedBags[data.bagId] = {
        obj = obj,
        coords = data.coords,
        identifier = data.identifier,
        bagId = data.bagId
    }
    
    -- Créer les options d'interaction avec le target
    exports.ox_target:addLocalEntity(obj, {
        {
            name = 'pickup_bag_' .. data.bagId,
            icon = 'fas fa-shopping-bag',
            label = Strings.pickup_bag,
            onSelect = function()
                TriggerPickupSequence(data.bagId)
            end,
            distance = Config.TargetDistance or 3.0
        },
        {
            name = 'open_bag_' .. data.bagId,
            icon = 'fas fa-box-open',
            label = Strings.open_bag,
            onSelect = function()
                TriggerOpenSequence(data.bagId)
            end,
            distance = Config.TargetDistance or 3.0
        }
    })
end

-- Séquence pour ramasser un sac (avec déplacement auto)
function TriggerPickupSequence(bagId)
    if not droppedBags[bagId] then return end
    
    local bagData = droppedBags[bagId]
    local coords = vector3(bagData.coords.x, bagData.coords.y, bagData.coords.z)
    
    -- Si le joueur est déjà assez proche
    if IsPlayerNearCoords(coords, 1.2) then
        PickupBag(bagId)
    else
        -- Déplacer le joueur avant de ramasser
        MoveToCoords(coords, function()
            PickupBag(bagId)
        end)
    end
end

-- Séquence pour ouvrir un sac (avec déplacement auto)
function TriggerOpenSequence(bagId)
    if not droppedBags[bagId] then return end
    
    local bagData = droppedBags[bagId]
    local coords = vector3(bagData.coords.x, bagData.coords.y, bagData.coords.z)
    
    -- Si le joueur est déjà assez proche
    if IsPlayerNearCoords(coords, 1.2) then
        OpenDroppedBag(bagId)
    else
        -- Déplacer le joueur avant d'ouvrir
        MoveToCoords(coords, function()
            OpenDroppedBag(bagId)
        end)
    end
end

-- Poser un sac au sol (appelé depuis client.lua)
function DropBag()
    if not bagEquipped or not bagObj then
        -- lib.notify({
        --     title = Strings.action_incomplete,
        --     description = Strings.no_bag_equipped,
        --     type = 'error'
        -- })
        return false
    end

    -- Utiliser ox_inventory:Search('slots', 'duffle2') pour trouver le sac
    local bagSlots = ox_inventory:Search('slots', 'duffle2')
    
    if not bagSlots or #bagSlots == 0 then
        lib.notify({
            title = Strings.action_incomplete,
            description = Strings.no_bag_found,
            type = 'error'
        })
        return false
    end
    
    -- Utiliser le premier sac trouvé
    local slotInfo = bagSlots[1]
    local slot = slotInfo.slot
    local metadata = slotInfo.metadata or {}
    
    -- Si le sac n'a pas d'identifiant, créons-en un
    if not metadata.identifier then
        local identifier = lib.callback.await('persistent_bag:getNewIdentifier', 100, slot)
        metadata.identifier = identifier
    end
    
    if not metadata.identifier then
        lib.notify({
            title = Strings.action_incomplete,
            description = Strings.no_bag_identifier,
            type = 'error'
        })
        return false
    end

    local playerCoords = GetEntityCoords(PlayerPedId())
    local playerHeading = GetEntityHeading(PlayerPedId())
    local forward = GetEntityForwardVector(PlayerPedId())
    local x, y, z = table.unpack(playerCoords + forward * 0.5) ----------------------------------------

    lib.requestAnimDict('random@domestic', 100)
    TaskPlayAnim(PlayerPedId(), 'random@domestic', 'pickup_low', 8.0, -8.0, -1, 0, 0, false, false, false)
    Wait(1000)
    ClearPedTasks(PlayerPedId())

    if DoesEntityExist(bagObj) then
        DeleteObject(bagObj)
    end
    bagEquipped = nil
    bagObj = nil
    
    -- Retirer le sac de l'inventaire du joueur
    TriggerServerEvent('persistent_bag:removeBagFromInventory', slot)
    
    -- Générer un ID unique pour le sac
    local bagId = "bag_" .. math.random(1, 999999) .. "_" .. metadata.identifier
    
    local bagData = {
        bagId = bagId,
        coords = vector3(x, y, z - 0.95),
        heading = playerHeading,
        identifier = metadata.identifier
    }
    
    -- Créer le sac posé localement
    CreateDroppedBag(bagData)
    
    -- Enregistrer le sac posé côté serveur pour la persistance
    TriggerServerEvent('persistent_bag:addDroppedBag', bagData)
    
    return true
end

-- Ramasser un sac posé
function PickupBag(bagId)
    if not droppedBags[bagId] then return end
    
    lib.requestAnimDict('random@domestic', 100)
    TaskPlayAnim(PlayerPedId(), 'random@domestic', 'pickup_low', 8.0, -8.0, -1, 0, 0, false, false, false)
    Wait(1000)
    ClearPedTasks(PlayerPedId())
    
    local bagData = droppedBags[bagId]
    
    if DoesEntityExist(bagData.obj) then
        DeleteObject(bagData.obj)
    end
    
    -- Ajouter le sac à l'inventaire
    TriggerServerEvent('persistent_bag:addBagToInventory', bagData.identifier)
    
    -- Supprimer le sac posé côté serveur
    TriggerServerEvent('persistent_bag:removeDroppedBag', bagId)
    
    Wait(500)
    local count = ox_inventory:Search('count', 'duffle2')
    if count and count >= 1 and not bagEquipped then
        PutOnBag()
    end
    
    droppedBags[bagId] = nil
end

-- Ouvrir un sac posé
function OpenDroppedBag(bagId)
    if not droppedBags[bagId] then return end
    
    local bagData = droppedBags[bagId]
    TriggerServerEvent('persistent_bag:openBackpack', bagData.identifier)
    ox_inventory:openInventory('stash', 'bag_' .. bagData.identifier)
end

-- Nettoyer les sacs posés lors de l'arrêt de la ressource
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
    for bagId, bagData in pairs(droppedBags) do
        if DoesEntityExist(bagData.obj) then
            DeleteObject(bagData.obj)
        end
    end
end)

-- Recevoir les sacs posés depuis le serveur au chargement
RegisterNetEvent('persistent_bag:receiveDroppedBags')
AddEventHandler('persistent_bag:receiveDroppedBags', function()
    -- Supprimer tous les sacs actuels (au cas où)
    for bagId, bagData in pairs(droppedBags) do
        if DoesEntityExist(bagData.obj) then
            DeleteObject(bagData.obj)
        end
    end
    droppedBags = {}
    
    -- Récupérer tous les sacs depuis le serveur
    local serverBags = lib.callback.await('persistent_bag:getDroppedBags', 100)
    
    -- Créer tous les sacs récupérés
    for _, bagData in ipairs(serverBags) do
        CreateDroppedBag(bagData)
    end
end)

-- Créer un sac posé pour tous les joueurs quand quelqu'un en pose un
RegisterNetEvent('persistent_bag:createDroppedBagForAll')
AddEventHandler('persistent_bag:createDroppedBagForAll', function(bagData)
    if not droppedBags[bagData.bagId] then -- Vérifier que nous n'avons pas déjà ce sac
        CreateDroppedBag(bagData)
    end
end)

-- Supprimer un sac posé pour tous les joueurs quand quelqu'un en ramasse un
RegisterNetEvent('persistent_bag:removeDroppedBagForAll')
AddEventHandler('persistent_bag:removeDroppedBagForAll', function(bagId)
    if droppedBags[bagId] then
        if DoesEntityExist(droppedBags[bagId].obj) then
            DeleteObject(droppedBags[bagId].obj)
        end
        droppedBags[bagId] = nil
    end
end)