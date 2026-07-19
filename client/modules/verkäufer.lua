local spawnedPeds = {}
local pendingSpawns = {}
local menuOpen = false
local sellableItemsPromise = nil

local function KeyboardInput(title, maxLength, regex)
    local promise = promise.new()
    exports['hex_menu_api']:inputOpen(GetCurrentResourceName(), 'rageui_input', {
        title = title,
        maxLength = maxLength,
        regex = regex
    }, function(data, menu)
        promise:resolve(data.value)
        menu.close()
    end, function(data, menu)
        promise:resolve(nil)
        menu.close()
    end)
    local result = Citizen.Await(promise)
    Wait(150)
    return result
end

local function SelectFromList(title, options)
    local promise = promise.new()
    local elements = {}
    for _, opt in ipairs(options) do
        elements[#elements + 1] = { title = opt.label, value = opt.value, type = 'button', description = opt.description }
    end
    exports['hex_menu_api']:rageOpen(GetCurrentResourceName(), 'rageui_verkaeufer', {
        title = title,
        elements = elements,
        align = 'left'
    }, function(data, menu)
        promise:resolve(data.current.value)
        menu.close()
    end, function(data, menu)
        promise:resolve(nil)
        menu.close()
    end, function() end)
    local result = Citizen.Await(promise)
    Wait(150)
    return result
end

RegisterNetEvent('forge_farming:verkaeufer:sellableItems')
AddEventHandler('forge_farming:verkaeufer:sellableItems', function(items)
    if not sellableItemsPromise then
        return
    end
    local pending = sellableItemsPromise
    sellableItemsPromise = nil
    pending:resolve(items)
end)

local function RequestSellableItems(pointId)
    sellableItemsPromise = promise.new()
    TriggerServerEvent('forge_farming:verkaeufer:getSellableItems', pointId)
    return Citizen.Await(sellableItemsPromise)
end

local function BuildSellOptions(items)
    local options = {}
    local counts = {}
    for _, entry in ipairs(items) do
        counts[entry.item] = entry.count
        options[#options + 1] = {
            label = Locale('verkaeufer_item_entry', entry.item, entry.count, entry.minPrice, entry.maxPrice),
            value = entry.item
        }
    end
    return options, counts
end

local function OpenVerkaeuferMenu(point)
    exports['hex_menu_api']:rageCloseAll()
    local items = RequestSellableItems(point.id)
    if type(items) ~= 'table' or #items == 0 then
        return
    end
    local options, counts = BuildSellOptions(items)
    local selectedItem = SelectFromList(Locale('verkaeufer_select_item'), options)
    if not selectedItem then
        return
    end
    local input = KeyboardInput(Locale('input_amount'), 4, '^[0-9]+$')
    if not input then
        return
    end
    local amount = tonumber(input)
    if not amount or amount < 1 or amount > (counts[selectedItem] or 0) then
        return
    end
    TriggerServerEvent('forge_farming:verkaeufer:sell', point.id, selectedItem, amount)
end

local function DrawVendorMarker(point)
    local coords = point.coords
    local typeZOffset = point.markerType ~= 1 and (Config.FloatingMarkerZOffset or 1.5) or 0.0
    local z = coords.z + (point.markerHeightOffset or 0.0) + typeZOffset
    DrawMarker(point.markerType, coords.x, coords.y, z,
        0.0, 0.0, 1.0, 0.0, 0.0, 0.0,
        point.markerRadius, point.markerRadius, point.markerRadius * 0.5,
        point.markerColor.r, point.markerColor.g, point.markerColor.b, point.markerColor.a,
        false, true, 2, false, nil, nil, false)
end

local function SpawnVendorPed(point)
    local model = joaat(point.pedModel)
    RequestModel(model)
    local timeout = GetGameTimer() + 10000
    while not HasModelLoaded(model) do
        if GetGameTimer() > timeout then
            pendingSpawns[point.id] = nil
            return
        end
        Wait(10)
    end
    local coords = point.coords
    local ped = CreatePed(4, model, coords.x, coords.y, coords.z, coords.heading, false, true)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetModelAsNoLongerNeeded(model)
    spawnedPeds[point.id] = ped
    pendingSpawns[point.id] = nil
end

local function EnsureVendorPed(point)
    if spawnedPeds[point.id] or pendingSpawns[point.id] then
        return
    end
    pendingSpawns[point.id] = true
    CreateThread(function()
        SpawnVendorPed(point)
    end)
end

local function RenderVendorPoint(point)
    if point.placementMode == 'marker' then
        DrawVendorMarker(point)
        return
    end
    if point.placementMode == 'npc' then
        EnsureVendorPed(point)
    end
end

local function StartMenuSession(point)
    CreateThread(function()
        menuOpen = true
        OpenVerkaeuferMenu(point)
        menuOpen = false
    end)
end

local function GetInteractionCoords(point)
    local ped = spawnedPeds[point.id]
    if point.placementMode == 'npc' and ped and ped ~= -1 and DoesEntityExist(ped) then
        return GetEntityCoords(ped)
    end
    return vector3(point.coords.x, point.coords.y, point.coords.z)
end

CreateThread(function()
    while true do
        local sleep = 500
        local playerCoords = GetEntityCoords(PlayerPedId())
        local closestPoint = nil
        local closestDistance = Config.InteractionDistance
        for _, point in pairs(ClientFarmPoints or {}) do
            if point.type == 'verkaeufer' then
                local coords = point.coords
                local drawDistance = #(playerCoords - vector3(coords.x, coords.y, coords.z))
                if drawDistance <= 30.0 then
                    sleep = 0
                    RenderVendorPoint(point)
                    local interactionDistance = #(playerCoords - GetInteractionCoords(point))
                    if interactionDistance <= closestDistance then
                        closestDistance = interactionDistance
                        closestPoint = point
                    end
                end
            end
        end
        if closestPoint and not menuOpen then
            TriggerEvent('fc_hud:helpNotify', 'E', Locale('verkaeufer_menu_title'))
            if IsControlJustPressed(0, 38) then
                StartMenuSession(closestPoint)
            end
        end
        Wait(sleep)
    end
end)

CreateThread(function()
    while true do
        Wait(5000)
        for pointId, ped in pairs(spawnedPeds) do
            local point = ClientFarmPoints and ClientFarmPoints[pointId]
            if not point or point.type ~= 'verkaeufer' or point.placementMode ~= 'npc' then
                if DoesEntityExist(ped) then
                    SetEntityAsMissionEntity(ped, true, true)
                    DeleteEntity(ped)
                end
                spawnedPeds[pointId] = nil
            end
        end
    end
end)

local spawnedBlips = {}

local function CreateVendorBlip(point)
    local blip = AddBlipForCoord(point.coords.x, point.coords.y, point.coords.z)
    SetBlipSprite(blip, point.blipSprite or 1)
    SetBlipColour(blip, point.blipColor or 3)
    SetBlipScale(blip, 0.8)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(Locale('point_type_verkaeufer'))
    EndTextCommandSetBlipName(blip)
    return blip
end

CreateThread(function()
    while true do
        Wait(3000)
        for _, point in pairs(ClientFarmPoints or {}) do
            if point.type == 'verkaeufer' then
                if point.showBlip then
                    if not spawnedBlips[point.id] then
                        spawnedBlips[point.id] = CreateVendorBlip(point)
                    else
                        SetBlipSprite(spawnedBlips[point.id], point.blipSprite or 1)
                        SetBlipColour(spawnedBlips[point.id], point.blipColor or 3)
                    end
                elseif spawnedBlips[point.id] then
                    RemoveBlip(spawnedBlips[point.id])
                    spawnedBlips[point.id] = nil
                end
            end
        end
        for pointId, blip in pairs(spawnedBlips) do
            local point = ClientFarmPoints and ClientFarmPoints[pointId]
            if not point or point.type ~= 'verkaeufer' or not point.showBlip then
                RemoveBlip(blip)
                spawnedBlips[pointId] = nil
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end
    for _, ped in pairs(spawnedPeds) do
        if DoesEntityExist(ped) then
            SetEntityAsMissionEntity(ped, true, true)
            DeleteEntity(ped)
        end
    end
    for _, blip in pairs(spawnedBlips) do
        RemoveBlip(blip)
    end
end)
