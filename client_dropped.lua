local droppedBags = {}
local ox_inventory = exports.ox_inventory

local function IsPlayerNearCoords(coords, distance)
    local playerCoords = GetEntityCoords(PlayerPedId())
    return #(playerCoords - coords) <= distance
end

local function MoveToCoords(coords, callback)
    local timeout = 15000
    local startTime = GetGameTimer()
    local playerCoords = GetEntityCoords(PlayerPedId())
    local direction = norm(coords - playerCoords)
    local targetCoords = coords - (direction * 0.5)
    TaskGoStraightToCoord(PlayerPedId(), targetCoords.x, targetCoords.y, targetCoords.z, 1.0, timeout, GetEntityHeading(PlayerPedId()), 0.1)
    CreateThread(function()
        while true do
            Wait(100)
            if IsPlayerNearCoords(coords, 1.2) or (GetGameTimer() - startTime) > timeout then
                ClearPedTasks(PlayerPedId())
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

function norm(vector)
    local length = #vector
    if length == 0 then return vector end
    return vector / length
end

function CreateDroppedBag(data)
    local modelHash = GetHashKey(Config.Models.dropped)
    if modelHash < 0 then
        modelHash = modelHash + 4294967296
    end
    if not HasModelLoaded(modelHash) then
        RequestModel(modelHash)
        local timeout = GetGameTimer() + 5000
        while not HasModelLoaded(modelHash) and GetGameTimer() < timeout do
            Wait(100)
        end
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

function TriggerPickupSequence(bagId)
    if not droppedBags[bagId] then return end
    local bagData = droppedBags[bagId]
    local coords = vector3(bagData.coords.x, bagData.coords.y, bagData.coords.z)
    if IsPlayerNearCoords(coords, 1.2) then
        PickupBag(bagId)
    else
        MoveToCoords(coords, function()
            PickupBag(bagId)
        end)
    end
end

function TriggerOpenSequence(bagId)
    if not droppedBags[bagId] then return end
    local bagData = droppedBags[bagId]
    local coords = vector3(bagData.coords.x, bagData.coords.y, bagData.coords.z)
    if IsPlayerNearCoords(coords, 1.2) then
        OpenDroppedBag(bagId)
    else
        MoveToCoords(coords, function()
            OpenDroppedBag(bagId)
        end)
    end
end

function DropBag()
    if not bagEquipped or not bagObj then
        return false
    end
    local bagSlots = ox_inventory:Search('slots', 'duffle2')
    if not bagSlots or #bagSlots == 0 then
        lib.notify({
            title = Strings.action_incomplete,
            description = Strings.no_bag_found,
            type = 'error'
        })
        return false
    end
    local slotInfo = bagSlots[1]
    local slot = slotInfo.slot
    local metadata = slotInfo.metadata or {}
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
    local x, y, z = table.unpack(playerCoords + forward * 0.5)
    lib.requestAnimDict('random@domestic', 100)
    TaskPlayAnim(PlayerPedId(), 'random@domestic', 'pickup_low', 8.0, -8.0, -1, 0, 0, false, false, false)
    Wait(1000)
    ClearPedTasks(PlayerPedId())
    if DoesEntityExist(bagObj) then
        DeleteObject(bagObj)
    end
    bagEquipped = nil
    bagObj = nil
    TriggerServerEvent('persistent_bag:removeBagFromInventory', slot)
    local bagId = "bag_" .. math.random(1, 999999) .. "_" .. metadata.identifier
    local bagData = {
        bagId = bagId,
        coords = vector3(x, y, z - 0.95),
        heading = playerHeading,
        identifier = metadata.identifier
    }
    CreateDroppedBag(bagData)
    TriggerServerEvent('persistent_bag:addDroppedBag', bagData)
    return true
end

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
    TriggerServerEvent('persistent_bag:addBagToInventory', bagData.identifier)
    TriggerServerEvent('persistent_bag:removeDroppedBag', bagId)
    Wait(500)
    local count = ox_inventory:Search('count', 'duffle2')
    if count and count >= 1 and not bagEquipped then
        PutOnBag()
    end
    droppedBags[bagId] = nil
end

function OpenDroppedBag(bagId)
    if not droppedBags[bagId] then return end
    local bagData = droppedBags[bagId]
    TriggerServerEvent('persistent_bag:openBackpack', bagData.identifier)
    ox_inventory:openInventory('stash', 'bag_' .. bagData.identifier)
end

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    for bagId, bagData in pairs(droppedBags) do
        if DoesEntityExist(bagData.obj) then
            DeleteObject(bagData.obj)
        end
    end
end)

RegisterNetEvent('persistent_bag:receiveDroppedBags')
AddEventHandler('persistent_bag:receiveDroppedBags', function()
    for bagId, bagData in pairs(droppedBags) do
        if DoesEntityExist(bagData.obj) then
            DeleteObject(bagData.obj)
        end
    end
    droppedBags = {}
    local serverBags = lib.callback.await('persistent_bag:getDroppedBags', 100)
    for _, bagData in ipairs(serverBags) do
        CreateDroppedBag(bagData)
    end
end)

RegisterNetEvent('persistent_bag:createDroppedBagForAll')
AddEventHandler('persistent_bag:createDroppedBagForAll', function(bagData)
    if not droppedBags[bagData.bagId] then
        CreateDroppedBag(bagData)
    end
end)

RegisterNetEvent('persistent_bag:removeDroppedBagForAll')
AddEventHandler('persistent_bag:removeDroppedBagForAll', function(bagId)
    if droppedBags[bagId] then
        if DoesEntityExist(droppedBags[bagId].obj) then
            DeleteObject(droppedBags[bagId].obj)
        end
        droppedBags[bagId] = nil
    end
end)
