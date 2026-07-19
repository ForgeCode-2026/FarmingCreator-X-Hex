local spawnedPeds = {}
local jobStatePromise = nil

RegisterNetEvent('forge_farming:verarbeiter:jobState')
AddEventHandler('forge_farming:verarbeiter:jobState', function(state)
    if not jobStatePromise then
        return
    end
    local pending = jobStatePromise
    jobStatePromise = nil
    pending:resolve(state)
end)

local function RequestJobState(pointId)
    local pending = promise.new()
    jobStatePromise = pending
    TriggerServerEvent('forge_farming:verarbeiter:getJobState', pointId)
    SetTimeout(5000, function()
        if jobStatePromise == pending then
            jobStatePromise = nil
            pending:resolve(nil)
        end
    end)
    return Citizen.Await(pending)
end

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
    exports['hex_menu_api']:rageCloseAll()
    local promise = promise.new()
    local elements = {}
    for _, opt in ipairs(options) do
        elements[#elements + 1] = { title = opt.label, value = opt.value, type = 'button', description = opt.description }
    end
    exports['hex_menu_api']:rageOpen(GetCurrentResourceName(), 'rageui_verarbeiter', {
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

local function FormatRemainingTime(ms)
    local totalSeconds = math.ceil((ms or 0) / 1000)
    local minutes = math.floor(totalSeconds / 60)
    local seconds = totalSeconds % 60
    return string.format('%02d:%02d', minutes, seconds)
end

local function FormatRecipeInputs(recipe)
    local parts = {}
    for _, input in ipairs(recipe.inputs or {}) do
        parts[#parts + 1] = string.format('%dx %s', input.amount, input.item)
    end
    return table.concat(parts, ', ')
end

local function BuildRecipeOptions(project)
    local options = {}
    for recipeId, recipe in pairs(project.recipes or {}) do
        options[#options + 1] = {
            label = recipe.label,
            value = recipeId,
            description = Locale('field_recipe_inputs') .. ': ' .. FormatRecipeInputs(recipe)
        }
    end
    table.sort(options, function(a, b)
        return tostring(a.label) < tostring(b.label)
    end)
    return options
end

local function PromptAmount()
    local choice = SelectFromList(Locale('input_amount'), {
        { label = Locale('verarbeiter_amount_all'), value = 'all' },
        { label = Locale('verarbeiter_amount_custom'), value = 'custom' },
    })
    if choice == 'all' then
        return 'max'
    end
    if choice ~= 'custom' then
        return nil
    end
    local input = KeyboardInput(Locale('input_amount'), 3, '^[0-9]+$')
    local amount = tonumber(input)
    if not amount or amount <= 0 then
        return nil
    end
    return amount
end

local function ShowJobMenu(point, state)
    local options = {}

    local finished = state.finishedRuns or 0
    local total = state.totalRuns or 0
    local pending = math.max(0, total - finished)

    if state.status == 'ready' then
        options[#options + 1] = { label = Locale('verarbeiter_all_done', total), value = 'info' }
    else
        options[#options + 1] = { label = Locale('verarbeiter_progress_done', finished, total), value = 'info' }
        options[#options + 1] = {
            label = Locale('verarbeiter_progress_pending', pending, FormatRemainingTime(state.remainingMs)),
            value = 'info',
        }
    end

    if finished > 0 then
        options[#options + 1] = {
            label = Locale('verarbeiter_collect_finished', state.finishedOutput or 0, state.outputItem or '?'),
            value = 'collect_finished',
        }
    end

    if state.status == 'running' then
        options[#options + 1] = { label = Locale('verarbeiter_add_more'), value = 'add_more' }
    end

    local choice = SelectFromList(Locale('verarbeiter_menu_title'), options)
    if choice == 'collect_finished' then
        local amount = PromptAmount()
        if not amount then
            return
        end
        TriggerServerEvent('forge_farming:verarbeiter:collectFinished', point.id, amount)
    elseif choice == 'add_more' then
        local amount = PromptAmount()
        if not amount then
            return
        end
        TriggerServerEvent('forge_farming:verarbeiter:addToJob', point.id, amount)
    end
end

local function ShowRecipeMenu(point)
    local project = ClientFarmProjects and ClientFarmProjects[point.projectId]
    if not project then
        return
    end
    local options = BuildRecipeOptions(project)
    if #options == 0 then
        return
    end
    local recipeId = SelectFromList(Locale('verarbeiter_recipe_select'), options)
    if not recipeId then
        return
    end
    local amount = PromptAmount()
    if not amount then
        return
    end
    TriggerServerEvent('forge_farming:verarbeiter:startJob', point.id, recipeId, amount)
end

local function OpenVerarbeiterMenu(point)
    local state = RequestJobState(point.id)
    if not state then
        return
    end
    if state.status == 'none' then
        ShowRecipeMenu(point)
        return
    end
    ShowJobMenu(point, state)
end

local function GetInteractionCoords(point)
    local ped = spawnedPeds[point.id]
    if point.placementMode == 'npc' and ped and ped ~= -1 and DoesEntityExist(ped) then
        return GetEntityCoords(ped)
    end
    return vector3(point.coords.x, point.coords.y, point.coords.z)
end

local function GetNearestVerarbeiterPoint(playerCoords)
    local nearestPoint = nil
    local nearestDist = Config.InteractionDistance
    for _, point in pairs(ClientFarmPoints or {}) do
        if point.type == 'verarbeiter' then
            local dist = #(playerCoords - GetInteractionCoords(point))
            if dist < nearestDist then
                nearestDist = dist
                nearestPoint = point
            end
        end
    end
    return nearestPoint
end

local function SpawnPointPed(point)
    spawnedPeds[point.id] = -1
    CreateThread(function()
        local model = joaat(point.pedModel)
        RequestModel(model)
        local timeout = GetGameTimer() + 10000
        while not HasModelLoaded(model) and GetGameTimer() < timeout do
            Wait(50)
        end
        if not HasModelLoaded(model) then
            spawnedPeds[point.id] = nil
            return
        end
        local coords = point.coords
        local ped = CreatePed(4, model, coords.x, coords.y, coords.z, coords.heading, false, true)
        FreezeEntityPosition(ped, true)
        SetEntityInvincible(ped, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        SetModelAsNoLongerNeeded(model)
        spawnedPeds[point.id] = ped
    end)
end

local function DrawVerarbeiterMarker(point)
    local coords = point.coords
    local typeZOffset = point.markerType ~= 1 and (Config.FloatingMarkerZOffset or 1.5) or 0.0
    local z = coords.z + (point.markerHeightOffset or 0.0) + typeZOffset
    DrawMarker(point.markerType, coords.x, coords.y, z, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, point.markerRadius, point.markerRadius, point.markerRadius * 0.5, point.markerColor.r, point.markerColor.g, point.markerColor.b, point.markerColor.a, false, true, 2, false, nil, nil, false)
end

CreateThread(function()
    while true do
        local playerCoords = GetEntityCoords(PlayerPedId())
        for _, point in pairs(ClientFarmPoints or {}) do
            if point.type == 'verarbeiter' then
                local dist = #(playerCoords - vector3(point.coords.x, point.coords.y, point.coords.z))
                if dist < 30.0 then
                    if point.placementMode == 'marker' then
                        DrawVerarbeiterMarker(point)
                    elseif point.placementMode == 'npc' and not spawnedPeds[point.id] then
                        SpawnPointPed(point)
                    end
                end
            end
        end
        Wait(0)
    end
end)

CreateThread(function()
    while true do
        Wait(5000)
        for pointId, ped in pairs(spawnedPeds) do
            local point = ClientFarmPoints and ClientFarmPoints[pointId]
            local stillValid = point and point.type == 'verarbeiter' and point.placementMode == 'npc'
            if ped ~= -1 then
                if not stillValid then
                    if DoesEntityExist(ped) then
                        DeletePed(ped)
                    end
                    spawnedPeds[pointId] = nil
                elseif not DoesEntityExist(ped) then
                    spawnedPeds[pointId] = nil
                end
            end
        end
    end
end)

local spawnedBlips = {}

local function CreateVerarbeiterBlip(point)
    local blip = AddBlipForCoord(point.coords.x, point.coords.y, point.coords.z)
    SetBlipSprite(blip, point.blipSprite or 1)
    SetBlipColour(blip, point.blipColor or 5)
    SetBlipScale(blip, 0.8)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(Locale('point_type_verarbeiter'))
    EndTextCommandSetBlipName(blip)
    return blip
end

CreateThread(function()
    while true do
        Wait(3000)
        for _, point in pairs(ClientFarmPoints or {}) do
            if point.type == 'verarbeiter' then
                if point.showBlip then
                    if not spawnedBlips[point.id] then
                        spawnedBlips[point.id] = CreateVerarbeiterBlip(point)
                    else
                        SetBlipSprite(spawnedBlips[point.id], point.blipSprite or 1)
                        SetBlipColour(spawnedBlips[point.id], point.blipColor or 5)
                    end
                elseif spawnedBlips[point.id] then
                    RemoveBlip(spawnedBlips[point.id])
                    spawnedBlips[point.id] = nil
                end
            end
        end
        for pointId, blip in pairs(spawnedBlips) do
            local point = ClientFarmPoints and ClientFarmPoints[pointId]
            if not point or point.type ~= 'verarbeiter' or not point.showBlip then
                RemoveBlip(blip)
                spawnedBlips[pointId] = nil
            end
        end
    end
end)

local hudPointId = nil
local hudState = nil
local hudFetchedAt = 0

CreateThread(function()
    while true do
        local sleep = 250
        local playerCoords = GetEntityCoords(PlayerPedId())
        local point = GetNearestVerarbeiterPoint(playerCoords)
        if point then
            sleep = 0
            if hudPointId ~= point.id or (GetGameTimer() - hudFetchedAt) > 3000 then
                hudPointId = point.id
                hudState = RequestJobState(point.id)
                hudFetchedAt = GetGameTimer()
            end

            local helpText = Locale('verarbeiter_menu_title')
            if hudState and hudState.status == 'running' then
                local remaining = math.max(0, (hudState.remainingMs or 0) - (GetGameTimer() - hudFetchedAt))
                helpText = Locale('verarbeiter_hud_progress', hudState.finishedRuns or 0, hudState.totalRuns or 0, FormatRemainingTime(remaining))
            elseif hudState and hudState.status == 'ready' then
                helpText = Locale('verarbeiter_hud_ready', hudState.totalRuns or 0)
            end
            TriggerEvent('fc_hud:helpNotify', 'E', helpText)

            if IsControlJustPressed(0, 38) then
                OpenVerarbeiterMenu(point)
                hudPointId = nil
            end
        else
            hudPointId = nil
            hudState = nil
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end
    for _, ped in pairs(spawnedPeds) do
        if ped ~= -1 and DoesEntityExist(ped) then
            DeletePed(ped)
        end
    end
    for _, blip in pairs(spawnedBlips) do
        RemoveBlip(blip)
    end
end)
