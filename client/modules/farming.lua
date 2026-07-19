local DRAW_DISTANCE = 30.0
local CONTROL_INTERACT = 38
local CONTROL_CANCEL = 73
local GATHER_ANIM_DICT = 'amb@world_human_gardener_plant@male@base'
local GATHER_ANIM_NAME = 'base'

local groundCache = {}
local isCollecting = false
local collectingPointId = nil

local function StartGatherAnim()
    RequestAnimDict(GATHER_ANIM_DICT)
    local timeout = GetGameTimer() + 2000
    while not HasAnimDictLoaded(GATHER_ANIM_DICT) and GetGameTimer() < timeout do
        Wait(10)
    end
    if not HasAnimDictLoaded(GATHER_ANIM_DICT) or not isCollecting then
        return
    end
    TaskPlayAnim(PlayerPedId(), GATHER_ANIM_DICT, GATHER_ANIM_NAME, 8.0, -8.0, -1, 1, 0, false, false, false)
end

local function StopGatherAnim()
    local ped = PlayerPedId()
    if DoesEntityExist(ped) then
        ClearPedTasks(ped)
    end
end

local function isFiniteNumber(value)
    return type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge
end

local function buildSafeNormal(normal)
    if normal and isFiniteNumber(normal.x) and isFiniteNumber(normal.y) and isFiniteNumber(normal.z)
        and (normal.x ~= 0.0 or normal.y ~= 0.0 or normal.z ~= 0.0) then
        return { x = normal.x, y = normal.y, z = normal.z }
    end
    return { x = 0.0, y = 0.0, z = 1.0 }
end

local function resolveGround(point)
    local coords = point.coords
    local cached = groundCache[point.id]
    if cached and cached.srcX == coords.x and cached.srcY == coords.y and cached.srcZ == coords.z then
        return cached
    end

    local found, groundZ, normal = GetGroundZAndNormalFor_3dCoord(coords.x, coords.y, coords.z + 1.0)
    if not found or not isFiniteNumber(groundZ) then
        return { z = coords.z, normal = { x = 0.0, y = 0.0, z = 1.0 } }
    end

    local ground = {
        z = groundZ,
        normal = buildSafeNormal(normal),
        srcX = coords.x,
        srcY = coords.y,
        srcZ = coords.z
    }
    groundCache[point.id] = ground
    return ground
end

local function drawSammlerMarker(point)
    local coords = point.coords
    local color = point.markerColor
    local markerHeight = (point.markerHeightOffset and point.markerHeightOffset > 0)
        and point.markerHeightOffset or (point.markerRadius * 0.5)
    markerHeight = math.max(0.05, math.min(markerHeight, 10.0))
    DrawMarker(
        point.markerType,
        coords.x, coords.y, coords.z,
        0.0, 0.0, 1.0,
        0.0, 0.0, 0.0,
        point.markerRadius, point.markerRadius, markerHeight,
        color.r, color.g, color.b, color.a,
        false, true, 2, false, nil, nil, false
    )
end

local function findClosestSammler(playerCoords)
    if type(ClientFarmPoints) ~= 'table' then
        return nil, nil
    end

    local closestPoint = nil
    local closestDistance = nil

    for _, point in pairs(ClientFarmPoints) do
        if point.type == 'sammler' then
            local coords = point.coords
            local distance = #(playerCoords - vector3(coords.x, coords.y, coords.z))

            if distance <= DRAW_DISTANCE then
                drawSammlerMarker(point)
            end

            if not closestDistance or distance < closestDistance then
                closestDistance = distance
                closestPoint = point
            end
        end
    end

    return closestPoint, closestDistance
end

local function handleInteraction(point, distance)
    if isCollecting then
        if IsControlJustPressed(0, CONTROL_CANCEL) then
            TriggerServerEvent('forge_farming:sammler:cancel')
        end
        return
    end

    if not point or not distance then
        return
    end

    local interactionDistance = (type(point.markerRadius) == 'number' and point.markerRadius > 0)
        and point.markerRadius or Config.InteractionDistance
    if distance > interactionDistance then
        return
    end

    TriggerEvent('fc_hud:helpNotify', 'E', Locale('sammler_help_collect'))

    if IsControlJustPressed(0, CONTROL_INTERACT) then
        TriggerServerEvent('forge_farming:sammler:start', point.id)
    end
end

RegisterNetEvent('forge_farming:sammler:started')
AddEventHandler('forge_farming:sammler:started', function(pointId)
    isCollecting = true
    collectingPointId = pointId
    CreateThread(StartGatherAnim)
end)

RegisterNetEvent('forge_farming:sammler:stopped')
AddEventHandler('forge_farming:sammler:stopped', function()
    isCollecting = false
    collectingPointId = nil
    StopGatherAnim()
end)

local function GetPointInteractionDistance(point)
    if type(point.markerRadius) == 'number' and point.markerRadius > 0 then
        return point.markerRadius
    end
    return Config.InteractionDistance
end

CreateThread(function()
    while true do
        local playerCoords = GetEntityCoords(PlayerPedId())

        if isCollecting and collectingPointId then
            local point = ClientFarmPoints and ClientFarmPoints[collectingPointId]
            if point then
                local coords = point.coords
                local dist = #(playerCoords - vector3(coords.x, coords.y, coords.z))
                if dist > GetPointInteractionDistance(point) then
                    isCollecting = false
                    collectingPointId = nil
                    StopGatherAnim()
                    TriggerServerEvent('forge_farming:sammler:cancel')
                end
            end
        end

        local closestPoint, closestDistance = findClosestSammler(playerCoords)
        handleInteraction(closestPoint, closestDistance)
        Wait(0)
    end
end)

local spawnedBlips = {}

local function CreateSammlerBlip(point)
    local blip = AddBlipForCoord(point.coords.x, point.coords.y, point.coords.z)
    SetBlipSprite(blip, point.blipSprite or 1)
    SetBlipColour(blip, point.blipColor or 2)
    SetBlipScale(blip, 0.8)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(Locale('point_type_sammler'))
    EndTextCommandSetBlipName(blip)
    return blip
end

CreateThread(function()
    while true do
        Wait(3000)
        for _, point in pairs(ClientFarmPoints or {}) do
            if point.type == 'sammler' then
                if point.showBlip then
                    if not spawnedBlips[point.id] then
                        spawnedBlips[point.id] = CreateSammlerBlip(point)
                    else
                        SetBlipSprite(spawnedBlips[point.id], point.blipSprite or 1)
                        SetBlipColour(spawnedBlips[point.id], point.blipColor or 2)
                    end
                elseif spawnedBlips[point.id] then
                    RemoveBlip(spawnedBlips[point.id])
                    spawnedBlips[point.id] = nil
                end
            end
        end
        for pointId, blip in pairs(spawnedBlips) do
            local point = ClientFarmPoints and ClientFarmPoints[pointId]
            if not point or point.type ~= 'sammler' or not point.showBlip then
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
    for _, blip in pairs(spawnedBlips) do
        RemoveBlip(blip)
    end
end)
