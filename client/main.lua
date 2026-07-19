ClientFarmProjects = {}
ClientFarmPoints = {}

RegisterNetEvent('forge_farming:sync:projects')
AddEventHandler('forge_farming:sync:projects', function(projects)
    ClientFarmProjects = projects
end)

RegisterNetEvent('forge_farming:sync:points')
AddEventHandler('forge_farming:sync:points', function(points)
    ClientFarmPoints = points
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end
    TriggerServerEvent('forge_farming:requestSync')
end)

TriggerServerEvent('forge_farming:requestSync')

local function KeyboardInput(title, maxLength, regex)
    DebugPrint('KeyboardInput oeffnet:', title)
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
    DebugPrint('KeyboardInput Ergebnis:', title, '->', tostring(result))
    Wait(150)
    return result
end

local function SelectFromList(menuId, title, options)
    DebugPrint('SelectFromList oeffnet:', menuId, title, '(' .. #options .. ' Optionen)')
    local promise = promise.new()
    local elements = {}
    for _, opt in ipairs(options) do
        elements[#elements + 1] = { title = opt.label, value = opt.value, type = 'button', description = opt.description }
    end
    exports['hex_menu_api']:rageOpen(GetCurrentResourceName(), menuId, {
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
    DebugPrint('SelectFromList Ergebnis:', menuId, '->', tostring(result))
    Wait(150)
    return result
end

local function GetSortedIds(items)
    local ids = {}
    for id in pairs(items or {}) do
        ids[#ids + 1] = id
    end
    table.sort(ids)
    return ids
end

local function CopySellPrices(sellPrices)
    local copy = {}
    for _, entry in ipairs(sellPrices or {}) do
        copy[#copy + 1] = { item = entry.item, minPrice = entry.minPrice, maxPrice = entry.maxPrice }
    end
    return copy
end

local OpenProjectListMenu, OpenProjectDetailMenu, OpenRecipeListMenu, OpenRecipeDetailMenu
local OpenSellPriceListMenu, OpenSellPriceDeleteMenu, OpenPointListMenu, OpenPointDetailMenu

local function SendProjectUpdate(project, sellPrices)
    TriggerServerEvent('forge_farming:creator:updateProject', project.id, {
        label = project.label,
        rawItem = project.rawItem,
        rawMinAmount = project.rawMinAmount,
        rawMaxAmount = project.rawMaxAmount,
        gatherDuration = project.gatherDuration,
        sellPrices = sellPrices,
    })
end

local function PromptProjectForm(existingProject)
    DebugPrint('PromptProjectForm gestartet, existingProject =', existingProject and existingProject.id or 'nil')
    exports['hex_menu_api']:rageCloseAll()

    local label = KeyboardInput(Locale('field_label'), 50, nil)
    if not label or label == '' then
        DebugPrint('PromptProjectForm abgebrochen: kein Label')
        return
    end

    local rawItem = KeyboardInput(Locale('field_raw_item'), 50, nil)
    if not rawItem or rawItem == '' then
        DebugPrint('PromptProjectForm abgebrochen: kein rawItem')
        return
    end

    local rawMinAmount = tonumber(KeyboardInput(Locale('field_raw_min_amount'), 4, '^[0-9]+$'))
    if not rawMinAmount then
        DebugPrint('PromptProjectForm abgebrochen: rawMinAmount ungueltig')
        return
    end

    local rawMaxAmount = tonumber(KeyboardInput(Locale('field_raw_max_amount'), 4, '^[0-9]+$'))
    if not rawMaxAmount then
        DebugPrint('PromptProjectForm abgebrochen: rawMaxAmount ungueltig')
        return
    end

    local gatherDuration = tonumber(KeyboardInput(Locale('field_gather_duration'), 6, '^[0-9]+$'))
    if not gatherDuration then
        DebugPrint('PromptProjectForm abgebrochen: gatherDuration ungueltig')
        return
    end

    if rawMinAmount > rawMaxAmount then
        DebugPrint('PromptProjectForm abgebrochen: rawMinAmount > rawMaxAmount')
        return
    end

    local data = {
        label = label,
        rawItem = rawItem,
        rawMinAmount = rawMinAmount,
        rawMaxAmount = rawMaxAmount,
        gatherDuration = gatherDuration,
        sellPrices = existingProject and existingProject.sellPrices or {},
    }

    if existingProject then
        DebugPrint('PromptProjectForm sendet updateProject', existingProject.id)
        TriggerServerEvent('forge_farming:creator:updateProject', existingProject.id, data)
    else
        DebugPrint('PromptProjectForm sendet createProject', label)
        TriggerServerEvent('forge_farming:creator:createProject', data)
    end
end

local function PromptRecipeInputs()
    local inputs = {}
    while true do
        local itemName = KeyboardInput(Locale('field_recipe_input_item') .. ' (leer lassen zum Beenden)', 50, nil)
        if not itemName or itemName == '' then
            break
        end
        local amount = tonumber(KeyboardInput(Locale('field_recipe_input_amount'), 4, '^[0-9]+$'))
        if not amount then
            return nil
        end
        inputs[#inputs + 1] = { item = itemName, amount = amount }
    end
    return inputs
end

local function PromptRecipeForm(projectId, existingRecipe)
    exports['hex_menu_api']:rageCloseAll()

    local label = KeyboardInput(Locale('field_label'), 50, nil)
    if not label or label == '' then return end

    local inputs = PromptRecipeInputs()
    if not inputs or #inputs == 0 then return end

    local outputItem = KeyboardInput(Locale('field_recipe_output_item'), 50, nil)
    if not outputItem or outputItem == '' then return end

    local outputAmount = tonumber(KeyboardInput(Locale('field_recipe_output_amount'), 4, '^[0-9]+$'))
    if not outputAmount then return end

    local duration = tonumber(KeyboardInput(Locale('field_recipe_duration'), 6, '^[0-9]+$'))
    if not duration then return end

    local data = {
        label = label,
        inputs = inputs,
        outputItem = outputItem,
        outputAmount = outputAmount,
        duration = duration,
    }

    if existingRecipe then
        TriggerServerEvent('forge_farming:creator:updateRecipe', existingRecipe.id, data)
    else
        TriggerServerEvent('forge_farming:creator:createRecipe', projectId, data)
    end
end

local function PromptNewSellPrice(projectId)
    local project = ClientFarmProjects[projectId]
    if not project then return end

    local item = KeyboardInput(Locale('field_sell_item'), 50, nil)
    if not item or item == '' then return end

    local minPrice = tonumber(KeyboardInput(Locale('field_sell_price_min'), 7, '^[0-9]+$'))
    if not minPrice then return end

    local maxPrice = tonumber(KeyboardInput(Locale('field_sell_price_max'), 7, '^[0-9]+$'))
    if not maxPrice or maxPrice < minPrice then return end

    local sellPrices = CopySellPrices(project.sellPrices)
    sellPrices[#sellPrices + 1] = { item = item, minPrice = minPrice, maxPrice = maxPrice }
    SendProjectUpdate(project, sellPrices)
end

local MARKER_COLOR_PRESETS = {
    { key = 'blue', label = 'Blau', color = { r = 0, g = 155, b = 255, a = 120 } },
    { key = 'red', label = 'Rot', color = { r = 255, g = 0, b = 0, a = 120 } },
    { key = 'green', label = 'Grün', color = { r = 0, g = 200, b = 0, a = 120 } },
    { key = 'yellow', label = 'Gelb', color = { r = 255, g = 220, b = 0, a = 120 } },
    { key = 'purple', label = 'Lila', color = { r = 170, g = 0, b = 255, a = 120 } },
    { key = 'orange', label = 'Orange', color = { r = 255, g = 140, b = 0, a = 120 } },
    { key = 'white', label = 'Weiß', color = { r = 255, g = 255, b = 255, a = 150 } },
}

local function FindColorPreset(key)
    for _, preset in ipairs(MARKER_COLOR_PRESETS) do
        if preset.key == key then
            return preset.color
        end
    end
    return nil
end

local function PromptMarkerColor()
    local options = {}
    for _, preset in ipairs(MARKER_COLOR_PRESETS) do
        options[#options + 1] = { label = preset.label, value = preset.key }
    end
    options[#options + 1] = { label = Locale('field_marker_color_custom'), value = 'custom' }

    local choice = SelectFromList('rageui_creator_marker_color', Locale('field_marker_color'), options)
    if not choice then return nil end
    if choice ~= 'custom' then
        return FindColorPreset(choice)
    end

    local channels = {}
    for _, channel in ipairs({ 'R', 'G', 'B', 'A' }) do
        local value = tonumber(KeyboardInput(Locale('field_marker_color') .. ' - ' .. channel, 3, '^[0-9]+$'))
        if not value then return nil end
        channels[#channels + 1] = math.max(0, math.min(255, value))
    end
    return { r = channels[1], g = channels[2], b = channels[3], a = channels[4] }
end

local function PromptMarkerConfig()
    local markerType = tonumber(KeyboardInput(Locale('field_marker_type'), 3, '^[0-9]+$'))
    if not markerType then return nil end
    markerType = math.max(0, math.min(math.floor(markerType), 43))

    local markerColor = PromptMarkerColor()
    if not markerColor then return nil end

    return {
        placementMode = 'marker',
        markerType = markerType,
        markerColor = markerColor,
        markerRadius = Config.DefaultMarkerRadius,
        markerHeightOffset = 0.0,
    }
end

local function PromptSammlerMarkerConfig()
    local markerColor = PromptMarkerColor()
    if not markerColor then return nil end

    local heightInput = KeyboardInput(Locale('field_marker_height'), 6, '^[0-9]*[.,]?[0-9]*$')
    local normalizedHeight = (heightInput or ''):gsub(',', '.')
    local markerHeightOffset = tonumber(normalizedHeight) or 0.0

    return {
        placementMode = 'marker',
        markerType = Config.DefaultMarkerType,
        markerColor = markerColor,
        markerRadius = Config.DefaultMarkerRadius,
        markerHeightOffset = markerHeightOffset,
    }
end

local function PromptNpcConfig()
    local pedModel = KeyboardInput(Locale('field_ped_model'), 50, nil)
    if not pedModel or pedModel == '' then return nil end
    return { placementMode = 'npc', pedModel = pedModel }
end

local function PromptShowBlip()
    local choice = SelectFromList('rageui_creator_show_blip', Locale('field_show_blip'), {
        { label = Locale('yes'), value = 'yes' },
        { label = Locale('no'), value = 'no' },
    })
    if not choice then return nil end
    return choice == 'yes'
end

local function ApplyBlipConfig(pendingPointData)
    local showBlip = PromptShowBlip()
    if showBlip == nil then return false end
    pendingPointData.showBlip = showBlip
    if not showBlip then return true end

    local sprite = tonumber(KeyboardInput(Locale('field_blip_sprite'), 4, '^[0-9]+$'))
    if not sprite then return false end
    pendingPointData.blipSprite = math.max(1, math.floor(sprite))

    local color = tonumber(KeyboardInput(Locale('field_blip_color'), 3, '^[0-9]+$'))
    if not color then return false end
    pendingPointData.blipColor = math.max(0, math.min(math.floor(color), 85))

    return true
end

local function BuildPendingPointData(pointType)
    if pointType == 'sammler' then
        local pendingPointData = PromptSammlerMarkerConfig()
        if not pendingPointData then return nil end

        if not ApplyBlipConfig(pendingPointData) then return nil end

        return pendingPointData
    end

    local mode = SelectFromList('rageui_creator_placement_mode', Locale('field_placement_mode'), {
        { label = Locale('placement_mode_marker'), value = 'marker' },
        { label = Locale('placement_mode_npc'), value = 'npc' },
    })
    if not mode then return nil end

    local pendingPointData
    if mode == 'marker' then
        pendingPointData = PromptMarkerConfig()
    else
        pendingPointData = PromptNpcConfig()
    end
    if not pendingPointData then return nil end

    if pointType == 'verkaeufer' then
        local payoutAccount = SelectFromList('rageui_creator_payout_account', Locale('field_payout_account'), {
            { label = Locale('payout_cash'), value = 'cash' },
            { label = Locale('payout_bank'), value = 'bank' },
            { label = Locale('payout_black_money'), value = 'black_money' },
        })
        if not payoutAccount then return nil end
        pendingPointData.payoutAccount = payoutAccount

        if payoutAccount == 'black_money' then
            local policeAlert = SelectFromList('rageui_creator_police_alert', Locale('field_police_alert'), {
                { label = Locale('yes'), value = 'yes' },
                { label = Locale('no'), value = 'no' },
            })
            if not policeAlert then return nil end
            pendingPointData.policeAlert = policeAlert == 'yes'
        end
    end

    if not ApplyBlipConfig(pendingPointData) then return nil end

    return pendingPointData
end

local function CreatePreviewPed(pedModel)
    local model = joaat(pedModel)
    if not IsModelInCdimage(model) or not IsModelAPed(model) then
        return nil
    end

    RequestModel(model)
    local deadline = GetGameTimer() + 5000
    while not HasModelLoaded(model) and GetGameTimer() < deadline do
        Wait(10)
    end
    if not HasModelLoaded(model) then
        return nil
    end

    local ped = CreatePed(4, model, 0.0, 0.0, -100.0, 0.0, false, false)
    SetEntityAlpha(ped, 150, false)
    SetEntityCollision(ped, false, false)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetModelAsNoLongerNeeded(model)
    return ped
end

local function GetPlacementTarget(maxRayDistance)
    local cursorX = GetControlNormal(0, 239)
    local cursorY = GetControlNormal(0, 240)
    local camCoords, camForward = GetWorldCoordFromScreenCoord(cursorX, cursorY)
    local rayEnd = camCoords + camForward * maxRayDistance
    local rayHandle = StartShapeTestRay(camCoords.x, camCoords.y, camCoords.z, rayEnd.x, rayEnd.y, rayEnd.z, -1, PlayerPedId(), 0)
    local _, hit, endCoords, surfaceNormal = GetShapeTestResult(rayHandle)
    if not hit then
        return nil, nil
    end
    return endCoords, surfaceNormal
end

local function GetWallBackHeading(surfaceNormal)
    if not surfaceNormal or math.abs(surfaceNormal.z) > 0.5 then
        return nil
    end
    return math.deg(math.atan(surfaceNormal.x, surfaceNormal.y)) % 360.0
end

local function DrawSammlerPreview(pendingPointData, coords, color)
    local markerHeight = (pendingPointData.markerHeightOffset and pendingPointData.markerHeightOffset > 0)
        and pendingPointData.markerHeightOffset or (pendingPointData.markerRadius * 0.5)
    markerHeight = math.max(0.05, math.min(markerHeight, 10.0))
    DrawMarker(1, coords.x, coords.y, coords.z,
        0.0, 0.0, 1.0, 0.0, 0.0, 0.0,
        pendingPointData.markerRadius, pendingPointData.markerRadius, markerHeight,
        color.r, color.g, color.b, color.a, false, true, 2, false, nil, nil, false)
end

local function DrawMarkerPreview(markerType, markerRadius, markerHeightOffset, coords, color)
    local typeZOffset = markerType ~= 1 and (Config.FloatingMarkerZOffset or 1.5) or 0.0
    DrawMarker(markerType, coords.x, coords.y, coords.z + markerHeightOffset + typeZOffset, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0,
        markerRadius * 2.0, markerRadius * 2.0, 1.0,
        color.r, color.g, color.b, color.a, false, false, 2, false, nil, nil, false)
end

local function DrawPlacementPreview(pointType, pendingPointData, previewPed, coords, color, previewHeading)
    if pointType == 'sammler' then
        return DrawSammlerPreview(pendingPointData, coords, color)
    end

    if pendingPointData.placementMode == 'marker' then
        return DrawMarkerPreview(pendingPointData.markerType, pendingPointData.markerRadius,
            pendingPointData.markerHeightOffset or 0.0, coords, color)
    end

    if previewPed then
        SetEntityCoordsNoOffset(previewPed, coords.x, coords.y, coords.z, false, false, false)
        SetEntityHeading(previewPed, previewHeading)
    end
    DrawMarkerPreview(Config.DefaultMarkerType, Config.DefaultMarkerRadius, 0.0, coords, color)
end

local function IsPlacementConfirmPressed()
    return IsControlJustPressed(0, 24) or IsDisabledControlJustPressed(0, 24)
end

local function IsPlacementCancelPressed()
    return IsControlJustPressed(0, 25)
        or IsDisabledControlJustPressed(0, 25)
        or IsControlJustPressed(0, 202)
        or IsDisabledControlJustPressed(0, 202)
end

local function SubmitPoint(projectId, pointType, pendingPointData, coords, heading, pointId)
    pendingPointData.type = pointType
    pendingPointData.coords = {
        x = coords.x,
        y = coords.y,
        z = coords.z,
        heading = heading,
    }
    if pointId then
        TriggerServerEvent('forge_farming:creator:updatePoint', pointId, pendingPointData)
    else
        TriggerServerEvent('forge_farming:creator:createPoint', projectId, pendingPointData)
    end
end

local MIN_MARKER_RADIUS = 0.2
local MAX_MARKER_RADIUS = 10.0
local CONTROL_SCROLL_UP = 241
local CONTROL_SCROLL_DOWN = 242
local CONTROL_ROTATE_LEFT = 44
local CONTROL_ROTATE_RIGHT = 38

local function AdjustMarkerRadius(pendingPointData)
    if IsControlJustPressed(0, CONTROL_SCROLL_UP) then
        pendingPointData.markerRadius = math.min(MAX_MARKER_RADIUS, (pendingPointData.markerRadius or Config.DefaultMarkerRadius) + 0.1)
    elseif IsControlJustPressed(0, CONTROL_SCROLL_DOWN) then
        pendingPointData.markerRadius = math.max(MIN_MARKER_RADIUS, (pendingPointData.markerRadius or Config.DefaultMarkerRadius) - 0.1)
    end
end

local function AdjustPreviewHeading(previewHeading, wallHeading)
    local rotatingLeft = IsControlPressed(0, CONTROL_ROTATE_LEFT) or IsDisabledControlPressed(0, CONTROL_ROTATE_LEFT)
    local rotatingRight = IsControlPressed(0, CONTROL_ROTATE_RIGHT) or IsDisabledControlPressed(0, CONTROL_ROTATE_RIGHT)

    if rotatingLeft then
        return (previewHeading - 2.0) % 360.0
    end
    if rotatingRight then
        return (previewHeading + 2.0) % 360.0
    end
    if wallHeading then
        return wallHeading
    end
    return previewHeading
end

local function StartPlacementTool(projectId, pointType, pendingPointData, pointId)
    exports['hex_menu_api']:rageCloseAll()

    local helpText = Locale('placement_confirm_hint') .. ' | ' .. Locale('placement_cancel_hint')
    local validColor = pendingPointData.markerColor or Config.DefaultMarkerColor
    local invalidColor = { r = 255, g = 0, b = 0, a = 120 }
    local previewPed = nil
    if pendingPointData.placementMode == 'npc' then
        previewPed = CreatePreviewPed(pendingPointData.pedModel)
    end

    local previewHeading = GetEntityHeading(PlayerPedId())
    local confirmedCoords = nil
    while true do
        Wait(0)
        SetMouseCursorActiveThisFrame()
        DisablePlayerFiring(PlayerId(), true)
        DisableControlAction(0, 24, true)
        DisableControlAction(0, 25, true)
        TriggerEvent('fc_hud:helpNotify', 'MOUSE1', helpText)

        local targetCoords, surfaceNormal = GetPlacementTarget(Config.MaxPlacementDistance * 2.0)

        if pendingPointData.placementMode == 'marker' then
            AdjustMarkerRadius(pendingPointData)
        else
            DisableControlAction(0, CONTROL_ROTATE_LEFT, true)
            DisableControlAction(0, CONTROL_ROTATE_RIGHT, true)
            previewHeading = AdjustPreviewHeading(previewHeading, GetWallBackHeading(surfaceNormal))
        end

        local inRange = false
        if targetCoords then
            local playerCoords = GetEntityCoords(PlayerPedId())
            inRange = #(playerCoords - targetCoords) <= Config.MaxPlacementDistance
            DrawPlacementPreview(pointType, pendingPointData, previewPed, targetCoords, inRange and validColor or invalidColor, previewHeading)
        elseif previewPed then
            SetEntityCoordsNoOffset(previewPed, 0.0, 0.0, -100.0, false, false, false)
        end

        if targetCoords and inRange and IsPlacementConfirmPressed() then
            confirmedCoords = targetCoords
            break
        end
        if IsPlacementCancelPressed() then
            break
        end
    end

    if previewPed then
        DeleteEntity(previewPed)
    end

    if confirmedCoords then
        local finalHeading = pendingPointData.placementMode == 'npc' and previewHeading or GetEntityHeading(PlayerPedId())
        SubmitPoint(projectId, pointType, pendingPointData, confirmedCoords, finalHeading, pointId)
        Wait(250)
    end
    OpenPointListMenu(projectId, pointType)
end

local function StartPointCreationFlow(projectId, pointType)
    exports['hex_menu_api']:rageCloseAll()

    local pendingPointData = BuildPendingPointData(pointType)
    if not pendingPointData then
        return OpenPointListMenu(projectId, pointType)
    end

    StartPlacementTool(projectId, pointType, pendingPointData)
end

local function StartPointEditFlow(pointId)
    local point = ClientFarmPoints[pointId]
    if not point then
        return OpenProjectListMenu()
    end

    exports['hex_menu_api']:rageCloseAll()

    local pendingPointData = BuildPendingPointData(point.type)
    if not pendingPointData then
        return OpenPointDetailMenu(pointId)
    end

    StartPlacementTool(point.projectId, point.type, pendingPointData, pointId)
end

local function HandleProjectDetailSelect(projectId, project, value)
    if value == 'edit' then
        CreateThread(function()
            PromptProjectForm(project)
            Wait(250)
            OpenProjectDetailMenu(projectId)
        end)
        return
    end
    if value == 'delete' then
        TriggerServerEvent('forge_farming:creator:deleteProject', projectId)
        CreateThread(function()
            Wait(250)
            OpenProjectListMenu()
        end)
        return
    end
    if value == 'recipes' then
        return OpenRecipeListMenu(projectId)
    end
    if value == 'sell_prices' then
        return OpenSellPriceListMenu(projectId)
    end
    local pointType = string.match(value or '', '^points_(.+)$')
    if pointType then
        OpenPointListMenu(projectId, pointType)
    end
end

function OpenProjectListMenu()
    exports['hex_menu_api']:rageCloseAll()

    local elements = {}
    for _, id in ipairs(GetSortedIds(ClientFarmProjects)) do
        elements[#elements + 1] = { title = ClientFarmProjects[id].label, value = 'project_' .. id, type = 'button' }
    end
    elements[#elements + 1] = { title = Locale('creator_new_project'), value = 'new', type = 'button' }

    exports['hex_menu_api']:rageOpen(GetCurrentResourceName(), 'rageui_creator_projects', {
        title = Locale('creator_menu_title'),
        elements = elements,
        align = 'left'
    }, function(data, menu)
        if data.current.value == 'new' then
            CreateThread(function()
                PromptProjectForm(nil)
                Wait(250)
                OpenProjectListMenu()
            end)
            return
        end
        local projectId = tonumber(string.match(data.current.value or '', '^project_(%d+)$'))
        if projectId then
            OpenProjectDetailMenu(projectId)
        end
    end, function(data, menu)
        menu.close()
    end, function() end)
end

function OpenProjectDetailMenu(projectId)
    local project = ClientFarmProjects[projectId]
    if not project then
        return OpenProjectListMenu()
    end

    exports['hex_menu_api']:rageCloseAll()

    local elements = {
        { title = Locale('creator_edit_project'), value = 'edit', type = 'button' },
        { title = Locale('creator_manage_recipes'), value = 'recipes', type = 'button' },
        { title = Locale('creator_manage_sell_prices'), value = 'sell_prices', type = 'button' },
        { title = Locale('creator_manage_points'), type = 'seperator' },
        { title = Locale('point_type_sammler'), value = 'points_sammler', type = 'button' },
        { title = Locale('point_type_verarbeiter'), value = 'points_verarbeiter', type = 'button' },
        { title = Locale('point_type_verkaeufer'), value = 'points_verkaeufer', type = 'button' },
        { title = Locale('creator_delete_project'), value = 'delete', type = 'button' },
    }

    exports['hex_menu_api']:rageOpen(GetCurrentResourceName(), 'rageui_creator_project_detail', {
        title = project.label,
        elements = elements,
        align = 'left'
    }, function(data, menu)
        HandleProjectDetailSelect(projectId, project, data.current.value)
    end, function(data, menu)
        menu.close()
    end, function() end)
end

function OpenRecipeListMenu(projectId)
    local project = ClientFarmProjects[projectId]
    if not project then
        return OpenProjectListMenu()
    end

    exports['hex_menu_api']:rageCloseAll()

    local elements = {}
    for _, id in ipairs(GetSortedIds(project.recipes)) do
        elements[#elements + 1] = { title = project.recipes[id].label, value = 'recipe_' .. id, type = 'button' }
    end
    elements[#elements + 1] = { title = Locale('creator_recipe_add'), value = 'new', type = 'button' }

    exports['hex_menu_api']:rageOpen(GetCurrentResourceName(), 'rageui_creator_recipes', {
        title = Locale('creator_manage_recipes'),
        elements = elements,
        align = 'left'
    }, function(data, menu)
        if data.current.value == 'new' then
            CreateThread(function()
                PromptRecipeForm(projectId, nil)
                Wait(250)
                OpenRecipeListMenu(projectId)
            end)
            return
        end
        local recipeId = tonumber(string.match(data.current.value or '', '^recipe_(%d+)$'))
        if recipeId then
            OpenRecipeDetailMenu(projectId, recipeId)
        end
    end, function(data, menu)
        menu.close()
    end, function() end)
end

function OpenRecipeDetailMenu(projectId, recipeId)
    local project = ClientFarmProjects[projectId]
    local recipe = project and project.recipes and project.recipes[recipeId]
    if not recipe then
        return OpenRecipeListMenu(projectId)
    end

    exports['hex_menu_api']:rageCloseAll()

    local elements = {
        { title = Locale('creator_recipe_edit'), value = 'edit', type = 'button' },
        { title = Locale('creator_recipe_delete'), value = 'delete', type = 'button' },
    }

    exports['hex_menu_api']:rageOpen(GetCurrentResourceName(), 'rageui_creator_recipe_detail', {
        title = recipe.label,
        elements = elements,
        align = 'left'
    }, function(data, menu)
        if data.current.value == 'edit' then
            CreateThread(function()
                PromptRecipeForm(projectId, recipe)
                Wait(250)
                OpenRecipeListMenu(projectId)
            end)
        elseif data.current.value == 'delete' then
            TriggerServerEvent('forge_farming:creator:deleteRecipe', recipeId)
            CreateThread(function()
                Wait(250)
                OpenRecipeListMenu(projectId)
            end)
        end
    end, function(data, menu)
        menu.close()
    end, function() end)
end

function OpenSellPriceListMenu(projectId)
    local project = ClientFarmProjects[projectId]
    if not project then
        return OpenProjectListMenu()
    end

    exports['hex_menu_api']:rageCloseAll()

    local elements = {}
    for index, entry in ipairs(project.sellPrices or {}) do
        elements[#elements + 1] = {
            title = Locale('creator_sell_price_entry', entry.item, entry.minPrice, entry.maxPrice),
            value = 'price_' .. index,
            type = 'button',
        }
    end
    elements[#elements + 1] = { title = Locale('creator_sell_price_add'), value = 'new', type = 'button' }

    exports['hex_menu_api']:rageOpen(GetCurrentResourceName(), 'rageui_creator_sell_prices', {
        title = Locale('creator_manage_sell_prices'),
        elements = elements,
        align = 'left'
    }, function(data, menu)
        if data.current.value == 'new' then
            CreateThread(function()
                PromptNewSellPrice(projectId)
                Wait(250)
                OpenSellPriceListMenu(projectId)
            end)
            return
        end
        local index = tonumber(string.match(data.current.value or '', '^price_(%d+)$'))
        if index then
            OpenSellPriceDeleteMenu(projectId, index)
        end
    end, function(data, menu)
        menu.close()
    end, function() end)
end

function OpenSellPriceDeleteMenu(projectId, index)
    local project = ClientFarmProjects[projectId]
    local entry = project and project.sellPrices and project.sellPrices[index]
    if not entry then
        return OpenSellPriceListMenu(projectId)
    end

    exports['hex_menu_api']:rageCloseAll()

    local elements = {
        { title = Locale('delete'), value = 'delete', type = 'button', description = Locale('creator_sell_price_entry', entry.item, entry.minPrice, entry.maxPrice) },
        { title = Locale('back'), value = 'back', type = 'button' },
    }

    exports['hex_menu_api']:rageOpen(GetCurrentResourceName(), 'rageui_creator_sell_price_detail', {
        title = Locale('creator_sell_price_entry', entry.item, entry.minPrice, entry.maxPrice),
        elements = elements,
        align = 'left'
    }, function(data, menu)
        if data.current.value == 'delete' then
            local currentProject = ClientFarmProjects[projectId]
            if not currentProject then
                return OpenProjectListMenu()
            end
            local sellPrices = CopySellPrices(currentProject.sellPrices)
            table.remove(sellPrices, index)
            SendProjectUpdate(currentProject, sellPrices)
            CreateThread(function()
                Wait(250)
                OpenSellPriceListMenu(projectId)
            end)
        elseif data.current.value == 'back' then
            OpenSellPriceListMenu(projectId)
        end
    end, function(data, menu)
        menu.close()
    end, function() end)
end

function OpenPointListMenu(projectId, pointType)
    exports['hex_menu_api']:rageCloseAll()

    local elements = {}
    for _, id in ipairs(GetSortedIds(ClientFarmPoints)) do
        local point = ClientFarmPoints[id]
        if point.projectId == projectId and point.type == pointType then
            elements[#elements + 1] = { title = 'Punkt #' .. id, value = 'point_' .. id, type = 'button' }
        end
    end
    elements[#elements + 1] = { title = Locale('creator_point_add'), value = 'new', type = 'button' }

    exports['hex_menu_api']:rageOpen(GetCurrentResourceName(), 'rageui_creator_points', {
        title = Locale('point_type_' .. pointType),
        elements = elements,
        align = 'left'
    }, function(data, menu)
        if data.current.value == 'new' then
            CreateThread(function()
                StartPointCreationFlow(projectId, pointType)
            end)
            return
        end
        local pointId = tonumber(string.match(data.current.value or '', '^point_(%d+)$'))
        if pointId then
            OpenPointDetailMenu(pointId)
        end
    end, function(data, menu)
        menu.close()
    end, function() end)
end

function OpenPointDetailMenu(pointId)
    local point = ClientFarmPoints[pointId]
    if not point then return end

    exports['hex_menu_api']:rageCloseAll()

    local modeLabel = point.placementMode == 'npc' and Locale('placement_mode_npc') or Locale('placement_mode_marker')
    local coordsInfo = string.format('%.1f, %.1f, %.1f', point.coords.x, point.coords.y, point.coords.z)
    local elements = {
        { title = modeLabel .. ' | ' .. coordsInfo, value = 'info', type = 'button', locked = true },
        { title = Locale('creator_point_edit'), value = 'edit', type = 'button' },
        { title = Locale('creator_point_delete'), value = 'delete', type = 'button' },
    }

    exports['hex_menu_api']:rageOpen(GetCurrentResourceName(), 'rageui_creator_point_detail', {
        title = 'Punkt #' .. pointId,
        elements = elements,
        align = 'left'
    }, function(data, menu)
        if data.current.value == 'edit' then
            CreateThread(function()
                StartPointEditFlow(pointId)
            end)
            return
        end
        if data.current.value ~= 'delete' then return end
        TriggerServerEvent('forge_farming:creator:deletePoint', pointId)
        CreateThread(function()
            Wait(250)
            OpenPointListMenu(point.projectId, point.type)
        end)
    end, function(data, menu)
        menu.close()
    end, function() end)
end

RegisterCommand('farmingcreator', function()
    OpenProjectListMenu()
end, false)
