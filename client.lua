-----------------For support, scripts, and more----------------
--------------- https://discord.gg/wasabiscripts  -------------
---------------------------------------------------------------
ESX = exports["es_extended"]:getSharedObject()

-- Définir ces variables sans 'local' pour qu'elles soient accessibles globalement
bagEquipped, bagObj = nil, nil
local ox_inventory = exports.ox_inventory
local ped = cache.ped
local playerFullyLoaded = false
local bagInInventory = false -- Variable pour suivre si le sac est réellement dans l'inventaire
local bagBeforeAppearance = false -- Variable pour tracker l'état du sac avant entrée dans Illenium Appearance
local loadingProtection = false -- Protection contre les appels multiples lors du chargement
local initialLoadDone = false -- Éviter les vérifications pendant le chargement initial

-- Exposer les fonctions PutOnBag et RemoveBag pour client_dropped.lua
function PutOnBag()
    if not playerFullyLoaded or loadingProtection then return end -- Protection contre les appels multiples
    
    -- Marquer comme en cours de chargement
    loadingProtection = true
    
    -- Vérifier si le joueur a réellement un sac dans son inventaire
    local count = ox_inventory:Search('count', 'duffle2')
    if count < 1 then 
        -- Si le sac est affiché mais n'est pas dans l'inventaire, on le retire
        if bagEquipped then 
            if DoesEntityExist(bagObj) then
                DeleteObject(bagObj)
            end
            bagObj = nil
            bagEquipped = nil
        end
        bagInInventory = false
        loadingProtection = false
        return 
    end
    
    bagInInventory = true
    
    -- Vérification stricte: supprimer d'abord si déjà équipé
    if bagEquipped and DoesEntityExist(bagObj) then
        DeleteObject(bagObj)
        bagObj = nil
        bagEquipped = nil
        Wait(100) -- Petit délai pour s'assurer que le nettoyage est complet
    end
    
    -- Créer un nouvel objet
    local x, y, z = table.unpack(GetOffsetFromEntityInWorldCoords(ped,0.0,3.0,0.5))
    
    -- S'assurer que le modèle est bien chargé
    local modelHash = Config.Models.equipped
    
    -- S'assurer que le hash est un nombre positif
    if modelHash < 0 then
        modelHash = modelHash + 4294967296
    end
    
    -- Décharger le modèle d'abord pour éviter les conflits
    if HasModelLoaded(modelHash) then
        SetModelAsNoLongerNeeded(modelHash)
        Wait(50)
    end
    
    -- Demander le modèle avec un timeout plus long
    RequestModel(modelHash)
    
    -- Attendre que le modèle soit bien chargé avec un timeout de 3 secondes
    local timeout = GetGameTimer() + 3000
    local loaded = false
    
    while GetGameTimer() < timeout do
        if HasModelLoaded(modelHash) then
            loaded = true
            break
        end
        Wait(50)
    end
    
    -- Vérifier si le modèle a été chargé avec succès
    if not loaded then
        print("^1[persistent_bag]^7 Impossible de charger le modèle du sac: " .. modelHash)
        loadingProtection = false
        return
    end
    
    -- Créer et attacher l'objet
    bagObj = CreateObjectNoOffset(modelHash, x, y, z, true, false)
    
    if DoesEntityExist(bagObj) then
        AttachEntityToEntity(bagObj, ped, GetPedBoneIndex(ped, 24818), -0.05, -0.0870, -0.0, 0.0, 90.0, 175.0, true, true, false, true, 1, true)
        bagEquipped = true
    else
        bagEquipped = nil
    end
    
    -- Libérer le modèle
    SetModelAsNoLongerNeeded(modelHash)
    
    -- Marquer comme chargé
    loadingProtection = false
end

function RemoveBag()
    if loadingProtection then return end -- Protection contre les appels multiples
    
    loadingProtection = true
    
    if DoesEntityExist(bagObj) then
        DeleteObject(bagObj)
    end
    
    if bagObj then
        SetModelAsNoLongerNeeded(GetEntityModel(bagObj))
    end
    
    bagObj = nil
    bagEquipped = nil
    
    loadingProtection = false
end

-- Fonction pour vérifier si l'inventaire courant est un véhicule
local function IsVehicleInventory(inventoryName)
    if not inventoryName then return false end
    return inventoryName:match('^glove') or inventoryName:match('^trunk') or inventoryName:match('^vehicle')
end

-- Précharger le modèle du sac au démarrage du script
CreateThread(function()
    -- Attendre que le jeu soit complètement chargé
    Wait(2000)
    
    -- Précharger le modèle du sac
    local modelHash = Config.Models.equipped
    
    -- S'assurer que le hash est un nombre positif
    if modelHash < 0 then
        modelHash = modelHash + 4294967296
    end
    
    -- Précharger le modèle
    RequestModel(modelHash)
    
    -- Attendre que le modèle soit chargé (jusqu'à 5 secondes)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(modelHash) and GetGameTimer() < timeout do
        Wait(100)
    end
    
    -- Si le modèle est chargé, le conserver en mémoire
    if HasModelLoaded(modelHash) then
        print("^2[persistent_bag]^7 Modèle du sac préchargé avec succès")
    else
        print("^1[persistent_bag]^7 Avertissement: Impossible de précharger le modèle du sac")
    end
end)

-- Vérifier l'inventaire au démarrage avec un système amélioré
CreateThread(function()
    -- Attendre que ESX soit chargé
    while not ESX.IsPlayerLoaded() do
        Wait(100)
    end
    
    -- Attendre que le joueur apparaisse complètement dans le monde
    while not IsEntityVisible(PlayerPedId()) do
        Wait(100)
    end
    
    -- Attendre que les vêtements et le modèle du joueur soient chargés
    while GetEntityModel(PlayerPedId()) == 0 do
        Wait(100)
    end
    
    -- Attendre un délai plus long pour être vraiment sûr
    Wait(500)
    
    -- Marquer comme chargé
    playerFullyLoaded = true
    
    -- Charger les sacs posés depuis le serveur
    TriggerEvent('persistent_bag:receiveDroppedBags')
    
    -- Vérifier une seule fois au démarrage avec un délai suffisant
    Wait(100)
    
    -- Vérifier si le joueur possède un sac dans son inventaire et l'équiper
    local count = ox_inventory:Search('count', 'duffle2')
    bagInInventory = (count and count > 0)
    
    initialLoadDone = true
    
    if bagInInventory and not bagEquipped then
        PutOnBag()
    end
end)

-- Nouvelle fonction pour gérer les problèmes potentiels de spawn/téléportation
RegisterNetEvent('esx:onPlayerSpawn')
AddEventHandler('esx:onPlayerSpawn', function()
    -- Ne pas s'exécuter pendant le chargement initial
    if not initialLoadDone then return end
    
    Wait(3000) -- Attendre que le spawn soit complètement terminé
    
    if not bagEquipped then
        local count = ox_inventory:Search('count', 'duffle2')
        if count and count >= 1 then
            PutOnBag()
        else
            bagInInventory = false
        end
    end
end)

-- Écouter les événements d'ouverture et fermeture d'inventaire pour gérer correctement les transitions
RegisterNetEvent('ox_inventory:openInventory')
AddEventHandler('ox_inventory:openInventory', function(data)
    if not playerFullyLoaded then return end
    
    -- Stocker l'information sur l'inventaire ouvert
    if data and data.type then
        currentInventory = data.type
    end
end)

RegisterNetEvent('ox_inventory:closeInventory')
AddEventHandler('ox_inventory:closeInventory', function()
    -- Vérifier si nous venons de fermer un inventaire de véhicule
    if currentInventory and IsVehicleInventory(currentInventory) then
        -- Forcer une mise à jour après avoir fermé un inventaire de véhicule
        Wait(100)
        local count = ox_inventory:Search('count', 'duffle2')
        
        -- Si le joueur est dans un véhicule (qui n'est pas une moto/vélo)
        if IsPedInAnyVehicle(PlayerPedId(), false) then
            local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
            local vehicleClass = GetVehicleClass(vehicle)
            
            -- Pour une moto/vélo, on peut afficher le sac
            if vehicleClass == 8 or vehicleClass == 13 then
                if count and count >= 1 and not bagEquipped then
                    PutOnBag()
                elseif count < 1 and bagEquipped then
                    RemoveBag()
                end
            else
                -- Pour les autres véhicules, on s'assure que le sac n'est pas visible
                -- même si le joueur vient de le récupérer dans l'inventaire
                if bagEquipped then
                    RemoveBag()
                end
                -- Mais on garde en mémoire que le joueur a le sac pour l'équiper à la sortie
                bagInInventory = (count and count >= 1)
            end
        else
            -- En dehors d'un véhicule, comportement normal
            if count and count >= 1 and not bagEquipped then
                PutOnBag()
            elseif count < 1 and bagEquipped then
                RemoveBag()
            end
        end
    end
    currentInventory = nil
end)

-- Événement important pour suivre les changements d'inventaire
AddEventHandler('ox_inventory:updateInventory', function(changes)
    if not playerFullyLoaded then return end -- Ne rien faire si le joueur n'est pas complètement chargé
    
    -- Ne pas exécuter pendant l'initialisation
    if not initialLoadDone then return end
    
    -- Forcer une vérification complète de l'inventaire au lieu de se fier uniquement aux changements
    local count = ox_inventory:Search('count', 'duffle2')
    
    -- Mise à jour de la variable de suivi
    bagInInventory = (count and count > 0)
    
    -- Si le joueur est dans un véhicule standard (pas moto/vélo)
    if IsPedInAnyVehicle(PlayerPedId(), false) then
        local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
        local vehicleClass = GetVehicleClass(vehicle)
        
        if vehicleClass ~= 8 and vehicleClass ~= 13 then
            -- Dans un véhicule standard, on s'assure que le sac n'est pas visible
            if bagEquipped then
                RemoveBag()
            end
            return -- On sort de la fonction sans afficher le sac
        end
    end
    
    -- Hors d'un véhicule standard, mise à jour synchronisée avec l'état réel de l'inventaire
    if count > 0 and not bagEquipped then
        PutOnBag()
    elseif count < 1 and bagEquipped then
        RemoveBag()
    end
end)

-- Fonction pour gérer le problème spécifique de désynchronisation avec Illenium Appearance
function ResyncBagAfterAppearanceChange()
    if loadingProtection then return end -- Éviter les conflits
    
    loadingProtection = true
    
    -- Nettoyer complètement l'objet du sac
    if DoesEntityExist(bagObj) then
        DeleteObject(bagObj)
        bagObj = nil
        bagEquipped = nil
    end
    
    -- Attendre que tout soit bien nettoyé
    Wait(500)
    
    -- Vérifier l'état réel de l'inventaire
    local count = ox_inventory:Search('count', 'duffle2')
    bagInInventory = (count and count > 0)
    
    -- Recréer le sac si nécessaire
    if bagInInventory then
        -- S'assurer que le modèle est bien chargé
        local modelHash = Config.Models.equipped
        if modelHash < 0 then
            modelHash = modelHash + 4294967296
        end
        
        if not HasModelLoaded(modelHash) then
            RequestModel(modelHash)
            -- Attendre que le modèle soit bien chargé
            local timeout = GetGameTimer() + 3000
            while not HasModelLoaded(modelHash) and GetGameTimer() < timeout do
                Wait(50)
            end
            
            if not HasModelLoaded(modelHash) then
                print("^1[persistent_bag]^7 Impossible de charger le modèle du sac")
                loadingProtection = false
                return
            end
        end
        
        local x, y, z = table.unpack(GetOffsetFromEntityInWorldCoords(ped,0.0,3.0,0.5))
        bagObj = CreateObjectNoOffset(modelHash, x, y, z, true, false)
        
        if DoesEntityExist(bagObj) then
            AttachEntityToEntity(bagObj, ped, GetPedBoneIndex(ped, 24818), -0.05, -0.0870, -0.0, 0.0, 90.0, 175.0, true, true, false, true, 1, true)
            bagEquipped = true
        else
            bagEquipped = nil
        end
    end
    
    loadingProtection = false
end

lib.onCache('ped', function(value)
    ped = value
    
    -- Attendre un moment après le changement de ped (spawn ou skin change)
    Wait(1000)
    
    -- Vérifier et réappliquer le sac si nécessaire
    if playerFullyLoaded then
        ResyncBagAfterAppearanceChange()
    end
end)

lib.onCache('vehicle', function(value)
    if not playerFullyLoaded or GetResourceState('ox_inventory') ~= 'started' then return end
    
    -- Attendre un peu pour que l'inventaire soit correctement mis à jour
    Wait(100)
    
    -- Toujours vérifier l'état réel de l'inventaire
    local count = ox_inventory:Search('count', 'duffle2')
    -- Mettre à jour notre variable de suivi
    bagInInventory = (count and count > 0)
    
    if value then
        -- Entrer dans un véhicule
        local vehicle = value
        local vehicleModel = GetEntityModel(vehicle)
        local vehicleName = GetDisplayNameFromVehicleModel(vehicleModel)
        local vehicleClass = GetVehicleClass(vehicle)
        
        -- Si c'est une moto, un vélo, ou la moto de police spécifiquement
        if vehicleClass == 8 or vehicleClass == 13 or (vehicleName == "POLICEB") then
            -- Pour toutes les motos et vélos, vérifier si on doit montrer le sac
            if bagInInventory and not bagEquipped then
                PutOnBag()
            elseif not bagInInventory and bagEquipped then
                RemoveBag()
            end
        else
            -- Pour les autres véhicules, enlever le sac quoi qu'il arrive
            if bagEquipped then
                RemoveBag()
            end
        end
    else
        -- Sortir d'un véhicule
        -- Vérifier d'abord si le joueur a un sac
        if bagInInventory and not bagEquipped then
            PutOnBag()
        elseif not bagInInventory and bagEquipped then
            RemoveBag()
        end
    end
end)

-- Vérifier régulièrement la synchronisation entre l'inventaire et l'affichage du sac
CreateThread(function()
    while true do
        Wait(8000) -- Intervalle de 8 secondes pour réduire l'impact sur les performances
        
        if playerFullyLoaded and initialLoadDone and not loadingProtection then
            local count = ox_inventory:Search('count', 'duffle2')
            local newBagState = (count and count > 0)
            
            -- Ne synchroniser que si l'état a réellement changé
            if newBagState ~= bagInInventory then
                bagInInventory = newBagState
                
                -- Vérifier si on est dans un véhicule standard (pas moto/vélo)
                local inStandardVehicle = false
                if IsPedInAnyVehicle(PlayerPedId(), false) then
                    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
                    local vehicleClass = GetVehicleClass(vehicle)
                    local vehicleName = GetDisplayNameFromVehicleModel(GetEntityModel(vehicle))
                    
                    -- Si ce n'est pas une moto/vélo et ce n'est pas une moto de police
                    inStandardVehicle = (vehicleClass ~= 8 and vehicleClass ~= 13 and vehicleName ~= "POLICEB")
                end
                
                -- Corriger la désynchronisation si nécessaire
                if not bagInInventory and bagEquipped then
                    -- Sac visible mais absent de l'inventaire
                    RemoveBag()
                elseif bagInInventory and not bagEquipped and not inStandardVehicle then
                    -- Sac dans l'inventaire mais pas visible (et pas dans un véhicule standard)
                    PutOnBag()
                elseif bagInInventory and bagEquipped and inStandardVehicle then
                    -- Sac visible alors qu'on est dans un véhicule standard
                    RemoveBag()
                end
            end
        end
    end
end)

-- Détecter l'événement d'ouverture et fermeture du menu Illenium Appearance
RegisterNetEvent('illenium-appearance:client:openUI')
AddEventHandler('illenium-appearance:client:openUI', function()
    -- Sauvegarder l'état du sac avant d'entrer dans le menu
    bagBeforeAppearance = bagEquipped
    
    -- Si le sac est équipé, on le retire temporairement pendant le menu
    if bagEquipped then
        RemoveBag()
    end
end)

-- Détecter la fermeture du menu Illenium Appearance
RegisterNetEvent('illenium-appearance:client:closeUI')
AddEventHandler('illenium-appearance:client:closeUI', function()
    -- Attendre un peu plus longtemps pour être sûr que tout est appliqué
    Wait(1000)
    
    -- Force la suppression de tout sac existant
    if DoesEntityExist(bagObj) then
        DeleteObject(bagObj)
        bagObj = nil
        bagEquipped = nil
    end
    
    -- Attendre encore un peu avant de réappliquer
    Wait(500)
    
    -- Vérifier si le joueur a un sac dans l'inventaire et le remettre
    local count = ox_inventory:Search('count', 'duffle2')
    if count and count >= 1 then
        PutOnBag()
    end
end)

-- Ajouter également un handler pour la sauvegarde des vêtements
RegisterNetEvent('illenium-appearance:client:saveOutfit')
AddEventHandler('illenium-appearance:client:saveOutfit', function()
    -- Attendre un peu pour que les nouveaux vêtements soient appliqués
    Wait(500)
    
    -- Forcer une synchronisation complète
    ResyncBagAfterAppearanceChange()
end)

-- Détection supplémentaire pour tous les événements liés aux vêtements d'Illenium
RegisterNetEvent('illenium-appearance:client:changeOutfit')
AddEventHandler('illenium-appearance:client:changeOutfit', function()
    Wait(500)
    ResyncBagAfterAppearanceChange()
end)

RegisterNetEvent('illenium-appearance:client:reloadSkin')
AddEventHandler('illenium-appearance:client:reloadSkin', function()
    Wait(500)
    ResyncBagAfterAppearanceChange()
end)

-- Ajouter un thread spécial pour détecter les changements de vêtements
CreateThread(function()
    local lastPedModel = GetEntityModel(PlayerPedId())
    local lastPedDrawableVar = {}
    
    -- Stocker les valeurs initiales des components
    for i = 0, 11 do
        lastPedDrawableVar[i] = GetPedDrawableVariation(PlayerPedId(), i)
    end
    
    while true do
        Wait(1000) -- Vérifier toutes les secondes
        
        if playerFullyLoaded then
            local currentPed = PlayerPedId()
            local currentModel = GetEntityModel(currentPed)
            
            -- Vérifier si le modèle du ped a changé
            if currentModel ~= lastPedModel then
                lastPedModel = currentModel
                ResyncBagAfterAppearanceChange()
            else
                -- Vérifier les changements de vêtements en comparant les drawable variations
                local hasChanged = false
                for i = 0, 11 do
                    local currentDrawable = GetPedDrawableVariation(currentPed, i)
                    if currentDrawable ~= lastPedDrawableVar[i] then
                        lastPedDrawableVar[i] = currentDrawable
                        hasChanged = true
                    end
                end
                
                -- Si des vêtements ont changé, resynchroniser le sac
                if hasChanged then
                    ResyncBagAfterAppearanceChange()
                end
            end
        end
    end
end)

-- Nettoyer les ressources lors de la déconnexion ou l'arrêt de la ressource
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
    if bagObj and DoesEntityExist(bagObj) then
        DeleteObject(bagObj)
    end
end)

-- Fonction export modifiée pour poser le sac au lieu d'ouvrir l'inventaire
exports('openBackpack', function(data, slot)
    if not playerFullyLoaded then 
        lib.notify({
            title = Strings.action_incomplete,
            description = "Veuillez attendre que votre personnage soit complètement chargé",
            type = 'error'
        })
        return false
    end
    
    -- Poser le sac au sol au lieu d'ouvrir l'inventaire
    return DropBag()
end)