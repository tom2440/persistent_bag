ESX = exports["es_extended"]:getSharedObject()

bagEquipped, bagObj = nil, nil
local ox_inventory = exports.ox_inventory
local ped = cache.ped
local playerFullyLoaded = false
local bagInInventory = false
local bagBeforeAppearance = false
local loadingProtection = false
local initialLoadDone = false

function PutOnBag()
    if not playerFullyLoaded or loadingProtection then return end
    loadingProtection = true
    local count = ox_inventory:Search('count', 'duffle2')
    if count < 1 then
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
    if bagEquipped and DoesEntityExist(bagObj) then
        DeleteObject(bagObj)
        bagObj = nil
        bagEquipped = nil
        Wait(100)
    end
    local x, y, z = table.unpack(GetOffsetFromEntityInWorldCoords(ped,0.0,3.0,0.5))
    local modelHash = Config.Models.equipped
    if modelHash < 0 then
        modelHash = modelHash + 4294967296
    end
    if HasModelLoaded(modelHash) then
        SetModelAsNoLongerNeeded(modelHash)
        Wait(50)
    end
    RequestModel(modelHash)
    local timeout = GetGameTimer() + 3000
    local loaded = false
    while GetGameTimer() < timeout do
        if HasModelLoaded(modelHash) then
            loaded = true
            break
        end
        Wait(50)
    end
    if not loaded then
        print("^1[persistent_bag]^7 Impossible de charger le modèle du sac: " .. modelHash)
        loadingProtection = false
        return
    end
    bagObj = CreateObjectNoOffset(modelHash, x, y, z, true, false)
    if DoesEntityExist(bagObj) then
        AttachEntityToEntity(bagObj, ped, GetPedBoneIndex(ped, 24818), -0.05, -0.0870, -0.0, 0.0, 90.0, 175.0, true, true, false, true, 1, true)
        bagEquipped = true
    else
        bagEquipped = nil
    end
    SetModelAsNoLongerNeeded(modelHash)
    loadingProtection = false
end

function RemoveBag()
    if loadingProtection then return end
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

local function IsVehicleInventory(inventoryName)
    if not inventoryName then return false end
    return inventoryName:match('^glove') or inventoryName:match('^trunk') or inventoryName:match('^vehicle')
end

CreateThread(function()
    Wait(2000)
    local modelHash = Config.Models.equipped
    if modelHash < 0 then
        modelHash = modelHash + 4294967296
    end
    RequestModel(modelHash)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(modelHash) and GetGameTimer() < timeout do
        Wait(100)
    end
    if HasModelLoaded(modelHash) then
        print("^2[persistent_bag]^7 Modèle du sac préchargé avec succès")
    else
        print("^1[persistent_bag]^7 Avertissement: Impossible de précharger le modèle du sac")
    end
end)

CreateThread(function()
    while not ESX.IsPlayerLoaded() do
        Wait(100)
    end
    while not IsEntityVisible(PlayerPedId()) do
        Wait(100)
    end
    while GetEntityModel(PlayerPedId()) == 0 do
        Wait(100)
    end
    Wait(500)
    playerFullyLoaded = true
    TriggerEvent('persistent_bag:receiveDroppedBags')
    Wait(100)
    local count = ox_inventory:Search('count', 'duffle2')
    bagInInventory = (count and count > 0)
    initialLoadDone = true
    if bagInInventory and not bagEquipped then
        PutOnBag()
    end
end)

RegisterNetEvent('esx:onPlayerSpawn')
AddEventHandler('esx:onPlayerSpawn', function()
    if not initialLoadDone then return end
    Wait(3000)
    if not bagEquipped then
        local count = ox_inventory:Search('count', 'duffle2')
        if count and count >= 1 then
            PutOnBag()
        else
            bagInInventory = false
        end
    end
end)

RegisterNetEvent('ox_inventory:openInventory')
AddEventHandler('ox_inventory:openInventory', function(data)
    if not playerFullyLoaded then return end
    if data and data.type then
        currentInventory = data.type
    end
end)

RegisterNetEvent('ox_inventory:closeInventory')
AddEventHandler('ox_inventory:closeInventory', function()
    if currentInventory and IsVehicleInventory(currentInventory) then
        Wait(100)
        local count = ox_inventory:Search('count', 'duffle2')
        if IsPedInAnyVehicle(PlayerPedId(), false) then
            local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
            local vehicleClass = GetVehicleClass(vehicle)
            if vehicleClass == 8 or vehicleClass == 13 then
                if count and count >= 1 and not bagEquipped then
                    PutOnBag()
                elseif count < 1 and bagEquipped then
                    RemoveBag()
                end
            else
                if bagEquipped then
                    RemoveBag()
                end
                bagInInventory = (count and count >= 1)
            end
        else
            if count and count >= 1 and not bagEquipped then
                PutOnBag()
            elseif count < 1 and bagEquipped then
                RemoveBag()
            end
        end
    end
    currentInventory = nil
end)

AddEventHandler('ox_inventory:updateInventory', function(changes)
    if not playerFullyLoaded then return end
    if not initialLoadDone then return end
    local count = ox_inventory:Search('count', 'duffle2')
    bagInInventory = (count and count > 0)
    if IsPedInAnyVehicle(PlayerPedId(), false) then
        local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
        local vehicleClass = GetVehicleClass(vehicle)
        if vehicleClass ~= 8 and vehicleClass ~= 13 then
            if bagEquipped then
                RemoveBag()
            end
            return
        end
    end
    if count > 0 and not bagEquipped then
        PutOnBag()
    elseif count < 1 and bagEquipped then
        RemoveBag()
    end
end)

function ResyncBagAfterAppearanceChange()
    if loadingProtection then return end
    loadingProtection = true
    if DoesEntityExist(bagObj) then
        DeleteObject(bagObj)
        bagObj = nil
        bagEquipped = nil
    end
    Wait(500)
    local count = ox_inventory:Search('count', 'duffle2')
    bagInInventory = (count and count > 0)
    if bagInInventory then
        local modelHash = Config.Models.equipped
        if modelHash < 0 then
            modelHash = modelHash + 4294967296
        end
        if not HasModelLoaded(modelHash) then
            RequestModel(modelHash)
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
    Wait(1000)
    if playerFullyLoaded then
        ResyncBagAfterAppearanceChange()
    end
end)

lib.onCache('vehicle', function(value)
    if not playerFullyLoaded or GetResourceState('ox_inventory') ~= 'started' then return end
    Wait(100)
    local count = ox_inventory:Search('count', 'duffle2')
    bagInInventory = (count and count > 0)
    if value then
        local vehicle = value
        local vehicleModel = GetEntityModel(vehicle)
        local vehicleName = GetDisplayNameFromVehicleModel(vehicleModel)
        local vehicleClass = GetVehicleClass(vehicle)
        if vehicleClass == 8 or vehicleClass == 13 or (vehicleName == "POLICEB") then
            if bagInInventory and not bagEquipped then
                PutOnBag()
            elseif not bagInInventory and bagEquipped then
                RemoveBag()
            end
        else
            if bagEquipped then
                RemoveBag()
            end
        end
    else
        if bagInInventory and not bagEquipped then
            PutOnBag()
        elseif not bagInInventory and bagEquipped then
            RemoveBag()
        end
    end
end)

CreateThread(function()
    while true do
        Wait(8000)
        if playerFullyLoaded and initialLoadDone and not loadingProtection then
            local count = ox_inventory:Search('count', 'duffle2')
            local newBagState = (count and count > 0)
            if newBagState ~= bagInInventory then
                bagInInventory = newBagState
                local inStandardVehicle = false
                if IsPedInAnyVehicle(PlayerPedId(), false) then
                    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
                    local vehicleClass = GetVehicleClass(vehicle)
                    local vehicleName = GetDisplayNameFromVehicleModel(GetEntityModel(vehicle))
                    inStandardVehicle = (vehicleClass ~= 8 and vehicleClass ~= 13 and vehicleName ~= "POLICEB")
                end
                if not bagInInventory and bagEquipped then
                    RemoveBag()
                elseif bagInInventory and not bagEquipped and not inStandardVehicle then
                    PutOnBag()
                elseif bagInInventory and bagEquipped and inStandardVehicle then
                    RemoveBag()
                end
            end
        end
    end
end)

RegisterNetEvent('illenium-appearance:client:openUI')
AddEventHandler('illenium-appearance:client:openUI', function()
    bagBeforeAppearance = bagEquipped
    if bagEquipped then
        RemoveBag()
    end
end)

RegisterNetEvent('illenium-appearance:client:closeUI')
AddEventHandler('illenium-appearance:client:closeUI', function()
    Wait(1000)
    if DoesEntityExist(bagObj) then
        DeleteObject(bagObj)
        bagObj = nil
        bagEquipped = nil
    end
    Wait(500)
    local count = ox_inventory:Search('count', 'duffle2')
    if count and count >= 1 then
        PutOnBag()
    end
end)

RegisterNetEvent('illenium-appearance:client:saveOutfit')
AddEventHandler('illenium-appearance:client:saveOutfit', function()
    Wait(500)
    ResyncBagAfterAppearanceChange()
end)

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

CreateThread(function()
    local lastPedModel = GetEntityModel(PlayerPedId())
    local lastPedDrawableVar = {}
    for i = 0, 11 do
        lastPedDrawableVar[i] = GetPedDrawableVariation(PlayerPedId(), i)
    end
    while true do
        Wait(1000)
        if playerFullyLoaded then
            local currentPed = PlayerPedId()
            local currentModel = GetEntityModel(currentPed)
            if currentModel ~= lastPedModel then
                lastPedModel = currentModel
                ResyncBagAfterAppearanceChange()
            else
                local hasChanged = false
                for i = 0, 11 do
                    local currentDrawable = GetPedDrawableVariation(currentPed, i)
                    if currentDrawable ~= lastPedDrawableVar[i] then
                        lastPedDrawableVar[i] = currentDrawable
                        hasChanged = true
                    end
                end
                if hasChanged then
                    ResyncBagAfterAppearanceChange()
                end
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    if bagObj and DoesEntityExist(bagObj) then
        DeleteObject(bagObj)
    end
end)

exports('openBackpack', function(data, slot)
    if not playerFullyLoaded then 
        lib.notify({
            title = Strings.action_incomplete,
            description = "Veuillez attendre que votre personnage soit complètement chargé",
            type = 'error'
        })
        return false
    end
    return DropBag()
end)
